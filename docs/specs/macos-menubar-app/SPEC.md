# TAVS macOS Menu Bar Companion App — Specification

**Status:** Final (post-Gemini + post-Codex review — ready for Phase 1)
**Created:** 2026-04-20
**Last Updated:** 2026-04-20 (revision 4 — expanded to team-implementable detail)
**Author:** Christian Stelmach (with Claude Code `/planning:discover-to-spec`)

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [User Stories & Scenarios](#2-user-stories--scenarios)
3. [Goals & Success Criteria](#3-goals--success-criteria)
4. [Architecture & Design](#4-architecture--design)
5. [Data Models & File Contracts](#5-data-models--file-contracts)
6. [Decisions & Rationale](#6-decisions--rationale)
7. [Implementation Phases & Tasks](#7-implementation-phases--tasks)
8. [Constraints & Boundaries](#8-constraints--boundaries)
9. [Rejected Alternatives](#9-rejected-alternatives)
10. [Verification Strategy](#10-verification-strategy)
11. [Open Questions](#11-open-questions)
12. [Review Notes](#12-review-notes)

---

## 1. Project Overview

### Name

`TAVS.app` — a small macOS menu bar companion for TAVS (Terminal Agent
Visual Signals).

### What it is

A native SwiftUI menu bar application that sits alongside the existing
shell-based TAVS tool in this repository. It adds two capabilities that
are impossible to express cleanly in bash alone:

1. **Scheduling** — TAVS paints backgrounds/titles only inside user-defined
   time windows (e.g., 08:00–20:00 weekdays) and goes silent during
   user-defined quiet periods (e.g., the last 10 minutes of every hour).
2. **Curated preferences UI** — a Mac-native single-window editor for the
   most-used TAVS settings (theme preset, title mode, identity mode, face
   style, stylish backgrounds, master on/off, schedule rules).

### Problem it solves

TAVS today paints terminal backgrounds and titles on every Claude-Code
(and Gemini/Codex/OpenCode) hook event. That is great during active work
and distracting during meetings, demos, and off-hours. Users currently
have no good lever to say "mute during meetings" or "silence after 20:00"
— they can set `TAVS_STATUS=false` per shell, but that's per-process,
forgettable, and does not re-activate automatically. For preferences,
they must either hand-edit `~/.tavs/user.conf` or run `tavs wizard`
interactively, neither of which is discoverable for the casual user.

### Primary user persona

A developer running one or more Claude Code sessions in parallel
terminals on macOS. They:
- want TAVS on during focused coding hours,
- want TAVS silent during presentations, meetings, and late evenings,
- want a visible menu-bar toggle for manual pauses,
- occasionally adjust theme/face/identity settings and prefer a GUI over
  editing a dotfile,
- run macOS 13+ (Ventura or later).

The design is explicitly Mac-only for the GUI; the shell-side changes
remain portable and are a no-op on Linux/BSD.

### Core purpose

Give the user a single Mac-native control surface for **when** TAVS
paints terminals and **how** it looks — so colorful screens stay off
during off-hours and come back in exactly the right visual state the
instant they should.

---

## 2. User Stories & Scenarios

These are the end-to-end flows the app must support. Each has a direct
verification method (see §10).

### S1 — Workday window

**As a** developer
**I want** TAVS to be visually active only between 08:00 and 20:00 on
weekdays
**so that** my terminals stop painting backgrounds after I log off in
the evening, and resume automatically in the morning without me thinking
about it.

**Happy path:**
1. First launch: user opens TAVS.app, goes to Preferences → Schedule,
   adds a window `days=[Mon..Fri], start=08:00, end=20:00`, closes window.
2. At 20:00 the next day, every open Claude Code terminal stops showing
   TAVS background/title effects — the terminal looks like a plain shell.
3. At 08:00 the morning after, every still-open terminal snaps back to
   the TAVS state it would have been in (active processing, idle, etc.).

**Verification:** temporarily set window to end in 2 minutes; observe
terminals go silent at the boundary and snap back when window reopens.

### S2 — Top-of-hour quiet period

**As a** developer
**I want** TAVS to mute from X:50 to X:59:59 every hour
**so that** I get a 10-minute visual break each hour during which my
terminals look normal.

**Happy path:**
1. User adds a quiet period: `kind=hourly, start_minute=50, end_minute=59`.
2. At :50 of the next hour, terminals go silent. At :00 (the next
   hour), terminals resume the state they should be in.
3. Hooks fire normally during the quiet period; subagent counters and
   session state stay correct; only the screen painting stops.

**Verification:** observe a terminal running a Claude Code session
across a :50 boundary; confirm the counter is still accurate after the
quiet period ends.

### S3 — Manual pause during a meeting

**As a** developer joining a video call
**I want** a one-click toggle in the menu bar to pause TAVS entirely
**so that** when I share my screen, none of my terminals flash
attention-grabbing colors.

**Happy path:**
1. User clicks menu bar icon → clicks "Pause TAVS".
2. All terminals immediately silent. Icon shows paused state.
3. After meeting, user clicks icon → clicks "Resume TAVS".
4. Terminals snap back to their correct state.

**Verification:** click the toggle during an active Claude Code session;
terminal visibly goes quiet within one hook cycle.

### S4 — Change theme from the app

**As a** developer who likes Nord on some days and Dracula on others
**I want** a theme picker in the menu bar app
**so that** I don't have to edit `user.conf` or remember CLI flags.

**Happy path:**
1. User opens Preferences → Appearance → picks "Dracula" from theme
   dropdown.
2. Setting persists to `~/.tavs/user.conf`.
3. Next Claude Code hook event applies Dracula colors.

**Verification:** change theme while a session is running; the next
prompt submission paints the new theme colors.

### S5 — App crashes or is force-quit

**As a** developer whose Mac crashes during a quiet period
**I want** my terminals to resume working when the app is down
**so that** TAVS is never "stuck muted" due to a missing supervisor.

**Happy path:**
1. Mute state active, quiet period ends in 30 minutes.
2. App crashes.
3. Within 2 minutes of the last app heartbeat, shell-side TAVS treats
   the mute state as stale and resumes normal painting.
4. When user re-launches app, scheduler takes over again.

**Verification:** `kill -9` the app process during mute; observe shell
re-starts painting within 2 minutes.

### S6 — First reboot after install

**As a** developer
**I want** the app to start automatically on login
**so that** my schedule works every day without manual launching.

**Happy path:**
1. User runs `./tavs install macos-app`; app registered as login item
   (with user consent).
2. Reboot.
3. Within 5 seconds of desktop becoming interactive, menu bar icon
   appears, scheduler has projected mute state for the current time.

**Verification:** reboot; stopwatch from login-prompt-dismissed to
icon-visible.

### S7 — Linux/BSD user (out of scope for GUI)

**As a** Linux user of TAVS
**I want** the shell changes introduced by this project to be a no-op
for me
**so that** my TAVS install doesn't regress because of a Mac-only
feature.

**Happy path:**
1. Pull latest TAVS.
2. `trigger.sh` still behaves byte-for-byte as before because no
   `~/.tavs/mute.state` file exists and nothing else changed.
3. Optionally the Linux user can hand-write `~/.tavs/schedule.json` and
   run `tavs schedule tick` from cron — but this is documented, not
   supported beyond "feature works if you wire it up yourself."

**Verification:** on a Linux VM, run the pre-existing TAVS test suite
after the Phase 1 shell changes land. All tests must pass unchanged.

---

## 3. Goals & Success Criteria

| # | Goal | Success Criterion | Priority | Story |
|---|------|-------------------|----------|-------|
| G1 | Schedule TAVS to be active only inside allowed windows | With `08:00–20:00` configured, no OSC bytes land on any TTY between 20:00 and 07:59:59. At 08:00:00 (±1s), broadcaster emits cached bytes per tracked TTY. | Must | S1 |
| G2 | Suppress TAVS during recurring quiet periods | With `minute 50–59 hourly` configured, no OSC bytes land on any TTY during X:50:00–X:59:59 regardless of new hook events. **Includes the idle-fade worker**. | Must | S2 |
| G3 | Re-apply last per-terminal state when a quiet period ends | At every `muted → unmuted` transition, every live tracked TTY receives the exact OSC bytes it would have received if never muted. | Must | S1, S2 |
| G4 | Curated Mac-native preferences UI | Theme, title mode, identity mode, face mode, stylish backgrounds, master on/off, schedule rules. Changes persist atomically, take effect within 1 trigger invocation. | Must | S3, S4 |
| G5 | Master on/off toggle in menu bar | Binary Active/Paused. Paused overrides schedule. Icon state unambiguous. | Must | S3 |
| G6 | Zero shell regression when app absent/crashed | Missing, stale, expired, or dead-PID `mute.state` → shell behaves byte-for-byte like today. | Must | S5, S7 |
| G7 | Single rule evaluator — no dual engine | Rule math lives only in Swift. Shell never parses `schedule.json`. | Must | — |
| G8 | State bookkeeping never skipped while muted | Subagent counter, identity registry, session-state priority, spinner PID tracking all continue to operate during mute. Only final OSC write is captured-not-written. | Must | S2 |
| G9 | Launch at login survives reboots | Self-signed-cert codesign; `SMAppService.mainApp` returns `.enabled` post-install; rebuild preserves registration. | Should | S6 |
| G10 | Low maintenance burden | Zero new shell dependencies. Single SwiftUI app. No launchd plist. <1000 LOC Swift (test-excluded). | Should | — |
| G11 | Clear user feedback at every state | Menu always shows current state reason ("Muted until 20:00", "Active — next mute in 23 min", "Paused"). | Should | S1, S2, S3 |

---

## 4. Architecture & Design

### 4.1 Overview: two artifacts, one contract

1. **`TAVS.app`** — a native SwiftUI macOS application owns:
   - Rule evaluation (schedule.json → mute.state projection)
   - Preferences UI (schedule + appearance tabs)
   - Menu bar icon + menu
   - Per-transition broadcaster that writes cached OSC bytes to every live TTY on mute→unmuted edges
   - 60-second heartbeat to `mute.state` so the shell side can detect a dead app

2. **The existing TAVS shell pipeline** — `trigger.sh`, its sourced
   helpers, and the idle-fade worker — is extended with two additions:
   - An **inline stage-0 gate** at the top of `trigger.sh`, before any
     sourcing, that reads `mute.state` using bash builtins only and sets
     a single suppression flag.
   - An **`emit_osc` wrapper** that replaces every direct
     `printf ... > $TTY_DEVICE` in the codebase. When the suppression
     flag is set, `emit_osc` appends to a per-process buffer which is
     atomically renamed to a per-TTY pending cache at dispatch end.
     When not set, it writes to the TTY as before.

The two artifacts communicate only through well-defined files on disk
(see §5). There are no sockets, no daemons-other-than-the-app, no
launchd plists, no D-Bus equivalents.

### 4.2 Architectural principles

1. **The shell never evaluates schedule rules.** Rule math lives in
   Swift. The shell reads a small pre-projected KV file and nothing
   more (D10, G7).
2. **The mute gate is a suppression wrapper, not a short-circuit.** All
   state bookkeeping (subagent counter, identity registry, session
   state, title composition, color resolution) runs at full dispatch
   even during mute. Only the final OSC byte-write is diverted (D21, G8).
3. **Cached bytes are the ground truth of replay.** The pending cache
   stores fully-rendered OSC sequences, not input arguments. Replay is
   a file-to-TTY copy; no re-rendering, no env-capture problem (D12).
4. **Absence means "not active."** A missing/stale/expired `mute.state`
   means TAVS behaves exactly as it does today. New TAVS users, Linux
   users, and Mac users who never install the app see zero change (D13,
   G6).
5. **Liveness is verifiable.** Heartbeat + PID + expiry epoch are all
   validated by the shell. A dead app cannot leave terminals
   permanently muted (D23).
6. **Hot path is bash-builtin only.** Stage-0 gate uses no forks except
   `kill -0` for liveness. Full mute-gate helpers live in a sourced file
   that runs later in dispatch (D29).
7. **Shell gets the minimum; app gets the complexity.** Every hard
   problem (DST arithmetic, boundary wake, fs-watch, login-item lifecycle)
   is Swift's responsibility.

### 4.3 Responsibilities

| Actor | Owns | Does not own |
|-------|------|---------------|
| TAVS.app (Swift) | `schedule.json`, `mute.state` writes, broadcasting on unmute, heartbeat, fs-watch, menu bar UI, prefs UI, login item | Any OSC rendering logic; shell dispatch |
| `trigger.sh` + idle worker + helpers (bash) | Everything it owns today; plus stage-0 read of `mute.state` and `emit_osc` buffering | Schedule rule evaluation |
| `tavs schedule` CLI (bash) | User-driven edits to `schedule.json` (including atomic write) | Rule evaluation (no `tick` command in v1; if app isn't running, edits are dormant) |
| User's terminal emulator | Rendering OSC sequences that reach it | — |

### 4.4 Component inventory

| # | Component | Purpose | Location |
|---|-----------|---------|----------|
| C1 | `TAVSApp.swift` | SwiftUI `@main`; `MenuBarExtra` scene; dependency wiring | `src/macos/TAVSApp/Sources/TAVSApp/TAVSApp.swift` |
| C2 | `Scheduler.swift` | Rule evaluation, projection to `mute.state`, transition detection, heartbeat | `Sources/TAVSApp/Scheduler.swift` |
| C3 | `Broadcaster.swift` | On `muted → unmuted` edge: enumerate active TTYs, write cached bytes to each, prune dead ones | `Sources/TAVSApp/Broadcaster.swift` |
| C4 | `ScheduleStore.swift` | `Codable` data models, atomic load/save, validation | `Sources/TAVSApp/ScheduleStore.swift` |
| C5 | `UserConfStore.swift` | Bash-KV round-tripper; preserves comments + unknown keys | `Sources/TAVSApp/UserConfStore.swift` |
| C6 | `MuteState.swift` | Projected-state struct and atomic writer | `Sources/TAVSApp/MuteState.swift` |
| C7 | `PreferencesView.swift` | Three-tab SwiftUI preferences window | `Sources/TAVSApp/PreferencesView.swift` |
| C8 | `MenuContent.swift` | Menu bar dropdown (toggle, status line, open prefs, quit) | `Sources/TAVSApp/MenuContent.swift` |
| C9 | `LoginItemManager.swift` | `SMAppService.mainApp` wrapper | `Sources/TAVSApp/LoginItemManager.swift` |
| C10 | `ProcessRunner.swift` + `Clock.swift` + `TimerScheduler.swift` + `FileWatcher.swift` | Test-injectable protocols for all external effects | `Sources/TAVSApp/{…}.swift` |
| C11 | `trigger.sh` (edited) | Adds stage-0 inline gate; sources `mute-gate.sh` for stage-1 helpers | `src/core/trigger.sh` |
| C12 | `mute-gate.sh` (new) | Stage-1 helpers: runtime dir resolution, active-TTY touch, buffer open/close, pending flush, replay-for-debug | `src/core/mute-gate.sh` |
| C13 | `idle-worker-background.sh` (edited) | Consults mute state each tick; emits through `emit_osc` | `src/core/idle-worker-background.sh` |
| C14 | `terminal-osc-sequences.sh`, `backgrounds.sh`, `title-management.sh` (edited) | Every direct-to-TTY write refactored to go through `emit_osc` | `src/core/*.sh` |
| C15 | `cmd-schedule.sh` (new) | `tavs schedule` CLI subcommands | `src/cli/cmd-schedule.sh` |
| C16 | `cmd-install-macos-app.sh` (new) | Builds, bundles, codesigns, installs, registers login item | `src/cli/cmd-install-macos-app.sh` |
| C17 | `cmd-sync.sh` (edited) | Enumerates new shell files in sync list | `src/cli/cmd-sync.sh` |
| C18 | Docs | Reference for scheduling and the app | `docs/reference/macos-menubar-app.md`, `docs/reference/scheduling.md`, README + CLAUDE.md updates |

### 4.5 Key mechanisms (prose, not code)

**Two-stage shell gate.** `trigger.sh` currently sources 14 helper
files at lines 34–50 before any dispatch, producing a ~57ms warm
baseline. A mute check inside a sourced helper cannot beat that. The
design therefore splits the gate:
- **Stage 0** runs at the top of `trigger.sh` immediately after the
  existing `TAVS_STATUS` kill switch and before *any* `source`
  statement. Stage 0 uses only bash builtins: a single `read`-loop over
  a tiny KV file, comparisons, and one optional `kill -0`. It sets
  `_TAVS_SUPPRESS_OUTPUT=1` iff the app says we should be muted and its
  heartbeat/PID/expiry all validate. It never touches the TTY, never
  writes any cache, never exits early.
- **Stage 1** is the sourced `mute-gate.sh` helper with functions
  used later in dispatch: resolve the runtime directory, touch the
  active-TTY registry, open/close the pending-cache buffer, flush on
  dispatch end. Stage 1 functions run inside the ~57ms dispatch window
  that already exists.

**`emit_osc` as the single choke point.** Every place in the shell that
currently writes an OSC byte sequence to `$TTY_DEVICE` is replaced with
a call to `emit_osc`. The function's behavior is: if
`_TAVS_SUPPRESS_OUTPUT` is 1, append bytes to the per-process pending
buffer; otherwise write to `$TTY_DEVICE`. This is the only code site
that needs to know about mute state; everything upstream is unchanged.

**Pending cache = rendered bytes.** The pending-cache file (one per
TTY) holds the actual OSC bytes the terminal would have received.
Replay is a file-to-TTY copy with no re-rendering. This guarantees
replay fidelity for free — subagent counters, session-state priority
pinning, identity assignments, title composition all ran normally and
baked their results into the bytes. The cost is a one-cycle lag if the
user changes theme during mute: replay shows the pre-change render; the
next hook re-renders with the new theme. Documented and accepted.

**Active-TTY registry.** Each `trigger.sh` or idle-worker invocation
`touch`es a file at `$TAVS_RUNTIME_DIR/active-ttys/<tty_safe>`. The
broadcaster enumerates this directory, filters to entries with mtime
within the last 24 hours (to drop dead sessions), and writes the
corresponding pending-cache bytes to `/dev/<tty_safe-unescaped>`. On
write failure (EIO/ENXIO/ENOENT/EBADF), the TTY is dead; the active-ttys
entry is unlinked. No `lsof` — a file write to a dead FD fails fast.

**UID-namespaced runtime dir.** New paths live under
`$TAVS_RUNTIME_DIR`, default `/tmp/tavs-$UID`, created with mode 0700.
Legacy paths under `/tmp/tavs/` are not touched in v1 (they inherit a
pre-existing single-user-only bug, tracked separately).

**Liveness protocol.** `mute.state` contains four liveness signals:
`MUTED`, `UNTIL_EPOCH`, `WRITTEN_EPOCH` (heartbeat timestamp),
`APP_PID`. The shell reads all four. Muted iff `MUTED="true"` **and**
`UNTIL_EPOCH` is 0 or in the future **and** `WRITTEN_EPOCH` is within
the last 120 seconds **and** either `APP_PID` is empty or
`kill -0 $APP_PID` succeeds. Any failure means "presume app dead,
resume normal behavior."

**Scheduler wake strategy.** The app computes the next relevant
boundary (earliest of: next window start/end, next quiet start/end,
heartbeat tick). It schedules a `DispatchSourceTimer` for that exact
instant, sleeps. On wake, re-evaluate, project new `mute.state`, and if
the transition is `muted → unmuted`, call the broadcaster. Additionally:
- fs-watch on the parent directory of `schedule.json` and `user.conf`
  (atomic rename defeats fs-watch on the file itself — see D28) with
  100ms debounce.
- `NSWorkspace.didWakeNotification` fires on system wake, re-evaluating
  in case a boundary was crossed while sleeping.

**Broadcast on unmute.** On every `muted → unmuted` transition, the
broadcaster enumerates the active-TTY registry, reads each
corresponding pending-cache file, and writes the bytes verbatim to the
matching `/dev/ttys00X` device. Writes are attempted in parallel
(`DispatchQueue.concurrentPerform`) with a per-TTY 200ms timeout. Dead
TTYs are pruned on write failure. Typical 20-terminal broadcast
completes in <50ms.

**Codesign + SMAppService.** `./tavs install macos-app` first attempts
to create a self-signed certificate named `TAVS-Local-Signing` in the
user's login keychain (one-time setup, ~1 `security` command). The app
bundle is signed with that stable cert. Stable cert subject = stable
code identity across rebuilds, which is what `SMAppService.mainApp`
needs to persist a login-item registration. If cert creation fails,
the installer falls back to ad-hoc signing and documents that login-item
registration will not persist across reinstalls.

**`MenuBarExtra` + `LSUIElement=true`.** The app bundle's `Info.plist`
sets `LSUIElement=<true/>` so macOS does not show a dock icon; only the
menu bar icon is visible. `MenuBarExtra` is a SwiftUI scene (macOS 13+)
that renders the icon and a click-triggered menu content view.

### 4.6 Component interactions

```mermaid
graph TD
    User([User]) -->|edits rules| PrefsWin[C7 PreferencesView]
    User -->|CLI| CLISched[C15 tavs schedule]
    PrefsWin -->|writes| ScheduleJSON[(schedule.json)]
    PrefsWin -->|writes curated keys| UserConf[(user.conf)]
    CLISched -->|writes| ScheduleJSON

    ScheduleJSON -.fs-watch.-> Sched[C2 Scheduler]
    UserConf -.fs-watch.-> Prefs[C5 UserConfStore]
    Sched -->|project + 60s heartbeat| MuteState[(mute.state)]
    Sched -->|muted→unmuted edge| Broadcast[C3 Broadcaster]

    Broadcast -->|enumerate| TTYReg[(active-ttys/)]
    Broadcast -->|read bytes| Pending[(pending/*.osc)]
    Broadcast -->|bytes → TTY device| TTYDevice[/dev/ttys00X]
    Broadcast -->|prune on EIO| TTYReg

    Hook[Claude Code hook] -->|invoke| Trigger[C11 trigger.sh]
    Trigger -->|stage-0 inline read| MuteState
    Trigger -->|touch| TTYReg
    Trigger -->|full bookkeeping runs| Bookkeeping[session-state, subagent-counter,<br/>identity-registry, title-composition]
    Trigger -->|OSC emission via| Emit[C14 emit_osc]
    Emit -->|suppressed: buffer| PendingBuf[[per-process buffer]]
    Emit -->|active: write| TTYDevice
    PendingBuf -->|end of dispatch: atomic rename| Pending

    IdleWorker[C13 idle-worker] -.each tick consults.-> MuteState
    IdleWorker -->|emits via| Emit

    Menu[C8 MenuContent] <-->|toggle, status| Sched
```

---

## 5. Data Models & File Contracts

### 5.1 File-system contract

All coordination is via files. Atomic writes use write-temp-then-rename.
New paths are UID-namespaced.

| Path | Owner (writer) | Reader | Purpose | Format |
|------|----------------|--------|---------|--------|
| `~/.tavs/schedule.json` | App (+ CLI) | App only | User-defined schedule rules and master toggle | JSON, versioned schema |
| `~/.tavs/mute.state` | App | `trigger.sh` (stage-0 hot path) + idle worker | Projected current mute state + liveness signals | Bash KV |
| `~/.tavs/user.conf` | App (+ CLI + wizard) | `trigger.sh` (existing pipeline) | Existing user config; app edits curated keys only | Bash KV (existing) |
| `$TAVS_RUNTIME_DIR/pending/<tty_safe>.osc` | `trigger.sh`, idle worker | App (write to TTY) | Rendered OSC bytes ready to replay | Raw bytes, binary-safe |
| `$TAVS_RUNTIME_DIR/active-ttys/<tty_safe>` | `trigger.sh`, idle worker (`touch`) | App (list + mtime) | TTY liveness registry | Empty file, mtime is the signal |

Where `$TAVS_RUNTIME_DIR` defaults to `/tmp/tavs-$(id -u)` (mode 0700,
auto-created) and `<tty_safe>` is the current TTY path with slashes
replaced by underscores, e.g. `dev_ttys001`.

### 5.2 `schedule.json` schema

```json
{
  "version": 1,
  "master_active": true,
  "allowed_windows": [
    {
      "id": "weekday-core-hours",
      "enabled": true,
      "days": ["mon", "tue", "wed", "thu", "fri"],
      "start": "08:00",
      "end": "20:00"
    }
  ],
  "quiet_periods": [
    {
      "id": "top-of-hour-break",
      "enabled": true,
      "kind": "hourly",
      "start_minute": 50,
      "end_minute": 59
    }
  ]
}
```

**Rule evaluation (Swift only):**

TAVS is **active** iff all three are true:
1. `master_active` is `true`.
2. `now` is inside at least one enabled `allowed_windows` entry.
3. `now` is **not** inside any enabled `quiet_periods` entry.

**Validation rules (enforced by `ScheduleStore.validate`, rejected at
Save in GUI, returns non-zero in CLI):**

- `master_active: true` requires at least one enabled `allowed_windows`
  entry. Empty list is an error, not "always active" (D26). To globally
  disable the feature, user sets `master_active: false`.
- Each `TimeWindow` has a non-empty `id`, at least one valid day, and
  time strings of the form `HH:MM` where `HH ∈ [00,23]` and `MM ∈ [00,59]`.
- `allowed_windows[].start == end` is invalid (zero-length window).
- Overnight window (`end < start`): window anchors on each listed day
  and extends past midnight. Example: `days=[fri], start="22:00",
  end="02:00"` is active 22:00:00–23:59:59 Fri and 00:00:00–02:00:00
  the following Sat, regardless of whether Sat is in `days`.
- `QuietPeriod.kind ∈ {"hourly", "fixed_daily"}`.
- `hourly`: `start_minute, end_minute ∈ [0,59]`. If
  `end_minute < start_minute`, the range wraps past the hour boundary:
  current minute `m` is inside iff `m >= start_minute OR m <= end_minute`.
- `fixed_daily`: same `start`/`end` format as `TimeWindow` and same
  overnight semantics.
- **DST:** wall-clock arithmetic. On spring-forward days, a boundary at
  02:30 simply doesn't fire. On fall-back days, a 02:30 boundary fires
  twice. Documented explicitly in `docs/reference/scheduling.md`.
- **Timezone:** system local time via
  `Calendar(identifier: .gregorian).dateComponents(...)`; no UTC math.

### 5.3 `mute.state` format

```
MUTED="true"
REASON="quiet_period"
UNTIL_EPOCH="1713624000"
WRITTEN_EPOCH="1713623400"
APP_PID="12345"
SCHEMA_VERSION="1"
```

| Key | Type | Semantics |
|-----|------|-----------|
| `MUTED` | `"true"` \| `"false"` | Current mute verdict |
| `REASON` | `"schedule_window"` \| `"quiet_period"` \| `"master_paused"` \| `""` | Human-readable cause |
| `UNTIL_EPOCH` | unix seconds, or `0` | When mute is expected to end; `0` = indefinite/unknown |
| `WRITTEN_EPOCH` | unix seconds | Last heartbeat write; bumped every 60s even when state unchanged |
| `APP_PID` | pid, or empty | Used for `kill -0` liveness check |
| `SCHEMA_VERSION` | int | Format version; shell reads version-1 only in v1 |

### 5.4 Pending-cache file format

Binary — raw OSC byte sequences concatenated. No headers, no KV. The
file is atomic-renamed into place at the end of each muted dispatch
from a per-process buffer. Size is always small (<4 KB typical; upper
bound ~32 KB). Replay is `dd if=<file> of=/dev/ttysXXX` semantics.

### 5.5 Curated `user.conf` keys owned by the app

Only these keys are modified by the app; everything else in the file
(comments, unknown keys, wizard-written keys) is preserved byte-for-byte
across round-trips.

| Key | Where in Prefs | Type |
|-----|----------------|------|
| `THEME_PRESET` | Appearance → Theme | string: nord, dracula, solarized, tokyo-night, catppuccin-{latte,frappe,macchiato,mocha} |
| `THEME_MODE` | Appearance → Theme Mode | enum: preset, dynamic, static |
| `TAVS_TITLE_MODE` | Appearance → Title Mode | enum: off, prefix-only, full, skip-processing |
| `TAVS_FACE_MODE` | Appearance → Face Mode | enum: standard, compact |
| `TAVS_COMPACT_THEME` | Appearance → Compact Theme | enum: squares, semantic, circles, mixed |
| `TAVS_IDENTITY_MODE` | Identity → Mode | enum: dual, single, off |
| `TAVS_DIR_ICON_TYPE` | Identity → Dir Icon | enum: flags, plants, buildings, auto |
| `ENABLE_STYLISH_BACKGROUNDS` | Appearance → Stylish Backgrounds | bool |
| `ENABLE_LIGHT_DARK_SWITCHING` | Appearance → Light/Dark Switching | bool |
| `TAVS_PAUSE_BG_DARK` | Appearance → Paused State (dark) | hex color `#RRGGBB` (default `#3A3A3A`) |
| `TAVS_PAUSE_BG_LIGHT` | Appearance → Paused State (light) | hex color `#RRGGBB` (default `#D0D0D0`) |

**Total: 11 controls across 2 tabs.** The two pause-bg keys were
added by commit `df164af` (post-Phase-2 follow-on) so light-mode and
dark-mode users can configure different paused-state shades. The
broadcaster picks the colour based on
`NSApplication.shared.effectiveAppearance` at the moment of paint.
A `Broadcaster.sanitizeHexColor` guard rejects malformed values and
falls back to the dark default so a bad user.conf cannot wedge the
pause paint. Tracked in scheduler state via `lastPaintedPauseColor`
so a Preferences edit while currently paused triggers a live
re-paint within one fs-watch tick.

Schedule tab contents live in `schedule.json`, not `user.conf`.

---

## 6. Decisions & Rationale

D01-D31. Full rationale was established through Q&A rounds and two
external reviews (Gemini + Codex). Summary table here; text rationale
in earlier revisions if needed.

| # | Decision | Summary |
|---|----------|---------|
| D01 | Framework | Native SwiftUI `.app` with `MenuBarExtra` |
| D02 | Mute scope | Full visual suppression (bg + palette + title + face + icons) |
| D03 | Rule granularity | N allowed windows AND NOT in any N quiet periods; `hourly` + `fixed_daily` quiet kinds |
| D04 | Unmute strategy | Active broadcast: Mac app writes cached bytes directly to each live TTY on mute→unmute edge |
| D05 | Settings scope | Curated 9 keys + schedule (not full parity with wizard) |
| D06 | Master toggle | Binary Active/Paused; per-rule toggles in prefs, not menu |
| D07 | Pending cache | `/tmp/tavs-$UID/pending/<tty_safe>.osc` raw bytes, atomic rename |
| D08 | Manual override | None in v1 (no snooze / force-unmute); schema reserves shape for v2 |
| D09 | Active-TTY registry | Touch files, mtime window (24h), no `lsof`; prune on write failure |
| D10 | Single evaluator | Rule math only in Swift; shell reads pre-projected KV |
| D11 | Wake strategy | `DispatchSourceTimer` + fs-watch + `NSWorkspace.didWakeNotification` + 60s heartbeat |
| D12 | Cache content | Rendered OSC bytes, not input args (cascades to solve priority pinning + env capture + counter deltas) |
| D13 | Backwards compat | Absent/stale `mute.state` = "not muted"; zero regression |
| D14 | Repo layout | `src/macos/TAVSApp/` Swift Package; no Xcode project in git |
| D15 | macOS minimum | 13 (Ventura) — MenuBarExtra + SMAppService both require 13+ |
| D16 | Distribution & signing | Self-signed cert (stable identity) with ad-hoc fallback; explicit Info.plist keys; ad-hoc fallback documents degraded login-item UX |
| D17 | Config co-editing | UserConfStore preserves unknown keys + comments byte-for-byte; fs-watch reloads on external change |
| D18 | TAVS_STATUS precedence | Env kill switch still first; mute file second |
| D19 | Shell helper location | `src/core/mute-gate.sh` sourced from `trigger.sh` + idle worker |
| D20 | Plugin sync | `tavs sync` updates both marketplace and cache dirs (pre-existing discipline) |
| D21 | Suppression wrapper | Mute gate suppresses OSC writes, never short-circuits dispatch |
| D22 | Runtime dir namespacing | `$TAVS_RUNTIME_DIR = /tmp/tavs-$UID`; legacy paths deferred |
| D23 | Liveness protocol | Heartbeat + UNTIL_EPOCH + PID check; stale/dead = "not muted" |
| D24 | Wrapping + overnight | Explicit semantics; DST documented |
| D25 | Idle worker mute | Phase 1 hard AC — idle worker consults mute state per tick |
| D26 | Empty-list rejection | `allowed_windows=[]` invalid; pause via `master_active: false` |
| D27 | ProcessRunner protocol | Test injection; no production injection seam |
| D28 | fs-watch pattern | Watch parent dir + 100ms debounce; reopen on rename |
| D29 | Hot-path budget | Stage-0 marginal overhead <2ms; total muted-trigger = baseline |
| D30 | Clock + TimerScheduler | Protocol-based clock + timer injection for deterministic tests |
| D31 | JSON round-trip | Semantic (model-equality), not byte-identical |

---

## 7. Implementation Phases & Tasks

Six phases. Each phase breaks into 4–8 tasks. Each task lists: what to
build, where, how to verify the result with direct feedback. At the end
of each phase there is an **end-of-phase demo** — a short, user-visible
check that proves the phase works before moving on.

### Phase 1 — Shell-side suppression wrapper

**Goal:** Make the existing TAVS shell pipeline mute-aware without any
Swift side. When `mute.state` is absent, shell behavior is byte-for-byte
identical to today. When `mute.state` says muted, OSC writes are
captured into pending cache and the TTY stays dark. All state
bookkeeping (counter, identity, priority) runs regardless.

**Depends on:** nothing. Pure shell, no Swift.

**Tasks:**

- **T1.1** — Introduce `$TAVS_RUNTIME_DIR` helper in `mute-gate.sh`.
  Resolves to `/tmp/tavs-$(id -u)`, creates mode 0700 on first call,
  exports the value.
  *Verify:* invoke the helper from a bash shell; confirm directory
  exists, mode is 0700, sibling user cannot write to it.

- **T1.2** — Add stage-0 inline block at the top of `trigger.sh` (after
  `TAVS_STATUS` check, before any `source`). Uses bash builtins only to
  read `~/.tavs/mute.state`, run the four liveness checks (D23), and
  set `_TAVS_SUPPRESS_OUTPUT=0|1`.
  *Verify:* run `trigger.sh reset` with no `mute.state` file present —
  unchanged behavior. Write a `MUTED="true"` + fresh heartbeat + live PID
  file; run `trigger.sh reset`; inspect with `set -x` that
  `_TAVS_SUPPRESS_OUTPUT=1` before any source.

- **T1.3** — Refactor every direct `printf ... > $TTY_DEVICE` call site
  in `terminal-osc-sequences.sh`, `backgrounds.sh`, `title-management.sh`
  (and anywhere else grep finds them) into calls to `emit_osc`.
  `emit_osc` lives in `terminal-osc-sequences.sh` and reads
  `_TAVS_SUPPRESS_OUTPUT` / `_TAVS_PENDING_BUFFER` from env.
  *Verify:* run all existing TAVS state triggers (`processing`,
  `permission`, `complete`, `idle`, etc.) in a terminal; confirm
  every state still paints correctly. Grep for any remaining direct
  `> $TTY_DEVICE` writes — none allowed except in `emit_osc` itself.

- **T1.4** — Implement pending-cache lifecycle: open a temp file at the
  start of each `trigger.sh` dispatch (only when suppressed); on
  successful end of dispatch, atomic-rename to
  `$TAVS_RUNTIME_DIR/pending/<tty_safe>.osc`. On crash or error, unlink.
  *Verify:* run with fault injection (`kill -TERM` mid-dispatch); confirm
  no half-written pending files.

- **T1.5** — Implement `register_active_tty` (unconditional `touch` on
  every `trigger.sh` invocation, muted or not) and 24h sweep-on-scan
  (called by the app later; also expose a `tavs debug clean-registry`
  CLI for manual use).
  *Verify:* simulate 25 TTYs touching the registry; sleep 25h with mtime
  forward-shifting; run sweep; confirm all 25 unlinked.

- **T1.6** — Extend `src/core/idle-worker-background.sh`: source
  `mute-gate.sh` on startup, re-read `mute.state` each tick, route its
  OSC emission through `emit_osc`. On mute, the worker's fade-step bytes
  go to the pending cache instead of the TTY. Worker sleeps and continues
  ticking — it does not exit.
  *Verify:* start an idle session, wait for idle fade to begin, write
  `MUTED="true"` to mute.state mid-fade; observe no further OSC on the
  TTY; observe pending cache grows. Remove mute.state; next tick emits to
  TTY again.

- **T1.7** — Add `trigger.sh replay <tty_safe>` debug subcommand: reads
  pending cache, writes bytes to TTY, unlinks cache. Safe to call on
  missing cache (no-op). Sets `_TAVS_REPLAY_BYPASS_MUTE=1` internally to
  prevent self-suppression.
  *Verify:* manually mute, fire a trigger, verify pending cache exists;
  run `trigger.sh replay dev_ttys001`; terminal visibly snaps to the
  captured state.

- **T1.8** — Update `src/cli/cmd-sync.sh` to enumerate `mute-gate.sh` and
  the updated core helpers in its sync list. Run `./tavs sync` locally;
  confirm both plugin dirs receive the new file.
  *Verify:* `diff -r` between source and both plugin dirs shows zero
  divergence after sync.

- **T1.9** — Write and run a golden-byte regression harness: capture
  OSC output per state before any Phase 1 change, re-capture after,
  diff. Any byte-level drift when `mute.state` is absent = regression.
  *Verify:* diff output shows 0 bytes of change for every state.

- **T1.10** — Hot-path benchmark: `tests/bench/hot-path.sh` runs
  `trigger.sh reset` 100 times, computes median over 3 trials. Record
  pre-change baseline in `tests/bench/baseline.txt`; assert post-change
  median ≤ baseline + 5ms.
  *Verify:* run the benchmark script; numbers match the budget.

**End-of-phase-1 demo (15 minutes):**

1. Run the baseline regression harness with no `mute.state` — 0 bytes of
   drift. Show the diff output.
2. Manually create `~/.tavs/mute.state` with `MUTED="true"` + fresh
   heartbeat + current-process PID.
3. Open a Claude Code session in a terminal. Submit a prompt.
4. Show: terminal stays dark (no background change, no title change, no
   face animation) for the full prompt lifecycle.
5. Show: `cat $TAVS_RUNTIME_DIR/pending/dev_ttys001.osc | xxd | head` —
   OSC bytes are cached.
6. Delete `mute.state`, then `trigger.sh replay dev_ttys001`. Terminal
   visibly snaps to the correct visual state.
7. Show: subagent counter file is accurate (muted start/stop pairs
   cancelled correctly).
8. Show: hot-path benchmark reports median within budget.

**Phase 1 acceptance = demo passes + all T1.x verification bullets pass.**

---

### Phase 2 — Swift scaffold + data stores + test harness

**Goal:** Bootstrap the Swift Package. Establish all data models,
file-watching abstractions, and test-injectable protocols. The app
exists as a runnable stub with an empty menu, but does nothing real yet.

**Depends on:** Phase 1 (no runtime coupling; parallel artifact).

**Tasks:**

- **T2.1** — Scaffold `src/macos/TAVSApp/` as a Swift Package:
  `Package.swift` targeting macOS 13+, SwiftUI + Foundation only, no
  third-party deps. `TAVSApp.swift` with `@main` + `MenuBarExtra`
  scene showing a placeholder SF Symbol icon and a menu with just
  "Quit".
  *Verify:* `swift build --package-path src/macos/TAVSApp` succeeds;
  `swift run` shows the icon in the menu bar; "Quit" works.

- **T2.2** — Implement `ScheduleStore.swift` with `Codable` models
  (`ScheduleConfig`, `TimeWindow`, `QuietPeriod`, `Day` enum,
  `QuietKind` enum), atomic load/save (temp+rename in same directory),
  and `validate()` enforcing every rule in §5.2.
  *Verify:* `swift test` unit tests: parse a canonical fixture, mutate,
  re-serialize; semantic equality holds. Every validation error case
  (empty list, invalid time, zero-length window, unknown day, out-of-range
  minute) produces a specific error.

- **T2.3** — Implement `UserConfStore.swift`: line-oriented bash-KV
  parser that preserves line order, comments (`#` prefix), blank lines,
  and unknown keys. Exposes typed accessors for the 11 curated keys
  (§5.5). Save writes the full file with only curated keys mutated.
  *Verify:* round-trip test: load a fixture `user.conf` with comments
  and unknown keys, save without changes, `diff` shows zero bytes.
  Mutate one curated key, save, diff shows exactly that one line
  changed.

- **T2.4** — Implement `MuteState.swift` with the KV format from §5.3,
  atomic writer (temp+rename).
  *Verify:* write under concurrent reader — no partial reads observed.

- **T2.5** — Define test-injectable protocols (D27, D30):
  `protocol Clock` (production `SystemClock`, test `VirtualClock`),
  `protocol TimerScheduler`, `protocol ProcessRunner`,
  `protocol FileWatcher`. Each has a production impl and a test mock in
  `Sources/TAVSApp/Mocks/`.
  *Verify:* unit tests inject a `VirtualClock` into a sample type and
  advance it; observe deterministic behavior.

- **T2.6** — Implement `FileWatcher` using the parent-dir + debounce
  pattern (D28): watches a directory, debounces events to 100ms,
  reopens target files on rename. Takes a callback.
  *Verify:* unit test with a real temp directory: atomically rename a
  file in place 5 times in rapid succession; exactly one callback
  fires after the debounce window.

**End-of-phase-2 demo (10 minutes):**

1. `swift build` succeeds with zero warnings.
2. `swift test` green: all unit tests pass (~20 tests).
3. `swift run` launches app; menu bar icon appears; click shows stub
   menu with "Quit"; quit works cleanly.
4. Load a sample `schedule.json` via `ScheduleStore.load()` from a REPL
   test; mutate; save; re-load; compare — equal.
5. Load a `user.conf` with comments, unknown keys, and all 9 curated
   keys; save without changes; `diff` shows 0 bytes.

**Phase 2 acceptance = demo passes + all T2.x pass + test coverage ≥ 80%
for the four stores.**

---

### Phase 3 — Scheduler + Broadcaster + live state

**Goal:** Make the app actually do its job. Rules evaluate, mute state
projects, transitions detected, broadcaster fires on unmute. Menu shows
live state. No UI editing yet — configuration is by hand-editing
`schedule.json`.

**Depends on:** Phases 1 and 2.

**Tasks:**

- **T3.1** — Implement `Scheduler.computeMuteState(at: Date, rules:
  ScheduleConfig) -> MuteState`. Pure function. Handles: empty enabled
  windows (only allowed when `master_active: false`, else error),
  overlapping windows, overnight windows, wrapping minute ranges,
  `fixed_daily` quiet, `master_active: false`, DST spring-forward and
  fall-back.
  *Verify:* exhaustive XCTest matrix with `VirtualClock`. Fixture file
  in `Tests/TAVSAppTests/Fixtures/scheduler-matrix.json` with 30+
  (input_rules, input_time, expected_output) triples.

- **T3.2** — Implement `Scheduler.nextTransition(after: Date) -> Date`.
  Returns the earliest next boundary. Used to size the
  `DispatchSourceTimer` sleep.
  *Verify:* same fixture matrix extended with expected-next-transition
  columns.

- **T3.3** — Wire `Scheduler` into the app lifecycle: on launch, load
  `schedule.json`, project initial `mute.state`, schedule the first
  transition timer, start the 60s heartbeat timer.
  *Verify:* launch the app with a schedule that mutes now; observe
  `mute.state` on disk; observe heartbeat tick via
  `tail -f ~/.tavs/mute.state` showing WRITTEN_EPOCH advancing.

- **T3.4** — Implement `Broadcaster.broadcast()`: enumerate
  `$TAVS_RUNTIME_DIR/active-ttys/`, filter mtime ≤ 24h, in parallel
  read each `pending/<tty_safe>.osc` and write bytes to the TTY device;
  on write failure prune the registry entry.
  *Verify:* manual test with 2 real terminals each holding a pending
  file; call the broadcaster via a debug hidden-flag on the app; bytes
  appear on both terminals. Kill one terminal's process, rerun; entry
  pruned silently, surviving terminal still painted.

- **T3.5** — Wire transition detection: scheduler's timer fires,
  compute new state, compare to previous. On `muted → unmuted`,
  call `Broadcaster.broadcast()` before writing the new `mute.state`.
  *Verify:* end-to-end: a 30-second quiet period. Watch active Claude
  Code terminal go dark at the boundary; watch it snap back 30 seconds
  later.

- **T3.6** — Implement fs-watch on `~/.tavs/schedule.json` (via
  `FileWatcher` protocol; parent-dir watch + debounce). On change,
  reload, re-project, re-schedule.
  *Verify:* edit `schedule.json` manually; observe `mute.state`
  re-projects within ~200ms.

- **T3.7** — Implement `NSWorkspace.didWakeNotification` handler: on
  system wake, re-evaluate immediately (a boundary may have been
  crossed during sleep).
  *Verify:* put machine to sleep for 3 minutes while scheduled
  transition is 1 minute away; wake; observe broadcaster fires within
  ~1s of wake.

- **T3.8** — Update `MenuContent.swift` to show live state:
  "Active — next mute in 23 min" or "Muted until 20:00" or
  "Paused — click to resume". Updates bound to `Scheduler`'s published
  state.
  *Verify:* watch the menu label update in real time as boundaries
  cross.

**End-of-phase-3 demo (20 minutes):**

1. Hand-write `schedule.json` with a 60-second quiet period starting
   in 30 seconds.
2. Open 3 Claude Code terminals in parallel, start prompts in each.
3. At the boundary, all 3 terminals simultaneously go dark (within
   ~200ms of the same clock tick).
4. Submit prompts in each terminal during the quiet window; observe
   counters/state bookkeeping still updates (inspect state files
   directly).
5. At the next boundary, all 3 terminals snap back to their correct
   state simultaneously (broadcaster fires).
6. Menu bar label accurately reports "Muted until HH:MM:SS" during,
   and "Active — next mute in Xm" after.
7. Edit `schedule.json` to flip `master_active: false`; menu updates
   within 1s.
8. Sleep machine 3 minutes, wake; any crossed boundaries are handled.

**Phase 3 acceptance = demo passes + Scheduler matrix fixture passes +
no wall-clock-dependent tests are flaky.**

---

### Phase 4 — `tavs schedule` CLI

**Goal:** Allow command-line editing of `schedule.json`. Provides a
stable contract for power users, Linux users, and scripting. The app
reacts to CLI-initiated edits via fs-watch already built in Phase 3.

**Depends on:** Phases 2 (schema) and 3 (fs-watch).

**Tasks:**

- **T4.1** — Implement `src/cli/cmd-schedule.sh` dispatcher with
  subcommands:
  - `tavs schedule show` — print current rules + current `mute.state` if present, as a human-readable table.
  - `tavs schedule pause` — set `master_active: false`.
  - `tavs schedule resume` — set `master_active: true`.
  - `tavs schedule add-window --days mon,tue --start 08:00 --end 20:00 [--id foo]`
  - `tavs schedule add-quiet --kind hourly --start-minute 50 --end-minute 59 [--id bar]`
  - `tavs schedule add-quiet --kind fixed_daily --start 12:00 --end 13:00 [--id lunch]`
  - `tavs schedule remove <id>`
  - `tavs schedule validate` — re-validate file, report errors.
  - `tavs schedule list` — list rule ids + state (enabled/disabled).
  *Verify:* run each subcommand; validate the resulting JSON against
  the Swift `ScheduleStore.validate()` by running the app's
  `--validate-config` hidden flag. Should always agree.

- **T4.2** — Implement validation parity: CLI uses `jq` to enforce the
  same rules Swift enforces (time format, wrapping, empty list
  rejection). This is explicitly duplicated logic — acceptable because
  the CLI is user-invoked (not hot path) and catching errors early in
  the CLI is better UX than letting the app refuse the file later.
  Contract test: `tests/integration/schedule-evaluator-parity.bats`
  feeds N malformed JSONs and N valid JSONs to both CLI validator and
  Swift validator; outputs must agree in pass/fail.
  *Verify:* contract test passes.

- **T4.3** — Atomic writes: CLI uses `mktemp` in `~/.tavs/` + `mv` (same
  pattern as existing TAVS code).
  *Verify:* concurrent `tavs schedule add-window` calls from two shells
  — no torn writes observed (one or both succeed, file always valid
  JSON).

- **T4.4** — `docs/reference/scheduling.md` — full schema documentation
  including wrapping/overnight/DST semantics, plus all CLI subcommand
  examples.
  *Verify:* technical writer / fresh reader can configure the feature
  using docs alone.

**End-of-phase-4 demo (10 minutes):**

1. Start from empty `~/.tavs/schedule.json`.
2. `tavs schedule add-window --days mon,tue,wed,thu,fri --start 08:00 --end 20:00`
3. `tavs schedule add-quiet --kind hourly --start-minute 50 --end-minute 59`
4. `tavs schedule show` — prints nicely.
5. `tavs schedule remove top-of-hour-break` fails (generated id differs,
   so show error message); `tavs schedule list` gets the id, then remove
   succeeds.
6. `tavs schedule pause` → icon goes to Paused state within 1s (fs-watch
   from Phase 3).
7. `tavs schedule resume` → icon goes back.
8. `tavs schedule add-window --start 25:00 --end 30:00` → validation
   error with a clear message.

**Phase 4 acceptance = demo passes + parity contract test passes.**

---

### Phase 5 — Preferences UI (Schedule, Appearance, Identity tabs)

**Goal:** A usable GUI for the curated settings. User never needs to
touch `user.conf` or `schedule.json` by hand for common adjustments.

**Depends on:** Phases 2 (stores) and 3 (scheduler reacts).

**Tasks:**

- **T5.1** — `PreferencesView.swift` with three `TabView` tabs:
  Schedule, Appearance, Identity. Tab navigation works; window is
  resizable; Close button and ⌘W work.
  *Verify:* open, click each tab, close the window; reopen later and
  the tab that was last active is preserved.

- **T5.2** — **Schedule tab:** Two subsections — "Allowed Windows"
  (list editor) and "Quiet Periods" (list editor). Each row is
  editable inline. "Add window" / "Add quiet period" buttons with
  inline validation. "Master active" toggle at the top. Live status
  line at the bottom: "Currently: Active — next mute in 23 min".
  *Verify:* add a window ending in 2 minutes; close prefs; watch
  terminals go silent at the boundary. Status line updates in real
  time.

- **T5.3** — **Appearance tab:** Theme dropdown (9 presets), Title
  Mode picker (4 options), Face Mode picker (standard / compact),
  Compact Theme picker (enabled only when Face Mode = compact),
  Stylish Backgrounds toggle, Light/Dark Switching toggle. Every
  control two-way binds to `UserConfStore`.
  *Verify:* change theme to Nord; next prompt in any open session
  paints Nord colors. Round-trip: open prefs, change nothing, close;
  `diff user.conf` shows zero bytes.

- **T5.4** — **Identity tab:** Identity Mode picker (dual / single / off),
  Dir Icon Type picker (flags / plants / buildings / auto). Enabled/
  disabled state reflects identity mode (dir icon picker disabled when
  mode != dual).
  *Verify:* switch from dual to single; next prompt title drops the
  flag, keeps the animal.

- **T5.5** — Inline validation: Schedule Save button disabled when
  invalid (empty allowed_windows + master_active, time errors, etc.);
  error messages adjacent to the offending field.
  *Verify:* delete the last window while master_active is on; Save is
  disabled; hint text shows "Add at least one window, or pause TAVS
  from the menu bar".

- **T5.6** — Preferences window respects the rest of the app: menu bar
  icon reflects state while prefs is open; quitting from menu closes
  prefs cleanly.
  *Verify:* open prefs, quit from menu bar; prefs closes without
  prompting.

**End-of-phase-5 demo (15 minutes):**

1. Fresh install state (empty schedule.json, default user.conf).
2. Open prefs from menu bar.
3. Schedule tab: add a weekday 08:00–20:00 window; add a top-of-hour
   quiet period; close window.
4. Appearance tab: change theme to Dracula, title mode to "full",
   face mode to "compact", compact theme to "semantic". Close.
5. Identity tab: verify dual mode is default; switch dir icon type to
   "plants".
6. Open a Claude Code session; submit a prompt.
7. Observe: Dracula background; full title mode (face, icons,
   context); compact face eyes; animal session icon paired with a
   plant emoji as directory indicator.
8. `diff` on `user.conf` shows exactly the 5 keys we mutated; all
   comments and unknown keys intact.

**Phase 5 acceptance = demo passes + round-trip bytes test passes.**

---

### Phase 6 — Bundle, codesign, install, docs, end-to-end

**Goal:** Ship-ready `.app` bundle with login-item auto-start. The
user goes from `git clone` to "it works and persists across reboot" in
one command.

**Depends on:** Phases 1–5.

**Tasks:**

- **T6.1** — `src/cli/cmd-install-macos-app.sh`. Steps:
  1. `swift build -c release --package-path src/macos/TAVSApp`.
  2. Assemble `/tmp/TAVS-build/TAVS.app/Contents/` with `Info.plist`
     (every key from §4.5 codesign paragraph), `MacOS/TAVSApp`,
     `Resources/AppIcon.icns`.
  3. Check/create self-signed cert `TAVS-Local-Signing` in login
     keychain (one-time, `security` CLI, user consents to Keychain
     prompt).
  4. `codesign --force --deep --sign "TAVS-Local-Signing"
     /tmp/TAVS-build/TAVS.app` — fall back to `--sign -` on failure.
  5. `plutil -lint Contents/Info.plist` and `codesign -vv TAVS.app` —
     abort on failure.
  6. `cp -R` to `/Applications/TAVS.app` (replacing any prior).
  7. `open /Applications/TAVS.app` — app launches, registers
     `SMAppService.mainApp`, verifies `.status == .enabled`, reports to
     stdout via a `--reported-status` hidden flag.
  *Verify:* run the script on a clean macOS 13 VM. `codesign -dvv
  /Applications/TAVS.app` reports the expected signing identity.
  `SMAppService` status is `.enabled`.

- **T6.2** — `src/cli/cmd-uninstall-macos-app.sh`: unregister the login
  item, `rm -rf /Applications/TAVS.app`, preserve `~/.tavs/` entirely
  (schedule + user config).
  *Verify:* run after install; login item removed, schedule.json
  preserved.

- **T6.3** — `AppIcon.icns` — v1 acceptable: an SF Symbol rasterized
  to the four standard `.icns` sizes. Recipe in the install script,
  produced from a tiny helper Swift program or `sips` pipeline.
  *Verify:* bundle contains the icon file, macOS shows it in the menu
  bar, in the "App in login items" sheet, and in Activity Monitor.

- **T6.4** — `docs/reference/macos-menubar-app.md` — comprehensive user
  reference covering install, uninstall, update, menu bar tour,
  preferences tour, how scheduling works conceptually, how to use the
  CLI equivalents, troubleshooting checklist (login item didn't
  register / mute stuck / can't find icon). Plus the Gatekeeper
  `xattr -dr com.apple.quarantine` note (S3).
  *Verify:* a fresh reader can install + configure + verify working
  using only this document.

- **T6.5** — README updates: one new section "macOS Menu Bar App" with
  a 5-line quick start. Link to the full reference. CLAUDE.md update
  with "macOS App" subsection summarizing the arch + the new paths so
  future devs are oriented.
  *Verify:* run through the README quick-start on a clean VM.

- **T6.6** — `tests/e2e/menubar-scheduling.sh` end-to-end script:
  1. Install the app.
  2. Write a schedule with quiet period 30s from now.
  3. Spawn a mock shell (`script`/`expect`) that fires `trigger.sh`
     every 3s.
  4. Cross the boundary; assert no OSC bytes reach the mock TTY during
     the quiet window.
  5. Cross the un-mute boundary; assert bytes arrive within 500ms.
  6. Uninstall cleanly.
  *Verify:* script exits 0 on a fresh macOS 13 VM. Logs captured to
  `/tmp/tavs-e2e-<timestamp>.log`.

- **T6.7** — Reboot-survival verification (manual): after install,
  reboot the machine. From login to menu bar icon visible, time it
  with a stopwatch (≤5s). Observe scheduler has projected the current
  mute state (inspect `mute.state` timestamp ≤5s old).
  *Verify:* passes on a fresh macOS 13 VM.

**End-of-phase-6 demo (final acceptance — 30 minutes):**

*This is the final product demo. If it passes, the project ships.*

1. On a clean macOS 13 VM: clone the repo. Run
   `./tavs install macos-app`. Consent to Keychain prompt for cert
   creation. Consent to the login-item prompt macOS surfaces.
2. Menu bar icon appears. Click it: menu shows "Active — schedule
   empty" or "Active — no rules configured". Click "Open
   Preferences…".
3. In Preferences → Schedule: add a weekday 08:00–20:00 window; add a
   top-of-hour quiet period. Close.
4. Menu bar label now shows "Active — next mute in N minutes" (or
   "Muted until HH:MM:SS" if we're currently in a quiet minute).
5. Open 4 Claude Code terminals in parallel. Submit prompts in each.
6. Adjust the system clock (or simply wait — if the demo is at :49,
   just wait 1 minute; otherwise quickly add a quiet period ending in
   2 minutes as a test rule).
7. At the boundary, all 4 terminals simultaneously go dark (plain
   shells, no TAVS visuals).
8. Submit prompts in each terminal during the quiet window. Claude
   Code still works; counters still accurate (inspect state files
   directly).
9. At the next boundary, all 4 terminals snap back to the correct
   visual state simultaneously.
10. Click menu bar icon → "Pause TAVS". All terminals immediately
    silent. Icon switches to paused state.
11. Click "Resume TAVS". Terminals snap back.
12. In Preferences → Appearance, change theme to Nord. Close. Submit a
    prompt; Nord colors appear.
13. `kill -9 $(pgrep TAVSApp)`. Wait 2 minutes. Terminals resume
    normal painting on their own (liveness check).
14. `open /Applications/TAVS.app`. App relaunches; scheduler resumes.
15. Reboot the VM. Log in. Start a stopwatch at password-accepted. By
    t=5s, menu bar icon is visible and `~/.tavs/mute.state` mtime is
    within 5s of now.

**Final acceptance = all 15 demo steps pass on a clean VM.**

---

## 8. Constraints & Boundaries

### Out of scope (v1)

- **Manual overrides** — snooze presets, force-unmute mid-quiet, auto-pause
  on screen-share detection. Schema reserves `manual_override` shape for
  v2.
- **Full `user.conf` parity** — advanced keys (per-agent faces, per-state
  title formats, palette tuning, compact theme variants, spinner styles)
  remain CLI-only.
- **Multi-user machines** — the new UID-namespaced paths are safe against
  collision, but the app is not tested on shared Macs. Legacy
  `/tmp/tavs/` paths for session-state/identity/title-state remain
  single-user-only (pre-existing).
- **Notifications** — no banners or alerts on mute transitions. Menu bar
  icon is the only surface.
- **Signed / notarized distribution** — v1 is self-signed-cert (or ad-hoc
  fallback). Developer ID and notarization deferred to v2.
- **Homebrew cask** — deferred.
- **Windows / Linux GUI** — Mac-only app. Shell changes are portable and
  no-op without the app.
- **macOS < 13** — app refuses to run; shell changes still work.

### Technical constraints

- Hot-path budget (D29): stage-0 marginal overhead <2ms over pre-change
  ~57ms baseline. Total muted-trigger runtime unchanged from baseline
  because full dispatch runs for bookkeeping.
- No new shell dependencies in the hot path. `jq` allowed only in
  user-invoked `tavs schedule` CLI commands.
- POSIX atomic writes (write-temp + rename in same directory) for every
  file the app owns.
- macOS 13+ only for the app. Shell parts work on any POSIX.
- Swift code budget: <1000 LOC total (excluding tests).
- Single-user install assumed.

### Dependencies

- Swift 5.9+ / Xcode 15+ command-line build tools for packaging. Users
  running the already-built bundle need only macOS 13+.
- System APIs: `MenuBarExtra` (13+), `SMAppService` (13+),
  `DispatchSource` (timer + fs-watch), `NSWorkspace` (wake), `Process`
  (via `ProcessRunner` only).
- No third-party Swift packages.
- Existing `tavs sync` discipline (both marketplace + cache dirs).

---

## 9. Rejected Alternatives

| Alternative | Why Rejected | Reference |
|-------------|--------------|-----------|
| SwiftBar plugin + launchd + Swift prefs | Three artifacts, SwiftBar prerequisite, split UX | D01 |
| Pure shell + SwiftBar + launchd | No good prefs UX | D01 |
| Python + rumps | `rumps` unmaintained; Gatekeeper friction | D01 |
| Partial mute (bg only) | User directive for full quiet | D02 |
| Cron single expression | Opaque; bad for GUI editor | D03 |
| Lazy unmute | User directive for zero-lag | D04 |
| Full `user.conf` GUI parity | 40+ controls, low ROI | D05 |
| Three-way Auto/Force toggle | Harder icon encoding; achievable via master + schedule | D06 |
| Persistent `~/.cache/tavs/pending/` | TTY device numbers rotate on reboot | D07 |
| Mute gate as early exit | Breaks counter, identity, session-state, idle worker | D21 |
| Cache input args + re-dispatch | Incomplete state capture (env, priority, counter) | D12 |
| Shell rule evaluator | Dual-evaluator drift risk | D10 |
| `lsof` per-TTY liveness | 100-300ms × N TTYs = seconds of lag | D09 |
| Shell evaluates schedule.json with `jq` | Hot-path dependency | D10 |
| Xcode project in git | `.xcodeproj` metadata is noisy | D14 |
| Truly unsigned `.app` | SMAppService rejects | D16 |
| Ad-hoc codesign for SMAppService persistence | Content-hash rotates on rebuild (TN3127) | D16 |
| Empty `allowed_windows` → always-allowed | UX trap | D26 |
| Shell-injection test seam | Security smell | D27 |
| <10ms mute-gate in sourced helper | Numerically impossible (57ms baseline) | D29 |
| Byte-identical JSON round-trip | `JSONEncoder` not byte-stable across Swift versions | D31 |
| Wall-clock timer tests (`±1s`) | CI scheduling drift | D30 |
| `DispatchSource` on target file directly | Dead vnode after atomic rename | D28 |

---

## 10. Verification Strategy

### 10.1 Automated tests

**Shell (bats-core), `tests/unit/`:**
- `mute-gate.bats` — every function with injected clock + mock filesystem.
- `schedule-evaluator-parity.bats` — CLI validator vs Swift validator
  contract test (§Phase 4).

**Shell (bats-core), `tests/integration/`:**
- `emit-osc.bats` — `/dev/pts` mock TTY; byte-diff each state in both
  muted and unmuted modes.
- `idle-worker-mute.bats` — spawn a worker, inject mute, assert
  silence.
- `baseline-regression.bats` — pre- and post-change OSC-byte parity
  with `mute.state` absent.
- `priority-pinning.bats` — muted permission pinned, then muted
  processing; pending cache = permission bytes.
- `counter-integrity.bats` — muted start/stop sequences leave counter
  accurate.
- `identity-teardown.bats` — muted session-end releases locks.
- `liveness.bats` — stale heartbeat / expired epoch / dead PID all
  treated as unmuted.

**Shell, `tests/bench/`:**
- `hot-path.sh` — 100 runs × 3 trials median; assert post-change
  baseline ≤ pre-change + 5ms (D29).

**Swift (XCTest via `swift test`):**
- `ScheduleStoreTests` — parse, serialize, semantic round-trip,
  validation edge cases.
- `UserConfStoreTests` — unknown-key preservation, comment
  preservation, byte-identical no-change round-trip.
- `SchedulerTests` — 30+ rule-eval fixtures with `VirtualClock`; DST
  cases; empty-list rejection; overnight windows; wrapping minutes.
- `BroadcasterTests` — `MockProcessRunner` + fake FS; pruning on
  write failure; parallelism.
- `MuteStateTests` — atomic write, format stability.
- `LoginItemManagerTests` — mocked `SMAppService`.
- `FileWatcherTests` — parent-dir pattern, debounce, rename handling.

**End-to-end, `tests/e2e/`:**
- `menubar-scheduling.sh` — full install → configure → observe
  mute/unmute cycle → uninstall (Phase 6 T6.6).

**Coverage targets:**
- ≥80% line coverage for `Scheduler`, `ScheduleStore`, `UserConfStore`,
  `Broadcaster`, `MuteState`, `FileWatcher`.
- Every public function in `mute-gate.sh` has ≥1 positive and ≥1
  negative test.

### 10.2 Observability during development

- **Shell:** existing `DEBUG_ALL=1` logs. New `DEBUG_MUTE=1` flag logs
  stage-0 decisions and emit_osc suppressions to `/tmp/tavs-mute-trace.log`.
- **Swift:** `os_log` with subsystem `com.cstelmach.tavs`. Developer
  can `log stream --predicate 'subsystem == "com.cstelmach.tavs"'` to
  see every rule evaluation, transition, broadcast, and file event.
- **Hidden CLI flags on the app:** `TAVSApp --validate-config`,
  `TAVSApp --reported-status`, `TAVSApp --dump-state`, for CI and
  debugging.

### 10.3 Manual verification matrix

Run on the last Phase 6 VM:
- iTerm2 ✓
- Ghostty ✓
- Kitty ✓
- Terminal.app ✓
- WezTerm ✓

Each terminal runs Phase 6 step 7 (mute cycle) and step 9 (snap-back).
Document any per-terminal quirks in the troubleshooting section.

### 10.4 Final user-acceptance demo

See Phase 6 end-of-phase demo (15-step script). This is the single
canonical demo. If all 15 steps pass on a clean macOS 13 VM, the
project is ready to ship.

---

## 11. Open Questions

- **Legacy `/tmp/tavs/` multi-user fix** — refactor existing session
  state / identity / title state to use `$TAVS_RUNTIME_DIR`.
  Pre-existing; separate spec.
- **Manual overrides (v2)** — snooze, force-unmute, auto-pause during
  screen share. Schema reserves shape.
- **Linux scheduling daemon (v2)** — a small shell/systemd-timer
  companion for Linux users.
- **Developer ID signing + notarization + Homebrew cask (v2)** —
  required for public distribution.
- **Custom `.icns` artwork (polish)** — v1 uses a rasterized SF Symbol.
- **Theme-change-during-mute replay lag** — by design (D12). If this
  becomes annoying, revisit the "render on replay" approach.

---

## 12. Review Notes

### Reviewed by: Gemini (`gemini-3.1-pro-preview`) — 2026-04-20

**Verdict:** BLOCKED (Completeness 4, Consistency 3, Testability 4,
Scope 6, Clarity 6 → overall 3/10). 15 findings, all CONFIRMED against
source code. Root cause for 4 of the 7 CRITICAL issues: mute gate being
an early-exit rather than a write suppressor.

### Reviewed by: Codex (`gpt-5.4`, reasoning=high) — 2026-04-20

**Verdict:** REQUEST CHANGES — 7 Blocking, 7 Significant, 5 Suggestions,
4 Good-Decision affirmations. Four new blocking findings not caught by
Gemini, all CONFIRMED against source and Apple documentation (TN3127).

### Changes from reviews (revisions 2–4)

- **SPEC-001 / Codex B7 → D22:** UID-namespaced runtime dir for new paths.
- **SPEC-002 → D10:** Dropped shell rule evaluator; Swift is the only
  evaluator; CLI only edits the JSON.
- **SPEC-003 / SPEC-008 → D21:** Mute gate is suppression, not
  short-circuit. Full dispatch always runs.
- **SPEC-004 → D12, D21:** Pending cache holds rendered bytes post-
  dispatch; session-state priority pinning respected naturally.
- **SPEC-005 / Codex B2 → D16:** Self-signed cert (stable identity);
  ad-hoc as documented fallback.
- **SPEC-006 → D23:** Shell validates heartbeat, UNTIL_EPOCH, and APP_PID.
- **SPEC-007 → D27:** `ProcessRunner` protocol.
- **SPEC-009 → D25:** Idle worker mute is Phase 1 acceptance, not Open
  Question.
- **SPEC-010 → D09:** Dropped `lsof`; write-then-handle-error.
- **SPEC-011 / SPEC-012 → D24, §5.2:** Wrapping, overnight, DST explicit.
- **SPEC-013:** Swift scaffold + `Codable` types in Phase 2 before CLI.
- **SPEC-014 → D26:** Empty `allowed_windows` rejected at validation.
- **SPEC-015:** Dissolved by D12 (bytes not args).
- **Codex B1 → D16, Phase 6:** Bundle packaging contract enumerates all
  required `Info.plist` keys.
- **Codex B3 → D29, §4.5:** Stage-0 inline + stage-1 sourced split.
- **Codex B6 → D28:** Parent-dir fs-watch + 100ms debounce.
- **Codex S6 → D31:** Semantic round-trip, not byte-identical, for JSON.
- **Codex S7 → D30:** `Clock` + `TimerScheduler` protocols for
  deterministic tests.
- **Revision 4:** Expanded to team-implementable detail — user
  stories, per-task breakdown with direct-feedback verification, final
  canonical demo script.

### Accepted risks (final)

- **Theme change during mute** — replay shows pre-change render; next
  hook re-renders. One-cycle visual lag. Documented. (D12)
- **Legacy `/tmp/tavs/` single-user** — pre-existing bug; v1 doesn't
  fix it. New paths safe; legacy paths inherit current behavior.
- **Ad-hoc codesign fallback** — if self-signed cert creation fails,
  login-item persistence becomes best-effort. Documented.
- **No Linux GUI scheduling in v1** — CLI edits `schedule.json`
  everywhere; only Mac app projects `mute.state`.
- **Broadcaster cross-session writes** — Mac app writes to `/dev/ttysXXX`
  devices; if the session has moved between mute and broadcast, the
  bytes paint the wrong session briefly. Next hook refreshes. Acceptable.

### Implementation readiness

Both reviewers' blockers have concrete spec resolutions. Revision 4
additionally provides phase-level task breakdowns, per-task verification
with direct-feedback steps, and a canonical final demo. **Ready for
Phase 1.**
