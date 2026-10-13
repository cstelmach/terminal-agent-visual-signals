# Recovery and managed output API

Last Updated: 2026-10-13 (Europe/Vienna)
Version: 1.14

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

`tavs sync` refreshes the root dispatcher, core/CLI dependencies, Claude/Codex adapters,
both Claude hook definitions, plugin shellrc and Codex installer in existing plugin roots.
Required copy/directory/permission failures return nonzero. Direct entry points regain execute
permission; preferences, schedules and lock definitions are not sync inputs. A failure may leave
earlier copies applied. Sync does not build/install the native helper or restart existing workers.

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

`VisualRestrictionsRevision.identity` exposes only the marker's device/inode or explicit missing
identity, with strict Codable parsing. The initiating run must retain the pinned revision while
its effects or pending cleanup remain live. Stored identities are compared under the original
writer deadline; atomic replacement invalidates them even when the Boolean value is unchanged.
No descriptor, desired focus mode or extra cancellation token is serialized.

`ProcessRunner.runBoundedOutput` retains stdout and exit status, accepts an explicit environment,
and caps the process at ten seconds with bounded pipe draining. `runBounded` remains the
code-zero-only wrapper with its two-second limit for native catalogue/configuration queries.
The device writer's separate original 100 ms deadline is unchanged.

`writeManagedToDevice(path:lockURL:beforeOpen:prepare:)` gives both callbacks the original
absolute 100 ms deadline. Background requests publish validated intent and the exact continuing
owner's bound copy in `beforeOpen`, then release the stable record lock before opening the device.
Style-only requests do not publish background intent. Device open precedes the output lock.
Full renders and forced resets pin the suspension marker before device open under the same
budget. Preparation rejects a replaced revision with `unaffected`, preserving intent without queued
palette, title or bell bytes. A new render after recovery captures the current revision.

`--managed-forced-reset` may clear an exited producer through its cached continuing-owner binding.
After producer exit it requires an unchanged observation and latest previously bound intent for
that exact delivery, TTY and device. A live producer may reset without prior intent, but any current
intent must belong to the same delivery. Checks run before open and under the output lock.
A newer delivery, standalone intent, missing binding or reused owner rejects the reset.
No native catalogue access or new helper verb is needed for this cleanup.

Preparation revalidates the opened descriptor, lifetime, stale delivery and current policy under
that lock. A new restriction replaces the complete ordinary render; selective backgrounds compose
over the latest ordinary intent. Failure or late open cannot claim paint or run late preparation.
When publication succeeded before a device failure, later recovery retains that intended color
or reset. If publication-lock contention consumes the whole budget, publication fails without a
new budget or late retry. No arbitrary program-set color restoration is claimed.

## Automatic occurrence foundation (Phase 9 in progress)

`AttentionState` consumes fresh native-keyed coverage and the current High set. Initialization
baselines existing observations; the activation time also excludes old records adopted later.
It retains consumed completion IDs and observed permission episodes in memory. Acknowledgement
subtracts only the captured occurrence set on its target, preserving later arrivals and other rows.
Occurrences include provider, producer generation, TTY and device, so old navigation cannot
acknowledge a replacement producer's cue. Downgrade removes eligibility without replay on promotion.

Claude completion uses its intake delivery ID; Codex requires its supported completion event and
turn ID. PermissionRequest and permission_prompt coalesce until observed processing/reset.
A prompt after a closed episode needs a fresh request anchor; ambiguous companions are ineligible.
Idle, compacting, subagent and cosmetic error restoration do not imply resumption. Invalid current
coverage removes eligibility; retained acknowledged records cannot rearm. Equal-time or older
same-producer observations do not invent an ordering. Generic Notification is diagnostic only.
Latest-only records may miss intervening hook events; no event journal or new hook was introduced.
The reducer supplies policy to the existing focus controller; it does not paint itself.

`FocusController.enableAutomatic(rows:high:coverage:)` explicitly replaces Manual and arms
Automatic with a pinned recovery revision. At zero cues it clears rendering while staying armed;
a later occurrence gets a fresh render ID. Every current High row is emphasized while any cue
remains. Changing High membership retires old effects, including a promoted row's previous dimming.
Unavailable catalogues invalidate queued rendering and preserve cue history without renewal.

Sessions supplies fresh coverage and committed priorities, keeps the existing non-Off timer,
and snapshots a target's cues before Go To. Only verified navigation success acknowledges that
snapshot. Failure changes no cue; later arrivals survive. Recovery and restart leave Off.
Sessions/menu expose Automatic Focus, per-row cue counts and completion-only acknowledgement.

