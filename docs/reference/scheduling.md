# Scheduling Reference

**Last Updated:** 2026-04-21 | **Version:** 1.0

TAVS.app adds time-based muting so terminal visual signals only fire
during your active work hours. This document covers the schedule file
format, rule evaluation semantics, and the `tavs schedule` CLI.

---

## Quick Start

```bash
# Add a weekday work window
tavs schedule add-window --days mon,tue,wed,thu,fri --start 08:00 --end 20:00

# Silence the last 10 minutes of every hour
tavs schedule add-quiet --kind hourly --start-minute 50 --end-minute 59

# Silence lunch break
tavs schedule add-quiet --kind fixed_daily --start 12:00 --end 13:00 --id lunch

# Check current state
tavs schedule show

# Pause everything temporarily
tavs schedule pause

# Resume
tavs schedule resume
```

---

## Schema: `~/.tavs/schedule.json`

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
    },
    {
      "id": "lunch-break",
      "enabled": true,
      "kind": "fixed_daily",
      "start": "12:00",
      "end": "13:00"
    }
  ]
}
```

### Top-Level Fields

| Field | Type | Description |
|-------|------|-------------|
| `version` | int | Schema version (always `1`) |
| `master_active` | bool | Global toggle. `false` = all TAVS output muted |

### Allowed Windows

TAVS only produces visual output when `now` falls inside at least one
enabled window. Windows define when TAVS is **active**.

| Field | Type | Constraints |
|-------|------|-------------|
| `id` | string | Non-empty, unique identifier |
| `enabled` | bool | Disabled windows are skipped during evaluation |
| `days` | array | One or more of: `mon`, `tue`, `wed`, `thu`, `fri`, `sat`, `sun` |
| `start` | string | `HH:MM` format, two digits each. `HH` in [00,23], `MM` in [00,59] |
| `end` | string | Same format as `start`. Must differ from `start` |
| `hard` | bool (optional) | When true, the mute OUTSIDE this window's hours becomes a hard lock (challenge-gated resume). Absent means false. See [Hard Lock](hard-lock.md). |

### Quiet Periods

Quiet periods carve out muted intervals inside allowed windows.

#### Hourly

| Field | Type | Constraints |
|-------|------|-------------|
| `id` | string | Non-empty |
| `enabled` | bool | Disabled periods are skipped |
| `kind` | string | `"hourly"` |
| `start_minute` | int | 0-59 |
| `end_minute` | int | 0-59 |

#### Fixed Daily

| Field | Type | Constraints |
|-------|------|-------------|
| `id` | string | Non-empty |
| `enabled` | bool | Disabled periods are skipped |
| `kind` | string | `"fixed_daily"` |
| `start` | string | `HH:MM`, same rules as window times |
| `end` | string | `HH:MM`, must differ from `start` |

Both quiet-period kinds also accept the optional `hard` flag: a hard quiet
period is a hard lock while inside it (challenge-gated resume, see
[Hard Lock](hard-lock.md)). The master pause is never hard.

---

## Validation Rules

Only enabled entries are validated. Disabled entries skip all checks.

1. **master_active + empty windows:** If `master_active` is `true`,
   there must be at least one enabled allowed window.
2. **Empty id:** Every entry must have a non-empty `id`.
3. **Empty days:** Enabled windows must have at least one day.
4. **Time format:** Must be exactly `HH:MM` with two-digit components.
   `8:00` is invalid; `08:00` is valid. Hours 00-23, minutes 00-59.
5. **Zero-length:** `start == end` is invalid (for both windows and
   fixed_daily quiet periods).
6. **Minute range:** `start_minute` and `end_minute` must be in [0,59].

---

## Overnight Windows

When `end < start` in a window, the window crosses midnight:

```json
{
  "id": "friday-night",
  "enabled": true,
  "days": ["fri"],
  "start": "22:00",
  "end": "02:00"
}
```

This window is active from **22:00:00 Friday** through **02:00:00
Saturday**, regardless of whether Saturday appears in `days`. The window
anchors on each listed day and extends past midnight.

---

## Wrapping Minute Ranges

When `end_minute < start_minute` in an hourly quiet period, the range
wraps past the hour boundary:

```json
{
  "id": "around-the-hour",
  "enabled": true,
  "kind": "hourly",
  "start_minute": 55,
  "end_minute": 5
}
```

Current minute `m` is inside this period iff `m >= 55 OR m <= 5`.
This mutes from :55 through :05 of the next hour.

---

## DST Behavior

All evaluation uses wall-clock local time via the system calendar.

- **Spring forward:** If a boundary falls within the skipped hour
  (e.g., 02:30 when clocks jump from 02:00 to 03:00), that boundary
  simply does not fire. The next valid boundary activates normally.
- **Fall back:** If a boundary falls within the repeated hour
  (e.g., 01:30 when clocks fall from 02:00 back to 01:00), the
  boundary fires twice — once in each pass through that hour.
- **No UTC math:** The scheduler uses `Calendar(identifier: .gregorian)`
  with the system timezone. All times in `schedule.json` are local.

---

## Evaluation Logic

TAVS is **active** (unmuted) iff all three conditions are true:

1. `master_active` is `true`
2. Current time is inside at least one enabled `allowed_windows` entry
3. Current time is **not** inside any enabled `quiet_periods` entry

Otherwise, TAVS is **muted**. The mute reason in `~/.tavs/mute.state`
reflects which condition failed: `master_paused`, `schedule_window`,
or `quiet_period`.

---

## CLI Reference

### `tavs schedule show`

Prints the current schedule configuration and mute state as a
human-readable table.

```
$ tavs schedule show

