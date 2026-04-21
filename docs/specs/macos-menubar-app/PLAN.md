# Implementation Plan — TAVS macOS Menu Bar Companion App

**Spec:** /Users/cs/local/code/apps/terminal-agent-visual-signals/docs/specs/macos-menubar-app/SPEC.md
**Created:** 2026-04-20
**Agent:** execute-spec (autonomous/Ralph Loop compatible)

---

## Prerequisites

- `bats-core` not installed. **Must install before Phase 1 tests run:**
  `brew install bats-core` (Spec §10.1 mandates `tests/unit/*.bats` + `tests/integration/*.bats`)
- Swift 6.2.4 present (`swift --version` confirmed). Used from Phase 2 onward.
- Xcode CLT needed for Phase 6 codesign/bundle (`xcrun`, `codesign`, `plutil`, `security`).
  Verify: `xcode-select -p` (should return a path, not an error)
- **Operator-assisted phases:** T6.1 creates a keychain cert (interactive Keychain prompt);
  T6.7 reboot survival requires physical/VM reboot. Flag as manual steps.
- Golden-byte baseline (T1.9) must be captured **before** any Phase 1 code change.
  The plan below orders T1.9-baseline first, T1.9-diff last.
- Test commands by phase:
  - Phase 1: `bats tests/unit/ tests/integration/` + `bash tests/bench/hot-path.sh`
  - Phase 2–5: `swift test --package-path src/macos/TAVSApp` + `pytest tests/` (regression guard)
  - Phase 6: `bash tests/e2e/menubar-scheduling.sh`

---

## Dependency Graph

```
Phase 1 (pure shell) ──┐
                       ├──► Phase 3 ──► Phase 4 ──┐
Phase 2 (Swift scaffold)┘         └──► Phase 5 ───┴──► Phase 6
```

**Critical path:** Phase 1 → Phase 3 → Phase 4/5 (parallel) → Phase 6
**Parallelizable:** Phases 1 and 2 (no runtime coupling; independent artifacts)
**Serial:** Phase 3 needs both 1 and 2; Phase 6 needs all five prior phases

---

## Phase 1: Shell-Side Suppression Wrapper

**Goal:** Make shell pipeline mute-aware. Absent `mute.state` → byte-identical behavior.
Present + valid `mute.state` → OSC writes captured into pending cache. All bookkeeping runs.

**Test command:** `bats tests/unit/mute-gate.bats tests/integration/`

### Implementation Steps

**T1.9-baseline (FIRST — before any code change):**
1. Write `tests/bench/baseline-capture.sh` that records OSC bytes per state to
   `tests/bench/baseline-bytes/*.osc` and `tests/bench/baseline.txt` (timing median).
2. Run it: capture golden bytes for all 8 states (processing, permission, complete, idle,
   compacting, subagent-start, tool_error, reset).

**T1.1 — Runtime dir helper:**
3. Create `src/core/mute-gate.sh` with `_tavs_runtime_dir()`: resolves to `/tmp/tavs-$(id -u)`,
   creates with `mkdir -m 0700 -p` on first call, exports `TAVS_RUNTIME_DIR`.

**T1.2 — Stage-0 inline gate in `trigger.sh`:**
4. Insert the stage-0 block AFTER the `TAVS_STATUS` kill switch (line ~25) and BEFORE
   the first `source` statement (line ~34). Block uses bash builtins only to read
   `~/.tavs/mute.state` KV, run 4 liveness checks (MUTED, UNTIL_EPOCH, WRITTEN_EPOCH
   within 120s, kill -0 APP_PID), set `_TAVS_SUPPRESS_OUTPUT=0|1`. Never exits early.

**T1.3 — `emit_osc` wrapper:**
5. Add `emit_osc()` function to `terminal-osc-sequences.sh`. When `_TAVS_SUPPRESS_OUTPUT=1`,
   appends bytes to temp file `$_TAVS_PENDING_BUFFER`; otherwise writes to `$TTY_DEVICE`.
6. Refactor all 10 known direct `> $TTY_DEVICE` call sites to use `emit_osc`:
   - `src/core/terminal-osc-sequences.sh`: lines 37, 78, 80, 135, 141, 222
   - `src/core/title-management.sh`: lines 525, 571
   - `src/core/title-iterm2.sh`: lines 54, 263

