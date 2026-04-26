# macOS Menu Bar Companion App

**Version:** 3.0.0
**Requires:** macOS 13+ (Ventura or later)

The TAVS menu bar app adds two capabilities that shell hooks alone cannot provide:

1. **Scheduling** — TAVS paints backgrounds and titles only inside user-defined
   time windows (e.g., 08:00–20:00 weekdays) and goes silent during quiet periods
   (e.g., the last 10 minutes of every hour).
2. **Curated preferences** — a Mac-native editor for the most-used TAVS settings
   without touching config files.

---

## Install

```bash
./tavs install macos-app
```

This command:
1. Builds the Swift app from source (release mode)
2. Assembles the `.app` bundle with icon and Info.plist
3. Creates a self-signed certificate for codesigning (one-time, you'll see a
   Keychain prompt)
4. Signs the bundle (falls back to ad-hoc if cert creation fails)
5. Copies to `/Applications/TAVS.app`
6. Launches the app and registers it as a login item

After install, a menu bar icon appears (hexagonal grid when active,
pause circle when muted).

### First Launch

macOS may show a Gatekeeper dialog. If you see "TAVS can't be opened because
Apple cannot check it for malicious software":

```bash
xattr -dr com.apple.quarantine /Applications/TAVS.app
```

Then open the app again. The install script does this automatically, but
macOS may re-quarantine on certain system updates.

### Login Item

The app registers itself to start at login via `SMAppService`. You can verify
and control this in:

**System Settings → General → Login Items → TAVS**

