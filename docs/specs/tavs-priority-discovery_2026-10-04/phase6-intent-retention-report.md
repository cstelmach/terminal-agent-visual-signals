# Phase 6 intent retention before device open

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0, foundation API/test slice completed; parent completed wiring/integration.
Starting checkpoint: parent 390 Swift tests green, renderer checkpoint `3a718d0`/`fcb684a`;
parent later reoriented `2d47bfe` without altering worker ownership.

## Verified design and scope

Read the archived design at
`docs/specs/tavs-priority-discovery_2026-10-04/phase6-intent-retention-design.md` and compared it
with current ProcessRunner, store, mocks and tests. Source confirms that the old prepare callback
could not publish if device open failed or output-lock entry timed out. The existing unbound
publisher started a separate local lock budget and was unsuitable as a post-timeout remedy.

Only the five authorized repository files changed:

- `src/macos/TAVSApp/Sources/TAVSApp/ProcessRunner.swift`
- `src/macos/TAVSApp/Sources/TAVSApp/terminal-visual-state.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/Mocks/MockProcessRunner.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/process-runner-tests.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/terminal-visual-state-tests.swift`

Backups were saved before mutation to
`/tmp/tavs-phase6-retain-intent-before-open-20261012/backup/`.
No RootRecovery, entry, renderer, shell, docs/META or Git edits were made. No live/native/Ghostty,
real-home/runtime or deployment activity occurred. Tests use explicit isolated roots, injected
metadata and owned PTYs. Parent owns wiring, full integration, documentation and commits.

## APIs and behavior

ProcessRunner adds:

```swift
func writeManagedToDevice(path: String, lockURL: URL,
    beforeOpen: ((UInt64) throws -> Void)?,
    prepare: @escaping (Int32, UInt64) throws -> Data?) throws -> Bool
```

The original call form remains a tiny protocol extension delegating with beforeOpen nil.
SystemProcessRunner calls the optional callback once inside its original completeDeviceWrite
worker, before device open, passing that worker's existing absolute 100ms deadline. Deadline
checks surround the callback; open retries do not repeat it. The original opened-device lock,
prepare/write ordering, late-open descriptor cleanup and single outer timer remain intact.
The callback must honor the deadline and release its metadata lock before returning.

TerminalVisualStateStore adds:

```swift
func publishIntent(_ record: OrdinaryBackgroundIntent,
    to target: TerminalTargetBinding, synthetic: Bool,
    intakeAt: Double, deadline: UInt64) throws
```

This validates typed input, exact target/record TTY and device, current lifetime/equivalent aliases,
producer generation/device and continuing owner. Under the existing stable writer lock it calls
existing publishIntentUnlocked and bindOrdinaryIntentUnlocked with the same supplied deadline.
It releases that lock before returning, performs no device open/output, and preserves existing
unbound publication compatibility, normalization, intake ordering and synthetic stale checks.

Private withLock now accepts an optional supplied absolute deadline and checks it through
managed directory/lock acquisition, lock waiting, immediately after acquisition and before/after
the body. It does not replace the supplied budget. Existing nil callers retain their local wait
and non-device publication behavior. Lock open is nonblocking/no-follow/close-on-exec, and fstat
requires a regular private0600 file, matching the device writer's lock checks. No additional lock,
file kind, schema, ticket, fallback output, deferred retry or publication budget was introduced.

MockProcessRunner retains its legacy three-argument managedHandler for nil callbacks and adds
managedBeforeOpenHandler with the full four-argument contract. New callbacks are forwarded by
that explicit seam; a nonnil callback with only a legacy handler fails instead of being discarded
or receiving a fresh budget. The injected writeError path executes the callback exactly once
inside original completeDeviceWrite, checks its deadline, then throws the device error. Parent
approved this seam and owns migration of connected recovery/entry test adapters during wiring.

## Truthful retention boundary

