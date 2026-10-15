import errno
import json
import os
from pathlib import Path
import pty
import select
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "src/core"))
import portable_helper as helper
import portable_metadata as metadata
from portable_context import encode_context, decode_context
from portable_records import StaleRecordError, generation_schema, key
import portable_record_io as records
import test_portable_ownership as fixture
from test_portable_records import linux_generation


def render_input(color="#123456"):
    fields = [""]*23
    fields[0], fields[18], fields[22] = color, "0", "0"
    return ("\0".join(fields)+"\0").encode()


class PortableHelperTests(unittest.TestCase):
    def test_distinct_ordinary_capability_claims_no_native_control_or_recovery(self):
        args = ["helper", "--validate-config", "--portable-ordinary-capabilities"]
        with patch("portable_helper.capture") as capture, patch("portable_helper.read_input") as read, \
                patch("portable_helper.inspect", return_value={"generation": fixture.generation(43)}):
            self.assertEqual(helper.run(args, self.environment), (0, b"tavs-portable-ordinary-schema=1\n", b""))
        capture.assert_not_called()
        read.assert_not_called()
        self.assertEqual(helper.run(args+["unexpected"], self.environment)[0], 1)
        self.assertEqual(helper.run([], self.environment)[0], 1)
        env = dict(self.environment, TAVS_SESSIONS_TEST_ROOT="")
        self.assertEqual(helper.run(args, env)[0], 1)
        with patch("portable_helper.sys.platform", "unsupported"):
            self.assertEqual(helper.run(args, self.environment)[0], 1)
        with patch("portable_helper.inspect", return_value=None):
            self.assertEqual(helper.run(args, self.environment)[0], 1)
        self.assertFalse(Path(self.runtime).exists())
        self.assertFalse(Path(self.marker).exists())

    def test_linux_capability_requires_current_scoped_identity(self):
        args = ["helper", "--validate-config", "--portable-ordinary-capabilities"]
        with patch("portable_helper.sys.platform", "linux"), \
                patch("portable_helper.inspect", return_value={"generation": linux_generation()}):
            self.assertEqual(helper.run(args, self.environment),
                             (0, b"tavs-portable-ordinary-schema=1\n", b""))
        with patch("portable_helper.sys.platform", "linux"), \
                patch("portable_helper.inspect", return_value={"generation": fixture.generation(43)}):
            self.assertEqual(helper.run(args, self.environment)[0], 1)
        self.assertFalse(Path(self.runtime).exists())

    def test_linux_dispatch_keeps_schema_two_and_avoids_darwin_temp_api(self):
        # Linux root admission uses /tmp, independent of the host runner's Darwin temp root.
        root = Path(tempfile.mkdtemp(prefix="helper-linux-", dir="/tmp"))
        environment = dict(self.environment, TAVS_TEST_ROOT=str(root), HOME=str(root / "home"),
                           TAVS_RUNTIME_DIR=str(root / "runtime"))
        marker, runtime = str(root / "home/.tavs/visual-restrictions.state"), str(root / "runtime")
        producer = linux_generation()
        context = dict(self.context, schema=2, producer=producer, device=123)
        token = encode_context(context, time.time())
        args = ["helper", "--managed-render", marker, runtime, "/dev/pts/43", token, "0"]
        with patch("portable_helper.sys.platform", "linux"), \
                patch("portable_helper.os.confstr", side_effect=AssertionError("Darwin-only API")), \
                patch("portable_helper.device_number", return_value=123), \
                patch("portable_helper.inspect", return_value={"generation": producer, "device": 123}), \
                patch("portable_helper.caller_ancestor", return_value=producer), \
                patch("portable_helper.read_input", return_value=render_input()), \
                patch("portable_helper.Renderer") as renderer:
            renderer.return_value.render.return_value = True
            self.assertEqual(helper.run(args, environment), (0, b"rendered\n", b""))
            record = renderer.return_value.render.call_args.args[1]
            self.assertEqual(record["schema"], 2)
            self.assertEqual(record["producer"], producer)
        native_token = encode_context(dict(self.context, producer=fixture.generation(43), device=123), time.time())
        with patch("portable_helper.sys.platform", "linux"), \
                patch("portable_helper.device_number", return_value=123), \
                patch("portable_helper.inspect") as inspect, \
                patch("portable_helper.Renderer") as renderer:
            self.assertEqual(helper.run(args[:5] + [native_token, "0"], environment),
                             (1, b"", b"Managed output unavailable. stage=context failure=value.\n"))
            inspect.assert_not_called()
            renderer.assert_not_called()
        self.assertFalse(Path(runtime).exists())
        self.assertFalse(Path(marker).exists())

    def setUp(self):
        # Native-format unit fixtures; real platform/process behavior has separate PTY classes.
        platform = patch("portable_helper.sys.platform", "darwin")
        platform.start(); self.addCleanup(platform.stop)
        temporary = patch("portable_helper.os.confstr", return_value=str(Path(os.environ["TAVS_TEST_ROOT"]).parent))
        temporary.start(); self.addCleanup(temporary.stop)
        self.root = Path(tempfile.mkdtemp(prefix="helper-", dir=os.environ["TAVS_TEST_ROOT"]))
        self.environment = dict(os.environ, HOME=str(self.root / "home"), TAVS_RUNTIME_DIR=str(self.root / "runtime"))
        self.marker = str(self.root / "home/.tavs/visual-restrictions.state")
        self.runtime = str(self.root / "runtime")
        self.context = {"schema": 1, "deliveryID": "delivery-43", "observedAt": time.time(),
                        "provider": "claude", "verifiedAgent": False}

    def test_unsupported_recovery_capabilities_and_counts_have_private_errors_without_mutation(self):
        requests = [["helper", "--visual-recover", self.marker, self.runtime, "recover"],
                    ["helper", "--validate-config", "--managed-output-capabilities"],
                    ["helper", "--organizer-context", "claude"],
                    ["helper", "--managed-render", self.marker, self.runtime, "/dev/tty", "private-token", "1", "extra"]]
        for args in requests:
            result = helper.run(args, self.environment)
            self.assertEqual(result[0], 1)
            self.assertEqual(result[1], b"")
            self.assertNotIn(b"private-token", result[2])
        self.assertFalse(Path(self.marker).exists())
        self.assertFalse(Path(self.runtime).exists())

    def test_scope_presence_even_empty_refuses_before_input_or_identity(self):
        for key in ("TAVS_SESSIONS_TEST_ROOT", "TAVS_SESSIONS_TEST_TARGETS", "TAVS_SESSIONS_TEST_FIXTURE"):
            env = dict(self.environment, **{key: ""})
            with patch("portable_helper.read_input") as read, patch("portable_helper.capture") as capture:
                result = helper.run(["helper", "--organizer-intake", "claude", str(os.getpid())], env)
            self.assertEqual(result[0], 1)
            read.assert_not_called()
            capture.assert_not_called()

    def test_managed_test_roots_cannot_escape_owned_directory(self):
        env = dict(self.environment, TAVS_TEST_ROOT=str(self.root))
        escaped = str(self.root.parent / "outside-marker")
        args = ["helper", "--managed-register", escaped, self.runtime, "/dev/ttys043", str(os.getpid())]
        with patch("portable_helper.device_number") as device:
            result = helper.run(args, env)
        self.assertEqual(result[0], 1)
        device.assert_not_called()
        self.assertFalse(Path(self.runtime).exists())

    def test_intake_uses_complete_fixed_order_and_keeps_body_out_of_context(self):
        payload = json.dumps({"session_id": "session-43", "hook_event_name": "Stop", "prompt": "private-body"}).encode()
        with patch("portable_helper.read_input", return_value=payload), patch("portable_helper.capture", return_value=self.context):
            result = helper.run(["helper", "--organizer-intake", "claude", str(os.getpid())], self.environment)
        self.assertEqual(result[0], 0)
        parts = result[1].split(b"\0")
        self.assertEqual(parts[::2][:-1], [b"TAVS_PERMISSION_MODE", b"TAVS_TRANSCRIPT_PATH", b"TAVS_SESSION_ID",
                                         b"TAVS_CWD", b"TAVS_ORGANIZER_CONTEXT", b"TAVS_ORGANIZER_INTAKE"])
        decoded = decode_context(parts[9].decode(), time.time())
        self.assertNotIn("private-body", str(decoded))
        self.assertEqual(parts[11], b"1")

    def test_bad_payload_does_not_emit_any_success_marker_or_exception_text(self):
        with patch("portable_helper.read_input", return_value=b'{"session_id": 43, "prompt":"private-body"}'):
            result = helper.run(["helper", "--organizer-intake", "claude", str(os.getpid())], self.environment)
        self.assertEqual(result, (1, b"", b"Organizer metadata unavailable.\n"))

    def test_managed_failure_reports_stage_and_bounded_errno_without_exception_text(self):
        args = ["helper", "--managed-register", self.marker, self.runtime, "/dev/ttys043", str(os.getpid())]
        private_error = type("BODY_SENTINEL", (ValueError,), {})
        for error, label in ((OSError(errno.EIO, "BODY_SENTINEL"), "os-5"),
                             (OSError(99999, "BODY_SENTINEL"), "os"),
                             (private_error("BODY_SENTINEL"), "value")):
            with patch("portable_helper.device_number", return_value=43), \
                    patch("portable_helper.caller_ancestor", return_value={}), \
                    patch("portable_helper.Renderer") as renderer:
                renderer.return_value.register.side_effect = error
                result = helper.run(args, self.environment)
            expected = ("Managed output unavailable. stage=write failure="+label+".\n").encode()
            self.assertEqual(result, (1, b"", expected))
        self.assertFalse(Path(self.runtime).exists())

    def test_managed_input_failure_reports_stage_without_payload_or_exception_text(self):
        producer = {"pid": 43, "startSeconds": 1, "startMicroseconds": 1}
        context = dict(self.context, producer=producer, device=43)
        args = ["helper", "--managed-render", self.marker, self.runtime, "/dev/ttys043",
                encode_context(context, time.time()), "1"]
        with patch("portable_helper.device_number", return_value=43), \
                patch("portable_helper.inspect", return_value={"generation": producer, "device": 43}), \
                patch("portable_helper.read_input", side_effect=ValueError("BODY_SENTINEL")):
            result = helper.run(args, self.environment)
        self.assertEqual(result, (1, b"", b"Managed output unavailable. stage=input failure=value.\n"))
        self.assertFalse(Path(self.runtime).exists())

    def test_invalid_provider_is_rejected_before_consuming_input(self):
        with patch("portable_helper.read_input") as read:
            result = helper.run(["helper", "--organizer-intake", "unsupported", str(os.getpid())], self.environment)
        self.assertEqual(result[0], 1)
        read.assert_not_called()

    def test_render_reader_rejects_delayed_eof_without_renewing_deadline(self):
        clock = {"now": 0, "waits": 0}
        def ready(read, write, errors, timeout):
            clock["waits"] += 1
            if clock["waits"] == 2:
                clock["now"] = 0.2
            return read, [], []
        with tempfile.TemporaryFile() as stream:
            stream.write(render_input())
            stream.seek(0)
            with patch("portable_metadata.sys.stdin", stream), \
                    patch("portable_metadata.time.monotonic", side_effect=lambda: clock["now"]), \
                    patch("portable_metadata.select.select", side_effect=ready):
                with self.assertRaises(ValueError):
                    metadata.read_input(limit=16_384, timeout=0.1, regular_or_pipe=True)

    def test_symlink_loop_root_failure_does_not_escape_private_error_boundary(self):
        loop = self.root / "loop"
        loop.symlink_to(loop)
        args = ["helper", "--managed-register", str(loop / "marker"), self.runtime,
                "/dev/ttys043", str(os.getpid())]
        result = helper.run(args, self.environment)
        self.assertEqual(result[:2], (1, b""))
        self.assertTrue(result[2].startswith(b"Managed output unavailable. stage=roots failure="))
        self.assertNotIn(str(loop).encode(), result[2])

    def test_observation_publication_remains_data_only_and_stale_has_code_three(self):
        token = encode_context(self.context, time.time())
        args = ["helper", "--organizer-observe", "/dev/ttys043", token, "complete"]
        self.assertEqual(helper.run(args, self.environment), (0, b"", b""))
        older = dict(self.context, observedAt=self.context["observedAt"]-1, deliveryID="older")
        args[3] = encode_context(older, time.time())
        self.assertEqual(helper.run(args, self.environment), (3, b"", b""))

    def test_organizer_intent_is_data_only_with_optional_identity_and_no_renderer(self):
        token = encode_context(self.context, time.time())
        args = ["helper", "--organizer-intent", "/dev/ttys043", token, "rgb:a/b/c", "0"]
        with patch("portable_helper.Renderer") as renderer:
            self.assertEqual(helper.run(args, self.environment), (0, b"", b""))
        renderer.assert_not_called()
        directory = Path(self.runtime) / "organizer"
        value = json.loads((directory / ("intent-"+key(args[2])+".json")).read_bytes())
        self.assertEqual(value["background"], "#AABBCC")
        self.assertNotIn("producer", value)
        self.assertFalse((directory / "targets").exists())

    def test_organizer_intent_synthetic_mismatch_is_silent_stale_and_bad_flag_is_unavailable(self):
        token = encode_context(self.context, time.time())
        args = ["helper", "--organizer-intent", "/dev/ttys043", token, "reset", "1"]
        self.assertEqual(helper.run(args, self.environment), (3, b"", b""))
        args[5] = "true"
        self.assertEqual(helper.run(args, self.environment), (1, b"", b"Organizer metadata unavailable.\n"))


    def test_dispatch_does_not_classify_generic_target_estale_as_stale_data(self):
        producer = {"pid": 43, "startSeconds": 100, "startMicroseconds": 0}
        value = dict(self.context, producer=producer, device=123)
        token = encode_context(value, time.time())
        args = ["helper", "--managed-render", self.marker, self.runtime, "/dev/ttys043", token, "1"]
        for error, code in ((OSError(errno.ESTALE, "private-path target changed"), 1),
                            (StaleRecordError("private-token data changed"), 3)):
            with patch("portable_helper.device_number", return_value=123), \
                    patch("portable_helper.inspect", return_value={"generation": producer, "device": 123}), \
                    patch("portable_helper.read_input", return_value=render_input()), \
                    patch("portable_helper.Renderer") as renderer:
                renderer.return_value.render.side_effect = error
                result = helper.run(args, self.environment)
            self.assertEqual(result[0], code)
            self.assertEqual(result[1], b"")
            self.assertNotIn(b"private-", result[2])


