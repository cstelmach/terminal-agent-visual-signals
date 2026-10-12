# Recovery and managed output API

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.1

## Public recovery commands

```bash
tavs recover
tavs recover --resume
```

Recovery saves persistent visual suspension before resolving the native helper. Suspension
survives TAVS restart and overrides pauses, locks and selective focus without a challenge.
Saved schedules, grants and session processes are preserved. Resume permits current rules again
and leaves selective focus Off. Neither operation replays historical alerts, titles or bells.

The helper returns JSON with `stateSaved`, `catalogueAvailable` and `items`. Each item contains
an optional validated `target` or `tty`, `status` and optional `reason`. Status is `restored`,
`vanished`, `unaffected` or `failed`. Missing catalogue access does not prevent cached healthy
targets from recovering. Unsafe registry-only targets and live delivery failures remain reported.

Exit 0 means the operation completed without reported failures. A nonzero CLI exit means saving
state failed, the helper was missing/unsupported, or native recovery was incomplete. When saving
state succeeds but helper resolution fails, the saved suspension remains effective.

## Internal helper compatibility

The shell queries `--validate-config --managed-output-capabilities` and requires exactly
`tavs-managed-output-schema=1`. This known validation branch is safe with older executables.
Unknown support is an explicit failure. Headless entry runs before GUI or login initialization.

The internal `--managed-render` request receives one bounded UTF-8 NUL-delimited stdin payload:

| Field indexes | Meaning |
|---|---|
| 0 | Optional background: empty, `reset`, or normalized hex |
| 1 | Palette action: empty, `set`, or `reset` |
| 2–17 | Sixteen optional palette colors |
| 18–19 | Title enabled flag and title |
| 20–21 | Image action and absolute image path |
| 22 | Bell enabled flag |

Exactly 23 fields and a final NUL are required, with a 16 KiB maximum. Control characters,
invalid flags and malformed colors/paths fail before output. The response is `rendered`,
`restricted` or `unaffected`. A rejected stale delivery exits 3; general failure exits 1.
These values govern title persistence and idle-worker retry. Synthetic work cannot emit a bell.
Current palette, background, title and image styling is composed inside the writer transaction;
the payload is ephemeral and is not retained as output history.

## Writer ordering

`writeManagedToDevice(path:lockURL:beforeOpen:prepare:)` gives both callbacks the original
absolute 100 ms deadline. Background requests publish validated intent and the exact continuing
owner's bound copy in `beforeOpen`, then release the stable record lock before opening the device.
Style-only requests do not publish background intent. Device open precedes the output lock.

Preparation revalidates the opened descriptor, lifetime, stale delivery and current policy under
that lock. A new restriction replaces the complete ordinary render; selective backgrounds compose
over the latest ordinary intent. Failure or late open cannot claim paint or run late preparation.
When publication succeeded before a device failure, later recovery retains that intended color
or reset. If publication-lock contention consumes the whole budget, publication fails without a
new budget or late retry. No arbitrary program-set color restoration is claimed.

## Preview rendering foundation (Phase 7 in progress)

`TerminalRenderer.previewBackground(ordinary:colors:)` uses normalized configured background
and foreground colors. It returns a conservative tint or nil when no safe meaningful change
exists. This is a configured-text contrast bound, not a guarantee for arbitrary program colors.

The internal schema-1 effect kind `preview` uses a separate `preview.json` alongside `effect.json`
for the same exact target. It expires two seconds after its original heartbeat timestamp; neither
refresh nor a same-ID save can extend that time. Exact-ID preview cancellation preserves the
underlying selective record. Global rules take precedence; suspension permits harmless previews.
Emergency recovery discovers and cancels both records through the existing bounded writer.
Controller/UI activation is still pending. Use matching current source-built components for
acceptance; old executables do not understand the preview record.

See [hard-lock reference](reference/hard-lock.md), [bug reference](BUG_REFERENCE.md) and
[implementation progress](specs/tavs-priority-discovery_2026-10-04/PROGRESS.md).
