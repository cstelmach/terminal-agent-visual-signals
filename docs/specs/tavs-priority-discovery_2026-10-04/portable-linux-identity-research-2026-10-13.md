Last Updated: 2026-10-15
Version: 1.1

# Linux terminal writer identity: adversarial limits

Last updated: 2026-10-13. Scope: public-web research only.

## Executive answer

A pidfd is a stronger process reference than a numeric PID plus a converted start timestamp.
It does not lock terminal ownership, process-group membership, or foreground status. Repeated
`/proc` verification and `fstat` can reject observed mismatches, but cannot make a separate
terminal write conditional on those observations remaining true. The safe claim is bounded
verification of a held endpoint with refusal on uncertainty, not atomic foreground ownership.
[pidfd_open(2)](https://man7.org/linux/man-pages/man2/pidfd_open.2.html),
[tcgetpgrp(3)](https://man7.org/linux/man-pages/man3/tcgetpgrp.3.html)

`startSeconds` and `startMicroseconds` need a defined clock basis. Linux start ticks do not
contain exact birth microseconds. Adding integer `btime` produces an approximate wall-clock
timestamp that can change after clock adjustment. Neither that tuple nor remembered terminal
metadata is a unique lifetime token.
[proc_pid_stat(5)](https://man7.org/linux/man-pages/man5/proc_pid_stat.5.html),
[upstream timekeeping.c](https://raw.githubusercontent.com/torvalds/linux/v6.17/kernel/time/timekeeping.c)

## Foundations and assumptions

The sources were retrieved afresh. Linux man-pages report version 6.19, with the relevant
pages dated 2026-02-08 and HTML fetched from that release on 2026-09-09. Python documentation
is the stable 3.14 branch, currently identifying itself as 3.14.8. Source-level findings are
pinned to upstream Linux v6.17, rather than asserted for every downstream kernel.

The parent supplied a wiki-recall verdict of no useful low-level coverage: proceed. No local
repository, application, device, `/proc` instance, tests, build, or service was accessed.
No runtime latency measurement was performed. Recommendations below are explicitly inferences.

The relevant identities are separate:

| Identity | What it establishes | What it does not establish |
|---|---|---|
| Numeric PID | A number in a PID namespace | Process lifetime continuity |
| PID plus start ticks | A sampled, quantized process-start discriminator | Collision-free lifetime identity |
| Held pidfd | Reference to the acquired process | Which process was intended before acquisition, or its current TTY |
| Held `/proc/<pid>` FD | Proc object that does not retarget a recycled PID | Process survival or numeric PID reservation |
| Held terminal FD | Open endpoint unaffected by later pathname changes | Current controlling/foreground ownership |

Sources: [PID namespaces](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html),
[proc descriptor behavior](https://docs.kernel.org/filesystems/proc.html),
[open-file descriptions](https://man7.org/linux/man-pages/man2/open.2.html).

## PID reuse between verification, open, and write

The kernel explicitly documents that open proc descriptors do not stop PID reuse, but
operations through them never act on a replacement process. They normally fail with `ESRCH`
after the original process disappears. Proc access can also be restricted by `hidepid`, and
`subset=pid` can hide global files needed for a `btime` conversion.
[kernel proc documentation](https://docs.kernel.org/filesystems/proc.html)

**Inference:** reopening `/proc/<pid>/stat` by its numeric pathname twice permits an ABA
sequence: original process, recycled PID, replacement process. Start ticks reduce the chance
of accepting that replacement, but the representation is quantized. A process can exit and a
replacement start within one tick. The PID namespace interface even permits a sufficiently
privileged caller to influence the next allocation through `ns_last_pid`.
[proc_pid_stat(5)](https://man7.org/linux/man-pages/man5/proc_pid_stat.5.html),
[PID allocation interface](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html)

**Inference:** retain one proc directory FD and obtain fresh `stat` reads relative to that
directory when lifetime continuity during the attempt matters. Do not mistake rereading a
buffered sample for a new kernel observation. This prevents numeric-path retargeting after
acquisition, but cannot prove an old persisted identity if its original process disappeared
before that FD was acquired.
[proc descriptor behavior](https://docs.kernel.org/filesystems/proc.html),
[relative descriptor operations](https://man7.org/linux/man-pages/man2/open.2.html)

## Pidfd compared with two verified proc snapshots

`pidfd_open` is available since Linux 5.3. Exit can be observed with polling; a pidfd refers to
the acquired process and does not turn into a replacement. Acquisition using a stale numeric
PID remains a separate problem. The documented fork-then-open guarantee relies on an unreaped
child and specified `SIGCHLD` handling; it is not a general guarantee for arbitrary old PIDs.
[pidfd_open(2)](https://man7.org/linux/man-pages/man2/pidfd_open.2.html)

| Approach | Benefit | Remaining limit |
|---|---|---|
| Two numeric proc pathname reads plus terminal `fstat` | Small, portable Python surface | Reacquisition race and coarse start-token collision |
| Two fresh reads through one held proc directory plus terminal `fstat` | Proc reads cannot target a replacement | No pollable exit indication; TTY association remains mutable |
| Held pidfd plus fresh proc reads and terminal FD | Stable process handle and explicit exit observation | Must correlate acquisition with intended process; no ownership lock |
| Held process and endpoint handles from session creation | Strongest continuity across later events | Requires retaining handles; foreground can still change |

This table is an inference from the cited interfaces, not a measured performance ranking.

`pidfd_getfd`, available since Linux 5.6, duplicates a target FD and shares its open-file
description, including file-status flags. It requires `PTRACE_MODE_ATTACH_REALCREDS` access
and can return `EPERM`. **Inference:** it avoids reopening a guessed `/dev` pathname, but it
captures whatever object occupies that FD number at acquisition. Also, setting `O_NONBLOCK`
on the duplicate changes the shared flags, potentially affecting the target. Do not silently
use this as a permission-bypassing or side-effect-free alternative.
[pidfd_getfd(2)](https://man7.org/linux/man-pages/man2/pidfd_getfd.2.html)

## Namespace and start-time conversion limits

Procfs PID numbering follows its configured PID namespace, while a task can have distinct
numbers in nested namespaces. **Inference:** proc PID values and syscall PIDs must be known
to refer to the same numbering domain; comparing bare integers across domains is insufficient.
[pid_namespaces(7)](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html)

Time namespaces virtualize monotonic and boot-time clocks, but not `CLOCK_REALTIME`.
[time_namespaces(7)](https://man7.org/linux/man-pages/man7/time_namespaces.7.html)

In v6.17, `do_task_stat` applies `timens_add_boottime_ns` to `task->start_boottime` before
converting to ticks. That helper uses the **current reader's** time namespace. `/proc/stat`
subtracts that reader offset from boot wall-time, then prints only `tv_sec`.
[array.c](https://raw.githubusercontent.com/torvalds/linux/v6.17/fs/proc/array.c),
[time_namespace.h](https://raw.githubusercontent.com/torvalds/linux/v6.17/include/linux/time_namespace.h),
[stat.c](https://raw.githubusercontent.com/torvalds/linux/v6.17/fs/proc/stat.c)

Two possible tuple contracts therefore differ:

```text
T = start ticks
H = sysconf(_SC_CLK_TCK), validated positive
(q, r) = divmod(T, H)

Boot-relative quantized representation:
    startSeconds = q
    startMicroseconds = floor(r * 1_000_000 / H)

Approximate epoch representation:
    startSeconds = btime + q
    startMicroseconds = floor(r * 1_000_000 / H)
```

These are derived mappings, not native Linux birth-time structures. Preserve raw `T` as the
Linux discriminator when possible. Avoid floating-point arithmetic. A value expressed in
microseconds retains tick precision; it does not gain microsecond accuracy. For `H=100`, one
tick is 10,000 microseconds. The kernel's common conversion divides nanoseconds by the tick
period; other compile-time cases use different integer formulas.
[tick definition](https://man7.org/linux/man-pages/man5/proc_pid_stat.5.html),
[nsec_to_clock_t](https://raw.githubusercontent.com/torvalds/linux/v6.17/kernel/time/time.c)

**Derivation under a fixed clock mapping and ordinary nonnegative, nonwrapping values:**
discarding boot-wall-time subseconds loses less than one second, and discarding start-time
subticks loses about one tick. Thus the epoch estimate can undershoot the corresponding
unquantized sum by almost `1 + 1/H` seconds. Fractional namespace offsets cancel before
quantization, but need not cancel after the separate integer truncations. The same process
can consequently produce different approximate tuples when read in different time namespaces.
[stat.c](https://raw.githubusercontent.com/torvalds/linux/v6.17/fs/proc/stat.c),
[time_namespace.h](https://raw.githubusercontent.com/torvalds/linux/v6.17/include/linux/time_namespace.h)

Upstream `getboottime64` explicitly says `settimeofday` affects its result.
**Inference:** recomputing `btime + T/H` can change for a surviving process following a wall
clock step. It is unsuitable as an immutable exact epoch birth identifier. Refuse a comparison
whose basis is unknown rather than choose a tolerance that silently accepts another process.
[timekeeping.c](https://raw.githubusercontent.com/torvalds/linux/v6.17/kernel/time/timekeeping.c)

## Foreground claims and controlling TTY disappearance

`tty_nr` describes the controlling terminal, and `tpgid` describes its foreground group.
These are observations, not ownership grants. Kernel code collects them under relevant
locks, then releases those locks before returning the stat output.
[array.c](https://raw.githubusercontent.com/torvalds/linux/v6.17/fs/proc/array.c)

`tcgetpgrp(fd)` queries the foreground group, but requires the caller's controlling terminal.
It may return `ENOTTY` for a detached helper opening somebody else's terminal; a positive
result alone is not proof that a currently existing group owns the terminal. **Inference:**
check equality with the required group in the right namespace, and refuse a failed query
when this live condition is part of the contract. Even a successful check can go stale
before the subsequent write.
[tcgetpgrp(3)](https://man7.org/linux/man-pages/man3/tcgetpgrp.3.html)

On hangup, the upstream TTY path preserves the TTY object but makes future writes fail;
the hung-up write operation returns `EIO`. **Inference:** retain the endpoint FD and report
failure. Reopening a remembered path to recover is a new endpoint acquisition and requires
all checks again. An open FD does not promise successful output or continued association.
[tty_io.c](https://raw.githubusercontent.com/torvalds/linux/v6.17/drivers/tty/tty_io.c)

## Devpts lifetime reuse and symlink paths

Each devpts mount has independent PTYs and indices.
[devpts documentation](https://docs.kernel.org/filesystems/devpts.html)

Upstream code frees indices and allocates them again; a new slave uses `i_ino = index + 3`
and a device ID derived from the fixed slave major and index. **Inference:** two devpts
instances can expose different endpoints with matching `st_rdev`, and sequential lifetimes
within one mount can repeat `(st_dev, st_ino, st_rdev)`. Saved inode and device numbers are
useful mismatch checks, but not terminal generation tokens. A held FD pins the particular
opened object for the attempt; metadata alone cannot prove continuity before opening.
[devpts inode.c](https://raw.githubusercontent.com/torvalds/linux/v6.17/fs/devpts/inode.c)

`fstat` examines the FD rather than resolving a pathname; `st_dev` identifies its containing
device and `st_rdev` the special-file device. Require a character device as well as the
expected decoded terminal device number.
[stat(2)](https://man7.org/linux/man-pages/man2/stat.2.html),
[stat structure](https://man7.org/linux/man-pages/man3/stat.3type.html)

`O_NOFOLLOW` rejects only the final path component when it is a symlink; earlier components
are still followed. `O_NOCTTY` prevents acquiring a controlling terminal on open.
[open(2)](https://man7.org/linux/man-pages/man2/open.2.html)

`openat2` can reject symlinks throughout a path, but that is a stricter policy with compatibility
costs. Proc FD entries are intentional magic links, so applying a blanket no-link policy to
that acquisition route defeats it. **Inference:** distinguish an approved object-reference
route from a supplied ordinary `/dev` path; do not trust `realpath` plus later open as atomic.
[openat2(2)](https://man7.org/linux/man-pages/man2/openat2.2.html)

Dereferencing `/proc/<pid>/fd` entries is subject to `PTRACE_MODE_READ_FSCREDS`, and creating
a new FD can still fail because of the underlying inode permissions.
[proc_pid_fd(5)](https://man7.org/linux/man-pages/man5/proc_pid_fd.5.html)

## A 100 ms budget and minimal refusal rules

Python supplies `os.pidfd_open` from 3.9 and `os.fstat`, `os.open`, and low-level `os.write`.
`os.write` returns actual bytes written and automatically retries certain interrupted calls.
[Python os](https://docs.python.org/3.14/library/os.html)

Use one absolute deadline derived from `time.monotonic_ns`, which avoids wall-clock changes
and float precision loss.
[Python time](https://docs.python.org/3.14/library/time.html)

Polling can exceed its requested timeout due to rounding and scheduling. **Inference:**
checking the deadline between synchronous calls is an admission policy, not a hard guarantee
that kernel work, scheduling, or process startup completes within 100 ms. A zero-timeout
pidfd poll avoids deliberately waiting for exit. No latency ranking is established here.
[poll(2)](https://man7.org/linux/man-pages/man2/poll.2.html)

Recommended refusal rules, inferred from the interfaces above:

1. Refuse absent, denied, malformed, incomplete, or changed required proc data. Do not use
   `kill(pid, 0)`, a cached timestamp, or pathname existence to replace identity evidence.
   Ptrace-redacted `[PT]` fields can appear as zero; the listed core PID, start, and TTY fields
   are not themselves marked `[PT]` in the stat manual.
2. Refuse an undefined clock basis, unknown PID numbering domain, or unexplained timestamp
   conversion mismatch. If epoch formatting is mandatory, disclose its quantization and
   mutable boot-wall-time basis.
3. Refuse a missing controlling terminal, unexpected terminal device, non-character endpoint,
   changed required session/group/TTY observations, or pidfd exit/error indication.
4. Refuse unresolved devpts/path-instance ambiguity. Write only through the FD actually
   validated. Do not close it and reopen a pathname between validation and output.
5. Recheck required process and foreground observations immediately before each output attempt.
   If the contract requires atomic ownership through the write, these APIs do not satisfy it.
6. Admit no new write after the deadline. Use an independently opened nonblocking endpoint
   when that is the selected acquisition route. Treat `EAGAIN`, hangup, and identity uncertainty
   as refusal or failure, not reasons to retry through another terminal.
7. A partial write is partial output already performed, not zero-output refusal. Bound any
   continuation by the same deadline and retained FD; report the actual byte count.

Partial writes and nonblocking `EAGAIN` are documented outcomes.
[write(2)](https://man7.org/linux/man-pages/man2/write.2.html)

## Recommendation and limits

For a one-shot observational check, one held proc directory with two fresh reads plus an
independently opened and `fstat`-checked terminal FD is a small useful design. A pidfd adds
explicit exit observation and stable process operations if supported; it does not repair
persisted coarse-token ambiguity or close the foreground-check/write race.

For a strong lifetime claim across events, retain process and terminal references from the
trusted session acquisition point. If only `{pid,startSeconds,startMicroseconds}` and a path
survive, refuse claims of adversarially unique identity. Raw start ticks and a declared clock
basis are more honest Linux data than invented exact wall birth microseconds.

Unresolved: the caller's exact tuple clock contract; whether process and endpoint handles can
be retained; whether the 100 ms requirement covers interpreter/process startup; available
kernel/Python versions and namespace topology; and whether snapshot foreground verification
is acceptable. These are implementation decisions, not resolved by this public research.

## Bibliography and retrieval notes

All links above were directly retrieved on 2026-10-13. The primary families are upstream
Linux documentation, Linux man-pages 6.19, stable Python 3.14 documentation, and versioned
Linux v6.17 source. No community claim was needed for a central conclusion.

One initial raw-source fetch of `timekeeping.c` returned an internal tool error. A retry
retrieved the complete raw source, including `getboottime64`; a GitHub HTML alternative did
not expose the required function and was not used as evidence for that claim. No benchmark,
runtime experiment, or local-environment compatibility claim is included.

## Follow-up: proposed boot-relative generation fields

The parent proposed `startSeconds = T // H + 1`,
`startMicroseconds = (T % H) * 1_000_000 // H`, rejecting `H > 1_000_000`, plus mandatory
boot ID and current-reader PID/time namespace inode IDs. This changes the tuple contract
from an epoch timestamp to a synthetic quantized discriminator. The `+1` offset should be
documented explicitly; it does not supply another unit of timing precision.

**Derivation:** for `1 <= H <= M = 1_000_000`, adjacent remainders satisfy
`floor((r+1) M/H) - floor(r M/H) >= 1`. Therefore the remainder encoding is injective,
and the quotient and remainder pair preserves distinct integer tick values. This eliminates
conversion-induced collisions and btime clock-step drift. It does not eliminate collisions
already present in the kernel's quantized `T` value.

Boot ID is a read-only randomly generated UUID that remains unchanged after generation.
**Inference:** equality supplies a useful reboot discriminator, subject to the ordinary UUID
collision assumption and a genuine, unmasked proc source; it is not mathematical proof that
two boots can never collide.
[kernel random sysctl documentation](https://docs.kernel.org/admin-guide/sysctl/kernel.html#random),
[random(4)](https://man7.org/linux/man-pages/man4/random.4.html)

Namespaces documentation specifies comparing the dereferenced namespace object's
`st_dev` **and** `st_ino`. Its namespace handles remain alive while held open. It does not
promise that a remembered inode number is an eternal identifier after object destruction.
**Inference:** record both values, or state explicitly the platform assumption if storing
only the inode. Retaining a namespace handle prevents its destruction during an attempt.
[namespaces(7)](https://man7.org/linux/man-pages/man7/namespaces.7.html)

`/proc/self/stat` PID equality with `os.getpid()` is useful but **not sufficient proof** of
PID namespace agreement: two distinct namespace-relative numbers can coincidentally match.
An inference from the namespace rules is to compare the dereferenced PID namespace of
`/proc/1` in the chosen proc mount with that of `/proc/self`; PID 1 belongs to that mount's
namespace, while the reader handle identifies the reader's active namespace. Refuse failed
or unavailable identity reads. This assumes genuine procfs and unmasked paths; it is not
proof against a privileged actor supplying substituted files.
[PID namespaces](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html),
[namespaces(7)](https://man7.org/linux/man-pages/man7/namespaces.7.html)

The `ns/time` entry exists from Linux 5.6 and is compiled into proc namespace entries only
when `CONFIG_TIME_NS` is enabled. Missing does not identify the reason: an old kernel,
disabled configuration, or inaccessible/masked environment needs different interpretation.
**Recommended minimal older-kernel rule:** if time namespace evidence is mandatory, absent
or unreadable `ns/time` means unsupported and refusal. Do not silently substitute zero,
the PID namespace ID, or a guessed initial-time-namespace value. Supporting older kernels
would need a separately specified, positively evidenced capability contract.
[namespaces(7)](https://man7.org/linux/man-pages/man7/namespaces.7.html),
[proc namespace entries](https://raw.githubusercontent.com/torvalds/linux/v6.17/fs/proc/namespaces.c)

**Verdict:** these fields are useful and avoid wall-clock dependence. With matching reader
namespace identities and boot ID, they reject observed cross-namespace and reboot mismatch.
They do not by themselves prevent same-tick PID reuse within one boot and namespace, and
ancestor/current-TTY rereads remain sampled facts. The proposed implementation can honestly
claim strict equality and refusal on observed mismatch; it cannot claim unique process
lifetime identity or atomic foreground authorization solely from these fields.

## Narrow follow-up: birth-interval guard and one-entry NSpid

These are proposed derivations against freshly retrieved v6.17 code, not runtime tests.
They strengthen the previous verdict under the conditions stated here.

**Exact conversion support:** `nsec_to_clock_t` uses integer floor division when
`1_000_000_000 % USER_HZ == 0`. The other branches use different integer arithmetic,
including documented approximation and overflow constraints. `H <= 1_000_000` ensures
injective tuple formatting, but alone does not establish that the kernel conversion is
exact `floor(ns * H / 1_000_000_000)`. A narrow implementation can refuse rates outside the
first branch; supporting others requires reproducing their conversion and checking bounds.
[time.c, nsec_to_clock_t](https://raw.githubusercontent.com/torvalds/linux/v6.17/kernel/time/time.c)

For that exact branch, use raw ticks rather than the tuple's synthetic `+1`:

```text
P = 1_000_000_000 // H
B = clock_gettime_ns(CLOCK_BOOTTIME) in the same reader time namespace
accept age only if B >= 0 and B // P > T
equivalently, B >= (T + 1) * P
```

**Derivation:** all starts encoded as `T` lie in `[T*P, (T+1)*P)`. At the stated boundary,
that entire interval has passed. Retain one proc directory, take the age sample, then open
and freshly read `stat` through that same directory and require unchanged identity fields
and a live state. A zombie/dead state, disappearance, namespace mismatch, or failure refuses.
No extra tick is mathematically required for the exact branch. Refuse within the 100 ms
budget rather than wait for a newborn process to age.

The clock must be `CLOCK_BOOTTIME`, not monotonic time since an arbitrary origin: it includes
suspend and matches the source clock used for `start_boottime`. Time-namespace offsets are
frozen after a task joins; the reader must remain in the same namespace for these operations.
[Python CLOCK_BOOTTIME](https://docs.python.org/3.14/library/time.html#time.CLOCK_BOOTTIME),
[time namespace structure](https://raw.githubusercontent.com/torvalds/linux/v6.17/include/linux/time_namespace.h)

**PID-recycling proof condition:** a future replacement must acquire the old number after
the accepted original stops owning it. Upstream `copy_process` calls `alloc_pid` before
recording `start_boottime`; allocation refuses an already occupied requested PID. Thus a
delayed, unpublished fork cannot acquire the original's still-occupied number, record an
old same-tick start, and later publish that replacement. Any later reuse records its start
after the guarded interval. This closes same-tick future reuse for the accepted live token
within the same boot and continuously existing reader namespace, without reserving the PID.
[fork.c](https://raw.githubusercontent.com/torvalds/linux/v6.17/kernel/fork.c),
[pid.c](https://raw.githubusercontent.com/torvalds/linux/v6.17/kernel/pid.c)

**NSpid derivation:** the kernel emits entries from the proc mount's namespace level through
the task's active namespace level. On genuine procfs, exactly one integer in
`/proc/self/status` means those levels coincide. Visibility requires the mount namespace to
be an ancestor of the task's namespace, so equal levels imply the same PID namespace.
Requiring that sole value equal `os.getpid()` completes the process-number check. Requiring
each candidate's dereferenced PID namespace `(st_dev, st_ino)` equal the reader's then
excludes candidates in descendant PID namespaces. This is stronger than stat PID equality
alone and avoids needing `/proc/1` access.
[proc_pid_status(5)](https://man7.org/linux/man-pages/man5/proc_pid_status.5.html),
[array.c namespace loop](https://raw.githubusercontent.com/torvalds/linux/v6.17/fs/proc/array.c)

Counterexamples and limits:

- A current tick comparison of `>= T`, or an approximate epoch tuple, does not prove the
  birth interval has ended. Unsupported conversion arithmetic can invalidate its boundary.
- `NSpid` denotes thread IDs. The stated `getpid()` test is for `/proc/self/status`; applying
  it to an arbitrary thread status may compare a TID with a TGID. Missing `NSpid` refuses.
- A later reader in a different or recreated time namespace is outside this proof. Stored
  namespace numbers alone do not establish object continuity after destruction. Time offset
  changes, arithmetic wrap, substituted proc paths, and restoration/migration require a
  separately justified scope; refuse unexplained evidence rather than generalize the proof.
- The guard addresses future process-token collisions, not terminal lifetime reuse,
  foreground changes, ancestry mutations, or the observation-to-write race.

Two attempted ancillary source fetches (`kernel/time/namespace.c` and
`include/linux/proc_ns.h`) timed out; the frozen-offset condition is supported by the
retrieved time namespace header. Namespace inode allocation/reuse was not independently
established here, so continuity after namespace destruction remains an explicit limitation.


## Schema 2 integration: 2026-10-15

Current implementation baseline: `efbaf3f`. The historical research above is retained. This
checkpoint describes local source and host tests, not newly performed Linux kernel acceptance.

The existing Linux inspector already emitted boot-relative births with complete linuxScope.
The helper still refused Linux, every constructor emitted schema 1, and native validators/keys
rejected or discarded that scope. The ordinary path now accepts explicit Linux context/record
schema 2. Native schema-1 data, birth semantics and path spellings keep their existing behavior.
The command protocol marker remains tavs-portable-ordinary-schema=1: verbs, argument counts,
NUL metadata, Base64 contexts and finite render packets have not changed.

Strict Linux generations contain boot UUID, PID/time namespace device/inode pairs, and ordered
monotonic/boottime offsets. All nested fields and integer bounds are validated. The full scope
participates in keys, physical bindings, foreground/ancestor/continuing-owner checks, and bound
intent admission. Keys use fixed ordered decimal fields in one component, at most 228 ASCII
bytes, without truncation or a hash. Linux targets allow canonical /dev/pts/N; native surfaces and
adoption remain schema-1-only. Identity-free data stays ineligible to authorize device output.

Linux births are not compared with wall-clock observation timestamps. Occurrence timestamps
still receive their existing bounds/order checks, and managed output requires current whole
process generation, concrete TTY/device and continuing owner. Capture, observation, intent,
registration and completed-global target reconstruction propagate the correct explicit schema.
The helper refuses a context from the other platform before mutation. Provider executable
verification on Linux remains unavailable; ordinary foreground correlation stays unverified.

Linux private test roots avoid Darwin confstr. A separate saved-source reproduction on this Mac
showed the old non-strict resolver accepting a cyclic marker path; the new strict-prefix/missing-
suffix resolver refuses it at roots with OSError 62. It also refuses dangling links and retains
private-root containment. This resolver is used only for injected test roots, not production
path repair. A stale generic-helper test was made explicitly native-format with platform/temp-
API doubles, while real Linux subclasses reuse unmocked owned-PTY/helper/hook cases.

All paths were backed up before changes under
`/Volumes/external/data/archive/tmp-by-day/2026-10-15/tavs-linux-ordinary-tp0ui9u8/`.
Scope: eight existing core Python modules and eight test modules, plus existing docs/capture.
This Phase 9 review correction repairs the existing ordinary-platform regression outside the
attention-specific file list. No SPEC/PLAN body or phase status was changed. Writer, ancestry
and input deadlines were not widened. No terminal/app/settings installation or Docker startup
was performed. Swift source is unchanged; prior Swift acceptance/failures remain as recorded.

### Verification

Commands used tests/run-isolated.sh and an explicit source-built helper. Mac-side format/dispatch
runs used private /tmp roots; injected identities are distinct from kernel/PTY acceptance.
Retained command logs:

- Vl6Wv1: three expected RED errors before schema/key/context implementation, 0.020 s.
- rS9IRg: 19 records/context checks pass, 0.019 s, including existing native path/shape checks.
- UZwOnL: 20 cases/one existing root-loop diagnostic failure, subsequently reproduced and fixed.
- QyaIxm: 19 helper/publication/completed-target checks pass, 0.460 s.
- HP3VrH: full 205 portable/one failure and five timeout errors, 33.010 s; eight Linux cases skip.
- cA6u1j: 41 focused/one observation-publication failure, 0.566 s; generic error hides its cause.
- Iubcmh: that observation case passes with only the expected stale-record exception captured;
  this does not attribute the earlier missing error.
- Q1JXDQ: final 41 focused checks pass, 2.149 s. Covers native compatibility and Linux format,
  dispatch, scope/key/copy guards, observation/intent publication and completed target rebuilding.
- MmLhLM: original roots returned a cyclic path; current roots explicitly refuse it. No device
  action was invoked by this saved-source reproduction.
- keFjsW: final full 205 portable/seven failures and 13 errors, 55.189 s, eight Linux skips.
  Broader timeout/status and owned-hook lifetime failures remain open; no all-green claim.

The independent source checker found no confirmed production admission defect and caught stale
Darwin assumptions in generic helper tests. That finding was checked and corrected; its report
was not runtime execution or final provider approval. Reports and full logs are retained with
owned backups. Native foreground/visual acceptance and historical timing causes remain open.

### Next Linux run

The operator chose to start Docker after current jobs finish. Docker was inspected read-only and
was stopped; no automatic start/poll loop is authorized or needed. Eight real Linux cases remain
unrun. After the operator starts it, use an isolated local Linux container/host with private test
roots and readonly source. The existing acceptance slice is:

```bash
TAVS_TEST_HELPER_BIN="$PWD/src/core/portable_helper.py" TMPDIR=/tmp \
  tests/run-isolated.sh env PYTHONPATH=tests/unit python3 -m unittest \
  test_portable_process_identity \
  test_portable_helper.LinuxPortableHelperPTYTests \
  test_portable_helper.LinuxPortableHookRoutingTests
```

Here the launcher's executable prerequisite uses the source ordinary helper. Hook cases supply
a missing native candidate explicitly, so no native app is needed. Verify actual /proc scope,
PTY rdev/process association, fresh helper birth-tick startup, real selection/intake/render,
synthetic/stale refusal and unchanged deadlines. A warmed fixture producer does not prove fresh
production-helper startup. Missing kernel namespace/clock properties remain unavailable; do not
remove the completed-birth-tick guard to manufacture a pass. Linux support and the full goal
remain unverified until this runtime evidence exists.

## Host fixture correction and suite refresh: 2026-10-15

Baseline `f4c1ca9`; only `test_portable_helper.py` changes. The Linux-format dispatch case formerly
selected Linux while inheriting a Darwin `/var/folders` wrapper root. `_roots` correctly rejected
it. The fixture now creates a fresh private `/tmp` root and local marker/runtime/HOME arguments,
reused by positive dispatch and native-token rejection. Real production root checks remain.

A source checker supported that root correction, but its negative-boundary claim needed stronger
evidence: without concrete device injection the native token was refused at identity, before
schema/platform validation. An explicit context-stage expectation reproduced this false-positive
control. The corrected negative case supplies device123, requires context/value rejection, and
asserts no process inspection or Renderer call. Positive dispatch still forbids Darwin confstr.
These are format/dispatch doubles, not Linux kernel/device acceptance. No production code changed.

Retained isolated results, using the explicit source-built helper:

- Hn6NJT: device writer17 pass,1.456s. Historical keFjsW failures do not recur, without attribution.
- vMiEpZ: portable205,one Linux-format root failure,8 Linux skips,9.282s. Earlier timing errors absent.
- ChqWyS: focused root correction passes,0.005s,under the default Darwin runner root.
- R5myKg: portable205 reports OK,8 skips,12.106s (197 host passes).
- 9FtWaG: helper17 pass,0.033s,under a `/tmp` runner.
- eMyZya: strengthened negative control RED,0.006s; actual identity versus expected context stage.
- IzNO8F: final portable205 reports OK,8 skips,8.542s. The new stage-specific control is included.
- X4ovLj: full Swift671,four assertions (two unexpected),32.893s; no all-green native claim.

Current Swift failures are in VisualRecoveryTests:
`testMarkerChangeDuringPolicyCheckRejectsPreviewAfterCachingTarget` times out during prepare;
`testNewIntakeDuringOpenRejectsPrepublishedRenderWithoutReplacingLatestIntent` reports intake
Organizer deadline expiry then expected-stale/deviceNotWritable mismatch; and
`testReconciliationQueuedBeforeSuspensionReadsTheMarkerAfterDeviceOpen` times out during prepare.
These are the next current-state cases to inspect. Earlier Swift and portable failures remain
retained and unattributed. Host load19.72/14.54/20.50 on the initial read is context, not cause proof.
The read-only Docker local-socket check was unavailable; no startup or repeat poll occurred.

Original source, tests, complete logs and the read-only source report are retained in
`/Volumes/external/data/archive/tmp-by-day/2026-10-15/tavs-portable-root-fixture-x3cv3wi6/`.
The source report verified the private-root fix and did not execute tests. No live app install,
settings/schedule changes, terminal paint or existing-session process action occurred. Eight real
Linux cases, native Ghostty acceptance and final goal completion remain open. SPEC/PLAN unchanged.
