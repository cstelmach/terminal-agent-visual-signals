# Phase 8 manual focus lifecycle

Last Updated: 2026-10-12
Version: 1.0
Source checkpoint: `efcb6cd` (`docs: Record copied-install verification`).

Read-only exploration. No source edits, builds, device output, native/Ghostty/UI commands,
installations, or real-home actions were performed.

## Smallest integration

Extend the current `FocusController` with Off/Manual mode and one captured native working set.
Keep browsing selection and preview state independent. Feed successful Sessions catalogue
refreshes into the controller for closure reconciliation, new outside surfaces, recomposition
and ownership heartbeat. Keep the existing Sessions repeating timer alive whenever the window
is open or manual mode is active. Do not introduce another catalogue service or timer API.

`SPEC.md:89-96` already requires two-second catalogue refresh while the organizer is open or
mode is not Off. `SPEC.md:116-121,328-331,417-426` requires independent captured selection,
focus surviving window close/global pause, new surfaces outside the captured set, and Off
when its last working surface is lost. Phase 8 PLAN steps are at `PLAN.md:407-412`.

All implementation anchors below are under `src/macos/TAVSApp/Sources/TAVSApp/`.

## Minimum controller state and API

Recommended public additions, alongside the existing preview methods:

```swift
enum FocusMode { case off, manual }

@Published private(set) var mode: FocusMode = .off
@Published private(set) var workingSet = Set<GhosttySurfaceID>()
@Published private(set) var focusStatus = "Focus: Off"

func focusSelected(_ selected: [GhosttySurface], catalogue: [GhosttySurface])
func acceptCatalogue(_ rows: [GhosttySurface])
func catalogueUnavailable()
func focusOff()
```

One in-memory manual request needs an effect ID, existing suspension-file revision, captured
working IDs, and previously affected target bindings for cleanup/retry. Keep current manual
identity separate from `current: Run`, which presently identifies the two-second preview
(`focus-controller.swift:18,119-126`). The existing lock and work queues can protect current
manual identity; no generic controller/service abstraction is needed.

Focus Selected snapshots the current valid selected surface IDs once. Browsing `selection`,
changing priorities, previews and normal refreshes must never overwrite that captured set.
A second deliberate Focus Selected can replace it. Publish the logical mode synchronously
on the main queue so the catalogue timer can remain alive before background painting starts.
Actual paint still requires current bindings, policy, revision and safe color composition.
Before dimming outside surfaces, require at least one currently verified working binding.
If every chosen or remaining working mapping is unavailable, retain honest unavailable status
and do not newly dim the rest of the catalogue on an unverified working set.

`acceptCatalogue` intersects working IDs with the validated complete current native IDs.
Present IDs with an unavailable mapping stay in the logical set but cannot authorize painting.
New IDs remain outside the set. Compute affected targets using current verified rows and
retain old affected bindings until restoration succeeds or their lifetime is confirmed ended.
If the captured set is empty after confirmed closure, transition Off and restore surviving
outside targets to their latest intent.

`catalogueUnavailable` preserves the captured set and cleanup bindings, shows stale coverage,
and prevents queued/new manual paint or ownership renewal from using old rows. A failed refresh
or existing ambiguous empty response does not prove a captured surface closed. Existing effects
stay recoverable. Their six-second ownership can become stale; do not claim this alone resets
paint in a plain shell (`terminal-visual-state.swift:169-175`, SPEC:179-186).

`focusOff` invalidates manual work first, clears the captured set, then cancels only this manual
effect ID across affected aliases and recomposes current policy/latest ordinary intent.
It does not cancel a current harmless preview. A normal preview clear must likewise leave
manual mode and its set intact. `.reconcile(clearSelective:true)` is too broad for Focus Off
because it also clears previews; use exact manual-ID clearing through the managed writer.

## Catalogue timer without a new timer owner

Current `SessionsModel.opened()` starts one two-second repeating timer at
`sessions-model.swift:116-121`; `closed()` cancels it unconditionally at `:123`.
Change only that timer's condition to:

```swift
isOpen || mode != .off
```

