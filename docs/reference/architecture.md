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
│  │  │session-      │ │             │ │                   │ │    │
│  │  │ icon.sh      │ │             │ │                   │ │    │
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

### session-icon.sh (Session Icons)

Assigns a unique animal emoji per terminal tab for visual identification:
- `assign_session_icon()` - Pick random icon from pool, persists per-TTY (idempotent)
- `get_session_icon()` - Return current session's icon (empty if disabled)
- `release_session_icon()` - Unregister on session end
- Registry-based uniqueness across concurrent sessions
- Stale cleanup removes entries for dead TTY devices
- State files: `session-icon.{TTY_SAFE}` (per-tab) and `session-icon-registry` (cross-session)

### title-management.sh (Title Composition)

Title management with user override detection:
- `compose_title()` - Build title from `{FACE}`, `{STATUS_ICON}`, `{AGENTS}`, `{SESSION_ICON}`, `{BASE}` tokens
- `set_tavs_title()` - Set title with full state tracking and user override respect
- `reset_tavs_title()` - Reset title to base (remove TAVS prefix)
- User title detection on iTerm2 via OSC 1337
- Title lock/unlock for explicit user control

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
  7. Compose title with {FACE} {STATUS_ICON} {AGENTS} {SESSION_ICON} {BASE} tokens
  8. Send OSC 0 (title)
  9. Record state
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
  1. Assign session icon (unique animal emoji per TTY)
  2. Icon persists across /clear (tied to terminal tab)
  3. Stale icons from dead TTYs cleaned up automatically
  4. Icon appears as {SESSION_ICON} token in title format
```

## Configuration Files

| File | Purpose |
|------|---------|
| `~/.claude/settings.json` | Claude Code hooks and plugin enablement |
| `~/.gemini/settings.json` | Gemini CLI hooks |
| `~/.codex/config.toml` | Codex CLI notify setting |
| `~/.opencode/config.json` | OpenCode plugin configuration |

## Related

- [Agent Themes](agent-themes.md) - Per-agent face, color, and background customization
- [Testing](testing.md) - How to test the visual signals
- [Troubleshooting](../troubleshooting/overview.md) - Common issues
