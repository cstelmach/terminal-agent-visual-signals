# Architecture

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.12

## Physical lifetime and native aliases

Plain and native bindings share intent/effects only when TTY, device and continuing-owner
generation match. Managed preparation reads equivalent cached aliases under the existing lock
and deadline; multiple live native IDs or unknown alias metadata fail visibly. Ordinary hooks
reuse a unique valid native binding, so native selective leases compose over their new intent.

Recovery groups by physical lifetime, cancels equivalent effects and writes/reports once.
A later native snapshot can register an alias without repeating a successful reset. Proven
owner-generation end is vanished; missing inspection alone is unavailable. Records are retained.
Live adoption snapshots owner-bound intent for producer-exit restoration. Legacy unbound
adoption cannot transfer an old color to a changed owner with the same native ID/device.

## Shell output routing

All TAVS background writes use the headless managed helper. Startup registers its continuing
shell owner and requests current policy. Idle resets and debug reconciliation use typed actions;
muted nonbackground signals are discarded without retaining pending OSC bodies. Synthetic
updates validate the current observation before palette/title output, including when background
coloring is disabled. Producer identity is checked separately from the continuing shell owner.

Capability queries use a known headless validation flag before any new verb. Missing/older/failed
helpers report failure and never fall back to raw background output. Actual write calls preserve
dedicated test scopes. Shell mute liveness matches the Swift policy's live PID, finite decimal
times and nonfuture heartbeat; a hard mirror cannot survive lock expiry or an unlock grant.

## Current-policy broadcasting

`Broadcaster` coalesces requests on a serial queue. Paused/locked requests carry no queued
styling; the managed writer reads current policy. Reconciliation preserves required reset
flags when later scheduler ticks arrive. Startup caches native bindings without paint, then
clears only prior effect targets, preserving unaffected shell backgrounds. Failed bindings
remain retryable. `lastResult` retains typed outcomes and catalogue availability.

The production scheduler supplies the same restriction store, clock and recovery service.
Startup requests cached cleanup even when restrictions are disabled; that cleanup precedes
native registration. Muted-to-unmuted transitions use safe typed cleanup after saving policy,
including a transition caused by persistent suspension.
All native and device operations run off its calling thread. Historical OSC buffers, argv
substring discovery and age-only registry pruning no longer authorize broadcaster output.

## Ordinary managed actions

`VisualRecovery.apply` runs typed batches without changing the persistent suspension marker.
Registration caches validated bindings without repainting. Forced idle reset validates its
synthetic delivery before producing palette/background/title bytes, and current global policy
retains precedence. It cannot spill stale reset styling after a newer meaningful observation.

Scoped target resolution uses one exact allowed cached native binding or a fresh allowed native
snapshot; owner-only identity never broadens a dedicated scope. Missing controller generation
fails restrictive paint explicitly while independent reset/registration remain available.
Production Sessions and broadcasting share GhosttyCatalog's native queue. Tests construct their
own injected catalogues and keep private scope separate.

## Typed recovery coordinator

`VisualRecovery` composes current policy and latest intent through the managed writer. Its
callback revalidates the opened device and binding, publishes/binds ordinary intent under the
same lock, and persists global effects before paint. Live selective backgrounds override
ordinary intent; expiry/clear restores the latest bound intent using background-only output.

`recover` saves suspension or explicit resumption first. Cached targets fan out independently
while native discovery runs off main. Available native rows add exact targets; registry names
remain hints. Confirmed vanished bindings and failed/unverified candidates are reported
separately, with failures retained. Catalogue unavailability is explicit and does not defeat
successful cached restoration. It alone is not evidence of a failed live target.

Emergency reset cancels current ownership and removes the exact obsolete pending file without
reading or replaying it, then sends OSC 104/110/111. Resume clears selective ownership and
composes only the current rule/intent. Dedicated scopes reject cached owner-only candidates
that lack an allowed native identity. No navigation, terminal input or process control occurs.

This coordinator passes owned-PTY tests, including queued recovery ordering and healthy repaint
before blocked discovery finishes. Broadcaster, startup, shell and headless routes are connected,
and the source helper advertises its managed capability. Independent review and physical native
acceptance remain outstanding; previews and focus are not released by these source checks alone.

