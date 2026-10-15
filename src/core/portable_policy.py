"""Read suspension and legacy rules as bounded data, never shell code."""

import errno
import os
from pathlib import Path
import re
import stat
import sys
import time


class InvalidRegularFileError(OSError):
    pass


def check_deadline(deadline):
    if time.monotonic_ns() >= deadline:
        raise OSError(errno.ETIMEDOUT, "Policy deadline exceeded")


def _owned(info):
    return info.st_uid == os.geteuid() and not info.st_mode & 0o022


def open_regular(path, deadline, limit, dir_fd=None):
    check_deadline(deadline)
    try:
        before = os.lstat(path, dir_fd=dir_fd)
    except FileNotFoundError:
        check_deadline(deadline)
        return None
    check_deadline(deadline)
    if not _owned(before):
        raise OSError(errno.EACCES, "Untrusted policy file")
    if not stat.S_ISREG(before.st_mode) or not 0 <= before.st_size <= limit:
        raise InvalidRegularFileError(errno.EINVAL, "Unavailable policy file")
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC, dir_fd=dir_fd)
    try:
        current = os.fstat(fd)
        check_deadline(deadline)
        if not _owned(current):
            raise OSError(errno.EACCES, "Untrusted policy file")
        if (not stat.S_ISREG(current.st_mode) or not 0 <= current.st_size <= limit
                or (before.st_dev, before.st_ino) != (current.st_dev, current.st_ino)):
            raise InvalidRegularFileError(errno.EINVAL, "Changed policy file")
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
            raise InvalidRegularFileError(errno.EFBIG, "Oversized policy file")


def read_regular(path, deadline, limit=1_048_576, dir_fd=None):
    fd = open_regular(path, deadline, limit, dir_fd=dir_fd)
    if fd is None:
        return None
    try:
        return read_fd(fd, deadline, limit)
    finally:
        os.close(fd)


def _policy_path(path, deadline):
    check_deadline(deadline)
    path = Path(path)
    if (not path.is_absolute() or ".." in path.parts or len(path.parts) < 3
            or len(str(path).encode("utf-8")) > 4096):
        raise OSError(errno.EINVAL, "Unavailable policy path")
    parts, current = path.parts[1:-1], Path("/")
    temporary = {Path("/private/tmp"), Path("/private/var/tmp")} if sys.platform == "darwin" else {
        Path("/tmp"), Path("/var/tmp")}
    for index, part in enumerate(parts):
        check_deadline(deadline)
        current = current / part
        try:
            info = os.lstat(current)
        except FileNotFoundError:
            check_deadline(deadline)
            return current.joinpath(*parts[index + 1:], path.name)
        check_deadline(deadline)
        leaf = index == len(parts) - 1
        if stat.S_ISLNK(info.st_mode):
            if (leaf or sys.platform != "darwin" or current not in {Path("/tmp"), Path("/var")}
                    or info.st_uid != 0):
                raise OSError(errno.EACCES, "Linked policy directory")
            target = "/private" + str(current)
            if os.readlink(current) not in {target, target[1:]}:
                raise OSError(errno.EACCES, "Changed system policy alias")
            private = os.lstat("/private")
            if (not stat.S_ISDIR(private.st_mode) or private.st_uid != 0
                    or private.st_mode & 0o022 or not os.access("/private", os.X_OK)):
                raise OSError(errno.EACCES, "Unavailable system policy directory")
            current = Path(target)
            info = os.lstat(current)
            check_deadline(deadline)
        owner = info.st_uid == os.geteuid() if leaf else info.st_uid in {0, os.geteuid()}
        sticky = (not leaf and info.st_uid == 0 and info.st_mode & stat.S_ISVTX and current in temporary)
        if (not stat.S_ISDIR(info.st_mode) or not owner or (info.st_mode & 0o022 and not sticky)
                or not os.access(current, os.X_OK)):
            raise OSError(errno.EACCES, "Unavailable policy directory")
        check_deadline(deadline)
    return current / path.name


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
        fd = open_regular(_policy_path(self.marker, deadline), deadline, 127)
        try:
            if fd is not None and read_fd(fd, deadline, 127) not in (self._marker(False), self._marker(True)):
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
        return self.matches_identity(revision.identity, deadline)

    def matches_identity(self, identity, deadline):
        check_deadline(deadline)
        path = _policy_path(self.marker, deadline)
        try:
            info = os.lstat(path)
        except FileNotFoundError:
            check_deadline(deadline)
            return identity == (0, 0)
        if not stat.S_ISREG(info.st_mode) or not _owned(info):
            raise OSError(errno.EINVAL, "Unavailable suspension state")
        check_deadline(deadline)
        return identity[1] != 0 and identity == (info.st_dev, info.st_ino)

    def suspended(self, deadline):
        data = read_regular(_policy_path(self.marker, deadline), deadline, 127)
        if data is None:
            return False
        if data not in (self._marker(False), self._marker(True)):
            raise OSError(errno.EINVAL, "Unavailable suspension state")
        return data == self._marker(True)

    def restricted(self, deadline, unavailable_disabled=False):
        def enabled():
            try:
                return not self.suspended(deadline)
            except OSError as error:
                check_deadline(deadline)
                if not unavailable_disabled or error.errno == errno.ETIMEDOUT:
                    raise
                return False
        if not enabled():
            return False
        data = read_regular(_policy_path(self.runtime / "lock.state", deadline), deadline, 8192)
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
            data = read_regular(_policy_path(self.marker.parent / "mute.state", deadline), deadline, 8192)
            fields = _fields(data) if data is not None else None
            selected = bool(fields and self._soft(fields, deadline))
        check_deadline(deadline)
        return selected and enabled()

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
