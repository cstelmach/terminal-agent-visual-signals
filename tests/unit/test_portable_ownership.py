import errno
import json
import os
from pathlib import Path
import pty
import select
import signal
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "src/core"))
from portable_ownership import Store
from portable_policy import Policy
from portable_records import key, read_record, target_path
import portable_device_writer as writer
from portable_process_identity import inspect


def generation(pid, seconds=100):
    return {"pid": pid, "startSeconds": seconds, "startMicroseconds": 0}


class PortableOwnershipTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix="ownership-", dir=os.environ["TAVS_TEST_ROOT"]))
        self.runtime = self.root / "runtime"
        self.marker = self.root / "home/visual-restrictions.state"
        self.marker.parent.mkdir()
        self.policy = Policy(self.marker, self.runtime, clock=lambda: 1000)
        self.tty = "/dev/ttys043"
        self.producer, self.owner, self.app, self.controller = (generation(p) for p in (43, 100, 90, 80))
        self.identities = {p: {"generation": generation(p), "parentPID": 100 if p == 43 else 1,
                               "device": 123, "group": p, "foregroundGroup": 43}
                           for p in (43, 100, 90, 80, 101)}
        self.missing = set()
        self.store = Store(self.runtime, self.policy, lookup=self.identities.get,
                           process_missing=lambda p: p in self.missing, device=lambda path: 123,
                           descriptor_device=lambda fd: 123, clock=lambda: 1000)
        self.target = {"tty": self.tty, "device": 123, "ttyOwner": self.owner}

    def deadline(self):
        return time.monotonic_ns() + 100_000_000

    def native(self, terminal):
        return dict(self.target, nativeSurface={"application": self.app, "terminalID": terminal})

    def save(self, target, filename="target.json", **changes):
        if filename == "target.json":
            record = {"schema": 1, "target": target}
        else:
            record = {"schema": 1, "target": target, "controller": self.controller,
                      "kind": "preview" if filename == "preview.json" else "selectiveBackground",
                      "effectID": "effect-43", "background": "#123456", "heartbeatAt": 999,
                      "active": True}
            record.update(changes)
        path = target_path(self.store.directory, target, filename)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(record))
        return path

    def admit(self):
        revision = self.policy.capture(self.deadline())
        try:
            return self.store.ordinary_ownership(self.target, revision, 43, self.deadline())
        finally:
            revision.close()

    def test_resolve_plain_or_one_native_alias_using_exact_lifetime(self):
        self.assertEqual(self.store.resolve(self.tty, self.producer, self.deadline()), self.target)
        self.save(self.target)
        native = self.native("pane-43")
        self.save(native)
        self.assertEqual(self.store.resolve(self.tty, self.producer, self.deadline()), native)
        self.assertEqual(len(self.admit()), 0)

    def test_effect_only_other_live_owner_and_duplicate_native_aliases_reject(self):
        other = dict(self.target, ttyOwner=generation(101))
        self.save(other, "effect.json")
        with self.assertRaises(OSError):
            self.store.resolve(self.tty, self.producer, self.deadline())
        self.identities[101]["generation"] = generation(101, 200)
        self.save(self.native("one"))
        self.save(self.native("two"))
        with self.assertRaises(OSError):
            self.store.resolve(self.tty, self.producer, self.deadline())

    def test_closed_lifetime_is_distinct_from_unknown_or_reused_identity(self):
        other = dict(self.target, ttyOwner=generation(101))
        self.save(other)
        self.identities.pop(101)
        with self.assertRaises(OSError):
            self.store.resolve(self.tty, self.producer, self.deadline())
        self.missing.add(101)
        self.assertEqual(self.store.resolve(self.tty, self.producer, self.deadline()), self.target)
        self.identities[100]["generation"] = generation(100, 200)
        with self.assertRaises(OSError):
            self.admit()

    def test_bad_record_path_symlink_and_effect_slot_cannot_authorize_output(self):
        path = self.save(self.target)
        path.rename(path.parent / "preview.json")
        with self.assertRaises(OSError):
            self.admit()
        path.parent.rename(path.parent.with_name("wrong"))
        with self.assertRaises(OSError):
            self.store.resolve(self.tty, self.producer, self.deadline())

    def test_unrelated_tty_bucket_does_not_block_but_links_in_current_bucket_do(self):
        unrelated = self.store.directory / "targets/another-tty"
        unrelated.mkdir(parents=True)
        (unrelated / "invalid.json").write_text('not a record')
        self.assertEqual(self.store.resolve(self.tty, self.producer, self.deadline()), self.target)
        path = self.save(self.target)
        (path.parent / "link").symlink_to(self.root)
        with self.assertRaises(OSError):
            self.admit()

    def test_current_preview_or_focus_ownership_refuses_ordinary_paint(self):
        self.save(self.target, "preview.json")
        with self.assertRaises(OSError) as failure:
            self.admit()
        self.assertEqual(failure.exception.errno, errno.EBUSY)
        self.save(self.target, "preview.json", heartbeatAt=998)
        self.assertEqual(len(self.admit()), 1)
        self.save(self.target, "effect.json", heartbeatAt=994)
        with self.assertRaises(OSError):
            self.admit()
        self.save(self.target, "effect.json", heartbeatAt=993.999)
        self.assertEqual(len(self.admit()), 2)

    def test_unknown_recent_controller_refuses_but_proven_dead_or_expired_releases(self):
        self.save(self.target, "preview.json")
        self.identities.pop(80)
        with self.assertRaises(OSError):
            self.admit()
        self.missing.add(80)
        self.assertEqual(len(self.admit()), 1)
        self.missing.clear()
        self.save(self.target, "preview.json", heartbeatAt=998)
        self.assertEqual(len(self.admit()), 1)

    def test_recovery_revisions_and_disabled_selective_effects(self):
        self.save(self.target, "effect.json")
        self.marker.write_bytes(Policy._marker(True))
        self.assertEqual(len(self.admit()), 1)
        self.save(self.target, "preview.json", revision={"device": 0, "inode": 0})
        self.assertEqual(len(self.admit()), 2)
        revision = self.policy.capture(self.deadline())
        replacement = self.root / "replacement"
        replacement.write_bytes(self.marker.read_bytes())
        replacement.replace(self.marker)
        try:
            with self.assertRaises(OSError):
                self.store.ordinary_ownership(self.target, revision, 43, self.deadline())
        finally:
            revision.close()

    def test_global_rule_and_exact_descriptor_revalidation_precede_output(self):
        self.runtime.mkdir(parents=True, exist_ok=True)
        (self.runtime / "lock.state").write_text('LOCKED="true"\nLOCK_UNTIL_EPOCH="2000"\n')
        with self.assertRaises(OSError) as failure:
            self.admit()
        self.assertEqual(failure.exception.errno, errno.EBUSY)
        self.marker.write_bytes(Policy._marker(True))
        self.store.descriptor_device = lambda fd: 456
        with self.assertRaises(OSError):
            self.admit()

    def test_known_missing_device_and_unknown_device_have_distinct_status(self):
        self.store.device = lambda path: None
        self.store.device_missing = lambda path: False
        self.assertEqual(self.store.status(self.target, self.deadline()), "unavailable")
        self.store.device_missing = lambda path: True
        self.assertEqual(self.store.status(self.target, self.deadline()), "vanished")

    def test_known_native_exit_classifies_alias_before_unknown_owner_metadata(self):
        self.identities.pop(100)
        self.identities.pop(90)
        self.missing.add(90)
        self.assertEqual(self.store.status(self.native("closed"), self.deadline()), "vanished")
        self.assertEqual(self.store.status(self.target, self.deadline()), "unavailable")

    def test_cached_target_cannot_invent_an_unbound_lifetime(self):
        with self.assertRaises(OSError):
            self.store.cached_target(self.tty, self.deadline())
        self.save(self.target)
        self.assertEqual(self.store.cached_target(self.tty, self.deadline()), self.target)
        native = self.native("pane-43")
        self.save(native)
        self.assertEqual(self.store.cached_target(self.tty, self.deadline()), native)
        self.save(self.native("other-pane"))
        with self.assertRaises(OSError):
            self.store.cached_target(self.tty, self.deadline())

    def test_residual_global_is_not_a_lease_and_canceled_corruption_is_still_rejected(self):
        path = self.save(self.target, "effect.json", kind="globalRestriction")
        self.identities.pop(80)
        self.assertEqual(len(self.admit()), 1)
        self.save(self.target, "effect.json", kind="globalRestriction", active=False)
        self.assertEqual(len(self.admit()), 1)
        record = json.loads(path.read_text())
        record["unknown"] = "data"
        path.write_text(json.dumps(record))
        with self.assertRaises(OSError):
            self.admit()

    def test_transient_directory_replacement_cannot_hide_an_active_preview(self):
        path = self.save(self.target, "preview.json")
        original = path.parent
        foreign = json.loads(path.read_text())
        foreign["active"] = False
        def replacement_read(filename, kind, now, deadline, **kwargs):
            if kind != "effect":
                return read_record(filename, kind, now, deadline, **kwargs)
            original.rename(self.root / "saved")
            original.mkdir()
            (original / filename).write_text(json.dumps(foreign))
            try:
                return read_record(filename, kind, now, deadline, **kwargs)
            finally:
                original.rename(self.root / "unused")
                (self.root / "saved").rename(original)
        with patch("portable_ownership.read_record", side_effect=replacement_read):
            with self.assertRaises(OSError) as failure:
                self.admit()
            self.assertEqual(failure.exception.errno, errno.EBUSY)


