Last Updated: 2026-10-13
Version: 1.0

# PARTIAL: Linux process generation and controlling TTY identity

Last updated: 2026-10-13. One guarded Flash quick scan.

The provider invocation succeeded and both quick-scan and final-report marker contracts passed.
The following AGY report is preserved as partial research evidence because its conclusions need
independent primary-source verification before implementation.

Host validation concerns, based only on the returned AGY output and runner evidence:

- The report says an open pidfd prevents numeric PID reallocation and holds a task struct. It does
  not supply a retrieved source excerpt establishing that exact guarantee. Treat this claim as
  unsupported here. Identity-safe operations through a pidfd and numeric `/proc/<pid>` lookups
  must not be conflated.
- The report's displayed `new_encode_dev` and glibc `makedev` formulas use the same placement for
  kernel-representable 12-bit major and 20-bit minor numbers. This contradicts the report's
  assertion that normalized raw comparison fails simply when a minor exceeds 255. The decoded
  major/minor comparison remains a clear recommendation, but the asserted reason is unreliable.
- The report labels `(pid, starttime_ticks)` a true generation token after admitting collisions
  from same-tick PID reuse. Treat tick-based identity as bounded by its stated resolution.
- The proposed pseudocode compares its two newly read starttimes but accepts no previously
  recorded generation token. It therefore does not establish identity with a prior registration.
  It also lacks strict numeric `/dev/pts/N` validation, allows unbounded proc reads, uses ASCII
  decoding for `comm`, and does not handle partial writes. It is illustrative, not a complete
  implementation of the requested writer contract.
- Namespace cancellation is described broadly despite whole-second `btime` truncation and
  tick-quantized starttime. Exact fractional-offset behavior remains insufficiently established.
- The AGY invocation log contains three `search_web` errors: timeout, no summary returned, and
  no candidates returned. The provider's `None found` gap claim does not acknowledge them.
  The preserved operational log does not contain fetched source payloads, so this host cannot
  independently confirm every claimed full-page retrieval or source date.

No corrective provider call or host-model replacement research was performed. No local repository
was in scope; fingerprint N/A before and after. No source, prompt, or report hashes were created.

Evidence directory:
`/tmp/agy-research/linux-process-identity-20261013T180607Z-ef5b9c94/`

