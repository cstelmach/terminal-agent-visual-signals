# Phase 6 bounded managed writer recon

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0

## Scope and conclusion

Read-only exploration at HEAD `f067bef` under:

`/Users/cs/local/code/apps/terminal-agent-visual-signals/`

Re-read dated SPEC managed-output/recovery contracts, PLAN Phase 6 and the current
PROGRESS Phase 5 completion. No project edit, build, test, device/process action,
native request or UI operation occurred. The requested report alone was written.

Extend the existing low-level writer, not a second output engine. Queue a typed
operation with its expected target binding. Open the device before locking, then
use one shared per-TTY lock and the ORIGINAL 100 ms deadline to validate the
opened device, current process/surface binding, suspension and current policy.
Compose bytes only there. Recovery uses the same path after persisting suspension.

## Contract and current source anchors

Dated package:

`docs/specs/tavs-priority-discovery_2026-10-04/`

- `SPEC.md:154-164`: latest typed ordinary intent; one coherent background owner;
  no arbitrary OSC parsing inside emit_osc.
- `SPEC.md:179-186`: effect target binding and controller generation/heartbeat
  persisted before paint; dead or six-second-stale ownership releases ordinary
  hooks; failed/unverified bindings remain retryable.
- `SPEC.md:239-279`: persist suspension first; union target recovery; shared
  serialization; opened device before lock; fresh in-lock policy; one 100 ms
  caller deadline; precise restored/vanished/unaffected/failed classification.
- `PLAN.md:292-345`: stable lock inode, every writer routed, independent headless
  recovery and required race/PTY tests.
- PROGRESS records Phase 5 DONE, readers/projections only. Its earlier policy
  checks do not establish Phase 6 output ordering.

Source paths below are under:

`src/macos/TAVSApp/Sources/TAVSApp/`

## Existing 100 ms writer

`ProcessRunner.swift:102`, `SystemProcessRunner.writeToDevice`, calls
`completeDeviceWrite():112`. That method creates an absolute monotonic deadline,
dispatches the worker and waits on a semaphore until the same deadline. A stalled
kernel open can retain a worker, but the caller returns an error.

`writeNonblockingToDevice():126` already:

- checks the deadline before open;
- opens with O_WRONLY/O_NONBLOCK/O_NOCTTY/O_CLOEXEC;
- retries EINTR only within the original deadline;
- closes the descriptor through defer;
- checks the deadline before every partial write;
- handles EINTR/EAGAIN, bounded POLLOUT polling and hangup/error events.

Missing for managed output: opened-fd character-device/rdev verification, shared
lock acquisition, fresh target/ownership/policy validation, typed composition,
effect persistence and a check immediately AFTER open before entering those
operations. The existing loop prevents a late byte write for nonempty Data;
it does not protect new lock/policy/effect work inserted before that loop.

Keep existing nonblocking write mechanics in one internal descriptor-writing
function that accepts the original deadline. Both legacy raw unit tests and the
new managed operation can reuse it. Do not add a second blocking FileHandle
writer or create a fresh 100 ms budget after acquiring/opening something.

## Existing per-TTY lock and the nested-lock trap

`terminal-visual-state.swift:313`, `TerminalVisualStateStore.withLock`, creates
the organizer directory and opens:

```text
organizer/writer-<base64url-exact-TTY>.lock
```

It uses O_RDWR/O_CREAT/O_NOFOLLOW/O_CLOEXEC, requires a regular lock file and uses
`flock(LOCK_EX | LOCK_NB)` with EINTR/EAGAIN handling and 1 ms retries. It starts
its OWN 100 ms deadline at line 330. The inode is currently stable: the function
does not replace/unlink the lock file.

Reuse that lock naming/inode for managed output and recovery. Do not add another
lock directory with a similar filename or unlink an apparently stale in-use lock.
A replacement inode allows two processes to believe they hold the same target lock.

