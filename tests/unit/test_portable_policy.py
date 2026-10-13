import errno
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "src/core"))
from portable_policy import Policy, read_regular


class PortablePolicyTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix="policy-", dir=os.environ["TAVS_TEST_ROOT"]))
        self.marker = self.root / "home/visual-restrictions.state"
        self.marker.parent.mkdir()
        self.runtime = self.root / "runtime"
        self.runtime.mkdir()
        self.policy = Policy(self.marker, self.runtime, clock=lambda: 1000, pid_alive=lambda pid: pid == 43)

    def deadline(self):
        return time.monotonic_ns() + 100_000_000

    def test_marker_revision_detects_replacement_even_when_boolean_is_equal(self):
        revision = self.policy.capture(self.deadline())
        self.assertTrue(self.policy.matches(revision, self.deadline()))
        self.marker.write_text('SCHEMA_VERSION="1"\nSUSPENDED="false"\n')
        self.assertFalse(self.policy.matches(revision, self.deadline()))
        revision.close()
        pinned = self.policy.capture(self.deadline())
        replacement = self.root / "replacement"
        replacement.write_text(self.marker.read_text())
        replacement.replace(self.marker)
        self.assertFalse(self.policy.matches(pinned, self.deadline()))
        pinned.close()

    def test_suspension_wins_without_changing_saved_rules(self):
        lock = self.runtime / "lock.state"
        lock.write_text('LOCKED="true"\nLOCK_UNTIL_EPOCH="2000"\n')
        self.assertTrue(self.policy.restricted(self.deadline()))
        self.marker.write_text('SCHEMA_VERSION="1"\nSUSPENDED="true"\n')
        self.assertFalse(self.policy.restricted(self.deadline()))
        self.assertEqual(lock.read_text(), 'LOCKED="true"\nLOCK_UNTIL_EPOCH="2000"\n')

    def test_soft_pause_requires_current_live_supported_fields(self):
        mute = self.marker.parent / "mute.state"
        base = 'MUTED="true"\nREASON="schedule_window"\nUNTIL_EPOCH="2000"\nWRITTEN_EPOCH="990"\nAPP_PID="43"\n'
        mute.write_text(base)
        self.assertTrue(self.policy.restricted(self.deadline()))
        for text in [base.replace('"43"', '"44"'), base.replace('"990"', '"800"'),
                     base + 'MUTE_LEVEL="hard"\n', base + 'REQUESTED_MUTED="false"\n',
                     base.replace('schedule_window', 'unknown'), base + 'MUTED="false"\n']:
            mute.write_text(text)
            self.assertFalse(self.policy.restricted(self.deadline()))

    def test_rule_text_is_data_and_io_ambiguity_is_failure(self):
        (self.runtime / "lock.state").write_text('LOCKED="true"\nLOCK_UNTIL_EPOCH="$(touch BAD)"\n')
        self.assertFalse(self.policy.restricted(self.deadline()))
        self.marker.symlink_to(self.runtime / "lock.state")
        with self.assertRaises(OSError):
            self.policy.capture(self.deadline())
        fifo = self.root / "fifo"
        os.mkfifo(fifo)
        with self.assertRaises(OSError):
            read_regular(fifo, self.deadline())
        with self.assertRaises(OSError) as failure:
            read_regular(self.runtime / "missing", time.monotonic_ns() - 1)
        self.assertEqual(failure.exception.errno, errno.ETIMEDOUT)

    def test_lock_boundaries_and_zero_padded_native_epochs(self):
        lock = self.runtime / "lock.state"
        lock.write_text('LOCKED="true"\nLOCK_UNTIL_EPOCH="' + '0' * 32 + '2000"\n')
        self.assertTrue(self.policy.restricted(self.deadline()))
        for suffix in ['UNLOCK_UNTIL_EPOCH="1001"\n', 'WRITTEN_EPOCH="9223372036854775808"\n']:
            lock.write_text('LOCKED="true"\nLOCK_UNTIL_EPOCH="2000"\n' + suffix)
            self.assertFalse(self.policy.restricted(self.deadline()))
        lock.write_text('LOCKED="true"\nLOCK_UNTIL_EPOCH="1000"\n')
        self.assertFalse(self.policy.restricted(self.deadline()))

    def test_recovery_during_policy_read_and_bounded_marker_validation(self):
        (self.marker.parent / "mute.state").write_text(
            'MUTED="true"\nUNTIL_EPOCH="0"\nWRITTEN_EPOCH="880"\nAPP_PID="43"\n')
        def recover(pid):
            self.marker.write_bytes(Policy._marker(True))
            return True
        self.policy.pid_alive = recover
        self.assertFalse(self.policy.restricted(self.deadline()))
        for data in [b'x' * 128, b'\xff', Policy._marker(False) + b'\n']:
            self.marker.write_bytes(data)
            with self.assertRaises(OSError):
                self.policy.capture(self.deadline())
        oversized = self.root / "large"
        oversized.write_bytes(b'x' * 9)
        with self.assertRaises(OSError):
            read_regular(oversized, self.deadline(), 8)


if __name__ == "__main__":
    unittest.main()