@unittest.skipUnless(sys.platform == "darwin", "Owned macOS hook routing acceptance")
class PortableHookRoutingTests(unittest.TestCase):
    def test_missing_native_helper_routes_real_hook_intake_and_render_to_owned_pty(self):
        root = Path(tempfile.mkdtemp(prefix="hook-routing-", dir=os.environ["TAVS_TEST_ROOT"]))
        (root / "home/.tavs").mkdir(parents=True)
        core = Path(__file__).resolve().parents[2] / "src/core/organizer-state.sh"
        env = dict(os.environ, HOME=str(root / "home"), TAVS_RUNTIME_DIR=str(root / "runtime"),
                   TAVS_TEST_HELPER_BIN=str(root / "missing-native"), TAVS_AGENT="claude")
        data = self.owned_shell(["/bin/bash", "-c", '''
set -e
source "$1"
_tavs_organizer_intake claude "$$" <<< '{"hook_event_name":"Stop","session_id":"hook-43","prompt":"BODY_SENTINEL"}'
[[ "$_TAVS_HELPER_BACKEND" == portable ]]
_tavs_organizer_begin complete
_tavs_render_begin
_tavs_render_queue background '#123456'
_tavs_render_flush
''', "_", str(core)], env)
        self.assertEqual(data, b"\x1b]11;#123456\x1b\\")
        directory = root / "runtime/organizer"
        observation = json.loads(next(directory.glob("observation-*.json")).read_bytes())
        intent = json.loads(next(directory.glob("intent-*.json")).read_bytes())
        self.assertEqual(observation["deliveryID"], intent["deliveryID"])
        self.assertFalse(observation["verifiedAgent"])
        self.assertNotIn("BODY_SENTINEL", str(observation)+str(intent))
        self.assertFalse((root / "home/.tavs/visual-restrictions.state").exists())

    def test_installed_shell_startup_registers_owned_pty_without_checkout_in_bash_and_zsh(self):
        repo = Path(__file__).resolve().parents[2]
        shells = ("/bin/bash", "/bin/zsh") if sys.platform == "darwin" else tuple(
            shell for shell in ("/bin/bash", "/bin/zsh") if Path(shell).is_file())
        self.assertIn("/bin/bash", shells)
        cases = [(False, "portable"), (True, "portable")]
        if sys.platform == "darwin":
            cases += [(False, "native"), (True, "native")]
        for shell in shells:
            for suspended, backend in cases:
                with self.subTest(shell=shell, suspended=suspended, backend=backend):
                    root = Path(tempfile.mkdtemp(prefix="shell-startup-", dir=os.environ["TAVS_TEST_ROOT"]))
                    (root / "home/.tavs").mkdir(parents=True)
                    env = dict(os.environ, HOME=str(root / "home"), ZDOTDIR=str(root / "home"),
                               CFFIXED_USER_HOME=str(root / "home"),
                               TAVS_RUNTIME_DIR=str(root / "runtime"),
                               SHELLRC_EXPECTED_BACKEND=backend,
                               TAVS_TEST_HELPER_BIN=(os.environ["TAVS_TEST_HELPER_BIN"]
                                                    if backend == "native" else str(root / "missing-native")))
                    marker = root / "home/.tavs/visual-restrictions.state"
                    if suspended:
                        marker.write_bytes(b'SCHEMA_VERSION="1"\nSUSPENDED="true"\n')
                    install = subprocess.run(["/bin/bash", str(repo / "tavs"), "install", "shell-integration"],
                                             env=env, capture_output=True, timeout=5)
                    self.assertEqual(install.returncode, 0, install.stderr)
                    env["TAVS_ROOT"] = str(root / "missing-checkout")
                    flags = ["--norc", "-ic"] if shell == "/bin/bash" else ["-fic"]
                    data = self.owned_shell([shell, *flags, '''
source "$HOME/.tavs/shellrc"
[[ "$_TAVS_HELPER_BACKEND" == "$SHELLRC_EXPECTED_BACKEND" ]] || exit 43
printf '%s' "$TTY_DEVICE" > "$HOME/registered-tty"
'''], env)
                    self.assertEqual(data, b"")
                    directory = root / "runtime/organizer/targets"
                    targets = list(directory.glob("**/target.json"))
                    self.assertEqual(len(targets), 1)
                    target = json.loads(targets[0].read_bytes())["target"]
                    self.assertEqual(target["tty"], (root / "home/registered-tty").read_text())
                    self.assertFalse((root / "runtime/active-ttys").exists())
                    self.assertFalse((root / "runtime/organizer" / ("intent-"+key(target["tty"])+".json")).exists())
                    if suspended:
                        self.assertEqual(marker.read_bytes(), b'SCHEMA_VERSION="1"\nSUSPENDED="true"\n')
                    else:
                        self.assertFalse(marker.exists())

    def owned_shell(self, args, env):
        actor, master = pty.fork()
        if actor == 0:
            env["TTY_DEVICE"] = os.ttyname(0)
            os.execve(args[0], args, env)
        data = bytearray()
        deadline = time.monotonic() + 5
        status = None
        try:
            while time.monotonic() < deadline:
                if select.select([master], [], [], 0.02)[0]:
                    try:
                        data.extend(os.read(master, 4096))
                    except OSError as error:
                        if error.errno != errno.EIO:
                            raise
                waited, value = os.waitpid(actor, os.WNOHANG)
                if waited:
                    status = value
                    break
            self.assertIsNotNone(status, "Owned hook shell did not finish")
            self.assertEqual(os.waitstatus_to_exitcode(status), 0, data)
            return bytes(data)
        finally:
            if status is None:
                os.kill(actor, signal.SIGKILL)
                os.waitpid(actor, 0)
            os.close(master)


