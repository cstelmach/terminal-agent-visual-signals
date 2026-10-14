# Initial paint and record deadline source checks

Last Updated: 2026-10-14
Version: 1.1

Original report scope: initial manual paint, late-preview timer fixture, managed writer callbacks and
recovery result translation. No source edits, builds, tests or app control were performed.

## Conclusion

No deterministic production defect or historical EPERM cause is established by this source
inspection. The smallest useful next step is a test-local recorder in the two reproducing tests.
It must record both the managed writer's Boolean and its original error, plus monotonic open and
prepare entry/exit. Keep the existing 100 ms deadline and exact physical-target admission.

## Confirmed observation gaps

- `FocusControllerTests.awaitManual` accepts a status containing either `outside` or `unavailable`.
  A result such as `1 of 1 outside mapped; 1 failed` satisfies that wait and also satisfies the
  current assertion that status does not contain `unavailable`. The manual diagnostic catches
  thrown errors, but currently does not capture successful `false` returns.
- `VisualRecovery.fanout` maps a writer `false` to `.unaffected`. Arbitrary thrown errors become
  `.failed` with the fixed reason `Managed restoration unavailable.` Thus the visible text cannot
  distinguish timeout, EBUSY, storage failure or target revalidation failure.
- `testLatePreviewTimerSchedulingUsesTheRemainingDisplayLifetime` only intercepts open. Its
  semaphore proves that the callback was reached. It does not prove Darwin.open succeeded or
  show how much of the real 100 ms budget had already elapsed.
- The mock's `managedBeforeOpenHandler` signature omits target and emergency, though the mock
  records target separately. Delegating through the short writer overload sets target to nil.
  That changes admission: a nil target conflicts with every writer on that path. Both examined
  tests issue non-emergency operations and can safely forward their known captured target using
  `target: captured.physicalTarget, emergency: false` without changing the shared mock API.

## Smallest diagnostic

Use one local NSLock-protected event list per reproducing test. Do not add production logging or
print payloads. Each event needs only the stage, monotonic uptime nanoseconds, optional supplied
writer deadline, result and original error description. Record:

1. Handler entry, then instantiate/delegate to SystemProcessRunner with an injected open callback.
2. Open entry and exit, including returned descriptor and immediately captured errno on failure.
   Preserve the original flags. After recording, restore errno before returning a failed open:
   recorder locking/formatting must not change the errno used for EINTR handling.
3. Wrapped beforeOpen entry/exit/error when the original beforeOpen exists. Preserve nil when it
   does not exist. Forward the same deadline unchanged, and rethrow the same error.
4. Wrapped prepare entry/exit/error. Forward the same fd and deadline. Record nil versus Data
   length, not content. Return the original Data unchanged, and rethrow the original error.
5. Caller return true/false or throw, with total uptime elapsed and the full event snapshot.

The prepare deadline permits remaining-budget calculation (`deadline > now ? deadline-now : 0`).
Open has no deadline parameter. Its entry/exit offsets from handler entry remain useful; if
beforeOpen supplied a deadline earlier, record that too. Do not manufacture a new deadline to
fill the gap. Explicitly assert that the initial attempt exists, returned true and had no error
before attempting the expected PTY read. Failure text should include final controller status.

For the late-preview test, retain its one-shot virtual-clock advance and semaphore in the open
callback. They test the timer's remaining display lifetime. Instrument around those existing
operations, rather than replacing them. Use its exact captured row target when delegating.

## Cleanup and interpretation

`completeDeviceWrite` creates its deadline before global-queue dispatch. Queue delay, metadata
publication, admission, open, writer-lock creation/acquisition, preparation and descriptor output
all share that deadline. A timeout returns to the caller without joining the worker. Therefore
caller throw is not proof that callbacks have stopped using the fixture.

The fixtures close PTYs and remove their root in teardown without a general controller drain.
Both examined tests can throw from the initial PTY read before executing their explicit clear.
On successful paths, restored bytes can arrive before admission release and before the main-queue
cleanup publication. These are confirmed lifecycle gaps, but do not prove the reported earlier
EPERM or a new production defect.

Subscribe before clear and await cleanupError/focusCleanupError publication to establish normal
controller completion. On a writer timeout, report which callbacks remain unfinished; publication
alone cannot establish worker exit. Do not add arbitrary sleeps or silently increase the budget.
A new explicit full-worker completion hook would exceed the smallest diagnostic and should wait
for actual captured evidence.

