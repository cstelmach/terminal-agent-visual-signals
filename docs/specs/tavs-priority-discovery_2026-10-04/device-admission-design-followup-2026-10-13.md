# TAVS device-worker admission

Last Updated: 2026-10-13
Version: 1
Inspected baseline: `3c1c451`+
## Conclusion

The smallest connected fix is a process-wide native-I/O admission guard inside the existing
bounded worker, after `beforeOpen` and before native device open. Keep the permit until the
worker actually finishes, including late descriptor close and lock release. A caller timeout
must not release it.

Use at most one admitted operation per validated physical TTY lifetime across SystemProcessRunner
instances. If a literal finite total worker bound is required, also cap the number of admitted
operations with one private process-wide capacity constant. A global cap has a real saturation
tradeoff: if all K slots are held by distinct stuck calls, a new otherwise healthy target cannot
be admitted. No semaphore can guarantee both a finite K and admission of arbitrary new healthy
targets while those K calls cannot be canceled.

This is a read-only source/design check. No tests, builds, native queries, devices, hooks,
installations or user payloads were inspected/executed. Only this requested report was created.

Paths below are relative to:
`/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/`.

## Current amplification

`Sources/TAVSApp/ProcessRunner.swift:199`, `completeDeviceWrite`, dispatches a new global-queue
worker for every call. Its semaphore bounds the caller to 100 ms but does not cancel a blocked
open, callback or write. Repeating an operation after timeout can therefore create another
native operation while the earlier worker still exists.

`openNonblockingDevice` protects against late open results by closing the returned descriptor
and refusing policy/output after expiry. That protects late work, but does not bound the number
of workers still stuck inside open. Nonblocking backpressure retries also remain correctly
bounded by the same deadline; admission must cover that whole I/O interval, not only open.

`VisualRecovery.performWrite` supplies typed intent publication or exact-ID metadata cancellation
through `beforeOpen`. The managed runner currently executes that callback on the worker, releases
its metadata lock, opens the device, then acquires output serialization and runs fresh preparation.

## Where admission belongs

### Guarding completeDeviceWrite before dispatch

A busy-key check before dispatch bounds repeated workers earliest, but also prevents `beforeOpen`
from running. New ordinary background intent would be lost merely because a prior open is stuck.
It would also skip exact-ID focus/preview metadata cancellation, allowing old leases to remain
authoritative while physical output is unavailable.

Moving publication synchronously onto the caller to compensate is unsafe: the existing tests
deliberately block publication, and the caller must still return within its original 100 ms.
Creating a second independently budgeted publication attempt would violate the one-budget contract.

### Guarding native I/O after beforeOpen

The correct order is:

1. Create the original monotonic 100 ms deadline once.
2. Dispatch the existing worker and check that deadline.
3. Run `beforeOpen` once under that same deadline, including metadata locking/publication.
4. Check the original deadline, then try process-wide I/O admission for this physical lifetime.
5. If busy/full, report explicit device failure without open, policy preparation or output.
6. If admitted, retain the permit through open, output-lock acquisition, preparation, write,
   unlock and descriptor close; release it only when that actual operation unwinds.

Keep beforeOpen outside the native-I/O permit so successive busy-target requests can update
latest typed intent or cancel matching metadata without creating another stuck device operation.
These short metadata workers can still be dispatched; the admission bound specifically limits
native open/write work, not arbitrary injected callback code or every possible filesystem stall.

Busy is a partial failure, not successful unaffected output or proof of disappearance. Existing
`deviceIOFailed(path, EBUSY)` can express it without another public result hierarchy.
VisualRecovery already reports generic managed failures and retains retry targets.

## State and lifetime key

Use a small static lock-protected in-flight collection shared across SystemProcessRunner objects.
An instance-local guard would be bypassed by another runner for the same target. Do not add a
service, worker queue per TTY, persistent admission file, registry, watchdog or process manager.

For managed writes, reuse `TerminalTargetBinding.physicalTarget` as the key: TTY path, device
number and continuing-owner PID/start generation, with nativeSurface removed. VisualRecovery
already validates that binding before calling the runner. Pass this existing value through the
managed API instead of reconstructing authority inside ProcessRunner.

- Plain/native aliases of one physical lifetime must share admission.
- An agent producer change on the same continuing shell is not a new physical lifetime.
- A reused path/device number with a validated new continuing-owner generation is a different
  lifetime and may be admitted while the old worker is still draining, subject to any global cap.
- Old worker completion must remove only its own key. A path-only remove can mistakenly release
  the new lifetime's permit.