Track one Boolean indicating whether that existing timer is armed. Repeated open, Focus
Selected or refresh operations must not add another repeating timer. Closing clears preview
and changes `isOpen`, then cancels catalogue polling only if mode is Off. Reopening while
manual focus already owns polling performs an immediate refresh without duplicating the timer.
Focus Off or loss of the last captured target stops polling only when the window is closed.

Observe the controller's actual `$mode` value to update that condition. The current subscription
at `sessions-model.swift:72` forwards `objectWillChange`; reading `focus.mode` inside that
notification can see its old value. A small dedicated mode subscription receiving the new
value avoids that trap and handles asynchronous automatic Off after confirmed closure.
Use the received mode argument when updating the timer rather than rereading an old value.

Reuse successful two-second catalogue acceptance as the manual recomposition/heartbeat tick.
Do not add another repeating heartbeat owner solely for manual focus. Existing preview
expiry remains on the controller's `timers` instance (`focus-controller.swift:38-41,80-83`),
separate from Sessions catalogue timers. Manual focus must never call that preview owner's
`cancelAll` except as part of explicit recovery, which ends both kinds of work.

Retain the current `refreshing` guard (`sessions-model.swift:158-161`) and native serialized
requests (`ghostty-catalog.swift:65-102`). Do not stack a manual paint job for every tick if
the previous bounded color/paint work is still running; retain at most one current request and
the latest accepted catalogue. Each queued writer still checks the current manual identity.

## Exact caller changes

| Caller | Existing anchor | Required change |
|---|---|---|
| `SessionsModel.selection.didSet` | `sessions-model.swift:11-15` | Keep preview-only; never capture/replace manual working set |
| `setPriority` | `sessions-model.swift:94-101` | Leave manual set untouched |
| `opened` / `closed` | `sessions-model.swift:116-123` | Apply open-or-manual timer condition; close clears preview only |
| `acceptCatalogue` | `sessions-model.swift:186-195` | Reconcile manual controller after accepting verified rows; intersect browsing selection independently |
| `markCoverageStale` | `sessions-model.swift:198-204` | Keep current preview clear; also mark manual catalogue unavailable without dropping captured IDs |
| `refresh` before its in-flight guard | `sessions-model.swift:158-161` | Observe suspension/revision changes even while native refresh is pending |
| `restoreVisibility` | `sessions-model.swift:127-140` | Existing `cancelForRecovery` must invalidate manual state too, before helper launch |
| `FocusController.cancelForRecovery` | `focus-controller.swift:104-108` | End preview and manual mode without ordinary repaint over emergency reset |
| Sessions controls/footer | `sessions-view.swift:17-30,105-117` | Add Focus Selected, Focus Off, actual mode/set status; retain Escape as preview clear |
| Menu | `MenuContent.swift:28-35` | Add always-reachable Focus Off using the same Sessions model; keep recovery reachable under lock |
| Factory | `TAVSApp.swift:195-219` | Reuse the existing controller, roots, allowed scope and color resolver |

The App retains its Sessions model as a `@StateObject` independently of the Sessions window
(`TAVSApp.swift:110-124`), so window closure does not require another model/service lifetime.

## State transitions

| Event | Captured set/mode | Presentation and polling |
|---|---|---|
| Browse/priority change | Preserve | Preview may override dimming temporarily; catalogue tick continues |
| Window close | Preserve Manual | Clear preview; continue catalogue tick |
| Successful catalogue adds surface | Preserve | New surface is outside and may be dimmed after validation |
| Successful catalogue removes one working ID | Remove only confirmed missing ID | Retain Manual while another captured ID remains |
| Last captured ID confirmed lost | Clear and Off | Restore surviving outside targets; stop closed-window polling |
| Failed/ambiguous empty catalogue | Preserve | No new effects from stale rows; retain cleanup and retry polling |
| Global pause/lock enters | Preserve Manual | Current global policy wins; keep polling for release and closure |
| Global pause/lock ends | Preserve Manual | Recompose captured outside set from newest intent after legacy reset |
| Focus Off | Clear and Off | Cancel manual effects only; current preview/global rule retains precedence |
| GUI recover or explicit resume | Clear and Off | Cancel both kinds before helper; no ordinary repaint over emergency reset |
| Independent recovery/repeated resume | Clear and Off when observed | Marker revision prevents queued reactivation; preserve reset output |
| App relaunch | Start Off | Existing broadcaster prior-effect reconciliation restores recorded targets |

