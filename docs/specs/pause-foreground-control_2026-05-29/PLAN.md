# Implementation Plan — Pause Foreground Control

**Spec:** /Users/cs/local/code/apps/terminal-agent-visual-signals/docs/specs/pause-foreground-control_2026-05-29/SPEC.md
**Created:** 2026-05-29
**Agent:** execute-spec (autonomous/Ralph Loop compatible)

---

## Prerequisites

- Work from project root:
  `/Users/cs/local/code/apps/terminal-agent-visual-signals`
- Swift toolchain compatible with `src/macos/TAVSApp/Package.swift`
  (`swift-tools-version: 6.0`, package uses Swift 5 language mode).
- Primary test command: `cd src/macos/TAVSApp && swift test`
- Shell regression checks may use targeted pytest/Bats tests already present
  under `tests/`, plus direct byte inspection with `rg`.
- Manual product validation requires Ghostty and the installed menu-bar app.

## Dependency Graph

```text
Phase 0
   |
Phase 1
   |
Phase 2
   |
Phase 3
   |
Phase 4
   |
Phase 5
```

**Critical path:** Phase 0 -> Phase 1 -> Phase 2 -> Phase 3 -> Phase 4 -> Phase 5

## Phase 0: Baseline and Safety Lock

### Implementation Steps

1. Run or attempt `cd src/macos/TAVSApp && swift test` and record the result in
   `docs/specs/pause-foreground-control_2026-05-29/PROGRESS.md`.
2. Inspect current pause coverage in:
   `src/macos/TAVSApp/Tests/TAVSAppTests/BroadcasterTests.swift`,
   `src/macos/TAVSApp/Tests/TAVSAppTests/SchedulerTests.swift`, and
   `src/macos/TAVSApp/Tests/TAVSAppTests/UserConfStoreTests.swift`.
3. Confirm shell active-state foreground logic remains out of scope by checking
   `src/core/trigger.sh` and `src/core/idle-worker-background.sh` for current
   foreground OSC behavior.
4. Record the no-OSC-0 pause/title regression boundary in `PROGRESS.md`.

### Files to Create/Modify

- `docs/specs/pause-foreground-control_2026-05-29/PROGRESS.md` — record baseline
  test status and implementation notes.

### Tests to Write

- No new tests in this phase. This phase runs and records the existing baseline.

### Verification

- [ ] `cd src/macos/TAVSApp && swift test`
- [ ] `rg -n "OSC 0|]0;|broadcastPaused|broadcastPausedClear" src/macos/TAVSApp/Tests/TAVSAppTests`
- [ ] `rg -n "]10|]110|OSC 10|OSC 110" src/core/trigger.sh src/core/idle-worker-background.sh`
- [ ] `git diff -- src/macos/TAVSApp src/core` shows no production behavior
  changes.

### Definition of Done

- [ ] Baseline Swift test result is recorded.
- [ ] Existing broadcaster, scheduler, and config test locations are recorded.
- [ ] No-title pause tests are identified as a regression boundary.
- [ ] No active-state shell foreground implementation is introduced.

## Phase 1: Pause Visual Model and Config Foundation

### Implementation Steps

1. Add `src/macos/TAVSApp/Sources/TAVSApp/PauseVisual.swift` with a sanitized
   `Equatable` value type containing `backgroundColor` and `foregroundColor`.
2. Implement strict `#RRGGBB` parsing, appearance-specific background defaults,
   and deterministic foreground fallback selection using WCAG 4.5:1 contrast.
3. Add `defaultPauseFgDark`, `defaultPauseFgLight`, `pauseFgDark`, and
   `pauseFgLight` to
   `src/macos/TAVSApp/Sources/TAVSApp/UserConfStore.swift`.
4. Change `UserConfStore` reads and writes so duplicate keys follow shell
   sourcing semantics: the last matching key is effective and changed saves
   replace the last matching key.
5. Update `src/config/user.conf.template` to document
   `TAVS_PAUSE_FG_DARK` and `TAVS_PAUSE_FG_LIGHT` beside pause backgrounds.

### Files to Create/Modify

- `src/macos/TAVSApp/Sources/TAVSApp/PauseVisual.swift` — pause visual contract,
  sanitization, contrast helpers, and fallback logic.
- `src/macos/TAVSApp/Sources/TAVSApp/UserConfStore.swift` — foreground keys,
  defaults, last-wins read/write semantics.
- `src/config/user.conf.template` — user-facing foreground key comments.
- `src/macos/TAVSApp/Tests/TAVSAppTests/UserConfStoreTests.swift` — foreground
  accessors, absent keys, duplicate last-wins, save preservation.