Schedule Configuration
──────────────────────────────────────────────────
  Master: active

  Allowed Windows (1)
    on   weekday-core-hours             mon,tue,wed,thu,fri  08:00-20:00

  Quiet Periods (1)
    on   top-of-hour-break              hourly :50-:59

  Current Mute State
    Active
```

### `tavs schedule list`

Lists all rule IDs with their state and type.

```
$ tavs schedule list
ID                                  STATE    TYPE
---                                 -----    ----
weekday-core-hours                  enabled  window
top-of-hour-break                   enabled  quiet/hourly
```

### `tavs schedule pause`

Sets `master_active` to `false`. The TAVS.app detects this via
filesystem watch and writes `mute.state` within 1 second.

### `tavs schedule resume`

Sets `master_active` to `true`. Warns if no enabled windows exist.

### `tavs schedule add-window`

```bash
tavs schedule add-window \
  --days mon,tue,wed,thu,fri \
  --start 08:00 \
  --end 20:00 \
  [--id custom-name]
```

If `--id` is omitted, a deterministic ID is generated from the
parameters (e.g., `window-mon-tue-wed-thu-fri-08-00-20-00`).

### `tavs schedule add-quiet`

```bash
# Hourly quiet period
tavs schedule add-quiet \
  --kind hourly \
  --start-minute 50 \
  --end-minute 59 \
  [--id name]

# Fixed daily quiet period
tavs schedule add-quiet \
  --kind fixed_daily \
  --start 12:00 \
  --end 13:00 \
  [--id lunch]
```

### `tavs schedule remove <id>`

Removes a rule by ID. Use `tavs schedule list` to find IDs.

```
$ tavs schedule remove nonexistent
Error: No rule found with id 'nonexistent'
Available ids:
  weekday-core-hours
  top-of-hour-break
```

### `tavs schedule validate`

Re-validates `~/.tavs/schedule.json` and reports errors.

```
$ tavs schedule validate
Schedule is valid.
```

---

## File Lifecycle

- `schedule.json` is created automatically on first `add-window`,
  `add-quiet`, `pause`, or `resume` command.
- All writes are atomic (`mktemp` + `mv` on the same filesystem).
- The TAVS.app watches `~/.tavs/` for changes and re-evaluates
  the schedule within 100ms of any write.
- Concurrent CLI invocations are safe: one or both succeed, and the
  file is always valid JSON.