## Intent publication inside managed output

`publishIntentUnlocked` reuses ordinary publication validation and chronology under the
caller's existing lock and original deadline. The public locking API keeps its earlier
metadata-only timing; it never paints a device. Synthetic and delayed old delivery rejection
remain unchanged.

`bindOrdinaryIntentUnlocked` verifies a live producer, the exact continuing target and equality
with the latest normalized per-TTY intent, then saves that same schema beside the target as
`bound-intent.json`. An equal latest copy can survive producer exit while its target remains
valid. Another owner/native binding or an unmatched latest delivery cannot borrow that evidence.
Corrupt bound data remains an explicit availability failure; its filename authorizes no target.

## Current global policy

`VisualRestrictionPolicy.current(deadline:)` runs inside managed output preparation, reusing
the original deadline. It reads suspension first and again before returning. Lock/mute files
are bounded to 8 KiB and opened as regular files without following symlinks. Unsafe/unreadable
files report fixed availability errors; malformed rule data cannot enable a restriction.

Finite effective hard locks precede soft liveness/heartbeat checks. A grant releases hard
causes and preserves an independent soft cause. Soft validity checks refresh time after PID
liveness. Color composition uses the persisted resolved fields and existing PauseVisual
normalization, without configuration reload or AppKit inside the writer.

Mute schema 1 adds `MUTE_LEVEL="hard|soft"` and `REQUESTED_MUTED="true|false"` after its existing
fields. The requested flag preserves current rule intent while effective MUTED is false under
suspension. Unknown requested flags cannot enable paint; missing fields retain legacy behavior.
The scheduler preserves these fields, requested finite expiry and resolved colors. It writes
both projections before visual reconciliation so fresh checks see the new rule. Typed writer
routing remains in progress.

## Recovery target and effect records

`TerminalVisualStateStore` caches a concrete TTY/device, continuing owner process generation
and optional exact Ghostty surface identity. Native capture requires fresh foreground evidence;
cached restoration can validate the continuing owner without Automation. Device/owner lookup
uncertainty remains unavailable. Only affirmative device or native-lifetime absence/replacement
establishes that the original target vanished. Opened descriptors must match the character device.

One current effect per binding retains controller generation, effect ID, kind, background,
heartbeat and active state. Unresolved old bindings remain separate candidates. Cancellation
retains the record but prevents the same ID or a heartbeat from reactivating it. Selective
ownership lasts at most six seconds with a live matching controller; current global rules
must still be evaluated separately. No OSC, titles or agent bodies enter these records.

The `*Unlocked` methods require the existing writer lock and original deadline. They do not
reacquire it or start a new timeout. Latest intent for an exact adopted native target can survive
producer exit into its continuing shell; observation and attention coverage still end on exit.
Unadopted owner-only intent requires a verified live producer or explicit default reset.

These records and the ordered writer are foundations. Discovery, renderer/CLI routing, recovery
fanout and retry reporting remain in progress.

## Ordered device writer

`ProcessRunner.writeManagedToDevice(path:lockURL:prepare:)` shares the existing asynchronous
100 ms caller deadline and nonblocking partial-write loop. It opens the device before taking a
stable private per-TTY file lock. Under that lock, `prepare` receives the actual descriptor and
the original monotonic deadline. It must validate the target, read current policy and persist
effects before returning bytes. Returning nil skips output; errors remain explicit failures.

Late device opens close without acquiring the lock or calling policy. Late prepared bytes are
rejected. State mutations in `prepare` must also honor the passed deadline because a blocked
closure cannot be forcibly canceled. Busy locks and backpressured devices retain the same
budget, and independent healthy writes can complete. The lock inode is never replaced/unlinked.

Broadcaster and managed background/reset callers use this writer. Ordinary palette/title/image
output still needs a single typed render transaction; its current direct-write gap is tracked
as Codex R2 in the dated Phase 6 package.

## Persistent visual suspension

