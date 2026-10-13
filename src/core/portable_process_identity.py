"""Process generations and concrete TTY identity for the portable ordinary writer."""

import ctypes
import os
import re
import stat
import sys
import time


class _BSDInfo(ctypes.Structure):
    _fields_ = [(name, ctypes.c_uint32) for name in (
        "pbi_flags", "pbi_status", "pbi_xstatus", "pbi_pid", "pbi_ppid", "pbi_uid",
        "pbi_gid", "pbi_ruid", "pbi_rgid", "pbi_svuid", "pbi_svgid", "rfu_1"
    )] + [
        ("pbi_comm", ctypes.c_char * 16), ("pbi_name", ctypes.c_char * 32)
    ] + [(name, ctypes.c_uint32) for name in (
        "pbi_nfiles", "pbi_pgid", "pbi_pjobc", "e_tdev", "e_tpgid"
    )] + [
        ("pbi_nice", ctypes.c_int32), ("pbi_start_tvsec", ctypes.c_uint64),
        ("pbi_start_tvusec", ctypes.c_uint64)
    ]


_libproc = None
if sys.platform == "darwin":
    try:
        _libproc = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
        _libproc.proc_pidinfo.argtypes = [
            ctypes.c_int32, ctypes.c_int32, ctypes.c_uint64, ctypes.c_void_p, ctypes.c_int32
        ]
        _libproc.proc_pidinfo.restype = ctypes.c_int32
        _libproc.proc_pidpath.argtypes = [ctypes.c_int32, ctypes.c_void_p, ctypes.c_uint32]
        _libproc.proc_pidpath.restype = ctypes.c_int32
    except (OSError, AttributeError):
        _libproc = None


def inspect(pid):
    if type(pid) is not int or not 0 < pid <= 2_147_483_647:
        return None
    if sys.platform == "linux":
        return _linux_inspect(pid)
    if _libproc is None:
        return None
    value = _BSDInfo()
    size = ctypes.sizeof(value)
    if size != 136 or _libproc.proc_pidinfo(pid, 3, 0, ctypes.byref(value), size) != size:
        return None
    if (value.pbi_pid != pid or value.pbi_start_tvsec == 0
            or value.pbi_start_tvusec >= 1_000_000 or value.pbi_status == 5
            or value.pbi_flags & 4):
        return None
    return {
        "generation": {"pid": pid, "startSeconds": value.pbi_start_tvsec,
                       "startMicroseconds": value.pbi_start_tvusec},
        "parentPID": value.pbi_ppid, "group": value.pbi_pgid,
        "device": value.e_tdev, "foregroundGroup": value.e_tpgid,
    }


def executable_path(pid):
    if sys.platform != "darwin" or _libproc is None or type(pid) is not int or not 0 < pid <= 2**31-1:
        return None
    path = ctypes.create_string_buffer(4096)
    if _libproc.proc_pidpath(pid, path, len(path)) <= 0:
        return None
    try:
        return path.value.decode("utf-8")
    except UnicodeError:
        return None


def foreground_family_contains(producer, foreground, device, lookup=inspect):
    source, current = lookup(producer["pid"]), lookup(foreground["pid"])
    return (device != 2**32-1 and source is not None and current is not None
            and source["generation"] == producer and current["generation"] == foreground
            and source["device"] == device and current["device"] == device
            and 0 < current["foregroundGroup"] <= 2**31-1
            and current["group"] == current["foregroundGroup"]
            and source["group"] == current["foregroundGroup"]
            and source["foregroundGroup"] == current["foregroundGroup"])


