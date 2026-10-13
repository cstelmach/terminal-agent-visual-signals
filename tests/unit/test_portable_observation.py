import errno
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
import time
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "src/core"))
from portable_policy import Policy
from portable_ownership import Store
from portable_observation import publish_observation
import portable_record_io as records
from portable_records import key
from portable_device_writer import output_lock


class PortableObservationTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix="observation-", dir=os.environ["TAVS_TEST_ROOT"]))
        self.runtime = self.root / "runtime"
        self.store = Store(self.runtime, Policy(self.root / "marker", self.runtime), clock=lambda: 1000)
        self.tty = "/dev/ttys043"
        self.path = self.store.directory / ("observation-"+key(self.tty)+".json")
        self.context = {"schema": 1, "deliveryID": "delivery-43", "observedAt": 999,
                        "provider": "claude", "verifiedAgent": False, "event": "Stop"}

    def publish(self, value=None, state="complete"):
        return publish_observation(self.store, self.context if value is None else value, self.tty, state)

    def test_publication_retains_only_observation_and_rejects_older_delivery(self):
        self.publish()
        saved = records.read(self.store.directory, self.path, "observation", 1000,
                             time.monotonic_ns()+100_000_000)
        self.assertEqual(saved["observedAt"], 999)
        self.assertFalse(saved["verifiedAgent"])
        self.assertEqual(set(p.name for p in self.store.directory.iterdir()),
                         {self.path.name, "writer-"+key(self.tty)+".lock"})
        with self.assertRaises(OSError) as failure:
            self.publish(dict(self.context, observedAt=998, deliveryID="older"))
        self.assertEqual(failure.exception.errno, errno.ESTALE)
        self.assertEqual(json.loads(self.path.read_bytes()), saved)
        self.publish(dict(self.context, deliveryID="equal-time"))
        self.assertEqual(json.loads(self.path.read_bytes())["deliveryID"], "equal-time")

    def test_invalid_regular_record_can_be_repaired_but_links_cannot(self):
        self.path.parent.mkdir(parents=True)
        self.path.write_text("not JSON")
        self.publish()
        saved = self.path.with_name("owned-original")
        self.path.rename(saved)
        self.path.symlink_to(saved)
        with self.assertRaises(OSError):
            self.publish()
        self.assertTrue(self.path.is_symlink())
        self.assertEqual(json.loads(saved.read_bytes())["deliveryID"], "delivery-43")

    def test_observation_rejects_unsupported_provider_state_and_invalid_response(self):
        for value, state in ((dict(self.context, provider="gemini"), "complete"),
                             (self.context, "success"),
                             (dict(self.context, responseID="x"*129), "complete")):
            with self.assertRaises((ValueError, OSError)):
                self.publish(value, state)
        self.assertFalse(self.path.exists())

    def test_unavailable_latest_type_or_lock_cannot_be_repaired_as_data(self):
        self.path.parent.mkdir(parents=True)
        os.mkfifo(self.path)
        with self.assertRaises(OSError):
            self.publish()
        self.assertTrue(stat.S_ISFIFO(self.path.stat().st_mode))

    def test_observation_lock_contention_keeps_original_deadline_and_prior_record(self):
        self.publish()
        before = self.path.read_bytes()
        lock = self.store.directory / ("writer-"+key(self.tty)+".lock")
        with output_lock(lock, time.monotonic_ns()+100_000_000):
            with self.assertRaises(OSError) as failure:
                self.publish(dict(self.context, deliveryID="replacement"))
        self.assertEqual(failure.exception.errno, errno.ETIMEDOUT)
        self.assertEqual(self.path.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
