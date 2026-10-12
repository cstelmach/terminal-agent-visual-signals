# Recovery and managed output API

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.4

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

The GUI client saves the same marker before querying the current bundle executable. It launches
`--visual-recover MARKER RUNTIME recover|resume` on a background queue, accepts valid reports on
exit 0 or 1, and displays partial failures without rolling back suspension. Capability queries
omit the three isolated launch keys; recovery retains their exact private scope. Fixture scope
uses its full validated ID set or the supplied narrower allowlist, never browsing selection.

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

`ProcessRunner.runBoundedOutput` retains stdout and exit status, accepts an explicit environment,
and caps the process at ten seconds with bounded pipe draining. `runBounded` remains the
code-zero-only wrapper with its two-second limit for native catalogue/configuration queries.
The device writer's separate original 100 ms deadline is unchanged.

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
Controller and GUI wiring are source-tested and checked in an isolated fixture. Use matching
source-built components for acceptance; old executables do not understand the preview record.

`TerminalPreviewRequest` captures the explicit selection's original time, colors and suspension
file revision. The revision holds a read-only descriptor until requests leave scope, preventing
inode reuse. A preview caches its validated target before comparing that revision inside the
existing writer lock. Recovery's atomic replacement rejects queued starts even if the Boolean
value is unchanged; later accepted writes are discoverable by recovery. Exact-ID clear uses the
same revision so an old clear cannot reapply ordinary color after emergency reset.
Replacement is a no-op; unavailable metadata and an expired original deadline remain failures.
This uses the existing marker and adds no persistent token, schema or polling protocol.

`TerminalRenderer.configuredColors(executable:configurationFiles:runner:)` checks explicit
configuration paths and uses bounded subprocesses away from the UI. Existing nonempty config
uses `+validate-config` followed by `+show-config --changes-only=false --no-pager`. With no
nonempty configuration it uses `+show-config --default --no-pager`, which bypasses template
creation. Canonical background, foreground and theme assignments are required; duplicates,
malformed output, failed validation and unresolved dual-theme appearance are unavailable.
The [show-config source](https://github.com/ghostty-org/ghostty/blob/main/src/cli/show_config.zig)
has no supported appearance selector; the
[validator](https://github.com/ghostty-org/ghostty/blob/main/src/cli/validate_config.zig) checks
diagnostics that ordinary output can omit. Queries reload configuration rather than observe
running colors. Concurrent deletion and optional-file loading remain native CLI limitations;
path preflight does not make configured queries transactional. No live query ran in development.

See [hard-lock reference](reference/hard-lock.md), [bug reference](BUG_REFERENCE.md) and
[implementation progress](specs/tavs-priority-discovery_2026-10-04/PROGRESS.md).
