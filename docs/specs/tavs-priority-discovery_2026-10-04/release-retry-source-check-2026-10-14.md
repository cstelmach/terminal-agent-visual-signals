# Release retry verification and limits

Last Updated: 2026-10-14 (Europe/Vienna)
Version: 1.0
Source baseline: `a576dcc`.

## Parent verification

The source finding is confirmed. Broadcaster retried currentRestriction after the rule ended,
which produced no bytes. Scheduler skipped unmuted retries. Targeted reconciliation now uses
current policy and retained global records, including canceled records after preparation failure.
The heartbeat remains disabled during suspension; neither path introduces a new native query.

Is0gWg caught a missing explicit beforeOpen:nil argument in the new test seam. Corrected before
behavioral RED WOIijj: three cases, five assertions. 5ACMKx passed the initial connected suite;
eTZ42j passed 62/62 with four new owned-PTY cases and the revised heartbeat caller assertion.
6LNVmm passed 596/596 Swift in 14.058 seconds. The source checker ran no tests; these results
come from the parent's isolated commands. Release jJlAb3 passed in 17.76 seconds.
Physical Ghostty acceptance remains unverified.

The four cases cover failure before/after preparation, failed-only targeting, stopping after
success, current background and no title/bell replay, and suspended fresh complete rendering.
Test wrappers preserve exact physical targets, nil publication callbacks and original deadlines.
No raw-output route, new timer, retry registry, receipt, schema or live state change was added.

The existing active reconciliation can reset a fresh ordinary palette while clearing a retained
legacy global record. This slice documents and tests that behavior; it does not solve that broader
preservation limitation or infer cross-process success. Suspended recovery preserves the fresh
render but can retain the old in-memory warning. Failed projection writes, independent headless
focus bookkeeping, Linux ordinary compatibility and native acceptance remain open.

## Read-only exploration and implementation check

The report below is preserved unchanged, including its read-only execution limits.

# TAVS release retry source exploration

Last Updated: 2026-10-14
Version: 1

Scope: read-only verification of R1 in
`docs/specs/tavs-priority-discovery_2026-10-04/current-claude-recovery-portable-2026-10-14.md`
against current source at commit `a576dcc`. No tests, applications, live native discovery,
or real preferences were executed. The working tree was clean when inspected.

## Answer

The active, unmuted release retry defect is confirmed. Two current conditions cause it:

1. Scheduler heartbeat retries only while muted (`Scheduler.swift:494-498`).
2. Broadcaster retry uses `.currentRestriction` (`Broadcaster.swift:125-126`), which returns
   no device bytes when current policy has no rule (`visual-recovery.swift:315-316`).

For the normal failed release with a retained global record, retrying
`.reconcile(resetLegacy: false, clearSelective: false)` is sufficient even if the failed
attempt already canceled that global record. The active reconciliation branch explicitly
checks for any global record, including an inactive record, at `visual-recovery.swift:365`.
Therefore the stronger `resetLegacy: true` remedy is unnecessary for this concrete case.

The smallest bounded correction is the false/false reconciliation in Broadcaster, plus a
Scheduler heartbeat condition that drops `isMuted` and retains
`!visualRestrictionsStatus.disablesRestrictions`. This addresses active unmuted retries.
It does not establish suspended recovery retries or cross-process success detection.

## Exact metadata and byte trace

`broadcastPausedClear()` enqueues `.reconcile(true, false)` at `Broadcaster.swift:37-38`.
`broadcast()` enqueues `.reconcile(false, false)` at lines 41-42. Pending reconciliation
operations combine their flags using OR at lines 78-79. Scheduler submits both at
`Scheduler.swift:480-482` after publishing the current projected state at lines 413-429.
Depending on queue timing, these calls may coalesce or run separately; the discriminating
retry test should avoid relying on a particular scheduling interleaving.

Under the per-TTY writer lock, no-rule reconciliation follows this sequence:

1. Load effects (`visual-recovery.swift:238`).
2. Compute current policy inside the serialized prepare callback (`:315`).
3. Read suspension state (`:340-341`).
4. In the active branch, set `resetLegacy` if it was already true, the caller requested
   it, or *any* global effect exists (`:365`). That final check does not require active.