- `src/macos/TAVSApp/Tests/TAVSAppTests/PauseVisualTests.swift` — sanitization
  and fallback behavior.

### Tests to Write

- `src/macos/TAVSApp/Tests/TAVSAppTests/PauseVisualTests.swift` — valid color
  normalization, malformed background fallback, absent/malformed foreground
  contrast fallback, custom background fallback, and mixed valid/malformed
  inputs.
- `src/macos/TAVSApp/Tests/TAVSAppTests/UserConfStoreTests.swift` — pause
  foreground round-trip, absent foreground keys returning `nil`, duplicate-key
  last-wins reads, changed-key replacement of the last duplicate, and
  preservation of comments/blank lines/unknown content.

### Verification

- [ ] `cd src/macos/TAVSApp && swift test`
- [ ] `rg -n "TAVS_PAUSE_FG|pauseFg|PauseVisual" src/macos/TAVSApp src/config/user.conf.template`
- [ ] `rg -n "TAVS_PAUSE_FG" src/config/defaults.conf` returns no matches.

### Definition of Done

- [ ] `PauseVisual` stores only valid `#RRGGBB` strings.
- [ ] Missing foreground keys return `nil` from `UserConfStore`.
- [ ] Absent foreground values are not persisted automatically.
- [ ] Malformed foreground values derive readable fallbacks from the resolved
  background.
- [ ] Malformed background values use appearance-specific background defaults.
- [ ] Duplicate key reads use the last matching key.
- [ ] Saving changed pause keys preserves unrelated `user.conf` content.
- [ ] `user.conf.template` documents pause foreground keys.

## Phase 2: Broadcast Payload Contract

### Implementation Steps

1. Change `BroadcasterProtocol.broadcastPaused(backgroundColor:)` in
   `src/macos/TAVSApp/Sources/TAVSApp/Scheduler.swift` to accept
   `PauseVisual`.
2. Change `Broadcaster.broadcastPaused` in
   `src/macos/TAVSApp/Sources/TAVSApp/Broadcaster.swift` to serialize sanitized
   `PauseVisual` values without doing fallback selection.
3. Add OSC 10 foreground set to pause entry before OSC 11 background set.
4. Add OSC 110 foreground reset to pause clear before OSC 111 background reset.
5. Update `src/macos/TAVSApp/Tests/TAVSAppTests/Mocks/MockBroadcaster.swift`
   to capture the full `PauseVisual`.
6. Extend broadcaster tests for foreground set/reset, legacy OSC 104/1337
   preservation, multiple TTYs, stale TTY pruning, and no OSC 0 emission.

### Files to Create/Modify

- `src/macos/TAVSApp/Sources/TAVSApp/Broadcaster.swift` — pause entry and clear
  OSC payloads.
- `src/macos/TAVSApp/Sources/TAVSApp/Scheduler.swift` — protocol signature only
  in this phase.
- `src/macos/TAVSApp/Tests/TAVSAppTests/Mocks/MockBroadcaster.swift` — test
  double signature and captured visual.
- `src/macos/TAVSApp/Tests/TAVSAppTests/BroadcasterTests.swift` — byte-level
  payload contract tests.

### Tests to Write

- `BroadcasterTests.testBroadcastPausedWritesForegroundAndBackgroundBytes`
- `BroadcasterTests.testBroadcastPausedClearResetsForegroundAndBackground`
- `BroadcasterTests.testBroadcastPausedPreservesImageClear`
- Extend existing no-OSC-0 coverage to the `PauseVisual` method signature.
- Extend or keep multiple/stale TTY tests green with the changed pause method.

### Verification

- [ ] `cd src/macos/TAVSApp && swift test`
- [ ] `rg -n "]10;|]110|]11;|]111|]104|SetBackgroundImageFile" src/macos/TAVSApp/Tests/TAVSAppTests/BroadcasterTests.swift`
- [ ] `rg -n "sanitizeHexColor|defaultPauseBgDark" src/macos/TAVSApp/Sources/TAVSApp/Broadcaster.swift` confirms broadcaster no longer owns fallback decisions.

### Definition of Done

- [ ] Pause entry payload includes OSC 104, OSC 10, OSC 11, and OSC 1337 image
  clear.
- [ ] Pause clear payload includes OSC 104, OSC 110, and OSC 111.
- [ ] `Broadcaster` serializes `PauseVisual` and does not choose fallback colors.
- [ ] No pause broadcaster method emits OSC 0 or paused title text.
- [ ] Multiple TTY and stale/dead TTY behavior remains unchanged.

## Phase 3: Scheduler Integration and Repaint Behavior

