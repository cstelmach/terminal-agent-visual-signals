# Phase 5 Swift scheduler and UI integration

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0
Baseline: `120c79d`

## Assigned scope and changed files

Only these eight assigned repository paths were edited:

- `src/macos/TAVSApp/Sources/TAVSApp/Scheduler.swift`
- `src/macos/TAVSApp/Sources/TAVSApp/TAVSApp.swift`
- `src/macos/TAVSApp/Sources/TAVSApp/MenuContent.swift`
- `src/macos/TAVSApp/Sources/TAVSApp/sessions-model.swift`
- `src/macos/TAVSApp/Sources/TAVSApp/sessions-view.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/SchedulerTests.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/SchedulerLockTests.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/sessions-model-tests.swift`

Parent owns the new VisualRestrictionsStateStore/status module and its tests. Its API and
implementation were consumed without edits. Shell, documentation, Git and live state were
not modified by this worker. Parent-provided backups exist. No commit was made.

Diff: 303 insertions, 20 deletions, including 239 added test lines. The production integration
is one connected consumer feature; no new service, generic framework, timer or watcher exists.

## Implemented behavior

Scheduler accepts `visualRestrictionsState: VisualRestrictionsStateStore? = nil`. Nil derives
the marker beside the injected muteStateURL, keeping existing test constructors private.
Production createDefault explicitly supplies `.tavs/visual-restrictions.state`.

The scheduler publishes `visualRestrictionsStatus` and the configured `masterActive`, separately
from projected `isMuted` and `isHardLocked`. Existing raw ScheduleEvaluator results,
LockStateMerge inputs, lock/grant state maintenance and all heartbeat/boundary/expiry timers
remain intact. Valid suspension and unavailable state override only visual projection: muted
false, reason none, visual hard lock false and explicit generic status before lock/grant text.

While disabled, previousMuted remains false and pause/lock paint caches are cleared. Entering
suspension does not run the ordinary unmute reset/replay path. No pause, lock, reset, replay or
startup discovery broadcaster call runs during disabled state. The legacy Restore Terminal
Colors method also reads the persistent store before permitting a reset; its menu action is
disabled visibly. Explicit resumption recomputes current rules and repaints any current pause/
lock rather than restoring a stale visual snapshot.

New manual locks keep the existing definition/merge behavior but stay visually inert under
suspension. Existing grants retain their actual deadlines and expire naturally. No configured
hard lock hidden by suspension challenges a master-schedule resume. The MenuContent master
label/action reads masterActive rather than inferring it from the projected mute reason.

Menu status explains suspension or unavailable state, and an added caption explains that new
rules/locks remain visually inactive. The menu icon uses eye.slash while restrictions are
disabled. Preferences already consume scheduler.statusText and isHardLocked, so their status
and challenge predicate inherit the same projection without an unrelated file change.

SessionsModel accepts the same explicit-store label, with its nil fallback adjacent to the
injected priorities URL. It reads status on construction and before refresh's in-flight native
guard. Thus its existing two-second refresh timer can update the suspension banner even while
a native request hangs or fails. The independent banner preserves native status, selection,
priorities, coverage, navigation and Focus: Off.

TAVSAppMain calls VisualRestrictionsStateStore.handle before all UI launch branches. Production
Sessions uses the explicit `.tavs` marker. Both private fixture and dedicated-native Sessions
constructors use `launch.root/home/.tavs/visual-restrictions.state`, matching the staged test
bundle's HOME/CFFIXED_USER_HOME convention. The private app still constructs no global Scheduler.

## Key APIs/functions touched

- Scheduler.init, start, restoreTerminalColors, loadAndEvaluate, finishEvaluation,
  updatePublishedState, visualRestrictionsStatus and masterActive.
- MenuContent's configured master toggle, legacy reset availability and inactive-rule notice.
- TAVSAppMain.main, TAVSApp's Sessions constructor/icon, IsolatedSessionsLaunch.model and
  Scheduler.createDefault.