Successful prepublication retains normalized intent and its exact lifetime-bound copy even if
later device open/output-lock entry fails. This state result does not claim paint succeeded;
the original device failure still propagates. If the publication lock itself remains held for
the entire original deadline, the operation fails with no open and no new intent. There is no
promise that all lock-entry failures retain intent and no after-timeout fallback publication.
Parent keeps the original post-open publisher/binder stale recheck before output bytes.

## Tests-first evidence

All worker Swift invocations used tests/run-isolated.sh with explicit helper:
`/tmp/tavs-phase6-routing-20261012T165000/build/arm64-apple-macosx/debug/TAVSApp`.
Scratch: `/tmp/tavs-phase6-routing-20261012T165000/build`.
Filter: `ProcessRunnerTests|TerminalVisualStateTests`.

Expected missing-API red, exit1:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.ME0UfZ/command.log`.
Tests preceded source and referenced the absent beforeOpen, pub-to-target and new mock seam.

Focused foundation green, exit0, 83/83:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.94ycmO/command.log`.
Counts: ProcessRunner23 plus TerminalVisualState60. Eleven new tests were added; no existing
assertions/tests were removed or deadline thresholds weakened. Counts are XCTest results, not
Swift Testing's separate zero-test footer. Owned-path git diff --check passed.

New regressions prove:

- Callback executes off main exactly once, including EINTR open retry, before device open and
  shares the identical absolute deadline with prepare.
- Failed/timed-out prepublication cannot open a device or call output preparation late.
- Normalized color remains bound while open wedges, and another descriptor can acquire the same
  stable lock during the wedged open. Timeout still fails; late fd closes and emits no bytes.
- A competing writer acquiring the output lock after publication retains reset intent while
  output fails under one budget, with no late preparation after lock release.
- The entire-budget publication-lock boundary retains the original intent, never opens/paints,
  and cannot mutate after lock release.
- Target-aware publication binds across aliases and child exit without observation mutation,
  releases its lock, honors a supplied25ms deadline rather than starting100ms again, and rejects
  stale synthetic delivery, changed owner/device, unknown native metadata and invalid private/
  symlink lock files without replacing current intent.
- The configured new mock forwards the callback; injected device error runs it once before failure.

Existing late-open, wedged policy, original100ms, stable inode, symlink/special lock, independent
healthy write, alias, ownership and metadata safety tests remain green in the focused run.

## Parent integration boundary

Parent asked this worker to hold full after focused green because three recovery integration
regressions were intentionally red until parent wired prepublication. Worker released source/build
slot after83 green and ran no full suite. Parent then reported integration red E5EXgN, focused121
green jCKqYd, and first full405 WQ84I6 failing one fixture future timestamp. The latter two logs
were inspected directly; fixture clock correction and full rerun smUB0P were parent work.
This report claims the worker's foundation83 green. Parent subsequently confirmed combined
full405 green at smUB0P, plus release/helper checks, and records those results in its integration
progress. Parent committed the five foundation paths as818fe5e after verification; wiring/tests/
docs are0704512. The worker performed no Git mutation or additional build.

## Handoff

Exact functions touched: ProcessRunner protocol and nil-delegating overload,
SystemProcessRunner.writeManagedToDevice, TerminalVisualStateStore.publishIntent(to:) and
withLock, MockProcessRunner.writeManagedToDevice/managedBeforeOpenHandler.
The five paths and build slot are stable/released. No further worker builds/source edits will run.
Parent owns production wiring, combined full, actual helper acceptance, docs and commit.
This completes the bounded foundation slice, not Phase6 or the master goal.

Observed workflow for parent capture: verified the source/design incompatibility before editing;
coordinated source/build ownership while actual renderer acceptance ran; captured missing-API red;
added a faithful four-argument mock seam instead of silently dropping callbacks; explicitly tested
successful-retention and unavoidable full-budget publication failure as different outcomes;
released after focused green when parent integration tests became intentionally behavioral red.
