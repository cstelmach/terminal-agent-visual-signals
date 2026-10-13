"""Current physical target proof and ordinary-output admission, without native control."""

import errno
import os
from pathlib import Path
import stat
import time

from portable_policy import check_deadline
from portable_process_identity import continuing_owner, device_number, inspect
from portable_records import _target as validate_shape, key, read_record, target_path


def _missing(pid):
    try:
        os.kill(pid, 0)
    except OSError as error:
        return error.errno == errno.ESRCH
    return False


def _descriptor_device(fd):
    info = os.fstat(fd)
    return info.st_rdev if stat.S_ISCHR(info.st_mode) else None


def _device_missing(path):
    try:
        os.lstat(path)
    except OSError as error:
        return error.errno in {errno.ENOENT, errno.ENXIO}
    return False


def _physical(target):
    owner = target["ttyOwner"]
    return target["tty"], target["device"], owner["pid"], owner["startSeconds"], owner["startMicroseconds"]


def _binding(target):
    surface = target.get("nativeSurface")
    app = surface["application"] if surface else None
    native = (app["pid"], app["startSeconds"], app["startMicroseconds"], surface["terminalID"]) if app else None
    return _physical(target), native


def _open_directory(path, deadline, parent_fd=None):
    check_deadline(deadline)
    name = path.name if parent_fd is not None else path
    try:
        before = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
    except FileNotFoundError:
        check_deadline(deadline)
        return None
    if not stat.S_ISDIR(before.st_mode):
        raise OSError(errno.EINVAL, "Unavailable visual directory")
    fd = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=parent_fd)
    try:
        opened = os.fstat(fd)
        check_deadline(deadline)
        if (opened.st_dev, opened.st_ino) != (before.st_dev, before.st_ino):
            raise OSError(errno.ESTALE, "Changed visual directory")
        return fd
    except BaseException:
        os.close(fd)
        raise


def _same_directory(path, fd, deadline):
    check_deadline(deadline)
    current, opened = os.lstat(path), os.fstat(fd)
    if not stat.S_ISDIR(current.st_mode) or (current.st_dev, current.st_ino) != (opened.st_dev, opened.st_ino):
        raise OSError(errno.ESTALE, "Changed visual directory")
    check_deadline(deadline)


def _walk(path, fd, deadline):
    with os.scandir(fd) as entries:
        for entry in entries:
            check_deadline(deadline)
            if entry.name.startswith("."):
                continue
            info = entry.stat(follow_symlinks=False)
            child = path / entry.name
            if stat.S_ISLNK(info.st_mode):
                raise OSError(errno.EINVAL, "Linked visual state")
            if stat.S_ISDIR(info.st_mode):
                child_fd = _open_directory(child, deadline, fd)
                if child_fd is None:
                    raise OSError(errno.ESTALE, "Changed visual directory")
                try:
                    yield from _walk(child, child_fd, deadline)
                finally:
                    os.close(child_fd)
            else:
                yield child, fd
    _same_directory(path, fd, deadline)