**T1.4 — Pending cache lifecycle:**
7. In `mute-gate.sh`: on dispatch start (when suppressed), open temp file and set
   `_TAVS_PENDING_BUFFER`; on dispatch end, atomic-rename to
   `$TAVS_RUNTIME_DIR/pending/<tty_safe>.osc`. On crash/error, unlink temp.

**T1.5 — Active-TTY registry:**
8. In `mute-gate.sh`: `register_active_tty()` does unconditional `touch` on every
   invocation (muted or not) at `$TAVS_RUNTIME_DIR/active-ttys/<tty_safe>`.
   Expose `tavs debug clean-registry` that sweeps entries older than 24h.

**T1.6 — Idle worker mute:**
9. Edit `src/core/idle-worker-background.sh`: source `mute-gate.sh` on startup, re-read
   `mute.state` each tick (before `_idle_send_palette`/`printf >&3` calls), route
   existing palette + OSC sends through `emit_osc`. Worker continues ticking during mute.

**T1.7 — Replay debug subcommand:**
10. Add `trigger.sh replay <tty_safe>` subcommand: reads pending cache, writes bytes to
    `/dev/<tty_safe-unescaped>`, unlinks cache. Sets `_TAVS_REPLAY_BYPASS_MUTE=1` to prevent
    self-suppression. No-op if cache missing.

**T1.8 — Sync update:**
11. Edit `src/cli/cmd-sync.sh` `_sync_to_target()` to also copy `mute-gate.sh` when
    syncing `src/core/*.sh`. Run `./tavs sync` and verify both targets include it.

**T1.9-diff — Golden regression check:**
12. Re-capture OSC bytes for all 8 states with `mute.state` absent. Diff against baseline.
    Zero bytes of change = pass.

**T1.10 — Hot-path benchmark:**
13. Write `tests/bench/hot-path.sh`: 100 runs × 3 trials of `trigger.sh reset`, compute
    median. Record pre-change baseline in `tests/bench/baseline.txt`. Assert post-change
    median ≤ baseline + 5ms.

### Files to Create/Modify

- `src/core/mute-gate.sh` — NEW (C12): runtime dir, active-TTY registry, pending cache lifecycle
- `src/core/trigger.sh` — EDIT: stage-0 inline block + `source mute-gate.sh`
- `src/core/terminal-osc-sequences.sh` — EDIT: `emit_osc()` + 6 call site refactors
- `src/core/title-management.sh` — EDIT: 2 call site refactors
- `src/core/title-iterm2.sh` — EDIT: 2 call site refactors
- `src/core/idle-worker-background.sh` — EDIT (C13): mute-gate integration per tick
- `src/cli/cmd-sync.sh` — EDIT: include mute-gate.sh in sync list
- `tests/unit/mute-gate.bats` — NEW: unit tests for all mute-gate.sh functions
- `tests/integration/emit-osc.bats` — NEW: byte-diff each state muted vs unmuted
- `tests/integration/baseline-regression.bats` — NEW: OSC byte parity with absent mute.state
- `tests/bench/baseline-capture.sh` — NEW: golden byte capture
- `tests/bench/hot-path.sh` — NEW: timing regression guard

### Tests to Write

- `tests/unit/mute-gate.bats` — liveness check permutations (all 4 fail paths), runtime dir
  creation, register_active_tty, pending cache open/close/rename/unlink-on-crash
- `tests/integration/emit-osc.bats` — mock TTY (`/dev/pts` or temp file), verify byte-diff
  per state in both muted and unmuted modes
- `tests/integration/baseline-regression.bats` — diff vs golden bytes with absent mute.state

### Definition of Done

- [ ] `mute.state` absent → `diff` of OSC bytes shows 0 bytes change vs baseline
- [ ] `mute.state` present with valid liveness → `_TAVS_SUPPRESS_OUTPUT=1`, OSC bytes go to pending cache
- [ ] Pending cache file exists after muted dispatch; replay writes bytes to TTY
- [ ] Idle worker emits through `emit_osc`; pending cache grows during mute; resumes on unmute
- [ ] `bats tests/unit/mute-gate.bats` all pass
- [ ] `bats tests/integration/` all pass
- [ ] Hot-path benchmark: post-change median ≤ baseline + 5ms
- [ ] `grep -r '> \$TTY_DEVICE' src/core/ | grep -v emit_osc` returns empty
- [ ] End-of-phase demo from SPEC §7 Phase 1 passes (15 min)

---

## Phase 2: Swift Scaffold + Data Stores + Test Harness

**Goal:** Bootstrap Swift Package. All data models, file-watching abstractions,
test-injectable protocols. Runnable stub with empty menu. No runtime coupling to Phase 1.