Empty catalogue currently means unavailable in Sessions (`sessions-model.swift:174-177`).
Do not silently reinterpret `.success([])` as confirmed closure in this slice. If the adapter
needs an explicitly verified empty-catalogue result later, that is a separate small interface
decision. Independent process/device evidence can already identify proven lifetime end via
`validateTarget` (`terminal-visual-state.swift:144-166`).

Recovery detection must compare the existing captured marker revision, not only suspended
Boolean. `recover` then `resume` can end active with a new marker identity. Reuse
`VisualRestrictionsStateStore.matches` (`visual-restrictions-state.swift:38-74`) before manual
writers and on polling. A revision change ends the prior manual request and mode; do not
capture the replacement revision automatically and revive it. Check this even before a
refresh's `refreshing` guard, as the existing status update already does. Explicit resumption
never restores a previous mode. Suspension also disables a new Focus Selected with explanation.

## Global pause release needs actual recomposition

Current `TerminalEffectRecord` uses one `effect.json` slot for global/selective background and
a separate preview slot (`terminal-visual-state.swift`, `effectURL`). Global writes replace
that shared slot (`visual-recovery.swift:217-227`). Retaining controller IDs through pause
therefore does not retain the underlying selective record automatically.

`Scheduler.clearPausedVisualAndReplayPending` already calls the safe broadcaster release path
(`Scheduler.swift:469-473`, `Broadcaster.swift:33-38`). That path resets legacy colors and
composes stored leases, but cannot recover manual dimming from a lease overwritten by global
paint. Writer/release integration must preserve or re-establish the captured outside effects.
Recomposition on the next successful catalogue tick can restore them within polling latency.
Do not claim immediate release restoration unless the writer or a small existing release
callback actually recomposes the retained set on that transition. No pending OSC replay.

## Focused regression additions

Reuse `FocusControllerTests`' injected clock, process identities, PTYs and independent mock
timer owners (`focus-controller-tests.swift:19-78,148-165`). Keep the existing preview expiry,
old-handler and queued-lookup cancellation cases (`:93-145`). Extend:

1. Focus Selected captures A; browse B and change priorities. Working set remains A.
2. Close Sessions during Manual. Preview timer clears, exactly one catalogue timer remains,
   and a subsequent tick sees a new C and treats it as outside. Reopen adds no duplicate timer.
3. Focus Off with window closed cancels catalogue polling; with window open it does not.
   Invoking preview Clear/Escape never cancels manual polling or changes the working set.
4. Verified catalogue loses one captured ID, then the last. Preserve the first remainder;
   finally go Off and restore every still-valid outside target to latest intent.
5. Permission failure and `.success([])` preserve captured IDs/cleanup targets, report stale
   coverage, and reject a queued/new outside paint. A valid later refresh resumes composition.
6. Preview outside B then expire/Clear it. B returns to manual dimming using newest ordinary
   intent. Focus Off during that preview leaves the preview active until its own expiry.
7. Pause/lock enters and ends. Captured set survives both; release uses newest intent and
   emits no historical title/bell. Cover the shared effect-slot overwrite explicitly.
8. Independent recover and recover-resume while window closed invalidate mode even when final
   marker status is active. Queued manual paint cannot reactivate; fresh explicit focus can.
9. Recovery unavailable/partial helper still leaves mode Off and its saved suspension state;
   existing recovery feedback survives normal refresh.
10. Failed target restoration remains retryable without blocking healthy targets; replaced
    TTY/owner generations do not inherit focus. Restart constructor starts Off and existing
    prior-effect reconciliation clears old effects.

Additional existing coverage: `sessions-model-tests.swift:87-99,120-175` tests confirmed
selection closure, timer ownership and status refresh before the in-flight native guard.
`SchedulerTests` already checks release ordering; `BroadcasterTests` checks safe recomposition.
No runtime, physical readability, sleep/wake or live timing acceptance was performed here.
