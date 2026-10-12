# Phase 9 integration contract

Last Updated: 2026-10-13
Version: 1.0
Source checkpoint: `d96cc9d` (`docs: Record manual focus verification`).

Read-only exploration. No source edits, builds, test execution, native/Ghostty/device/UI
commands, installs, or real-home actions were performed.

## Recommended reuse

Add the planned deterministic `attention-state.swift` reducer and extend the existing
`FocusController` to Automatic. Reuse its current focus render run, queue, heartbeat/rollover,
exact-ID cleanup, pinned recovery revision and `.focus(TerminalFocusRequest)` writer.
Automatic changes the source of the emphasized IDs; it does not need another render service.

| Choice | Consequence |
|---|---|
| Reuse current focus run (recommended) | Existing recovery, preview precedence, global-rule composition and stale-ID protections serve both modes; a small mode-specific decision supplies emphasized IDs |
| Separate automatic render service | Duplicates ownership, queue cancellation, revision pinning and cleanup, and can create competing writers; no current requirement needs that separation |

The reducer owns occurrence meaning and acknowledgement. The controller owns mode and
rendering. Sessions already supplies validated rows, priorities, correlated coverage and
verified navigation completions, so use those inputs instead of rereading arbitrary hook data
or deriving cues from ordinary background colors.

## Binding requirements from SPEC/PLAN

- `PLAN.md:447-456`: baseline on explicit enable, supported correlated High triggers, permission
  companion coalescing, all High emphasized while any cue remains, exact navigation snapshots,
  exclusive modes and polling while Automatic is armed.
- `SPEC.md:134-150`: observation/producer correlation, supported IDs, one permission episode,
  distinct completion deliveries, and ambiguous repeats remaining ineligible.
- `SPEC.md:151-152,439-455`: acknowledgement snapshots, no stale enable replay, resolution,
  priority downgrade, synthetic-idle independence, completion-only limits and mode switching.
- `SPEC.md:89-96,116-119,244-247`: non-Off polling, no new effects from unavailable catalogue,
  Off after launch/resumption, and suspension taking precedence.

## Minimum seams

Recommended additions, with signatures adapted to the reducer's actual types:

```swift
enum FocusMode { case off, manual, automatic }

func enableAutomatic(rows: [GhosttySurface],
                     priorities: [GhosttySurfaceID: SurfacePriority],
                     coverage: [GhosttySurfaceID: TerminalVisualCoverage])

func acceptCatalogue(_ rows: [GhosttySurface],
                     priorities: [GhosttySurfaceID: SurfacePriority],
                     coverage: [GhosttySurfaceID: TerminalVisualCoverage])

func cueSnapshot(for surface: GhosttySurfaceID) -> Set<AttentionOccurrenceID>
func acknowledge(_ ids: Set<AttentionOccurrenceID>, for surface: GhosttySurfaceID)
```

Keep `focusSelected`, `focusOff`, `catalogueUnavailable` and `cancelForRecovery` as the
existing explicit lifecycle boundaries. Add only the reducer state and published cue/status
data required by the UI. No persisted automatic mode or cue file is needed by this spec.

`enableAutomatic` must first invalidate/clear Manual rendering, baseline the current accepted
observations, capture the existing recovery revision, then publish `.automatic`. A successful
enable with no cues is armed, with no dimming. Do not activate from current cached completion.
Focus Selected explicitly switches Automatic to Manual and discards automatic arming/cues.
Focus Off and recovery disarm everything; restart constructors remain Off.

## Rendering and the armed/active distinction

When the reducer has at least one eligible unacknowledged High cue, derive emphasized IDs
from **all current High rows**, including High rows without observations/cues. Dim Normal/Low
through the existing `.focus` path. Emphasizing only the cue-bearing rows violates the spec.
Existing current-binding checks still require at least one verified emphasized surface before
dimming outside rows (`focus-controller.swift:185-186`). An eligible cue already requires a
verified destination, but do not weaken that writer/controller guard.

