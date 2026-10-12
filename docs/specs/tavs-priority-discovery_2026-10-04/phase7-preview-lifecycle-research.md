# TAVS Phase 7 preview lifecycle exploration

Last Updated: 2026-10-12
Version: 1.0

Scope: read-only source exploration. No builds, device writes, native/AppleEvents/UI commands,
installations, or real-home changes were performed. Source anchors describe the checkout read
on this date. The parent owns implementation and verification.

## Recommendation

Extend the existing `VisualRecovery` managed writer with preview start, exact-ID heartbeat,
and exact-ID clear. Retain `TerminalVisualStateStore` as the persisted owner/intent store.
Use a small controller for selection and the two-second deadline. Do not add another writer,
state directory, arbitrary OSC parser, watcher daemon, or general timer API.

The existing state helpers provide most of the required mechanism. The missing pieces are:

1. A harmless preview effect kind distinct from restriction-driven selective focus.
2. Start/refresh/clear operations routed through the existing managed writer.
3. One current preview ID and deadline, with stale-callback rejection.
4. Separate preview and Sessions catalogue timer owners.

## Contract and existing boundaries

- Dated `SPEC.md:116-121`: every selection change restarts one two-second preview for all
  selected rows; deselections, Clear, Escape, and window close clear it. Selection and focus
  remain separate state.
- `SPEC.md:154-164`: ordinary intent changes during effects; clear must use the latest intent,
  and normal writers must respect controller ownership.
- `SPEC.md:179-186`: persist target, effect, controller PID/start generation, and heartbeat
  before paint; two-second refresh while needed; dead or more-than-six-second-old ownership
  stops blocking ordinary output. Abrupt crash paint may remain until recovery/relaunch.
- `SPEC.md:190-214`: suspension allows a new harmless preview, an active global rule blocks
  previews, background-only clear uses OSC 111 when no ordinary intent exists, and configured
  colors are not arbitrary running-program colors.
- `SPEC.md:263-269`: target, owner and current policy checks occur inside shared per-TTY
  serialization after bounded device open.
- Dated `PLAN.md:352-360,388-401`: background-only renderer, immediate clear paths, separate
  preview/refresh timers, recovery clears previews, and live timing/visibility remain required.

## Existing APIs to reuse

All source paths below are under `src/macos/TAVSApp/Sources/TAVSApp/`.

| API | Anchor | Use |
|---|---|---|
| `captureTarget(for:)` | `terminal-visual-state.swift:127-135` | Capture selected native row against current foreground family and continuing TTY owner |
| `validateTarget` | `terminal-visual-state.swift:144-166` | Check process generations, device, native application, and opened descriptor |
| `physicalTarget` | `terminal-visual-state.swift:41-43` | Deduplicate plain/native aliases of the same device and owner generation |
| `isSelectiveLeaseActive` | `terminal-visual-state.swift:169-176` | Existing six-second heartbeat and controller-generation check |
| `saveEffectUnlocked` | `terminal-visual-state.swift:204-217` | Persist ownership before output; same canceled ID cannot reactivate |
| `matchingEffectUnlocked` | `terminal-visual-state.swift:219-224` | Match active effect ID and controller generation |
| `refreshEffectUnlocked` | `terminal-visual-state.swift:226-234` | Heartbeat exact active ID, live controller and valid target |
| `cancelEffectUnlocked` | `terminal-visual-state.swift:236-243` | Mark exact active ID canceled without deleting recovery information |
| `equivalentBindingsUnlocked` | `terminal-visual-state.swift:245-290` | Discover current plain/native aliases; reject ambiguity and unavailable metadata |
| `ordinaryBackgroundUnlocked` | `terminal-visual-state.swift:293-322` | Latest valid intent, including exact bound intent after producer exit |
| `write(_:to:)` / `performWrite` | `visual-recovery.swift:62-76,112-198` | One serialized validation/composition/write path |
| `effectsUnlocked` / `cancelEffects` | `visual-recovery.swift:348-359` | Enumerate and cancel effects across equivalent aliases under the existing lock |
| `reconcilePriorEffects` | `visual-recovery.swift:280-286` | Relaunch clears recorded prior effects without waiting for native discovery |
| `backgroundBytes` | `visual-recovery.swift:396-398` | OSC 11 or OSC 111 only |

`ProcessRunner.swift:129-178` opens the device before acquiring the advisory lock, then runs
the prepare callback while holding that lock. It carries a single original deadline.
`ProcessRunner.swift:184-195` gives each write 100 ms. A late worker must honor that original
deadline before any state mutation, so preview code must not obtain a fresh budget.

## Smallest API additions