**Depends on:** Phase 1 (can be built in parallel)
**Test command:** `swift test --package-path src/macos/TAVSApp`

### Implementation Steps

1. Create `src/macos/TAVSApp/Package.swift` targeting macOS 13+, SwiftUI + Foundation only.
2. Create `src/macos/TAVSApp/Sources/TAVSApp/TAVSApp.swift` with `@main`, `MenuBarExtra`
   showing SF Symbol icon + "Quit" menu item. Set `LSUIElement=true` in stub Info.plist.
3. Create `ScheduleStore.swift`: `Codable` models (`ScheduleConfig`, `TimeWindow`,
   `QuietPeriod`, `Day` enum, `QuietKind` enum), atomic load/save (temp+rename same dir),
   `validate()` enforcing all SPEC §5.2 rules.
4. Create `UserConfStore.swift`: line-oriented bash-KV parser preserving comments, blank
   lines, unknown keys. Typed accessors for 9 curated keys (SPEC §5.5). Atomic save.
5. Create `MuteState.swift`: KV format from SPEC §5.3, atomic writer.
6. Create test-injectable protocols in `Sources/TAVSApp/`:
   - `Clock.swift` → `protocol Clock`, `SystemClock`, `VirtualClock`
   - `TimerScheduler.swift` → `protocol TimerScheduler` + production impl
   - `ProcessRunner.swift` → `protocol ProcessRunner` + production impl
   - `FileWatcher.swift` (C10) → parent-dir watch + 100ms debounce
7. Create `Sources/TAVSApp/Mocks/` with test mocks for all 4 protocols.
8. Write unit tests:
   - `Tests/TAVSAppTests/ScheduleStoreTests.swift`
   - `Tests/TAVSAppTests/UserConfStoreTests.swift`
   - `Tests/TAVSAppTests/MuteStateTests.swift`
   - `Tests/TAVSAppTests/FileWatcherTests.swift`

### Files to Create/Modify

- `src/macos/TAVSApp/Package.swift` — NEW
- `src/macos/TAVSApp/Sources/TAVSApp/TAVSApp.swift` — NEW (C1)
- `src/macos/TAVSApp/Sources/TAVSApp/ScheduleStore.swift` — NEW (C4)
- `src/macos/TAVSApp/Sources/TAVSApp/UserConfStore.swift` — NEW (C5)
- `src/macos/TAVSApp/Sources/TAVSApp/MuteState.swift` — NEW (C6)
- `src/macos/TAVSApp/Sources/TAVSApp/MenuContent.swift` — NEW stub (C8)
- `src/macos/TAVSApp/Sources/TAVSApp/Clock.swift` — NEW (C10)
- `src/macos/TAVSApp/Sources/TAVSApp/TimerScheduler.swift` — NEW (C10)
- `src/macos/TAVSApp/Sources/TAVSApp/ProcessRunner.swift` — NEW (C10)
- `src/macos/TAVSApp/Sources/TAVSApp/FileWatcher.swift` — NEW (C10)
- `src/macos/TAVSApp/Sources/TAVSApp/Mocks/*.swift` — NEW (test mocks)
- `src/macos/TAVSApp/Tests/TAVSAppTests/*.swift` — NEW (~4 test files, ~20 tests)

### Tests to Write (SPEC §10.1 Swift)

- `ScheduleStoreTests`: parse canonical fixture, mutate, re-serialize; semantic equality.
  Every validation error case (empty list, invalid time, zero-length window, unknown day,
  out-of-range minute) produces a specific error.
- `UserConfStoreTests`: load fixture with comments + unknown keys, save unchanged, diff=0.
  Mutate one curated key, save, diff shows exactly that line changed.
- `MuteStateTests`: atomic write under concurrent reader — no partial reads.
- `FileWatcherTests`: real temp dir, 5 rapid renames, exactly 1 callback after debounce.

### Definition of Done

- [ ] `swift build --package-path src/macos/TAVSApp` zero warnings
- [ ] `swift test --package-path src/macos/TAVSApp` green (~20 tests)
- [ ] `swift run --package-path src/macos/TAVSApp` shows menu bar icon; "Quit" works
- [ ] `ScheduleStore` load/mutate/save/reload round-trip = semantically equal
- [ ] `UserConfStore` round-trip: comments + unknown keys preserved byte-for-byte
- [ ] Test coverage ≥ 80% for the four stores (SPEC §10.1)

---