Guarded runner invocation evidence:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/agy-failover-primary.qEYJ0y/`

Copied invocation log: `runner-agy-log`. Raw output: `quick-stdout.txt`.
Runner stderr was empty; guarded runner exit status was 0. The log records successful
primary-account authentication. The provider contract test passed before the call.

The report below is AGY output. Only the source-title em dash has been replaced with a colon
for the requested writing style; the raw provider output is retained unchanged in the evidence
files above.

===EXECUTIVE_SUMMARY===
Validating a target process and its controlling terminal from Python stdlib requires understanding the boundary between kernel-internal descriptors and userspace representations.

Field 22 of `/proc/<pid>/stat` (`starttime`) records boot-relative clock ticks at `USER_HZ` frequency, not an epoch timestamp. When converting to a `{pid, startSeconds, startMicroseconds}` schema, adding `/proc/stat` `btime` creates an epoch timestamp that is purely cosmetic. Because `btime` tracks `CLOCK_REALTIME` via `getboottime64()`, it fluctuates on NTP clock steps, whereas `starttime` remains fixed relative to boot. Furthermore, identical `starttime` ticks can be shared by rapid process turnover within a single tick window (10 ms at 100 Hz), meaning `{pid, startSeconds, startMicroseconds}` alone cannot detect all PID reuse races. A true process-generation token is either the immutable boot-tick tuple `(pid, starttime_ticks)` or, preferably, an active Linux `pidfd` handle.

Field 7 `tty_nr` is a signed decimal representation of the kernel 32-bit `new_encode_dev` layout. Comparing it directly to Python `os.stat().st_rdev` is unsafe on Linux because userspace `dev_t` is a 64-bit glibc encoding where higher major/minor bits occupy different positions. The correct approach normalizes `tty_nr` to an unsigned 32-bit integer, decodes kernel `(major, minor)` using bitwise shifts, and compares against `(os.major(st.st_rdev), os.minor(st.st_rdev))`.

For a terminal writer opening `/dev/pts/N`, `pidfd_open` prevents PID recycling but does not freeze the terminal device or prevent PTY reallocation if the master closes. The smallest safe workflow uses `os.open` with `O_NOCTTY | O_NONBLOCK | O_NOFOLLOW`, runs `os.fstat` to confirm a character device matching the decoded major/minor, and brackets the operation with pre- and post-generation and foreground checks (`pgrp == tpgid`).
===END_EXECUTIVE_SUMMARY===
===KEY_FINDINGS===
### 1. `/proc/<pid>/stat` Parsing, Identity, and Starttime

#### Foundational Definitions
- **`starttime` (Field 22)**: Defined in [proc_pid_stat(5)](https://www.man7.org/linux/man-pages/man5/proc_pid_stat.5.html) as the time the process started after system boot, expressed in clock ticks (`USER_HZ`). In kernel source [fs/proc/array.c](https://raw.githubusercontent.com/torvalds/linux/master/fs/proc/array.c), it is computed as:
  ```c
  start_time = nsec_to_clock_t(timens_add_boottime_ns(task->start_boottime));
  ```
  The origin is the system boot instant (specifically `CLOCK_BOOTTIME`).
- **`btime`**: Defined in [proc_stat(5)](https://man7.org/linux/man-pages/man5/proc_stat.5.html) as system boot time in whole seconds since the Unix Epoch (1970-01-01 00:00:00 UTC). In [fs/proc/stat.c](https://raw.githubusercontent.com/torvalds/linux/master/fs/proc/stat.c), it is retrieved using:
  ```c
  getboottime64(&boottime);
  timens_sub_boottime(&boottime);
  seq_printf(p, ... "btime %llu\n", (unsigned long long)boottime.tv_sec);
  ```
  In kernel `kernel/time/timekeeping.c`, `getboottime64` subtracts `offs_boot` from `offs_real`.
- **Clock Tick Resolution (`_SC_CLK_TCK`)**: Obtained in Python via `os.sysconf('SC_CLK_TCK')` (typically 100 on Linux x86/ARM, yielding 10 ms ticks).

#### Epoch vs. Boot-Relative Times and Accuracy
- In schema `{pid, startSeconds, startMicroseconds}`, the values represent an epoch timestamp if derived by combining `btime` with `starttime`.
- Accuracy limitation: `/proc/stat` `btime` is truncated to integer seconds. The sub-second fraction of boot time is omitted entirely by the kernel. Furthermore, `starttime` is quantized to `1 / USER_HZ` (10 ms at 100 Hz). Therefore, claiming microsecond-level accuracy for an epoch conversion is false; precision is bounded by 10,000 microseconds per tick, and absolute accuracy suffers up to 1 second of truncation error from `btime`.

#### Exact Integer Conversion (No Float Math)
Let `btime` be integer seconds from `/proc/stat`.
Let `ticks` be integer field 22 from `/proc/<pid>/stat`.
Let `hz = os.sysconf('SC_CLK_TCK')`.

1. Integer division for whole elapsed seconds:
   `elapsed_sec = ticks // hz`
2. Remainder ticks:
   `rem_ticks = ticks % hz`
3. Microseconds from remainder ticks with integer truncation:
   `startMicroseconds = (rem_ticks * 1_000_000) // hz`
4. Total epoch start seconds:
   `startSeconds = btime + elapsed_sec`

**Worked Example**:
Given:
- `btime = 1700000000`
- `hz = 100`
- `ticks = 12345` (representing 123.45 seconds after boot)

Calculation:
- `elapsed_sec = 12345 // 100 = 123`
- `rem_ticks = 12345 % 100 = 45`
- `startSeconds = 1700000000 + 123 = 1700000123`
- `startMicroseconds = (45 * 1_000_000) // 100 = 450_000`
Resulting schema: `{pid: 1234, startSeconds: 1700000123, startMicroseconds: 450000}`.

Rounding policy note: Standard integer truncation (`//`) is used. Half-up rounding can be expressed as `((rem_ticks * 1_000_000) + (hz // 2)) // hz`.

