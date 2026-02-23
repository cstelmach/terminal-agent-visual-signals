# Architecture

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
│  │     • Background color (OSC 11)                        │    │
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
- Theme preset loading (Catppuccin, Nord, Dracula, etc.)
- AGENT_ prefix resolution (e.g., `CLAUDE_DARK_PROCESSING` -> `DARK_PROCESSING`)
- Color resolution based on dark/light/muted mode
- Mode-aware processing color override based on `TAVS_PERMISSION_MODE`

### face-selection.sh (Face Selection)

Random face selection from per-agent face pools:
- `get_random_face()` - Select random face for a state from AGENT_FACES_ arrays
- `get_compact_face()` - Compact mode: emoji eyes in agent frame, subagent count as right eye
- Supports all states including subagent and tool_error
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
- `_registry_lookup/store/remove()` - Persistent key→icon mappings with atomic writes
- `_active_sessions_update/remove/check_collision()` - Active-sessions index for O(1) collision detection
- `_registry_cleanup_expired()` - TTL-based cleanup of old entries
- Persistence routing: `/tmp/tavs-identity/` (ephemeral) or `~/.cache/tavs/` (persistent)

### dir-icon.sh (Directory Identity)

Deterministic directory→flag mapping with worktree awareness (dual mode only):
- `assign_dir_icon()` - Assign flag from 190-flag pool per working directory (idempotent)
- `get_dir_icon()` - Return single flag or `main→worktree` format for git worktrees
- `release_dir_icon()` - Remove per-TTY cache (registry mapping preserved)
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
| Reset | Default | - | Clear state |

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
  2. Icon persists across /clear (tied to session_id, not TTY device)
  3. Stale icons from dead TTYs cleaned up automatically
  4. Icon appears as {SESSION_ICON} token in title format
  5. In dual mode, dir icon deferred to first UserPromptSubmit (cwd available)

UserPromptSubmit (new-prompt):
  1. Revalidate identity: re-check session icon collision status
  2. Assign dir icon from working directory (dual mode only)
  3. Worktree detection: if git worktree, shows main→worktree format
  4. Title shows «{DIR_ICON}|{SESSION_ICON}» in dual mode

Session End (reset session-end):
  1. Release session icon (remove per-TTY cache, keep registry mapping)
  2. Release dir icon (remove per-TTY cache)
  3. Active-sessions index entry removed
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