class Store:
    def __init__(self, runtime, policy, lookup=inspect, process_missing=_missing,
                 device=device_number, descriptor_device=_descriptor_device, clock=time.time,
                 device_missing=_device_missing):
        self.directory = Path(runtime) / "organizer"
        self.policy, self.lookup, self.process_missing = policy, lookup, process_missing
        self.device, self.descriptor_device, self.clock = device, descriptor_device, clock
        self.device_missing = device_missing

    def _lookup(self, pid, deadline):
        check_deadline(deadline)
        value = self.lookup(pid)
        check_deadline(deadline)
        return value

    def status(self, target, deadline, descriptor=None):
        check_deadline(deadline)
        try:
            validate_shape(target)
        except (ValueError, TypeError):
            return "unavailable"
        owner = self._lookup(target["ttyOwner"]["pid"], deadline)
        if owner is not None and owner["generation"] != target["ttyOwner"]:
            return "vanished"
        if owner is None:
            absent = self.process_missing(target["ttyOwner"]["pid"])
            check_deadline(deadline)
            if absent:
                return "vanished"
        number = self.device(target["tty"])
        check_deadline(deadline)
        if number is not None and number != target["device"]:
            return "vanished"
        if number is None:
            absent = self.device_missing(target["tty"])
            check_deadline(deadline)
            return "vanished" if absent else "unavailable"
        surface = target.get("nativeSurface")
        if surface is not None:
            app = self._lookup(surface["application"]["pid"], deadline)
            if app is None:
                absent = self.process_missing(surface["application"]["pid"])
                check_deadline(deadline)
                return "vanished" if absent else "unavailable"
            if app["generation"] != surface["application"]:
                return "vanished"
        if owner is None or owner["device"] != target["device"]:
            return "unavailable"
        if descriptor is not None:
            number = self.descriptor_device(descriptor)
            check_deadline(deadline)
            if number != target["device"]:
                return "unavailable"
        check_deadline(deadline)
        return "valid"

    def cached(self, tty, deadline, targets_only=False):
        targets, effects, descriptors = [], [], []
        path = self.directory
        try:
            parent = None
            for part in (None, "targets", key(tty)):
                if part is not None:
                    path = path / part
                fd = _open_directory(path, deadline, parent)
                if fd is None:
                    for directory, held in descriptors:
                        _same_directory(directory, held, deadline)
                    return targets, effects
                descriptors.append((path, fd))
                parent = fd
            for record_path, parent_fd in _walk(path, fd, deadline):
                filename = record_path.name
                if targets_only and filename != "target.json":
                    continue
                if filename not in {"target.json", "effect.json", "preview.json", "focus.json", "bound-intent.json"}:
                    continue
                kind = "target" if filename == "target.json" else "intent" if filename == "bound-intent.json" else "effect"
                record = read_record(filename, kind, self.clock(), deadline, dir_fd=parent_fd)
                if record is None:
                    raise OSError(errno.ESTALE, "Changed visual record")
                if kind == "intent":
                    saved = read_record("target.json", "target", self.clock(), deadline, dir_fd=parent_fd)
                    if saved is None:
                        raise OSError(errno.EINVAL, "Unbound visual intent")
                    target = saved["target"]
                    if (record["tty"] != target["tty"] or record.get("device") != target["device"]
                            or record.get("producer") is None):
                        raise OSError(errno.EINVAL, "Unbound visual intent")
                else:
                    target = record["target"]
                if target["tty"] != tty or record_path != target_path(self.directory, target, filename):
                    raise OSError(errno.EINVAL, "Misplaced visual record")
                if kind == "effect":
                    slot = "preview.json" if record["kind"] == "preview" else "focus.json" if record["kind"] == "focus" else "effect.json"
                    if filename != slot:
                        raise OSError(errno.EINVAL, "Misplaced visual effect")
                    effects.append((record_path, record))
                targets.append(target)
            for directory, fd in descriptors:
                _same_directory(directory, fd, deadline)
            return targets, effects
        except (ValueError, RecursionError) as error:
            raise OSError(errno.EINVAL, "Invalid cached visual state") from error
        finally:
            for _, fd in reversed(descriptors):
                os.close(fd)

    def _current(self, target, deadline, descriptor=None, targets_only=False):
        if self.status(target, deadline, descriptor) != "valid":
            raise OSError(errno.ESTALE, "Current visual target unavailable")
        targets, effects = self.cached(target["tty"], deadline, targets_only=targets_only)
        live = {_binding(target): target}
        for candidate in targets:
            status = self.status(candidate, deadline)
            if status == "unavailable":
                raise OSError(errno.EAGAIN, "Visual binding unavailable")
            if status == "valid":
                if _physical(candidate) != _physical(target):
                    raise OSError(errno.EBUSY, "Competing visual owner")
                live[_binding(candidate)] = candidate
        if len({identity[1] for identity in live if identity[1] is not None}) > 1:
            raise OSError(errno.EBUSY, "Ambiguous native surface")
        return list(live.values()), [(path, effect) for path, effect in effects if _binding(effect["target"]) in live]

    def resolve(self, tty, producer, deadline, targets_only=False):
        check_deadline(deadline)
        device = self.device(tty)
        check_deadline(deadline)
        owner = continuing_owner(producer, device, lambda pid: self._lookup(pid, deadline)) if device is not None else None
        if owner is None:
            raise OSError(errno.ESTALE, "Current TTY owner unavailable")
        plain = {"tty": tty, "device": device, "ttyOwner": owner}
        aliases, _ = self._current(plain, deadline, targets_only=targets_only)
        target = next((candidate for candidate in aliases if candidate.get("nativeSurface") is not None), plain)
        if self.status(target, deadline) != "valid":
            raise OSError(errno.ESTALE, "Visual target changed")
        check_deadline(deadline)
        return target

    def ordinary_ownership(self, target, revision, descriptor, deadline):
        """Require the caller's shared output lock; return obsolete active records to cancel."""
        if not self.policy.matches(revision, deadline):
            raise OSError(errno.ESTALE, "Visual suspension revision changed")
        _, effects = self._current(target, deadline, descriptor)
        if self.policy.restricted(deadline):
            raise OSError(errno.EBUSY, "Native visual rule owns output")
        suspended = self.policy.suspended(deadline)
        obsolete = []
        for path, effect in effects:
            check_deadline(deadline)
            if not effect["active"]:
                continue
            live = effect["kind"] != "globalRestriction" and not (suspended and effect["kind"] != "preview")
            age = self.clock() - effect["heartbeatAt"]
            live = live and age >= 0 and (age < 2 if effect["kind"] == "preview" else age <= 6)
            identity = effect.get("revision")
            live = live and (identity is None or (identity["device"], identity["inode"]) == revision.identity)
            if live:
                controller = self._lookup(effect["controller"]["pid"], deadline)
                if controller is None:
                    absent = self.process_missing(effect["controller"]["pid"])
                    check_deadline(deadline)
                    if not absent:
                        raise OSError(errno.EAGAIN, "Visual controller unavailable")
                    live = False
                else:
                    live = controller["generation"] == effect["controller"]
            if live:
                raise OSError(errno.EBUSY, "Native visual effect owns output")
            obsolete.append((path, effect))
        if not self.policy.matches(revision, deadline) or self.status(target, deadline, descriptor) != "valid":
            raise OSError(errno.ESTALE, "Visual ownership changed")
        check_deadline(deadline)
        return obsolete