#### Realtime Clock Steps, Time Namespaces, and PID Reuse
- **Realtime Clock Invariance**: Epoch-derived starttime is NOT invariant under realtime clock steps. When `CLOCK_REALTIME` steps forward or backward (NTP synchronization or `settimeofday`), `offs_real` in the kernel changes, immediately modifying `/proc/stat` `btime`. Re-evaluating `startSeconds` produces a different value for the identical running process.
- **Time Namespaces**: Inside a time namespace, `timens_add_boottime_ns` offsets `start_time` and `timens_sub_boottime` offsets `btime` ([fs/proc/array.c](https://raw.githubusercontent.com/torvalds/linux/master/fs/proc/array.c), [fs/proc/stat.c](https://raw.githubusercontent.com/torvalds/linux/master/fs/proc/stat.c)). If viewed consistently inside the same namespace, the offset cancels out; if viewed across different namespaces, timestamps diverge.
- **PID Reuse Detection**: Schema `{pid, startSeconds, startMicroseconds}` does NOT detect all PID reuse. If process A exits and process B is spawned with the recycled PID within the same 10 ms clock tick (`ticks` identical), both processes have identical PID, `startSeconds`, and `startMicroseconds`.
- **Token Distinction**:
  - Cosmetic Epoch Timestamp: `(btime + ticks // hz)` fluctuates with wall-clock adjustments and suffers second-truncation jitter.
  - Stable In-Kernel Generation Token: `(pid, starttime_ticks)` is invariant to wall-clock steps because `task->start_boottime` is monotonic. A Linux `pidfd` provides an absolute, non-reusable kernel handle.

---

### 2. `/proc/<pid>/stat` Controlling TTY Field `tty_nr`

#### Kernel Encoding Definitions
In [fs/proc/array.c](https://raw.githubusercontent.com/torvalds/linux/master/fs/proc/array.c):
```c
int tty_pgrp = -1, tty_nr = 0;
...
if (sig->tty) {
    ...
    tty_nr = new_encode_dev(tty_devnum(sig->tty));
}
...
seq_put_decimal_ll(m, " ", tty_nr);
```
In [include/linux/kdev_t.h](https://raw.githubusercontent.com/torvalds/linux/master/include/linux/kdev_t.h):
```c
static __always_inline u32 new_encode_dev(dev_t dev)
{
    unsigned major = MAJOR(dev);
    unsigned minor = MINOR(dev);
    return (minor & 0xff) | (major << 8) | ((minor & ~0xff) << 12);
}

static __always_inline dev_t new_decode_dev(u32 dev)
{
    unsigned major = (dev & 0xfff00) >> 8;
    unsigned minor = (dev & 0xff) | ((dev >> 12) & 0xfff00);
    return MKDEV(major, minor);
}
```

#### Normalizing Signed 32-bit to `u32` and Splitting Major/Minor
`tty_nr` is written as signed decimal (`seq_put_decimal_ll`, `%d`). If bit 31 is set (when minor bit 19 is set: `(minor & ~0xff) << 12`), `tty_nr` parses as a negative integer.
1. Normalization to unsigned 32-bit:
   ```python
   tty_u32 = tty_nr & 0xFFFFFFFF
   ```
2. Extracting Major and Minor:
   ```python
   major = (tty_u32 & 0xFFF00) >> 8
   minor = (tty_u32 & 0x000FF) | ((tty_u32 >> 12) & 0xFFF00)
   ```
   Notice that bits 8..19 hold the 12-bit major number, bits 0..7 hold minor bits 0..7, and bits 20..31 hold minor bits 8..19.

#### Comparing Against `os.stat().st_rdev` and Userspace `dev_t`
In Linux userspace, `st_rdev` is a 64-bit `dev_t` constructed by glibc's `makedev(maj, min)` ([makedev(3)](https://man7.org/linux/man-pages/man3/makedev.3.html)):
```c
__dev = (((__dev_t) (major & 0x00000fffu)) << 8)
      | (((__dev_t) (major & 0xfffff000u)) << 32)
      | (((__dev_t) (minor & 0x000000ffu)) << 0)
      | (((__dev_t) (minor & 0xffffff00u)) << 12);
```
Directly comparing `tty_u32 == os.stat(path).st_rdev` is wrong because:
1. `st_rdev` in Python is a 64-bit integer where extended major/minor bits occupy bits above 31.
2. Kernel `new_encode_dev` packs a 32-bit integer where minor bits 8..19 are placed in bits 20..31.
3. While they coincide for major < 4096 and minor < 256, direct raw integer comparison fails if extended device bit ranges are populated or if running on platforms with alternate `dev_t` layouts.
- **Correct conversion**: Decompose `st_rdev` using `os.major(st.st_rdev)` and `os.minor(st.st_rdev)`, then compare against the decoded `(major, minor)` from `tty_nr`. Alternatively, compute `os.makedev(major, minor) == st.st_rdev`.

#### Concrete Linux `/dev/pts/N` Device Example (`/dev/pts/7`)
- Unix98 PTY Slave Major is 136 (`UNIX98_PTY_SLAVE_MAJOR = 128 + 8`, [include/uapi/linux/major.h](https://raw.githubusercontent.com/torvalds/linux/master/include/uapi/linux/major.h), [pts(4)](https://man7.org/linux/man-pages/man4/pts.4.html)).
- For `/dev/pts/7`: `major = 136`, `minor = 7`.
- `new_encode_dev`:
  - `minor & 0xff = 7` (hex `0x07`)
  - `major << 8 = 136 << 8 = 34816` (hex `0x8800`)
  - `(minor & ~0xff) << 12 = 0`
  - `encoded32 = 0x8800 | 0x07 = 0x8807 = 34823`.
- Expected `tty_nr`: `34823`.
- In `/proc/<pid>/stat`: field 7 is `34823`.
- Normalization and decode:
  - `tty_u32 = 34823 & 0xffffffff = 34823`
  - `major = (34823 & 0xfff00) >> 8 = 0x8800 >> 8 = 136`
  - `minor = (34823 & 0xff) | ((34823 >> 12) & 0xfff00) = 7 | 0 = 7`.
- Stat comparison:
  - `st = os.stat('/dev/pts/7')`
  - `os.major(st.st_rdev) == 136` and `os.minor(st.st_rdev) == 7`. Matches.

---

### 3. TTY State, Sessions, Foreground Status, and Safe Parsing

#### Attached Controlling TTY vs. Foreground Association
- **Attached Controlling TTY**: Established if and only if `tty_nr != 0` ([fs/proc/array.c](https://raw.githubusercontent.com/torvalds/linux/master/fs/proc/array.c)). If `tty_nr == 0`, the process has no controlling terminal (daemon, detached background process, or kernel thread).
- **Foreground Association**: Requires:
  1. `tty_nr != 0` (controlling terminal exists).
  2. `tpgid > 0` (a valid foreground process group exists).
  3. `pgrp == tpgid` (the process's process group matches the terminal's foreground process group).
  If `pgrp != tpgid`, the process is in a background process group on that terminal.

#### Process State and Stale Snapshots
- Field 3 `state`: Single char. Defined in [proc_pid_stat(5)](https://www.man7.org/linux/man-pages/man5/proc_pid_stat.5.html) and [fs/proc/array.c](https://raw.githubusercontent.com/torvalds/linux/master/fs/proc/array.c):
  - `R` (running), `S` (sleeping), `D` (disk sleep), `T` (stopped), `t` (tracing stop).
  - `Z` (zombie), `X` / `x` (dead), `I` (idle).
- Zombie/Dead states: If `state in ('Z', 'X', 'x')`, the process has terminated. Its terminal handles are either closing or orphaned. It cannot consume terminal output.
- Stale snapshot causes:
  1. Process exit / reap / PID recycle between snapshot and action.
  2. Terminal detachment: Process calls `setsid()` or `ioctl(TIOCNOTTY)`.
  3. Job control transfer: Shell changes foreground group (`tcsetpgrp`), altering `tpgid`.
  4. Permission restrictions: Reading `/proc/<pid>/stat` may fail with `EACCES` under `hidepid` mount options.
  5. Permission-gated fields: In [proc_pid_stat(5)](https://www.man7.org/linux/man-pages/man5/proc_pid_stat.5.html), fields marked `[PT]` return 0 if ptrace checks fail, but fields 1 to 22 (including `comm`, `state`, `pgrp`, `session`, `tty_nr`, `tpgid`, and `starttime`) are public and not gated by `[PT]`.

#### Safe Parsing of `comm`
In [fs/proc/array.c](https://raw.githubusercontent.com/torvalds/linux/master/fs/proc/array.c), `comm` is printed as `seq_puts(m, " ("); proc_task_name(m, task, false); seq_puts(m, ") ");`.
Because `comm` strings can contain spaces and parentheses:
- Rule: Locate the **first open parenthesis** `(` to mark the start of `comm`.
- Locate the **last close parenthesis** `)` in the entire stat record using `rfind(')')`.
- The text between first `(` and last `)` is `comm`.
- The remaining string after the last `)` and its subsequent space is split by whitespace. The items correspond strictly to field 3 (`state`), field 4 (`ppid`), field 5 (`pgrp`), field 6 (`session`), field 7 (`tty_nr`), field 8 (`tpgid`), through field 22 (`starttime`).

---

### 4. PID Namespace and Time Namespace Caveats

#### PID Namespaces
- In [pid_namespaces(7)](https://www.man7.org/linux/man-pages/man7/pid_namespaces.7.html):
  - A `/proc` filesystem instance reflects the PID namespace of the process that mounted it.
  - System calls that operate on PIDs use the caller's PID namespace.
  - Assumption required: The target process PID and the `/proc` filesystem being inspected must belong to the same PID namespace. If a worker PID was allocated in a child PID namespace (e.g. inside a container) but `/proc` is mounted from the host (or vice-versa), looking up `/proc/<pid>` either inspects a completely unrelated process or fails with `ENOENT`. Cross-namespace PID validation without translating through pidfd or namespace descriptors is invalid.

#### Time Namespaces
- In [time_namespaces(7)](https://www.man7.org/linux/man-pages/man7/time_namespaces.7.html):
  - Time namespaces virtualize `CLOCK_MONOTONIC` and `CLOCK_BOOTTIME` via `/proc/pid/timens_offsets`.
  - In [fs/proc/stat.c](https://raw.githubusercontent.com/torvalds/linux/master/fs/proc/stat.c), `btime` is shifted by `timens_sub_boottime`.
  - In [fs/proc/array.c](https://raw.githubusercontent.com/torvalds/linux/master/fs/proc/array.c), `starttime` is shifted by `timens_add_boottime_ns`.
  - Assumption required: `/proc/stat` and `/proc/<pid>/stat` must be read from the same time namespace. If `/proc/stat` is read from the root namespace and `/proc/<pid>/stat` is read from a container with non-zero boottime offset, the computed epoch start time will be corrupted by the namespace offset.

---

### 5. Minimal Safe Workflow for a Stdlib Python Terminal Writer

#### Comparing `/proc` Rereading vs. `pidfd`
- `os.pidfd_open(pid)` is available in Python 3.9+ on Linux >= 5.3 ([os documentation](https://docs.python.org/3/library/os.html), [pidfd_open(2)](https://man7.org/linux/man-pages/man2/pidfd_open.2.html)).
- What `pidfd` guarantees: Holding an open `pidfd` guarantees that the kernel will not reallocate the PID to a new process even after exit, completely eliminating PID recycling races for signals and status queries.
- What `pidfd` DOES NOT guarantee: A `pidfd` binds the process, but does NOT freeze the process or bind its controlling terminal. The target process can close or detach its TTY, or the terminal master emulator can close `/dev/ptmx`, freeing `/dev/pts/N` for reuse by another session while the target process is still running.

#### Minimal Workflow
1. **Acquire Process Reference**:
   Call `pfd = os.pidfd_open(pid)` if available. If `ESRCH`, abort.
2. **Pre-Read `/proc/<pid>/stat`**:
   Parse `(state, pgrp, session, tty_nr, tpgid, starttime)` using the first `(` and last `)` rule.
   - Assert `state not in ('Z', 'X', 'x')`.
   - Assert `tty_nr != 0`.
   - If foreground output required, assert `tpgid > 0` and `pgrp == tpgid`.
   - Decode `(ctl_major, ctl_minor)` from `tty_nr`.
3. **Open Terminal Path**:
   Open candidate path `/dev/pts/N`:
   ```python
   fd = os.open(pts_path, os.O_WRONLY | os.O_NOCTTY | os.O_NONBLOCK | os.O_NOFOLLOW)
   ```
   - `O_NOCTTY`: Mandatory ([open(2)](https://man7.org/linux/man-pages/man2/open.2.html)). Prevents the opening process from acquiring `/dev/pts/N` as its controlling terminal.
   - `O_NOFOLLOW`: Mandatory ([open(2)](https://man7.org/linux/man-pages/man2/open.2.html)). Prevents symlink attacks.
   - `O_NONBLOCK`: Prevents indefinite hang on opening blocking devices.
4. **Inspect Opened File Descriptor**:
   Call `st = os.fstat(fd)`.
   - Assert `stat.S_ISCHR(st.st_mode)` is true.
   - Extract `fd_major = os.major(st.st_rdev)` and `fd_minor = os.minor(st.st_rdev)`.
   - Assert `(fd_major, fd_minor) == (ctl_major, ctl_minor)`.
5. **Post-Read Verification**:
   Reread `/proc/<pid>/stat`:
   - Assert process exists, `starttime` matches pre-read value, `tty_nr` matches `(ctl_major, ctl_minor)`, `state not in ('Z', 'X', 'x')`, and `pgrp == tpgid`.
   - If `pfd` is held, verify liveness (e.g., non-blocking poll with `select.poll()` does not show `POLLHUP`).
6. **Perform Write**:
   Write to `fd`, then close `fd`.

#### Residual Races
- **Inference**: A window remains where the target process detaches from the controlling terminal or changes process groups immediately after the post-read check returns but before `os.write(fd, ...)` executes. No userspace mechanism short of `ptrace` stopping the process can eliminate this race.
- **Inference**: If the PTY master closes immediately prior to `open`, but is reopened by an unrelated process claiming the same PTY number, the pre/post check detects the change only if the target process's `tty_nr` has been cleared or altered.
===END_KEY_FINDINGS===
===CONSENSUS_AND_ALTERNATIVES===
### Comparison: Rereading `/proc/<pid>/stat` vs. `pidfd`

| Dimension | `/proc/<pid>/stat` Rereading | `os.pidfd_open` + `/proc` Check |
| :--- | :--- | :--- |
| **Availability** | All Linux kernels and all Python 3 versions | Linux >= 5.3, Python >= 3.9 |
| **PID Recycling Protection** | Partial: Vulnerable if PID is recycled within the same clock tick (10 ms at 100 Hz) | Absolute: Kernel holds task struct; PID cannot be recycled while pidfd is open |
| **Controlling TTY Pinning** | None: TTY can detach concurrently | None: pidfd pins task, not the TTY file description |
| **PTY Number Reuse Protection** | Relies on pre/post `(major, minor)` matching | Relies on pre/post `(major, minor)` matching |
| **System Overhead** | Two procfs file reads | One syscall (`pidfd_open`) + two procfs file reads |

### Identified Conflicts and Limitations
- **Conflict**: Many legacy Unix guides recommend comparing `os.stat().st_rdev` directly to `/proc/<pid>/stat` `tty_nr`.
  - **Resolution based on retrieved source**: Upstream kernel `fs/proc/array.c` uses `new_encode_dev` (32-bit layout), whereas glibc `makedev` formats a 64-bit `dev_t`. Direct integer comparison is an anti-pattern; primary sources demonstrate that decomposing via `os.major` and `os.minor` is required.
- **Conflict**: Relying on `{pid, startSeconds, startMicroseconds}` as a unique token.
  - **Resolution based on retrieved source**: Primary sources reveal `btime` in `/proc/stat` shifts on wall-clock steps, and `starttime` is quantized to ticks. Rapid process cycling within one tick produces identical tokens.
===END_CONSENSUS_AND_ALTERNATIVES===
===RECOMMENDATIONS===
### Minimal Safe Implementation Choices
1. Do not use float math or epoch conversions for process identity; use raw `(pid, starttime_ticks)` or `pidfd`.
2. Normalize `tty_nr` via `& 0xFFFFFFFF` and extract major/minor using bitwise masks.
3. Open the candidate PTY path exclusively with `O_WRONLY | O_NOCTTY | O_NONBLOCK | O_NOFOLLOW`.
4. Validate the opened file descriptor using `os.fstat`, checking character device mode and comparing `os.major(st.st_rdev)` and `os.minor(st.st_rdev)`.
5. Enforce pre- and post-read validation around the file descriptor open and write steps.

### Python 3 Pseudocode (Grounded in Retrieved Evidence)
```python
import os
import stat
import select

def parse_proc_stat(pid: int):
    with open(f"/proc/{pid}/stat", "r", encoding="ascii") as f:
        data = f.read()

    # Boundary rule: comm is delimited by first '(' and last ')'
    left = data.find("(")
    right = data.rfind(")")
    if left == -1 or right == -1 or left > right:
        raise ValueError("Malformed /proc/<pid>/stat")

    comm = data[left + 1:right]
    rest = data[right + 2:].split()

    # rest[0] is field 3 (state)
    state = rest[0]
    pgrp = int(rest[2])       # field 5
    session = int(rest[3])    # field 6
    tty_nr = int(rest[4])     # field 7
    tpgid = int(rest[5])      # field 8
    starttime = int(rest[19]) # field 22

    return {
        "state": state,
        "pgrp": pgrp,
        "session": session,
        "tty_nr": tty_nr,
        "tpgid": tpgid,
        "starttime": starttime,
    }

def decode_tty_nr(tty_nr: int):
    # Normalize signed 32-bit to unsigned 32-bit
    tty_u32 = tty_nr & 0xFFFFFFFF
    # new_decode_dev bit shifts from include/linux/kdev_t.h
    major = (tty_u32 & 0xFFF00) >> 8
    minor = (tty_u32 & 0x000FF) | ((tty_u32 >> 12) & 0xFFF00)
    return major, minor

def safe_write_terminal(pid: int, pts_path: str, message: bytes, require_foreground: bool = True):
    pfd = None
    if hasattr(os, "pidfd_open"):
        try:
            pfd = os.pidfd_open(pid)
        except OSError:
            return False

    try:
        # Pre-read
        pre = parse_proc_stat(pid)
        if pre["state"] in ("Z", "X", "x") or pre["tty_nr"] == 0:
            return False
        if require_foreground and (pre["tpgid"] <= 0 or pre["pgrp"] != pre["tpgid"]):
            return False

        ctl_major, ctl_minor = decode_tty_nr(pre["tty_nr"])

        # Safe open
        flags = os.O_WRONLY | os.O_NOCTTY | os.O_NONBLOCK
        if hasattr(os, "O_NOFOLLOW"):
            flags |= os.O_NOFOLLOW

        fd = os.open(pts_path, flags)
        try:
            st = os.fstat(fd)
            if not stat.S_ISCHR(st.st_mode):
                return False
            if os.major(st.st_rdev) != ctl_major or os.minor(st.st_rdev) != ctl_minor:
                return False

            # Post-read verification
            post = parse_proc_stat(pid)
            if (post["starttime"] != pre["starttime"] or
                post["tty_nr"] != pre["tty_nr"] or
                post["state"] in ("Z", "X", "x")):
                return False
            if require_foreground and (post["tpgid"] <= 0 or post["pgrp"] != post["tpgid"]):
                return False

            if pfd is not None:
                poller = select.poll()
                poller.register(pfd, select.POLLIN | select.POLLHUP)
                events = poller.poll(0)
                if events:
                    return False

            os.write(fd, message)
            return True
        finally:
            os.close(fd)
    finally:
        if pfd is not None:
            os.close(pfd)
```
===END_RECOMMENDATIONS===
===FURTHER_RESEARCH===
- In-kernel synchronization: Investigation into whether a future Linux kernel interface could allow atomic validation and acquisition of controlling TTY file descriptors directly from `pidfd` without relying on filesystem path checks.
- Namespace mapping libraries: Developing portable helpers for translating PIDs and time offsets when parent orchestrators must monitor processes across mixed PID and time namespaces.
===END_FURTHER_RESEARCH===
===BIBLIOGRAPHY===
- Linux Kernel Source: `fs/proc/array.c` (Upstream Linux master, commit tree as of 2026-10-13), https://raw.githubusercontent.com/torvalds/linux/master/fs/proc/array.c (Retrieved full source: `do_task_stat`, `proc_task_name`, `task_state`).
- Linux Kernel Source: `fs/proc/stat.c` (Upstream Linux master, commit tree as of 2026-10-13), https://raw.githubusercontent.com/torvalds/linux/master/fs/proc/stat.c (Retrieved full source: `show_stat`, `btime`, `getboottime64`, `timens_sub_boottime`).
- Linux Kernel Source: `include/linux/kdev_t.h` (Upstream Linux master, commit tree as of 2026-10-13), https://raw.githubusercontent.com/torvalds/linux/master/include/linux/kdev_t.h (Retrieved full source: `new_encode_dev`, `new_decode_dev`, `MAJOR`, `MINOR`, `MKDEV`).
- Linux Kernel Source: `include/uapi/linux/major.h` (Upstream Linux master, commit tree as of 2026-10-13), https://raw.githubusercontent.com/torvalds/linux/master/include/uapi/linux/major.h (Retrieved source: `UNIX98_PTY_SLAVE_MAJOR`).
- Linux man-pages: `proc_pid_stat(5)` (v6.19 tarball, 2026-02-08, fetched 2026-10-13), https://www.man7.org/linux/man-pages/man5/proc_pid_stat.5.html (Retrieved full page).
- Linux man-pages: `proc_stat(5)` (v6.19 tarball, 2026-02-08, fetched 2026-10-13), https://man7.org/linux/man-pages/man5/proc_stat.5.html (Retrieved full page).
- Linux man-pages: `pidfd_open(2)` (v6.19 tarball, fetched 2026-10-13), https://man7.org/linux/man-pages/man2/pidfd_open.2.html (Retrieved full page).
- Linux man-pages: `open(2)` (v6.19 tarball, fetched 2026-10-13), https://man7.org/linux/man-pages/man2/open.2.html (Retrieved full page).
- Linux man-pages: `makedev(3)` (v6.19 tarball, fetched 2026-10-13), https://man7.org/linux/man-pages/man3/makedev.3.html (Retrieved full page).
- Linux man-pages: `pts(4)` (v6.19 tarball, fetched 2026-10-13), https://man7.org/linux/man-pages/man4/pts.4.html (Retrieved full page).
- Linux man-pages: `pid_namespaces(7)` (v6.19 tarball, fetched 2026-10-13), https://man7.org/linux/man-pages/man7/pid_namespaces.7.html (Retrieved full page).
- Linux man-pages: `time_namespaces(7)` (v6.19 tarball, fetched 2026-10-13), https://man7.org/linux/man-pages/man7/time_namespaces.7.html (Retrieved full page).
- Python Documentation: `os : Miscellaneous operating system interfaces` (Python 3.15.0 documentation, fetched 2026-10-13), https://docs.python.org/3/library/os.html (Retrieved documentation for `os.major`, `os.minor`, `os.makedev`, `os.pidfd_open`, `os.open`, `os.fstat`, `os.sysconf`).
===END_BIBLIOGRAPHY===
===RESEARCH_META===
Date: 2026-10-13.
Scan Type: Quick depth, single Flash scan.
Scope: Public-web-only; primary upstream Linux kernel source, upstream man-pages, and official Python documentation retrieved via fetch_public_url.
Repository: No local repository in scope; fingerprint N/A.
Source Retrieval Limitations: Text slices retrieved with max_characters <= 3000 and iterated where truncated. No local code inspection or private URLs accessed.
===END_RESEARCH_META===
