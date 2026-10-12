# Phase 8 controller follow-up

Last Updated: 2026-10-13
Version: 1.0
Base: `52b44a0`; reviewed the dirty controller and related current source/tests.

Read-only. No source edits, builds, test execution, native/Ghostty/UI commands, device output,
installations, or real-home actions were performed. Parent owns implementation and builds.

## One concrete defect: unmapped targets falsely refresh the common heartbeat

Evidence in `src/macos/TAVSApp/Sources/TAVSApp/focus-controller.swift`:

- `:194` drops unmapped outside rows with `compactMap(captureTarget)`.
- `:205` applies focus only to the surviving mapped targets.
- `:206-209` advances `run.lastHeartbeat` whenever no returned item is `.failed`, including
  an empty item list when a previously painted outside surface becomes unmapped.
- `:141-149` decides whether to roll the effect ID solely from that common heartbeat.

The writer deliberately cannot renew an expired existing focus record under the same ID:
`terminal-visual-state.swift:213-220` requires `isSelectiveLeaseActive(current)` for an active
same-ID focus save. The six-second boundary is at `:169-177`.

Concrete sequence:

1. Capture working A and paint outside B at time 1000 with effect ID X.
2. Keep A valid, but report B with a missing/unavailable mapping on catalogue ticks at
   1002, 1004, 1006 and 1008. B is dropped from mapped targets, the result has no failed
   item, and the controller's common heartbeat advances on every tick.
3. B's actual `focus.json` remains at heartbeat 1000 and has expired by time 1008.
4. Return B with a valid mapping at 1010. The common heartbeat is only two seconds old,
   so the controller keeps ID X. Saving B under X throws `staleEffect`, leaving B undimmed
   or with stale paint until failed updates eventually allow the common heartbeat to age
   beyond six seconds and trigger ID rollover.

This is an actual delayed recovery path, not an inferred future requirement. Existing
`testCatalogueFailureRetainsLogicalSetAndExpiredOwnershipGetsANewID`
(`focus-controller-tests.swift:120-132`) checks a complete unavailable gap, but not successful
catalogues containing an unmapped outside row, so it does not exercise the false heartbeat.

Smallest fix: do not advance the common heartbeat when mapped target count is smaller than
outside row count. Keep the existing no-failed-items condition. A fresh mapped row after
unrenewed ownership then gets a new ID through the current rollover path. No new timer,
per-target heartbeat registry, state schema or service is necessary.

Suggested regression: use the current injected clock/PTYS and surface copies. After initial
paint, pass an unavailable mapping for B through several successful catalogue ticks totaling
more than six seconds, then restore B's original valid row. Assert its new effect ID differs
from X, heartbeat equals the current accepted tick, and restoration does not wait through
another six-second failure period. Cover a mixed outside set with one healthy row as well.

## Other requested checks

### Queue coalescing

`manualUpdating` allows one dispatched manual worker and `manualPending` keeps only the most
recent catalogue tuple (`focus-controller.swift:28-29,154-155,173-179`). Accepted catalogue
updates increment the current run version. `catalogueUnavailable` increments it and clears
the pending tuple (`:158-162`). Both the worker and its managed request check run identity
plus version (`:182-183,195-204,232-235`). Completion clears the running flag and drains the
latest pending tuple (`:213-228`). I found no concrete unbounded manual-job queue or stale
manual-result publication defect in that flow. Preview expiry still has its separate timer.

### Captured set

Focus Selected captures the intersection of selected/current catalogue IDs (`:124-133`),
then updates only from accepted catalogue closure (`:137-140`). Preview has separate current
run state and does not write `workingSet`. The worker requires at least one verified working
binding before touching outside targets (`:185-186`). These paths match captured-set semantics.

### Target and pinned-revision lifetime

Before any manual writer is dispatched, affected targets are retained under the controller
lock (`:194-199`). Focus Off invalidates current manual identity first and hands the retained
run to exact-ID clearing (`:165-170,237-253`). Failed clearing puts the run back in
`pendingFocusClear` (`:247-249`). Recovery also retains old runs instead of releasing their
pinned marker descriptors before metadata cancellation (`:114-121`).

The writer cancels matching effect metadata in its existing `beforeOpen` callback before a
device-open failure (`visual-recovery.swift:160-175`), and the run reference survives clear
callbacks. `VisualRestrictionsRevision.deinit` closes the held descriptor
(`visual-restrictions-state.swift:36-48`). I found no demonstrated premature pin release in
these controller paths. Confirmed vanished targets remain safely generation-bound.

### Rollover

The rollover code creates a new ID while retaining the same pinned recovery revision and
keeps the old run for exact-ID cleanup (`focus-controller.swift:148-150`). That avoids
reactivating a canceled/expired ID, and clearing the old ID cannot cancel the new one.
The concrete problem is the false common heartbeat described above, not the rollover
mechanism itself.

### Failed and empty catalogue handling

The current Sessions integration routes `.success([])` and `.failure` to stale coverage,
which calls `catalogueUnavailable` (`sessions-model.swift:200-207,225-228`). It calls controller
`acceptCatalogue` only after nonempty successful results (`:191-199,212-221`). Therefore empty
and failed catalogue responses preserve the logical set and invalidate queued manual work.

Direct `FocusController.acceptCatalogue([])` would empty the set and switch Off, but this is
not a reachable empty-response defect in the current caller routing. The existing confirmed
last-closure test uses a nonempty valid catalogue without its former working ID
(`focus-controller-tests.swift:108-117`). Do not change that contract merely to add machinery.

## Verification gap

No tests were run. Besides the unmapped/remapped regression, the current dirty tests do not
show a blocked manual worker receiving multiple catalogue versions followed by a failure;
the source coalescing guards look correct, but that combined ordering remains unexecuted here.


## Parent adjudication and executed checks

The unmapped-target heartbeat finding was verified in current source. Regression `jsee8s`
failed on the reused expired ID; requiring all outside rows to map made `JKIr5M` pass.
The final controller also defers retired-ID cleanup until replacement processing finishes.
Blocked/coalesced updates followed by a catalogue failure now have an executed regression
(`kvH5Sx`, 17 controller tests). Final `Tic2GM` passed all 466 Swift tests.
The isolated runner retains each complete log. This validates source/owned-PTY behavior,
not native Ghostty color, focus or navigation acceptance.