If the login item doesn't persist across reinstalls, your system may have
rejected the signing certificate. The app still works — you'll just need to
launch it manually after reboots. See [Troubleshooting](#troubleshooting).

---

## Uninstall

```bash
./tavs uninstall macos-app
```

This removes:
- `/Applications/TAVS.app`
- `~/.tavs/mute.state` (so shells resume normal painting immediately)
- Pending OSC caches in `/tmp/tavs-*/pending/`

This preserves:
- `~/.tavs/user.conf` (your settings)
- `~/.tavs/schedule.json` (your schedule rules)
- All other `~/.tavs/` files

---

## Update

```bash
./tavs install macos-app
```

The install command replaces any existing installation. Your settings and
schedule are preserved since they live in `~/.tavs/`.

---

## Menu Bar Tour

Click the menu bar icon to see:

| Item | Description |
|------|-------------|
| **Status line** | "Active — next mute in 23 min" or "Muted until 20:00" or "Paused" |
| **Pause/Resume** | Toggle master pause. Overrides schedule. |
| **Open Preferences…** | Opens the three-tab settings window (⌘,) |
| **Quit TAVS** | Stops the app. Shells resume normal painting within 2 minutes. |

### Icon States

| Icon | Meaning |
|------|---------|
| Hexagonal grid (filled) | Active — TAVS is painting terminals |
| Pause circle (filled) | Muted or paused — terminals are dark |

---

## Preferences

Open via the menu bar → "Open Preferences…" or ⌘, (when the app is focused).

### Schedule Tab

Controls **when** TAVS is active.

**Master Active** toggle at the top enables/disables the entire schedule.
When off, all terminals are muted regardless of time windows.

**Allowed Windows** — time ranges when TAVS is allowed to paint:
- Each window has days (Mon–Sun), start time, and end time
- Overnight windows work: `22:00–02:00` on Friday means 22:00 Fri to 02:00 Sat
- Add multiple windows for different schedules (e.g., weekdays + Saturday morning)
- At least one enabled window is required when master is active

**Quiet Periods** — recurring mute windows within allowed time:
- **Hourly**: mute from minute X to minute Y every hour (e.g., :50–:59)
- **Fixed daily**: mute from HH:MM to HH:MM every day (e.g., 12:00–13:00 lunch)
- Quiet periods are checked after allowed windows — they carve out silence

**Save** button validates rules before saving. Invalid configurations
(empty windows with master active, bad time formats) show a hint message
and disable the Save button.

**Status line** at the bottom shows the current schedule state in real time.

### Appearance Tab

Controls **how** terminals look. Changes persist to `~/.tavs/user.conf` and
take effect on the next hook event.

| Setting | Options | Default |
|---------|---------|---------|
| Theme Preset | nord, dracula, solarized-dark, solarized-light, tokyo-night, catppuccin-{latte,frappe,macchiato,mocha} | catppuccin-frappe |
| Title Mode | skip-processing, prefix-only, full, off | skip-processing |
| Face Mode | standard, compact | compact |
| Compact Theme | squares, semantic, circles, mixed | squares |
| Stylish Backgrounds | on/off | off |
| Light/Dark Switching | on/off | off |

The Compact Theme picker is only enabled when Face Mode is set to "compact".

### Identity Tab

Controls session and directory identification in terminal titles.

| Setting | Options | Default |
|---------|---------|---------|
| Identity Mode | dual, single, off | dual |
| Dir Icon Type | flags, plants, buildings, auto | flags |

The Dir Icon Type picker is only enabled when Identity Mode is "dual"
(because only dual mode uses directory icons).

---

## CLI Equivalents

Everything the app does can also be done from the command line:

| App Action | CLI Equivalent |
|------------|---------------|
| Pause | `tavs schedule pause` |
| Resume | `tavs schedule resume` |
| Add window | `tavs schedule add-window --days mon,fri --start 08:00 --end 20:00` |
| Add quiet period | `tavs schedule add-quiet --kind hourly --start-minute 50 --end-minute 59` |
| Remove rule | `tavs schedule remove <id>` |
| Show schedule | `tavs schedule show` |
| Change theme | `tavs set theme nord` |
| Change title mode | `tavs set title-mode full` |

The app watches `~/.tavs/schedule.json` for changes, so CLI edits take effect
within ~200ms without restarting the app.

See [Scheduling Reference](scheduling.md) for the full schema documentation.

---

## How Scheduling Works

### Rule Evaluation

TAVS is **active** when all three conditions are true:
1. `master_active` is `true`
2. Current time is inside at least one enabled allowed window
3. Current time is **not** inside any enabled quiet period

The app evaluates rules every 60 seconds (heartbeat) and at every
boundary transition (start/end of windows and quiet periods).

### Mute State Protocol

The app writes `~/.tavs/mute.state` — a small key-value file that the shell
reads on every hook event. The file includes:

- `MUTED` — current verdict (true/false)
- `REASON` — why (schedule_window, quiet_period, master_paused)
- `UNTIL_EPOCH` — when mute is expected to end
- `WRITTEN_EPOCH` — heartbeat timestamp (bumped every 60s)
- `APP_PID` — for liveness verification

### Liveness Protocol

The shell validates all four signals before suppressing output:
- `MUTED="true"` — explicit mute verdict
- `UNTIL_EPOCH` is 0 or in the future
- `WRITTEN_EPOCH` is within the last 120 seconds
- `APP_PID` is alive (`kill -0`)

If any check fails, the shell treats the state as "app is dead" and resumes
normal painting. This means:
- **App crashes → terminals resume within 2 minutes**
- **App not installed → zero behavior change**
- **Stale mute.state → ignored**

### Broadcast on Unmute

When transitioning from muted to unmuted, the app writes cached OSC bytes
directly to every live terminal. This means all terminals snap back to their
correct visual state simultaneously — no need to wait for the next hook event.

### Paused Visual State

While muted, the app paints a distinctive visual on every registered TTY so a
paused terminal is unmistakable from an idle one:

| Element | Value |
|---|---|
| Background | `#3A3A3A` (mid-grey) |
| Title | *(unchanged — TAVS does not touch the tab label on pause)* |
| Background image (iTerm2) | Cleared |
| Palette | Reset to terminal defaults |

The grey background is the single user-facing pause signal. TAVS deliberately
does not emit an OSC 0 title during pause: an empty OSC 0 blanks user-set tab
names, and a "Paused" label would stick on idle terminals that never fire a
hook during the mute window, leaving them mislabelled after resume. Dropping
the title entirely makes "instantly back" true by construction — there is no
title state for resume to restore. The menu-bar status line still surfaces the
precise mute reason (manual pause, schedule window, quiet period).

### Transition Ordering

Ordering on the two transitions is load-bearing:

**Active → muted:**
1. `writeMuteState(muted:true)` — shell's stage-0 gate now suppresses hook OSC
   output to `pending/<tty>.osc` instead of the TTY
2. `broadcastPaused()` — paint grey on every active TTY

**Muted → active:**
1. `broadcastPausedClear()` — reset background + palette on every TTY (title is
   intentionally **not** reset; empty OSC 0 would blank user-configured tab
   names in `TAVS_TITLE_MODE=prefix-only`)
2. `broadcast()` — drain `pending/*.osc` so each TTY sees the latest bookkept
   state
3. `writeMuteState(muted:false)` — shell resumes normal painting
4. `clearPending()` — discard any bytes hooks appended to `pending/` during the
   tiny window between steps 2 and 3; those bytes reflect mid-transition state
   that is stale by definition and would otherwise replay as "current" on a
   later unmute cycle

### Restart Semantics

On every app start, `Scheduler.start()` seeds `previousMuted` from the
on-disk `mute.state` if it exists. This lets a restart-after-crash correctly
fire the unmute transition if the schedule now says active — without the seed,
a crash while muted followed by a relaunch into an unmuted schedule would
leave terminals painted grey indefinitely.

### Known Trade-offs

| Behaviour | Why |
|---|---|
| Idle sessions (no hook during mute) return to palette defaults on unmute, not their pre-pause idle gradient | The app has no way to repaint the per-session idle stage; the owning session's idle worker repaints on its next tick. |
| Pause signals background-only, no tab-title label | Emitting a title on pause either blanks user-set tab names (empty OSC 0) or sticks on idle terminals. Resume instant-ness is prioritised over an explicit "Paused" label; the menu-bar status line surfaces the mute reason instead. |

### DST Behavior

Schedule boundaries use wall-clock time (system local timezone):
- **Spring forward**: A boundary at 02:30 simply doesn't fire (02:30 doesn't exist)
- **Fall back**: A boundary at 01:30 fires twice (01:30 exists twice)

