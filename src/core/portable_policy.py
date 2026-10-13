"""Read suspension and legacy rules as bounded data, never shell code."""

import errno
import os
from pathlib import Path
import re
import stat
import time


def check_deadline(deadline):
    if time.monotonic_ns() >= deadline:
        raise OSError(errno.ETIMEDOUT, "Policy deadline exceeded")


def open_regular(path, deadline, limit):
    check_deadline(deadline)
    try:
        before = os.lstat(path)
    except FileNotFoundError:
        check_deadline(deadline)
        return None
    if not stat.S_ISREG(before.st_mode) or not 0 <= before.st_size <= limit:
        raise OSError(errno.EINVAL, "Unavailable policy file")
    check_deadline(deadline)
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC)
    try:
        current = os.fstat(fd)
        check_deadline(deadline)
        if (not stat.S_ISREG(current.st_mode) or not 0 <= current.st_size <= limit
                or (before.st_dev, before.st_ino) != (current.st_dev, current.st_ino)):
            raise OSError(errno.EINVAL, "Changed policy file")
        return fd
    except BaseException:
        os.close(fd)
        raise


def read_fd(fd, deadline, limit):
    result = bytearray()
    while True:
        check_deadline(deadline)
        try:
            chunk = os.read(fd, limit + 1 - len(result))
        except InterruptedError:
            continue
        check_deadline(deadline)
        if not chunk:
            return bytes(result)
        result.extend(chunk)
        if len(result) > limit:
            raise OSError(errno.EFBIG, "Oversized policy file")


def read_regular(path, deadline, limit=1_048_576):
    fd = open_regular(path, deadline, limit)
    if fd is None:
        return None
    try:
        return read_fd(fd, deadline, limit)
    finally:
        os.close(fd)


def _missing_accessible(path, deadline):
    parent = Path(path).parent
    while True:
        check_deadline(deadline)
        try:
            os.lstat(parent)
            available = stat.S_ISDIR(os.stat(parent).st_mode) and os.access(parent, os.X_OK)
            check_deadline(deadline)
            if not available:
                raise OSError(errno.EACCES, "Unavailable suspension directory")
            return
        except FileNotFoundError:
            if parent == parent.parent:
                raise OSError(errno.EACCES, "Unavailable suspension directory")
            parent = parent.parent


class Revision:
    def __init__(self, path, fd):
        self.path, self.fd = path, fd
        info = os.fstat(fd) if fd is not None else None
        self.identity = (info.st_dev, info.st_ino) if info else (0, 0)

    def close(self):
        if self.fd is not None:
            os.close(self.fd)
            self.fd = None

    def __del__(self):
        self.close()


def _fields(data):
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return None
    if "\0" in text:
        return None
    result = {}
    for line in text.split("\n"):
        if not line:
            continue
        key, equal, value = line.partition("=")
        if not key or not equal or key in result or len(value) < 2 or value[0] != '"' or value[-1] != '"':
            return None
        result[key] = value[1:-1]
    return result if result.get("SCHEMA_VERSION", "1") == "1" else None


def _epoch(value):
    if not isinstance(value, str) or re.fullmatch(r"[0-9]+", value) is None:
        return None
    digits = value.lstrip("0") or "0"
    if len(digits) > 19:
        return None
    result = int(digits)
    return result if result <= 2**63 - 1 else None


def _pid_alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


class Policy:
    def __init__(self, marker, runtime, clock=time.time, pid_alive=_pid_alive):
        self.marker, self.runtime = Path(marker), Path(runtime)
        self.clock, self.pid_alive = clock, pid_alive

    def capture(self, deadline):
        fd = open_regular(self.marker, deadline, 127)
        try:
            if fd is None:
                _missing_accessible(self.marker, deadline)
            elif read_fd(fd, deadline, 127) not in (self._marker(False), self._marker(True)):
                raise OSError(errno.EINVAL, "Unavailable suspension state")
            # Pin the inode until the transaction ends, including same-value atomic replacement.
            return Revision(self.marker, fd)
        except BaseException:
            if fd is not None:
                os.close(fd)
            raise

    @staticmethod
    def _marker(suspended):
        return ('SCHEMA_VERSION="1"\nSUSPENDED="%s"\n' % str(suspended).lower()).encode()

    def matches(self, revision, deadline):
        check_deadline(deadline)
        if revision.path != self.marker:
            raise OSError(errno.EINVAL, "Wrong suspension revision")
        try:
            info = os.lstat(self.marker)
        except FileNotFoundError:
            _missing_accessible(self.marker, deadline)
            return revision.identity == (0, 0)
        if not stat.S_ISREG(info.st_mode):
            raise OSError(errno.EINVAL, "Unavailable suspension state")
        check_deadline(deadline)
        return revision.identity[1] != 0 and revision.identity == (info.st_dev, info.st_ino)

    def suspended(self, deadline):
        data = read_regular(self.marker, deadline, 127)
        if data is None:
            _missing_accessible(self.marker, deadline)
            return False
        if data not in (self._marker(False), self._marker(True)):
            raise OSError(errno.EINVAL, "Unavailable suspension state")
        return data == self._marker(True)

    def restricted(self, deadline):
        if self.suspended(deadline):
            return False
        data = read_regular(self.runtime / "lock.state", deadline, 8192)
        fields = _fields(data) if data is not None else None
        now = int(self.clock())
        selected = False
        if fields and fields.get("LOCKED") in {"true", "false"}:
            until = _epoch(fields.get("LOCK_UNTIL_EPOCH"))
            unlock = _epoch(fields.get("UNLOCK_UNTIL_EPOCH", "0"))
            written = _epoch(fields.get("WRITTEN_EPOCH", "0"))
            if None not in (until, unlock, written):
                selected = fields["LOCKED"] == "true" and now < until and not now < unlock
        if not selected:
            data = read_regular(self.marker.parent / "mute.state", deadline, 8192)
            fields = _fields(data) if data is not None else None
            selected = bool(fields and self._soft(fields, deadline))
        check_deadline(deadline)
        return selected and not self.suspended(deadline)

    def _soft(self, fields, deadline):
        reason, level = fields.get("REASON", ""), fields.get("MUTE_LEVEL")
        if (fields.get("MUTED") not in {"true", "false"}
                or fields.get("REQUESTED_MUTED", fields.get("MUTED")) != "true"
                or reason not in {"schedule_window", "quiet_period", "master_paused", "hard_lock", ""}
                or level not in {None, "soft"} or (level is None and reason == "hard_lock")):
            return False
        until, written, pid = (_epoch(fields.get(key)) for key in ("UNTIL_EPOCH", "WRITTEN_EPOCH", "APP_PID"))
        if None in (until, written, pid) or not 0 < pid <= 2**31 - 1:
            return False
        alive = self.pid_alive(pid)
        check_deadline(deadline)
        now = int(self.clock())
        return alive and (until == 0 or now <= until) and written <= now and now - written <= 120
