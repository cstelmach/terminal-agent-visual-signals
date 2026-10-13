# Recovery scheduler source investigation

## Metadata

- reviewer: Codex source investigation subagent
- review_type: code
- review_mode: gatekeeping
- tier: standard
- date: 2026-10-13
- target: Claude final-review L4 (Pass C L1), baseline `5adf24145228b9530cf2320e8c03dc321503e89c`
- scope: current tracked source and connected test source only; no tests, live process inspection,
  terminal output, application control, or product edits

All source paths below are relative to
`/Users/cs/local/code/apps/terminal-agent-visual-signals`.

## Rubric Scores

These scores assess the narrow recovery/reconciliation behavior, not the whole product.

| Dimension | Score | Evidence |
|---|---:|---|
| correctness | 4 | Disabled reconciliation reapplies cached ordinary background and resets fresh foreground/palette. |
| security | 7 | Target validation and shared writer serialization remain in the examined path; no security audit performed. |
| maintainability | 6 | A shared writer owns composition, but its large branch mixes recovery and normal release semantics. |
| test_coverage | 5 | Recovery and ordinary release have focused tests, but their running-GUI interleaving is absent. |
| completeness | 5 | Independent recovery is implemented, but later GUI/startup reconciliation violates its default-restoration contract. |

## Verdict

**verdict**: VETO
**confidence**: high for the source claim; no runtime reproduction was attempted.

## Falsification checks

1. Could recovery intentionally restore ordinary themes? No. SPEC lines 249-255 expressly require
   emergency recovery to reset defaults, leave typed intent available, and allow the next legitimate
   hook to restore themes.
2. Could the scheduler avoid reconciliation on suspension? No. Scheduler lines 392-422 project
   suspension to unmuted and then execute the usual muted-to-unmuted release path. Existing
   SchedulerLockTests lines 130-150 assert both broadcaster calls during this transition.
3. Could the shared writer suppress ordinary composition whenever suspended? No. Policy returns no
   current global rule, but `needsBackground` is true for non-render operations, so reconciliation
   reads ordinary intent at visual-recovery.swift lines 362-365.
4. Could queue coalescing make this harmless? No. It can reduce two operations to one, but preserves
   the reset flag. If the first operation has already been drained, both execute. Either first
   reconciliation can violate the contract.
5. Could retained inactive effects be successful-reset receipts? No. `cancelEffectUnlocked` only
   writes `active = false`; emergency cancellation precedes the eventual device write. Failed
   output and successfully restored output can leave the same inactive record shape.

## Findings

### [R1] HIGH: GUI and relaunch reconciliation can undo emergency recovery

- **Situation**: `Scheduler.swift:392-422,469-471`, `Broadcaster.swift:33-38,63-71,98-106`,
  `visual-recovery.swift:334-395,487-490`.
- **Behavior**: While suspended, scheduler release enqueues `.reconcile(true, false)` and
  `.reconcile(false, false)`. Reconciliation bypasses restrictions correctly, but still uses ordinary
  intent as background. It emits OSC 104/110 when the caller's reset flag is set or any global effect
  record remains, including canceled records. Startup reconciliation uses the same path, with
  `clearSelective: true`, on targets retained in the effect cache.
- **Impact**: A completed emergency OSC 104/110/111 reset can be followed by an ordinary cached
  background without a legitimate hook. If a fresh legitimate hook already restored its ordinary
  palette/foreground, a late clear can reset those again. Restoring defaults therefore does not
  remain stable until the next permitted action.
- **Suggestion**: Give disabled `.reconcile` a narrow shared composition rule inside the existing
  managed device writer. Suppress ordinary output when no currently applicable effect needs
  cleanup. Retire residual restrictive effects to defaults without reapplying old ordinary intent.
  Preserve legitimate ordinary/render writes and current harmless-preview clear/expiry behavior.
  Keep active-mode normal pause/lock release unchanged.

## Confirmed source sequence

1. `recover()` persists suspension before `.emergencyReset` (`visual-recovery.swift:399-408`).
2. Emergency writer reads disabled policy under serialization, cancels all effects, removes pending
   opaque output, and returns exactly OSC 104/110/111 (`visual-recovery.swift:232-237`).
3. Typed ordinary intent remains. `testRecoveryPersistsFirstClearsOwnershipAndNeverReplaysPendingBodies`
   explicitly verifies its bytes remain unchanged (`visual-recovery-tests.swift:942-965`).
