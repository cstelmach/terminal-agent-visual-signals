import errno
import fcntl
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

CORE = Path(__file__).resolve().parents[2] / "src/core"
sys.path.insert(0, str(CORE))
import portable_lock_state as locks


class PortableLockStateTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix="lock-transaction-", dir=os.environ["TAVS_TEST_ROOT"]))
        self.path = self.root / "runtime/lock.state"

    def update(self, operation, *values):
        return locks.update(self.path, operation, values, 1000, time.monotonic_ns() + 100_000_000)

    def fields(self):
        return dict(line.split("=", 1) for line in self.path.read_text().splitlines())

    def test_now_keeps_the_longer_end_and_grant_preserves_current_fields(self):
        self.assertEqual(self.update("now", "8000", "#abcdef", ""), 8000)
        self.assertEqual(self.update("now", "4000", "#123456", "#ffffff"), 8000)
        self.assertEqual(self.update("grant", "1500"), 8000)
        fields = self.fields()
        self.assertEqual(fields["LOCK_BG"], '"#123456"')
        self.assertEqual(fields["LOCK_FG"], '"#FFFFFF"')
        self.assertEqual(fields["UNLOCK_UNTIL_EPOCH"], '"1500"')
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)

    def test_legacy_numeric_defaults_and_zero_prefixes_remain_supported(self):
        self.path.parent.mkdir()
        self.path.write_text('LOCKED="true"\nLOCK_UNTIL_EPOCH="0008000"\nUNLOCK_UNTIL_EPOCH="bad"')
        self.assertEqual(self.update("grant", "0001500"), 8000)
        self.assertEqual(self.fields()["UNLOCK_UNTIL_EPOCH"], '"1500"')

    def test_invalid_input_or_existing_state_preserves_accepted_bytes(self):
        self.update("now", "8000", "", "")
        before = self.path.read_bytes()
        for operation, values in [("now", ("0", "", "")), ("now", ("9000", "bad", "")),
                                  ("grant", ("9223372036854775808",)), ("replace", ("true",))]:
            with self.subTest(operation=operation, values=values), self.assertRaises((ValueError, OSError)):
                self.update(operation, *values)
            self.assertEqual(self.path.read_bytes(), before)
        self.path.write_text('LOCKED="true"\nLOCK_UNTIL_EPOCH="bad"\n')
        before = self.path.read_bytes()
        with self.assertRaises((ValueError, OSError)):
            self.update("grant", "1500")
        self.assertEqual(self.path.read_bytes(), before)

    def test_untrusted_parent_leaf_and_mutex_are_rejected(self):
        self.update("now", "8000", "", "")
        before = self.path.read_bytes()
        for target in [self.path.parent, self.path, Path(str(self.path) + ".lock")]:
            mode = target.stat().st_mode & 0o777
            target.chmod(mode | 0o020)
            try:
                with self.assertRaises(OSError):
                    self.update("now", "9000", "", "")
                self.assertEqual(self.path.read_bytes(), before)
            finally:
                target.chmod(mode)
        self.path.chmod(0o640)
        self.assertEqual(self.update("grant", "1500"), 8000)

    def test_link_and_fifo_destinations_are_never_opened_for_writing(self):
        self.path.parent.mkdir()
        outside = self.root / "outside"
        outside.write_bytes(b"unchanged")
        self.path.symlink_to(outside)
        with self.assertRaises(OSError):
            self.update("now", "8000", "", "")
        self.assertEqual(outside.read_bytes(), b"unchanged")
        self.path.unlink()
        os.mkfifo(self.path)
        with self.assertRaises(OSError):
            self.update("now", "8000", "", "")

    def test_contention_and_expired_deadline_preserve_accepted_state(self):
        self.update("now", "8000", "", "")
        before = self.path.read_bytes()
        fd = os.open(str(self.path) + ".lock", os.O_RDWR)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX)
            with self.assertRaises(OSError) as failure:
                self.update("now", "9000", "", "")
            self.assertEqual(failure.exception.errno, errno.ETIMEDOUT)
        finally:
            os.close(fd)
        with self.assertRaises(OSError):
            locks.update(self.path, "grant", ("1500",), 1000, time.monotonic_ns() - 1)
        self.assertEqual(self.path.read_bytes(), before)

    def test_failed_replace_cleans_owned_temporary_and_preserves_state(self):
        self.update("now", "8000", "", "")
        before = self.path.read_bytes()
        with mock.patch.object(locks.os, "replace", side_effect=OSError(errno.EIO, "injected")):
            with self.assertRaises(OSError):
                self.update("grant", "1500")
        self.assertEqual(self.path.read_bytes(), before)
        self.assertEqual(sorted(p.name for p in self.path.parent.iterdir()), ["lock.state", "lock.state.lock"])

    def test_close_errors_after_publication_do_not_report_a_committed_grant_as_failed(self):
        self.update("now", "8000", "", "")
        before, close = self.path.read_bytes(), os.close

        def fail_after_real_close(fd):
            close(fd)
            if self.path.read_bytes() != before:
                raise OSError(errno.EIO, "injected close result")

        with mock.patch.object(locks.os, "close", side_effect=fail_after_real_close):
            self.assertEqual(self.update("grant", "1500"), 8000)
        self.assertEqual(self.fields()["UNLOCK_UNTIL_EPOCH"], '"1500"')

    def test_precommit_close_error_still_cleans_the_owned_temporary(self):
        self.update("now", "8000", "", "")
        before, opened, close = self.path.read_bytes(), os.open, os.close
        temporary = []

        def remember_temporary(path, *args, **kwargs):
            fd = opened(path, *args, **kwargs)
            if str(path).startswith(".lock-state-"):
                temporary.append(fd)
            return fd

        def fail_temporary_close(fd):
            close(fd)
            if fd in temporary:
                raise OSError(errno.EIO, "injected close result")

        with mock.patch.object(locks.os, "open", side_effect=remember_temporary), \
                mock.patch.object(locks.os, "close", side_effect=fail_temporary_close), \
                mock.patch.object(locks.os, "write", side_effect=OSError(errno.EIO, "injected write")):
            with self.assertRaises(OSError):
                self.update("grant", "1500")
        self.assertEqual(self.path.read_bytes(), before)
        self.assertEqual(sorted(p.name for p in self.path.parent.iterdir()), ["lock.state", "lock.state.lock"])

    def test_two_process_updates_merge_after_the_first_transaction_releases(self):
        self.concurrent_operation("now")

    def test_a_grant_transaction_cannot_replace_a_competing_extension(self):
        self.concurrent_operation("grant")

    def concurrent_operation(self, operation):
        self.update("now", "2000", "", "")
        ready_r, ready_w = os.pipe()
        release_r, release_w = os.pipe()
        code = """
import os, sys, time
sys.path.insert(0, sys.argv[1])
import portable_lock_state as locks
original=locks.read_regular
def paused(*args, **kwargs):
    result=original(*args, **kwargs)
    os.write(int(sys.argv[3]), b'ready')
    os.read(int(sys.argv[4]), 1)
    return result
locks.read_regular=paused
operation=sys.argv[5]
values=('4000','','') if operation=='now' else ('1500',)
locks.update(sys.argv[2], operation, values, 1000, time.monotonic_ns()+5_000_000_000)
"""
        child = subprocess.Popen([sys.executable, "-c", code, str(CORE), str(self.path), str(ready_w), str(release_r), operation],
                                 pass_fds=(ready_w, release_r), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        os.close(ready_w); os.close(release_r)
        try:
            self.assertTrue(select.select([ready_r], [], [], 5)[0])
            self.assertEqual(os.read(ready_r, 5), b"ready")
            with self.assertRaises(OSError) as failure:
                self.update("now", "8000", "", "")
            self.assertEqual(failure.exception.errno, errno.ETIMEDOUT)
            os.write(release_w, b"x")
            _, error = child.communicate(timeout=5)
            self.assertEqual(child.returncode, 0, error.decode())
            self.assertEqual(self.update("now", "8000", "", ""), 8000)
            self.assertEqual(self.fields()["LOCK_UNTIL_EPOCH"], '"8000"')
        finally:
            if child.poll() is None:
                child.kill(); child.communicate()
            os.close(ready_r); os.close(release_w)