The first manual update begins with no prior focus leases, so color-recipe retirement cannot wait
on an existing same-controller lease during that initial paint. The late preview fixture has no
predecessor preview on its first paint. Fresh-process failure evidence also means predecessor
fixture teardown is not a necessary explanation. Run the two instrumented cases sequentially and
stop on the first captured original failure; passing retries do not close the diagnosis.

## Source pointers

- `Tests/TAVSAppTests/focus-controller-tests.swift`: tearDownWithError, awaitManual,
  testManualCapturedSetIsIndependentOfPreviewAndClearsLatestIntent, and
  testLatePreviewTimerSchedulingUsesTheRemainingDisplayLifetime.
  These fixture lines changed during the parent's concurrent diagnostic edit.
- `Tests/TAVSAppTests/Mocks/MockProcessRunner.swift`: lines 11 and 62-85.
- `Sources/TAVSApp/ProcessRunner.swift`: lines 159-245 and 265-283.
- `Sources/TAVSApp/visual-recovery.swift`: lines 211-214, 246-279 and 548-590.
- `Sources/TAVSApp/focus-controller.swift`: lines 51-114, 117-162 and 429-449.

## Addendum: queued full recovery fixtures

Last Updated: 2026-10-14

Read TJMEY4's complete owned log and current VisualRecoveryTests source. The forced-reset fixture
failed at its queued result assertion with deviceWriteTimedOut. Its open callback holds an already
running 100 ms writer while the main test executes full recover, reads reset bytes and asserts
results. Finishing all that before release is an incidental wall-clock requirement of this fixture,
not its semantic purpose of rejecting a captured pre-recovery revision.

The render-case attribution differs: its errors at lines 550 and 552 occur in the subsequent fresh
`recovery().render` and expected-byte read. The queued result assertion at line 548 did not fail.
The proposed correction cannot alone establish the cause of that fresh render's Organizer deadline
exceeded. Preserve that failure as unresolved if it recurs with the corrected fixture.

### Recommended bounded fixture correction

Use a MockProcessRunner handler local to each test. Require its original beforeOpen callback, then:

1. Invoke that callback exactly once under SystemProcessRunner.completeDeviceWrite's own bounded
   deadline, retaining entry/exit deadline checks. That captures the old render revision and
   publishes the original ordinary/forced-reset metadata through the existing code.
2. Signal entered and wait for release outside a device writer budget. The test performs unchanged
   full recover, reset-byte assertion and optional explicit resume while paused there.
3. Start a real SystemProcessRunner managed write with `beforeOpen: nil`, the original prepare
   closure, exact known `target.physicalTarget`, and `emergency: false`.

The prepare closure still holds the original captured renderRevision. Its original fresh-deadline
revision check must return nil after recover/resume replaced the marker, yielding false without
style, palette or historical title replay. No re-publication or re-capture may occur after release.
This is a test-local publication/admission boundary fixture, not a proposal to split production
writer budgets. Production keeps one 100 ms deadline; independent writer tests must retain coverage
of late open/preparation deadlines. Keep a clear comment explaining this semantic scope.

### Alternatives

Accepting deviceWriteTimedOut in the current fixture would allow elapsed time to prove rejection
without exercising revision invalidation. It also needs actual late-worker drain before closing
PTYs/removing roots. It is suitable for a separate timeout test, not this revision test.

Writing only a suspension marker inside prepare can deterministically exercise a revision change,
but omits full recovery's metadata/pending invalidation and optional resume flow. Invoking full
recover inside prepare reenters output/state locks while the original writer owns its lock, adding
a deadline/lock-contention dependency instead of removing one. The proposed boundary fixture
retains more of the intended recovery semantics with less timing coupling.

## Parent disposition: 2026-10-14 11:32 CEST

The original observation gaps and target/errno cautions match current source. `434c1fc` records
all outcomes locally and awaits successful controller cleanup. Seven fresh pairs passed before
the final stage-outcome refinement; no original first-paint error reproduced. The changed recovery
fixtures execute original beforeOpen once under a bounded call, gate outside the device budget,
and preserve original prepare/revision with exact target. Full recover/reset/resume assertions stay.
Mycxxb passed four cases; 0c67dG passed all 570 tests in 18.460 seconds. TJMEY4 remains a failed
full run with three unexpected assertions. The later fresh render error is not attributed to the
barrier, nor are historical first paint/EPERM failures. No production deadline was split or widened.
The source check ran no tests and establishes no native acceptance. Required Linux/native checks
remain open. Parent notes do not replace the original report above.