4. On the next scheduler evaluation, a prior mute becomes projected unmuted while definitions stay
   stored (`Scheduler.swift:352-397`). `wasMuted && !projectedMuted` calls the ordinary release
   function after publishing the new mute projection (`Scheduler.swift:417-422`).
5. Broadcaster queues normal reconciliations. Two pending reconciles merge their flags with logical
   OR; a later `.currentRestriction` cannot overwrite required reconciliation
   (`Broadcaster.swift:63-71`). Dequeued work reads current state inside the shared writer, not the
   scheduler's snapshot (`Broadcaster.swift:23-24,106`).
6. Recovery's inactive global record remains. `cancelEffects` only cancels active records and the
   state store persists them as inactive (`visual-recovery.swift:576-580`,
   `terminal-visual-state.swift:291-298`). `effectsUnlocked` returns these retained records too.
7. A disabled reconciliation sees no global rule, but includes inactive global records in
   `resetLegacy`, invalidates pending, recomposes cached ordinary intent, and emits reset/theme
   bytes (`visual-recovery.swift:309-395`).
8. Relaunch cleanup also traverses retained inactive effect records. `reconcilePriorEffects()`
   targets every saved effect's target, not only active ownership (`visual-recovery.swift:487-490`).

The claim is slightly narrower than “ordinary foreground/palette replay.” `.reconcile` does not
replay an ordinary render's entire foreground/palette/title/bell stream. It resets foreground/palette
with OSC 104/110 and reapplies ordinary **background** via OSC 11. That is sufficient to undo
emergency default background and, after a fresh hook, to strip its newly applied palette/foreground.

## Smallest correct shared fix

Keep scheduler projection, timer/lock/grant maintenance, Broadcaster queueing, and active-mode release.
Concentrate the behavior change in the existing `.reconcile` path in `performWrite`, after target
validation and while its per-TTY lock is held. Avoid new persistent freshness state, receipts, or
intent timestamps.

The rule must distinguish cleanup work from unconditional ordinary recomposition. A practical
behavior table is:

| Current writer state under disabled restrictions | Reconciliation output |
|---|---|
| Emergency completed; only canceled restrictive/preview records remain | No bytes. Remove obsolete pending output as today. |
| No effects; cached ordinary intent exists | No bytes. A subsequent legitimate hook may paint it. |
| Fresh ordinary hook already rendered; only canceled prior records remain | No bytes, including no OSC 104/110/111. Preserve hook output. |
| Still-active residual global restriction, no current harmless preview | Cancel ownership; OSC 104/110/111 defaults only. No ordinary theme. |
| Still-active residual selective/focus restriction, no current harmless preview | Cancel ownership; background default reset only. No OSC 104/110. |
| Valid new explicit preview in the current suspension revision | Keep or recompose that preview's background, without unrelated palette/foreground reset. |
| Current-revision preview clear/expiry | Preserve its normal current-intent/default background restoration. No unrelated palette/foreground reset. |
| Marker unavailable or stale pre-recovery preview ownership | Disable restriction ownership; clear residual paint to defaults rather than ordinary theme. |
| Explicit resume, status active | Existing normal rule/current-intent composition applies. |

Use the existing effect `active` bit to identify residual ownership that has not yet been canceled,
not merely `effects.contains(kind: .globalRestriction)` or the caller's reset flag. The caller flag
means “ordinary release requested,” not “physical legacy paint is still present after emergency.”
Ignore that flag for disabled reconciliation when there is no residual legacy cleanup need.

A blanket `restrictionsDisabled -> return nil` is too broad because startup must clear residual
restrictions even when the headless helper failed or the GUI was killed. A blanket
`restrictionsDisabled -> Self.reset` is also wrong: it erases a fresh ordinary hook, erases permitted
new previews, and modifies foreground/palette after background-only preview activity.

For preview clear/expiry, the existing marker revision identifies a post-suspension explicit
preview. Current preview lease selection already checks revisions at lines 341-347. An expired
preview is absent from that active lease array but its saved effect can remain `active == true`.
If generic `.reconcile` performs preview expiry, retain a distinction between an ended preview in
this suspension revision and a stale preview from before recovery. Reuse its existing revision,
not a newly stored intent-freshness marker. Direct `.clearPreview` already has revision/ownership
checks and should keep its behavior.

When a residual global restriction and a valid current preview coexist, reset only the residual
legacy foreground/palette as needed and keep the preview background as the final background. Do
not let generic baseline cleanup override the explicitly permitted preview. In the ordinary
completed-emergency sequence all old restrictions are inactive, so no such legacy reset is needed.

