import errno
import fcntl
import os
from pathlib import Path
import pty
import select
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "src/core"))
import portable_device_writer as writer
from portable_records import StaleRecordError


class PortableDeviceWriterTests(unittest.TestCase):
    def test_worker_preserves_stale_record_category_separately_from_target_errno(self):
        for error in (StaleRecordError("Stale delivery"), OSError(errno.ESTALE, "Changed target")):
            def prepare(fd, deadline):
                raise error
            with self.assertRaises(OSError) as failure:
                writer.write_managed(self.path, self.lock, None, prepare)
            self.assertEqual(isinstance(failure.exception, StaleRecordError), isinstance(error, StaleRecordError))
            self.assertEqual(failure.exception.errno, errno.ESTALE)
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])

    def setUp(self):
        self.master, self.slave = pty.openpty()
        self.path = os.ttyname(self.slave)
        self.root = Path(tempfile.mkdtemp(prefix="writer-", dir=os.environ["TAVS_TEST_ROOT"]))
        self.lock = str(self.root / "output.lock")

    def tearDown(self):
        deadline = time.monotonic() + 1
        while writer._children and time.monotonic() < deadline:
            writer.reap_completed()
            time.sleep(0.001)
        self.assertFalse(writer._children, "Owned writer children did not retire")
        os.close(self.master)
        os.close(self.slave)
        writer.reap_completed()

    def test_current_payload_uses_one_stable_private_lock_and_exact_device(self):
        expected = os.fstat(self.slave).st_rdev
        def prepare(fd, deadline):
            if os.fstat(fd).st_rdev != expected or time.monotonic_ns() >= deadline:
                raise OSError(errno.ESTALE, "Invalid target")
            return b"writer-43"
        self.assertTrue(writer.write_managed(self.path, self.lock, None, prepare))
        self.assertTrue(select.select([self.master], [], [], 1)[0])
        self.assertEqual(os.read(self.master, 1024), b"writer-43")
        self.assertEqual(os.stat(self.lock).st_mode & 0o777, 0o600)
        inode = os.stat(self.lock).st_ino
        self.assertFalse(writer.write_managed(self.path, self.lock, None, lambda fd, deadline: None))
        self.assertEqual(os.stat(self.lock).st_ino, inode)

    def test_held_lock_returns_by_original_deadline_without_late_output(self):
        fd = os.open(self.lock, os.O_RDWR | os.O_CREAT, 0o600)
        fcntl.flock(fd, fcntl.LOCK_EX)
        try:
            start = time.monotonic()
            with self.assertRaises(OSError) as failure:
                writer.write_managed(self.path, self.lock, None, lambda fd, deadline: b"late")
            self.assertEqual(failure.exception.errno, errno.ETIMEDOUT)
            self.assertLess(time.monotonic() - start, 0.25)
        finally:
            os.close(fd)
        self.assertFalse(select.select([self.master], [], [], 0.15)[0])

    def test_delayed_preparation_cannot_paint_after_caller_timeout(self):
        def prepare(fd, deadline):
            time.sleep(0.2)
            return b"late"
        with self.assertRaises(OSError) as failure:
            writer.write_managed(self.path, self.lock, None, prepare)
        self.assertEqual(failure.exception.errno, errno.ETIMEDOUT)
        self.assertFalse(select.select([self.master], [], [], 0.25)[0])

    def test_stale_preopen_rejection_never_opens_or_creates_output_lock(self):
        def reject(deadline):
            raise OSError(errno.ESTALE, "Invalid context")
        with self.assertRaises(OSError) as failure:
            writer.write_managed(self.path, self.lock, reject,
                                 lambda fd, deadline: self.fail("Rejected request reached prepare"))
        self.assertEqual(failure.exception.errno, errno.ESTALE)
        self.assertFalse(Path(self.lock).exists())
        self.assertFalse(select.select([self.master], [], [], 0)[0])

    def test_worker_does_not_keep_caller_stdio_channels_open(self):
        def before_open(deadline):
            for fd in (0, 1, 2):
                try:
                    os.fstat(fd)
                except OSError as error:
                    if error.errno == errno.EBADF:
                        continue
                raise OSError(errno.EIO, "Worker inherited caller channel")
        self.assertTrue(writer.write_managed(self.path, self.lock, before_open,
                                             lambda fd, deadline: b"detached"))
        self.assertEqual(os.read(self.master, 1024), b"detached")

    def test_partial_device_failure_reports_written_bytes(self):
        write = os.write
        calls = 0
        def partially_write(fd, data):
            nonlocal calls
            if os.isatty(fd):
                calls += 1
                if calls == 1:
                    return write(fd, data[:3])
                raise OSError(errno.EIO, "Injected failure")
            return write(fd, data)
        with patch("portable_device_writer.os.write", partially_write):
            with self.assertRaises(OSError) as failure:
                writer.write_managed(self.path, self.lock, None, lambda fd, deadline: b"abcdef")
        self.assertEqual(failure.exception.errno, errno.EIO)
        self.assertEqual(failure.exception.bytes_written, 3)
        self.assertEqual(os.read(self.master, 1024), b"abc")

    def test_slow_inspection_cannot_start_a_late_device_open(self):
        opened = self.root / "late-open"
        inspect, open_device = writer.device_number, os.open
        def delayed(path):
            time.sleep(0.15)
            return inspect(path)
        def mark_open(path, flags, *args, **kwargs):
            if path == self.path:
                opened.write_text("opened")
            return open_device(path, flags, *args, **kwargs)
        with patch("portable_device_writer.device_number", delayed), \
             patch("portable_device_writer.os.open", mark_open), \
             patch("portable_device_writer.os.kill", lambda *args: None):
            with self.assertRaises(OSError):
                writer.write_managed(self.path, self.lock, None, lambda fd, deadline: b"late")
        time.sleep(0.2)
        writer.reap_completed()
        self.assertFalse(opened.exists())

    def test_late_lock_acquisition_cannot_enter_metadata_preparation(self):
        prepared = self.root / "late-prepare"
        flock = fcntl.flock
        def delayed(fd, flags):
            value = flock(fd, flags)
            time.sleep(0.15)
            return value
        def prepare(fd, deadline):
            prepared.write_text("prepared")
            return b"late"
        with patch("portable_device_writer.fcntl.flock", delayed), \
             patch("portable_device_writer.os.kill", lambda *args: None):
            with self.assertRaises(OSError):
                writer.write_managed(self.path, self.lock, None, prepare)
        time.sleep(0.2)
        writer.reap_completed()
        self.assertFalse(prepared.exists())

    def test_before_open_publication_reuses_same_lock_before_output(self):
        published = self.root / "published"
        def before_open(deadline):
            with writer.output_lock(self.lock, deadline):
                published.write_text("published")
        self.assertTrue(writer.write_managed(self.path, self.lock, before_open,
                                             lambda fd, deadline: b"current"))
        self.assertTrue(published.exists())
        self.assertEqual(os.read(self.master, 1024), b"current")

    def test_after_output_failure_reports_known_complete_bytes_under_held_lock(self):
        def after_write(fd, deadline):
            probe = os.open(self.lock, os.O_RDWR)
            try:
                with self.assertRaises(BlockingIOError):
                    fcntl.flock(probe, fcntl.LOCK_EX | fcntl.LOCK_NB)
            finally:
                os.close(probe)
            raise OSError(errno.EIO, "Injected metadata completion failure")
        with self.assertRaises(OSError) as failure:
            writer.write_managed(self.path, self.lock, None, lambda fd, deadline: b"complete",
                                 after_write=after_write)
        self.assertEqual(failure.exception.bytes_written, 8)
        self.assertEqual(os.read(self.master, 1024), b"complete")

    def test_after_output_cannot_return_success_with_an_expired_deadline(self):
        def expire(fd, deadline):
            writer.time.monotonic_ns = lambda: deadline
        with self.assertRaises(OSError) as failure:
            writer.write_managed(self.path, self.lock, None, lambda fd, deadline: b"complete", after_write=expire)
        self.assertEqual(failure.exception.errno, errno.ETIMEDOUT)
        self.assertEqual(failure.exception.bytes_written, 8)
        self.assertEqual(os.read(self.master, 1024), b"complete")


if __name__ == "__main__":
    unittest.main()