At zero cues, retire the current dimming run and clear its exact focus ID while leaving
`mode == .automatic`, reducer history/acknowledgements and arming revision intact. Do not call
public `focusOff()` as the zero-cue transition: it currently clears mode and captured state
(`focus-controller.swift:165-170`). Reusing the same effect ID after cancellation also fails
the store's inactive same-ID guard (`terminal-visual-state.swift:213-220`). A later new cue
therefore needs a fresh render Run, using the same valid arming revision.

The smallest implementation can retain an empty current Run while armed, allocate a fresh
Run whenever prior dimming is retired, and reuse current queue/coalescing/cleanup code. It
does not need separate services for armed and active modes. Keep preview's two-second timer
independent; preview Clear/expiry must not disarm Automatic or acknowledge attention.

Automatic High membership can change while cues remain. Retire/recompose the old outside
effects when a Normal row is promoted to High, so its prior dimming is actually cleared.
The current manual membership cannot grow except explicit recapture, so its refresh code
does not presently remove an old affected target just because it joins the emphasized set.
Do not merely replace `workingSet` and paint the new outside set; that leaves the promoted
High row's previous focus record active. Reuse exact-ID cleanup/new Run for membership changes
instead of adding a second ownership path.

## Exact Sessions/controller callers

- `SessionsModel.selection.didSet`, `sessions-model.swift:11-15`: remain preview-only.
  Browsing does not enable Automatic, modify its High set or acknowledge cues.
- `setPriority`, `:105-123`: after a successful committed save, feed current priorities and
  accepted coverage into the reducer/controller immediately. Downgrade removes cue eligibility;
  restoring High must not replay a delivery already seen while Normal/Low.
- `acceptCatalogue`, `:213-223`: provide rows, actual effective priorities and fresh coverage
  together. It already publishes coverage before calling the controller. Do not feed a prior
  tick's coverage to new rows or use status prose as correlation authority.
- `markCoverageStale`, `:226-233`: keep Automatic armed; invalidate queued rendering and expose
  unavailable coverage. Preserve occurrence/acknowledgement history so failed polling does not
  manufacture a new occurrence on recovery. A successful later invalid binding can remove
  eligibility; failure alone is not proof of exit.
- `updatePolling`, `:136-141`: already uses `isOpen || mode != .off`. Adding `.automatic` keeps
  its one catalogue timer alive even with zero cues and the window closed. Keep the existing
  `$mode` subscription (`:83`) and timer-owner isolation.
- `restoreVisibility`, `:153-165`, and controller `cancelForRecovery`,
  `focus-controller.swift:114-122`: invalidate Automatic/reducer state before helper launch.
  This remains true for partial/missing helper failure and explicit resume.
- Existing `canFocusSelected`, `sessions-model.swift:51-54`: add an analogous enable guard for
  Automatic requiring a usable accepted catalogue, active restrictions and no recovery.

The current focus render code at `focus-controller.swift:173-231` already coalesces updates,
checks current request versions at device preparation, caches colors per run, and updates its
common heartbeat only when all outside rows map and no target fails (`:207-209`). Preserve
those protections when broadening the mode-specific policy.

## Navigation acknowledgement

At `SessionsModel.goTo`, `sessions-model.swift:236-244`:

1. Snapshot that target's current cue identities before setting up or dispatching navigation.
2. Keep that immutable set in the existing completion closure.
3. On verified `.success`, acknowledge only those identities on that native surface and
   recompose current automatic state. A newer cue on that surface survives.
4. On `.failure`, acknowledge nothing and retain current failure feedback.

`GhosttyCatalog.goTo`, `ghostty-catalog.swift:105-126`, already verifies application generation,
native terminal/TTY mapping and `focused == true`. No new navigation service or retry is needed.
A timed-out action remains unacknowledged because success was not verified.

Occurrence identities must distinguish supported response/turn IDs from actual delivery IDs,
and stay scoped to producer generation/native lifetime. A completion arriving while navigation
is pending must not be cleared by reading the current record at callback time. Go To on a
High row with no cue acknowledges an empty snapshot and leaves other rows' cues active.

## Existing observation contract and limits

`TerminalVisualStateStore.coverage`, `terminal-visual-state.swift:696-747`, returns an observation
only after adoption/correlation against a fresh row. Retained adopted deliveries can remain
valid while backgrounded, but their producer generation/device is still checked
(`:760-790`). Tests explicitly allow such retained deliveries
(`terminal-visual-state-tests.swift:118-147`). Do not reject them by age or by the phrase
"Last-known agent observation" in status text.