`~/.tavs/visual-restrictions.state` contains exactly this canonical text, including its final LF:

```text
SCHEMA_VERSION="1"
SUSPENDED="true"
```

Explicit resumption writes `SUSPENDED="false"`; it does not delete saved schedules or locks.
The shell and Swift stores classify absent state as active, valid true as suspended, and an
existing malformed/unreadable/special marker as unavailable. Unavailable state disables
restrictions visibly. Readers accept only the canonical schema, bound input and never source
the marker. The standalone installed shellrc embeds the identical reader/predicate because it
has no dependency bundle. Shared fixtures pin Bash, zsh and Swift agreement.

Suspension precedes hook stage-0, stage-1, idle-worker and effective-lock checks. Ordinary
observations/background intent continue, and shell startup still registers its TTY. New locks
remain saved but visually inert; CLI status explains when rules are suspended or unavailable.
Mute diagnostics now use the injected runtime directory instead of a shared fixed tmp file.

The scheduler continues raw rule evaluation, lock/grant merging and expiry timers. Suspension
overrides its visual projection and disables restrictive paint. Safe typed cleanup still runs
on startup and muted-to-unmuted transitions, retrying prior effects without historical replay.
Menu controls use configured master activation separately from projected mute.
Sessions reads the independent marker before an in-flight native refresh can return early.
Production stores receive an explicit `.tavs` URL; private launch stores use `root/home/.tavs`.

Headless capability/read/write verbs run before UI launch and require explicit file URLs:

```bash
TAVSApp --validate-config --visual-restrictions-capabilities
TAVSApp --visual-restrictions-read /absolute/private/visual-restrictions.state
TAVSApp --visual-restrictions-write /absolute/private/visual-restrictions.state true
```

This reader/projection foundation does not yet clear terminal pixels or invalidate historical
pending output. Independent repaint and serialized device checks belong to the recovery phase.

## Organizer observation and intent records

The Swift companion provides headless metadata intake and separate per-TTY records. Before
using these verbs, shell adapters query the established validation entry point:

```bash
TAVSApp --validate-config --organizer-capabilities
# Supported output: tavs-organizer-schema=1
```

An unsupported helper leaves metadata coverage unavailable; basic fixed-state signaling
continues. Tests must select their source-built executable with `TAVS_TEST_HELPER_BIN`.

`organizer-intake.swift` decodes at most 1 MiB of JSON and exports only existing permission,
transcript-path, session/thread-ID and directory fields plus an opaque metadata context.
It rejects control characters in session/thread IDs. The context carries a local delivery
ID, intake time, supported event/response ID and kernel producer generation/device. Bodies
never reach core debug logs. Native version binaries can match the resolved provider command;
generic interpreters do not establish agent identity.

`terminal-visual-state.swift` stores schema-1 observation and ordinary-intent JSON beneath
`TAVS_RUNTIME_DIR/organizer`, defaulting to `/tmp/tavs-UID/organizer`. Whole-path Base64URL
keys avoid TTY basename collisions. Files are atomically replaced under per-TTY locks with
a 100 ms acquisition limit; reads reject oversized, malformed and special-file inputs.
Fresh legitimate publications can replace malformed regular latest files. Synthetic updates
cannot repair corruption or supersede a newer intake. Native adoption bindings remain strict.

`send_osc_bg` records normalized color/reset intent before mute routing. Idle gradients and
delayed error restoration retain their originating context and never publish observations.
The helper compares frozen intake time as well as render time, so a late ordinary write
cannot replace intent belonging to a newer observation. This does not yet serialize device
painting with preview/recovery ownership; that belongs to the later recovery phase.

Sessions reads/adopts records off the UI thread after a successful nonempty native catalogue
refresh. Adoption requires the exact native surface, producer generation, controlling device
and foreground family. Persisted adoption can retain a continuing producer's known delivery
after it backgrounds. Exited, reused, unbound and ambiguous producers cannot authorize cues.
Failed refreshes retain displayed observations but disable attention eligibility. Completion
appears as `Response ended`; Codex observations explicitly show completion-only coverage.