5. Resolve the latest ordinary background or current selective lease (`:368-403`).
6. Cancel applicable active effects (`:404-406`).
7. Construct OSC 104 and 110 when `resetLegacy` is true, then the background (`:411-416`).
8. ProcessRunner checks the deadline and writes bytes after prepare returns
   (`ProcessRunner.swift:206-209`). The shared writer budget stays 100 ms (`:217-228`).

Cancellation retains the record: `terminal-visual-state.swift:291-298` changes
`effect.active` to false and writes the same record. `effectsUnlocked` reads current
records without filtering active status (`visual-recovery.swift:600-604`). Thus a failure
after prepare can leave an inactive global record and old physical terminal colors.
On a subsequent active false/false reconciliation, line 365 still requests OSC 104/110.

There is already supporting coverage outside the requested test pair:
`visual-recovery-tests.swift:1602-1614`,
`testRelaunchClearsLegacyForegroundAfterCanceledGlobalPaintFailure`, seeds an inactive
global effect and asserts OSC 104/110 from `reconcilePriorEffects()`. That entry uses
`.reconcile(false, true)` at `visual-recovery.swift:518`, so it confirms the canceled-record
branch but does not cover Broadcaster false/false retry wiring.

## State distinctions

| Current state | Retained metadata | False/false reconciliation |
| --- | --- | --- |
| Active with current rule | Any | Recomputes and paints current pause/lock at `:320-337`. |
| Active, no rule | Active global | OSC 104/110 plus current ordinary or selective background. |
| Active, no rule | Canceled global | Also OSC 104/110 plus current background (`:365`). |
| Active, no rule | No global | Background composition, with no forced OSC 104/110. |
| Suspended, no preview | Active global | Cancels it and returns default reset (`:354-359`). |
| Suspended, no preview | Canceled only | Returns nil, regardless of caller's reset flag. |
| Suspended, current preview | Matching preview | Preserves preview; global cleanup is separate. |

Changing false to true does not repair a suspended failed clear whose prepare already
canceled all effects. The disabled-state branch returns nil before the reset flag is
used. Removing the entire Scheduler guard would call retry in this state, but would
not fix this case; it would repeatedly produce `.unaffected` while preserving failure.

Suspended successful recovery and subsequent fresh ordinary renders are intentionally
protected by this nil result. Existing coverage includes:

- `BroadcasterTests.swift:183-205`: suspended scheduler clear does not replay retained
  background after recovery, including after a fresh ordinary background write.
- `BroadcasterTests.swift:222-253`: delayed suspended clear and relaunch preserve a fresh
  complete render, including palette, title and image behavior.
- `visual-recovery-tests.swift:875-970`: current suspended previews and residual global
  cleanup have distinct behavior.

## Separate successful recovery and fresh hooks

A separate successful `recover()` persists suspension and emits the emergency reset
(`visual-recovery.swift:426-436`, `:239-243`). Broadcaster owns its failures in memory
(`Broadcaster.swift:13`). An operation in another VisualRecovery instance or process
does not by itself call Broadcaster.record or prove its previous failed operation
completed. Treat the report's lingering menu warning as an in-memory status limitation,
not proof that current physical colors are still wrong.

`record` removes a retained failure only on `.restored` or `.vanished`
(`Broadcaster.swift:133-136`). It intentionally keeps the failure on `.unaffected`.
Returning nil after a completed suspended recovery therefore preserves the warning.
Do not change `.unaffected` to clear failures wholesale: registration and no-op policy
checks also return this status, and the existing test at BroadcasterTests:429-448 pins
the distinction between registration and successful device output.

After a failed release already canceled a global record, an ordinary background write
or full render computes `resetLegacy` from active globals only (`visual-recovery.swift:342`),
so that hook does not automatically issue OSC 110. Full render may set or reset palette
using its supplied render fields; ordinary background output cannot establish a palette
or foreground reset. `TerminalRender.beforeBackground` emits OSC 4 or 104
(`terminal-render.swift:56-65`); it has no foreground OSC 10 setter.

