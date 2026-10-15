import errno
import os
from pathlib import Path
import select
import signal
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
    child_producer = True
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

    def test_residual_global_reset_precedes_current_style_and_retires_after_success(self):
        path = self.effect()
        self.assertTrue(self.render(style(title="fresh")))
        self.assertEqual(self.received(), b"\x1b]104\a\x1b]110\a\x1b]11;#123456\x1b\\\x1b]0;fresh\x1b\\")
        self.assertIsNone(records.read(self.store.directory, path, "effect", time.time(),
                                       time.monotonic_ns()+100_000_000))

    def test_fresh_palette_retires_canceled_global_before_later_reconcile(self):
        path = self.effect(active=False)
        fields = [""] * 23
        fields[0], fields[1], fields[2] = "#123456", "set", "#ABCDEF"
        fields[18], fields[19], fields[22] = "1", "fresh", "1"
        display = Render(("\0".join(fields) + "\0").encode())
        self.assertTrue(self.render(display))
        self.assertEqual(self.received(), b"\x1b]104\a\x1b]110\a" + display.encode(synthetic=False))
        self.assertIsNone(records.read(self.store.directory, path, "effect", time.time(),
                                       time.monotonic_ns()+100_000_000))
        self.assertTrue(Renderer(self.store).reconcile(self.tty, reset_legacy=False))
        self.assertEqual(self.received(), b"\x1b]11;#123456\x1b\\")

    def test_failed_legacy_retirement_keeps_debt_after_physical_bytes(self):
        path = self.effect(active=False)
        original_unlink = os.unlink
        def reject_retirement(name, *args, **kwargs):
            if name == path.name:
                raise OSError(errno.EACCES, "Injected retirement failure")
            return original_unlink(name, *args, **kwargs)
        with patch("portable_renderer.os.unlink", side_effect=reject_retirement):
            with self.assertRaises(OSError) as failure:
                self.render()
        self.assertEqual(failure.exception.errno, errno.EACCES)
        self.assertEqual(failure.exception.bytes_written, len(b"\x1b]104\a\x1b]110\a\x1b]11;#123456\x1b\\"))
        self.assertEqual(self.received(), b"\x1b]104\a\x1b]110\a\x1b]11;#123456\x1b\\")
        self.assertIsNotNone(records.read(self.store.directory, path, "effect", time.time(),
                                          time.monotonic_ns()+100_000_000))
        self.assertTrue(Renderer(self.store).reconcile(self.tty, reset_legacy=False))
        self.assertEqual(self.received(), b"\x1b]104\a\x1b]110\a\x1b]11;#123456\x1b\\")
        self.assertIsNone(records.read(self.store.directory, path, "effect", time.time(),
                                       time.monotonic_ns()+100_000_000))

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
            self.assertFalse(self.render())
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

    def test_forced_reset_after_actual_producer_exit_uses_bound_parent_lifetime(self):
        record = self.record()
        observation = {key: value for key, value in record.items() if key not in {"updatedAt", "background"}}
        observation.update(provider="claude", verifiedAgent=False, state="complete", observedAt=record["updatedAt"])
        path = self.store.directory / ("observation-"+key(self.tty)+".json")
        records.write(self.store.directory, path, observation, "observation", time.time(), time.monotonic_ns()+100_000_000)
        self.assertTrue(self.render(record=record))
        self.received()
        os.kill(self.producer_pid, signal.SIGTERM)
        until = time.monotonic() + 1
        while self.store.lookup(self.producer_pid) is not None and time.monotonic() < until:
            time.sleep(0.001)
        self.assertIsNone(self.store.lookup(self.producer_pid))
        reset = dict(record, background="reset", updatedAt=time.time())
        self.assertTrue(Renderer(self.store).forced_reset(reset, record["updatedAt"], ""))
        self.assertEqual(self.received(), b"\x1b]104\a\x1b]111\x1b\\\x1b]0;\x1b\\")

    def test_forced_reset_title_controls_are_rejected(self):
        with self.assertRaises(OSError):
            Renderer(self.store).forced_reset(self.record(), time.time(), "\x1b]11;red")

    def test_live_same_generation_on_other_device_cannot_use_orphan_authority(self):
        record = self.record()
        observation = {key: value for key, value in record.items() if key not in {"updatedAt", "background"}}
        observation.update(provider="claude", verifiedAgent=False, state="complete", observedAt=record["updatedAt"])
        path = self.store.directory / ("observation-"+key(self.tty)+".json")
        records.write(self.store.directory, path, observation, "observation", time.time(), time.monotonic_ns()+100_000_000)
        self.assertTrue(self.render(record=record))
        self.received()
        actual_lookup = self.store.lookup
        def moved_device(pid):
            value = actual_lookup(pid)
            if pid == self.producer_pid and value is not None:
                value = dict(value, device=record["device"]+1)
            return value
        self.store.lookup = moved_device
        with self.assertRaises(OSError):
            Renderer(self.store).forced_reset(dict(record, updatedAt=time.time()), record["updatedAt"], "")
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])

    def pending(self):
        path = self.runtime / "pending" / (self.tty.replace("/", "_") + ".osc")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"\x1b]0;historical title\a\a")
        return path

    def current_preview_revision(self, path):
        deadline = time.monotonic_ns() + 100_000_000
        revision = self.store.policy.capture(deadline)
        try:
            record = records.read(self.store.directory, path, "effect", time.time(), deadline)
            record["revision"] = dict(zip(("device", "inode"), revision.identity))
            records.write(self.store.directory, path, record, "effect", time.time(), deadline)
        finally:
            revision.close()

    def test_reconcile_restores_current_color_without_title_or_alert_replay(self):
        self.assertTrue(self.render(style(title="current title", bell=True)))
        self.received()
        pending = self.pending()
        self.assertTrue(Renderer(self.store).reconcile(self.tty, reset_legacy=False))
        self.assertEqual(self.received(), b"\x1b]11;#123456\x1b\\")
        self.assertFalse(pending.exists())

    def test_active_reconcile_resets_legacy_even_with_cancelled_global_record(self):
        self.assertTrue(self.render())
        self.received()
        self.effect(active=False)
        self.assertTrue(Renderer(self.store).reconcile(self.tty, reset_legacy=False))
        self.assertEqual(self.received(), b"\x1b]104\a\x1b]110\a\x1b]11;#123456\x1b\\")

    def test_suspended_reconcile_after_completed_recovery_does_not_repaint(self):
        self.assertTrue(self.render())
        self.received()
        self.effect(active=False)
        self.marker.write_bytes(Policy._marker(True))
        pending = self.pending()
        self.assertFalse(Renderer(self.store).reconcile(self.tty))
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])
        self.assertFalse(pending.exists())

    def test_suspended_residual_global_clears_defaults_once_without_theme_replay(self):
        path = self.effect()
        self.marker.write_bytes(Policy._marker(True))
        renderer = Renderer(self.store)
        self.assertTrue(renderer.reconcile(self.tty))
        self.assertEqual(self.received(), b"\x1b]104\a\x1b]110\a\x1b]111\a")
        self.assertIsNone(records.read(self.store.directory, path, "effect", time.time(),
                                       time.monotonic_ns()+100_000_000))
        self.assertFalse(renderer.reconcile(self.tty))
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])

    def test_suspended_preview_without_revision_clears_background_default(self):
        path = self.effect("preview")
        self.marker.write_bytes(Policy._marker(True))
        self.assertTrue(Renderer(self.store).reconcile(self.tty))
        self.assertEqual(self.received(), b"\x1b]111\x1b\\")
        self.assertFalse(records.read(self.store.directory, path, "effect", time.time(),
                                      time.monotonic_ns()+100_000_000)["active"])

    def test_suspended_current_live_preview_refuses_paint_and_invalidates_pending(self):
        self.marker.write_bytes(Policy._marker(True))
        path = self.effect("preview")
        self.current_preview_revision(path)
        pending = self.pending()
        with self.assertRaises(OSError) as failure:
            Renderer(self.store).reconcile(self.tty)
        self.assertEqual(failure.exception.errno, errno.EBUSY)
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])
        self.assertFalse(pending.exists())
        self.assertTrue(records.read(self.store.directory, path, "effect", time.time(),
                                     time.monotonic_ns()+100_000_000)["active"])

    def test_suspended_expired_current_preview_restores_latest_intent_once(self):
        self.assertTrue(self.render())
        self.received()
        self.marker.write_bytes(Policy._marker(True))
        path = self.effect("preview", age=3)
        self.current_preview_revision(path)
        renderer = Renderer(self.store)
        self.assertTrue(renderer.reconcile(self.tty))
        self.assertEqual(self.received(), b"\x1b]11;#123456\x1b\\")
        self.assertFalse(renderer.reconcile(self.tty))
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])

    def test_explicit_clear_releases_current_selective_control(self):
        self.assertTrue(self.render())
        self.received()
        path = self.effect("preview")
        self.assertTrue(Renderer(self.store).reconcile(self.tty, clear_selective=True))
        self.assertEqual(self.received(), b"\x1b]104\a\x1b]110\a\x1b]11;#123456\x1b\\")
        self.assertFalse(records.read(self.store.directory, path, "effect", time.time(),
                                      time.monotonic_ns()+100_000_000)["active"])

    def test_suspended_explicit_clear_of_current_preview_restores_ordinary_intent(self):
        self.assertTrue(self.render())
        self.received()
        self.marker.write_bytes(Policy._marker(True))
        path = self.effect("preview")
        self.current_preview_revision(path)
        self.assertTrue(Renderer(self.store).reconcile(self.tty, clear_selective=True))
        self.assertEqual(self.received(), b"\x1b]11;#123456\x1b\\")
        self.assertFalse(records.read(self.store.directory, path, "effect", time.time(),
                                      time.monotonic_ns()+100_000_000)["active"])

    def test_reconcile_queued_before_recovery_uses_after_open_suspension(self):
        self.assertTrue(self.render())
        self.received()
        pending = self.pending()
        original_open = os.open
        def recover_during_open(path, flags, *args, **kwargs):
            if str(path) == self.tty:
                self.marker.write_bytes(Policy._marker(True))
            return original_open(path, flags, *args, **kwargs)
        with patch("portable_device_writer.os.open", side_effect=recover_during_open):
            self.assertFalse(Renderer(self.store).reconcile(self.tty))
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])
        self.assertFalse(pending.exists())

    def test_reconcile_refuses_linked_pending_without_reading_or_cancelling(self):
        path = self.effect()
        pending = self.pending()
        saved = pending.with_name("saved-pending")
        pending.rename(saved)
        pending.symlink_to(saved)
        with self.assertRaises(OSError):
            Renderer(self.store).reconcile(self.tty)
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])
        self.assertTrue(saved.exists())
        self.assertTrue(pending.is_symlink())
        self.assertTrue(records.read(self.store.directory, path, "effect", time.time(),
                                     time.monotonic_ns()+100_000_000)["active"])

    def test_reconcile_failed_write_retains_cleanup_for_retry(self):
        path = self.effect()
        self.marker.write_bytes(Policy._marker(True))
        original_write = os.write
        def fail_device(fd, data):
            if os.isatty(fd):
                raise OSError(errno.EIO, "Injected reconcile-write failure")
            return original_write(fd, data)
        with patch("portable_device_writer.os.write", side_effect=fail_device):
            with self.assertRaises(OSError):
                Renderer(self.store).reconcile(self.tty)
        self.assertTrue(records.read(self.store.directory, path, "effect", time.time(),
                                     time.monotonic_ns()+100_000_000)["active"])
        self.assertTrue(Renderer(self.store).reconcile(self.tty))
        self.assertEqual(self.received(), b"\x1b]104\a\x1b]110\a\x1b]111\a")

    def test_reconcile_flags_require_actual_bools(self):
        with self.assertRaises(OSError) as failure:
            Renderer(self.store).reconcile(self.tty, reset_legacy=1)
        self.assertEqual(failure.exception.errno, errno.EINVAL)

    def test_current_global_rule_refuses_clear_without_cancelling_its_effect(self):
        path = self.effect()
        pending = self.pending()
        (self.runtime / "lock.state").write_text(
            'SCHEMA_VERSION="1"\nLOCKED="true"\nLOCK_UNTIL_EPOCH="%d"\n' % (int(time.time())+120))
        with self.assertRaises(OSError) as failure:
            Renderer(self.store).reconcile(self.tty, clear_selective=True)
        self.assertEqual(failure.exception.errno, errno.EBUSY)
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])
        self.assertTrue(pending.exists())
        self.assertTrue(records.read(self.store.directory, path, "effect", time.time(),
                                     time.monotonic_ns()+100_000_000)["active"])

    def test_ordinary_background_publication_keeps_its_native_context_boundary(self):
        record = self.record()
        path = self.store.directory / ("observation-"+key(self.tty)+".json")
        path.parent.mkdir(parents=True)
        path.write_bytes(b"invalid observation")
        record["background"] = "#123456"
        self.assertTrue(Renderer(self.store).background(record, False, record["updatedAt"]))
        self.assertEqual(self.received(), b"\x1b]11;#123456\x1b\\")
        with self.assertRaises(OSError):
            self.render(record=record)
        self.assertEqual(path.read_bytes(), b"invalid observation")

    def test_ordinary_background_reads_current_suspension_after_open_without_frozen_revision(self):
        record = dict(self.record(), background="#123456")
        original_open = os.open
        def recover(path, flags, *args, **kwargs):
            if str(path) == self.tty:
                replacement = self.root / "replacement"
                replacement.write_bytes(Policy._marker(True))
                replacement.replace(self.marker)
            return original_open(path, flags, *args, **kwargs)
        with patch("portable_device_writer.os.open", side_effect=recover):
            self.assertTrue(Renderer(self.store).background(record, False, record["updatedAt"]))
        self.assertEqual(self.received(), b"\x1b]11;#123456\x1b\\")

    def test_ordinary_background_disables_unavailable_marker_but_full_render_refuses(self):
        self.marker.write_bytes(b"unavailable suspension state")
        record = dict(self.record(), background="#123456")
        self.assertTrue(Renderer(self.store).background(record, False, record["updatedAt"]))
        self.assertEqual(self.received(), b"\x1b]11;#123456\x1b\\")
        with self.assertRaises(OSError):
            self.render(record=record)

    def test_recovery_during_background_composition_rejects_reconcile_paint(self):
        self.assertTrue(self.render())
        self.received()
        path = self.effect("preview", age=3)
        renderer = Renderer(self.store)
        original_background = renderer.intents.ordinary_background_unlocked
        def recover_during_background(target, deadline):
            result = original_background(target, deadline)
            replacement = self.root / "replacement"
            replacement.write_bytes(Policy._marker(True))
            replacement.replace(self.marker)
            return result
        with patch.object(renderer.intents, "ordinary_background_unlocked", side_effect=recover_during_background):
            with self.assertRaises(OSError) as failure:
                renderer.reconcile(self.tty)
        self.assertEqual(failure.exception.errno, errno.ESTALE)
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])
        self.assertTrue(records.read(self.store.directory, path, "effect", time.time(),
                                     time.monotonic_ns()+100_000_000)["active"])

    def test_reconcile_invalidates_only_current_tty_pending_slot(self):
        self.assertTrue(self.render())
        self.received()
        pending = self.pending()
        other = pending.with_name("_dev_ttys-other.osc")
        other.write_bytes(b"other owned pending")
        self.assertTrue(Renderer(self.store).reconcile(self.tty))
        self.assertEqual(self.received(), b"\x1b]104\a\x1b]110\a\x1b]11;#123456\x1b\\")
        self.assertFalse(pending.exists())
        self.assertEqual(other.read_bytes(), b"other owned pending")