### Implementation Steps

1. Replace `pauseColorProvider: () -> String` in
   `src/macos/TAVSApp/Sources/TAVSApp/Scheduler.swift` with
   `pauseVisualProvider: () -> PauseVisual`.
2. Replace `lastPaintedPauseColor` with `lastPaintedPauseVisual`.
3. Ensure active-to-muted, startup-into-muted, and muted steady-state repaint
   paths pass the full `PauseVisual` to the broadcaster.
4. Keep muted-to-active ordering as `broadcastPausedClear()` before
   `broadcast()`, then clear `lastPaintedPauseVisual`.
5. Replace `PauseColorResolver` in
   `src/macos/TAVSApp/Sources/TAVSApp/TAVSApp.swift` with a pause visual
   resolver that reads background and foreground keys and selects dark/light
   appearance without requiring tests to query `NSApplication.shared`.
6. Extend scheduler tests for foreground-only changes, background-only changes,
   unchanged visuals, appearance-driven visual changes, startup mute paint, and
   clear-before-replay ordering.

### Files to Create/Modify

- `src/macos/TAVSApp/Sources/TAVSApp/Scheduler.swift` — provider type,
  idempotence state, transition behavior.
- `src/macos/TAVSApp/Sources/TAVSApp/TAVSApp.swift` — default pause visual
  resolver wiring.
- `src/macos/TAVSApp/Tests/TAVSAppTests/SchedulerTests.swift` — transition and
  repaint tests.
- `src/macos/TAVSApp/Tests/TAVSAppTests/Mocks/MockBroadcaster.swift` — call
  order capture if needed for clear-before-replay assertions.

### Tests to Write

- `SchedulerLifecycleTests.testActiveToMutedPaintsPauseVisual`
- `SchedulerLifecycleTests.testForegroundOnlyChangeWhileMutedRepaints`
- `SchedulerLifecycleTests.testBackgroundOnlyChangeWhileMutedRepaints`
- `SchedulerLifecycleTests.testUnchangedPauseVisualIsIdempotent`
- `SchedulerLifecycleTests.testAppearanceDerivedVisualChangeRepaintsOnEvaluation`
- `SchedulerLifecycleTests.testMutedToActiveClearsBeforePendingReplay`
- Update startup-into-muted and schedule-unmute tests to assert full visual
  behavior.

### Verification

- [ ] `cd src/macos/TAVSApp && swift test`
- [ ] `rg -n "pauseColorProvider|lastPaintedPauseColor|broadcastPaused\\(backgroundColor" src/macos/TAVSApp` returns no matches.
- [ ] `rg -n "pauseVisualProvider|lastPaintedPauseVisual|broadcastPaused\\(visual" src/macos/TAVSApp` shows scheduler and tests use the new contract.

### Definition of Done

- [ ] All muted reasons use the same `PauseVisual` path.
- [ ] Active-to-muted writes one pause payload including foreground.
- [ ] Foreground-only and background-only changes repaint once while muted.
- [ ] Unchanged visuals do not repaint across reevaluations.
- [ ] Muted-to-active clears pause foreground/background before pending replay.
- [ ] Tests can force "next scheduler evaluation" without sleeping.

## Phase 4: Preferences, User Configuration, and Documentation

### Implementation Steps

1. Add dark/light foreground `ColorPicker` controls to the existing Paused State
   section in `src/macos/TAVSApp/Sources/TAVSApp/PreferencesView.swift`.
2. Load foreground picker values through the same `PauseVisual` fallback logic
   used by runtime paint.
3. Save foreground keys only when the user changes those controls; preserve
   malformed raw values on unrelated saves.
4. Update pause visual docs in `README.md`,
   `docs/reference/macos-menubar-app.md`, and `docs/reference/testing.md`.
5. Update relevant architecture/testing references for OSC 10/110, OSC 11/111,
   TrueColor limitations, OSC 104 legacy cleanup, OSC 1337 legacy image clear,
   and heartbeat-bounded repaint timing.
6. Remove stale `~2 seconds` pause repaint language from
   `docs/reference/macos-menubar-app.md`.

### Files to Create/Modify

- `src/macos/TAVSApp/Sources/TAVSApp/PreferencesView.swift` — foreground color
  pickers, fallback display, changed-key save behavior.
- `src/macos/TAVSApp/Tests/TAVSAppTests/UserConfStoreTests.swift` or a focused
  new Swift test file if a UI-adjacent seam is extracted.
- `README.md` — user-facing pause foreground and terminal limitation docs.
- `docs/reference/macos-menubar-app.md` — scheduler/menu-bar pause behavior and
  repaint timing.