If a fresh full render occurs while active after the failed release, the stale
Broadcaster failure remains. A subsequent false/false reconciliation still sees the
canceled global and emits OSC 104/110. It can therefore reset that fresh ordinary
palette while restoring the latest published background. This behavior already exists
for an explicit active `broadcast()` or startup reconcile; changing retry exposes it
to an automatic later heartbeat as well. Do not claim false preserves fresh active
palette, and do not claim true uniquely causes this consequence.

Under suspension after completed recovery, that fresh render is protected by the
disabled-state nil branch, as the existing tests demonstrate. Resuming active state
changes the applicable branch and must not be silently conflated with suspension.

Canceled global metadata does not distinguish failed prepare-before-output from
successful clear or recovery. The present source cannot infer those outcomes across
processes from `.active == false`, a newer background intent, or a marker alone.
No receipt, new schema, success ledger or control plane is needed to test the scoped
active unmuted defect. Do not assert those broader guarantees in the scoped fix.

## Smallest useful tests

### 1. Broadcaster release fails after prepare, then false/false retry clears it

Add one test to BroadcasterTests using its existing owned PTY, state and runner helpers.

- Seed a global effect and an ordinary intent; set current policy unmuted.
- Arrange the runner to call `prepare` under the normal SystemProcessRunner writer,
  then throw `deviceWriteTimedOut` before returning those bytes for the selected target.
  The wrapper should call the actual prepare with its original descriptor/deadline,
  then throw, rather than sleeping or extending the 100 ms production deadline.
- Call `broadcastPausedClear()`, waitUntilIdle, and assert no output, one failed item,
  and a retained global effect with `active == false`.
- Heal the runner; call retryFailedRestrictions; waitUntilIdle.
- Assert exact OSC 104/110 plus latest ordinary background, failure removal, and no
  writes to a healthy target when one is included.
- Call retry once more and assert no further attempts or bytes.

This directly discriminates canceled metadata handling and Broadcaster operation choice.
The current implementation still calls the managed runner on retry, but emits no bytes.
The source report's phrase 'no second write' should mean no second device output, not
no second runner invocation.

Existing test `testGenericFailureRetainsOldRegistryAndBindingForRetryBesideHealthyTarget`
at BroadcasterTests:368-395 injects failure before prepare and retries via broadcast,
so it does not cover this cancellation boundary. Existing muted targeted retry coverage
at :397-427 should continue to pass without being reimplemented.

### 2. Update existing Scheduler heartbeat gating test

`SchedulerTests.swift:437-456` explicitly asserts retries only while muted. Rename that
test and update its active/unmuted expectation at :452 from 1 to 2. Keep suspended
expectation unchanged at :447 when retaining the disablesRestrictions guard.

Use the first repeating timer handler, as this test already does. `fireAll()` also
fires one-shot transition timers and adds unnecessary scheduling behavior. A real
Broadcaster inside SchedulerTests is unnecessary if test 1 covers actual bytes and
this test covers Scheduler's caller wiring.

### 3. Bound the suspended and fresh-render claims

Extend a Broadcaster retry case to leave an in-memory failure, then heal using a
separate VisualRecovery with successful recover(), publish a fresh ordinary render
while suspended, and retry directly. Assert no extra bytes and continued failure.
This documents the current safety boundary; it does not claim the failure was retried.

Add or adapt one active fresh-render characterization: fail after prepare, render a
fresh palette and background while active, then retry. Assert the actual current
OSC 104/110 plus latest background behavior. If the desired contract instead requires
preserving that fresh palette, name that as a separate behavior decision before treating
the scoped two-line retry fix as sufficient for that additional contract.

These cases should use the existing helpers rather than new retry state or framework.
They can share setup in their test body or use the existing cache/recovery helpers.

## Confirmed, corrected and unverified R1 claims

- Confirmed: current Scheduler skips active unmuted retry; current retry no-rule operation
  emits no bytes; post-prepare failure can leave physical palette/foreground restriction.
- Corrected: false reset flag is sufficient with retained canceled global metadata in
  active reconciliation. The part04 'still-active global effect' explanation is too narrow.
- Corrected: ordinary hook is not guaranteed to reset foreground/palette. Part05 has the
  stronger account; explicit reconciliation, relaunch or recovery are additional routes.
- Corrected: later active broadcast/reconcile can reset canceled global metadata without
  another mute cycle; part05's listed recovery routes are not exhaustive.
