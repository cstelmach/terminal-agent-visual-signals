#!/usr/bin/env python3
"""Trusted legacy lock mutations under one bounded read/merge/replace transaction."""

import errno
import os
import sys
import time
import uuid

from portable_device_writer import output_lock
from portable_ownership import _open_directory, _same_directory
from portable_policy import _epoch, _policy_path, check_deadline, read_regular
from portable_render import normalized_hex


def _number(value):
    number = _epoch(value)
    if number is None:
        raise ValueError("Invalid lock time")
    return number


def _color(value):
    return normalized_hex(value) if value else ""


def _parse(data):
    text = data.decode("utf-8")
    if "\0" in text:
        raise ValueError("Invalid lock state")
    fields = {}
    for line in text.split("\n"):
        key, equal, value = line.partition("=")
        if equal:
            if value.startswith('"'):
                value = value[1:]
            if value.endswith('"'):
                value = value[:-1]
            fields[key] = value
    if "LOCKED" not in fields or fields.get("SCHEMA_VERSION", "1") != "1":
        raise ValueError("Invalid lock state")
    return {
        "LOCKED": "true" if fields["LOCKED"] == "true" else "false",
        "REASON": "schedule" if fields.get("REASON") == "schedule" else "manual",
        "LOCK_UNTIL_EPOCH": str(_number(fields.get("LOCK_UNTIL_EPOCH"))),
        "UNLOCK_UNTIL_EPOCH": str(_epoch(fields.get("UNLOCK_UNTIL_EPOCH")) or 0),
        "WRITTEN_EPOCH": str(_epoch(fields.get("WRITTEN_EPOCH")) or 0),
        "LOCK_BG": fields.get("LOCK_BG", ""), "LOCK_FG": fields.get("LOCK_FG", ""),
        "SCHEMA_VERSION": "1",
    }


def update(path, operation, values, now, deadline):
    check_deadline(deadline)
    now = _number(str(now))
    if operation == "now" and len(values) == 3:
        until, bg, fg = _number(values[0]), _color(values[1]), _color(values[2])
        if until <= now:
            raise ValueError("Expired lock time")
    elif operation == "grant" and len(values) == 1:
        until = _number(values[0])
        if until <= now:
            raise ValueError("Expired grant time")
    elif operation == "replace" and len(values) == 6:
        if values[0] not in {"true", "false"} or values[1] not in {"manual", "schedule"}:
            raise ValueError("Invalid lock definition")
        until, grant = _number(values[2]), _number(values[3])
        bg, fg = _color(values[4]), _color(values[5])
    else:
        raise ValueError("Invalid lock operation")
    path = _policy_path(path, deadline)
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    path = _policy_path(path, deadline)
    parent = _open_directory(path.parent, deadline)
    if parent is None:
        raise OSError(errno.ESTALE, "Lock directory changed")
    committed = False
    try:
        with output_lock(str(path) + ".lock", deadline):
            _policy_path(path, deadline)
            _same_directory(path.parent, parent, deadline)
            data = read_regular(path.name, deadline, 8192, dir_fd=parent)
            current = _parse(data) if data is not None else None
            if operation == "grant":
                if current is None:
                    raise OSError(errno.ENOENT, "Lock state absent")
                result = dict(current, UNLOCK_UNTIL_EPOCH=str(until), WRITTEN_EPOCH=str(now))
            else:
                if operation == "now":
                    previous = int(current["LOCK_UNTIL_EPOCH"]) if current and current["LOCKED"] == "true" else 0
                    until, grant = max(until, previous), 0
                result = {"LOCKED": "true" if operation == "now" else values[0],
                          "REASON": "manual" if operation == "now" else values[1],
                          "LOCK_UNTIL_EPOCH": str(until), "UNLOCK_UNTIL_EPOCH": str(grant),
                          "WRITTEN_EPOCH": str(now), "LOCK_BG": bg, "LOCK_FG": fg,
                          "SCHEMA_VERSION": "1"}
            payload = "".join(key + '="' + value + '"\n' for key, value in result.items()).encode("utf-8")
            if len(payload) > 8192:
                raise OSError(errno.EFBIG, "Oversized lock state")
            _policy_path(path, deadline)
            _same_directory(path.parent, parent, deadline)
            temporary = ".lock-state-" + str(uuid.uuid4()) + ".tmp"
            fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW
                         | os.O_NONBLOCK | os.O_CLOEXEC, 0o600, dir_fd=parent)
            try:
                offset = 0
                while offset < len(payload):
                    check_deadline(deadline)
                    try:
                        count = os.write(fd, payload[offset:])
                    except InterruptedError:
                        continue
                    if count <= 0:
                        raise OSError(errno.EIO, "Incomplete lock state")
                    offset += count
                _policy_path(path, deadline)
                _same_directory(path.parent, parent, deadline)
                os.replace(temporary, path.name, src_dir_fd=parent, dst_dir_fd=parent)
                committed = True
            finally:
                try:
                    os.close(fd)
                finally:
                    try:
                        os.unlink(temporary, dir_fd=parent)
                    except FileNotFoundError:
                        pass
    except OSError:
        # Successful replacement commits the state; cleanup errors cannot undo it.
        if not committed:
            raise
    finally:
        try:
            os.close(parent)
        except OSError:
            if not committed:
                raise
    return int(result["LOCK_UNTIL_EPOCH"])


if __name__ == "__main__":
    try:
        print(update(sys.argv[1], sys.argv[2], sys.argv[3:], int(time.time()),
                     time.monotonic_ns() + 100_000_000))
    except (OSError, ValueError, IndexError):
        print("Lock state mutation unavailable.", file=sys.stderr)
        sys.exit(1)