- `docs/reference/testing.md` — Ghostty manual validation steps.
- `docs/reference/architecture.md` — OSC contract if current diagrams/tables
  mention only background.
- `docs/reference/palette-theming.md` — clarify pause foreground is not palette
  override if needed by existing wording.

### Tests to Write

- Focused Swift tests for any extracted preference color/fallback helper.
- `UserConfStoreTests` coverage that unchanged open/close-equivalent saves do
  not materialize default foreground keys.
- `UserConfStoreTests` coverage that unrelated saves preserve malformed raw
  pause foreground/background lines.

### Verification

- [ ] `cd src/macos/TAVSApp && swift test`
- [ ] `rg -n "TAVS_PAUSE_FG|OSC 10|OSC 110|default foreground|TrueColor|SetBackgroundImageFile|OSC 104" README.md docs/reference src/config/user.conf.template`
- [ ] Manual UI smoke check: open TAVS Preferences -> Appearance and confirm
  four Paused State color pickers render.

### Definition of Done

- [ ] Preferences renders dark/light pause background and foreground controls.
- [ ] Preferences persists changed foreground values to `user.conf`.
- [ ] Preferences displays malformed pause values using runtime fallback logic.
- [ ] Unchanged or unrelated saves preserve absent/malformed foreground keys.
- [ ] Docs describe OSC 10/110, OSC 11/111, TrueColor limitation, reset
  semantics, OSC 104 legacy cleanup, OSC 1337 legacy image clear, no title
  changes, and heartbeat-bounded repaint timing.

## Phase 5: Product Validation and Release Readiness

### Implementation Steps

1. Run `cd src/macos/TAVSApp && swift test`.
2. Run targeted shell regression checks proving shell-driven active states do
   not emit OSC 10/110.
3. Validate Ghostty manual pause and resume with default-colored and explicit
   TrueColor sample text.
4. Validate Preferences-driven foreground customization and inspect
   `~/.tavs/user.conf`.
5. Validate malformed foreground/background fallback and absent-foreground
   custom-background readability.
6. Record final automated and manual validation notes in `PROGRESS.md`.

### Files to Create/Modify

- `docs/specs/pause-foreground-control_2026-05-29/PROGRESS.md` — final
  validation notes and residual risk.

### Tests to Write

- No new tests expected. This phase validates the completed feature and records
  findings.

### Verification

- [ ] `cd src/macos/TAVSApp && swift test`
- [ ] `rg -n "]10|]110|OSC 10|OSC 110" src/core/trigger.sh src/core/idle-worker-background.sh` returns no active-state foreground emission.
- [ ] Ghostty manual pause changes default foreground and background.
- [ ] Ghostty manual resume resets default foreground and background.
- [ ] Scheduled quiet-period mute uses the same pause visual behavior as manual
  pause.
- [ ] Preferences customization affects the next muted paint.
- [ ] Malformed config does not leak raw values into OSC payloads.

### Definition of Done

- [ ] Automated tests pass or unrelated failures are documented.
- [ ] Manual Ghostty pause/resume behavior matches the SPEC.
- [ ] Preferences customization and malformed config scenarios are validated.
- [ ] Normal shell-driven active states still do not emit OSC 10/110.
- [ ] Accepted residual risks are recorded.

## Risk Areas

| Risk | Phase | Mitigation |
|------|-------|------------|
| `UserConfStore` duplicate-key change breaks byte preservation | 1 | Add tests for no-change save, changed last duplicate, comments, blanks, and unknown keys. |
| Contrast fallback math is subtly wrong | 1 | Test known dark, light, mid, and custom backgrounds against expected readable foregrounds. |
| Broadcaster starts owning fallback decisions again | 2 | Keep fallback in `PauseVisual`; verify no fallback constants remain in `Broadcaster`. |
| Clear/replay ordering regresses during scheduler refactor | 3 | Capture call order in `MockBroadcaster` and assert clear before replay. |
| Preferences saves materialize absent foreground keys | 4 | Preserve load/save semantics with tests for unchanged and unrelated saves. |
| Documentation over-promises recoloring explicit app output | 4 | Explicitly document terminal default foreground scope and TrueColor limitation. |
| Manual Ghostty validation depends on local app state | 5 | Record exact commands/menu actions and any blocker in `PROGRESS.md`. |

## Sequencing & Dependencies

| Phase | Depends On | Can Parallel With |
|-------|------------|-------------------|
| 0 | — | — |
| 1 | 0 | — |
| 2 | 1 | — |
| 3 | 2 | — |
| 4 | 3 | — |
| 5 | 4 | — |