These are recommendations, not existing APIs. Method/operation names can follow surrounding
style. Extend `ManagedVisualOperation` rather than creating another output service:

```swift
case preview(effectID: String,
             compose: (String?) throws -> String,
             isCurrent: () -> Bool)
case refreshPreview(effectID: String)
case clearPreview(effectID: String)
```

`compose` is the small renderer callback. Inside the writer lock, provide it the current
`ordinaryBackgroundUnlocked` result. It chooses the configured baseline only when needed,
returns a validated visible safe tint, or throws an explicit unavailable result. Resolve
Ghostty configuration outside the device lock with the existing bounded subprocess API.
An already-computed color alone is insufficient for latest-intent composition after queuing.

The existing `VisualRecovery.controller` supplies the process generation. Confirm it is live
before creating a new effect; `saveEffectUnlocked` validates structure, but does not itself
perform the live-controller check used by `refreshEffectUnlocked`.

Start should validate the opened target, check the current preview ID/deadline, obtain current
policy, and reject an active global rule with an explanation. Then inspect equivalent aliases,
cancel superseded preview records owned by this controller, persist the new effect, and return
only the background bytes. Do not replace another live controller's lease silently.

Refresh should locate the matching preview ID/controller across equivalent aliases, recheck
current policy and the controller deadline, and call `refreshEffectUnlocked` only for the
matching record. It can recompose the tint from latest intent if the controller is repainting.
An unmatched/canceled ID must perform no mutation or output.

Clear should cancel only matching preview records across aliases. If there is no match, return
without painting; an old timeout must not replace a new preview or current global rule.
For a matching clear, compose current policy/current remaining ownership/latest ordinary
intent under the same lock. No background intent means OSC 111. Retain inactive effects for
retry/relaunch restoration when repaint fails.

Do not use `.reconcile(resetLegacy:false, clearSelective:true)` as ordinary preview clear:
it cancels every selective lease, which is broader than the preview ID and would clear a
restarted preview or future focus. Reserve that operation for recovery/relaunch.

## Preview distinction and policy

`TerminalEffectKind` currently has only `globalRestriction` and `selectiveBackground`
(`terminal-visual-state.swift:47`). `visual-recovery.swift:171-173` suppresses all selective
leases when restrictions are disabled. This conflicts with new harmless previews under
suspension (`SPEC.md:192-193`). Add one enum case such as `selectionPreview`, keep the same
record schema/keys, and extend lease liveness to that case.

Composition should allow live `selectionPreview` ownership while suspended and still suppress
restriction-driven `selectiveBackground`. Emergency recovery must cancel both kinds.
If both preview and focus records occur across aliases, select the preview by precedence
instead of requiring every lease to have identical ID/background. Do not implement a focus
stack in Phase 7; Phase 8's captured set remains controller state and can recompose after clear.

The strict decoder derives supported kinds from `TerminalEffectKind(rawValue:)`
(`terminal-visual-state.swift:1089-1104`). No shell or Python effect-kind parser was found in
`src/`; shell paths delegate to the managed Swift helper. The copied/bundled helper still
must be updated, since an older Swift reader rejects a new enum value. No CLI preview verb
is required by the spec.

`VisualRestrictionPolicy.current` rereads suspension and current lock/mute state inside the
writer (`visual-restriction-policy.swift:27-50`). A queued preview must use that result.
`VisualRecovery.recover` persists suspension before reset (`visual-recovery.swift:201-211`).
Recovery resets current previews; a later explicitly started preview may be harmless.
GUI-triggered recovery must invalidate its current preview ID before launching repaint so a
queued start/heartbeat cannot revive pre-recovery ownership. Independent headless recovery
also cancels persisted matching IDs, so an old heartbeat fails. However, a queued initial
start with no persisted record yet has nothing for recovery to cancel. The suspension Boolean
does not distinguish that start from a new explicit preview. Include that ordering in a
regression before claiming full cancellation safety. An in-memory controller token alone
does not solve independent recovery. The parent must choose the smallest shared-state check
that prevents pre-recovery starts without blocking genuinely new previews.

## Aliases and lifetime

- Capture targets from current catalogue rows. Do not derive authority from cached row title,
  directory, selection ID alone, or TTY path.
- Group selected aliases by `physicalTarget`; emit one write per verified physical target.
- Use `equivalentBindingsUnlocked` within the managed write. It accepts a plain binding and
  one native binding, but rejects multiple current native surface IDs or unavailable metadata.
- Exact effect ID and controller matching must cover every equivalent alias, since ordinary
  hook output can resolve through either binding (`visual-recovery.swift:263-307,348-359`).