Extend the lock helper to accept an optional caller-supplied absolute deadline;
metadata-only callers can retain their existing default budget. Managed callers
must pass the device writer's deadline. Check deadline before/after lock-file
open, after acquisition, after policy/composition and before each device write.
Use the remaining time for retry sleeps, never restart the budget.

Current publishObservation, publishIntent and coverage EACH acquire withLock.
`coverage(for:)` at line 135 then adopts/reads records inside that lock. Calling
coverage or publishIntent from a callback already holding the same flock is a
self-deadlock/time-out. Expose a small scoped transaction plus existing unlocked
read/write/adoption helpers for the known policy operation, or organize the new
managed method inside the store where it can call those private helpers directly.
Do not solve this with recursive locks, thread-local ownership machinery or a
second lock. The lexical path should make one acquisition apparent.

Regular typed record reads already reject special/symlink/oversized files with
lstat/open/fstat and an 8 KiB bound. Preserve that behavior when adding effects.
Fresh policy reads while holding the output lock must also be nonblocking/bounded
data reads, not an opaque file/subprocess call that can strand the held lock.

## Smallest managed-operation shape

Keep a concrete operation enum/value next to the managed writer/recovery code,
with only operations this phase actually needs. For example:

- ordinary background intent, with its existing delivery/producer binding;
- current global restriction, meaning re-evaluate current mute/lock/suspension;
- clear/recompose background from current typed intent/default;
- emergency recovery reset, fixed OSC 104/110/111 contract.

The low-level ProcessRunner owns deadline/open/lock/write mechanics. The typed
policy body owns validating a current bound target, record ownership/liveness and
constructing the allowed byte sequence. A narrowly injected policy closure is
enough; no generic adapter framework is needed. Do not queue arbitrary Data and
attach a boolean named restrictive: a previously selected pause/lock can no
longer be authoritative after rules or suspension change.

No native AppleEvent or two-second configuration subprocess belongs inside the
100 ms locked body. Native catalogue validation has its separate bound before
dispatch. Inside serialization, recheck current kernel generations, opened-fd
device and validated continuing binding; use the current typed records/policy.
If a fresh native identity refresh failed, do not apply new effects from stale
catalogue rows. Unknown binding is an explicit failure, not a fallback target.

### Ordered operation outline

1. Set one absolute 100 ms deadline in completeDeviceWrite.
2. Worker checks deadline, opens the candidate device without acquiring any lock.
3. Defer close; immediately reject a late open. fstat the ACTUAL fd, requiring
   character-special mode and matching expected st_rdev bit pattern.
4. Acquire the stable same-TTY file lock using the remaining deadline.
5. Inside it, verify the expected native/application or continuing TTY-owner
   generation and current fd device, then fresh-read suspension. Phase 5's
   unavailable state disables restrictions just like suspended state.
6. Fresh-read current mute/lock/grant/ordinary intent/effect ownership and compose
   CURRENT policy, not the scheduler's queued snapshot. Recheck the relevant
   producer/delivery for synthetic work. A dead or six-second-stale controller
   cannot block legitimate current ordinary intent.
7. Persist the effect/binding/owner record before a restrictive paint. Record
   attempted/retained targets honestly; do not claim that persistence proves
   the bytes were visibly delivered.
8. Check deadline again and write with the existing partial-write/poll loop,
   keeping the same lock through completion/failure. Defer unlock/close on every
   return/error. Report skipped-policy only for a valid unaffected operation;
   failed validation/busy/timeouts remain failed/unverified.

Effect records retain exact target binding and controller process generation,
plus the latest effect/heartbeat, even for unregistered plain shells. They are
runtime product state required for recovery, not a separate process ledger.

### Why fd validation and process validation are both needed

Current `ProcessIdentity.deviceNumber(path)` checks the path's lstat/rdev.
That cannot establish which object was actually opened after a delayed open.
Use fstat(fd).st_rdev inside the operation, with UInt32(bitPattern: dev_t).
Never authorize a managed write to a regular capture file as if it were a terminal.