def _parse_linux_stat(data, pid, hz, boot_ns, scope):
    if len(data) > 8192 or not 0 < hz <= 1_000_000 or 1_000_000_000 % hz:
        return None
    left, right = data.find(b"("), data.rfind(b") ")
    if left < 1 or right < left or data[:left].strip() != str(pid).encode("ascii"):
        return None
    fields = data[right + 2:].split()
    if len(fields) < 20 or fields[0] not in {b"R", b"S", b"D", b"T", b"t", b"I", b"W", b"P", b"K"}:
        return None
    numbers = [fields[i] for i in (1, 2, 4, 5, 19)]
    if any(re.fullmatch(rb"-?[0-9]+", value) is None for value in numbers):
        return None
    parent, group, device, foreground, ticks = map(int, numbers)
    if (not 0 <= parent <= 2_147_483_647 or not 0 <= group <= 2_147_483_647
            or not -2_147_483_648 <= device <= 2_147_483_647
            or not -1 <= foreground <= 2_147_483_647 or not 0 <= ticks < 2**64):
        return None
    # A generation is accepted only after its entire birth tick has passed.
    if boot_ns // (1_000_000_000 // hz) <= ticks:
        return None
    seconds, remainder = divmod(ticks, hz)
    if seconds + 1 >= 2**64:
        return None
    return {
        "generation": {"pid": pid, "startSeconds": seconds + 1,
                       "startMicroseconds": remainder * 1_000_000 // hz, "linuxScope": scope},
        "parentPID": parent, "group": group,
        "device": device & 0xFFFFFFFF if device else 0xFFFFFFFF,
        "foregroundGroup": max(0, foreground),
    }


def _read_proc(directory, name, limit):
    fd = os.open(name, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK,
                 dir_fd=directory)
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            raise ValueError("Process identity unavailable")
        data = bytearray()
        while len(data) <= limit:
            chunk = os.read(fd, min(4096, limit + 1 - len(data)))
            if not chunk:
                return bytes(data)
            data.extend(chunk)
        raise ValueError("Process identity unavailable")
    finally:
        os.close(fd)


def _namespace(directory, name):
    # Proc namespace links are the kernel's documented object-reference interface.
    fd = os.open("ns/" + name, os.O_RDONLY | os.O_CLOEXEC, dir_fd=directory)
    try:
        value = os.fstat(fd)
        return [value.st_dev, value.st_ino]
    finally:
        os.close(fd)


def _linux_inspect(pid):
    descriptors = []
    try:
        flags = os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC
        current = os.open("/proc/self", flags)
        descriptors.append(current)
        status = _read_proc(current, "status", 16_384).splitlines()
        identifiers = [line.split()[1:] for line in status if line.startswith(b"NSpid:")]
        if identifiers != [[str(os.getpid()).encode("ascii")]]:
            return None
        target = os.open("/proc/" + str(pid), flags | os.O_NOFOLLOW)
        descriptors.append(target)
        pid_namespace, time_namespace = _namespace(current, "pid"), _namespace(current, "time")
        if (_namespace(target, "pid") != pid_namespace
                or _namespace(target, "time") != time_namespace):
            return None
        root = os.open("/proc", flags | os.O_NOFOLLOW)
        descriptors.append(root)
        boot = _read_proc(root, "sys/kernel/random/boot_id", 64).strip().decode("ascii")
        if re.fullmatch(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}", boot) is None:
            return None
        scope = {"bootID": boot, "pidNamespace": pid_namespace, "timeNamespace": time_namespace}
        offsets = {}
        for line in _read_proc(current, "timens_offsets", 256).splitlines():
            parts = line.split()
            if (len(parts) != 3 or parts[0] not in {b"monotonic", b"boottime"}
                    or parts[0] in offsets or re.fullmatch(rb"-?[0-9]+", parts[1]) is None
                    or re.fullmatch(rb"[0-9]+", parts[2]) is None
                    or not 0 <= int(parts[2]) < 1_000_000_000):
                return None
            offsets[parts[0]] = [int(parts[1]), int(parts[2])]
        if set(offsets) != {b"monotonic", b"boottime"}:
            return None
        scope["timeOffsets"] = [offsets[b"monotonic"], offsets[b"boottime"]]
        hz = os.sysconf("SC_CLK_TCK")
        first = _parse_linux_stat(_read_proc(target, "stat", 8192), pid, hz,
                                  time.clock_gettime_ns(time.CLOCK_BOOTTIME), scope)
        second = _parse_linux_stat(_read_proc(target, "stat", 8192), pid, hz,
                                   time.clock_gettime_ns(time.CLOCK_BOOTTIME), scope)
        if (_namespace(target, "pid") != pid_namespace
                or _namespace(target, "time") != time_namespace):
            return None
        return first if first is not None and first == second else None
    except (OSError, ValueError, UnicodeError, AttributeError):
        return None
    finally:
        for fd in descriptors:
            os.close(fd)


def device_number(path):
    if not isinstance(path, str) or len(path.encode("utf-8")) > 128:
        return None
    if not re.fullmatch(r"/dev/tty[A-Za-z0-9]+|/dev/pts/[0-9]+", path):
        return None
    try:
        value = os.lstat(path)
    except OSError:
        return None
    if not stat.S_ISCHR(value.st_mode) or not 0 <= value.st_rdev < 4_294_967_295:
        return None
    return value.st_rdev


def continuing_owner(seed, device, lookup=None):
    lookup = inspect if lookup is None else lookup
    if not isinstance(seed, dict) or type(seed.get("pid")) is not int:
        return None
    owner = lookup(seed["pid"])
    if owner is None or owner["generation"] != seed or owner["device"] != device:
        return None
    visited = {seed["pid"]}
    for _ in range(16):
        parent_pid = owner["parentPID"]
        if parent_pid <= 1:
            break
        if parent_pid > 2_147_483_647 or parent_pid in visited:
            return None
        parent = lookup(parent_pid)
        if parent is None or parent["generation"]["pid"] != parent_pid:
            return None
        if parent["device"] != device:
            break
        visited.add(parent_pid)
        owner = parent
    generation = owner["generation"].copy()
    again = lookup(generation["pid"])
    return generation if again is not None and again["generation"] == generation else None