class OwnedPTYFixture:
    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix="ownership-pty-", dir=os.environ["TAVS_TEST_ROOT"]))
        self.actor, self.master = pty.fork()
        if self.actor == 0:
            try:
                if getattr(self, "child_producer", False):
                    child = os.fork()
                    if child == 0:
                        try:
                            os.read(0, 1)
                        finally:
                            os._exit(0)
                    (self.root / "producer-pid").write_text(str(child))
                    def retire_child(signum, frame):
                        os.kill(child, signal.SIGTERM)
                        os.waitpid(child, 0)
                        os._exit(0)
                    signal.signal(signal.SIGTERM, retire_child)
                os.write(1, (os.ttyname(0) + "\n").encode())
                os.read(0, 1)
            finally:
                os._exit(0)
        self.addCleanup(self.retire)
        data = bytearray()
        deadline = time.monotonic() + 2
        while b"\n" not in data:
            left = max(0, deadline - time.monotonic())
            self.assertTrue(select.select([self.master], [], [], left)[0])
            data.extend(os.read(self.master, 256))
        self.tty = data.decode().strip()
        self.producer_pid = int((self.root / "producer-pid").read_text()) if getattr(self, "child_producer", False) else self.actor
        self.producer = inspect(self.producer_pid)["generation"]
        self.runtime = self.root / "runtime"
        self.marker = self.root / "home/visual-restrictions.state"
        self.marker.parent.mkdir()
        self.policy = Policy(self.marker, self.runtime)
        self.store = Store(self.runtime, self.policy)

    def retire(self):
        until = time.monotonic() + 1
        while writer._children and time.monotonic() < until:
            writer.reap_completed()
            time.sleep(0.001)
        self.assertFalse(writer._children, "Owned device writer did not retire")
        if os.waitpid(self.actor, os.WNOHANG)[0] == 0:
            os.kill(self.actor, signal.SIGTERM)
            os.waitpid(self.actor, 0)
        os.close(self.master)