- Current line correction: Scheduler gating assertion is now :437-452, not :393-395.
- Unverified: live terminal rendering, cross-process ordinary hook self-healing, native
  catalogue behavior, post-timeout physical byte coverage, or separate process clearing
  Broadcaster's in-memory warning. Source tests can establish bytes and routing only.
- Separate scope: canceled focus ownership and late focus clear are not this global
  release retry. Preserve their generation, revision and lease logic unchanged.

Historical memory was used only for the operational boundary that live TAVS/terminal
state is snapshot-specific. All code conclusions above were read from current source.

## Follow-up: source check of the implementation diff

Checked the current uncommitted four-file diff on 2026-10-14. No tests were executed and
no source was edited. `git diff --check` found no whitespace errors.

No actionable source issue was found in the requested retry implementation or its new
test seams. This is a source assessment, not a passing-test or live-acceptance claim.

### Implementation and retry scope

- Broadcaster now retries `.reconcile(false, false)` through the targeted overload at
  `Broadcaster.swift:126-127`. `retryTargets` still comes only from retained bound
  failures at :102. Fanout still validates generations and groups physical aliases.
- Targeted VisualRecovery.apply only invokes fanout (`visual-recovery.swift:488-490`);
  it does not call the native-discovery overload at :439. The implementation adds no
  discovery on retry, and preserves the prior catalogue availability value.
- The queue admission guard at Broadcaster:52 remains `!running && !failures.isEmpty`.
  One pending flag is still drained and cleared at :101-107. Retry calls during running
  work cannot accumulate more queue entries; calls without failures do not enqueue.
- Scheduler now retries after evaluation whenever the marker is active
  (`Scheduler.swift:494-498`). Suspension and unavailable-marker guards are retained.
  This fixes active unmuted release retry and leaves projection writes unchanged.

### New tests and seams

- `BroadcasterTests.swift:451-500` covers both failure before prepare and failure after
  prepare. The post-prepare seam calls the real prepare callback before throwing EIO,
  so it exercises cancellation without delivering the prepared bytes. This establishes
  the relevant failure boundary without claiming to reproduce actual timeout latency.
- The two-target wrapper selects the matching owned target by path (:468) and forwards
  its physical binding to SystemProcessRunner (:469-470). Both owned fixture targets
  are plain bindings with distinct paths and generations. The single-target wrapper
  also forwards its physical binding at :518-519. Neither wrapper passes target nil.
- Explicit `beforeOpen: nil` is correct for these intercepted operations: initial
  currentRestriction and release/retry reconcile do not have publication or selective
  clear callbacks. The fresh ordinary render uses the separate default recovery service
  rather than this mock, so its beforeOpen publication is not dropped by the seam.
- The failure-stage tests assert retained global activity according to failure stage
  (:483), only the failed path on retry (:490), exact OSC 104/110 plus latest background
  (:493), no healthy bytes (:495), failure removal (:491) and no subsequent runner call
  when failures are empty (:497-500). The guarded read at :492 cannot hide failure:
  the preceding failure-count assertion independently fails if retry did not restore.
- The active fresh-render case at :503-556 asserts actual palette reset plus latest
  background, with no replayed title, image or bell bytes on retry. The prior render
  explicitly includes palette, title, image-clear and bell fields (:538-547), making
  the exact retry byte assertion discriminating.
- The suspended fresh-render case invokes a separate successful recovery service,
  consumes its reset bytes, renders fresh content and then directly retries the stale
  Broadcaster failure. It asserts no output and retained failure (:549-551). This is
  same-process service separation, not a test of real cross-process feedback.
- SchedulerTests:437-456 keeps muted retry and suspended suppression, then expects an
  active unmuted retry count of 2 at :452. Existing real Broadcaster tests establish
  bytes while this mock test establishes the Scheduler call.

### Remaining bounds

The new active characterization explicitly accepts that retry emits OSC 104 and can
reset a fresh palette. It establishes current behavior, not resolution of the broader
fresh-active-palette limitation. Suspended recovery feedback still does not clear the
Broadcaster warning without an observed restored/vanished result. Projection write
failures, external success feedback, native discovery behavior and real device timeout
behavior remain outside this change. Canceled focus handling is untouched.
