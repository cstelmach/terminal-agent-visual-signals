# Phase 6 suspended relaunch recovery correction

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0, assigned Codex R1 correction completed.
Baseline: `95a90a0`, parent full Swift baseline 364 tests.

## Verified finding

Read `/tmp/codex-tavs-phase6-recovery-review-20261012.md`, then checked current source.
Codex R1 is confirmed: Scheduler.start gated discovery and prior-effect cleanup on active
restrictions; finishEvaluation suppressed muted-to-unmuted cleanup while disabled; Broadcaster
performed native registration before cached-effect reconciliation. These paths could leave
restrictive paint after a failed/interrupted recovery and delay cached cleanup behind discovery.
No R2/R3 work was performed in this slice.

## Owned files and authorization

Initially assigned four paths; parent explicitly authorized SchedulerLockTests.swift as a fifth
path for surgical expectation updates after obsolete zero-call contracts were found there.

- `src/macos/TAVSApp/Sources/TAVSApp/Scheduler.swift`
- `src/macos/TAVSApp/Sources/TAVSApp/Broadcaster.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/SchedulerTests.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/BroadcasterTests.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/SchedulerLockTests.swift`

Current backups were saved before mutation under
`/tmp/tavs-phase6-suspended-relaunch-20261012/backup/`.
No Git mutation, repository documentation, META capture, native/UI access, real-home/runtime
state, install or unrelated edits were performed. Parent owns documentation and atomic commit.

## Changes

Scheduler.start now always requests the existing typed discovery/cleanup route. Its comment and
related discovery test comment describe cached effects and native terminal bindings instead of
obsolete process/registry discovery. The status marker remains unchanged by startup.

finishEvaluation now permits the existing safe muted-to-unmuted typed clear after writing the
new projection, including when suspension/unavailable status disables restrictions. Requested
pause/lock state, definitions, grants and expiry timers remain intact. Disabled projection still
cannot call restrictive pause/lock paint. Cleanup occurs once because previousMuted becomes false.

Broadcaster drains cached prior effects before invoking native registration. Cleanup stays on its
existing serial queue and uses the existing typed recovery/managed writer. No new protocol,
control plane, raw byte replay, native query inside the writer lock or new timeout was added.

## Regression coverage

Three new tests:

1. Unavailable startup reconciles persisted muted state without changing marker or saved rules.
2. Unavailable marker transition clears once, preserves requested pause and emits no new
   restrictive paint across repeated evaluations.
3. Owned PTYs with prior global effects receive exact OSC104/110/111 reset bytes before a blocked
   native query starts, for active, suspended and unavailable status. Disabled cases retain a
   requested muted policy on disk, proving fresh suspension prevents restrictive repaint.

Existing suspension transition, explicit persistent suspended restart, unknown marker and
new-lock/master/grant-expiry tests were updated to concrete discovery/typed-cleanup calls.
Saved schedule/lock, no restrictive disabled paint, grant-only unmuted behavior, expiry timers,
resume repaint, writer deadline and unaffected-shell no-paint checks remain asserted.

## Red, correction and green evidence

All Swift invocations used `tests/run-isolated.sh` with explicit helper:
`/tmp/tavs-phase6-routing-20261012T165000/build/arm64-apple-macosx/debug/TAVSApp`.
Shared scratch: `/tmp/tavs-phase6-routing-20261012T165000/build`.

Initial test-only compile failure, preserved:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.RFpdMA/command.log`.
Exit 1: the new test assumed MuteStateReader.read existed. Corrected it to inspect the existing
REQUESTED_MUTED serialized field, already used by neighboring tests. Production source was
still unchanged. This was a fixture mistake, not evidence of the product defect.

Behavioral red:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.HJvJuu/command.log`.
Exit 1: 67 focused tests, 23 failures including three unexpected PTY timeout assertions. The log
shows missing disabled startup/transition cleanup and reset bytes arriving only after native
release. No writer deadline was relaxed or assertion removed to obtain green.

Focused green:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.F38C1k/command.log`.
Exit 0: 67/67, composed of Broadcaster15, SchedulerLifecycle35 and SchedulerLock17.

Full green:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.BnDgf8/command.log`.
Exit 0: 367/367. The total is baseline364 plus three new tests. These are XCTest results, not
Swift Testing's separate zero-test footer.

Commands used the following suffix after the helper environment and isolated runner:

```sh
swift test --package-path src/macos/TAVSApp \
  --scratch-path /tmp/tavs-phase6-routing-20261012T165000/build \
  --filter 'SchedulerLifecycleTests|SchedulerLockTests|BroadcasterTests'
swift test --package-path src/macos/TAVSApp \
  --scratch-path /tmp/tavs-phase6-routing-20261012T165000/build
```

Owned-path git diff --check passed. The sole edit after full green was the discovery test's
obsolete comment; no executable code/assertion changed after the full run.

## Handoff and limitations

Key production functions: Scheduler.start, Scheduler.finishEvaluation and Broadcaster.drain.
Source/test files are stable; shared build slot was released promptly after full green and the
final comment correction. No further builds or source edits will be performed by this worker.

Owned fixture behavior is verified. Live app/native visual acceptance, independent review,
R2/R3 resolution and final Phase 6/goal completion remain parent work. This report does not
assert those outcomes.

Observed workflow for parent capture: verified the review against current source before changing
anything; wrote required contract tests first; preserved and corrected the fixture API mistake;
used a semaphore outside the original managed writer deadline to expose native ordering;
updated only legitimate cleanup contracts rather than weakening safety/expiry assertions.
