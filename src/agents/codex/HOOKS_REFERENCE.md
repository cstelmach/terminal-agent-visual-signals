# Codex CLI Hooks Reference for Terminal Visual Signals

**Last Updated:** 2026-01-08
**Codex CLI Version:** v0.2.x (Latest as of January 2026)
**Documentation Sources:** [OpenAI Codex CLI](https://developers.openai.com/codex/cli), [GitHub Repository](https://github.com/openai/codex)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Current Status: No Hooks System](#2-current-status-no-hooks-system)
3. [Available Event Mechanisms](#3-available-event-mechanisms)
   - [notify Configuration](#notify-configuration)
   - [tui.notifications](#tuinotifications)
   - [codex exec --json](#codex-exec---json)
4. [Comparison with Claude Code and Gemini CLI](#4-comparison-with-claude-code-and-gemini-cli)
5. [Visual Signal Limitations](#5-visual-signal-limitations)
6. [Community Feature Requests](#6-community-feature-requests)
7. [Proposed Hook Events (Future)](#7-proposed-hook-events-future)
8. [Workarounds](#8-workarounds)
9. [Configuration Examples](#9-configuration-examples)
10. [When Hooks Are Implemented](#10-when-hooks-are-implemented)
11. [References](#11-references)

---

## 1. Overview

**⚠️ CRITICAL: Codex CLI does NOT have a hooks system comparable to Claude Code or Gemini CLI.**

Unlike Claude Code (10 hook events) and Gemini CLI (11 hook events), OpenAI's Codex CLI currently provides only a basic notification mechanism that fires on a single event type.

### Current State Summary

| Feature | Claude Code | Gemini CLI | Codex CLI |
|---------|-------------|------------|-----------|
| **Full Hooks System** | ✅ Yes | ✅ Yes | ❌ No |
| **Lifecycle Events** | 10 events | 11 events | 1 event* |
| **Session Start/End** | ✅ | ✅ | ❌ |
| **Tool Execution Hooks** | ✅ PreToolUse/PostToolUse | ✅ BeforeTool/AfterTool | ❌ |
| **Permission Hooks** | ✅ PermissionRequest | ❌ (no approval model) | ❌ |
| **Blocking Hooks** | ✅ exit code 2 | ❌ | ❌ |
| **Input Modification** | ✅ via stdout | ❌ | ❌ |
| **Context Compression** | ✅ PreCompact | ✅ PreCompress | ❌ |
| **JSON Payload to Hooks** | ✅ via stdin | ✅ via stdin | ✅ limited |

*Codex CLI's `notify` feature only fires on `agent-turn-complete`.

---

## 2. Current Status: No Hooks System

As of January 2026, Codex CLI does **not** implement a hooks system. The development team has acknowledged community requests but has not committed to a timeline.

### What This Means for Terminal Visual Signals

| Visual State | Claude Code | Gemini CLI | Codex CLI |
|--------------|-------------|------------|-----------|
| **processing** (🟠) | UserPromptSubmit, PreToolUse | BeforeAgent, BeforeTool | ❌ Not possible |
| **permission** (🔴) | PermissionRequest | N/A | ❌ Not possible |
| **complete** (🟢) | Stop | AfterAgent | ✅ `notify` (limited) |
| **idle** (🟣) | Notification(idle_prompt) | N/A | ❌ Not possible |
| **compacting** (🔄) | PreCompact | PreCompress | ❌ Not possible |
| **reset** | SessionStart/End | SessionStart/End | ❌ Not possible |

**Result:** Only the `complete` state can be triggered via Codex CLI's `notify` mechanism.

---

## 3. Available Event Mechanisms

### notify Configuration

The `notify` setting in `~/.codex/config.toml` allows running a command when specific events occur.

```toml
# ~/.codex/config.toml
notify = ["bash", "-lc", "/path/to/your/script.sh"]
```

#### Supported Events

| Event | Description |
|-------|-------------|
| `agent-turn-complete` | Agent has finished processing (only supported event) |

#### JSON Payload

The notify command receives a JSON payload via stdin:

```json
{
  "type": "agent-turn-complete",
  "thread-id": "thread_abc123",
  "turn-id": "turn_xyz789",
  "cwd": "/path/to/working/directory",
  "input-messages": [...],
  "last-assistant-message": "Here is the result..."
}
```

#### Example Script

```bash
#!/bin/bash
# ~/.codex/hooks/on-complete.sh

# Read JSON payload from stdin
payload=$(cat)

# Extract information
turn_id=$(echo "$payload" | jq -r '.["turn-id"]')
event_type=$(echo "$payload" | jq -r '.type')

# Only handle agent-turn-complete
if [[ "$event_type" == "agent-turn-complete" ]]; then
    # Trigger visual signal
    ~/.claude/hooks/terminal-agent-visual-signals/src/agents/codex/trigger.sh complete
fi
```

---

### tui.notifications

Desktop notifications for the TUI (Terminal User Interface) mode.

```toml
# ~/.codex/config.toml
[tui]
notifications = ["agent-turn-complete", "approval-requested"]
```

| Event | Description |
|-------|-------------|
| `agent-turn-complete` | Agent finished processing |
| `approval-requested` | Agent needs user approval |

**Note:** These are desktop notifications (OS-level), not shell hooks. They cannot be used to trigger custom scripts or terminal visual signals.

---

### codex exec --json

For CI/CD and non-interactive use, Codex provides JSON event streaming:

```bash
codex exec --json "your task here" | jq
```

#### Event Types

| Event | Description |
|-------|-------------|
| `thread.started` | Thread/session began |
| `turn.started` | Turn began |
| `turn.completed` | Turn finished successfully |
| `turn.failed` | Turn failed with error |
| `item.created` | Item (message/tool) created |
| `item.updated` | Item updated |
| `item.completed` | Item completed |
| `error` | Error occurred |

#### Example Output

```json
{"event":"thread.started","data":{"thread_id":"thread_abc123"}}
{"event":"turn.started","data":{"turn_id":"turn_xyz789"}}
{"event":"item.created","data":{"item":{"type":"message","role":"assistant"}}}
{"event":"turn.completed","data":{"turn_id":"turn_xyz789"}}
```

#### Limitations

- **Non-interactive only**: Does not work with the TUI
- **Requires streaming**: Must process newline-delimited JSON
- **No shell integration**: Cannot trigger terminal visual signals in interactive mode

---

## 4. Comparison with Claude Code and Gemini CLI

### Event Mapping

| Purpose | Claude Code | Gemini CLI | Codex CLI |
|---------|-------------|------------|-----------|
| Session start | `SessionStart` | `SessionStart` | ❌ |
| Session end | `SessionEnd` | `SessionEnd` | ❌ |
| User prompt | `UserPromptSubmit` | `BeforeAgent` | ❌ |
| Before LLM call | — | `BeforeModel` | ❌ |
| After LLM call | — | `AfterModel` | ❌ |
| Before tool | `PreToolUse` | `BeforeTool` | ❌ |
| After tool | `PostToolUse` | `AfterTool` | ❌ |
| Permission needed | `PermissionRequest` | — | ❌ |
| Agent complete | `Stop` | `AfterAgent` | `notify`* |
| Subagent complete | `SubagentStop` | — | ❌ |
| Context compress | `PreCompact` | `PreCompress` | ❌ |
| Notification | `Notification` | `Notification` | `tui.notifications`** |

*Only via `notify` configuration
**Desktop notifications only, not shell hooks

### Feature Comparison

| Feature | Claude Code | Gemini CLI | Codex CLI |
|---------|-------------|------------|-----------|
| Configuration file | `settings.json` | `settings.json` | `config.toml` |
| Hooks per event | Multiple | Multiple | Single |
| Matchers/patterns | ✅ regex/glob | ✅ regex | ❌ |
| Blocking capability | ✅ exit 2 | ❌ | ❌ |
| Timeout control | ✅ configurable | ✅ | ❌ |
| Modify input | ✅ via stdout | ❌ | ❌ |
| JSON payload | ✅ comprehensive | ✅ comprehensive | ✅ limited |

---

## 5. Visual Signal Limitations

### What Works

```
✅ COMPLETE STATE ONLY
   └─→ trigger.sh complete (via notify)
       └─→ Terminal background: Green (#1a472a)
       └─→ Terminal title: 🟢 Codex
```

### What Does NOT Work

```
❌ PROCESSING STATE
   └─→ No hook fires when Codex starts processing

❌ PERMISSION STATE
   └─→ Codex uses different approval model (approval-requested notification only)

❌ IDLE STATE
   └─→ No idle detection mechanism

❌ COMPACTING STATE
   └─→ No context compression hook

❌ SESSION LIFECYCLE
   └─→ No session start/end hooks
```

### Practical Impact

```
┌─────────────────────────────────────────────────────────────────────┐
│                     CODEX CLI VISUAL SIGNALS                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  User types prompt                                                   │
│       │                                                              │
│       ▼                                                              │
│  [NO VISUAL CHANGE] ← Cannot detect prompt submission               │
│       │                                                              │
│       ▼                                                              │
│  Codex processes...                                                  │
│       │                                                              │
│       ▼                                                              │
│  [NO VISUAL CHANGE] ← Cannot detect processing state                │
│       │                                                              │
│       ▼                                                              │
│  Codex needs approval?                                               │
│       │                                                              │
│       ▼                                                              │
│  [NO VISUAL CHANGE] ← Cannot hook into approval requests            │
│       │                                                              │
│       ▼                                                              │
│  Codex completes                                                     │
│       │                                                              │
│       ▼                                                              │
│  [GREEN BACKGROUND] ← notify fires agent-turn-complete              │
│       │                                                              │
│       ▼                                                              │
│  User starts new prompt                                              │
│       │                                                              │
│       ▼                                                              │
│  [STAYS GREEN] ← Cannot detect new prompt, no reset possible        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 6. Community Feature Requests

The Codex CLI community has been actively requesting a proper hooks system.

### GitHub Discussion #2150 (60+ votes)

**Title:** "Feature Request: Hook System for Codex CLI"
**URL:** https://github.com/openai/codex/discussions/2150
**Status:** Open (no official commitment)

Key community asks:
- Session lifecycle hooks (start/end)
- Tool execution hooks (before/after)
- Context compression hooks
- Blocking hooks for automation

### GitHub Issue #2109 (37+ thumbs up)

**Title:** "Add proper event hooks like Claude Code"
**URL:** https://github.com/openai/codex/issues/2109
**Status:** Open

### GitHub Issue #3052

**Title:** "Extended notification events"
**URL:** https://github.com/openai/codex/issues/3052
**Status:** Open

Requests additional events for `notify`:
- `approval-requested`
- `tool-execution-started`
- `tool-execution-completed`

### GitHub Issue #2582

**Title:** "Plugin/Extension system proposal"
**URL:** https://github.com/openai/codex/issues/2582
**Status:** Discussion

Proposes a broader plugin architecture similar to VS Code extensions.

### Official Response

OpenAI's response to hook requests has been: "If you'd like to see this feature, please upvote the discussion."

No timeline or commitment has been provided.

---

## 7. Proposed Hook Events (Future)

If/when Codex CLI implements hooks, here's what we would need for full visual signal support:

### Minimum Required Events

| Event | Visual Signal | Priority |
|-------|---------------|----------|
| `SessionStart` | reset | High |
| `SessionEnd` | reset | High |
| `BeforeExecution` | processing | Critical |
| `AfterExecution` | complete | Already exists (notify) |
| `ApprovalRequested` | permission | High |

### Ideal Full Implementation

```json
{
  "hooks": {
    "SessionStart": [...],
    "SessionEnd": [...],
    "BeforeAgent": [...],
    "AfterAgent": [...],
    "BeforeTool": [...],
    "AfterTool": [...],
    "ApprovalRequested": [...],
    "PreCompress": [...]
  }
}
```

---

## 8. Workarounds

### Workaround 1: notify + Timer Reset

Use the single `notify` event to trigger complete, then rely on a timer to reset.

```bash
#!/bin/bash
# ~/.codex/hooks/on-complete.sh

TRIGGER="$HOME/.claude/hooks/terminal-agent-visual-signals/src/agents/codex/trigger.sh"

# Set complete state
"$TRIGGER" complete

# Background process to reset after 60 seconds
(sleep 60 && "$TRIGGER" reset) &
```

**Limitation:** No visual feedback during processing.

### Workaround 2: codex exec Wrapper (CI/CD Only)

For non-interactive use, wrap `codex exec --json`:

```bash
#!/bin/bash
# codex-wrapper.sh

TRIGGER="$HOME/.claude/hooks/terminal-agent-visual-signals/src/agents/codex/trigger.sh"

# Start processing indicator
"$TRIGGER" processing

# Run codex with JSON streaming
codex exec --json "$@" | while read -r line; do
    event=$(echo "$line" | jq -r '.event')

    case "$event" in
        "turn.completed")
            "$TRIGGER" complete
            ;;
        "turn.failed")
            "$TRIGGER" reset
            ;;
    esac

    # Pass through output
    echo "$line"
done
```

**Limitation:** Only works in non-interactive mode.

### Workaround 3: Manual Keyboard Trigger

Bind a keyboard shortcut to manually trigger states.

```bash
# Add to ~/.bashrc or ~/.zshrc
alias codex-processing='~/.claude/hooks/terminal-agent-visual-signals/src/agents/codex/trigger.sh processing'
alias codex-complete='~/.claude/hooks/terminal-agent-visual-signals/src/agents/codex/trigger.sh complete'
alias codex-reset='~/.claude/hooks/terminal-agent-visual-signals/src/agents/codex/trigger.sh reset'
```

**Limitation:** Requires manual intervention.

---

## 9. Configuration Examples

### Minimal notify Setup

```toml
# ~/.codex/config.toml

# Trigger visual signal on completion
notify = ["bash", "-lc", "~/.claude/hooks/terminal-agent-visual-signals/src/agents/codex/trigger.sh complete"]
```

### With Desktop Notifications

```toml
# ~/.codex/config.toml

# Visual signal on completion
notify = ["bash", "-lc", "~/.claude/hooks/terminal-agent-visual-signals/src/agents/codex/trigger.sh complete"]

# Desktop notifications for awareness
[tui]
notifications = ["agent-turn-complete", "approval-requested"]
```

### With Logging

```toml
# ~/.codex/config.toml

# Script that logs and triggers visual
notify = ["bash", "-lc", "~/.codex/hooks/on-complete.sh"]
```

```bash
#!/bin/bash
# ~/.codex/hooks/on-complete.sh

# Read payload
payload=$(cat)

# Log the event
echo "[$(date '+%Y-%m-%d %H:%M:%S')] agent-turn-complete" >> ~/.codex/hooks.log
echo "$payload" | jq . >> ~/.codex/hooks.log

# Trigger visual signal
~/.claude/hooks/terminal-agent-visual-signals/src/agents/codex/trigger.sh complete
```

---

## 10. When Hooks Are Implemented

When Codex CLI adds a proper hooks system, update the following:

### 1. Update hooks.json

Replace the placeholder with actual hook definitions:

```json
{
  "SessionStart": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/terminal-agent-visual-signals/src/agents/codex/trigger.sh reset"
        }
      ]
    }
  ],
  "SessionEnd": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/terminal-agent-visual-signals/src/agents/codex/trigger.sh reset"
        }
      ]
    }
  ],
  "BeforeAgent": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/terminal-agent-visual-signals/src/agents/codex/trigger.sh processing"
        }
      ]
    }
  ],
  "AfterAgent": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/terminal-agent-visual-signals/src/agents/codex/trigger.sh complete"
        }
      ]
    }
  ],
  "BeforeTool": [
    {
      "matcher": "*",
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/terminal-agent-visual-signals/src/agents/codex/trigger.sh processing"
        }
      ]
    }
  ],
  "AfterTool": [
    {
      "matcher": "*",
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/terminal-agent-visual-signals/src/agents/codex/trigger.sh processing"
        }
      ]
    }
  ],
  "ApprovalRequested": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/terminal-agent-visual-signals/src/agents/codex/trigger.sh permission"
        }
      ]
    }
  ],
  "PreCompress": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/terminal-agent-visual-signals/src/agents/codex/trigger.sh compacting"
        }
      ]
    }
  ]
}
```

### 2. Update README.md

Remove the "NOT YET AVAILABLE" notice and document actual usage.

### 3. Test All States

Verify each visual state triggers correctly:
- `processing` (🟠) on BeforeAgent/BeforeTool
- `permission` (🔴) on ApprovalRequested
- `complete` (🟢) on AfterAgent
- `compacting` (🔄) on PreCompress
- `reset` on SessionStart/SessionEnd

---

## 11. References

### Official Documentation

- [Codex CLI Documentation](https://developers.openai.com/codex/cli)
- [Codex CLI Features](https://developers.openai.com/codex/cli/features/)
- [Codex CLI Configuration](https://developers.openai.com/codex/cli/configuration/)
- [Codex CLI GitHub Repository](https://github.com/openai/codex)

### Feature Requests

- [Discussion #2150: Hook System Request](https://github.com/openai/codex/discussions/2150) (60+ votes)
- [Issue #2109: Claude-like Hooks](https://github.com/openai/codex/issues/2109) (37+ thumbs up)
- [Issue #3052: Extended Notification Events](https://github.com/openai/codex/issues/3052)
- [Issue #2582: Plugin System Proposal](https://github.com/openai/codex/issues/2582)

### Related Documentation

- [Claude Code Hooks Reference](../claude/HOOKS_REFERENCE.md)
- [Gemini CLI Hooks Reference](../gemini/HOOKS_REFERENCE.md)
- [Terminal Visual Signals Core Documentation](../../core/README.md)

---

## Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2026-01-08 | 1.0.0 | Initial documentation of Codex CLI limitations |

---

*This document will be updated when Codex CLI implements a proper hooks system.*