if __name__ == "__main__":
    unittest.main()


class PortableLegacyCompletionTests(unittest.TestCase):
    """Format/lifecycle checks with injected identity, separate from real 100 ms PTY checks."""
    def setUp(self):
        self.fixture = ownership_fixture.PortableOwnershipTests()
        self.fixture.setUp()
        self.store = self.fixture.store
        self.renderer = Renderer(self.store)
        self.deadline = 2**63 - 1

    def test_canceled_global_owes_reset_until_completion_and_keeps_binding(self):
        path = self.fixture.save(self.fixture.target, "effect.json", kind="globalRestriction", active=False)
        revision = self.store.policy.capture(self.deadline)
        try:
            obsolete = self.store.ordinary_ownership(self.fixture.target, revision, 43, self.deadline)
        finally:
            revision.close()
        self.assertEqual([item[0] for item in obsolete], [path])
        self.renderer._complete_effects(obsolete, self.deadline)
        self.assertFalse(path.exists())
        self.assertIsNotNone(records.read(self.store.directory,
            target_path(self.store.directory, self.fixture.target, "target.json"),
            "target", 1000, self.deadline))

    def test_completion_keeps_replacement_global_and_selective_record(self):
        path = self.fixture.save(self.fixture.target, "effect.json", kind="globalRestriction", active=False)
        old = records.read(self.store.directory, path, "effect", 1000, self.deadline)
        replacement = dict(old, effectID="replacement-global")
        records.write(self.store.directory, path, replacement, "effect", 1000, self.deadline)
        with self.assertRaises(OSError) as failure:
            self.renderer._complete_effects([(path, old)], self.deadline)
        self.assertEqual(failure.exception.errno, errno.ESTALE)
        self.assertEqual(records.read(self.store.directory, path, "effect", 1000, self.deadline), replacement)
        selective = dict(replacement, kind="selectiveBackground", active=True)
        records.write(self.store.directory, path, selective, "effect", 1000, self.deadline)
        self.renderer._complete_effects([(path, selective)], self.deadline)
        self.assertEqual(records.read(self.store.directory, path, "effect", 1000, self.deadline),
                         dict(selective, active=False))