---

# TAVS deadline-stage source exploration

Last Updated: 2026-10-14 (Europe/Vienna)
Version: 1.0
Current tracked source: `8ab30a0 docs: Record provider checks and full-suite failures`.
Workspace: `/Users/cs/local/code/apps/terminal-agent-visual-signals`.
Scope: read-only source and preserved-log inspection. No tests, suites, apps, settings, terminal
output, installs, or other-process termination. This report is the only authored output.

## Findings and limits

The two historical full runs remain failures. Source and logs establish deadline placement and
some outcome classes, but they contain no enqueue, worker-start, file-operation, or parent-return
stage timestamps. They cannot establish a host-load cause. The focused passes described in the
source-check report cannot establish that cause either.

The most useful next diagnostic is a test-local decorator around the real `SystemProcessRunner`,
forwarding its complete managed-write signature, with timestamps around actual callbacks and
its existing `openDevice` injection. This distinguishes substantial portions of the path while
retaining the 100 ms deadline. Do not substitute the shorter MockProcessRunner handler as a
transparent wrapper: that handler omits target and emergency parameters.

Exact atomic-parent/temp-open/write/rename attribution has no existing injection seam. Measure
public store calls first. If that aggregate remains unresolved, the smallest additional source
instrumentation is direct local stage marks in the existing helpers, with no new scheduling,
retry, deadline, or persistence layer. Those marks would observe a future run, not recover the
missing historical timings.

## Preserved log evidence

Read afresh:

- `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.7cN3d0/command.log`
- `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.2S03Yz/command.log`
- `docs/specs/tavs-priority-discovery_2026-10-04/provider-synthetic-source-check-2026-10-14.md`

`7cN3d0`, lines 564-567: the PID-file read at `process-runner-tests.swift:72` threw Cocoa 260,
with an underlying ENOENT. The test had already accepted `processTimedOut`. There was no failure
of its `<0.7 seconds` assertion at line 71. XCTest reports 1.542 seconds for the entire case;
that total does not establish the duration of `runBounded`, and includes work outside that
asserted interval. Full-suite result: 616 tests, two unexpected failures, lines 1325-1328.

`2S03Yz`, nine affected methods:

| Method | Logged failure | Entire case time |
|---|---|---:|
| testBindingRequiresExactLatestRecordAndReportsCorruptBoundIntent | Organizer deadline exceeded, store:602 | 0.387 s |
| testEffectMetadataRejectsUnknownPayloadsFutureTimesAndColors | Organizer deadline exceeded, store:1112 | 0.139 s |
| testCompleteRenderUsesOneWriteAndCurrentSelectiveBackground | Organizer deadline exceeded, runner:228 | 0.137 s |
| testFailedPersistenceStartsNeitherDiscoveryNorDeviceOutput | Organizer deadline exceeded, runner:228 | 0.106 s |
| testFocusCancellationEvidenceDoesNotClaimPaintUnderGlobalRule | deviceWriteTimedOut, then absent cancellation evidence/assertion failures | 0.203 s |
| testFocusClearCancelsMetadataBeforeADeviceFailure | Organizer deadline exceeded, runner:228 | 0.113 s |
| testFocusRenewalAndExactClearPreserveASeparatePreview | Organizer deadline exceeded, then PTY read timeout | 1.340 s |
| testGlobalPauseAndPreviewReleaseRecomposeDynamicFocus | deviceWriteTimedOut, runner:228 | 0.167 s |
| testOldFocusClearCannotCancelANewerRunAndPlainAliasUsesNativeRecipe | Organizer deadline exceeded, runner:228 | 0.164 s |

The logged catch/rethrow lines do not identify the stage that first exceeded the deadline.
Store line 1112 is the write helper's typed-error rethrow; runner line 228 is the completed
worker result's rethrow. A `deviceWriteTimedOut` rethrown at line 228 could originate within
the worker; that line alone is not evidence of the parent semaphore branch at lines 224-226.
The entire-case durations also combine several operations and fixture work.

## The shared 100 ms device path

`ProcessRunner.swift:217-228` starts one monotonic deadline at `DispatchTime.now() + 100 ms`
before `DispatchQueue.global(qos: .userInitiated).async`. It waits on a semaphore against that
same deadline. There is no budget restart when the worker begins.

Managed-write stages, `ProcessRunner.swift:159-211`:

1. Global-worker queue/scheduling delay after the original deadline is created.
2. Initial deadline check, then optional `beforeOpen`, then another deadline check.
3. Admission: validate target path, standardize path, acquire the static NSLock, scan the
   in-flight set, insert the key. The key contains physical target plus emergency lane.
4. Injected device open with O_NONBLOCK/O_NOCTTY/O_CLOEXEC. EINTR retries use the same deadline.
5. Post-open deadline check. A descriptor that arrives after expiry is closed immediately.
6. Create lock parent directory, lstat it, open lock file, fstat its type/mode.
7. Acquire per-TTY flock using LOCK_NB and <=1 ms sleeps, against the original deadline.
8. Run `prepare(device, deadline)` under that lock and check the same deadline afterward.
9. Write bytes with partial-write/EINTR/EAGAIN/poll handling, against the original deadline.
10. Unlock/close lock, close device, release admission; publish result and signal completion.
11. Parent resumes from semaphore and either returns the worker result or reports its own timeout.

All these stages share 100 ms. Individual Foundation/filesystem/NSLock calls are synchronous;
checks before and after do not interrupt a syscall while it is blocked. The outer semaphore
protects caller progress during a stalled device worker. On caller timeout the worker survives
until its operation finishes; its in-flight reservation survives until its defer runs.

Admission is intentionally after prepublication, so a busy/stuck device may still receive the
latest metadata publication without multiplying actual opens. Source test
`testPostOpenPreparationRetainsAdmissionAfterCallerTimeout` checks exactly that behavior.
Changing order to reduce work would change this delivery contract.

The static admission NSLock has no timeout-aware acquisition. Its current critical sections
perform only set operations, but scheduling while an owner holds it could delay another worker.
There is no source/log evidence that this occurred historically.

## Metadata work and parent preparation

Store `withLock`, lines 976-1026, repeats organizer-directory create/lstat, lock open/fstat,
and flock acquisition. A supplied managed deadline covers those stages and the body. With no
supplied deadline, its locally created 100 ms budget begins at line 1005 and bounds only the
flock wait; directory/open/fstat and the body are not covered by that local budget.

Store standalone tests create real monotonic 100 ms deadlines (`terminal-visual-state-tests:
1294`). Their VirtualClock controls record/lease time, not these wall-clock deadlines. Those
standalone failures do not involve the global device worker at all. The metadata test at line
877 is a valid save after earlier invalid-input checks; its cold target path includes both
`target.json` and `effect.json` creation. The binding test's valid bind at line 1266 similarly
can create a target record and bound intent. Historical logs do not show which nested call
failed in the binding test.

Cold `cacheTargetUnlocked`, store:223-234:

- validate target structure and current device/process identity;
- read existing target record if present;
- if absent, prepare target directory then atomically write target.json.

`prepareTargetDirectory`, store:551-582:

- always asks FileManager to create the organizer root and lstats that root;
- walks every relative path component;
- lstats an existing component twice, once for absence and once for final type verification;
- creates an absent component, handles a competing creator by rechecking it, then verifies type;
- retains deadline checks around these operations.

It runs only when `target.json` is absent. An already-cached matching target returns early, so
it is inaccurate to say every effect heartbeat repeats parent-directory preparation.
It does still validate/read cached target metadata.

The atomic record write itself, store:1088-1113, does not prepare directories. It encodes JSON,
checks size <=8192 bytes, creates a unique 0600 temporary file, writes all bytes, renames it
onto the record, then checks the deadline again. Its defer closes/unlinks the temporary name.

Connected repeated metadata paths are source-visible:

- `VisualRecovery.performWrite` beforeOpen publishes ordinary intent under the store lock
  (`visual-recovery.swift:158-170`). Publication enumerates equivalent bindings, validates
  producer/continuing owner, reads observation and latest intent, writes global intent, then
  binds target intent (`terminal-visual-state.swift:633-648`,724-766,380-398).
- After device open, the runner recreates/verifies the same organizer directory and opens the
  same stable lock again (`ProcessRunner.swift:171-204`). This follows the deliberate release
  of the metadata lock during device open.
- Preparation caches/reads the target again (`visual-recovery.swift:233`), enumerates bindings
  and reads three effect slots per alias (`:238`,600-604).
- An ordinary publication is published/bound again during preparation (`:305-313`), preserving
  the newer-intake check after a delayed open.
- Focus preparation reads effects, ordinary intent/bindings, saves the focus effect, then rereads
  effects (`:238`,280,289,292). `saveEffectUnlocked` itself rereads the current slot and cached
  target before writing (`terminal-visual-state.swift:252-268`).