@unittest.skipUnless(sys.platform == "darwin", "Native schema-1 owned process/PTY acceptance")
class PortableOwnershipPTYTests(OwnedPTYFixture, unittest.TestCase):
    def write(self, recover=False):
        context = {}
        def before_open(deadline):
            context["revision"] = self.policy.capture(deadline)
            context["target"] = self.store.resolve(self.tty, self.producer, deadline)
            if recover:
                replacement = self.root / "replacement"
                replacement.write_bytes(Policy._marker(True))
                replacement.replace(self.marker)
        def prepare(fd, deadline):
            obsolete = self.store.ordinary_ownership(context["target"], context["revision"], fd, deadline)
            if obsolete:
                raise OSError(errno.EBUSY, "Uncleared managed effects")
            return b"\x1b]11;#123456\x1b\\"
        lock = self.store.directory / ("writer-" + key(self.tty) + ".lock")
        return writer.write_managed(self.tty, lock, before_open, prepare)

    def test_actual_process_identity_and_device_allow_only_current_owned_output(self):
        self.assertTrue(self.write())
        self.assertTrue(select.select([self.master], [], [], 1)[0])
        self.assertEqual(os.read(self.master, 1024), b"\x1b]11;#123456\x1b\\")

    def test_recovery_between_capture_and_device_open_prevents_output(self):
        with self.assertRaises(OSError) as failure:
            self.write(recover=True)
        self.assertEqual(failure.exception.errno, errno.ESTALE)
        self.assertFalse(select.select([self.master], [], [], 0.15)[0])


if __name__ == "__main__":
    unittest.main()