## Phase 3: Scheduler + Broadcaster + Live State

**Goal:** App evaluates rules, projects mute state, detects transitions, broadcasts on
unmute. Menu shows live status. Configuration by hand-editing `schedule.json`.

**Depends on:** Phases 1 and 2
**Test command:** `swift test --package-path src/macos/TAVSApp` (30+ fixture matrix)

### Implementation Steps

1. Create `Scheduler.swift` with `computeMuteState(at:rules:) -> MuteState` (pure func).
   Handle: empty-window error, overlapping windows, overnight windows, wrapping minute
   ranges, fixed_daily quiet, master_active false, DST spring-forward/fall-back.
2. Implement `nextTransition(after:) -> Date` (used to size DispatchSourceTimer sleep).
3. Create `Tests/TAVSAppTests/Fixtures/scheduler-matrix.json` with 30+ triples
   (input_rules, input_time, expected_output). Includes DST cases, overnight, wrapping.
4. Write `SchedulerTests.swift` feeding the fixture matrix via `VirtualClock`.
5. Create `Broadcaster.swift`: enumerate `$TAVS_RUNTIME_DIR/active-ttys/`, filter mtime
   ≤ 24h, parallel read each `pending/<tty_safe>.osc` + write to TTY device; prune on error.
6. Write `BroadcasterTests.swift` with `MockProcessRunner` + fake FS.
7. Wire `Scheduler` into app lifecycle in `TAVSApp.swift`: load `schedule.json`, project
   initial `mute.state`, start first transition timer, start 60s heartbeat.
8. Implement `FileWatcher` on `~/.tavs/` (parent dir of `schedule.json`).
9. Implement `NSWorkspace.didWakeNotification` handler: re-evaluate on system wake.
10. Update `MenuContent.swift`: live state string ("Active — next mute in 23 min" etc.)
    bound to `Scheduler`'s `@Published` state.

### Files to Create/Modify

- `src/macos/TAVSApp/Sources/TAVSApp/Scheduler.swift` — NEW (C2)
- `src/macos/TAVSApp/Sources/TAVSApp/Broadcaster.swift` — NEW (C3)
- `src/macos/TAVSApp/Sources/TAVSApp/LoginItemManager.swift` — NEW (C9)
- `src/macos/TAVSApp/Sources/TAVSApp/TAVSApp.swift` — EDIT: wire scheduler + broadcaster
- `src/macos/TAVSApp/Sources/TAVSApp/MenuContent.swift` — EDIT: live state
- `src/macos/TAVSApp/Tests/TAVSAppTests/SchedulerTests.swift` — NEW
- `src/macos/TAVSApp/Tests/TAVSAppTests/BroadcasterTests.swift` — NEW
- `src/macos/TAVSApp/Tests/TAVSAppTests/Fixtures/scheduler-matrix.json` — NEW (30+ triples)

### Tests to Write

- `SchedulerTests`: 30+ fixture matrix via `VirtualClock`; DST spring-forward; DST fall-back;
  overnight windows; wrapping minutes; empty window rejection; `master_active: false`.
- `BroadcasterTests`: MockProcessRunner + fake FS; pruning on write failure; parallel writes.
- `LoginItemManagerTests`: mocked `SMAppService`.

### Definition of Done

- [ ] Scheduler matrix fixture passes (30+ test cases, no flaky wall-clock tests)
- [ ] `mute.state` projects on launch; heartbeat advances WRITTEN_EPOCH every 60s
- [ ] Two real terminals with pending files: broadcaster writes to both on unmute
- [ ] 30-second quiet period end-to-end: terminal goes dark, snaps back 30s later
- [ ] `schedule.json` edit → `mute.state` re-projects within ~200ms (fs-watch)
- [ ] System wake → broadcaster fires within ~1s of wake (if boundary was crossed)
- [ ] Menu label updates in real time as boundaries cross

---

## Phase 4: `tavs schedule` CLI

**Goal:** Command-line editing of `schedule.json`. Power-user and scripting contract.
App reacts to CLI edits via fs-watch from Phase 3.

**Depends on:** Phases 2 (schema) and 3 (fs-watch)
**Test command:** `bats tests/integration/schedule-evaluator-parity.bats`

### Implementation Steps

1. Create `src/cli/cmd-schedule.sh` with dispatcher for all 9 subcommands:
   `show`, `pause`, `resume`, `add-window`, `add-quiet` (hourly + fixed_daily),
   `remove <id>`, `validate`, `list`. Atomic writes (mktemp + mv in `~/.tavs/`).