These are real work candidates, not proven unnecessary operations or measured bottlenecks.
Removing rereads/publication without proving the intervening-open race contract would be unsafe.

## Source-verified limits, not established historical causes

1. The process timeout test assumes the shell executes its PID-file write within 150 ms of the
   runner's deadline start. No startup handshake or observed-launch callback establishes that.
   A valid owned-process timeout may kill the child before that write, causing the test's reap
   assertion to fail while the runner still kills/reaps correctly.
2. `runBoundedOutput` starts its deadline before Process setup and synchronous `process.run()`
   (`ProcessRunner.swift:65-85`). No outer deadline interrupts Process.run. The defer synchronously
   calls waitUntilExit after killing an owned running process (`:75-79`). The polling deadline
   does not guarantee an absolute upper bound on launch or cleanup.
3. Store `read` checks deadline before open and after reading, but not inside its read loop
   (`terminal-visual-state.swift:1050-1055`). Repeated EINTR can therefore keep that loop active
   after deadline expiry until a non-EINTR result. A managed caller still has the outer 100 ms
   completion guard; a standalone store call does not. Logs do not show EINTR.
4. Rename can publish a complete record and then the post-rename deadline check can fail
   (`store:1109-1111`). Error does not imply the record was untouched. This is an outcome
   ambiguity inherent in checking a deadline around a synchronous commit syscall, not evidence
   that the logged errors happened after rename.

No source-verified defect has been established as the cause of the nine historical deadline
cases. Preserve those limits separately from hypotheses about host or test timing.

## Smallest bounded diagnostic using existing seams

Use a test-local forwarding ProcessRunner around the real SystemProcessRunner. Record only
monotonic timestamps, stage names, result/error enums and byte counts in an NSLock-protected
in-memory buffer. Print a compact snapshot after each selected operation. No logging I/O or
string formatting inside the deadline path.

Forward the full managed signature: original path, lockURL, target, emergency, beforeOpen and
prepare. Preserve a nil beforeOpen: wrap with `beforeOpen.map`, never replace nil with a
non-nil observer closure. Preserve the actual fd/deadline passed to prepare and the exact Data?
return and thrown errors. Do not call completeDeviceWrite around the delegation, since that
would add a second budget/worker.

Construct the actual runner with its existing `openDevice` callback. Timestamp open begin/end
around `Darwin.open`; save errno immediately afterward, append the event, restore errno, and
return the original descriptor. Do not alter fd flags, retry behavior, target identity or lanes.
The current MockProcessRunner managed handlers cannot transparently forward this signature:
its handler types at lines 10-12 and dispatch at lines 82-86 omit target/emergency.

Available observable boundaries:

| Timestamp | What it really measures |
|---|---|
| wrapper call begin | Before the real writer establishes/enqueues its deadline |
| actual beforeOpen begin/end, when present | Worker has entered after initial deadline check; metadata callback duration |
| injected open begin/end | After admission; actual open duration |
| prepare begin/end | Device open and stable-lock preparation/acquisition finished; aggregate metadata/policy/render preparation |
| wrapper return/throw | Parent-visible original outcome and completion time |

Once beforeOpen/prepare supplies deadline D, the runner's original start is exactly
`D - 100000000` ns. That is the budget anchor, not the time the worker actually started.
BeforeOpen entry is just after worker startup/check. When beforeOpen was nil, no existing
callback supplies worker-start time before open. If failure occurs before all callbacks, only
caller timing is available. Do not label that interval pure queue delay.

Open-end to prepare-begin measures directory/create/lstat/lock-open/fstat/flock plus checks.
Prepare-end to parent-return combines bytes, deferred cleanup, completion signal and parent
wake. If prepare returns nil, label it skipped paint, not a device write. If parent returns
before a late callback finishes, keep that fact and its late outcome separate. If a worker
is still incomplete after a small bounded diagnostic wait, report it as incomplete and keep
its owned fixture resources until it finishes; do not erase a directory under the worker.

Choose one previously failing connected case, for example complete-render or exact-focus-clear,
and one direct cold-store case, for example effect metadata save. Run each once after the
trace is reviewable. Retain original assertions and the 100 ms production deadline. Expand to
the other affected cases only if the first traces leave a useful concrete gap. A fresh pass
is a pass of that diagnostic run and does not erase the historical full-suite failures.

