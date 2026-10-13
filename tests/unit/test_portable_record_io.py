import errno
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "src/core"))
from portable_record_io import read, write


class PortableRecordIOTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix="record-io-", dir=os.environ["TAVS_TEST_ROOT"]))
        self.directory = self.root / "runtime/organizer"
        self.path = self.directory / "targets/tty/owner/plain/target.json"
        self.record = {"schema": 1, "target": {"tty": "/dev/ttys043", "device": 123,
                       "ttyOwner": {"pid": 43, "startSeconds": 100, "startMicroseconds": 0}}}

    def deadline(self):
        return time.monotonic_ns() + 100_000_000

    def test_nested_atomic_replace_is_complete_private_and_keeps_old_open_file(self):
        write(self.directory, self.path, self.record, "target", 1000, self.deadline())
        fd = os.open(self.path, os.O_RDONLY)
        try:
            previous = os.fstat(fd).st_ino
            newer = {"schema": 1, "target": dict(self.record["target"], device=456)}
            write(self.directory, self.path, newer, "target", 1000, self.deadline())
            self.assertNotEqual(os.stat(self.path).st_ino, previous)
            self.assertEqual(json.loads(os.read(fd, 8192)), self.record)
            self.assertEqual(read(self.directory, self.path, "target", 1000, self.deadline()), newer)
            self.assertEqual(os.stat(self.path).st_mode & 0o777, 0o600)
            self.assertEqual(list(self.path.parent.glob('.record-*.tmp')), [])
        finally:
            os.close(fd)

    def test_invalid_record_or_linked_ancestor_never_replaces_data(self):
        write(self.directory, self.path, self.record, "target", 1000, self.deadline())
        original = self.path.read_bytes()
        with self.assertRaises(OSError):
            write(self.directory, self.path, {"schema": True}, "target", 1000, self.deadline())
        self.assertEqual(self.path.read_bytes(), original)
        linked = self.directory / "linked"
        linked.symlink_to(self.path.parent)
        with self.assertRaises(OSError):
            write(self.directory, linked / "target.json", self.record, "target", 1000, self.deadline())
        with self.assertRaises(OSError):
            read(self.directory, linked / "target.json", "target", 1000, self.deadline())
        self.assertEqual(self.path.read_bytes(), original)

    def test_original_deadline_expiring_midwrite_leaves_prior_record(self):
        write(self.directory, self.path, self.record, "target", 1000, self.deadline())
        original = self.path.read_bytes()
        deadline = self.deadline()
        original_write = os.write
        with patch("portable_policy.time.monotonic_ns", return_value=deadline - 1) as clock:
            def partial(fd, data):
                count = original_write(fd, data[:3])
                clock.return_value = deadline
                return count
            with patch("portable_record_io.os.write", side_effect=partial):
                with self.assertRaises(OSError) as failure:
                    write(self.directory, self.path, self.record, "target", 1000, deadline)
                self.assertEqual(failure.exception.errno, errno.ETIMEDOUT)
        self.assertEqual(self.path.read_bytes(), original)
        self.assertEqual(list(self.path.parent.glob('.record-*.tmp')), [])

    def test_missing_read_does_not_create_directories_or_escape_root(self):
        self.assertIsNone(read(self.directory, self.path, "target", 1000, self.deadline()))
        self.assertFalse(self.directory.exists())
        with self.assertRaises(OSError):
            write(self.directory, self.directory / "../escape.json", self.record, "target", 1000, self.deadline())
        self.assertFalse((self.root / "runtime/escape.json").exists())

    def test_close_error_still_removes_only_the_failed_write_temporary(self):
        write(self.directory, self.path, self.record, "target", 1000, self.deadline())
        original = self.path.read_bytes()
        original_close = os.close
        def failed_close(fd):
            regular = stat.S_ISREG(os.fstat(fd).st_mode)
            original_close(fd)
            if regular:
                raise OSError(errno.EIO, "Injected close failure")
        with patch("portable_record_io.os.write", side_effect=OSError(errno.EIO, "Injected write failure")), \
             patch("portable_record_io.os.close", side_effect=failed_close):
            with self.assertRaises(OSError):
                write(self.directory, self.path, self.record, "target", 1000, self.deadline())
        self.assertEqual(self.path.read_bytes(), original)
        self.assertEqual(list(self.path.parent.glob('.record-*.tmp')), [])


if __name__ == "__main__":
    unittest.main()