The fix can remain a small branch or a few booleans in the shared writer. It does not require a new
scheduler operation, cancellation API, control-plane artifact, or alternative output writer.

## Failure and retry limitation to preserve honestly

Inactive record shape does not distinguish a successful emergency write from an emergency write
that failed after canceling ownership. Without adding state, disabled generic reconciliation cannot
both always retry that possible residual paint and always preserve a fresh ordinary hook that
followed a successful reset. Choosing to emit defaults for every inactive record violates the fresh
hook contract demonstrably. Choosing to suppress generic inactive-record output is the minimal
correct policy for completed recovery, while a reported failed recovery remains explicitly retryable
through `recover()`, which resets cached targets regardless of the effect's active bit.

Do not remove those records or disable explicit recovery retry. Keep existing active-mode relaunch
cleanup of canceled global failure records (`visual-recovery-tests.swift:1462-1473`). Do not claim
that a no-op suspended reconciliation repaired a previously failed device reset. The current API
already exposes partial failures, so this limitation requires no new durable freshness mechanism.

## Races and coalescing

- GUI clear before headless reset: disabled shared reconciliation clears residual restrictions to
  defaults; the later independent reset finishes with defaults. Ordinary intent is not reintroduced.
- GUI clear after headless reset: old effects are inactive; shared reconciliation emits no bytes.
- Ordinary hook after headless reset but before delayed GUI clear: normal hook/render emits its theme;
  the delayed inactive-effect reconciliation emits no bytes and cannot strip that theme.
- Reconcile queued while active, suspended before device open finishes: a guard inside the writer
  sees current disabled state. A scheduler-only guard or queue-time decision misses this case.
- Marker changes after writer checks: retain the existing serialization ordering. Independent reset
  still runs after any earlier committed write under the same lock. Do not bypass that lock or add
  a later corrective repaint as the sole race strategy.
- Pending reset flags: current coalescing ORs them. This is correct for ordinary active-mode release;
  disabled writer behavior must decide whether reset is still needed from current effects. Do not
  mutate coalescing to drop a required normal reset.
- Dequeued versus pending work: both one coalesced release and two separately drained releases need
  the same result. Tests should not assume a deterministic queue merge merely because two methods
  were called consecutively.
- Startup: the shared fix also reaches prior-effect reconciliation, including when native discovery
  blocks. Retain its independent cached-target cleanup before native catalogue queries.
- Plain/native aliases: one physical target can carry both records. Inspect all equivalent effects
  as the current shared path does; classify cleanup once and avoid duplicate output.

## Focused regression recommendations

1. **Completed emergency followed by both release calls.** Owned PTY with old bound ordinary color,
   active global paint, and historical pending sentinel. Recover and drain exact 104/110/111.
   Then call `broadcastPausedClear()` and `broadcast()`, await idle, assert no further bytes;
   intent remains and pending sentinel is absent. Repeat separately draining each method so the
   test covers both coalesced and non-coalesced execution.
2. **Delayed clear preserves a fresh ordinary render.** Block dequeue/native or device open using
   the existing semaphore fixtures, queue clear while active, complete independent recovery, then
   deliver a fresh ordinary render containing background, foreground/palette, title, and bell.
   Release queued clear and assert no extra bytes. No forced default reset may follow the hook.
3. **Suspended relaunch after successful recovery.** After old global/selective/focus records become
   inactive through recovery, run `discoverAndRegisterActiveAgentTTYs()`. Assert no repaint of old
   ordinary color and no palette/foreground reset, including when a fresh hook already ran.
4. **Residual cleanup before independent repaint.** Persist suspended marker without emergency
   output, leave active global or selective/focus effect, and run shared reconciliation or startup.
   Global yields defaults 104/110/111, background-only yields OSC 111, and neither reapplies old
   ordinary color. Preserve blocked-native startup cleanup coverage.
5. **New suspended preview remains valid.** After recovery, create a new preview in the current
   revision, then deliver delayed `broadcastPausedClear()`/`broadcast()`. Preserve live tint and
   do not emit 104/110. When that preview expires or is deliberately cleared, restore latest
   ordinary intent or default using only background bytes. Test stale pre-recovery preview
   separately so it cannot resurrect an old theme.
