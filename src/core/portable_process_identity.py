"""Process generations and concrete TTY identity for the portable ordinary writer."""

import ctypes
import errno
import os
import platform
import re
import stat
import sys
import time

from portable_policy import check_deadline


class _Timeval(ctypes.Structure):
    _fields_ = [("seconds", ctypes.c_long), ("microseconds", ctypes.c_int32)]


class _KernelProcess(ctypes.Structure):
    # Public kinfo_proc on Darwin arm64/x86_64; unrelated fields stay opaque.
    _fields_ = [
        ("start", _Timeval), ("unused_before_flags", ctypes.c_byte * 16),
        ("flags", ctypes.c_int32), ("status", ctypes.c_int8),
        ("status_padding", ctypes.c_byte * 3), ("pid", ctypes.c_int32),
        ("unused_before_parent", ctypes.c_byte * 516),
        ("parent", ctypes.c_int32), ("group", ctypes.c_int32),
        ("unused_job_control", ctypes.c_byte * 4),
        ("device", ctypes.c_int32), ("foreground", ctypes.c_int32),
        ("unused_tail", ctypes.c_byte * 68)
    ]


_KERNEL_LAYOUT_SUPPORTED = (
    platform.machine() in {"arm64", "x86_64"} and sys.byteorder == "little"
    and ctypes.sizeof(ctypes.c_void_p) == 8 and ctypes.sizeof(_Timeval) == 16
    and _Timeval.microseconds.offset == 8
    and ctypes.sizeof(_KernelProcess) == 648 and ctypes.alignment(_KernelProcess) == 8
    and all(getattr(_KernelProcess, name).offset == offset for name, offset in {
        "start": 0, "flags": 32, "status": 36, "pid": 40,
        "parent": 560, "group": 564, "device": 572, "foreground": 576
    }.items())
)
_sysctl = None
_libproc = None
if sys.platform == "darwin":
    try:
        _sysctl = ctypes.CDLL("/usr/lib/libSystem.B.dylib", use_errno=True).sysctl
        _sysctl.argtypes = [ctypes.POINTER(ctypes.c_int), ctypes.c_uint, ctypes.c_void_p,
                           ctypes.POINTER(ctypes.c_size_t), ctypes.c_void_p, ctypes.c_size_t]
        _sysctl.restype = ctypes.c_int
    except (OSError, AttributeError):
        _sysctl = None
    try:
        _libproc = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
        _libproc.proc_pidpath.argtypes = [ctypes.c_int32, ctypes.c_void_p, ctypes.c_uint32]
        _libproc.proc_pidpath.restype = ctypes.c_int32
    except (OSError, AttributeError):
        _libproc = None


def inspect(pid):
    if type(pid) is not int or not 0 < pid <= 2_147_483_647:
        return None
    if sys.platform == "linux":
        return _linux_inspect(pid)
    if sys.platform != "darwin" or _sysctl is None or not _KERNEL_LAYOUT_SUPPORTED:
        return None
    value = _KernelProcess()
    size = ctypes.c_size_t(ctypes.sizeof(value))
    mib = (ctypes.c_int * 4)(1, 14, 1, pid)  # CTL_KERN, KERN_PROC, KERN_PROC_PID
    if (_sysctl(mib, len(mib), ctypes.byref(value), ctypes.byref(size), None, 0) != 0
            or size.value != ctypes.sizeof(value)):
        return None
    if (value.pid != pid or value.start.seconds <= 0
            or not 0 <= value.start.microseconds < 1_000_000 or value.status not in {2, 3, 4}
            or value.flags & 0x2000 or value.parent < 0 or value.group < 0
            or value.foreground < -1):  # P_WEXIT; bit 4 is the ordinary P_LP64 flag.
        return None
    return {
        "generation": {"pid": pid, "startSeconds": value.start.seconds,
                       "startMicroseconds": value.start.microseconds},
        "parentPID": value.parent, "group": value.group,
        "device": value.device & 0xFFFFFFFF, "foregroundGroup": value.foreground & 0xFFFFFFFF,
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
            and producer.get("linuxScope") == foreground.get("linuxScope")
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
        if parent["generation"].get("linuxScope") != seed.get("linuxScope"):
            return None
        visited.add(parent_pid)
        owner = parent
    generation = owner["generation"].copy()
    again = lookup(generation["pid"])
    return generation if again is not None and again["generation"] == generation else None


def caller_ancestor(caller, device=None, lookup=None, start=None, deadline=None):
    lookup = inspect if lookup is None else lookup
    current = os.getpid() if start is None else start
    deadline = time.monotonic_ns()+100_000_000 if deadline is None else deadline
    if type(caller) is not int or not 0 < caller <= 2**31-1:
        raise OSError(errno.EINVAL, "Invalid helper caller")
    seen = set()
    origin = None
    for _ in range(16):
        check_deadline(deadline)
        if current in seen:
            raise OSError(errno.EINVAL, "Cyclic helper ancestry")
        seen.add(current)
        source = lookup(current)
        check_deadline(deadline)
        generation = source["generation"] if source is not None else None
        if (generation is None or generation["pid"] != current
                or type(generation["startSeconds"]) is not int or not 0 < generation["startSeconds"] < 2**64
                or type(generation["startMicroseconds"]) is not int or not 0 <= generation["startMicroseconds"] < 1_000_000):
            raise OSError(errno.EINVAL, "Helper ancestry unavailable")
        if origin is None:
            origin = generation
        elif generation.get("linuxScope") != origin.get("linuxScope"):
            raise OSError(errno.EINVAL, "Helper ancestry scope changed")
        if current == caller:
            again = lookup(caller)
            check_deadline(deadline)
            if (device is not None and source["device"] != device
                    or again is None or again["generation"] != generation or again["device"] != source["device"]):
                raise OSError(errno.EINVAL, "Helper caller changed")
            return generation.copy()
        parent = source["parentPID"]
        if type(parent) is not int or not 1 < parent <= 2**31-1:
            raise OSError(errno.EINVAL, "Helper caller unavailable")
        current = parent
    raise OSError(errno.EINVAL, "Helper caller ancestry too deep")