The isolated Dock app injects its runtime beneath the private launch root and omits the
scheduler and personal preferences. Fixture navigation remains explicitly simulated.

See the [organizer SPEC](../specs/tavs-priority-discovery_2026-10-04/SPEC.md) for recovery,
preview and focus phases, and [Codex intake](../../src/agents/codex/README.md) for notify argv.

## Overview

TAVS - Terminal Agent Visual Signals provides terminal state indicators for multiple AI CLI tools through a unified core system with platform-specific adapters.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                              TAVS                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐    │
│  │  Claude Code   │  │   Gemini CLI   │  │   OpenCode     │    │
│  │    Plugin      │  │   Installer    │  │  TS Plugin     │    │
│  │  (hooks.json)  │  │ (install-*.sh) │  │  (npm pkg)     │    │
│  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘    │
│          │                   │                   │              │
│          ▼                   ▼                   ▼              │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              Agent Trigger Wrappers                     │    │
│  │      src/agents/{claude,gemini,codex,opencode}/         │    │
│  │         trigger.sh  +  data/{faces,colors}.conf         │    │
│  └───────────────────────┬────────────────────────────────┘    │
│                          │                                      │
│                          ▼                                      │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                    Core System                          │    │
│  │                 src/core/trigger.sh                     │    │
│  │                                                         │    │
│  │  ┌──────────────┐ ┌─────────────┐ ┌──────────────────┐ │    │
│  │  │theme-config- │ │session-     │ │terminal-osc-     │ │    │
│  │  │ loader.sh    │ │ state.sh    │ │ sequences.sh     │ │    │
│  │  │face-         │ │             │ │                   │ │    │
│  │  │ selection.sh │ │             │ │spinner.sh        │ │    │
│  │  └──────────────┘ └─────────────┘ └──────────────────┘ │    │
│  │                                                         │    │
│  │  ┌──────────────┐ ┌─────────────┐ ┌──────────────────┐ │    │
│  │  │title-        │ │idle-worker- │ │subagent-         │ │    │
│  │  │ management.sh│ │ background  │ │ counter.sh       │ │    │
│  │  │title-        │ │ .sh         │ │palette-mode-     │ │    │
│  │  │ iterm2.sh    │ │             │ │ helpers.sh       │ │    │
│  │  │session-      │ │             │ │context-          │ │    │
│  │  │ icon.sh      │ │             │ │ data.sh          │ │    │
│  │  │identity-     │ │             │ │                   │ │    │
│  │  │ registry.sh  │ │             │ │                   │ │    │
│  │  │dir-icon.sh   │ │             │ │                   │ │    │
│  │  └──────────────┘ └─────────────┘ └──────────────────┘ │    │
│  └───────────────────────┬────────────────────────────────┘    │
│                          │                                      │
│                          ▼                                      │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                  Terminal (OSC Sequences)               │    │
│  │     • Default foreground (OSC 10 / OSC 110)            │    │
│  │     • Background color/reset (OSC 11 / OSC 111)        │    │
│  │     • 16-color palette (OSC 4) - optional              │    │
│  │     • Tab title (OSC 0)                                │    │
│  │     • Background image (OSC 1337 / kitten @)          │    │
│  │     • Bell notification (BEL)                          │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Core Modules

### trigger.sh (Entry Point)

Main dispatcher that handles state transitions:
- Receives state parameter (processing, permission, complete, idle, compacting, subagent-start, subagent-stop, tool_error, reset)
- Sources configuration modules
- Executes appropriate OSC sequences
- Manages idle timer lifecycle
- Coordinates subagent counter and auto-return for tool errors

### theme-config-loader.sh (Configuration)

Loads configuration hierarchy and resolves agent-specific variables:
- Master defaults from `src/config/defaults.conf`
- User overrides from `~/.tavs/user.conf`
- Title preset expansion (`TAVS_TITLE_PRESET` → face mode + all format vars)
- Theme preset loading (Catppuccin, Nord, Dracula, etc.)
- AGENT_ prefix resolution (e.g., `CLAUDE_DARK_PROCESSING` -> `DARK_PROCESSING`)
- Color resolution based on dark/light/muted mode
- Mode-aware processing color override based on `TAVS_PERMISSION_MODE`