The existing `attentionEligible` flag is a trigger eligibility convenience, not occurrence
history (`terminal-visual-state.swift:799-805`). Correlated processing/reset observations can
resolve a cue while that flag is false; ordinary intent cannot. Codex needs its supported
`agent-turn-complete` plus response ID for eligibility. Claude permission companions use
`PermissionRequest` and `permission_prompt` intake events
(`organizer-intake.swift:61-66`). Actual intake generates one delivery ID (`:88-91`), while
synthetic background paths retain it instead of creating meaningful observations.

Baseline permission episodes too: an old PermissionRequest present at enable must not turn
into a new cue when its later companion notification arrives. Track seen occurrences even
when they are Normal/Low, acknowledged, or temporarily ineligible; otherwise a priority
promotion or repeated poll can replay them.

Do not let an old record that was absent/uncorrelated at enable become a new cue merely when
it is adopted later. Preserve the enable boundary and baseline newly usable old observations
using the actual observation metadata. No body hash or guessed provider request ID is needed.

The store keeps one latest meaningful observation per TTY. Intermediate deliveries or
resumption signals overwritten between polling reads may not be observable. The reducer must
remain conservative about episode transitions it cannot prove and report supported coverage
honestly. This phase does not authorize a new event-history service or additional hooks.

## Failure paths to preserve

- Configuration/mapping failures: retain armed mode and cue state with unavailable rendering
  feedback; do not infer task success, approval, resumption or cue acknowledgement.
- Global pause/lock: current global visual wins; retain Automatic/cues and recompose after
  release through the existing focus records. A masked cue remains unacknowledged.
- Missing/invalid/known-exited producer or native lifetime on a fresh read: remove eligibility
  for that occurrence; never retarget it onto a reused TTY or replacement producer.
- Catalogue timeout/empty response: keep armed polling and stale feedback; no new effect from
  cached rows. Existing records stay recoverable and cannot be claimed visually restored by age.
- Marker replacement, including recover then resume ending active: existing revision checks
  invalidate the armed mode. Do not rebind an old arming revision to resume it.
- Zero cues, downgrade or successful acknowledgement: release dimming via exact-ID cleanup;
  failed cleanup remains retryable without blocking healthy targets or losing the pinned revision.

## Focused verification additions

Reuse current injected timers, clock, PTYs and navigation closures. Add:

1. Enable with old completion/permission; remain Automatic armed with zero cues and one closed-
   window polling timer. A later companion of the baselined permission does not activate.
2. A new High cue activates; all High rows stay emphasized, including a High plain shell.
   New Normal/Low rows stay outside; unknown/uncorrelated rows never trigger.
3. Multiple cues coexist; acknowledge one and preserve another. Zero cues clears dimming while
   mode remains Automatic; a later fresh cue uses a new render ID.
4. Promote an already dimmed row to High during another row's cue; its old dim record clears.
   Downgrade a cue-bearing row, then restore High; the old occurrence does not replay.
5. Go To captures cue A, cue B arrives during the held callback, then verified success only
   acknowledges A. Failure/timeout acknowledges neither. Navigation never occurs automatically.
6. Priority/rendering/preview/global-pause changes do not acknowledge attention. Synthetic idle
   leaves an unacknowledged completion active. Supported processing/reset/known exit resolves it.
7. Manual/Automatic switches are exclusive; Focus Off, recovery failure/resume and restart leave
   Off. Failed/empty catalogue leaves Automatic armed without creating new paint.

Existing tests to extend: `sessions-model-tests.swift:56-99,178-272` for deliberate navigation,
catalogue failure and correlated coverage; `terminal-visual-state-tests.swift:118-162,314-345`
for adoption, generation reuse, supported response IDs and trigger associations;
`focus-controller-tests.swift` for coalescing, expired ownership, preview precedence and recovery;
`tests/integration/hook-observations.bats` for real allowlisted metadata and delivery identity.

No tests or live automatic-focus acceptance were performed. Primary integration risks are
conflating armed with active, acknowledging current instead of captured cues, and leaving
former outside effects on a newly emphasized High surface.