---

## Architecture

```
TAVS.app (Swift)                    Shell (bash)
┌──────────────┐                    ┌──────────────────┐
│ Scheduler    │──writes──►         │ trigger.sh        │
│ (rule eval)  │        mute.state  │ (stage-0 gate)   │
│              │                    │                   │
│ Broadcaster  │──writes──►         │ emit_osc()       │
│ (on unmute)  │     /dev/ttysXXX   │ (choke point)    │
│              │                    │                   │
│ FileWatcher  │◄──watches──        │ active-ttys/      │
│ (schedule)   │     ~/.tavs/       │ pending/*.osc     │
└──────────────┘                    └──────────────────┘
```

The app and shell communicate only through files on disk:
- `~/.tavs/schedule.json` — schedule rules (app + CLI write, app reads)
- `~/.tavs/mute.state` — projected state (app writes, shell reads)
- `/tmp/tavs-$UID/active-ttys/` — live TTY registry (shell writes, app reads)
- `/tmp/tavs-$UID/pending/*.osc` — cached OSC bytes (shell writes, app reads on unmute)

---

## Troubleshooting

### Menu bar icon doesn't appear

1. Check the app is running: `pgrep -x TAVSApp`
2. Try launching manually: `open /Applications/TAVS.app`
3. Check Console.app for errors: filter by `com.cstelmach.tavs`

### Terminals stay muted after app crash

The liveness protocol should resume painting within 2 minutes.
If stuck longer:
```bash
rm ~/.tavs/mute.state
```

### Login item doesn't persist across reinstalls

This happens when the codesigning identity changes between builds.
The app falls back to ad-hoc signing if the self-signed certificate
can't be created, which means each rebuild gets a new identity.

Fix: ensure the `TAVS-Local-Signing` certificate exists in your login
keychain:
```bash
security find-identity -v -p codesigning ~/Library/Keychains/login.keychain-db | grep TAVS
```

If missing, the next `tavs install macos-app` will recreate it.

### Schedule not taking effect

1. Check the app is running: `pgrep -x TAVSApp`
2. Verify schedule is valid: `tavs schedule validate`
3. Check mute.state: `cat ~/.tavs/mute.state`
4. Check heartbeat is fresh: `WRITTEN_EPOCH` should be within 120s of now

### Theme change doesn't apply

Theme changes take effect on the **next hook event** (next prompt submission,
permission request, etc.). They don't retroactively repaint existing terminals.

### App uses too much CPU

The app should be nearly idle (waking only on timer boundaries and file
changes). If CPU usage is high, check:
1. File watcher storm: another process rapidly modifying `~/.tavs/`
2. Schedule with very short quiet periods (< 1 minute gaps)

Report issues at: https://github.com/cstelmach/terminal-agent-visual-signals/issues

### Debug logging

```bash
log stream --predicate 'subsystem == "com.cstelmach.tavs"' --level debug
```

This shows every rule evaluation, transition, broadcast, and file event
from the app.

For shell-side mute debugging:
```bash
DEBUG_MUTE=1 ./src/core/trigger.sh processing
cat /tmp/tavs-mute-trace.log
```
