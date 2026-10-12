# Phase 4 Sessions coverage integration

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0

## Changed files

- `src/macos/TAVSApp/Sources/TAVSApp/sessions-model.swift`
- `src/macos/TAVSApp/Sources/TAVSApp/sessions-view.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/sessions-model-tests.swift`

Only these three assigned repository files were edited in this slice. The completed record
foundation, TAVSApp, intake/CLI, shell, documentation and Git state were not edited by this
worker. Parent-owned concurrent changes were preserved. No commit was made.

## Result

The main and convenience SessionsModel constructors now accept
`visualState: TerminalVisualStateStore? = nil`. Models without a store retain synchronous
refresh behavior. A published `visualCoverage` dictionary is keyed by exact GhosttySurfaceID.

Fresh nonempty catalogue results are read/adopted on one background serial queue. The complete
row/coverage result is published on main, and refreshing remains true through that publication.
The existing refresh guard prevents overlapping catalogue/record refreshes. Priorities and
selection still reconcile against the successfully returned native rows.

Failed or empty catalogue responses do not call the store. They retain previously displayed
observations/intents, disable attentionEligible on every retained entry, and label coverage
last-known with native access unavailable. Fresh results replace the dictionary, so closed
native IDs lose coverage along with their rows.

The Observations column displays provider and reported state, observation age and coverage
status. Complete is labeled `Response ended`, without claiming success. Unverified producers
are labeled explicitly, missing records remain `No agent observation`/`Not observed`, and Codex
coverage is marked completion-only. No renderer, preview, focus or navigation change was made.

Key functions/properties touched:

- SessionsModel.init, convenience init, refresh, visualCoverage.
- New acceptCatalogue and markCoverageStale private helpers.
- SessionsView's existing Observations TableColumn.

## Verification

Tests were added before implementation. No Swift build began until parent explicitly released
the shared scratch. Exact command:

```bash
TAVS_TEST_HELPER_BIN=/tmp/tavs-phase4-20261012T114102/build/arm64-apple-macosx/debug/TAVSApp \
  tests/run-isolated.sh swift test --package-path src/macos/TAVSApp \
  --scratch-path /tmp/tavs-phase4-20261012T114102/build --filter SessionsModelTests
```

- Red log: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.hZZ9Z6/command.log`.
  Exit 1: the new visualState constructor argument did not exist.
- Green log: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.4GmYkd/command.log`.
  **15 tests, zero failures**, 0.021 seconds. No compiler warnings/errors were present.
- `git diff --check` for all three owned files passed.
- Diff: 156 insertions, 14 deletions across three files, including 97 new test lines.

Three added behavioral tests establish:

1. Generation/device correlation is inspected off-main; dictionary publication completes on
   main; refreshing remains true before completion; the adopted observation is cue-eligible.
2. Failed catalogue access preserves the old displayed permission observation but disables its
   cue eligibility. A newly written producer record is not adopted during that failed refresh.
3. Initial failed and empty catalogue results perform zero identity lookups/adoptions, despite
   an intact unadopted record existing in the injected runtime directory.

Existing nil-store tests remained synchronous and passed, including priority persistence,
native lifetime changes, selection/navigation separation, closure reconciliation and fixture
launch behavior. All new runtime/preferences URLs and process/device metadata were explicit
private fixtures. Source backups for model/view already existed under the parent's Phase4 root.

## Parent handoff and capture notes

The shared scratch is idle. Parent can wire visualState into real/private TAVSApp constructors
and run full integration/Swift verification. The worker did not start another full build.

Observed workflow: current SPEC/PLAN/PROGRESS/GOAL were reread for the connected slice; callers
were searched before changing constructor shape; callback tests preceded the implementation;
the actual XCTest count was read from the retained log; failure intentionally retained display
metadata while withdrawing authorization to consume it as an attention cue. Fold these facts
into the parent's required meta-thinking capture with honest model attribution.

No native calls, live process metadata, UI actions, rendering/device writes, shell suites,
real-home state or scheduling were exercised. GUI rendering and parent constructor wiring
remain unverified by this worker. Catalogue callbacks retain their existing main-thread
contract; new background record work publishes through DispatchQueue.main.
