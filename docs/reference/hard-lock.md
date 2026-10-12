# Hard Lock Reference

**Last Updated:** 2026-10-12 | **Version:** 1.2

The hard lock is a visual commitment device: during an effective locked period,
registered terminals receive the pause visual and a `🔒 locked until HH:MM` title.
Agent signals are suppressed. Its ordinary time-boxed unlock uses a challenge.
Persistent visual suspension overrides that effective policy without a challenge,
while retaining saved rules and grants. Restrictions remain reversible during testing;
stronger locks are deferred until recovery and required acceptance are validated.

## Concepts

| Concept | Meaning |
|---------|---------|
| Soft pause | Today's mute (schedule windows, quiet periods, master pause). One click to reverse. Fail-open: dies with the app. |
| Hard lock | A pause that is challenge-gated to reverse and fail-closed: it holds until its end time even if TAVS.app is killed. |
| Unlock grant | Time-boxed suspension of a hard lock after passing the challenge. When it expires, the lock re-engages automatically. |
| Challenge | A pre-set password, a typing puzzle, or both (see below). |

A hard lock always implies the mute. A grant suspends only hard-caused
muting; soft rules are never affected by grants.

## Independent recovery implementation

The source CLI accepts `tavs recover` and `tavs recover --resume`. It atomically
saves persistent suspension/resumption before resolving the native helper, forwards
the helper's result and returns nonzero for missing/unsupported or failed recovery.
It preserves schedules and lock/grant definitions. Resumption leaves focus Off.

The source-built helper implements recovery before UI/login initialization. Its exact capability
query is `--validate-config --managed-output-capabilities`, returning
`tavs-managed-output-schema=1`. Recovery reports JSON with `stateSaved`, `catalogueAvailable` and
per-target `restored`, `vanished`, `unaffected` or `failed` outcomes. A missing helper leaves the
saved policy intact and reports failure. Resume reads current rules and cannot replay historical
pending alerts or titles.

Connected Swift tests and public CLI recovery/resumption pass with owned PTYs and injected
catalogues. Independent review remains in progress. This source has not been installed into the
working app; physical terminal restoration is unverified.

## Lock sources

1. **Schedule rules marked hard.** Add `"hard": true` to an allowed window
   or quiet period (CLI: edit `~/.tavs/schedule.json`; app: the `🔒 Hard`
   checkbox per row in Preferences → Schedule).
   - A hard *quiet period* is locked while inside it.
   - A hard *allowed window* locks the time OUTSIDE its hours ("outside my
     allowed hours, resuming is gated"). Any enabled hard window hardens the
     outside-windows mute.
   - The master pause toggle is NEVER hard.
2. **Manual:** `tavs lock now [--for 2h]` (default 1h) or the menu bar's
   "Lock Now (1h)". Engaging is never challenge-gated and cancels any
   active grant. Repeated `lock now` keeps the LATER end time.

## CLI

```bash
tavs lock now [--for 15m|2h|2h30m|1d]   # engage (default 1h)
tavs lock status                        # state + remaining time
tavs unlock [--for 15m|1h|4h|rest-of-day]  # challenge, then time-boxed grant
tavs lock set-password [--type both]    # configure the password challenge
```

Without `--for`, `tavs unlock` offers the presets interactively. The menu
bar has the same flow under "Unlock…" (visible while locked).

## Challenges

Configured in `~/.tavs/challenge.conf` (mode 600):

| Type | Behavior |
|------|----------|
| `puzzle` (default, no setup needed) | Retype a shown sentence with each word's FIRST letter moved to the word's END: "the quick brown fox" becomes "het uickq rownb oxf". A fresh sentence per attempt. |
| `password` | Salted SHA-256 password set via `tavs lock set-password`. |
| `both` | Password first, then the puzzle. |

Three attempts per challenge, then the operation fails and the lock stays.
If `challenge.conf` is missing or inconsistent, the puzzle is used, so a
hard lock can never make the system unrecoverable.

## What is gated while a hard lock is effective

- `tavs unlock` (grants access for the chosen duration)
- `tavs schedule resume`, `add-window`, `add-quiet`, `remove`
  (permission for that single edit; no grant is created)
- Menu bar "Resume TAVS" and Preferences → Schedule "Save"

Never gated: `tavs schedule pause`, `tavs lock now`, menu "Pause TAVS",
appearance settings (`tavs set`, wizard, themes).

## State and lifecycle

The lock projection lives in `/tmp/tavs-$UID/lock.state`:

```
LOCKED="true"                  REASON="manual"|"schedule"
LOCK_UNTIL_EPOCH="..."         # always finite; there is no indefinite lock
UNLOCK_UNTIL_EPOCH="0"         # grant end, 0 = none
WRITTEN_EPOCH="..." LOCK_BG="#3A3A3A" LOCK_FG="" SCHEMA_VERSION="1"
```

The shell honors it via a single predicate, with deliberately NO app-PID or
heartbeat check (that is the fail-closed core):

```
effective := LOCKED && now < LOCK_UNTIL && !(now < UNLOCK_UNTIL)
```

Lifecycle rules:

- **Killing TAVS.app does not end the lock.** Hooks stay suppressed and new
  terminals keep painting (shell integration) until `LOCK_UNTIL_EPOCH`.
- **Expiry always wins.** Locks and grants end exactly at their epochs; the
  app wakes on the second, the shell re-checks per invocation.
- **Reboot clears manual locks and grants** (`/tmp` is wiped). Scheduled
  hard windows re-engage when the login item relaunches and re-evaluates.
- Absent or malformed `lock.state` (including a non-numeric
  `LOCK_UNTIL_EPOCH`) means NOT locked.

## All-terminal coverage

`tavs install shell-integration` adds a fenced source block to `~/.zshrc`
(and `~/.bashrc` when present). Every new interactive terminal then:

1. registers its TTY in `/tmp/tavs-$UID/active-ttys/` so the app's
   broadcast reaches it, and
2. self-paints the current lock/pause state immediately at open.

Cost: under 1ms at shell startup when TAVS is idle. Remove with
`tavs install shell-integration --remove`.

## Honest limits

The lock guards against reflexes, not against a determined owner of the
machine. The following bypasses exist by design and are accepted:

- deleting `/tmp/tavs-$UID/lock.state` or `~/.tavs/challenge.conf`
- editing `~/.tavs/schedule.json` directly
- `TAVS_STATUS=false` (suppresses agent signals for that invocation; it
  does not remove the paint of other terminals)
- rebooting (manual locks only; scheduled hard windows come back)

Each of those requires deliberately choosing to break your own rule, which
is exactly the moment of friction the lock is designed to create.

## FAQ

**Terminals stayed painted after the lock ended and the app was dead.**
Without the app, nothing broadcasts the un-paint. Each terminal fixes
itself on the next shell open or agent hook; relaunching TAVS.app clears
everything at its next evaluation.

**I set a hard window but the menu still resumes without a challenge.**
Hard windows gate the time OUTSIDE their hours. Check `tavs lock status`
to see whether a lock is actually effective right now.

**Can I test my challenge without waiting for a lock?**
`tavs unlock` outside a lock prints "No effective lock" without prompting.
Engage a short `tavs lock now --for 1m` and unlock it.
