"""Exercise the shared shell tables using private files and owned shell processes."""

import fcntl
import os
from pathlib import Path
import shlex
import signal
import subprocess
import sys
import tempfile
import time
import unittest


MODULE = Path(__file__).resolve().parents[2] / "src/core/session-state.sh"
SHELLS = [path for path in ("/bin/bash", "/bin/zsh") if Path(path).exists()]
COLORS = "claude '#112233' true dark '#223344' '#334455' '#445566' '#556677' '#667788'"


class SessionStateConcurrencyTests(unittest.TestCase):
    def fixture(self):
        root = Path(tempfile.mkdtemp(prefix="session-table-", dir=os.environ["TAVS_TEST_ROOT"]))
        for name in ("home", "state", "tmp", "bin", "gates"):
            (root / name).mkdir(mode=0o700)
        env = dict(PATH=str(root / "bin") + os.pathsep + "/usr/bin:/bin:/usr/sbin:/sbin",
                   HOME=str(root / "home"), CFFIXED_USER_HOME=str(root / "home"),
                   ZDOTDIR=str(root / "home"), TMPDIR=str(root / "tmp"),
                   TAVS_TMP_DIR=str(root / "state"), GATES=str(root / "gates"), IDLE_DEBUG="0")
        return root, env

    def command(self, shell, script):
        options = ["--noprofile", "--norc"] if shell.endswith("bash") else ["-f"]
        return [shell, *options, "-c", 'source "$1"\nget_time_ms() { echo 43000; }\n' + script,
                "session-table-test", str(MODULE)]

    def run_shell(self, shell, script, env):
        return subprocess.run(self.command(shell, script), env=env, capture_output=True,
                              text=True, timeout=10)

    def wait_for(self, process, *paths):
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if any(path.exists() for path in paths):
                return
            if process.poll() is not None:
                self.fail("Owned shell exited before fixture event: " + str(paths))
            time.sleep(0.005)
        self.fail("Owned shell did not reach fixture event: " + str(paths))

    def reap(self, process):
        try:
            return process.communicate(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.communicate(timeout=10)
            raise

    def gate_tools(self, root):
        # Gate publication, after each actor has prepared its entire replacement table.
        mv = root / "bin/mv"
        mv.write_text(f"#!{sys.executable}\n" + '''import os, pathlib, subprocess, sys, time
gate = pathlib.Path(os.environ["GATES"])
actor = os.environ.get("ACTOR", "")
if actor:
    (gate / (actor + ".prepared")).touch()
    deadline = time.monotonic() + 10
    while not (gate / (actor + ".release")).exists():
        if time.monotonic() > deadline:
            sys.exit(99)
        time.sleep(0.005)
result = subprocess.run(["/bin/mv", *sys.argv[1:]])
if actor:
    (gate / (actor + ".done")).touch()
sys.exit(result.returncode)
''')
        mv.chmod(0o700)
        # The second actor announces an acquisition attempt before the real backend blocks.
        for name, real in (("lockf", "/usr/bin/lockf"), ("python3", sys.executable)):
            wrapper = root / "bin" / name
            wrapper.write_text('#!/bin/sh\n'
                               'if [ -n "${ACTOR:-}" ]; then\n'
                               '  : > "$GATES/$ACTOR.lock-request"\nfi\n'
                               f'exec {shlex.quote(real)} "$@"\n')
            wrapper.chmod(0o700)

    def race(self, shell, table, first, second, expected):
        root, env = self.fixture()
        db = root / "state" / table
        initial = ("one idle 15 42 11\ntwo idle 15 42 22\nkeep processing 30 43 33\n"
                   if table == "state" else "one old\ntwo old\nkeep unchanged\n")
        db.write_text(initial)
        db.chmod(0o600)
        self.gate_tools(root)
        script = f'''
(export ACTOR=one; TTY_SAFE=one; {first}; echo $? > "$GATES/one.status") &
first_pid=$!
while [[ ! -f "$GATES/launch-two" ]]; do sleep 0.01; done
(export ACTOR=two; TTY_SAFE=two; {second}; echo $? > "$GATES/two.status") &
second_pid=$!
wait "$first_pid"
wait "$second_pid"
'''
        process = subprocess.Popen(self.command(shell, script), env=env, start_new_session=True,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        gates = root / "gates"
        try:
            self.wait_for(process, gates / "one.prepared")
            (gates / "launch-two").touch()
            self.wait_for(process, gates / "two.prepared", gates / "two.lock-request")
            (gates / "one.release").touch()
            self.wait_for(process, gates / "one.done")
            self.wait_for(process, gates / "two.prepared")
            (gates / "two.release").touch()
        finally:
            for marker in ("launch-two", "one.release", "two.release"):
                (gates / marker).touch()
            output, error = self.reap(process)
            (gates / "driver.stdout").write_text(output)
            (gates / "driver.stderr").write_text(error)
        self.assertEqual(process.returncode, 0, output + error)
        self.assertEqual(db.read_text(), expected, str(root))
        for actor in ("one", "two"):
            self.assertEqual((gates / (actor + ".status")).read_text(), "0\n", str(root))
        self.assertEqual(list(db.parent.glob(table + ".tmp.*")), [])

    def test_concurrent_state_writes_keep_both_updates_and_unrelated_row(self):
        for shell in SHELLS:
            with self.subTest(shell=shell):
                self.race(shell, "state", "write_session_state permission 111",
                          "record_state complete",
                          "keep processing 30 43 33\none permission 100 43000 111\n"
                          "two complete 20 43000 \n")

    def test_concurrent_color_writes_keep_both_updates(self):
        for shell in SHELLS:
            with self.subTest(shell=shell):
                self.race(shell, "colors", "write_session_colors " + COLORS,
                          "write_session_colors codex '#abcdef' false light",
                          "keep unchanged\none claude #112233 true dark #223344 #334455 "
                          "#445566 #556677 #667788\ntwo codex #abcdef false light     \n")

    def test_color_clear_and_write_share_the_same_transaction_lock(self):
        for shell in SHELLS:
            with self.subTest(shell=shell, order="clear-first"):
                self.race(shell, "colors", "clear_session_colors", "write_session_colors " + COLORS,
                          "keep unchanged\ntwo claude #112233 true dark #223344 #334455 "
                          "#445566 #556677 #667788\n")
            with self.subTest(shell=shell, order="write-first"):
                self.race(shell, "colors", "write_session_colors " + COLORS, "clear_session_colors",
                          "keep unchanged\none claude #112233 true dark #223344 #334455 "
                          "#445566 #556677 #667788\n")

    def test_empty_clear_success_and_literal_tty_key(self):
        for shell in SHELLS:
            with self.subTest(shell=shell):
                root, env = self.fixture()
                (root / "state/colors").write_text("tty.1 old\nttyx1 keep\n")
                result = self.run_shell(shell, '''
TTY_SAFE=tty.1
clear_session_colors || exit 20
[[ "$(cat "$SESSION_COLORS_DB")" == 'ttyx1 keep' ]] || exit 23
TTY_SAFE=ttyx1
clear_session_colors || exit 21
clear_session_colors || exit 22
''', env)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((root / "state/colors").read_text(), "")

    def test_held_lock_times_out_without_reading_clock_or_mutating_table(self):
        for shell in SHELLS:
            for table, call in (("state", "write_session_state permission"),
                                ("colors", "write_session_colors " + COLORS),
                                ("colors", "clear_session_colors")):
                with self.subTest(shell=shell, call=call):
                    root, env = self.fixture()
                    db = root / "state" / table
                    db.write_text("tty original\n")
                    lock = Path(str(db) + ".lock")
                    lock.touch(mode=0o600)
                    with lock.open("rb") as owner:
                        fcntl.flock(owner, fcntl.LOCK_EX)
                        result = self.run_shell(shell, '''
get_time_ms() { echo touched > "$GATES/clock"; echo 43000; }
TTY_SAFE=tty
''' + call, env)
                    self.assertNotEqual(result.returncode, 0, str(root))
                    self.assertEqual(db.read_text(), "tty original\n")
                    self.assertFalse((root / "gates/clock").exists())
                    self.assertEqual(list(db.parent.glob(table + ".tmp.*")), [])

    def test_crashed_owned_writer_releases_stable_lock(self):
        for shell in SHELLS:
            with self.subTest(shell=shell):
                root, env = self.fixture()
                script = '''
get_time_ms() {
    : > "$GATES/clock"
    while [[ ! -f "$GATES/release" ]]; do sleep 0.01; done
    echo 43000
}
TTY_SAFE=tty
write_session_state permission 111
'''
                process = subprocess.Popen(self.command(shell, script), env=env,
                                           start_new_session=True, stdout=subprocess.PIPE,
                                           stderr=subprocess.PIPE, text=True)
                try:
                    self.wait_for(process, root / "gates/clock")
                    lock = root / "state/state.lock"
                    before = lock.stat()
                finally:
                    if process.poll() is None:
                        os.killpg(process.pid, signal.SIGKILL)
                    self.reap(process)
                result = self.run_shell(shell, "TTY_SAFE=tty; write_session_state idle 222", env)
                self.assertEqual(result.returncode, 0, result.stderr)
                after = lock.stat()
                self.assertEqual((before.st_dev, before.st_ino), (after.st_dev, after.st_ino))
                self.assertEqual((root / "state/state").read_text(), "tty idle 15 43000 222\n")

    def test_failed_publication_preserves_data_and_caller_descriptor_and_trap(self):
        for shell in SHELLS:
            with self.subTest(shell=shell):
                root, env = self.fixture()
                db = root / "state/state"
                db.write_text("tty original\n")
                (root / "state/state.tmp.keep").write_text("unrelated\n")
                result = self.run_shell(shell, '''
trap ':' TERM
before=$(trap)
exec 9> "$GATES/parent-fd"
mv() { return 23; }
TTY_SAFE=tty
if write_session_state permission; then exit 20; fi
[[ "$(cat "$STATE_DB")" == 'tty original' ]] || exit 22
set -- "$TAVS_TMP_DIR"/state.tmp.*
[[ "$#" -eq 1 && "$1" == "$TAVS_TMP_DIR/state.tmp.keep" ]] || exit 23
[[ "$(trap)" == "$before" ]] || exit 21
printf 'retained' >&9
unset -f mv
write_session_state idle 222
''', env)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((root / "gates/parent-fd").read_text(), "retained")
                self.assertEqual((root / "state/state.tmp.keep").read_text(), "unrelated\n")
                self.assertEqual(list(db.parent.glob("state.tmp.*")), [root / "state/state.tmp.keep"])
                self.assertEqual(db.read_text(), "tty idle 15 43000 222\n")

    def test_lock_or_filter_failure_never_publishes_an_unlocked_or_partial_update(self):
        for shell in SHELLS:
            for failure in ("lockf() { return 69; }; python3() { return 69; }",
                            "awk() { printf partial; return 23; }"):
                with self.subTest(shell=shell, failure=failure):
                    root, env = self.fixture()
                    db = root / "state/state"
                    db.write_text("tty original\nkeep unchanged\n")
                    result = self.run_shell(shell, failure + '''
TTY_SAFE=tty
if write_session_state permission; then exit 20; fi
exit 0
''', env)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(db.read_text(), "tty original\nkeep unchanged\n")
                    self.assertEqual(list(db.parent.glob("state.tmp.*")), [])
                    result = self.run_shell(shell, "TTY_SAFE=tty; record_state idle", env)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(db.read_text(), "keep unchanged\ntty idle 15 43000 \n")

    def test_rejects_linked_or_other_user_writable_parent(self):
        for shell in SHELLS:
            for kind in ("symlink", "writable"):
                with self.subTest(shell=shell, kind=kind):
                    root, env = self.fixture()
                    actual = root / "state"
                    (actual / "state").write_text("tty original\n")
                    if kind == "symlink":
                        link = root / "linked-state"
                        link.symlink_to(actual, target_is_directory=True)
                        env["TAVS_TMP_DIR"] = str(link)
                    else:
                        actual.chmod(0o777)
                    result = self.run_shell(shell, "TTY_SAFE=tty; record_state idle", env)
                    self.assertNotEqual(result.returncode, 0, result.stderr)
                    self.assertEqual((actual / "state").read_text(), "tty original\n")
                    self.assertFalse((actual / "state.lock").exists())

    def test_rejects_replaceable_or_other_uid_controlled_ancestor(self):
        for shell in SHELLS:
            for kind in ("writable", "other-owner"):
                with self.subTest(shell=shell, kind=kind):
                    root, env = self.fixture()
                    ancestor = root / "ancestor"
                    ancestor.mkdir(mode=0o700)
                    table_dir = ancestor / "tables"
                    table_dir.mkdir(mode=0o700)
                    db = table_dir / "state"
                    db.write_text("tty original\n")
                    env["TAVS_TMP_DIR"] = str(table_dir)
                    script = ""
                    if kind == "writable":
                        ancestor.chmod(0o777)
                    else:
                        env["UNTRUSTED_PARENT"] = str(ancestor.resolve())
                        script = '''
stat() {
    for arg in "$@"; do
        if [[ "$arg" == "$UNTRUSTED_PARENT" ]]; then
            printf '%s:700\\n' "$((EUID+1))"
            return 0
        fi
    done
    command stat "$@"
}
'''
                    result = self.run_shell(shell, script + "TTY_SAFE=tty; record_state idle", env)
                    self.assertNotEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(db.read_text(), "tty original\n")
                    self.assertFalse((table_dir / "state.lock").exists())

    def test_safe_physical_ancestors_and_sticky_parent_preserve_standard_aliases(self):
        for shell in SHELLS:
            for mode in (0o700, 0o1777):
                with self.subTest(shell=shell, parent_mode=oct(mode)):
                    root, env = self.fixture()
                    actual = root / "actual"
                    actual.mkdir(mode=mode)
                    actual.chmod(mode)
                    table_dir = actual / "tables"
                    table_dir.mkdir(mode=0o700)
                    alias = root / "alias"
                    alias.symlink_to(actual, target_is_directory=True)
                    env["TAVS_TMP_DIR"] = str(alias / "tables")
                    # Read permission is distinct from the write bits that permit replacement.
                    for name in ("state", "state.lock"):
                        (table_dir / name).touch(mode=0o604)
                        (table_dir / name).chmod(0o604)
                    result = self.run_shell(shell, "TTY_SAFE=tty; record_state idle", env)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual((table_dir / "state").read_text(), "tty idle 15 43000 \n")

    def test_rejects_unsafe_lock_or_table_without_mutating_destination(self):
        for shell in SHELLS:
            for leaf in ("state", "state.lock"):
                for kind in ("symlink", "fifo", "directory", "writable"):
                    with self.subTest(shell=shell, leaf=leaf, kind=kind):
                        root, env = self.fixture()
                        destination = root / "gates/untouched"
                        destination.write_text("private\n")
                        target = root / "state" / leaf
                        if kind == "symlink":
                            target.symlink_to(destination)
                        elif kind == "fifo":
                            os.mkfifo(target, 0o600)
                        elif kind == "directory":
                            target.mkdir()
                        else:
                            target.write_text("existing\n")
                            target.chmod(0o666)
                        result = self.run_shell(shell, "TTY_SAFE=tty; write_session_state permission", env)
                        self.assertNotEqual(result.returncode, 0, str(root))
                        self.assertEqual(destination.read_text(), "private\n")
                        self.assertEqual(list((root / "state").glob("state.tmp.*")), [])


if __name__ == "__main__":
    unittest.main()