For the direct store case, timestamps around each existing public helper and injected
lookup/device/descriptor callbacks can distinguish identity work from aggregate storage, but
cannot split prepareTargetDirectory from JSON/temp-open/write/rename. No change to the existing
store init or private file helpers is required for that first pass.

If exact file-stage splits are necessary afterward, add only direct begin/end marks around the
existing operations in prepareTargetDirectory/read/write, and actual worker-entry/result/signal
marks in completeDeviceWrite. No injectable filesystem, queue abstraction, timer framework,
process supervisor or persisted event schema is justified by this diagnostic.

## Process test: retain the original outcome and avoid startup-dependent evidence

The actual runner owns Process and knows its launched PID immediately after `process.run()`.
Its cleanup is independent of the shell PID marker. Existing APIs return only stdout/exitCode
on success and discard partial-output/PID/timing observations on throw. A test-local decorator
therefore cannot observe the original launched PID or exact launch stages.

For a deterministic reap assertion without widening the 150 ms deadline, the smallest source
seam would observe that actual launched PID just after Process.run returns and the already
computed deadline. Capture launch begin/end, timeout-throw time and cleanup end as local scalar
observations. Do not add a child-readiness wait that restarts the timeout. After the call
throws, assert kill(observedPID,0) == -1 and ESRCH for that specific owned Process.

Keep child readiness separate: absence of the shell marker means this run did not establish
that the child closed both output streams. It must not be called a proof of the closed-pipe
branch. To test that branch deterministically, a separate owned helper needs a bounded startup
handshake before exercising the polling/termination stage, or a Process injection enabling an
already-ready helper. No such seam exists currently; this is a distinct test-design choice,
not permission to restart the production deadline or suppress the existing assertion.

All new observations would apply to the new run only. The historical marker is gone and the
old logs cannot reconstruct its launch/cleanup times.

## Session capture and memory

Repository edits were explicitly excluded by the delegated task, so no META-THINKING-CAPTURE
entry was appended by this subagent. Parent can capture the combined session. The method here
was source/log comparison followed by an explicit map of observable and unobservable stages.

Memory was consulted only for prior TAVS safety/context guidance. All deadline facts above were
rechecked against current source. Relevant registry entry: MEMORY.md:800-810; historical rollout
id `01a100cb-205c-7840-8268-c3d4ab1f7849`.

## Parent correction and verification: record read retries

The current source confirms the missing loop deadline check. A defaulted readDescriptor syscall
closure permits controlled EINTR/partial reads; its production default remains Darwin.read.
A single check at the top of the existing loop stops the next attempt after expiry. All original
fd/inode/type/size validation, supplied deadlines and close handling remain. No callback renews
or substitutes a deadline. This addresses an actual source gap independently of timing attribution.

Exact verification through tests/run-isolated.sh, owned scratch build and explicit helper:

- jhc4kO: behavioral RED, 3 tests and 2 failed assertions, 0.448 seconds. Both expiry cases
  observed 2 syscall attempts instead of 1. The within-budget EINTR/partial-read case already passed.
- cpDRTk: TerminalVisualStateTests, VisualRecoveryTests and ProcessRunnerTests, 201/201,
  8.944 seconds. Expiry cases now stop at 1; the within-budget case completes. Records stay intact.
- xMoxpJ: full Swift suite, 619/619, 17.133 seconds. Earlier failed runs remain in the provider
  source check and are not explained by this pass or the new regression cases.
- dKefZH: serial release build, 23.81 seconds. No real app or deployed helper was replaced.
- TOldLS: 19/19 background-intent Bats checks with that rebuilt helper and private owned PTYs.

Logs are retained beneath the existing macOS temporary root:
/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.<run>/command.log.
The scratch remains /tmp/tavs-focus-leases-84v8mqbc/build. A read syscall already in progress
cannot be preempted by this loop check. The managed caller still uses the existing 100 ms bound.
No historical EINTR event was recorded, so no link to the older failures is established.

### Process-size check

The preceding 14 commits changed 5,870 documentation/capture lines, 276 production lines and
1,096 test lines. These are addition-plus-deletion counts and include unchanged history moves,
not a count of newly authored prose. Seven feature commits fix source-verified review findings:
schedule-load crashes, native effect revalidation, GUI recovery confirmation, release retries,
projection persistence, quiet-bound validation and ordinary-provider synthetic compatibility.
The recorded findings produced these fixes; the result is not the zero-benefit case in the
project rule. This iteration reuses existing report/docs and makes one connected source commit.
No process artifact or instruction is retired, and no new review/governance mechanism is added.