6. **Normal active-mode release still works.** Existing release tests should keep exact
   104/110 + latest ordinary background, preserve active focus, emit no old title/bell, and remove
   pending OSC. Keep active-mode canceled-global-failure relaunch behavior and explicit resume
   current-rule behavior. Add assertions rather than changing these contracts to fit the fix.

The most useful existing fixtures/tests are:

- `BroadcasterTests.swift:147-175`: ordinary clear/latest intent and startup prior-effect cleanup.
- `BroadcasterTests.swift:206-287`: cleanup before blocked native discovery, queued suspension,
  and coalescing/reset-flag retention.
- `SchedulerLockTests.swift:94-150`: suspension preserves lock/grant definitions and timers.
- `SchedulerTests.swift:380-465`: suspended/unavailable startup and transition routing.
- `visual-recovery-tests.swift:766-773`: stale explicit preview clear after recovery emits no bytes.
- `visual-recovery-tests.swift:812-877`: preview failure retry, expiry, and harmless suspended preview.
- `visual-recovery-tests.swift:1068-1102`: queued restriction rejection and ordinary intent retention.
- `visual-recovery-tests.swift:1462-1473`: active-mode canceled global failure cleanup.
- `visual-recovery-tests.swift:1531-1546`: explicit resume recomposes current rule across aliases.

## Summary

L4 is a confirmed recovery-contract defect. Scheduler-only suppression is incomplete; the smallest
shared correction is a disabled-reconciliation composition rule under the existing writer lock.
It should suppress duplicate ordinary/default output after completed emergency, clear still-active
residual restrictions to defaults, and retain legitimate ordinary hooks, harmless current previews,
and normal active pause/lock release.

No tests were run and no product files, settings, user processes, applications, or devices were
touched. This is source evidence, not live visual acceptance.

## Capture note for the root session

[O] Verified the requested Git baseline, traced SPEC through scheduler release, broadcaster
coalescing, shared writer composition, retained effect records, and connected PTY test source.
[O] Distinguished background theme reapplication from foreground/palette resets and identified
that inactive records are not completion receipts. [R] The smallest reliable repair is at shared
reconciliation because scheduler-only branching cannot cover queued or relaunch writes.
The root session should include this in its required meta-thinking capture; the delegated read-only
scope did not authorize editing the project's capture file.

## Memory orientation

A lightweight registry pass located prior TAVS restoration guidance about reset-only recovery and
live acceptance. Every conclusion above was reverified from current source. Registry reference:
`MEMORY.md:672-680`, rollout `01a100cb-205c-7840-8268-c3d4ab1f7849`.

## Source-only follow-up on the three-file recovery diff

- Main fix is correct for canceled records, retained ordinary intent, and fresh full renders.
  Coalesced or separately drained scheduler calls both reach the shared disabled guard.
- Residual active global plus current preview is handled: obsolete global gets canceled, then
  OSC 104/110 precedes the live preview background (visual-recovery.swift:346-355,403-407).
  The new preview test cancels global through recovery first, so it does not test that coexistence.
- Confirmed gap: unavailable marker is included in `restrictionsDisabled` (line 334), but the
  preview exemption at 343-344 only checks identity. In-place malformed regular-file contents
  retain identity while `read()` returns unavailable (visual-restrictions-state.swift:81-118).
  This preserves/repaints a preview despite the normal preview guard rejecting unavailable state
  (visual-recovery.swift:247). Require status suspended before granting the preview exemption.
  Nonregular/unreadable marker can also make identity matching throw before residual cleanup.
- Confirmed preview-clear gap: `!clear` at line 343 treats a current suspension preview as obsolete
  when startup uses `clearSelective:true`, returning OSC 111 instead of latest ordinary color.
  SPEC:184,208 requires launch/preview clear to restore current intent/default. Remove `!clear`
  from preview classification; prior cancellation at 313 and clearSelective still prevent tint
  retention. Add a current suspended preview plus ordinary-color clearSelective:true assertion.
- Canceled-global failed-emergency retry remains available: explicit emergencyReset ignores the
  active bit and resets cached targets; active-mode canceled-global reconciliation is unchanged.
  Disabled generic no-op cannot prove a prior failed reset succeeded, as the original report notes.
- Added delayed-render test delays native completion after recovery; it covers preservation but
  not enqueue-before-suspension/device-open interleaving. Shared guard location handles that by
  source inspection; no tests were run here. Ordinary active release/coalescing code is unchanged.
- The newly added unavailable-identity regression describes the first gap and awaits its source fix.
  Read-only investigation only; no product edits, tests, live processes, devices, or native calls.