### face-selection.sh (Face Selection)

Random face selection from per-agent face pools:
- `get_random_face()` - Select random face for a state from AGENT_FACES_ arrays
- `get_compact_face()` - Compact mode: emoji eyes in agent frame, context food as right eye
- Supports all states including subagent, tool_error, and reset (start vs end)
- Reset distinction: `reset` uses standard eyes, `reset_final` uses em dash eyes (session-end)
- Fallback to UNKNOWN_ faces for unrecognized agents
- Compact mode: `TAVS_FACE_MODE="compact"` replaces text eyes with emoji from theme pools (semantic, circles, squares, mixed)

### session-state.sh (State Management)

Session state tracking:
- Records current state to file
- Manages state transitions
- Prevents duplicate signals

### terminal-osc-sequences.sh (OSC Functions)

Terminal escape sequence functions:
- `send_osc_bg` - Change background color (OSC 11)
- `send_osc_palette` - Modify 16-color ANSI palette (OSC 4)
- `send_osc_palette_reset` - Reset palette to terminal defaults (OSC 104)
- `send_bell_if_enabled` - Notification bell (BEL)
- `_build_osc_palette_seq` - Build palette sequence (shared by trigger and idle-worker)

The macOS menu-bar broadcaster has an additional pause contract: pause entry
resets legacy palette overrides (OSC 104), sets default foreground/background
(OSC 10/11), and clears legacy iTerm2 background images (OSC 1337
`SetBackgroundImageFile`). Pause clear resets palette and default foreground, then restores
latest ordinary background intent or the configured background reset. Normal active states do not emit
OSC 10/110; they continue to own state backgrounds, palettes, and titles only.

### session-icon.sh (Session Identity)

Deterministic session identity via animal emoji per session_id (v2) or random per-TTY (legacy):
- `assign_session_icon()` - Deterministic round-robin from 77-animal pool per session_id (idempotent)
- `get_session_icon()` - Return primary icon, or `"primary secondary"` pair during active collision
- `release_session_icon()` - Remove per-TTY cache and active-sessions entry (registry mapping preserved)
- 2-icon collision overflow: when two sessions share the same primary, both show a pair
- Legacy mode (`TAVS_IDENTITY_MODE=off`): exact v1 behavior (random per-TTY, 25 animals)
- Bidirectional format migration (v1↔v2) with auto-detection
- State files: `session-icon.{TTY_SAFE}` (per-tab KV cache) via identity registry

### identity-registry.sh (Identity Registry)

Shared registry foundation for session and directory icon modules:
- `_round_robin_next_locked(type, pool)` - Sequential assignment with mkdir-based locking
- `_registry_lookup/store/remove()` - Persistent key→icon mappings with atomic writes, filesystem-locked CRUD
- `_active_sessions_update/remove/check_collision()` - Active-sessions index for O(1) collision detection
- `_registry_cleanup_expired()` - TTL-based cleanup of old entries (filesystem-locked)
- `_acquire_lock/_release_lock()` - mkdir-based filesystem locking (prevents concurrent write races)
- Persistence routing: `/tmp/tavs/identity/` (ephemeral) or `~/.cache/tavs/` (persistent)

### dir-icon.sh (Directory Identity)

Deterministic directory→flag mapping with worktree awareness (dual mode only):
- `assign_dir_icon()` - Assign flag from 190-flag pool per working directory (idempotent)
- `get_dir_icon()` - Return single flag or `main→worktree` format for git worktrees
- `release_dir_icon()` - Remove per-TTY cache (registry mapping preserved)
- Sourced at top level (like `session-icon.sh`) so `get_dir_icon()` is available to all states
- `assign_dir_icon()` requires identity-registry.sh (loaded via `_load_identity_modules()`)
- Platform-aware git timeout helper (`timeout` → `gtimeout` → bare)
- Worktree detection via git-common-dir comparison
- Fallback pools: plants (26) and buildings (24) for alternate styling

### title-management.sh (Title Composition)

