# Implementation Plan — Fizzy-Pebble Closeout

**Spec:** /Users/cs/.claude/plans/take-a-deep-breath-fizzy-pebble.md
**Created:** 2026-04-27
**Agent:** execute-spec (manual mode)

> Prior plan/progress for `can-we-actually-make-functional-gray.md` archived to
> `docs/_archive/2026-04-27_can-we-actually-make-functional-gray/` per the
> execute-spec pre-step protocol (different spec, must not co-mingle).

---

## Prerequisites

- macOS 13+ with Swift 6.0 toolchain
- TAVS.app installed at `/Applications/TAVS.app`
- Test commands:
  - `swift test --package-path src/macos/TAVSApp`
  - `bats tests/unit/ tests/integration/`

## Phase Map (mirrors fizzy-pebble spec §3)

```
Phase 0 (baseline) ─→ Phase 1 (menu wiring) ─→ Phase 2 (paused-visual)
                                                       │
                                                       ▼
                                       Phase 3 (schedule restore) ─→ Phase 4 (acceptance)
```

## Scope Fence

| File / path | Phase | Change |
|---|---|---|
| `src/macos/TAVSApp/Sources/TAVSApp/MenuContent.swift` | 1 | Wire Open Preferences + add Edit Schedule |
| `src/macos/TAVSApp/Sources/TAVSApp/Broadcaster.swift` | 2 | Drop OSC 0 emission in `broadcastPaused` |
| `src/macos/TAVSApp/Tests/TAVSAppTests/BroadcasterTests.swift` | 2 | Update paused-bytes assertion + no-OSC-0 test |
| `docs/reference/macos-menubar-app.md` | 2 | Refresh Paused Visual Behaviour section |
| `~/.tavs/schedule.json` | 3 | Recreate via `tavs schedule` CLI (not in git) |
| `PLAN.md`, `PROGRESS.md` | meta | Re-baselined for this spec (Step 0) |

Out of scope: shell trigger.sh, mute-gate.sh, defaults.conf — fizzy-pebble §1.3.

---

## Phase 0 — Preparation & baseline (no code changes)

**Status:** DONE (prior session, 2026-04-21 22:03)
**Verification:** baseline tests captured (Swift 105/105, bats 59/59 at the time); `/tmp/schedule.json.bak` was intact when first captured but later lost to a machine reboot before Phase 3 could consume it.

## Phase 1 — Menu-bar ↔ Preferences wiring

**Status:** DONE — commit `19e75ac feat(macos): Wire Preferences menu buttons and add Edit Schedule shortcut`
**Result:** "Open Preferences…" and "Edit Schedule…" menu items both open the SwiftUI settings window; "Edit Schedule…" pre-seeds `tavs_prefs_tab=0` so it always lands on the Schedule tab. macOS-13 selector fallback in place.

## Phase 2 — Paused-visual simplification

**Status:** DONE — commit `264a898 fix(broadcaster): Drop paused-title emission so resume is instant`
**Bonus follow-on:** commit `df164af feat(macos): Configurable paused background per macOS appearance` adds light/dark configurable pause background.
**Result:** `broadcastPaused()` no longer emits OSC 0 (the paused title), so there is no title state for resume to restore — "instantly back" holds by construction. Updated tests + reference docs accompany the change.

## Phase 3 — Recreate the original schedule

**Status:** DONE (this session, 2026-04-27)
**No commit** — `~/.tavs/schedule.json` is gitignored user data.
**Background:** Backup `/tmp/schedule.json.bak` was lost to a reboot. Exhaustive search this session confirmed no copy exists in `/Volumes/external/data/archive`, `~/.Trash`, or Time Machine. User confirmed the recreate-via-CLI path; values per archived PROGRESS.md.

### Implementation Steps

1. `./tavs schedule add-window --days mon,tue,wed,thu,fri --start 08:00 --end 20:00 --id weekdays`
2. `./tavs schedule add-quiet --kind fixed_daily --start 12:00 --end 13:00 --id lunch`
3. `./tavs schedule remove test-all-day`
4. `./tavs schedule pause`
5. `./tavs schedule show` to confirm

### Verification

- `~/.tavs/schedule.json` contains exactly: weekdays Mon–Fri 08:00–20:00 + lunch fixed_daily 12:00–13:00 + `master_active: false` + `version: 1`
- `~/.tavs/mute.state` reads `MUTED="true"`, `REASON="master_paused"` within ~2 s
- `./tavs schedule show` prints "Master: paused" with the two configured rules

### Definition of Done

- [x] schedule.json matches documented original structure
- [x] mute.state reflects paused via FileWatcher
- [x] Menu/CLI both report paused state

## Phase 4 — Acceptance & cross-feature regression

**Status:** Partially DONE — automated checks (T4.1, T4.6) PASS this session; visual UI checks (T4.2–T4.5) are user-gated.
**No commit** — acceptance only.

### Automated (DONE)

| Task | Result |
|---|---|
| T4.1 — Run `swift test` and `bats` | ✅ Swift 108/108, bats 59/59 (no regressions) |
| T4.6 — `pkill TAVSApp && open /Applications/TAVS.app` | ✅ Killed PID 13761 → relaunched as PID 82230 → mute.state correctly re-derived (`MUTED="true"`, `REASON="master_paused"`) |

### User-gated visual checks (next steps)

| Task | Action | Pass criterion |
|---|---|---|
| T4.2 | Click menu-bar icon | Icon = `pause.circle.fill` (since paused). Status text reads "Paused — click to resume" or similar. |
| T4.3 | Menu → "Open Preferences…" then "Edit Schedule…" | Both open the window. Edit Schedule lands on Schedule tab. Make a trivial Schedule edit + Save → `cat ~/.tavs/schedule.json` shows it. |
| T4.4 | Revert the trivial edit | schedule.json matches Phase 3 baseline again. |
| T4.5 | Resume → click "Pause TAVS" → click "Resume TAVS" | Grey appears on registered live terminals within ~2 s; clears within ~2 s; **tab titles unchanged throughout** (Phase 2 acceptance). |

### Definition of Done

- [x] T4.1 test suites green
- [x] T4.6 kill+relaunch survives correctly
- [ ] T4.2 visual icon matches state — user-gated
- [ ] T4.3 Preferences round-trip — user-gated
- [ ] T4.4 schedule revert — user-gated
- [ ] T4.5 menu pause/resume cycle, no title staleness — user-gated

## Risk Areas

| Risk | Phase | Mitigation |
|---|---|---|
| User-gated visual checks T4.2–T4.5 cannot be automated | 4 | Surface in checkpoint with concrete criteria. |
| Future reboots could lose `~/.tavs/schedule.json` again if accidentally deleted | meta | Schedule values now documented in PROGRESS.md follow-up section + this PLAN.md Phase 3. |

## Sequencing & Dependencies

| Phase | Depends On | Status |
|---|---|---|
| 0 | — | DONE |
| 1 | 0 | DONE |
| 2 | 0 | DONE |
| 3 | — | DONE |
| 4 | 1, 2, 3 | Auto checks DONE; visual checks pending user |
