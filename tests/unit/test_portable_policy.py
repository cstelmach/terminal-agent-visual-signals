import errno
import os
from pathlib import Path
import stat
import sys
import tempfile
import time
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "src/core"))
from portable_policy import InvalidRegularFileError, Policy, read_regular


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

    def test_marker_operations_reject_writable_storage_and_changed_revision_permissions(self):
        self.marker.write_bytes(Policy._marker(False))
        revision = self.policy.capture(self.deadline())
        self.addCleanup(revision.close)

        def capture():
            current = self.policy.capture(self.deadline())
            current.close()

        for path, mode in [(self.marker, 0o660), (self.marker, 0o606),
                           (self.marker.parent, 0o770), (self.root, 0o1777)]:
            previous = stat.S_IMODE(path.stat().st_mode)
            try:
                path.chmod(mode)
                for operation in [capture, lambda: self.policy.suspended(self.deadline()),
                                  lambda: self.policy.matches(revision, self.deadline())]:
                    with self.subTest(path=path.name, mode=mode, operation=operation):
                        with self.assertRaises(OSError):
                            operation()
            finally:
                path.chmod(previous)
        self.assertEqual(self.marker.read_bytes(), Policy._marker(False))

    def test_missing_marker_under_unsafe_prefix_is_unavailable_without_creating_state(self):
        self.marker.parent.chmod(0o770)
        with self.assertRaises(OSError):
            self.policy.capture(self.deadline())
        self.assertFalse(self.marker.exists())
        self.assertFalse(self.policy.restricted(self.deadline(), unavailable_disabled=True))
        with self.assertRaises(OSError) as failure:
            self.policy.restricted(time.monotonic_ns() - 1, unavailable_disabled=True)
        self.assertEqual(failure.exception.errno, errno.ETIMEDOUT)
        invalid = Policy(self.marker.parent / "../marker", self.runtime)
        with self.assertRaises(OSError) as failure:
            invalid.restricted(time.monotonic_ns() - 1, unavailable_disabled=True)
        self.assertEqual(failure.exception.errno, errno.ETIMEDOUT)

    def test_rules_reject_writable_leaf_and_runtime_even_for_missing_lock(self):
        lock = self.runtime / "lock.state"
        mute = self.marker.parent / "mute.state"
        lock.write_text('LOCKED="true"\nLOCK_UNTIL_EPOCH="2000"\n')
        lock.chmod(0o660)
        with self.assertRaises(OSError):
            self.policy.restricted(self.deadline())
        lock.rename(self.root / "retained-lock")
        mute.write_text('MUTED="true"\nUNTIL_EPOCH="0"\nWRITTEN_EPOCH="990"\nAPP_PID="43"\n')
        mute.chmod(0o606)
        with self.assertRaises(OSError):
            self.policy.restricted(self.deadline())
        mute.chmod(0o600)
        self.runtime.chmod(0o770)
        with self.assertRaises(OSError):
            self.policy.restricted(self.deadline())
        self.assertFalse(lock.exists())

    def test_arbitrary_directory_links_and_dotdot_are_unavailable_before_absence(self):
        self.marker.write_bytes(Policy._marker(False))
        home_link = self.root / "linked-home"
        home_link.symlink_to(self.marker.parent, target_is_directory=True)
        for marker in [home_link / self.marker.name, home_link / "missing/marker",
                       self.marker.parent / "../absent-marker"]:
            with self.subTest(marker=marker):
                policy = Policy(marker, self.runtime)
                with self.assertRaises(OSError):
                    policy.capture(self.deadline())
        runtime_link = self.root / "linked-runtime"
        runtime_link.symlink_to(self.runtime, target_is_directory=True)
        with self.assertRaises(OSError):
            Policy(self.marker, runtime_link).restricted(self.deadline())

    def test_foreign_marker_or_parent_metadata_is_unavailable(self):
        self.marker.write_bytes(Policy._marker(False))
        revision = self.policy.capture(self.deadline())
        self.addCleanup(revision.close)
        actual = os.lstat
        for target in [self.marker, self.marker.parent, self.root]:
            spellings = {str(target), str(target.resolve())}

            def foreign(path, *args, **kwargs):
                info = actual(path, *args, **kwargs)
                if str(path) in spellings:
                    values = list(info)
                    values[4] = os.geteuid() + 1
                    return os.stat_result(values)
                return info

            with mock.patch("portable_policy.os.lstat", side_effect=foreign):
                with self.subTest(target=target.name):
                    with self.assertRaises(OSError):
                        self.policy.suspended(self.deadline())
                    with self.assertRaises(OSError):
                        self.policy.matches(revision, self.deadline())

    def test_changed_opened_file_metadata_is_rejected_and_descriptor_closed(self):
        self.marker.write_bytes(Policy._marker(False))
        actual = os.fstat
        for field in ["owner", "write_bits"]:
            def untrusted(fd):
                values = list(actual(fd))
                if field == "owner":
                    values[4] = os.geteuid() + 1
                else:
                    values[0] |= 0o022
                return os.stat_result(values)

            with self.subTest(field=field), mock.patch("portable_policy.os.fstat", side_effect=untrusted), \
                    mock.patch("portable_policy.os.close", wraps=os.close) as close:
                with self.assertRaises(OSError) as failure:
                    read_regular(self.marker, self.deadline(), 127)
                self.assertEqual(failure.exception.errno, errno.EACCES)
                self.assertNotIsInstance(failure.exception, InvalidRegularFileError)
                self.assertEqual(close.call_count, 1)

    def test_trusted_missing_parent_and_read_only_group_permissions_remain_supported(self):
        marker = self.marker.parent / "missing/nested/marker"
        policy = Policy(marker, self.runtime)
        revision = policy.capture(self.deadline())
        self.addCleanup(revision.close)
        self.assertTrue(policy.matches(revision, self.deadline()))
        self.assertFalse(marker.parent.exists())
        self.marker.write_bytes(Policy._marker(True))
        self.marker.chmod(0o640)
        self.assertTrue(self.policy.suspended(self.deadline()))
        current = self.policy.capture(self.deadline())
        self.addCleanup(current.close)
        self.assertTrue(self.policy.matches(current, self.deadline()))

    def test_unavailable_policy_fallback_does_not_swallow_expired_io_failure(self):
        with mock.patch.object(self.policy, "suspended", side_effect=OSError(errno.EACCES, "Fixture unavailable")):
            with mock.patch("portable_policy.time.monotonic_ns", return_value=1):
                self.assertFalse(self.policy.restricted(2, unavailable_disabled=True))
            with mock.patch("portable_policy.time.monotonic_ns", return_value=3):
                with self.assertRaises(OSError) as failure:
                    self.policy.restricted(2, unavailable_disabled=True)
                self.assertEqual(failure.exception.errno, errno.ETIMEDOUT)

    def test_untrusted_regular_records_cannot_be_repaired_as_malformed_data(self):
        from portable_record_io import read_latest
        path = self.root / "latest.json"
        body = b"retained malformed record"
        path.write_bytes(body)
        self.assertIsNone(read_latest(self.root, path, "observation", 1000, self.deadline(), True))
        path.chmod(0o660)
        with self.assertRaises(OSError) as failure:
            read_latest(self.root, path, "observation", 1000, self.deadline(), True)
        self.assertEqual(failure.exception.errno, errno.EACCES)
        self.assertEqual(path.read_bytes(), body)


if __name__ == "__main__":
    unittest.main()
