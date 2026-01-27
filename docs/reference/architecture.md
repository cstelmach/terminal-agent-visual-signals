# Architecture

## Overview

Terminal Agent Visual Signals provides terminal state indicators for multiple AI CLI tools through a unified core system with platform-specific adapters.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Terminal Visual Signals                      │
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
│  │                    trigger.sh                           │    │
│  └───────────────────────┬────────────────────────────────┘    │
│                          │                                      │
│                          ▼                                      │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                    Core System                          │    │
│  │                 src/core/trigger.sh                     │    │
│  │                                                         │    │
│  │  ┌─────────┐  ┌─────────┐  ┌──────────┐  ┌─────────┐  │    │
│  │  │theme.sh │  │state.sh │  │terminal.sh│  │idle-    │  │    │
│  │  │themes.sh│  │         │  │           │  │worker.sh│  │    │
│  │  └─────────┘  └─────────┘  └──────────┘  └─────────┘  │    │
│  └───────────────────────┬────────────────────────────────┘    │
│                          │                                      │
│                          ▼                                      │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                  Terminal (OSC Sequences)               │    │
│  │     • Background color (OSC 11)                        │    │
│  │     • Tab title (OSC 0)                                │    │
│  │     • Bell notification (BEL)                          │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Core Modules

### trigger.sh (Entry Point)

Main dispatcher that handles state transitions:
- Receives state parameter (processing, permission, complete, idle, compacting, reset)
- Sources configuration modules
- Executes appropriate OSC sequences
- Manages idle timer lifecycle

### theme.sh (Configuration)

Defines visual appearance:
- Colors for each state (Catppuccin Frappe palette)
- Toggle switches for features (ENABLE_BACKGROUND_CHANGE, ENABLE_TITLE_PREFIX)
- Anthropomorphising configuration (face themes)

### themes.sh (Face Library)

Collection of ASCII face themes:
- minimal, bear, cat, lenny, shrug, plain
- Claude-branded themes: claudA, claudB, claudC, claudD, claudE, claudF
- Each theme defines faces for all states including idle stages

### state.sh (State Management)

Session state tracking:
- Records current state to file
- Manages state transitions
- Prevents duplicate signals

### terminal.sh (OSC Functions)

Terminal escape sequence functions:
- `send_osc_bg` - Change background color
- `send_osc_title` - Update tab title
- `send_bell_if_enabled` - Notification bell

### idle-worker.sh (Idle Timer)

Background process for graduated idle states:
- Spawns after completion
- Cycles through 6 idle stages
- Respects skip signals from new activity

## Agent Adapters

### Claude Code (Shell Hooks)

- **Method:** JSON hooks in `~/.claude/settings.json`
- **Path:** `${CLAUDE_PLUGIN_ROOT}` variable
- **Features:** Full event coverage (9 events)
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
- **Package:** `@terminal-visual-signals/opencode-plugin`

## Visual States

| State | Color (Hex) | Emoji | Description |
|-------|-------------|-------|-------------|
| Processing | `#ef9f76` | 🟠 | Agent working |
| Permission | `#e78284` | 🔴 | Needs user approval |
| Complete | `#a6d189` | 🟢 | Response finished |
| Idle (6 stages) | `#ca9ee6` → deeper | 🟣 | Graduated idle |
| Compacting | `#81c8be` | 🔄 | Context compression |
| Reset | Default | - | Clear state |

## Data Flow

```
User submits prompt
       │
       ▼
CLI Hook fires (UserPromptSubmit/BeforeAgent/onUserPrompt)
       │
       ▼
Agent trigger.sh called with "processing"
       │
       ▼
Core trigger.sh:
  1. Kill any existing idle timer
  2. Check state change needed
  3. Send OSC 11 (background color)
  4. Send OSC 0 (title with emoji/face)
  5. Record state
       │
       ▼
[Agent works, tools execute...]
       │
       ▼
CLI Hook fires (Stop/AfterAgent/onAgentResponse)
       │
       ▼
Core trigger.sh called with "complete"
  1. Send complete signals
  2. Spawn idle-worker.sh background process
       │
       ▼
[30+ seconds pass without activity]
       │
       ▼
idle-worker.sh transitions through idle stages
```

## Configuration Files

| File | Purpose |
|------|---------|
| `~/.claude/settings.json` | Claude Code hooks and plugin enablement |
| `~/.gemini/settings.json` | Gemini CLI hooks |
| `~/.codex/config.toml` | Codex CLI notify setting |
| `~/.opencode/config.json` | OpenCode plugin configuration |

## Related

- [Testing](testing.md) - How to test the visual signals
- [Troubleshooting](../troubleshooting/overview.md) - Common issues
