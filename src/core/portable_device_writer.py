"""One bounded device transaction; record policy is supplied by its typed caller."""

import errno
import fcntl
import json
import os
from pathlib import Path
import select
import signal
import stat
import time

from portable_process_identity import device_number


_children = set()


def reap_completed():
    for pid in tuple(_children):
        try:
            if os.waitpid(pid, os.WNOHANG)[0]:
                _children.discard(pid)
        except ChildProcessError:
            _children.discard(pid)


def _check(deadline):
    if time.monotonic_ns() >= deadline:
        raise OSError(errno.ETIMEDOUT, "Portable device output timed out")


def _perform(path, lock_path, before_open, prepare, deadline):
    _check(deadline)
    if before_open is not None:
        before_open(deadline)
    _check(deadline)
    expected = device_number(path)
    if expected is None:
        raise OSError(errno.EINVAL, "Invalid device")
    _check(deadline)
    fd = os.open(path, os.O_WRONLY | os.O_NONBLOCK | os.O_NOCTTY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        _check(deadline)
        opened = os.fstat(fd)
        if not stat.S_ISCHR(opened.st_mode) or opened.st_rdev != expected:
            raise OSError(errno.ESTALE, "Device changed")
        parent = Path(lock_path).parent
        parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        _check(deadline)
        if not stat.S_ISDIR(os.lstat(parent).st_mode):
            raise OSError(errno.EINVAL, "Invalid lock directory")
        lock = os.open(lock_path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC, 0o600)
        try:
            _check(deadline)
            info = os.fstat(lock)
            if (not stat.S_ISREG(info.st_mode) or info.st_mode & 0o777 != 0o600
                    or info.st_uid != os.geteuid()):
                raise OSError(errno.EINVAL, "Invalid output lock")
            while True:
                _check(deadline)
                try:
                    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    break
                except (BlockingIOError, InterruptedError):
                    time.sleep(min(0.001, max(0, (deadline - time.monotonic_ns()) / 1e9)))
            _check(deadline)
            data = prepare(fd, deadline)
            _check(deadline)
            if data is None:
                return False
            if not isinstance(data, bytes) or len(data) > 32_768:
                raise OSError(errno.EINVAL, "Invalid output payload")
            written = 0
            try:
                while written < len(data):
                    _check(deadline)
                    try:
                        count = os.write(fd, data[written:])
                    except InterruptedError:
                        continue
                    except BlockingIOError:
                        left = max(0, (deadline - time.monotonic_ns()) / 1e9)
                        select.select([], [fd], [], left)
                        continue
                    if count == 0:
                        raise OSError(errno.EIO, "Incomplete device output")
                    written += count
            except OSError as error:
                error.bytes_written = written
                raise
            return bool(data)
        finally:
            os.close(lock)
    finally:
        os.close(fd)


def write_managed(path, lock_path, before_open, prepare):
    reap_completed()
    deadline = time.monotonic_ns() + 100_000_000
    read_fd, write_fd = os.pipe()
    try:
        pid = os.fork()
    except OSError:
        os.close(read_fd); os.close(write_fd)
        raise
    if pid == 0:
        os.close(read_fd)
        # A wedged child must not keep a hook's stdin or result pipes alive.
        for descriptor in (0, 1, 2):
            if descriptor == write_fd:
                continue
            try:
                os.close(descriptor)
            except OSError:
                pass
        try:
            try:
                result = {"wrote": _perform(path, lock_path, before_open, prepare, deadline)}
            except Exception as error:
                result = {"errno": (error.errno or errno.EIO) if isinstance(error, OSError) else errno.EINVAL,
                          "bytes": getattr(error, "bytes_written", None)}
            try:
                os.write(write_fd, json.dumps(result).encode("ascii"))
            except OSError:
                pass
        finally:
            os._exit(0)
    os.close(write_fd)
    _children.add(pid)
    try:
        left = max(0, (deadline - time.monotonic_ns()) / 1e9)
        if not select.select([read_fd], [], [], left)[0]:
            failure = OSError(errno.ETIMEDOUT, "Portable device output timed out")
            failure.bytes_written = None
            raise failure
        value = json.loads(os.read(read_fd, 512))
        if "errno" in value:
            failure = OSError(value["errno"], "Portable device output unavailable")
            failure.bytes_written = value["bytes"]
            raise failure
        return value["wrote"]
    except (ValueError, KeyError):
        failure = OSError(errno.EIO, "Portable device output unavailable")
        failure.bytes_written = None
        raise failure from None
    finally:
        os.close(read_fd)
        try:
            if os.waitpid(pid, os.WNOHANG)[0] == 0:
                os.kill(pid, signal.SIGKILL)
            else:
                _children.discard(pid)
        except (ChildProcessError, ProcessLookupError):
            _children.discard(pid)
        reap_completed()
