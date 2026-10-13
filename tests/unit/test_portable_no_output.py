import errno
import os
from pathlib import Path
import select
import sys
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "src/core"))
from portable_renderer import Renderer
from portable_policy import Policy
from portable_records import key, target_path
import portable_record_io as records
import test_portable_ownership as fixture
from portable_process_identity import caller_ancestor, inspect


@unittest.skipUnless(sys.platform == "darwin", "Native schema-1 owned process/PTY operations")
class PortableNoOutputTests(fixture.OwnedPTYFixture, unittest.TestCase):
    child_producer = True

    def setUp(self):
        super().setUp()
        self.renderer = Renderer(self.store)
        self.target = self.store.resolve(self.tty, self.producer, self.deadline())
        self.target_path = target_path(self.store.directory, self.target, "target.json")

    def deadline(self):
        return time.monotonic_ns()+100_000_000

    def record(self):
        return {"schema": 1, "tty": self.tty, "device": self.store.device(self.tty),
                "producer": self.producer, "deliveryID": "delivery-43", "updatedAt": time.time(),
                "background": "reset"}

    def observation(self, record):
        value = {key: value for key, value in record.items() if key not in {"updatedAt", "background"}}
        value.update(provider="claude", verifiedAgent=False, state="complete", observedAt=record["updatedAt"])
        path = self.store.directory / ("observation-"+key(self.tty)+".json")
        records.write(self.store.directory, path, value, "observation", time.time(), self.deadline())
        return path

    def effect(self, kind="preview"):
        path = target_path(self.store.directory, self.target, "preview.json" if kind == "preview" else "effect.json")
        value = {"schema": 1, "target": self.target, "controller": self.producer, "effectID": "effect-43",
                 "kind": kind, "background": "#ABCDEF", "heartbeatAt": time.time(), "active": True}
        records.write(self.store.directory, path, value, "effect", time.time(), self.deadline())
        return path

    def no_bytes(self):
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])

    def native_effect(self, terminal):
        native = dict(self.target, nativeSurface={"application": inspect(os.getpid())["generation"],
                                                 "terminalID": terminal})
        path = target_path(self.store.directory, native, "preview.json")
        value = {"schema": 1, "target": native, "controller": self.producer, "effectID": "effect-43",
                 "kind": "preview", "background": "#ABCDEF", "heartbeatAt": time.time(), "active": True}
        records.write(self.store.directory, path, value, "effect", time.time(), self.deadline())
        return native, path

    def test_register_caches_current_target_without_policy_intent_or_pixels(self):
        self.marker.write_bytes(b"unavailable suspension state")
        self.assertFalse(self.renderer.register(self.tty, self.producer))
        self.no_bytes()
        saved = records.read(self.store.directory, self.target_path, "target", time.time(), self.deadline())
        self.assertEqual(saved, {"schema": 1, "target": self.target})
        self.assertFalse((self.store.directory / ("intent-"+key(self.tty)+".json")).exists())

    def test_register_preserves_current_preview(self):
        path = self.effect()
        before = path.read_bytes()
        self.assertFalse(self.renderer.register(self.tty, self.producer))
        self.no_bytes()
        self.assertEqual(path.read_bytes(), before)

    def test_current_without_rule_preserves_effects_and_pending_output(self):
        global_path, preview_path = self.effect("globalRestriction"), self.effect()
        before = [path.read_bytes() for path in (global_path, preview_path)]
        pending = self.runtime / "pending" / (self.tty.replace("/", "_")+".osc")
        pending.parent.mkdir(parents=True)
        pending.write_bytes(b"\a historical pending")
        self.assertFalse(self.renderer.current(self.tty, self.producer))
        self.no_bytes()
        self.assertTrue(self.target_path.exists())
        self.assertEqual([path.read_bytes() for path in (global_path, preview_path)], before)
        self.assertEqual(pending.read_bytes(), b"\a historical pending")

    def test_current_rule_is_unavailable_in_portable_backend_without_paint(self):
        path = self.effect("globalRestriction")
        before = path.read_bytes()
        (self.runtime / "lock.state").write_text('LOCKED="true"\nLOCK_UNTIL_EPOCH="%d"\n' % (int(time.time())+120))
        with self.assertRaises(OSError) as failure:
            self.renderer.current(self.tty, self.producer)
        self.assertEqual(failure.exception.errno, errno.EBUSY)
        self.no_bytes()
        self.assertEqual(path.read_bytes(), before)

    def test_current_unavailable_suspension_is_disabled_without_paint(self):
        self.marker.write_bytes(b"unavailable suspension state")
        self.assertFalse(self.renderer.current(self.tty, self.producer))
        self.no_bytes()

    def test_check_context_preserves_observation_without_caching_or_paint(self):
        record = self.record()
        path = self.observation(record)
        before = path.read_bytes()
        self.marker.write_bytes(b"unavailable suspension state")
        self.assertFalse(self.renderer.check_context(record, record["updatedAt"]))
        self.no_bytes()
        self.assertEqual(path.read_bytes(), before)
        self.assertFalse(self.target_path.exists())
        self.assertFalse((self.store.directory / ("intent-"+key(self.tty)+".json")).exists())

    def test_check_context_does_not_cancel_live_effects(self):
        record = self.record()
        self.observation(record)
        path = self.effect()
        before = path.read_bytes()
        self.assertFalse(self.renderer.check_context(record, record["updatedAt"]))
        self.no_bytes()
        self.assertEqual(path.read_bytes(), before)
        self.assertFalse(self.target_path.exists())

    def test_check_context_rejects_superseding_observation_without_publication(self):
        record = self.record()
        newer = dict(record, updatedAt=time.time(), deliveryID="newer")
        path = self.observation(newer)
        before = path.read_bytes()
        with self.assertRaises(OSError) as failure:
            self.renderer.check_context(record, record["updatedAt"])
        self.assertEqual(failure.exception.errno, errno.ESTALE)
        self.no_bytes()
        self.assertEqual(path.read_bytes(), before)
        self.assertFalse(self.target_path.exists())

    def test_open_failure_cannot_cache_register_target(self):
        original_open = os.open
        def fail_device(path, flags, *args, **kwargs):
            if str(path) == self.tty:
                raise OSError(errno.EIO, "Injected open failure")
            return original_open(path, flags, *args, **kwargs)
        with patch("portable_device_writer.os.open", side_effect=fail_device):
            with self.assertRaises(OSError):
                self.renderer.register(self.tty, self.producer)
        self.no_bytes()
        self.assertFalse(self.target_path.exists())

    def test_no_output_operations_still_require_opened_device_identity(self):
        self.store.descriptor_device = lambda fd: self.target["device"]+1
        with self.assertRaises(OSError):
            self.renderer.register(self.tty, self.producer)
        self.no_bytes()
        self.assertFalse(self.target_path.exists())

    def test_register_and_check_ignore_malformed_regular_effect_and_bound_data(self):
        path = self.effect()
        path.write_bytes(b"invalid effect")
        bound = target_path(self.store.directory, self.target, "bound-intent.json")
        bound.write_bytes(b"invalid bound intent")
        record = self.record()
        self.observation(record)
        self.assertFalse(self.renderer.check_context(record, record["updatedAt"]))
        self.assertFalse(self.target_path.exists())
        self.assertFalse(self.renderer.register(self.tty, self.producer))
        self.no_bytes()
        self.assertEqual(path.read_bytes(), b"invalid effect")
        self.assertEqual(bound.read_bytes(), b"invalid bound intent")

    def test_current_checks_effects_but_does_not_read_ordinary_bound_intent(self):
        path = self.effect()
        bound = target_path(self.store.directory, self.target, "bound-intent.json")
        bound.write_bytes(b"invalid bound intent")
        self.assertFalse(self.renderer.current(self.tty, self.producer))
        path.write_bytes(b"invalid effect")
        with self.assertRaises(OSError):
            self.renderer.current(self.tty, self.producer)
        self.no_bytes()
        self.assertEqual(bound.read_bytes(), b"invalid bound intent")

    def test_existing_target_cache_is_not_rewritten(self):
        self.assertFalse(self.renderer.register(self.tty, self.producer))
        old = self.target_path.stat()
        self.assertFalse(self.renderer.register(self.tty, self.producer))
        new = self.target_path.stat()
        self.assertEqual((old.st_dev, old.st_ino, old.st_mtime_ns), (new.st_dev, new.st_ino, new.st_mtime_ns))
        self.no_bytes()

    def test_valid_effect_only_native_alias_is_preferred_and_its_slot_is_checked(self):
        native, path = self.native_effect("pane-43")
        native_cache = target_path(self.store.directory, native, "target.json")
        self.assertFalse(self.renderer.register(self.tty, self.producer))
        self.assertTrue(native_cache.exists())
        self.assertFalse(self.target_path.exists())
        path.write_bytes(b"invalid native effect")
        with self.assertRaises(OSError):
            self.renderer.current(self.tty, self.producer)
        self.no_bytes()

    def test_ambiguous_effect_only_native_aliases_refuse_before_caching(self):
        self.native_effect("pane-one")
        self.native_effect("pane-two")
        record = self.record()
        self.observation(record)
        for operation in (lambda: self.renderer.register(self.tty, self.producer),
                          lambda: self.renderer.current(self.tty, self.producer),
                          lambda: self.renderer.check_context(record, record["updatedAt"])):
            with self.assertRaises(OSError) as failure:
                operation()
            self.assertEqual(failure.exception.errno, errno.EBUSY)
        self.no_bytes()
        self.assertFalse(self.target_path.exists())

    def test_live_owned_pty_child_is_not_a_helper_caller_ancestor(self):
        with self.assertRaises(OSError):
            caller_ancestor(self.producer_pid)
        self.no_bytes()
        self.assertFalse(self.target_path.exists())

    def test_unavailable_suspension_disables_current_without_reading_rule_fifo(self):
        self.marker.write_bytes(b"unavailable suspension state")
        self.runtime.mkdir(exist_ok=True)
        os.mkfifo(self.runtime / "lock.state")
        self.assertFalse(self.renderer.current(self.tty, self.producer))
        self.no_bytes()

    def test_active_suspension_policy_does_not_hide_rule_storage_failure(self):
        self.marker.write_bytes(Policy._marker(False))
        self.runtime.mkdir(exist_ok=True)
        os.mkfifo(self.runtime / "lock.state")
        with self.assertRaises(OSError):
            self.renderer.current(self.tty, self.producer)
        self.no_bytes()
        self.assertTrue(self.target_path.exists())


if __name__ == "__main__":
    unittest.main()