Device number alone cannot distinguish TTY reuse. Require retained process PID
plus kernel start seconds/microseconds and controlling device; where appropriate,
use existing foregroundFamilyContains against current validated foreground
generation. A native terminal ID alone is not application-generation authority.
Cached recovery may use a verified continuing TTY-owner generation when Automation
is absent, as the spec permits; unknown/exited inspection is not affirmative
authorization to paint whatever now occupies that path.

## Recovery ordering and queued restrictions

Recovery persists suspension BEFORE acquiring output locks, invalidates temporary
ownership/pending output under the relevant target transaction, then sends the
fixed reset on each valid target using the SAME lock/deadline mechanics.

An old writer that checks policy after persistence rejects its restrictive plan.
An old writer already inside serialization may finish first; recovery cannot
reset until that older write releases the lock, so reset wins afterward. This
is the guarantee. A pre-generation check followed by unlocked output, or a
second reset after arbitrary sleeps, does not establish it.

Check deadline after every paused/slow segment. If a worker returns from open
after its caller timed out, it must close the fd without acquiring ownership or
painting. If a policy callback was delayed past the deadline, do not paint its
eventual result. Persisted effects for partial failures remain retryable rather
than being removed on generic I/O errors.

## Concrete production callers that must change

- `Broadcaster.broadcastPaused` and `broadcastLocked`: currently build bytes
  from a supplied visual/until text and call writeToAllActiveTTYs. Queue a current
  typed rule operation instead; recheck suspension, grants and rule expiry under
  the lock. Preserve legitimate existing global-pause byte semantics.
- `Broadcaster.broadcastPausedClear`: fixed reset bytes are reusable, but device
  delivery must use the managed path and distinguish normal recompose versus
  emergency reset. Preview/background-only clear must not use OSC 104/110.
- `Broadcaster.broadcast`: currently replays opaque pending Data and deletes
  candidate/pending files on failure. Replace controlled replay with current
  typed background intent or explicit unsupported behavior; do not parse/strip
  arbitrary cached OSC. Recovery/resume must not replay historical BEL or title.
- `Scheduler.clearPausedVisualAndReplayPending`: still invokes clear then opaque
  broadcast. Connect it to the new typed policy/recompose path as the later
  global-release contract requires; no unprotected reset should remain.
- `src/core/terminal-osc-sequences.sh:99`, send_osc_bg: currently publishes intent
  then directly emits OSC 11/111. Extend the existing organizer bridge to request
  managed semantic output so an active controller cannot be erased by an ordinary
  hook. Preserve ordinary signaling when no controller owns an effect.
- `src/core/organizer-state.sh`: existing capability-safe helper selection and
  metadata calls are reusable for a concrete managed verb. An unsupported/failed
  helper must not silently fall through to an unguarded restrictive paint.
- `src/shell/tavs-shellrc.sh:159-182`: pause/lock bytes still printf directly after
  an earlier policy read. Route the known startup rule operation through the
  helper, retaining standalone reader/status behavior and exact shell TTY.
- `src/core/idle-worker-background.sh:134-146`: forced reset currently bypasses
  suppression and directly resets palette/title around send_osc_bg. Gate that
  synthetic reset through current binding/policy before any reset styling;
  a stale delivery cannot send extra reset bytes after background rejection.
- `src/core/trigger.sh` debug replay cats cached output to a device. Make it a
  typed current-intent operation or reject opaque replay; no raw replay bypass.
- Delayed tool-error and ordinary idle paths already carry intake identity after
  Phase 4. Preserve it and enforce fresh producer/delivery validation at output.
- New headless recovery/managed entry points belong before GUI/login/default
  scheduler construction. CLI suspension persistence precedes helper resolution;
  reuse the existing safe capability query pattern for old binaries.

Legitimate current nonbackground hook palette/title/BEL/image behavior should
not be globally removed. Work at semantic helpers/known operation builders;
do not make emit_osc an arbitrary stream parser. Queued synthetic/opaque resets
are distinct from an actual new bound hook event.

