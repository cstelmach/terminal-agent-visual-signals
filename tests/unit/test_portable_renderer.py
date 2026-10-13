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
from portable_render import Render
import portable_record_io as records
from portable_records import key, target_path
import test_portable_ownership as ownership_fixture


def style(background="#123456", title=None, bell=False):
    fields = [""] * 23
    fields[0] = background or ""
    fields[18] = "1" if title is not None else "0"
    fields[19] = title or ""
    fields[22] = "1" if bell else "0"
    return Render(("\0".join(fields) + "\0").encode())


@unittest.skipUnless(sys.platform == "darwin", "Native schema-1 owned process/PTY transaction")
class PortableRendererTests(ownership_fixture.OwnedPTYFixture, unittest.TestCase):
    def record(self):
        return {"schema": 1, "tty": self.tty, "device": self.store.device(self.tty),
                "producer": self.producer, "deliveryID": "delivery-43", "updatedAt": time.time(),
                "background": "reset"}

    def render(self, display=None, synthetic=False, record=None):
        record = self.record() if record is None else record
        return Renderer(self.store).render(display or style(), record, synthetic, record["updatedAt"])

    def effect(self, kind="globalRestriction", age=0, active=True):
        target = self.store.resolve(self.tty, self.producer, time.monotonic_ns() + 100_000_000)
        path = target_path(self.store.directory, target, "preview.json" if kind == "preview" else "effect.json")
        value = {"schema": 1, "target": target, "controller": self.producer, "effectID": "effect-43",
                 "kind": kind, "background": "#ABCDEF", "heartbeatAt": time.time() - age, "active": active}
        records.write(self.store.directory, path, value, "effect", time.time(), time.monotonic_ns()+100_000_000)
        return path

    def received(self):
        self.assertTrue(select.select([self.master], [], [], 1)[0])
        return os.read(self.master, 4096)

    def test_current_style_paints_and_retains_normalized_intent(self):
        self.assertTrue(self.render(style(title="current", bell=True)))
        self.assertEqual(self.received(), b"\x1b]11;#123456\x1b\\\x1b]0;current\x1b\\\a")
        path = self.store.directory / ("intent-" + key(self.tty) + ".json")
        latest = records.read(self.store.directory, path, "intent", time.time(), time.monotonic_ns()+100_000_000)
        self.assertEqual(latest["background"], "#123456")

    def test_open_failure_retains_before_open_intent_without_output(self):
        original_open = os.open
        def fail_device(path, flags, *args, **kwargs):
            if str(path) == self.tty:
                raise OSError(errno.EIO, "Injected device-open failure")
            return original_open(path, flags, *args, **kwargs)
        with patch("portable_device_writer.os.open", side_effect=fail_device):
            with self.assertRaises(OSError):
                self.render()
        path = self.store.directory / ("intent-" + key(self.tty) + ".json")
        self.assertEqual(records.read(self.store.directory, path, "intent", time.time(),
                                     time.monotonic_ns()+100_000_000)["background"], "#123456")
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])

    def test_live_preview_refuses_pixels_but_retains_latest_intent(self):
        path = self.effect("preview")
        with self.assertRaises(OSError) as failure:
            self.render()
        self.assertEqual(failure.exception.errno, errno.EBUSY)
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])
        self.assertTrue(records.read(self.store.directory, path, "effect", time.time(),
                                     time.monotonic_ns()+100_000_000)["active"])
        latest = self.store.directory / ("intent-"+key(self.tty)+".json")
        self.assertEqual(records.read(self.store.directory, latest, "intent", time.time(),
                                     time.monotonic_ns()+100_000_000)["background"], "#123456")

    def test_residual_global_reset_precedes_current_style_and_cancels_after_success(self):
        path = self.effect()
        self.assertTrue(self.render(style(title="fresh")))
        self.assertEqual(self.received(), b"\x1b]104\a\x1b]110\a\x1b]11;#123456\x1b\\\x1b]0;fresh\x1b\\")
        self.assertFalse(records.read(self.store.directory, path, "effect", time.time(),
                                      time.monotonic_ns()+100_000_000)["active"])

    def test_failed_output_keeps_residual_global_for_retry(self):
        path = self.effect()
        original_write = os.write
        def fail_device(fd, data):
            if os.isatty(fd):
                raise OSError(errno.EIO, "Injected device-write failure")
            return original_write(fd, data)
        with patch("portable_device_writer.os.write", side_effect=fail_device):
            with self.assertRaises(OSError):
                self.render()
        self.assertTrue(records.read(self.store.directory, path, "effect", time.time(),
                                     time.monotonic_ns()+100_000_000)["active"])
        self.assertTrue(self.render())
        self.assertTrue(self.received().startswith(b"\x1b]104\a\x1b]110\a"))

    def test_synthetic_style_preserves_occurrence_and_suppresses_alert(self):
        record = self.record()
        observation = {key: value for key, value in record.items() if key not in {"updatedAt", "background"}}
        observation.update(provider="claude", verifiedAgent=False, state="complete", observedAt=record["updatedAt"])
        path = self.store.directory / ("observation-"+key(self.tty)+".json")
        records.write(self.store.directory, path, observation, "observation", time.time(), time.monotonic_ns()+100_000_000)
        before = path.read_bytes()
        self.assertTrue(self.render(style(bell=True), synthetic=True, record=record))
        self.assertEqual(self.received(), b"\x1b]11;#123456\x1b\\")
        self.assertEqual(path.read_bytes(), before)

    def test_recovery_during_open_rejects_prepared_style(self):
        original_open = os.open
        def recover_during_open(path, flags, *args, **kwargs):
            if str(path) == self.tty:
                replacement = self.root / "replacement"
                replacement.write_bytes(Policy._marker(True))
                replacement.replace(self.marker)
            return original_open(path, flags, *args, **kwargs)
        with patch("portable_device_writer.os.open", side_effect=recover_during_open):
            with self.assertRaises(OSError) as failure:
                self.render()
        self.assertEqual(failure.exception.errno, errno.ESTALE)
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])

    def test_expired_preview_clears_to_latest_background_without_legacy_reset(self):
        self.assertTrue(self.render())
        self.received()
        path = self.effect("preview", age=3)
        self.assertTrue(self.render(style(background=None, title="fresh")))
        self.assertEqual(self.received(), b"\x1b]11;#123456\x1b\\\x1b]0;fresh\x1b\\")
        self.assertFalse(records.read(self.store.directory, path, "effect", time.time(),
                                      time.monotonic_ns()+100_000_000)["active"])

    def test_changed_effect_after_output_is_not_cancelled_and_reports_complete_bytes(self):
        path = self.effect()
        original_write = os.write
        def changed_after_output(fd, data):
            count = original_write(fd, data)
            if os.isatty(fd):
                current = records.read(self.store.directory, path, "effect", time.time(),
                                       time.monotonic_ns()+100_000_000)
                current["effectID"] = "new-effect"
                records.write(self.store.directory, path, current, "effect", time.time(),
                              time.monotonic_ns()+100_000_000)
            return count
        with patch("portable_device_writer.os.write", side_effect=changed_after_output):
            with self.assertRaises(OSError) as failure:
                self.render()
        expected = b"\x1b]104\a\x1b]110\a\x1b]11;#123456\x1b\\"
        self.assertEqual(failure.exception.errno, errno.ESTALE)
        self.assertEqual(failure.exception.bytes_written, len(expected))
        self.assertEqual(self.received(), expected)
        remaining = records.read(self.store.directory, path, "effect", time.time(),
                                 time.monotonic_ns()+100_000_000)
        self.assertEqual(remaining["effectID"], "new-effect")
        self.assertTrue(remaining["active"])


if __name__ == "__main__":
    unittest.main()