Path alone, or the stable per-TTY lockURL alone, is not a lifetime key. Including native terminal
ID would incorrectly give aliases independent permits. Avoid inventing metadata fingerprints,
TTL-based permit release or provider/session request IDs.

Current production device calls all enter through VisualRecovery's managed path; raw
writeToDevice/completeDeviceWrite remain exposed and tested. An unresolved raw call lacks a
validated owner generation. Its conservative admission can be keyed by path and must not claim
TTY-reuse precision it cannot establish. Do not let an unresolved raw slot silently bypass a
known same-path managed operation when enforcing the same-target bound.

## Global capacity and independent healthy targets

One in-flight slot per lifetime prevents repeated calls to one stuck target from amplifying
workers. It does not provide a finite total bound across unlimited distinct targets or reused
lifetimes. A finite total bound needs a private capacity K in addition to duplicate-key exclusion.

Do not use one serial I/O worker: one blocked open would hold every healthy target behind it.
With separate admitted workers, one stuck target consumes one slot and unrelated targets can
continue whenever capacity remains. Same-key busy calls should not reserve additional slots or
queue native I/O behind the stuck operation.

At full capacity, return an honest capacity failure within the original deadline. If brief
capacity waiting is desired for healthy bursts, it must use the remaining original budget and
must not reset the 100 ms deadline. K is an internal resource limit, not a new user setting.
Choose its production value against the existing fanout acceptance; no source evidence here
establishes an optimal numeric value. Tests can use a small isolated capacity to cover saturation.

Never drop an old permit merely because the caller timed out or its target lifetime ended:
that worker may still be blocked. Lifetime separation permits safe new-target identity, while
the optional global cap still accounts for old workers consuming actual resources.

## Publication and output limits to preserve

A stuck open does not hold the output lock, so a later beforeOpen can publish a newer intent
before its device-I/O attempt is rejected as busy. The existing prepublication tests already
establish that ordering. The guard must preserve ordinary, forced-reset and metadata-clear paths.

If an old operation is stuck while holding the stable output lock, beforeOpen may itself fail
to acquire that lock within 100 ms. Existing tests correctly preserve the previous intent and
report failure in this situation. Admission alone cannot guarantee publication through a lock
still held by another worker; do not remove locking or publish unsynchronized data to pretend
otherwise.

Releasing a stalled open after caller expiry must still close its fd, skip policy/paint and
release its exact admission key. Admission does not cancel a syscall already entered or undo
bytes already committed. Retain the existing descriptor validation, deadline checks, fresh
policy and output serialization rather than claiming stronger cancellation from the guard.

## Concrete regression seams

Reuse ProcessRunnerTests' injected openDevice, owned PTYs, private roots, semaphores, injected
state lookup and exact original-deadline assertions. Do not need a native app or real wedged TTY.

1. Block one injected open and let its caller time out. Repeat the same lifetime through many
   runner instances. Assert native open count remains one while later beforeOpen callbacks run,
   and all callers finish within their original budgets with explicit failures.
2. On that busy lifetime, publish a newer ordinary intent in a second beforeOpen. Assert the
   latest stored/bound color survives, no second device open occurs and the old late result
   cannot overwrite it. Include exact-ID metadata cancellation while busy.
3. While A is blocked, write healthy B. Assert B completes independently while capacity remains.
   Keep `testManagedBackpressureDoesNotDelayHealthyIndependentWrite`.
4. Release A after expiry. Assert its descriptor closes and policy/output are skipped; a fresh
   same-lifetime request can then acquire the released permit.
5. Simulate two validated owner generations for the same path. Admit the new lifetime while old
   open is blocked and verify the old worker's release does not remove the new permit. Never
   infer the new lifetime from arbitrary changed provider IDs.
6. Keep a post-open operation alive through injected blocked prepare, or use a narrowly injected
   write closure if exact write-phase coverage is necessary. Caller timeout must not release its
   permit while that operation still holds its fd/lock. The existing late-policy test supplies
   the first seam without changing production I/O.
7. Fill an isolated small global capacity with distinct blocked lifetimes. Assert count never
   exceeds K, further I/O fails explicitly, publication still runs where its lock is available,
   and a completed worker permits another admission. Do not assert unconditional healthy
   admission after all K permits are indefinitely occupied.
8. Preserve EINTR retry, one beforeOpen call, shared deadline, publication failure-before-open,
   busy output lock, late descriptor close and policy failure tests.

All blocked test seams must be released in defer so static admission does not contaminate later
tests. Direct worker counters are enough; no fingerprints or additional process artifacts are
needed.