- Preserve target bindings on write failure. Confirmed vanished targets can leave the active
  selection; unavailable live targets require an explicit retryable failure, not guessed reuse.
- `ordinaryBackgroundUnlocked` reads the newest record and accepts bound copies only when they
  equal that newest record. A continuing shell can restore a producer's bound intent after
  the producer exits; an older bound color must never override a newer unbound record.

## Controller and timers

`TimerScheduler` already supports one-shot, repeating and `cancelAll`
(`TimerScheduler.swift:3-38`); no protocol change is necessary. Sessions catalogue refresh
owns its own scheduler and cancels all its timers on close
(`sessions-model.swift:97-104`). Give preview expiry a different scheduler instance.

Minimum controller state is the current preview ID, common two-second deadline, and painted
target bindings. Selection change invalidates the previous ID, cancels the old expiry timer,
clears deselections and starts one timer for all new selected rows. The deadline starts at
selection change, not separately after each target finishes painting. A target delayed past
the deadline must not acquire preview ownership.

Use one serial controller queue for lifecycle work and a synchronized current-ID check inside
the managed prepare callback. A main-thread check before queuing is insufficient: a different
old ID can otherwise overwrite a newer effect via `saveEffectUnlocked`. Canceled timer
handlers may already be queued, so every expiry/refresh callback must match its captured ID.

A two-second preview has no intermediate heartbeat interval. Initial paint records heartbeat;
at two seconds the expiry cancels it instead of renewing an expired preview. Repeated selection
changes save fresh effects. Keep the two-second exact-ID heartbeat operation available for
ownership that remains active; do not add a watchdog or polling loop merely for a two-second
preview. If a repeating heartbeat is scheduled, ensure expiry and current-ID/deadline guards
win when both callbacks are due together.

`SessionsModel.selection` is currently directly published (`sessions-model.swift:11`), and
catalogue acceptance intersects selection (`:134-143`). Wire preview initiation to actual
selection changes, including that intersection; ordinary catalogue polling must not restart
an unchanged selection. `closed()` must cancel preview as well as refresh. `sessions-view.swift`
currently has Clear Selection at `:26-27`, Table selection at `:34`, and close at `:102-103`;
add Clear Preview/Escape without navigation or activation.

`Broadcaster.swift:33-39,98-106` already routes normal global release to a legacy reset plus
current recomposition, and clears prior effects on launch. Reuse this behavior and extend
its lease composition; do not introduce pending OSC replay into preview clear.

## Meaningful regression suggestions

Existing tests to retain and extend:

- `terminal-visual-state-tests.swift:546-597`: canceled same ID cannot revive, wrong ID or
  controller preserves a new effect, and six-second boundary plus controller PID reuse.
- `terminal-visual-state-tests.swift:600-643`: same held lock/original deadline, immutable
  observation and intent bytes, and expired writes cannot mutate effects.
- `visual-recovery-tests.swift:415-424`: intent updates while ownership wins; stale owner
  clears to the newest intent.
- `visual-recovery-tests.swift:606-677`: latest bound intent survives producer exit;
  native/plain alias recovery writes once and cancels every matching alias.
- `sessions-model-tests.swift:120-133`: refresh owns its own timer and stops on close.

Add controller/writer tests for:

1. Multirow selection shares exactly one two-second deadline; switching selection at 1.5 s
   cancels deselections and the old handler cannot clear the new preview.
2. Intent changes to a new color and then reset during preview; expiry paints the newest
   value, with no title, BEL alert, foreground, palette, cursor or pending replay bytes.
3. No ordinary intent: preview uses configured background for composition, clear emits only
   OSC 111. An unsafe/no-visible tint is explained instead of counted as a painted preview.
4. Active global rule blocks selection preview. A rule activated while device open is pending
   wins when the prepare callback reads policy. Suspension permits a fresh harmless preview.
5. Recovery invalidates the current preview and resets once; queued start and heartbeat
   cannot recreate it. A new explicit preview after recovery can start.
6. Native/plain aliases receive one physical write; clearing old ID does not cancel a new
   alias lease. Ambiguous native aliases or reused owner/device never authorize paint.
7. Paint failure after persisted ownership remains discoverable for clear/relaunch. One
   failed target does not prevent restoration of healthy selected targets.
8. Preview timer cancellation leaves the catalogue refresh timer running; catalogue refresh
   does not extend preview; Clear/Escape/close end preview immediately without navigation.

These are source-grounded recommendations. No runtime, compilation, physical visibility,
keyboard-focus, timing, live Ghostty configuration, or signed/copied-helper acceptance was
performed here. Those remain parent verification work.