Title management with user override detection and per-state format selection:
- `compose_title()` - Build title with 4-level format fallback (agent+state → agent → state → global), dynamic guillemet injection for dual identity mode, resolve 20+ tokens including context/metadata/identity
- `set_tavs_title()` - Set title with full state tracking and user override respect
- `reset_tavs_title()` - Reset title to base (remove TAVS prefix)
- User title detection on iTerm2 via OSC 1337
- Title lock/unlock for explicit user control

### context-data.sh (Context Window Data)

Context window data resolution for title tokens:
- `load_context_data()` - Read bridge state file or estimate from transcript (3-tier fallback)
- `read_bridge_state()` - Safe key=value parsing from `~/.cache/tavs/context.{TTY_SAFE}`
- `resolve_context_token()` - Map token name to formatted value (10 display styles + 5 metadata)
- Transcript estimation: parse JSONL for actual token usage counts
- Per-agent context window sizing (200k Claude, 1M Gemini)
- Icon array lookup for food emoji, color circles, bars, braille, number emoji

### subagent-counter.sh (Subagent Tracking)

Tracks active subagent count for visual state and title display:
- `increment_subagent_count()` - Called on SubagentStart hook (atomic mktemp+mv writes)
- `decrement_subagent_count()` - Called on SubagentStop hook (atomic, clamped to 0)
- `get_subagent_title_suffix()` - Returns formatted count (e.g., `+2`) for title
- `reset_subagent_count()` - Resets on complete, reset, and new prompt (UserPromptSubmit)
- Session-isolated via TTY-safe files in `~/.cache/tavs/`
- New prompt resets counter via `new-prompt` flag to prevent stale counts after abort

### spinner.sh (Animated Spinners)

Manages animated spinner frames for processing state titles (when `TAVS_TITLE_MODE="full"`):
- Multiple spinner styles: braille, circle, block, eye-animate, none
- Eye synchronization modes: sync, opposite, stagger, mirror, clockwise, counter
- Session identity: random selections persisted per session for consistent visual identity
- Per-agent face frames: `{L}` and `{R}` placeholders replaced with spinner characters
- Secure state storage: `~/.cache/tavs/` (not `/tmp`) with safe file parsing

### idle-worker-background.sh (Idle Timer)

Background process for graduated idle states:
- Spawns after completion
- Cycles through 6 idle stages
- Respects skip signals from new activity

## Agent Adapters

### Claude Code (Shell Hooks)

- **Method:** JSON hooks in `~/.claude/settings.json`
- **Path:** `${CLAUDE_PLUGIN_ROOT}` variable
- **Features:** Full event coverage (14 hook routes across 11 event types)
- **Events:** UserPromptSubmit, PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest, Stop, Notification (permission_prompt, idle_prompt), SessionStart, SessionEnd, PreCompact (auto, manual), SubagentStart, SubagentStop
- **Plugin:** Marketplace installation supported
- **StatusLine Bridge:** Optional `statusline-bridge.sh` reads StatusLine JSON for context window data (silent data siphon — no stdout). See [Dynamic Titles](dynamic-titles.md).

### Gemini CLI (Shell Hooks)

- **Method:** JSON hooks in `~/.gemini/settings.json`
- **Path:** Absolute paths
- **Features:** Full event coverage (8 events)
- **Installer:** `install-gemini.sh`

### Codex CLI (Limited)

- **Method:** TOML config `~/.codex/config.toml`
- **Path:** Absolute paths
- **Features:** Only `notify` event (completion signal)
- **Installer:** `install-codex.sh`

### OpenCode (TypeScript Plugin)

- **Method:** npm package with TypeScript
- **Path:** Resolved via `__dirname`
- **Features:** 4 events (SessionStart, ToolUse, AgentResponse, etc.)
- **Package:** `@tavs/opencode-plugin`

## Visual States

