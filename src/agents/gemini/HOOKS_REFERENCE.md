# Gemini CLI Hooks Reference for TAVS

**Last Updated:** 2026-01-07
**Gemini CLI Version:** v0.24.0+
**Documentation Sources:** [geminicli.com](https://geminicli.com/docs/hooks/), [GitHub](https://github.com/google-gemini/gemini-cli)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Hook Execution Flow](#2-hook-execution-flow)
3. [Complete Hook Reference](#3-complete-hook-reference)
   - [SessionStart](#sessionstart)
   - [SessionEnd](#sessionend)
   - [BeforeAgent](#beforeagent)
   - [AfterAgent](#afteragent)
   - [BeforeModel](#beforemodel)
   - [AfterModel](#aftermodel)
   - [BeforeToolSelection](#beforetoolselection)
   - [BeforeTool](#beforetool)
   - [AfterTool](#aftertool)
   - [PreCompress](#precompress)
   - [Notification](#notification)
4. [Visual Signal Mapping](#4-visual-signal-mapping)
5. [Configuration Guide](#5-configuration-guide)
6. [Communication Protocol](#6-communication-protocol)
7. [BeforeModel/AfterModel: Should You Use Them?](#7-beforemodelaftermodel-should-you-use-them)
8. [Comparison with Claude Code](#8-comparison-with-claude-code)
9. [Known Issues & Troubleshooting](#9-known-issues--troubleshooting)
10. [Best Practices](#10-best-practices)
11. [References](#11-references)

---

## 1. Overview

Gemini CLI provides **11 hook events** that fire at specific points in the agentic loop. This allows customization of behavior without modifying the core CLI.

### Key Characteristics

| Property | Value |
|----------|-------|
| **Protocol** | JSON via stdin/stdout |
| **Exit Codes** | 0=success, 2=block |
| **Execution** | Synchronous (blocks agent loop) |
| **Default State** | Disabled |
| **Hook Types** | Command only (plugins planned) |

### Quick Setup

```json
// ~/.gemini/settings.json
{
  "tools": {
    "enableHooks": true
  }
}
```

---

## 2. Hook Execution Flow

### Master Execution Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        GEMINI CLI HOOK EXECUTION FLOW                         │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                           SESSION LIFECYCLE                              │ │
│  ├─────────────────────────────────────────────────────────────────────────┤ │
│  │  USER STARTS GEMINI CLI                                                  │ │
│  │  └─→ SessionStart ─────────────────────────────────→ reset              │ │
│  │      source: startup | resume | clear                                    │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                        │
│                                      ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                           USER SUBMITS PROMPT                            │ │
│  ├─────────────────────────────────────────────────────────────────────────┤ │
│  │  BeforeAgent ──────────────────────────────────────→ processing (🟠)    │ │
│  │      Fires: ONCE per user prompt                                         │ │
│  │      Input: prompt, stop_hook_active                                     │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                        │
│                                      ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                           LLM PROCESSING                                 │ │
│  ├─────────────────────────────────────────────────────────────────────────┤ │
│  │  ┌───────────────────────────────────────────────────────────────────┐  │ │
│  │  │  BeforeModel ─────────────────────────────────→ ⚠️ OPTIONAL       │  │ │
│  │  │      Fires: Before EVERY LLM call (multiple times!)               │  │ │
│  │  │      Input: llm_request                                           │  │ │
│  │  └───────────────────────────────────────────────────────────────────┘  │ │
│  │                              │                                           │ │
│  │                              ▼                                           │ │
│  │                    ┌─────────────────┐                                   │ │
│  │                    │    [LLM CALL]   │                                   │ │
│  │                    │   (Gemini API)  │                                   │ │
│  │                    └─────────────────┘                                   │ │
│  │                              │                                           │ │
│  │                              ▼                                           │ │
│  │  ┌───────────────────────────────────────────────────────────────────┐  │ │
│  │  │  AfterModel ──────────────────────────────────→ ❌ NOT USEFUL     │  │ │
│  │  │      Fires: After EVERY LLM response (multiple times!)            │  │ │
│  │  │      Input: llm_request, llm_response                             │  │ │
│  │  │      Note: Agent NOT done yet - can't show "complete"             │  │ │
│  │  └───────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                          │ │
│  │  ⚠️ This section can REPEAT multiple times per prompt!                  │ │
│  │     (Extended thinking, multi-step reasoning)                            │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                        │
│           ┌──────────────────────────┴──────────────────────────┐            │
│           │                                                      │            │
│           ▼ (LLM decides: no tools)                             ▼ (tools)    │
│  ┌────────────────────┐                          ┌────────────────────────┐  │
│  │  Skip to AfterAgent│                          │   TOOL EXECUTION       │  │
│  └────────────────────┘                          ├────────────────────────┤  │
│                                                  │  BeforeToolSelection   │  │
│                                                  │      (optional)        │  │
│                                                  │          │             │  │
│                                                  │          ▼             │  │
│                                                  │  BeforeTool ─→ proc.   │  │
│                                                  │      Per tool          │  │
│                                                  │          │             │  │
│                                                  │          ▼             │  │
│                                                  │    [TOOL RUNS]         │  │
│                                                  │          │             │  │
│                                                  │          ▼             │  │
│                                                  │  AfterTool ──→ proc.   │  │
│                                                  │      Per tool          │  │
│                                                  │          │             │  │
│                                                  │  (May loop to LLM      │  │
│                                                  │   for more tools)      │  │
│                                                  └────────────┬───────────┘  │
│                                                               │              │
│           ┌───────────────────────────────────────────────────┘              │
│           │                                                                   │
│           ▼                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                           AGENT COMPLETES                                │ │
│  ├─────────────────────────────────────────────────────────────────────────┤ │
│  │  AfterAgent ───────────────────────────────────────→ complete (🟢)      │ │
│  │      Fires: ONCE when agent loop finishes                                │ │
│  │      Input: prompt, prompt_response, stop_hook_active                    │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                        │
│                                      ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                           IDLE TIMER STARTS                              │ │
│  ├─────────────────────────────────────────────────────────────────────────┤ │
│  │  (Internal to trigger script)                                            │ │
│  │  After configured timeout ─────────────────────────→ idle (🟣)          │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
├───────────────────────────────────────────────────────────────────────────────┤
│                           SPECIAL EVENTS                                      │
├───────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │  PERMISSION REQUEST                                                      │ │
│  │  Notification (matcher: ToolPermission) ───────────→ permission (🔴)    │ │
│  │      Fires: When tool needs user approval                                │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │  CONTEXT COMPRESSION                                                     │ │
│  │  PreCompress ──────────────────────────────────────→ compacting (🔄)    │ │
│  │      trigger: manual | auto (at 70% token threshold)                     │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │  SESSION ENDS                                                            │ │
│  │  SessionEnd ───────────────────────────────────────→ reset              │ │
│  │      reason: exit | clear | logout | prompt_input_exit | other           │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Scenario: Simple Prompt (No Tools)

```
┌──────────────────────────────────────────────────────────────────┐
│ User: "What is the capital of France?"                           │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  T=0.00s  BeforeAgent ────────────────→ 🟠 processing            │
│  T=0.05s  BeforeModel (optional) ─────→ 🟠 processing (same)     │
│  T=0.05s  [LLM thinking...]                                       │
│  T=2.00s  AfterModel (not useful)                                 │
│  T=2.05s  AfterAgent ─────────────────→ 🟢 complete              │
│  T=62.0s  [Idle timer] ───────────────→ 🟣 idle                  │
│                                                                   │
│  Total hooks fired: 2-4 (depending on config)                     │
└──────────────────────────────────────────────────────────────────┘
```

### Scenario: Prompt with Tool Use

```
┌──────────────────────────────────────────────────────────────────┐
│ User: "Read the README.md file"                                  │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  T=0.00s  BeforeAgent ────────────────→ 🟠 processing            │
│  T=0.05s  BeforeModel (planning) ─────→ 🟠 (optional)            │
│  T=1.00s  [LLM decides to use Read tool]                          │
│  T=1.05s  AfterModel                                              │
│  T=1.10s  BeforeToolSelection                                     │
│  T=1.15s  BeforeTool ─────────────────→ 🟠 processing            │
│  T=1.20s  [Read tool executes]                                    │
│  T=1.50s  AfterTool ──────────────────→ 🟠 processing            │
│  T=1.55s  BeforeModel (synthesis) ────→ 🟠 (optional)            │
│  T=3.00s  [LLM synthesizes response]                              │
│  T=3.05s  AfterModel                                              │
│  T=3.10s  AfterAgent ─────────────────→ 🟢 complete              │
│                                                                   │
│  Total hooks fired: 4-8 (depending on config)                     │
└──────────────────────────────────────────────────────────────────┘
```

### Scenario: Multi-LLM Extended Thinking

```
┌──────────────────────────────────────────────────────────────────┐
│ User: "Analyze this complex architecture..."                     │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  T=0.00s  BeforeAgent ────────────────→ 🟠 processing            │
│                                                                   │
│  ┌─ LLM Call 1 ───────────────────────────────────────────────┐  │
│  │  BeforeModel → [LLM thinking] → AfterModel                 │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌─ LLM Call 2 ───────────────────────────────────────────────┐  │
│  │  BeforeModel → [LLM thinking] → AfterModel                 │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌─ LLM Call 3 ───────────────────────────────────────────────┐  │
│  │  BeforeModel → [LLM thinking] → AfterModel                 │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  T=15.0s  AfterAgent ─────────────────→ 🟢 complete              │
│                                                                   │
│  Note: BeforeModel/AfterModel fired 3x each!                      │
│  If using BeforeModel for "processing", that's 6 extra hooks      │
└──────────────────────────────────────────────────────────────────┘
```

---

## 3. Complete Hook Reference

### SessionStart

| Property | Value |
|----------|-------|
| **Category** | Session Lifecycle |
| **Fires** | When a new session begins |
| **Frequency** | Once per session |
| **Visual Signal** | `reset` |

#### Trigger Conditions

| Source | Description |
|--------|-------------|
| `startup` | Fresh session start |
| `resume` | Resuming a previous session |
| `clear` | Session was cleared |

#### Input Payload

```json
{
  "event": "SessionStart",
  "session_id": "abc123-def456",
  "source": "startup",
  "timestamp": "2026-01-07T12:00:00.000Z",
  "cwd": "/path/to/project",
  "transcript_path": "/path/to/transcript.json"
}
```

#### Output Capabilities

```json
{
  "hookSpecificOutput": {
    "additionalContext": "Inject text into agent context"
  }
}
```

#### Use Cases

- Initialize session-specific resources
- Load cross-session memory
- Set up logging
- **Visual Signals:** Reset terminal to default state

#### Example Hook

```bash
#!/bin/bash
# SessionStart hook for visual signals
input=$(cat)
source=$(echo "$input" | jq -r '.source')

echo "[SessionStart] source=$source" >> /tmp/gemini-hooks.log

# Reset terminal visual state
/path/to/trigger.sh reset

exit 0
```

---

### SessionEnd

| Property | Value |
|----------|-------|
| **Category** | Session Lifecycle |
| **Fires** | When session terminates |
| **Frequency** | Once per session |
| **Visual Signal** | `reset` |

#### Trigger Conditions

| Reason | Description |
|--------|-------------|
| `exit` | Normal exit (user typed /exit or Ctrl+C) |
| `clear` | Session was cleared |
| `logout` | User logged out |
| `prompt_input_exit` | Exit from prompt input |
| `other` | Other reasons |

#### Input Payload

```json
{
  "event": "SessionEnd",
  "session_id": "abc123-def456",
  "reason": "exit",
  "timestamp": "2026-01-07T14:00:00.000Z"
}
```

#### Use Cases

- Persist session data
- Cleanup resources
- Generate session summaries
- **Visual Signals:** Clear all visual state

---

### BeforeAgent

| Property | Value |
|----------|-------|
| **Category** | Agent Loop |
| **Fires** | Before agent loop processes input |
| **Frequency** | **ONCE per user prompt** ⭐ |
| **Visual Signal** | `processing` |

#### Why This Hook Is Important

BeforeAgent fires **exactly once** when the user submits a prompt, making it perfect for signaling that processing has started. Unlike BeforeModel which fires multiple times, BeforeAgent is clean and predictable.

#### Input Payload

```json
{
  "event": "BeforeAgent",
  "session_id": "abc123-def456",
  "prompt": "Read the README.md file",
  "stop_hook_active": false,
  "timestamp": "2026-01-07T12:00:00.000Z"
}
```

#### Output Capabilities

```json
{
  "hookSpecificOutput": {
    "additionalContext": "Inject context before agent starts"
  }
}
```

#### Use Cases

- Inject memories or context
- Validate or transform user input
- **Visual Signals:** Show "processing" indicator (🟠 orange)

#### Example Hook

```bash
#!/bin/bash
# BeforeAgent hook - fires ONCE per prompt
input=$(cat)
prompt=$(echo "$input" | jq -r '.prompt')

# Log the prompt
echo "[BeforeAgent] prompt: $prompt" >> /tmp/gemini-hooks.log

# Set visual state to processing
/path/to/trigger.sh processing

exit 0
```

---

### AfterAgent

| Property | Value |
|----------|-------|
| **Category** | Agent Loop |
| **Fires** | After agent loop completes |
| **Frequency** | **ONCE per completion** ⭐ |
| **Visual Signal** | `complete` |

#### Why This Hook Is Important

AfterAgent fires **exactly once** when the agent finishes responding, making it perfect for signaling completion. This is different from AfterModel which fires after every LLM call.

#### Input Payload

```json
{
  "event": "AfterAgent",
  "session_id": "abc123-def456",
  "prompt": "Read the README.md file",
  "prompt_response": "Here is the content of README.md:\n...",
  "stop_hook_active": false,
  "timestamp": "2026-01-07T12:00:05.000Z"
}
```

#### Use Cases

- Log interactions
- Consolidate memories
- **Visual Signals:** Show "complete" indicator (🟢 green)

#### Example Hook

```bash
#!/bin/bash
# AfterAgent hook - fires ONCE when done
input=$(cat)

# Set visual state to complete
/path/to/trigger.sh complete

exit 0
```

---

### BeforeModel

| Property | Value |
|----------|-------|
| **Category** | Model/LLM |
| **Fires** | Before sending LLM request |
| **Frequency** | **MULTIPLE times per agent loop!** ⚠️ |
| **Visual Signal** | `processing` (optional, see discussion below) |

#### ⚠️ Important: Multiple Fires

BeforeModel fires **before every LLM API call**, which can happen multiple times:

- Planning call (deciding what to do)
- Synthesis call (after tools return)
- Extended thinking (multiple reasoning steps)

#### Input Payload

```json
{
  "event": "BeforeModel",
  "session_id": "abc123-def456",
  "llm_request": {
    "model": "gemini-3-pro",
    "messages": [
      {"role": "user", "content": "Read the README.md file"}
    ],
    "config": {
      "temperature": 0.7,
      "maxOutputTokens": 8192,
      "topP": 0.95,
      "topK": 40
    },
    "toolConfig": {
      "mode": "AUTO",
      "allowedFunctionNames": ["Read", "Write", "Bash"]
    }
  }
}
```

#### Output Capabilities

```json
{
  "hookSpecificOutput": {
    "llm_request": {
      "config": {"temperature": 0.5}
    },
    "llm_response": {
      "text": "Synthetic response - bypass LLM entirely"
    }
  }
}
```

#### Use Cases

- Modify prompts dynamically
- Inject system instructions
- Control model parameters
- Provide synthetic responses (bypass LLM)

#### For Visual Signals

See [Section 7](#7-beforemodelaftermodel-should-you-use-them) for detailed discussion on whether to use this hook.

---

### AfterModel

| Property | Value |
|----------|-------|
| **Category** | Model/LLM |
| **Fires** | After receiving LLM response |
| **Frequency** | **MULTIPLE times per agent loop!** ⚠️ |
| **Visual Signal** | ❌ **NOT USEFUL** |

#### Why NOT Useful for Visual Signals

AfterModel fires after each LLM response, but the agent **isn't done yet**. You can't show "complete" because:
- Tools might still need to run
- More LLM calls might happen
- Only AfterAgent signals true completion

#### Input Payload

```json
{
  "event": "AfterModel",
  "session_id": "abc123-def456",
  "llm_request": { /* original request */ },
  "llm_response": {
    "text": "I'll read that file for you...",
    "candidates": [{
      "content": {"role": "model", "parts": ["..."]},
      "finishReason": "STOP"
    }],
    "usageMetadata": {
      "promptTokenCount": 150,
      "candidatesTokenCount": 50,
      "totalTokenCount": 200
    }
  }
}
```

#### Output Capabilities

```json
{
  "hookSpecificOutput": {
    "llm_response": {
      "text": "Modified response text"
    }
  }
}
```

#### Use Cases

- Process/sanitize LLM outputs
- Log interactions
- Extract information for analytics

---

### BeforeToolSelection

| Property | Value |
|----------|-------|
| **Category** | Planning |
| **Fires** | Before tool selection phase |
| **Frequency** | Once per tool decision |
| **Visual Signal** | None |

#### Input Payload

```json
{
  "event": "BeforeToolSelection",
  "session_id": "abc123-def456",
  "llm_request": { /* request context */ },
  "available_tools": ["Read", "Write", "Edit", "Bash", "Glob", "Grep"]
}
```

#### Output Capabilities

```json
{
  "hookSpecificOutput": {
    "toolConfig": {
      "mode": "AUTO",
      "allowedFunctionNames": ["Read", "Write", "Edit"]
    }
  }
}
```

#### Use Cases

- Filter available tools dynamically
- Implement RAG-based tool selection
- Reduce 100+ tools to relevant ~15

---

### BeforeTool

| Property | Value |
|----------|-------|
| **Category** | Tool Execution |
| **Fires** | Before each tool executes |
| **Frequency** | Once per tool |
| **Visual Signal** | `processing` |

#### Input Payload

```json
{
  "event": "BeforeTool",
  "session_id": "abc123-def456",
  "tool_name": "Read",
  "tool_input": {
    "file_path": "/path/to/README.md"
  }
}
```

#### Output Capabilities

```json
{
  "decision": "allow",  // allow | deny | block | ask
  "reason": "Explanation for deny/block"
}
```

#### Use Cases

- Validate tool calls
- Block dangerous operations
- Security guardrails (prevent committing secrets)
- **Visual Signals:** Maintain "processing" state during tool execution

#### Example: Security Hook

```bash
#!/bin/bash
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')

if [[ "$tool_name" == "Bash" ]]; then
  command=$(echo "$input" | jq -r '.tool_input.command')

  # Block dangerous commands
  if echo "$command" | grep -qE 'rm -rf|mkfs|dd if='; then
    jq -n '{decision: "deny", reason: "Dangerous command blocked"}'
    exit 2
  fi
fi

jq -n '{decision: "allow"}'
exit 0
```

---

### AfterTool

| Property | Value |
|----------|-------|
| **Category** | Tool Execution |
| **Fires** | After each tool completes |
| **Frequency** | Once per tool |
| **Visual Signal** | `processing` |

#### Input Payload

```json
{
  "event": "AfterTool",
  "session_id": "abc123-def456",
  "tool_name": "Read",
  "tool_input": {
    "file_path": "/path/to/README.md"
  },
  "tool_response": {
    "content": "# README\n\nThis is the content..."
  }
}
```

#### Output Capabilities

```json
{
  "hookSpecificOutput": {
    "additionalContext": "Inject context after tool"
  },
  "systemMessage": "Message displayed to user"
}
```

#### Use Cases

- Log tool executions
- Process results
- Trigger follow-up actions (auto-run tests)
- **Visual Signals:** Maintain "processing" state between tools

---

### PreCompress

| Property | Value |
|----------|-------|
| **Category** | Compression |
| **Fires** | Before context compression |
| **Frequency** | On demand |
| **Visual Signal** | `compacting` |

#### Trigger Conditions

| Trigger | Description |
|---------|-------------|
| `manual` | User ran `/compress` command |
| `auto` | Token usage reached 70% threshold |

#### Input Payload

```json
{
  "event": "PreCompress",
  "session_id": "abc123-def456",
  "trigger": "auto"
}
```

#### Use Cases

- Backup conversation before compression
- Analyze chat before compression
- **Visual Signals:** Show "compacting" indicator (🔄 teal)

---

### Notification

| Property | Value |
|----------|-------|
| **Category** | Notifications |
| **Fires** | On notification events |
| **Frequency** | Variable |
| **Visual Signal** | `permission` (for ToolPermission) |

#### Notification Types

| Type | Description |
|------|-------------|
| `ToolPermission` | Tool needs user approval |
| `Notification` | General notifications (errors, warnings, info) |

#### Input Payload

```json
{
  "event": "Notification",
  "session_id": "abc123-def456",
  "notification_type": "ToolPermission",
  "message": "Tool 'Bash' requires permission",
  "details": {
    "tool_name": "Bash",
    "command": "git push"
  }
}
```

#### Use Cases

- Send alerts to Slack/Teams
- Custom error handling
- **Visual Signals:** Show "permission" indicator (🔴 red)

#### ⚠️ Note: No Idle Notification

Unlike Claude Code, Gemini CLI does **NOT** have an `idle_prompt` notification. The idle state must be handled via internal timer (which this project does via `idle-worker.sh`).

---

## 4. Visual Signal Mapping

### Recommended Configuration

| Gemini Hook | Visual State | Color | Emoji | Fires |
|-------------|--------------|-------|-------|-------|
| `SessionStart` | `reset` | Default | — | Once at start |
| `BeforeAgent` | `processing` | #473D2F | 🟠 | **Once per prompt** |
| `BeforeTool` | `processing` | #473D2F | 🟠 | Per tool |
| `AfterTool` | `processing` | #473D2F | 🟠 | Per tool |
| `AfterAgent` | `complete` | #473046 | 🟢 | **Once when done** |
| `PreCompress` | `compacting` | #2B4645 | 🔄 | On compression |
| `Notification` (ToolPermission) | `permission` | #4A2021 | 🔴 | On permission request |
| `SessionEnd` | `reset` | Default | — | Once at end |

### Hooks NOT Used for Visual Signals

| Hook | Reason |
|------|--------|
| `BeforeModel` | Optional - see discussion in Section 7 |
| `AfterModel` | Cannot show "complete" - agent not done yet |
| `BeforeToolSelection` | Internal planning, not visible to user |

---

## 5. Configuration Guide

### Enable Hooks (Required!)

```json
// ~/.gemini/settings.json
{
  "tools": {
    "enableHooks": true
  }
}
```

### Configuration Locations

| Level | Path | Priority |
|-------|------|----------|
| Project | `.gemini/settings.json` | Highest |
| User | `~/.gemini/settings.json` | Medium |
| System | `/etc/gemini-cli/settings.json` | Lowest |
| Extension | `<extension>/hooks/hooks.json` | Per-extension |

### Hook Definition Structure

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "pattern",
        "hooks": [
          {
            "name": "unique-hook-name",
            "type": "command",
            "command": "/absolute/path/to/script.sh",
            "description": "Human-readable description",
            "timeout": 60000
          }
        ]
      }
    ]
  }
}
```

### Hook Properties

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `name` | string | Recommended | Command path | Unique identifier |
| `type` | string | Required | — | Currently only `"command"` |
| `command` | string | Required | — | Path to script |
| `description` | string | Optional | — | Shown in `/hooks panel` |
| `timeout` | number | Optional | 60000 | Timeout in ms |
| `matcher` | string | Optional | — | Filter pattern |

### Path Resolution

| Variable | Description |
|----------|-------------|
| `$GEMINI_PROJECT_DIR` | Project root directory |
| `${extensionPath}` | Extension installation directory |
| `${workspacePath}` | Current workspace |

**⚠️ Important:** Use **absolute paths**. Tilde (`~`) expansion may not work reliably!

```json
// ❌ BAD - tilde may not expand
"command": "~/.gemini/hooks/script.sh"

// ✅ GOOD - absolute path
"command": "/Users/username/.gemini/hooks/script.sh"

// ✅ GOOD - variable substitution
"command": "$GEMINI_PROJECT_DIR/.gemini/hooks/script.sh"
```

### Matchers

| Pattern | Description | Example |
|---------|-------------|---------|
| `*` | Match all | All tools |
| `ToolName` | Exact match | `"Read"` |
| `A\|B` | Multiple (regex OR) | `"Read\|Write"` |
| `^pattern.*` | Regex | `"^Write.*"` |

#### Event-Specific Matchers

| Event | Matchers |
|-------|----------|
| SessionStart | `startup`, `resume`, `clear` |
| SessionEnd | `exit`, `clear`, `logout`, `prompt_input_exit`, `other` |
| PreCompress | `manual`, `auto` |
| BeforeTool/AfterTool | Tool names or `*` |
| Notification | `ToolPermission`, `Notification` |

---

## 6. Communication Protocol

### Input (stdin)

All hooks receive JSON via stdin with base fields:

```json
{
  "session_id": "unique-session-id",
  "transcript_path": "/path/to/transcript.json",
  "cwd": "/current/working/directory",
  "hook_event_name": "BeforeTool",
  "timestamp": "2026-01-07T12:34:56.789Z"
}
```

Plus event-specific fields (see each hook's section above).

### Output (stdout)

Return JSON to communicate back:

```json
{
  "decision": "allow",
  "reason": "string",
  "systemMessage": "Message shown to user",
  "continue": true,
  "stopReason": "string",
  "suppressOutput": false,
  "hookSpecificOutput": {}
}
```

### Exit Codes

| Code | Meaning | Behavior |
|------|---------|----------|
| `0` | Success | Operation continues |
| `1` | Warning | Logged, operation continues |
| `2` | Block | Operation blocked, stderr shown |

### Example Script Template

```bash
#!/bin/bash
# Hook script template

# Read JSON input from stdin
input=$(cat)

# Parse fields
session_id=$(echo "$input" | jq -r '.session_id')
event=$(echo "$input" | jq -r '.hook_event_name')

# Log for debugging
echo "[$event] session=$session_id" >> /tmp/gemini-hooks.log

# Do your processing here...

# Return success
jq -n '{decision: "allow"}'
exit 0
```

---

## 7. BeforeModel/AfterModel: Should You Use Them?

### The Question

Since BeforeModel fires when the LLM starts processing, should we use it to signal "processing"?

### Analysis

**Arguments FOR using BeforeModel:**

| Pro | Explanation |
|-----|-------------|
| Semantically correct | LLM IS processing when BeforeModel fires |
| Immediate feedback | Signal appears right when LLM starts |
| Backup | If BeforeAgent fails, BeforeModel catches it |

**Arguments AGAINST using BeforeModel:**

| Con | Explanation |
|-----|-------------|
| Redundant | BeforeAgent already set "processing" |
| Performance overhead | Extra hook executions (~30-50ms each) |
| Multiple fires | 2-6 extra hook calls per prompt |
| No visual benefit | Already showing 🟠 from BeforeAgent |

### Performance Impact

| Scenario | Without BeforeModel | With BeforeModel | Overhead |
|----------|--------------------|--------------------|----------|
| Simple prompt | 2 hooks | 4 hooks | +100ms |
| 1 tool | 4 hooks | 8 hooks | +200ms |
| Extended thinking (3 LLM calls) | 2 hooks | 8 hooks | +300ms |

### Recommendation

**For most users:** Skip BeforeModel. BeforeAgent provides the same visual signal with less overhead.

**If you want maximum responsiveness:** Include BeforeModel as a backup. The overhead is measurable but not significant.

### Configuration Options

**Option 1: Minimal (Recommended)**
```json
{
  "hooks": {
    "BeforeAgent": [{"hooks": [{"command": "...trigger.sh processing"}]}],
    "BeforeTool": [{"hooks": [{"command": "...trigger.sh processing"}]}],
    "AfterTool": [{"hooks": [{"command": "...trigger.sh processing"}]}],
    "AfterAgent": [{"hooks": [{"command": "...trigger.sh complete"}]}]
  }
}
```

**Option 2: With BeforeModel Backup**
```json
{
  "hooks": {
    "BeforeAgent": [{"hooks": [{"command": "...trigger.sh processing"}]}],
    "BeforeModel": [{"hooks": [{"command": "...trigger.sh processing"}]}],
    "BeforeTool": [{"hooks": [{"command": "...trigger.sh processing"}]}],
    "AfterTool": [{"hooks": [{"command": "...trigger.sh processing"}]}],
    "AfterAgent": [{"hooks": [{"command": "...trigger.sh complete"}]}]
  }
}
```

### Why NOT AfterModel?

AfterModel fires after LLM responds, but:
- Agent isn't done yet (tools may run)
- Can't show "complete" (would be wrong)
- Can't show "processing" (already showing it)
- No useful visual state to set

**Conclusion:** AfterModel has no useful visual signal mapping.

---

## 8. Comparison with Claude Code

### Hook Event Mapping

| Visual Signal | Claude Code Hook | Gemini CLI Hook |
|---------------|------------------|-----------------|
| Processing start | `UserPromptSubmit` | `BeforeAgent` |
| Tool execution | `PreToolUse` / `PostToolUse` | `BeforeTool` / `AfterTool` |
| Completion | `Stop` | `AfterAgent` |
| Permission | `PermissionRequest` | `Notification` (ToolPermission) |
| Idle | `Notification` (idle_prompt) | ❌ Not available |
| Compression | `PreCompact` | `PreCompress` |
| Session start | `SessionStart` | `SessionStart` |
| Session end | `SessionEnd` | `SessionEnd` |

### Key Differences

| Aspect | Claude Code | Gemini CLI |
|--------|-------------|-----------|
| Idle notification | Built-in `idle_prompt` | Not available |
| LLM hooks | None | `BeforeModel`, `AfterModel` |
| Tool selection hook | None | `BeforeToolSelection` |
| Permission handling | Dedicated hook | Via Notification |
| Config structure | Flat array | Grouped by event |
| Environment variable | `$CLAUDE_PROJECT_DIR` | `$GEMINI_PROJECT_DIR` |

### Migration Notes

1. **No `idle_prompt`:** Gemini CLI doesn't notify on idle. Use internal timer.
2. **`PermissionRequest` → `Notification`:** Use `ToolPermission` matcher.
3. **Path variables:** Replace `$CLAUDE_PROJECT_DIR` with `$GEMINI_PROJECT_DIR`.
4. **Config restructure:** Gemini groups hooks by event type.

---

## 9. Known Issues & Troubleshooting

### Issue: Hooks Not Executing

**Symptom:** Hooks configured but not firing

**Checklist:**
- [ ] `"enableHooks": true` in `tools` section
- [ ] Script is executable (`chmod +x`)
- [ ] Path is absolute (not `~`)
- [ ] JSON syntax is valid
- [ ] Script returns exit code 0

**Debug:**
```bash
# Test script manually
echo '{"event":"BeforeTool","tool_name":"Read"}' | /path/to/hook.sh

# Check logs
tail -f /tmp/gemini-hooks.log
```

### Issue: Stale State After Restart

**Symptom:** Terminal shows wrong color on session start

**Solution:** Clear the state file:
```bash
rm /tmp/tavs.state
```

### Issue: "compacting" Shows at Start

**Cause:** Stale state from previous session

**Solution:** Ensure `SessionStart` hook fires and resets state.

### Issue: Migration Command Missing

**Symptom:** `gemini hooks migrate --from-claude` doesn't work

**Status:** Known bug in v0.24.0 (GitHub Issue #16049)

**Workaround:** Manual migration using this documentation.

### Issue: Hooks Running Slowly

**Cause:** Synchronous execution blocks agent loop

**Solutions:**
- Set shorter timeouts
- Use specific matchers (not `*`)
- Optimize script execution
- Avoid network calls in hooks

---

## 10. Best Practices

### Performance

1. **Use specific matchers** - Avoid `*` on frequent events
2. **Set appropriate timeouts** - Default 60s is too long
3. **Keep scripts fast** - Aim for <100ms execution
4. **Minimize file I/O** - Cache where possible

### Security

1. **Validate all inputs** - Data comes from LLM outputs
2. **Avoid printing environment** - May contain API keys
3. **Review third-party hooks** - Project hooks are untrusted
4. **Use absolute paths** - Prevent path injection

### Development

1. **Test independently** - Echo test JSON to stdin
2. **Log everything** - Debug files, not stderr
3. **Use jq** - Don't parse JSON with grep/sed
4. **Check exit codes** - 0=success, 2=block

### Visual Signals Specific

1. **Use BeforeAgent** - Not BeforeModel for processing
2. **Use AfterAgent** - Not AfterModel for completion
3. **Handle stale state** - Clear on SessionStart
4. **Test all states** - Run trigger.sh manually

---

## 11. References

### Official Documentation

- [Gemini CLI Hooks Overview](https://geminicli.com/docs/hooks/)
- [Hooks Reference](https://geminicli.com/docs/hooks/reference/)
- [Writing Hooks](https://geminicli.com/docs/hooks/writing-hooks/)
- [Best Practices](https://geminicli.com/docs/hooks/best-practices/)
- [Configuration](https://geminicli.com/docs/get-started/configuration/)

### GitHub

- [Main Repository](https://github.com/google-gemini/gemini-cli)
- [Hooks Not Working #13155](https://github.com/google-gemini/gemini-cli/issues/13155)
- [Migration Missing #16049](https://github.com/google-gemini/gemini-cli/issues/16049)
- [Comprehensive Hooks #11703](https://github.com/google-gemini/gemini-cli/issues/11703)

### Related Projects

- [Claude Code Hooks Mastery](https://github.com/disler/claude-code-hooks-mastery)
- [TAVS - Terminal Agent Visual Signals](https://github.com/cstelmach/terminal-agent-visual-signals)

---

*Documentation generated: 2026-01-07*
*Based on Gemini CLI v0.24.0 and official documentation*
