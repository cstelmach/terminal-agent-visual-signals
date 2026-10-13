"""Bounded typed record replacement through held parent directories."""

from contextlib import contextmanager
import errno
import json
import os
from pathlib import Path
import stat
import uuid

from portable_ownership import _open_directory, _same_directory
from portable_policy import check_deadline
from portable_records import decode, read_record


@contextmanager
def parent_directory(root, path, deadline, create=False):
    root, path = Path(root), Path(path)
    try:
        components = path.relative_to(root).parts
    except ValueError as error:
        raise OSError(errno.EINVAL, "Record path outside runtime") from error
    if (not root.is_absolute() or not path.is_absolute() or not components
            or any(part in {".", "..", ""} for part in components)):
        raise OSError(errno.EINVAL, "Invalid record path")
    check_deadline(deadline)
    if create:
        root.mkdir(mode=0o700, parents=True, exist_ok=True)
        check_deadline(deadline)
    held = []
    directory = root
    try:
        fd = _open_directory(directory, deadline)
        if fd is not None:
            held.append((directory, fd))
            for component in components[:-1]:
                if create:
                    check_deadline(deadline)
                    try:
                        os.mkdir(component, mode=0o700, dir_fd=fd)
                    except FileExistsError:
                        pass
                    check_deadline(deadline)
                directory = directory / component
                child = _open_directory(directory, deadline, fd)
                if child is None:
                    fd = None
                    break
                held.append((directory, child))
                fd = child
        if create and fd is None:
            raise OSError(errno.ESTALE, "Changed record directory")
        for directory, opened in held:
            _same_directory(directory, opened, deadline)
        yield fd
        for directory, opened in held:
            _same_directory(directory, opened, deadline)
        check_deadline(deadline)
    finally:
        for _, opened in reversed(held):
            os.close(opened)


def read(root, path, kind, now, deadline):
    with parent_directory(root, path, deadline) as fd:
        if fd is None:
            return None
        return read_record(Path(path).name, kind, now, deadline, dir_fd=fd)


def read_latest(root, path, kind, now, deadline, recover_invalid):
    try:
        return read(root, path, kind, now, deadline)
    except OSError as error:
        if not recover_invalid or error.errno not in {errno.EINVAL, errno.EFBIG}:
            raise
    except ValueError:
        if not recover_invalid:
            raise
    # Invalid data can be repaired, but links and unavailable storage cannot.
    with parent_directory(root, path, deadline) as parent:
        if parent is None or not stat.S_ISREG(os.stat(Path(path).name, dir_fd=parent, follow_symlinks=False).st_mode):
            raise OSError(errno.EINVAL, "Latest visual record unavailable")
        check_deadline(deadline)
    return None


def write(root, path, record, kind, now, deadline):
    check_deadline(deadline)
    try:
        data = json.dumps(record, ensure_ascii=False, allow_nan=False, separators=(",", ":")).encode("utf-8")
        decode(data, kind, now)
    except (ValueError, TypeError, OverflowError, RecursionError) as error:
        raise OSError(errno.EINVAL, "Invalid record publication") from error
    check_deadline(deadline)
    with parent_directory(root, path, deadline, create=True) as parent:
        name = Path(path).name
        try:
            current = os.stat(name, dir_fd=parent, follow_symlinks=False)
        except FileNotFoundError:
            current = None
        check_deadline(deadline)
        if current is not None and not stat.S_ISREG(current.st_mode):
            raise OSError(errno.EINVAL, "Invalid record destination")
        temporary = ".record-" + str(uuid.uuid4()) + ".tmp"
        fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW
                     | os.O_NONBLOCK | os.O_CLOEXEC, 0o600, dir_fd=parent)
        try:
            written = 0
            while written < len(data):
                check_deadline(deadline)
                try:
                    count = os.write(fd, data[written:])
                except InterruptedError:
                    continue
                check_deadline(deadline)
                if count <= 0:
                    raise OSError(errno.EIO, "Incomplete record publication")
                written += count
            check_deadline(deadline)
            os.replace(temporary, name, src_dir_fd=parent, dst_dir_fd=parent)
            check_deadline(deadline)
        finally:
            try:
                os.close(fd)
            finally:
                try:
                    os.unlink(temporary, dir_fd=parent)
                except FileNotFoundError:
                    pass
