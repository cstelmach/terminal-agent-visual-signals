import errno
import json
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "src/core"))
from portable_intent import Intents
from portable_ownership import Store
from portable_policy import Policy
import portable_record_io as records
from portable_records import StaleRecordError, key, target_path


class PortableIntentTests(unittest.TestCase):
    def test_ordinary_provider_synthetic_updates_keep_observation_and_reject_supersession(self):
        for provider in ("gemini", "opencode", "unknown"):
            with self.subTest(provider=provider):
                self.observe(provider=provider, event=None)
                original = self.observation_path.read_bytes()
                result = self.publish(synthetic=True)
                self.assertEqual(result["background"], "#112233")
                self.assertEqual(self.observation_path.read_bytes(), original)
                self.observe(provider=provider, event=None, deliveryID="replacement", observedAt=901)
                with self.assertRaises(StaleRecordError):
                    self.publish(synthetic=True)

    def test_unbound_normal_intent_needs_no_device_or_live_producer_and_creates_no_target(self):
        record = dict(self.record)
        record.pop("device")
        record.pop("producer")
        self.assertEqual(self.intents.publish_unbound(record, False, 900)["background"], "#112233")
        self.assertEqual(set(path.name for path in self.store.directory.iterdir()),
                         {self.path.name, "writer-"+key(self.target["tty"])+".lock"})
        self.assertFalse((self.store.directory / "targets").exists())
        self.identities.clear()
        record = dict(self.record, updatedAt=960)
        self.intents.publish_unbound(record, False, 900)
        self.assertEqual(json.loads(self.path.read_bytes())["updatedAt"], 960)

    def test_unbound_synthetic_keeps_observation_identity_and_requires_live_exact_device(self):
        self.observe()
        before = self.observation_path.read_bytes()
        self.intents.publish_unbound(self.record, True, 900)
        self.assertEqual(self.observation_path.read_bytes(), before)
        self.assertFalse((self.store.directory / "targets").exists())
        original = self.path.read_bytes()
        self.identities[43]["device"] = 124
        with self.assertRaises(StaleRecordError):
            self.intents.publish_unbound(dict(self.record, updatedAt=960), True, 900)
        self.assertEqual(self.path.read_bytes(), original)

    def test_unbound_ordering_and_supersession_match_bound_publication(self):
        self.intents.publish_unbound(self.record, False, 900)
        with self.assertRaises(StaleRecordError):
            self.intents.publish_unbound(dict(self.record, updatedAt=940), False, 900)
        replacement = dict(self.record, deliveryID="new-delivery", updatedAt=920)
        self.observe(deliveryID="new-delivery", observedAt=910)
        self.intents.publish_unbound(replacement, False, 910)
        self.assertEqual(json.loads(self.path.read_bytes())["deliveryID"], "new-delivery")

    def test_wrong_cached_tty_alone_cannot_authorize_older_delivery_supersession(self):
        self.intents.publish_unbound(self.record, False, 900)
        current = json.loads(self.path.read_bytes())
        current["tty"] = "/dev/ttysOther43"
        self.path.write_text(json.dumps(current))
        self.observe()
        with self.assertRaises(StaleRecordError):
            self.intents.publish_unbound(dict(self.record, updatedAt=940), False, 900)
        self.assertEqual(json.loads(self.path.read_bytes()), current)

    def test_unbound_equal_timestamp_can_replace_background(self):
        self.intents.publish_unbound(self.record, False, 900)
        self.intents.publish_unbound(dict(self.record, background="#AABBCC"), False, 900)
        self.assertEqual(json.loads(self.path.read_bytes())["background"], "#AABBCC")

    def test_bound_producer_exit_during_latest_read_prevents_shared_write(self):
        def producer_exits(tty, synthetic, deadline):
            self.identities.pop(43)
            return None
        with patch.object(self.intents, "_latest", side_effect=producer_exits):
            with self.assertRaises(OSError) as failure:
                self.publish()
        self.assertNotIsInstance(failure.exception, StaleRecordError)
        self.assertFalse(self.path.exists())
        self.assertFalse((self.store.directory / "targets").exists())

    def test_unbound_repairs_only_regular_intent_and_synthetic_record_errors_are_unavailable(self):
        self.path.parent.mkdir(parents=True)
        self.path.write_bytes(b"invalid intent")
        self.observe()
        with self.assertRaises(OSError) as failure:
            self.intents.publish_unbound(self.record, True, 900)
        self.assertNotIsInstance(failure.exception, StaleRecordError)
        self.intents.publish_unbound(self.record, False, 900)
        self.observation_path.write_bytes(b"invalid observation")
        with self.assertRaises(OSError) as failure:
            self.intents.publish_unbound(self.record, True, 900)
        self.assertNotIsInstance(failure.exception, StaleRecordError)

    def test_synthetic_invalid_observation_file_is_stale_but_storage_and_target_are_not(self):
        self.observation_path.parent.mkdir(parents=True)
        os.mkfifo(self.observation_path)
        with self.assertRaises(StaleRecordError):
            self.intents.validate_context_unlocked(self.target, self.record, True, 900, self.deadline())
        with patch("portable_intent.records.read", side_effect=OSError(errno.EACCES, "Storage denied")):
            with self.assertRaises(OSError) as failure:
                self.intents.validate_context_unlocked(self.target, self.record, True, 900, self.deadline())
        self.assertNotIsInstance(failure.exception, StaleRecordError)
        self.assertEqual(failure.exception.errno, errno.EACCES)

    def test_superseding_delivery_is_stale_record_and_changed_target_is_unavailable(self):
        self.observe(observedAt=901)
        with self.assertRaises(StaleRecordError):
            self.intents.validate_context_unlocked(self.target, self.record, True, 900, self.deadline())
        self.observe()
        self.identities[100]["generation"] = dict(self.owner, startSeconds=101)
        with self.assertRaises(OSError) as failure:
            self.intents.validate_context_unlocked(self.target, self.record, True, 900, self.deadline())
        self.assertNotIsInstance(failure.exception, StaleRecordError)

    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix="intent-", dir=os.environ["TAVS_TEST_ROOT"]))
        self.runtime = self.root / "runtime"
        self.marker = self.root / "home/visual-restrictions.state"
        self.marker.parent.mkdir()
        self.producer = {"pid": 43, "startSeconds": 200, "startMicroseconds": 0}
        self.owner = {"pid": 100, "startSeconds": 100, "startMicroseconds": 0}
        self.target = {"tty": "/dev/ttys043", "device": 123, "ttyOwner": self.owner}
        self.identities = {43: {"generation": self.producer, "device": 123, "parentPID": 100},
                           100: {"generation": self.owner, "device": 123, "parentPID": 1}}
        self.store = Store(self.runtime, Policy(self.marker, self.runtime),
                           lookup=self.identities.get, process_missing=lambda pid: pid not in self.identities,
                           device=lambda tty: 123, descriptor_device=lambda fd: 123, clock=lambda: 1000)
        self.intents = Intents(self.store)
        self.record = {"schema": 1, "tty": self.target["tty"], "device": 123,
                       "producer": self.producer, "deliveryID": "delivery-43", "updatedAt": 950,
                       "background": "rgb:1/2/3"}
        self.path = self.store.directory / ("intent-" + key(self.target["tty"]) + ".json")
        self.observation_path = self.store.directory / ("observation-" + key(self.target["tty"]) + ".json")

    def deadline(self):
        return time.monotonic_ns() + 100_000_000

    def observe(self, **changes):
        observation = {"schema": 1, "tty": self.target["tty"], "device": 123, "producer": self.producer,
                       "provider": "claude", "verifiedAgent": False, "state": "complete",
                       "event": "Stop", "deliveryID": "delivery-43", "observedAt": 900}
        observation.update(changes)
        records.write(self.store.directory, self.observation_path, observation, "observation", 1000, self.deadline())

    def publish(self, record=None, synthetic=False, intake=900):
        return self.intents.publish_unlocked(self.target, record or self.record, synthetic, intake, self.deadline())

    def test_ordinary_publication_is_normalized_and_bound_to_current_lifetime(self):
        result = self.publish()
        self.assertEqual(result["background"], "#112233")
        latest = records.read(self.store.directory, self.path, "intent", 1000, self.deadline())
        bound_path = target_path(self.store.directory, self.target, "bound-intent.json")
        bound = records.read(self.store.directory, bound_path, "intent", 1000, self.deadline())
        self.assertEqual(latest, result)
        self.assertEqual(bound, result)
        self.assertFalse(self.observation_path.exists())

    def test_intent_changes_during_owned_preview_without_changing_effect_or_observation(self):
        effect = {"schema": 1, "target": self.target, "controller": self.owner, "effectID": "preview-43",
                  "kind": "preview", "background": "#ABCDEF", "heartbeatAt": 999, "active": True}
        path = target_path(self.store.directory, self.target, "preview.json")
        records.write(self.store.directory, path, effect, "effect", 1000, self.deadline())
        original = path.read_bytes()
        self.observe()
        observation = self.observation_path.read_bytes()
        self.assertEqual(self.publish(synthetic=True)["background"], "#112233")
        self.assertEqual(path.read_bytes(), original)
        self.assertEqual(self.observation_path.read_bytes(), observation)

    def test_synthetic_requires_exact_observation_live_producer_and_original_intake(self):
        with self.assertRaises(OSError):
            self.publish(synthetic=True)
        self.observe(deliveryID="other-delivery")
        with self.assertRaises(OSError):
            self.publish(synthetic=True)
        self.observe(observedAt=901)
        with self.assertRaises(OSError):
            self.publish(synthetic=True)
        self.observe()
        self.publish(synthetic=True)
        original = self.path.read_bytes()
        self.identities[43]["generation"] = dict(self.producer, startSeconds=300)
        with self.assertRaises(OSError):
            self.publish(synthetic=True)
        self.assertEqual(self.path.read_bytes(), original)

    def test_current_observation_supersedes_a_later_old_render_timestamp(self):
        self.publish(dict(self.record, deliveryID="old", updatedAt=999))
        self.observe(deliveryID="new", observedAt=930)
        new = dict(self.record, deliveryID="new", updatedAt=950)
        self.assertEqual(self.publish(new, intake=940)["deliveryID"], "new")
        with self.assertRaises(OSError):
            self.publish(dict(self.record, deliveryID="old", updatedAt=1000), intake=900)
        self.assertEqual(records.read(self.store.directory, self.path, "intent", 1000, self.deadline())["deliveryID"], "new")

    def test_older_intent_without_superseding_observation_cannot_replace_latest(self):
        self.publish()
        original = self.path.read_bytes()
        with self.assertRaises(OSError):
            self.publish(dict(self.record, updatedAt=949))
        self.assertEqual(self.path.read_bytes(), original)

    def test_ordinary_repairs_only_regular_intent_corruption_and_synthetic_refuses(self):
        self.publish()
        self.path.write_bytes(b'{')
        self.observe()
        with self.assertRaises(OSError):
            self.publish(synthetic=True)
        self.assertEqual(self.path.read_bytes(), b'{')
        self.publish()
        saved = self.root / "saved-intent"
        self.path.rename(saved)
        self.path.symlink_to(saved)
        with self.assertRaises(OSError):
            self.publish()
        self.assertEqual(saved.read_bytes(), self.path.read_bytes())

    def test_corrupt_observation_can_retain_intent_but_never_authorize_style_output(self):
        self.store.directory.mkdir(parents=True)
        self.observation_path.write_bytes(b'{')
        self.publish()
        with self.assertRaises(OSError):
            self.intents.validate_context_unlocked(self.target, self.record, False, 900, self.deadline())

    def test_invalid_bound_copy_refuses_binding_but_retains_requested_latest(self):
        self.publish()
        original = self.path.read_bytes()
        bound = target_path(self.store.directory, self.target, "bound-intent.json")
        bound.write_bytes(b'{')
        with self.assertRaises(OSError):
            self.publish(dict(self.record, updatedAt=960))
        latest = records.read(self.store.directory, self.path, "intent", 1000, self.deadline())
        self.assertEqual(latest["updatedAt"], 960)
        self.assertNotEqual(self.path.read_bytes(), original)
        self.assertEqual(bound.read_bytes(), b'{')
        self.assertEqual(self.store.resolve(self.target["tty"], self.producer, self.deadline(), targets_only=True), self.target)
        revision = self.store.policy.capture(self.deadline())
        try:
            with self.assertRaises(OSError):
                self.store.ordinary_ownership(self.target, revision, 43, self.deadline())
        finally:
            revision.close()
        with self.assertRaises(OSError) as failure:
            self.intents.publish_unlocked(self.target, self.record, False, 900, time.monotonic_ns() - 1)
        self.assertEqual(failure.exception.errno, errno.ETIMEDOUT)

    def test_context_rechecks_producer_after_observation_read(self):
        self.observe()
        original_read = records.read
        def exiting_read(root, path, kind, now, deadline):
            result = original_read(root, path, kind, now, deadline)
            if kind == "observation":
                self.identities.pop(43)
            return result
        with patch("portable_intent.records.read", side_effect=exiting_read):
            with self.assertRaises(OSError):
                self.intents.validate_context_unlocked(self.target, self.record, True, 900, self.deadline())

    def test_binding_requires_the_full_latest_record_not_only_delivery_identity(self):
        original_read = records.read
        reads = 0
        def changed_latest(root, path, kind, now, deadline):
            nonlocal reads
            if kind == "intent" and path == self.path:
                reads += 1
                if reads == 2:
                    records.write(root, path, dict(self.record, background="#FFFFFF"), kind, now, deadline)
            return original_read(root, path, kind, now, deadline)
        with patch("portable_intent.records.read", side_effect=changed_latest):
            with self.assertRaises(OSError) as failure:
                self.publish()
            self.assertEqual(failure.exception.errno, errno.ESTALE)
        self.assertFalse(target_path(self.store.directory, self.target, "bound-intent.json").exists())

    def test_bound_latest_survives_producer_exit_but_other_delivery_does_not(self):
        self.publish()
        self.identities.pop(43)
        self.assertEqual(self.intents.ordinary_background_unlocked(self.target, self.deadline()), "#112233")
        records.write(self.store.directory, self.path, dict(self.record, deliveryID="unbound", updatedAt=960),
                      "intent", 1000, self.deadline())
        self.assertIsNone(self.intents.ordinary_background_unlocked(self.target, self.deadline()))

    def test_unbound_native_intent_requires_existing_exact_adoption(self):
        native = dict(self.target, nativeSurface={"application": self.owner, "terminalID": "pane-43"})
        records.write(self.store.directory, self.path, self.record, "intent", 1000, self.deadline())
        self.assertEqual(self.intents.ordinary_background_unlocked(self.target, self.deadline()), "#112233")
        self.assertIsNone(self.intents.ordinary_background_unlocked(native, self.deadline()))
        adoption = {"schema": 1, "tty": self.target["tty"], "device": 123, "producer": self.producer,
                    "surface": native["nativeSurface"], "intentDeliveryID": self.record["deliveryID"]}
        path = self.store.directory / ("adoption-" + key(self.target["tty"]) + "-43-200-0.json")
        records.write(self.store.directory, path, adoption, "adoption", 1000, self.deadline())
        self.assertEqual(self.intents.ordinary_background_unlocked(native, self.deadline()), "#112233")

    def test_live_forced_reset_requires_original_observation_and_delivery(self):
        reset = dict(self.record, background="reset", updatedAt=980)
        with self.assertRaises(OSError):
            self.intents.publish_forced_reset_unlocked(self.target, reset, 900, self.deadline())
        self.observe()
        self.intents.publish_forced_reset_unlocked(self.target, reset, 900, self.deadline())
        self.assertEqual(self.intents.ordinary_background_unlocked(self.target, self.deadline()), "reset")

    def test_exited_producer_can_reset_only_unchanged_bound_latest(self):
        self.observe()
        self.publish()
        self.identities.pop(43)
        reset = dict(self.record, background="reset", updatedAt=980)
        self.intents.publish_forced_reset_unlocked(self.target, reset, 900, self.deadline())
        self.assertEqual(self.intents.ordinary_background_unlocked(self.target, self.deadline()), "reset")
        self.assertEqual(self.observation_path.read_bytes().count(b'delivery-43'), 1)

    def test_orphan_reset_refuses_other_delivery_or_newer_observation(self):
        self.observe()
        self.publish()
        self.identities.pop(43)
        reset = dict(self.record, background="reset", updatedAt=980)
        with self.assertRaises(OSError):
            self.intents.publish_forced_reset_unlocked(self.target, dict(reset, deliveryID="other"), 900, self.deadline())
        self.observe(observedAt=901)
        with self.assertRaises(OSError):
            self.intents.publish_forced_reset_unlocked(self.target, reset, 900, self.deadline())
        self.assertEqual(records.read(self.store.directory, self.path, "intent", 1000, self.deadline())["background"], "#112233")

    def test_orphan_reset_refuses_changed_bound_copy_and_reused_owner(self):
        self.observe()
        self.publish()
        self.identities.pop(43)
        bound = target_path(self.store.directory, self.target, "bound-intent.json")
        records.write(self.store.directory, bound, dict(self.record, background="#FFFFFF"),
                      "intent", 1000, self.deadline())
        reset = dict(self.record, background="reset", updatedAt=980)
        with self.assertRaises(OSError):
            self.intents.publish_forced_reset_unlocked(self.target, reset, 900, self.deadline())
        self.identities[100]["generation"] = dict(self.owner, startSeconds=300)
        with self.assertRaises(OSError):
            self.intents.publish_forced_reset_unlocked(self.target, reset, 900, self.deadline())

    def test_forced_reset_refuses_nonreset_intent(self):
        with self.assertRaises(OSError):
            self.intents.publish_forced_reset_unlocked(self.target, self.record, 900, self.deadline())


if __name__ == "__main__":
    unittest.main()
