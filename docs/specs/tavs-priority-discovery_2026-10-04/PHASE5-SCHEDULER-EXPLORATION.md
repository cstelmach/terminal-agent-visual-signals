# Phase 5 scheduler and UI suspension integration

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0

## Scope and current boundary

Read-only inspection at HEAD `120c79d` in:

`/Users/cs/local/code/apps/terminal-agent-visual-signals/`

Re-read the dated package's SPEC persistent-state/precedence/recovery contract,
PLAN Phase 5 and adjoining Phase 6/7 responsibilities, and current PROGRESS
including the Phase 4 completion entry. Phase 4's typed observations/intent exist;
Phase 5 establishes persistent suspension/readers. Device ordering, independent
repaint and public recovery controls remain later work. No build, test, live
read/write, native request or project edit was performed here.

The minimal scheduler change is to keep evaluating configured rules and merging
locks normally, then override only the visual projection with suspension. Do not
replace schedule evaluation with an early return or overwrite saved rules/grants.
Suspended ticks must emit no pause, lock, reset or opaque pending replay.

## Exact contract anchors

Package directory:

`/Users/cs/local/code/apps/terminal-agent-visual-signals/docs/specs/tavs-priority-discovery_2026-10-04/`

- `SPEC.md:168-179`: explicit injectable roots; durable
  `~/.tavs/visual-restrictions.state`; schema 1 and suspended boolean.
- `SPEC.md:192-198`: suspension takes precedence over global/selective restrictions.
- `SPEC.md:230-247`: visible menu/Sessions/status state; explicit resumption;
  underlying definitions retained; new locks/rules visually inert.
- `SPEC.md:249-272`: repaint/reset, pending invalidation and shared in-lock
  output ordering are the independent recovery contract, not a boolean alone.
- `PLAN.md:244-286`: strict shared parsing, visible malformed/unknown handling,
  consistent readers, preserved definitions, and no independent repaint claim
  in Phase 5.
- `PLAN.md:288-347`: Phase 6 ordered recovery across every writer.
- `PLAN.md:350-359`: later GUI recovery integration and global-pause-release
  replacement of opaque replay.

## Minimal explicit persistent store injection

Swift source root for the following files:

`/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/`

Use the planned `visual-restrictions-state.swift` as a small value reader/writer,
following LockState's at-URL functions and Foundation atomic-write style. Return
enough typed status to distinguish absent, known active/suspended and malformed/
unsupported state. Define malformed/unknown behavior in the shared fixture, and
show that state rather than treating parse failure as verified recovery. Do not
source/eval the file or read an ambient home path inside the parser.

Add `visualRestrictionsStateURL` to Scheduler's initializer at
`Scheduler.swift:199`. A required URL is clearest; if compatibility warrants an
optional argument, derive its fallback next to the injected mute/schedule URL,
following the existing lockStateURL fixture pattern. Never default that fallback
to FileManager's real home. Production `Scheduler.createDefault()` at
`TAVSApp.swift:204` explicitly passes `.tavs/visual-restrictions.state`.

This is one injected file/store, not a new policy service hierarchy. Existing
tests already inject clocks, URLs, timers, watchers and broadcaster doubles.
Temporary fixture roots can contain a persistent-state subdirectory separate
from runtime files, demonstrating that removing runtime files does not erase
suspension.

SessionsModel also needs an explicit state URL or one derived from its already
injected prioritiesURL parent. Production and isolated Sessions constructors must
receive the appropriate root. The isolated app still omits the global scheduler;
do not inject a production Scheduler merely to show one status banner.

## Scheduler integration points and ordering

### Preserve configured evaluation

`loadAndEvaluate()` at line 324 cancels/re-arms its own timers, loads ScheduleStore
and calls ScheduleEvaluator. The no-config branch at line 338 still evaluates
manual lock state through finishEvaluation. Apply the suspension reader in a path
that also covers that no-config branch.

Inside `finishEvaluation()` at line 353, leave the following intact:

