# Initial paint source check

Last Updated: 2026-10-14
Version: 1.0

Read-only scope: initial manual paint, late-preview timer fixture, managed writer callbacks and
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