| State | Color | Emoji | Description |
|-------|-------|-------|-------------|
| Processing | Orange | 🟠 | Agent working |
| Permission | Red | 🔴 | Needs user approval |
| Complete | Green | 🟢 | Response finished |
| Idle (6 stages) | Purple → deeper | 🟣 | Graduated idle |
| Compacting | Teal | 🔄 | Context compression |
| Subagent | Golden-Yellow | 🔀 | Task tool spawned subagent |
| Tool Error | Orange-Red | ❌ | Tool execution failed (auto-returns after 1.5s) |
| Reset (start) | Default | ⚪ | Session start — face with standard eyes |
| Reset (end) | Default | ⚪ | Session end — face with em dash eyes (muted) |

## Data Flow

```
User submits prompt
       │
       ▼
CLI Hook fires (UserPromptSubmit/BeforeAgent/onUserPrompt)
       │
       ▼
Agent trigger.sh called with "processing new-prompt"
       │
       ▼
Core trigger.sh:
  1. Reset stale subagent counter (new-prompt flag)
  2. Kill any existing idle timer
  3. Check state change needed
  4. Apply palette if enabled (OSC 4)
  5. Send OSC 11 (background color)
  6. Check TAVS_TITLE_MODE (full/prefix-only/skip-processing/off)
  7. Select per-state format (4-level fallback: agent+state → agent → state → global)
  8. Load context data (bridge → transcript → empty)
  9. Compose title with 20 tokens ({FACE} {STATUS_ICON} {CONTEXT_FOOD} {CONTEXT_PCT} ...)
  10. Send OSC 0 (title)
  11. Record state
       │
       ▼
[Agent works, tools execute...]
       │
       ├──► Tool fails → PostToolUseFailure hook
       │         │
       │         ▼
       │    trigger.sh "tool_error"
       │      - Orange-red bg, ❌ emoji
       │      - Auto-returns to processing after 1.5s
       │
       ├──► Task tool spawns subagent → SubagentStart hook
       │         │
       │         ▼
       │    trigger.sh "subagent-start"
       │      - Increment counter
       │      - Golden-yellow bg, 🔀 emoji
       │      - Title shows "+N" subagent count
       │
       ├──► Subagent completes → SubagentStop hook
       │         │
       │         ▼
       │    trigger.sh "subagent-stop"
       │      - Decrement counter
       │      - If count=0, return to processing
       │      - Otherwise update title with new count
       │
       ▼
CLI Hook fires (Stop/AfterAgent/onAgentResponse)
       │
       ▼
Core trigger.sh called with "complete"
  1. Reset subagent counter
  2. Send complete signals
  3. Spawn idle-worker background process
       │
       ▼
[30+ seconds pass without activity]
       │
       ▼
idle-worker transitions through 6 idle stages

Session Start (reset):
  1. Assign session icon (deterministic animal per session_id via round-robin)
  2. Assign dir icon (dual mode — cwd available from hook JSON)
  3. Show face + ⚪ status icon (session-start variant: standard eyes)
  4. Icon persists across /clear (tied to session_id, not TTY device)
  5. Stale icons from dead TTYs cleaned up automatically

UserPromptSubmit (new-prompt):
  1. Revalidate identity: re-check session icon collision status
  2. Re-assign dir icon (cwd may have changed between prompts, dual mode only)
  3. Worktree detection: if git worktree, shows main→worktree format
  4. Title shows «{DIR_ICON}|{SESSION_ICON}» in dual mode

Session End (reset session-end):
  1. Release session icon (remove per-TTY cache, keep registry mapping)
  2. Release dir icon (remove per-TTY cache)
  3. Active-sessions index entry removed
  4. Show face with em dash eyes (session-end variant: muted/closing)
```

## Configuration Files

| File | Purpose |
|------|---------|
| `~/.claude/settings.json` | Claude Code hooks and plugin enablement |
| `~/.gemini/settings.json` | Gemini CLI hooks |
| `~/.codex/config.toml` | Codex CLI notify setting |
| `~/.opencode/config.json` | OpenCode plugin configuration |

## Related

- [Dynamic Titles](dynamic-titles.md) - Per-state title templates and context window tokens
- [Agent Themes](agent-themes.md) - Per-agent face, color, and background customization
- [Testing](testing.md) - How to test the visual signals
- [Troubleshooting](../troubleshooting/overview.md) - Common issues