1. Existing lock read, raw schedule-hard verdict and next transition calculation.
2. `LockStateMerge.merged()` at line 363 with the raw schedule verdict.
3. Manual/schedule lock end and grant end calculation.
4. Normal semantic lock-state maintenance via writeLockStateIfChanged.
5. Heartbeat, schedule boundary, lock-expiry and grant-expiry timers at lines
   446-453, plus existing wake notification.

Do not pass `scheduleHardMuted=false` solely because suspension is true: that
would conflate disabled visuals with the configured schedule and can discard a
scheduled lock projection/grant relationship. Do not zero grant deadlines or
extend lock/grant time while suspended. Their actual epochs continue to expire.
Preserve schedule.json bytes except for an explicit user edit. Lock projection
may legitimately change on natural expiry; tests should distinguish definition
preservation from freezing derived time-dependent state forever.

### Override the visual projection afterward

Compute the ordinary configured mute/effective-lock outcome first. Then valid
suspension projects `muted=false`, no active visual hard lock, and an explicit
suspended UI state. The suspended reason is not proof that old terminal pixels
were cleared. Prefer a published `isVisualRestrictionsSuspended` plus parser
status over pretending the unrelated `.none` reason means normal active policy.

`isHardLocked` currently drives visual UI gates. It should represent the effective
visual hard lock after suspension, or all its consumers must explicitly include
the suspension predicate. Retain the configured merged lock locally/separately
for expiry/status. Do not use a hidden configured lock to challenge an edit or
resume while suspension overrides it.

### Avoid the existing unmute side effect

At lines 390-395, changing projectedMuted from true to false calls
`clearPausedVisualAndReplayPending()`. At lines 469-471 that resets defaults then
calls `Broadcaster.broadcast()` to replay opaque pending OSC. If suspension is
implemented as an ordinary unmute transition, this path replays historical BEL/
titles and performs a reset before Phase 6 provides ordering.

Guard the transition side effects while suspended. Likewise guard paintMuted
calls at lines 425-432, including appearance-change repaint and soft/hard visual
switches. Keep previousMuted aligned with the suspended projection (false), so
leaving suspension does not inherit a fabricated true-to-false unmute transition.
Updating internal last-painted caches is bookkeeping, not a terminal clear.

Write the unmuted mute.state projection and publish suspended status, but emit
NO broadcaster operation on entering suspension or on repeated suspended ticks,
file watches, expiry wakes, rule edits or appearance changes. Normal hook intent
publication continues according to the shared shell readers.

On explicit resumption, re-evaluate the current configured schedule/lock, rather
than restoring an old muted/focus snapshot. If the schedule is already restrictive,
status must explain it. Full invalidation of historical pending output and
recovery-versus-delayed-writer ordering remain Phase 6; do not claim the Phase 5
reader guards establish those guarantees or delete opaque output ad hoc.

## File watching

`startFileWatch()` at Scheduler line 505 watches the parent of scheduleURL. In
production that is `.tavs`, which also contains the suspension marker. Its
existing callback can therefore re-read the suspension atomically on changes;
no second production watcher is needed if the injected marker shares that parent.
Keep test fixtures consistent with this relationship and assert the watched URL.

The separate runtime watcher at line 518 compares lock.state content only. Do
not put the durable marker there or expect that lock-only callback to notice it.
Heartbeat also re-reads state, and wake should re-evaluate suspension normally.
Avoid sharing scheduler timers with Sessions: they are cancelled on every global
evaluation. Sessions already owns its own two-second refresh timer.

## UI/status consumers requiring connected changes

### MenuContent.swift

The existing status Text at line 12 automatically reflects scheduler.statusText,
but the menu button label/action at lines 15-18 uses isMuted + masterPaused to
infer whether master scheduling is paused. Once suspension projects unmuted,
that inference fails even if config.masterActive remains false.

Expose/read configured masterActive or an `isMasterPaused` computed property,
and use it for that label/action. Keep suspension and configured pause distinct.
The scheduler's togglePause guard at line 275 and the menu challenge condition
at line 19 must agree on effective visual locking under suspension.

New manual Lock Now remains a definition-writing action, but status/help should
explain that it applies after explicit resumption. Unlock/grant display must not
claim an active visual lock while suspended.