2. Implement inline `jq`-based validation (same rules as Swift, SPEC §5.2).
   Important: `jq` allowed only here (user-invoked, not hot path — D10).
3. Register `schedule` subcommand in `src/cli/cmd-schedule.sh` and the `tavs` dispatcher.
4. Write `tests/integration/schedule-evaluator-parity.bats`: N malformed + N valid JSONs,
   feed to both CLI validator and Swift validator (`TAVSApp --validate-config` flag);
   outputs must agree in pass/fail.
5. Create `docs/reference/scheduling.md`: full schema, wrapping/overnight/DST semantics,
   CLI subcommand examples.

### Files to Create/Modify

- `src/cli/cmd-schedule.sh` — NEW (C15)
- `tavs` (dispatcher) — EDIT: register `schedule` subcommand
- `tests/integration/schedule-evaluator-parity.bats` — NEW
- `docs/reference/scheduling.md` — NEW

### Tests to Write

- `schedule-evaluator-parity.bats`: CLI validator vs Swift validator contract test (SPEC §T4.2)
- Atomic write test: concurrent `tavs schedule add-window` from two shells (no torn writes)

### Definition of Done

- [ ] All 9 subcommands work end-to-end
- [ ] Parity contract test passes: CLI and Swift agree on all N test cases
- [ ] Atomic write: concurrent calls leave file always valid JSON
- [ ] `tavs schedule pause` → icon goes to Paused state within 1s (fs-watch)
- [ ] Validation error for `--start 25:00` → clear error message, exit 1

---

## Phase 5: Preferences UI (Schedule, Appearance, Identity Tabs)

**Goal:** Mac-native three-tab preferences window. User never touches dotfiles for
common adjustments.

**Depends on:** Phases 2 (stores) and 3 (scheduler reacts)
**Test command:** `swift test --package-path src/macos/TAVSApp`

### Implementation Steps

1. Create `PreferencesView.swift` with `TabView` (Schedule, Appearance, Identity tabs).
   Window: resizable, last-active-tab persisted, ⌘W closes.
2. **Schedule tab:** "Master active" toggle, "Allowed Windows" list editor with inline
   editing + "Add window" button, "Quiet Periods" list editor + "Add quiet period" button.
   Live status line at bottom. Inline validation (Save button disabled when invalid).
3. **Appearance tab:** Theme dropdown (9 presets), Title Mode picker (4 options), Face
   Mode picker, Compact Theme picker (conditional on compact), Stylish Backgrounds toggle,
   Light/Dark Switching toggle. Two-way binding to `UserConfStore`.
4. **Identity tab:** Identity Mode picker (dual/single/off), Dir Icon Type picker (enabled
   only in dual mode). Disabled state encoding.
5. Inline validation: error messages adjacent to offending field; Save disabled on invalid.
6. Wire prefs window open/close to menu bar "Open Preferences…" action.

### Files to Create/Modify

- `src/macos/TAVSApp/Sources/TAVSApp/PreferencesView.swift` — NEW (C7)
- `src/macos/TAVSApp/Sources/TAVSApp/TAVSApp.swift` — EDIT: open prefs window action
- `src/macos/TAVSApp/Sources/TAVSApp/MenuContent.swift` — EDIT: "Open Preferences…" item

### Tests to Write

- `UserConfStoreTests` additions: theme change round-trip; no-change round-trip preserves
  comments and unknown keys byte-for-byte (DoD regression guard).

### Definition of Done

- [ ] Three tabs open/navigate/close; last-active tab preserved
- [ ] Schedule tab: add window ending in 2 min → terminal goes silent at boundary
- [ ] Appearance tab: change theme to Nord → next prompt paints Nord colors
- [ ] Appearance tab: close without changes → `diff user.conf` = 0 bytes
- [ ] Identity tab: switch to single mode → next prompt title shows animal only
- [ ] Inline validation: last window deleted + master_active → Save disabled
- [ ] `diff user.conf` after 5-control change → exactly 5 lines changed, comments intact

---

## Phase 6: Bundle, Codesign, Install, Docs, End-to-End

**Goal:** Ship-ready `.app` bundle with login-item auto-start. `./tavs install macos-app`
goes from repo to persistent menu bar icon in one command.

**Depends on:** Phases 1–5
**Test command:** `bash tests/e2e/menubar-scheduling.sh` (automated) + 15-step manual demo

### Implementation Steps