`TerminalFocusRequest.isCurrent` receives the original writer deadline at each final guard.
Automatic revalidates at least one actual cue producer and its captured native binding through
`validateAttentionSource`, without taking another TTY's coverage lock. This returns valid,
vanished or unavailable for the exact cue, native surface and optional captured target. Missing
inspection preserves its cue; known process/device/application reuse or exit resolves only the
captured occurrences. Positive loss in one domain is not hidden by uncertainty in another.
Currency and the original deadline are checked again after lookup. If no source is valid, new
painting is rejected while unavailable cues remain. Already proven exits are resolved even if
a later source inspection times out. An independent worker preflight checks all-High catalogues,
with one shared 100 ms inspection deadline; it creates no nested device-writer allowance.
Restoring an unchanged observation cannot replay an acknowledged occurrence or end its episode.

`TerminalFocusRequest.didRenew` reports actual metadata publication under the writer lock.
The controller advances its common heartbeat only after every intended mapped target renews
and no write fails. Rejected predicates and zero-target fanout do not renew. A global mask may
hide bytes while still renewing metadata. More than six seconds without renewal rotates the
effect ID on the next catalogue, preserving the attention cue. Unrenewed effects are reported
as unavailable instead of being described as successfully emphasized.
Persisted focus recipes contain no cue actor; later ordinary composition relies on the accepted
lease and controller refresh/cleanup. No new cue registry or event journal was added.
Native automatic salience and active-cue UI acceptance remain unverified. Final source reviews
are complete; their remaining material corrections are tracked in the dated research package.

## Manual focus (Phase 8 source verified)

Dynamic schema-1 `focus` records use `focus.json`, separate from legacy/global `effect.json`
and `preview.json`. They require normalized `focusColors` and marker `revision`; malformed,
missing and wrong-kind fields are rejected. Canceled or expired same-ID records cannot renew,
and the generic heartbeat helper cannot extend dynamic focus. Legacy fixed records retain their
existing slot and semantics. Matching current source-built components are required for this kind.

`TerminalRenderer.focusBackground(ordinary:colors:)` supplies the Phase 8 pure dimming transform.
It reduces chroma in linear light, then tries bounded neutral adjustments for visible dark/light
background changes. Candidates need total RGB distance of 24 and luminance change at most 0.08.
Configured-text contrast stays at least 4.5:1, or does not worsen a lower baseline. Invalid or
unsafe inputs return nil. Current/reset intent handling is shared with the preview renderer.
The managed writer now composes this transform from current ordinary intent on every paint.
Only a guarded controller request advances the six-second heartbeat. Global pause and preview
retain precedence without replacing the dynamic record; clearing or expiry recomposes fresh
intent. Alias agreement compares inputs, revision, run and controller, not last computed color.
Exact-ID clear cancels metadata before device open and emits no stale repaint after replacement.
Stored revision mismatch cannot revive a lease after partial recovery and explicit resumption.
`FocusController.focusSelected(_:catalogue:)` captures native surface IDs independently of
browsing selection and priorities. Accepted catalogues retain that set, add new surfaces only
to its outside set, and end Manual on confirmed last-member closure. Successful empty Sessions
catalogues reconcile confirmed closure, prune selection/priorities and clear closed cues while
Automatic stays armed. Actual failed catalogues retain logical membership, invalidate queued
updates and authorize no new paint. No-surface catalogues disable new Automatic activation.
At least one captured surface needs a verified binding before any outside background is changed.

Manual updates reuse the serialized preview worker and coalesce to the latest catalogue.
Requests revalidate run identity, catalogue version, six-second age and pinned recovery revision.
An expired run gets a fresh effect ID; unmapped or failed outside targets cannot refresh its
common heartbeat. Retired IDs are cleared after replacement, so old cleanup cannot repaint a
new run. Failed exact-ID cleanup retains its targets and revision pin for retry or recovery.

Sessions keeps one two-second catalogue timer while its window is open or Manual is active.
Focus Off preserves browsing selection and preview. Restore Visibility cancels both in-memory
effects before independent recovery; external suspension ends Manual on the next refresh.
Relaunch and explicit resumption start Off. Sessions and menu controls expose unavailable and
partial outcomes; the working-set row label is also included in its accessibility label.
Native dimming/readability and closed-window GUI acceptance remain unverified.

## Preview rendering foundation (Phase 7 source verified)

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