Do not rename the existing Restore Terminal Colors button to Restore Visibility
yet: it is a legacy broadcaster reset, not the full recovery operation. Its
guard/availability should not suggest suspension has already restored pixels.
The conservative connected change is to refuse that legacy reset while suspended
until the independent recovery path replaces it. Phase 6/7 can integrate the
actual public recovery controls.

### PreferencesView.swift

ScheduleTab already displays scheduler.statusText at line 95, so ensure the
suspension label takes precedence over lock/grant text. `attemptSave()` at line
143 uses isHardLocked to show ChallengeGate. Under suspension new definitions
can be saved without hidden hard-lock challenge while staying visually inert.
Keep the draft Master Active toggle, hard-rule checkboxes and saved definitions
intact. Add a short suspension notice that existing/new rules apply on resumption,
not a second toggle that silently rewrites schedule definitions.

### Scheduler.updatePublishedState()

At lines 630-637, lock and unlock-grant messages win before normal status text.
Put suspension/invalid-state display before those branches. Preserve the actual
configured epoch data internally; the message must not say Locked or Active when
the visual policy is suspended/unknown.

### TAVSApp.swift MenuBarExtra

The icon at line 117 currently depends only on scheduler.isMuted. Projecting false
would display the ordinary active icon under suspension. Add a distinct suspended
indicator using the published suspension state, and keep the menu explanation.
The production factory supplies the marker URL explicitly; isolated Sessions
launch remains separate and cannot start discovery or register login items.

### SessionsModel/View

`SessionsModel.refresh()` at line 98 returns early while a native refresh is
pending. Read the small suspension state BEFORE that native-request guard, or
separately through its existing two-second timer, so a denied/hung catalogue
cannot prevent the suspension banner updating.

The marker read is independent of priorities/observations and must not change
selection, saved priority, catalogue availability, native navigation or coverage.
Show its status independently of model.status, which explains catalogue failures.
`SessionsView` currently displays Focus: Off at line 93; retain that truthful mode
and add suspension status. No manual/automatic activation exists yet, and no such
state should be persisted/restored in this phase.

## Tests and mock injection

Exact Swift test root:

`/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Tests/TAVSAppTests/`

- Planned `visual-restrictions-state-tests.swift`: shared schema fixtures for
  absent/active/suspended/malformed/unknown/duplicate-key data, atomic persistence
  and reader result/status. No parser defaults may reach personal state.
- `SchedulerTests.swift`: inject private suspension URL in lifecycle setup at
  line 311 and the additional visual/status schedulers at lines 495, 554, 610,
  721, 759, 797, 842, 946 and 1001, or use a safely derived fixture default.
- `SchedulerLockTests.swift:60`, makeScheduler: inject marker under private
  persistent root, separate from lock runtime. Verify manual/scheduled locks and
  unlock grants survive suspension and expire on their original epochs.
- Existing MockFileWatcher stores only callback/counters. Add the watched URL
  to assert the marker shares the observed persistent directory; use
  simulateChange followed by the existing main-dispatch test pattern.
- MockBroadcaster already counts broadcast, pause, lock and clear calls. Compare
  all four counts before/after entering suspension, heartbeat, wake/file-change
  simulation, grant/lock expiry and saved new rules. Every automatic suspended
  path must add zero calls, including clear and opaque replay.
- Existing VirtualClock/MockTimerScheduler are sufficient for expiry and boundary
  cases. Do not add a scheduler framework or share its timer instance with Sessions.
- `sessions-model-tests.swift`: inject the private status URL; test banner updates
  while catalogue is unavailable/in flight and no selection/priority/navigation
  changes. Isolated Sessions factory test should prove no real-home marker read.
- Pure configured-master-state tests should catch the menu's previous label/action
  inference, without launching the app or presenting a ChallengeGate.

Assert schedule bytes and surviving lock/grant epochs remain unchanged immediately
on suspension. Separately advance time and assert natural expiry, continued timers,
no suspended paint/replay and current configured policy on explicit resumption.
Do not assert current terminal colors were restored: that is not Phase 5 work.

No test or live verification result is claimed in this report.