1. Create `src/cli/cmd-install-macos-app.sh` (C16): `swift build -c release`, assemble
   `.app/Contents/` (Info.plist with all required keys, MacOS/TAVSApp, Resources/AppIcon.icns),
   create self-signed cert `TAVS-Local-Signing` via `security` CLI (one-time, user consents),
   codesign with `--force --deep` (ad-hoc fallback), `plutil -lint` + `codesign -vv`,
   `cp -R` to `/Applications/TAVS.app`, launch to register `SMAppService.mainApp`.
2. Create `src/cli/cmd-uninstall-macos-app.sh`: unregister login item, `rm -rf
   /Applications/TAVS.app`, preserve `~/.tavs/` entirely.
3. Produce `AppIcon.icns` via `sips` pipeline or minimal Swift helper (rasterize SF Symbol
   to 4 standard sizes).
4. Write `tests/e2e/menubar-scheduling.sh` (SPEC T6.6): install → configure → mock TTY
   → cross mute boundary → assert OSC silence → cross unmute boundary → assert bytes
   arrive within 500ms → uninstall.
5. Create `docs/reference/macos-menubar-app.md` (comprehensive user reference).
6. Update README with "macOS Menu Bar App" section (5-line quick start).
7. Update `CLAUDE.md` with "macOS App" subsection (arch + new paths).
8. Register `install macos-app` and `uninstall macos-app` subcommands in `tavs` dispatcher.

### Files to Create/Modify

- `src/cli/cmd-install-macos-app.sh` — NEW (C16)
- `src/cli/cmd-uninstall-macos-app.sh` — NEW
- `src/macos/TAVSApp/Resources/AppIcon.icns` — NEW (or generate step in installer)
- `src/macos/TAVSApp/Sources/TAVSApp/Info.plist` — NEW
- `tests/e2e/menubar-scheduling.sh` — NEW
- `docs/reference/macos-menubar-app.md` — NEW
- `README.md` — EDIT: macOS Menu Bar App section
- `CLAUDE.md` — EDIT: macOS App subsection
- `tavs` dispatcher — EDIT: register install/uninstall macos-app subcommands

### Tests to Write

- `tests/e2e/menubar-scheduling.sh`: automated mute/unmute cycle + install/uninstall
- T6.7 (manual): reboot VM, stopwatch from login to icon visible (≤5s)

### Definition of Done

- [ ] `codesign -dvv /Applications/TAVS.app` reports `TAVS-Local-Signing` identity
- [ ] `SMAppService` status `.enabled` post-install
- [ ] `tests/e2e/menubar-scheduling.sh` exits 0
- [ ] `./tavs uninstall macos-app` removes app, preserves `~/.tavs/schedule.json`
- [ ] README quick-start on clean VM succeeds
- [ ] SPEC Phase 6 15-step canonical demo passes on clean macOS 13 VM

---

## Risk Areas

| Risk | Phase | Mitigation |
|------|-------|------------|
| bats-core not installed | 1 | `brew install bats-core` as first step |
| Keychain prompt for cert creation | 6 | Document as operator-assisted; ad-hoc fallback |
| `SMAppService` needs stable cert identity across rebuilds | 6 | Self-signed cert with fixed subject (TN3127) |
| Idle worker OSC writes use `>&3` (fd, not `$TTY_DEVICE`) | 1 | `emit_osc` must handle fd-3 path; verify separately |
| `kill -0 APP_PID` unreliable if PID recycled | 1 | Combined with WRITTEN_EPOCH check (D23 defense-in-depth) |
| DST spring-forward: boundary at 02:30 never fires | 3 | Document in scheduling.md; tested in SchedulerTests |
| Atomic rename defeats fs-watch on file itself | 3 | Parent-dir watch pattern (D28) |
| Broadcaster cross-session write briefly paints wrong session | 6 | Accepted risk (SPEC §12) |
| Swift LOC budget <1000 (excluding tests) | 2–5 | Track with `wc -l` in divergence check |
| Linux regression from shell changes | 1 | T1.9 golden-byte test + SPEC S7 baseline |

---

## Sequencing & Dependencies

| Phase | Depends On | Can Run Parallel With |
|-------|-----------|----------------------|
| 1     | —         | Phase 2              |
| 2     | —         | Phase 1              |
| 3     | 1 + 2     | —                    |
| 4     | 2 + 3     | Phase 5              |
| 5     | 2 + 3     | Phase 4              |
| 6     | 1 + 2 + 3 + 4 + 5 | —           |