## Failure retention and old tests

Broadcaster currently deletes candidates on any write error at lines 71-75 and
162-165. It also deletes registry entries on attribute failure or 24 h age at
lines 184-192. None of those alone proves the native/TTY-owner binding vanished.
Recovery must enumerate the union of effect state, markers and available native
catalogue, then classify. Retain live/uncertain/busy/backpressured candidates for
retry; retire only confirmed closed/invalid lifetimes with adequate evidence.

Existing tests intentionally require wrong behavior for the new contract:
testBroadcastPrunesDeadTTY, testBroadcastPausedPrunesDeadTTY and the mixed PTY
restore test infer death from deviceNotWritable/disconnection. Revise them to
assert retention for generic failure and add an independent confirmed-vanished
case. Age-pruning tests likewise cannot stand as recovery disappearance proof.
Missing/obsolete pending-file invalidation is separate from dropping the target.

## Test seams and meaningful cases

Exact Swift test root is the existing TAVSApp/Tests/TAVSAppTests directory.
Use planned visual-recovery-tests.swift, process-runner-tests.swift,
terminal-visual-state-tests.swift and current BroadcasterTests.swift.

Existing good coverage: exact PTY bytes, large partial writes, disconnected PTY,
wedged operation/caller timeout, full queue deadline and mixed healthy/dead fanout.
The raw writer tests do not prove managed ordering. The store's existing
testBoundedLockDoesNotBlockAnotherTTY proves independent metadata locks only.

Small seams: injectable device open and one pre-policy callback/barrier, defaulting
to real primitives/no-op. Keep them in the low-level writer rather than a new
test harness framework. Extend MockProcessRunner with a managed-operation capture/
handler that exercises fresh policy; a mock that merely records prebuilt Data
cannot verify this contract.

- Paused before open: persist suspension, release the barrier before deadline;
  restrictive output is rejected. Separately release after timeout and assert
  no late lock/paint/effect recreation.
- Late open: injected open returns a real owned PTY fd after caller timeout;
  verify it is closed and no bytes/ownership follow.
- Paused before policy after lock acquisition: persist suspension, start recovery,
  release the writer while its deadline remains valid; writer fresh-check rejects
  and recovery reset follows. A separate older completed-write case proves reset
  ordering when policy was checked before suspension.
- Busy lock: hold the stable inode with a separate descriptor, attempt the writer,
  verify total caller budget remains one 100 ms interval and another TTY succeeds.
  Assert same lock inode survives retries; no unlink/replacement workaround.
- Descriptor mismatch: opened fd points to a different owned PTY/regular file;
  cached expected device/generation cannot authorize bytes. Use injected process
  snapshots for deterministic PID/start/device changes, without querying others.
- Policy changes: queued lock ends, grant starts or suspension becomes unavailable
  before lock/policy; current rules, not old supplied bytes, determine output.
- Backpressure/partial failure: preserve existing exact/large-byte tests, then
  validate managed failure classification and retryable effect records.
- Healthy fanout: wedged/busy/unverified target does not prevent independent
  healthy reset. Report per-target counts accurately; generic I/O failure cannot
  count as vanished. Zero affected targets is saved suspension with zero restored.
- Cached plain shell/no Automation: validated continuing owner/device allows reset;
  missing/unverifiable/reused owner does not. No native call is needed for the
  cached valid case.
- Nested-lock regression: the actual typed policy transaction executes once under
  the same lock without calling coverage/publish methods that reacquire it.
- Reset bytes and resume: assert exactly permitted default reset bytes, no OSC 0
  or historical BEL/title replay, unchanged definitions and preserved typed intent.

Owned PTYs do not automatically make the test process their controlling TTY.
Use an explicit owned-holder setup or injected identity snapshots for the writer
validation cases; never weaken production identity checks to accept regular
capture files. No proposed test was run during this reconnaissance.
