# Phase 6 production Broadcaster routing

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0, completed assigned routing slice.
Starting baseline: `72dd557`. Parent API release: `f0cbc45`.

## Scope and ownership

Only these repository paths were edited by this worker:

- `src/macos/TAVSApp/Sources/TAVSApp/Broadcaster.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/BroadcasterTests.swift`

Parent owns VisualRecovery, production Scheduler factory, project documentation, commits and
meta-thinking capture. No live UI/native metadata, real-home/runtime state, installs or Git
mutations were performed. Fixtures use explicit isolated roots, injected identities and owned
PTYs. Backups are under `/tmp/tavs-phase6-routing-20261012T165000/backup/`.

## Delivered behavior

Broadcaster takes VisualRecovery and uses one serial queue with one coalesced pending operation
and pending registration flag. Reset and selective-clear flags merge with OR. A later current
restriction tick preserves a pending reconcile, which itself reads current policy.

Paused/locked requests ignore caller visual/title snapshots and delegate currentRestriction.
Clear requests delegate reconcile(true,false); ordinary broadcast delegates reconcile(false,false).
Startup delegates register followed by reconcilePriorEffects, which limits clearing to existing
effect targets. It does not paint newly discovered unaffected shells. Pending registration and
prior-effect flags survive coalesced normal requests. Every native/preflight and managed-device
operation is off the caller's thread. A condition-protected lastResult retains metadata diagnostics
and startup discovery availability, and waitUntilIdle provides isolated test coordination.

Removed feature-orphaned raw pending replay, direct writeToDevice production routing, argv
substring discovery, arbitrary filename-to-TTY authorization, mtime pruning and write-failure
registry deletion. Recovery retains retryable bindings and computes actual current bytes.

## Tests and evidence

Tests were written before production replacement. Shared scratch:
`/tmp/tavs-phase6-routing-20261012T165000/build`.
Helper: `/tmp/tavs-phase6-routing-20261012T165000/baseline-helper`.
Every test invocation used `tests/run-isolated.sh`.

- Red expected constructor mismatch:
  `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.HyzeMm/command.log`.
  Exit 1. Parent factory calls Broadcaster(recovery:) while old source only had
  init(runtimeDir:processRunner:).
- First routing focused green: 13/13, exit 0:
  `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.WtjHdt/command.log`.
- Expanded native plain-shell registration focused green: 14/14, exit 0:
  `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.QQKfk1/command.log`.
- Full integration green: 338/338, exit 0:
  `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.AnMD6h/command.log`.
- Final startup scope correction focused green: 14/14, exit 0:
  `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.dIB9et/command.log`.
- Final full integration green: 340/340, exit 0:
  `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.AQHwlW/command.log`.
- git diff --check for both owned paths passed.

Old broadcaster had 33 tests. Six owned-PTY writer and original 100ms deadline tests remain;
27 expectations tied to obsolete replay/pruning/parser/caller-color behavior were replaced
by eight production-routing regressions. The full count change from parent baseline357 to338
is exactly 357 - 33 + 14, not skipped tests. Parent then added two prior-effects recovery
tests, producing the final 340 total. Counts are XCTest results, not the separate zero-test
Swift Testing footer.

New checks cover exact current pause/hard-lock bytes, queued suspension, historical title/alert
exclusion, selective-effect relaunch cancellation, off-main managed/native work, uncached native
plain-shell registration with nil paint, coalescing 100 ticks without native backlog, and generic
failure retention/retry next to a healthy owned target.

## Startup scope defect and correction

Parent identified startup register followed by unrestricted reconcile as too broad. Confirmed
from source and the new uncached-native fixture: registration returns nil paint, but subsequent
reconcile emits OSC111 to a newly discovered no-effect plain shell. This is passing test evidence
of current behavior, not acceptance of that behavior. Normal unmuted startup must preserve
unaffected shell backgrounds and clear only prior effects.

Parent added narrowly scoped VisualRecovery.reconcilePriorEffects using cached effect targets
without native/registry expansion, plus independent red/green recovery tests. Worker held edits
and builds during that slice, then changed Broadcaster startup to use the method. The retained
uncached-native test now proves exactly one metadata prepare returning nil, no bytes, cached
native identity and truthful unaffected/catalogueAvailable diagnostics. Coalescing now performs
two native calls instead of three; prior-effect clearing does not enumerate native rows again.

Final focused14 and full340 green followed the correction. Source/build slot was released to
parent and the entry worker immediately after the full result. No further source edits or builds
will run in this slice.

## Handoff

Key functions: init(recovery:), broadcastPaused, broadcastLocked, broadcastPausedClear, broadcast,
discoverAndRegisterActiveAgentTTYs, enqueue, drain, lastResult and waitUntilIdle.
Only the two scope paths above changed. Managed writer deadlines and ProcessRunner source are
untouched. No normal action calls recover or changes the suspension marker. No production
Broadcaster raw pending bytes, ps argv discovery, pruning or direct-device calls remain.

All fixture behavior is verified; live app/native visual acceptance, remaining headless routing
integration and independent review remain parent work. This report does not close Phase 6 or
the master goal.

## Observed workflow for parent capture

Tests exposed the required constructor boundary before source changes. Exact PTY bytes caught
queue-time policy semantics; semaphore gates were outside the 100ms managed-device deadline.
A failed combined delete/add patch for the test file made no mutation; verified backups preceded
the approved replacement. Full-suite success did not replace semantic review: startup reset of
unaffected shells remained a defect despite all tests passing and was reported before release.