@unittest.skipUnless(sys.platform == "darwin", "Owned macOS helper/device acceptance")
class PortableHelperPTYTests(fixture.OwnedPTYFixture, unittest.TestCase):
    child_producer = True

    def setUp(self):
        super().setUp()
        self.helper_path = Path(__file__).resolve().parents[2] / "src/core/portable_helper.py"
        self.context = {"schema": generation_schema(self.producer), "deliveryID": "delivery-43", "observedAt": time.time(),
                        "provider": "claude", "verifiedAgent": False, "device": self.store.device(self.tty),
                        "producer": self.producer, "event": "Stop"}
        self.token = encode_context(self.context, time.time())
        self.env = dict(os.environ, TAVS_RUNTIME_DIR=str(self.runtime))

    def observe(self, **changes):
        value = dict(self.context, tty=self.tty, state="complete", **changes)
        path = self.store.directory / ("observation-"+key(self.tty)+".json")
        records.write(self.store.directory, path, value, "observation", time.time(), time.monotonic_ns()+100_000_000)
        return path

    def invoke(self, verb="--managed-render", tail=None, input=render_input()):
        tail = [self.token, "1"] if tail is None else tail
        return subprocess.run([sys.executable, str(self.helper_path), verb, str(self.marker), str(self.runtime),
                               self.tty, *tail], input=input, env=self.env, capture_output=True, timeout=3)

    def test_synthetic_render_is_exact_and_unrelated_ordinary_caller_never_switches_mode(self):
        self.observe()
        failed = self.invoke(tail=[self.token, "0"])
        self.assertEqual(failed.returncode, 1)
        self.assertEqual(failed.stdout, b"")
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])
        self.assertFalse((self.store.directory / ("intent-"+key(self.tty)+".json")).exists())
        rendered = self.invoke()
        self.assertEqual((rendered.returncode, rendered.stdout, rendered.stderr), (0, b"rendered\n", b""))
        self.assertTrue(select.select([self.master], [], [], 1)[0])
        self.assertEqual(os.read(self.master, 4096), b"\x1b]11;#123456\x1b\\")

    def test_stale_observation_and_record_type_keep_code_three_without_pixels(self):
        self.observe(deliveryID="other-delivery")
        failed = self.invoke(verb="--managed-check-context", tail=[self.token], input=b"")
        self.assertEqual((failed.returncode, failed.stdout, failed.stderr),
                         (3, b"", b"Managed output stale.\n"))
        path = self.store.directory / ("observation-"+key(self.tty)+".json")
        path.rename(path.with_name("saved-observation"))
        os.mkfifo(path)
        failed = self.invoke(verb="--managed-check-context", tail=[self.token], input=b"")
        self.assertEqual(failed.returncode, 3)
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])

    def test_marker_change_queued_during_open_returns_unaffected_without_pixels(self):
        self.observe()
        original_open = os.open
        def recover(path, flags, *args, **kwargs):
            if str(path) == self.tty:
                replacement = self.root / "replacement"
                replacement.write_bytes(b'SCHEMA_VERSION="1"\nSUSPENDED="true"\n')
                replacement.replace(self.marker)
            return original_open(path, flags, *args, **kwargs)
        args = ["helper", "--managed-render", str(self.marker), str(self.runtime), self.tty, self.token, "1"]
        with patch("portable_helper.read_input", return_value=render_input()), patch("portable_device_writer.os.open", side_effect=recover):
            self.assertEqual(helper.run(args, self.env), (0, b"unaffected\n", b""))
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])

    def test_render_input_without_eof_times_out_before_intent_or_device_output(self):
        self.observe()
        args = [sys.executable, str(self.helper_path), "--managed-render", str(self.marker), str(self.runtime),
                self.tty, self.token, "1"]
        process = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, env=self.env)
        try:
            process.stdin.write(render_input())
            process.stdin.flush()
            process.wait(timeout=1)
            self.assertEqual(process.returncode, 1)
            self.assertEqual(process.stdout.read(), b"")
            self.assertEqual(process.stderr.read(), b"Managed output unavailable. stage=input failure=value.\n")
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=1)
            process.stdin.close()
            process.stdout.close()
            process.stderr.close()
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])
        self.assertFalse((self.store.directory / ("intent-"+key(self.tty)+".json")).exists())

    def test_render_input_rejects_oversize_and_character_device_without_consuming_it(self):
        self.observe()
        failed = self.invoke(input=b"x"*16_385)
        self.assertEqual(failed.returncode, 1)
        args = [sys.executable, str(self.helper_path), "--managed-render", str(self.marker), str(self.runtime),
                self.tty, self.token, "1"]
        failed = subprocess.run(args, stdin=self.master, env=self.env, capture_output=True, timeout=3)
        self.assertEqual(failed.returncode, 1)
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])
        self.assertFalse((self.store.directory / ("intent-"+key(self.tty)+".json")).exists())

    def test_owned_synthetic_unbound_intent_changes_data_without_device_output_or_target(self):
        self.observe()
        args = [sys.executable, str(self.helper_path), "--organizer-intent", self.tty, self.token, "#123456", "1"]
        result = subprocess.run(args, env=self.env, capture_output=True, timeout=3)
        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, b"", b""))
        saved = json.loads((self.store.directory / ("intent-"+key(self.tty)+".json")).read_bytes())
        self.assertEqual(saved["deliveryID"], self.context["deliveryID"])
        self.assertEqual(saved["background"], "#123456")
        self.assertFalse((self.store.directory / "targets").exists())
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])


class LinuxPortableHelperPTYTests(PortableHelperPTYTests):
    __unittest_skip__ = sys.platform != "linux"
    __unittest_skip_why__ = "Requires a real Linux kernel and owned PTY"


class LinuxPortableHookRoutingTests(PortableHookRoutingTests):
    __unittest_skip__ = sys.platform != "linux"
    __unittest_skip_why__ = "Requires real Linux standalone helper and hook routing"


if __name__ == "__main__":
    unittest.main()