- SessionsModel.init, convenience init, refresh and visualRestrictionsStatus.
- SessionsView's independent status banner.

## Tests-first verification

The SPEC suspension/precedence/recovery requirements, PLAN Phase 5, current PROGRESS/GOAL and
the scheduler exploration report were reread before this slice. Constructor/default semantics
and the no-broadcaster interpretation were agreed with parent before implementation. No build
started until parent supplied the shared module and released the scratch.

Exact focused command:

```bash
TAVS_TEST_HELPER_BIN=/tmp/tavs-phase5-20261012T132300/baseline-helper \
  tests/run-isolated.sh swift test --package-path src/macos/TAVSApp \
  --scratch-path /tmp/tavs-phase5-20261012T132300/build \
  --filter 'SchedulerLifecycleTests|SchedulerLockTests|SessionsModelTests'
```

Retained evidence:

- Initial red: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.9Wa87m/command.log`.
  Exit 1 because Scheduler/model injection/status/master APIs did not exist.
- First green: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.TT8ykz/command.log`.
  64 consumer tests, zero failures.
- Parent clarified the isolated bundle's private HOME convention. The fixture marker path was
  changed before the production constructor. Red:
  `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.pJQU0a/command.log`.
  One fixture test failed with active versus suspended, proving the old root marker mismatch.
- Final green: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.kU9MHg/command.log`.
  **64 tests, zero failures**: 33 lifecycle, 15 lock, 16 Sessions, 0.239 seconds total.
- No compiler warnings/errors were found in final focused output.
- `git diff --check` for all eight owned files passed.

Only a comment clarification followed the final focused run. No behavioral change followed it.
Parent will run full shared-store/Swift/parity verification; this worker started no full build.
The shared scratch is idle and released to parent.

Added behavioral evidence covers:

1. Suspending an already painted pause causes zero reset/replay/paint calls; heartbeat, file
   watch and legacy restore remain inert; resume repaints the current pause once.
2. Explicit persistent-store suspension survives scheduler relaunch with stale muted runtime
   state and missing schedule, without discovery or historical replay.
3. Unknown schema disables visuals, explains unavailable state and preserves configured master.
4. Overlapping hard quiet/schedule rules plus manual lock/grant retain immediate lock/schedule
   bytes and original expiry timers. Grant expiry and resume use the continuing manual deadline.
5. Soft restrictions with a manual hard lock and grant are also overridden without rewriting
   surviving lock/grant definitions or broadcasting.
6. A newly saved manual lock remains visually inert, then becomes current on explicit resume.
7. Configured master resume under suspension requires no hidden hard-lock challenge.
8. Manual lock/grant expiry still executes without schedule while suspended, with no later replay.
9. Sessions updates marker status before an in-flight native early return and after native
   failure, without selection/priority/navigation/coverage mutation.
10. The existing private fixture factory reads the marker under its private HOME's `.tavs`.

## Capture notes and remaining limits

Observed workflow: tests preceded API changes; parent contract questions were settled before
implementation; disabling the visual projection was placed after raw merge instead of short-
circuiting rule evaluation; all broadcaster calls were counted; a private-root mismatch was
turned into a red regression before correction; actual XCTest counts were read from full logs.
Parent should fold these facts into its required meta-thinking capture with honest attribution.

This is the Phase 5 reader/projection foundation. It does not establish fresh serialized device
checks, independent physical recovery, invalidation of old pending OSC, latest-intent restoration
or a guarantee against a queued writer racing a later suspension. Active legacy unmute behavior
still belongs to later Phase 6/7 replacement. No recovery button or painting was added here.

No native/UI actions, live metadata, install/sync/settings changes, shell suites, real-home
scheduling or device writes were performed. Icon/menu/banner rendering is compiled but requires
parent Computer Use acceptance. Existing tests' cleanup remains confined to owned private roots.
