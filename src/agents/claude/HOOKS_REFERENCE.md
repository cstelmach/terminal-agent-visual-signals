# Claude Code Hooks Reference for TAVS

**Last Updated:** 2026-01-08
**Claude Code Version:** v2.0.45+
**Documentation Sources:** [docs.anthropic.com](https://docs.anthropic.com/en/docs/claude-code), [GitHub](https://github.com/anthropics/claude-code)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Hook Execution Flow](#2-hook-execution-flow)
3. [Complete Hook Reference](#3-complete-hook-reference)
   - [PreToolUse](#pretooluse)
   - [PostToolUse](#posttooluse)
   - [PermissionRequest](#permissionrequest)
   - [UserPromptSubmit](#userpromptsubmit)
   - [Notification](#notification)
   - [Stop](#stop)
   - [SubagentStop](#subagentstop)
   - [PreCompact](#precompact)
   - [SessionStart](#sessionstart)
   - [SessionEnd](#sessionend)
4. [Visual Signal Mapping](#4-visual-signal-mapping)
5. [Configuration Guide](#5-configuration-guide)
6. [Communication Protocol](#6-communication-protocol)
7. [Matcher Patterns](#7-matcher-patterns)
8. [Comparison with Gemini CLI](#8-comparison-with-gemini-cli)
9. [Known Issues & Troubleshooting](#9-known-issues--troubleshooting)
10. [Best Practices](#10-best-practices)
11. [References](#11-references)

---

## 1. Overview

Claude Code provides **10 hook events** that fire at specific points during the agent loop, enabling customization without modifying core behavior.

### Key Characteristics

| Property | Value |
|----------|-------|
| **Protocol** | JSON via stdin/stdout |
| **Exit Codes** | 0=success, 2=block, 1/3+=warning |
| **Execution** | Parallel (all matching hooks run simultaneously) |
| **Default State** | Enabled (no `enableHooks` toggle needed) |
| **Hook Types** | `command` (shell) or `prompt` (LLM evaluation) |
| **Deduplication** | Automatic for identical hook commands |

### Quick Reference

```json
// ~/.claude/settings.json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "pattern",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/script.sh",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

---

## 2. Hook Execution Flow

### Master Execution Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        CLAUDE CODE HOOK EXECUTION FLOW                        │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                           SESSION LIFECYCLE                              │ │
│  ├─────────────────────────────────────────────────────────────────────────┤ │
│  │  USER STARTS CLAUDE CODE                                                 │ │
│  │  └─→ SessionStart ─────────────────────────────────→ reset              │ │
│  │      source: startup | resume | clear | compact                          │ │
│  │      ⭐ stdout becomes Claude's context!                                 │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                        │
│                                      ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                           USER SUBMITS PROMPT                            │ │
│  ├─────────────────────────────────────────────────────────────────────────┤ │
│  │  UserPromptSubmit ─────────────────────────────────→ processing (🟠)    │ │
│  │      Fires: ONCE per user prompt                                         │ │
│  │      Input: prompt text                                                  │ │
│  │      ⭐ Can inject additionalContext!                                    │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                        │
│                                      ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                           CLAUDE PROCESSING                              │ │
│  ├─────────────────────────────────────────────────────────────────────────┤ │
│  │  (Claude thinks and decides what tools to use)                           │ │
│  │  ⚠️ No hooks fire during Claude's thinking!                             │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                        │
│           ┌──────────────────────────┴──────────────────────────┐            │
│           │                                                      │            │
│           ▼ (no tools needed)                                   ▼ (tools)    │
│  ┌────────────────────┐                          ┌────────────────────────┐  │
│  │  Skip to Stop      │                          │   TOOL EXECUTION       │  │
│  └────────────────────┘                          ├────────────────────────┤  │
│                                                  │                        │  │
│                                                  │  ┌─────────────────┐   │  │
│                                                  │  │ PreToolUse      │   │  │
│                                                  │  │ → processing    │   │  │
│                                                  │  │ (per tool)      │   │  │
│                                                  │  └────────┬────────┘   │  │
│                                                  │           │            │  │
│                                                  │           ▼            │  │
│                                                  │  ┌─────────────────┐   │  │
│                                                  │  │ Permission?     │   │  │
│                                                  │  └────────┬────────┘   │  │
│                                                  │           │            │  │
│                                                  │    ┌──────┴──────┐     │  │
│                                                  │    │             │     │  │
│                                                  │    ▼ (needs)     ▼ (no)│  │
│                                                  │ ┌──────────┐  ┌──────┐ │  │
│                                                  │ │Permission│  │ Skip │ │  │
│                                                  │ │Request   │  │      │ │  │
│                                                  │ │→ perm 🔴 │  │      │ │  │
│                                                  │ └────┬─────┘  └──┬───┘ │  │
│                                                  │      └─────┬─────┘     │  │
│                                                  │            │           │  │
│                                                  │            ▼           │  │
│                                                  │  ┌─────────────────┐   │  │
│                                                  │  │  [TOOL RUNS]    │   │  │
│                                                  │  └────────┬────────┘   │  │
│                                                  │           │            │  │
│                                                  │           ▼            │  │
│                                                  │  ┌─────────────────┐   │  │
│                                                  │  │ PostToolUse     │   │  │
│                                                  │  │ → processing    │   │  │
│                                                  │  │ (per tool)      │   │  │
│                                                  │  └────────┬────────┘   │  │
│                                                  │           │            │  │
│                                                  │  (May loop for more    │  │
│                                                  │   tools)               │  │
│                                                  └────────────┬───────────┘  │
│                                                               │              │
│           ┌───────────────────────────────────────────────────┘              │
│           │                                                                   │
│           ▼                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                           CLAUDE COMPLETES                               │ │
│  ├─────────────────────────────────────────────────────────────────────────┤ │
│  │  Stop ─────────────────────────────────────────────→ complete (🟢)      │ │
│  │      Fires: ONCE when main agent finishes                                │ │
│  │      Can be blocked to force continuation!                               │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                        │
│                                      ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                           IDLE DETECTION                                 │ │
│  ├─────────────────────────────────────────────────────────────────────────┤ │
│  │  Notification (idle_prompt) ───────────────────────→ idle (🟣)          │ │
│  │      Fires: After ~60 seconds idle                                       │ │
│  │      ⭐ Claude Code has built-in idle detection!                         │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
├───────────────────────────────────────────────────────────────────────────────┤
│                           SPECIAL EVENTS                                      │
├───────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │  CONTEXT COMPRESSION                                                     │ │
│  │  PreCompact ───────────────────────────────────────→ compacting (🔄)    │ │
│  │      trigger: manual (/compact) | auto (context full)                    │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │  SUBAGENT COMPLETION                                                     │ │
│  │  SubagentStop ─────────────────────────────────────→ (varies)           │ │
│  │      Fires: When Task tool subagent finishes                             │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │  SESSION ENDS                                                            │ │
│  │  SessionEnd ───────────────────────────────────────→ reset              │ │
│  │      reason: clear | logout | prompt_input_exit | other                  │ │
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
│  T=0.00s  UserPromptSubmit ──────────→ 🟠 processing            │
│  T=0.05s  [Claude thinking...]                                    │
│  T=2.00s  Stop ──────────────────────→ 🟢 complete              │
│  T=62.0s  Notification (idle_prompt) → 🟣 idle                   │
│                                                                   │
│  Total hooks fired: 2 (+ optional idle notification)              │
└──────────────────────────────────────────────────────────────────┘
```

### Scenario: Prompt with Tool Use

```
┌──────────────────────────────────────────────────────────────────┐
│ User: "Read the README.md file"                                  │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  T=0.00s  UserPromptSubmit ──────────→ 🟠 processing            │
│  T=0.50s  PreToolUse (Read) ─────────→ 🟠 processing            │
│  T=0.55s  [Read tool executes]                                    │
│  T=0.80s  PostToolUse (Read) ────────→ 🟠 processing            │
│  T=1.00s  [Claude synthesizes response]                           │
│  T=2.00s  Stop ──────────────────────→ 🟢 complete              │
│                                                                   │
│  Total hooks fired: 4                                             │
└──────────────────────────────────────────────────────────────────┘
```

### Scenario: Prompt with Permission Request

```
┌──────────────────────────────────────────────────────────────────┐
│ User: "Create a new file called test.txt"                        │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  T=0.00s  UserPromptSubmit ──────────→ 🟠 processing            │
│  T=0.50s  PreToolUse (Write) ────────→ 🟠 processing            │
│  T=0.55s  PermissionRequest ─────────→ 🔴 permission            │
│  T=0.55s  Notification (perm_prompt) → 🔴 permission            │
│  T=5.00s  [User grants permission]                                │
│  T=5.05s  [Write tool executes]                                   │
│  T=5.30s  PostToolUse (Write) ───────→ 🟠 processing            │
│  T=5.50s  Stop ──────────────────────→ 🟢 complete              │
│                                                                   │
│  Total hooks fired: 6                                             │
└──────────────────────────────────────────────────────────────────┘
```

### Scenario: Multi-Tool Chain

```
┌──────────────────────────────────────────────────────────────────┐
│ User: "Find all TODO comments and list them"                     │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  T=0.00s  UserPromptSubmit ──────────→ 🟠 processing            │
│                                                                   │
│  T=0.50s  PreToolUse (Glob) ─────────→ 🟠 processing            │
│  T=0.60s  [Glob executes]                                         │
│  T=0.70s  PostToolUse (Glob) ────────→ 🟠 processing            │
│                                                                   │
│  T=1.00s  PreToolUse (Grep) ─────────→ 🟠 processing            │
│  T=1.10s  [Grep executes]                                         │
│  T=1.50s  PostToolUse (Grep) ────────→ 🟠 processing            │
│                                                                   │
│  T=2.00s  PreToolUse (Read) ─────────→ 🟠 processing            │
│  T=2.10s  [Read executes]                                         │
│  T=2.30s  PostToolUse (Read) ────────→ 🟠 processing            │
│                                                                   │
│  T=3.00s  Stop ──────────────────────→ 🟢 complete              │
│                                                                   │
│  Total hooks fired: 8                                             │
└──────────────────────────────────────────────────────────────────┘
```

---

## 3. Complete Hook Reference

### PreToolUse

| Property | Value |
|----------|-------|
| **Category** | Tool Execution |
| **Fires** | After Claude creates tool parameters, before tool executes |
| **Frequency** | Once per tool call |
| **Visual Signal** | `processing` |

#### When It Fires

PreToolUse fires at the critical moment between Claude's decision to use a tool and the actual execution. This allows you to:
- Validate tool parameters
- Block dangerous operations
- Modify tool inputs
- Auto-approve safe operations

#### Input Payload

```json
{
  "session_id": "abc123-def456",
  "transcript_path": "/path/to/transcript.json",
  "cwd": "/current/working/directory",
  "permission_mode": "default|plan|acceptEdits|dontAsk|bypassPermissions",
  "hook_event_name": "PreToolUse",
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/path/to/file.txt",
    "content": "file content here"
  },
  "tool_use_id": "unique-tool-use-id"
}
```

#### Output Capabilities

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow|deny|ask",
    "permissionDecisionReason": "Explanation for user",
    "updatedInput": {
      "file_path": "/modified/path.txt"
    }
  }
}
```

| Decision | Effect |
|----------|--------|
| `allow` | Execute tool immediately (bypass permission dialog) |
| `deny` | Block tool execution, show reason to user |
| `ask` | Show permission dialog to user (default behavior) |

#### Use Cases

- Block writes to sensitive files (`.env`, `.git/`)
- Auto-approve safe read operations
- Validate bash commands before execution
- Log all tool usage for auditing
- **Visual Signals:** Show "processing" indicator (🟠)

#### Example: Security Hook

```bash
#!/bin/bash
# Block sensitive file operations
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

if [[ "$tool_name" =~ ^(Write|Edit)$ ]]; then
  if [[ "$file_path" =~ \.env|\.git/|secrets/ ]]; then
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: "Protected file - cannot modify"
      }
    }'
    exit 0
  fi
fi

# Default: allow
exit 0
```

---

### PostToolUse

| Property | Value |
|----------|-------|
| **Category** | Tool Execution |
| **Fires** | Immediately after tool completes successfully |
| **Frequency** | Once per tool call |
| **Visual Signal** | `processing` |

#### When It Fires

PostToolUse fires after a tool has successfully executed, allowing you to:
- Process tool results
- Trigger follow-up actions (linting, formatting)
- Log tool outputs
- Provide additional context to Claude

#### Input Payload

```json
{
  "session_id": "abc123-def456",
  "transcript_path": "/path/to/transcript.json",
  "cwd": "/current/working/directory",
  "permission_mode": "default",
  "hook_event_name": "PostToolUse",
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/path/to/file.py",
    "content": "def hello(): pass"
  },
  "tool_response": {
    "filePath": "/path/to/file.py",
    "status": "success"
  },
  "tool_use_id": "unique-tool-use-id"
}
```

#### Output Capabilities

```json
{
  "decision": "block|undefined",
  "reason": "Feedback for Claude (if blocking)",
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Extra information for Claude"
  }
}
```

| Decision | Effect |
|----------|--------|
| `block` | Tell Claude something went wrong, provide `reason` |
| `undefined` | Pass through (default) |

#### Use Cases

- Auto-format written files (prettier, black)
- Run linters on changed code
- Trigger test runs after file changes
- Log all file modifications
- **Visual Signals:** Maintain "processing" state during tool chains

#### Example: Auto-Format Python Files

```bash
#!/bin/bash
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

if [[ "$tool_name" =~ ^(Write|Edit)$ ]] && [[ "$file_path" == *.py ]]; then
  # Run black formatter
  black "$file_path" 2>/dev/null
fi

exit 0
```

---

### PermissionRequest

| Property | Value |
|----------|-------|
| **Category** | Permission System |
| **Fires** | When user is shown a permission dialog |
| **Frequency** | Once per permission request |
| **Visual Signal** | `permission` |

#### When It Fires

PermissionRequest fires when Claude Code would normally show a permission dialog to the user. This happens for:
- File writes/edits (unless auto-approved)
- Bash commands (unless in allowed list)
- Tool operations requiring user consent

#### Input Payload

```json
{
  "session_id": "abc123-def456",
  "transcript_path": "/path/to/transcript.json",
  "cwd": "/current/working/directory",
  "permission_mode": "default",
  "hook_event_name": "PermissionRequest",
  "tool_name": "Bash",
  "tool_input": {
    "command": "npm install",
    "description": "Install dependencies"
  }
}
```

#### Output Capabilities

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow|deny",
      "updatedInput": {
        "command": "npm install --dry-run"
      },
      "message": "Reason for denial",
      "interrupt": true
    }
  }
}
```

| Behavior | Effect |
|----------|--------|
| `allow` | Grant permission automatically |
| `deny` | Deny permission, optionally with `message` |

#### Use Cases

- Auto-approve safe npm commands
- Block destructive operations
- Modify commands before execution
- **Visual Signals:** Show "permission" indicator (🔴)

---

### UserPromptSubmit

| Property | Value |
|----------|-------|
| **Category** | User Input |
| **Fires** | When user submits a prompt, before Claude processes |
| **Frequency** | **ONCE per user prompt** ⭐ |
| **Visual Signal** | `processing` |

#### Why This Hook Is Important

UserPromptSubmit fires **exactly once** when the user submits a prompt. This makes it perfect for:
- Signaling that processing has started
- Injecting context into the conversation
- Validating/blocking prompts
- Logging user interactions

#### Input Payload

```json
{
  "session_id": "abc123-def456",
  "transcript_path": "/path/to/transcript.json",
  "cwd": "/current/working/directory",
  "permission_mode": "default",
  "hook_event_name": "UserPromptSubmit",
  "prompt": "Read the README.md file and summarize it"
}
```

#### Output Capabilities

**Simple (stdout becomes context):**
```bash
#!/bin/bash
# stdout is added to Claude's context!
echo "Current git branch: $(git branch --show-current)"
echo "Last commit: $(git log -1 --oneline)"
```

**Structured JSON:**
```json
{
  "decision": "block|undefined",
  "reason": "Shown to user when blocking",
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "Added to Claude's context"
  }
}
```

#### Use Cases

- Inject git status, current time, project context
- Validate prompts for sensitive information
- Block certain types of requests
- **Visual Signals:** Show "processing" indicator (🟠)

#### Example: Context Injection

```bash
#!/bin/bash
# Inject project context on every prompt
echo "Project: $(basename $PWD)"
echo "Branch: $(git branch --show-current 2>/dev/null || echo 'N/A')"
echo "Modified files: $(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')"
```

---

### Notification

| Property | Value |
|----------|-------|
| **Category** | Notifications |
| **Fires** | When Claude Code sends notifications |
| **Frequency** | Variable |
| **Visual Signal** | `permission` or `idle` (depends on matcher) |

#### Notification Types (Matchers)

| Matcher | When It Fires | Visual Signal |
|---------|---------------|---------------|
| `permission_prompt` | Permission dialog shown | `permission` |
| `idle_prompt` | Idle for ~60 seconds | `idle` |
| `auth_success` | Authentication successful | — |
| `elicitation_dialog` | MCP tool needs input | — |
| `""` (empty) | All notifications | — |

#### Input Payload

```json
{
  "session_id": "abc123-def456",
  "transcript_path": "/path/to/transcript.json",
  "cwd": "/current/working/directory",
  "permission_mode": "default",
  "hook_event_name": "Notification",
  "message": "Notification message",
  "notification_type": "idle_prompt|permission_prompt|..."
}
```

#### Output Capabilities

Notifications are informational only - cannot block them. Exit code determines success/failure logging.

#### Use Cases

- Desktop notifications (ntfy, pushover)
- Slack/Teams alerts for permission requests
- Custom alerting systems
- **Visual Signals:**
  - `permission_prompt` → "permission" (🔴)
  - `idle_prompt` → "idle" (🟣) / skip to idle stage

#### Example: Desktop Notification

```bash
#!/bin/bash
input=$(cat)
notification_type=$(echo "$input" | jq -r '.notification_type')
message=$(echo "$input" | jq -r '.message')

case "$notification_type" in
  permission_prompt)
    osascript -e "display notification \"Permission needed\" with title \"Claude Code\""
    ;;
  idle_prompt)
    # Trigger idle visual state
    /path/to/trigger.sh idle
    ;;
esac
```

---

### Stop

| Property | Value |
|----------|-------|
| **Category** | Agent Control |
| **Fires** | When main Claude Code agent finishes responding |
| **Frequency** | **ONCE per completion** ⭐ |
| **Visual Signal** | `complete` |

#### Why This Hook Is Important

Stop fires **exactly once** when Claude finishes responding. This makes it perfect for signaling completion. Unlike Gemini's `AfterAgent`, Claude's `Stop` can be **blocked** to force Claude to continue.

#### Input Payload

```json
{
  "session_id": "abc123-def456",
  "transcript_path": "/path/to/transcript.json",
  "permission_mode": "default",
  "hook_event_name": "Stop",
  "stop_hook_active": false
}
```

**Important:** `stop_hook_active` is `true` if a Stop hook already prevented stopping. Check this to avoid infinite loops!

#### Output Capabilities

```json
{
  "decision": "block|undefined",
  "reason": "Why Claude should continue (required when blocking)"
}
```

| Decision | Effect |
|----------|--------|
| `block` | Prevent stopping, Claude continues with `reason` |
| `undefined` | Allow stop (default) |

#### Use Cases

- Intelligent stopping decisions (verify completion)
- Force Claude to continue if incomplete
- **Visual Signals:** Show "complete" indicator (🟢)

#### Example: Prevent Premature Stop

```python
#!/usr/bin/env python3
import json
import sys

data = json.load(sys.stdin)

# Avoid infinite loops
if data.get("stop_hook_active"):
    sys.exit(0)

# Custom logic to verify completion
# (simplified example)
print(json.dumps({
    "decision": "undefined"  # Allow stop
}))
```

---

### SubagentStop

| Property | Value |
|----------|-------|
| **Category** | Agent Control |
| **Fires** | When a subagent (Task tool) finishes |
| **Frequency** | Once per subagent completion |
| **Visual Signal** | — (typically not used for visual signals) |

#### When It Fires

SubagentStop fires when a subagent launched via the Task tool completes. This allows the main agent to evaluate and potentially request refinements.

#### Input Payload

Same as Stop.

#### Output Capabilities

Same as Stop - can block to request subagent refinement.

#### Use Cases

- Evaluate subagent outputs
- Request refinements
- Manage multi-agent workflows

---

### PreCompact

| Property | Value |
|----------|-------|
| **Category** | Context Management |
| **Fires** | Before Claude Code compacts the conversation |
| **Frequency** | On demand |
| **Visual Signal** | `compacting` |

#### Trigger Conditions

| Trigger | Description |
|---------|-------------|
| `manual` | User ran `/compact` command |
| `auto` | Context window full, automatic compaction |

#### Input Payload

```json
{
  "session_id": "abc123-def456",
  "transcript_path": "/path/to/transcript.json",
  "permission_mode": "default",
  "hook_event_name": "PreCompact",
  "trigger": "manual|auto",
  "custom_instructions": "Optional compaction instructions"
}
```

#### Output Capabilities

Cannot block compaction. Exit code only.

#### Use Cases

- Backup conversation before compaction
- Log compaction events
- **Visual Signals:** Show "compacting" indicator (🔄)

---

### SessionStart

| Property | Value |
|----------|-------|
| **Category** | Session Lifecycle |
| **Fires** | When session starts or resumes |
| **Frequency** | Once per session |
| **Visual Signal** | `reset` |

#### Trigger Conditions (Matchers)

| Source | Description |
|--------|-------------|
| `startup` | Fresh session start |
| `resume` | Using `--resume`, `--continue`, or `/resume` |
| `clear` | After `/clear` command |
| `compact` | After compaction completes |

#### Input Payload

```json
{
  "session_id": "abc123-def456",
  "transcript_path": "/path/to/transcript.json",
  "permission_mode": "default",
  "hook_event_name": "SessionStart",
  "source": "startup|resume|clear|compact"
}
```

#### Special Features

1. **stdout becomes Claude's context!** Anything printed is added to the conversation.
2. **Environment variable persistence:** Use `$CLAUDE_ENV_FILE` to set variables for the session.

#### Output Capabilities

**Simple stdout (becomes context):**
```bash
#!/bin/bash
echo "Welcome! Current branch: $(git branch --show-current)"
```

**Environment persistence:**
```bash
#!/bin/bash
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo 'export MY_VAR=value' >> "$CLAUDE_ENV_FILE"
fi
```

**Structured JSON:**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Added to Claude's context"
  }
}
```

#### Use Cases

- Load project context on session start
- Set environment variables
- Welcome messages
- **Visual Signals:** Reset terminal state

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
| `clear` | `/clear` command |
| `logout` | User logged out |
| `prompt_input_exit` | Exit from prompt input |
| `other` | Other termination reasons |

#### Input Payload

```json
{
  "session_id": "abc123-def456",
  "transcript_path": "/path/to/transcript.json",
  "cwd": "/current/working/directory",
  "permission_mode": "default",
  "hook_event_name": "SessionEnd",
  "reason": "clear|logout|prompt_input_exit|other"
}
```

#### Output Capabilities

Cannot block termination. Exit code only.

#### Use Cases

- Cleanup tasks
- Session logging
- Analytics
- **Visual Signals:** Clear all visual state

---

## 4. Visual Signal Mapping

### Recommended Configuration

| Claude Code Hook | Visual State | Color | Emoji | Fires |
|------------------|--------------|-------|-------|-------|
| `SessionStart` | `reset` | Default | — | Once at start |
| `UserPromptSubmit` | `processing` | #473D2F | 🟠 | **Once per prompt** |
| `PreToolUse` | `processing` | #473D2F | 🟠 | Per tool |
| `PostToolUse` | `processing` | #473D2F | 🟠 | Per tool |
| `PermissionRequest` | `permission` | #4A2021 | 🔴 | On permission |
| `Notification` (permission_prompt) | `permission` | #4A2021 | 🔴 | On permission |
| `Notification` (idle_prompt) | `idle` | #443147 | 🟣 | After ~60s idle |
| `Stop` | `complete` | #473046 | 🟢 | **Once when done** |
| `PreCompact` | `compacting` | #2B4645 | 🔄 | On compression |
| `SessionEnd` | `reset` | Default | — | Once at end |

### Hook Priority for Visual Signals

```
permission (100) > idle (90) > compacting (50) > processing (30) > complete (20) > reset (10)
```

Higher priority states are protected during a grace period to prevent rapid state changes from overriding important states.

---

## 5. Configuration Guide

### Settings File Locations

| Level | Path | Priority | Use Case |
|-------|------|----------|----------|
| User | `~/.claude/settings.json` | Lowest | Personal preferences |
| Project | `.claude/settings.json` | Medium | Team shared config |
| Local | `.claude/settings.local.json` | Highest | Personal project overrides |
| Plugin | `<plugin>/hooks/hooks.json` | Plugin-specific | Plugin hooks |

### Hook Definition Structure

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "pattern",
        "hooks": [
          {
            "type": "command",
            "command": "/absolute/path/to/script.sh",
            "timeout": 60
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
| `type` | string | Required | — | `"command"` or `"prompt"` |
| `command` | string | Required (command) | — | Shell command to execute |
| `prompt` | string | Required (prompt) | — | LLM prompt for evaluation |
| `timeout` | number | Optional | 60 | Timeout in seconds |
| `matcher` | string | Optional | — | Filter pattern for events |

### Path Variables

| Variable | Description | Available In |
|----------|-------------|--------------|
| `$CLAUDE_PROJECT_DIR` | Project root | All hooks |
| `${CLAUDE_PLUGIN_ROOT}` | Plugin directory | Plugin hooks only |
| `$CLAUDE_ENV_FILE` | Env persistence file | SessionStart only |
| `~` | Home directory | All hooks (expanded) |

### Complete Configuration Example

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/terminal-agent-visual-signals/trigger.sh reset"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/terminal-agent-visual-signals/trigger.sh reset"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/terminal-agent-visual-signals/trigger.sh processing"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/terminal-agent-visual-signals/trigger.sh processing"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/terminal-agent-visual-signals/trigger.sh processing"
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/terminal-agent-visual-signals/trigger.sh permission"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/terminal-agent-visual-signals/trigger.sh permission"
          }
        ]
      },
      {
        "matcher": "idle_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/terminal-agent-visual-signals/trigger.sh idle"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/terminal-agent-visual-signals/trigger.sh complete"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "auto",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/terminal-agent-visual-signals/trigger.sh compacting"
          }
        ]
      },
      {
        "matcher": "manual",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/terminal-agent-visual-signals/trigger.sh compacting"
          }
        ]
      }
    ]
  }
}
```

---

## 6. Communication Protocol

### Input (stdin)

All hooks receive JSON via stdin with base fields:

```json
{
  "session_id": "unique-session-id",
  "transcript_path": "/path/to/transcript.json",
  "cwd": "/current/working/directory",
  "permission_mode": "default|plan|acceptEdits|dontAsk|bypassPermissions",
  "hook_event_name": "EventName"
}
```

Plus event-specific fields (see each hook's section above).

### Output (stdout)

Return JSON to communicate back:

```json
{
  "decision": "block|allow|deny|ask|undefined",
  "reason": "Explanation (required for some decisions)",
  "continue": true,
  "stopReason": "Message to user",
  "suppressOutput": false,
  "systemMessage": "Warning message",
  "hookSpecificOutput": {
    "hookEventName": "EventName",
    "additionalContext": "Extra info for Claude"
  }
}
```

### Exit Codes

| Code | Meaning | Behavior | stdout Parsed? |
|------|---------|----------|----------------|
| `0` | Success | Operation continues | Yes |
| `2` | Block/Error | Operation blocked, stderr shown | **No** |
| `1, 3+` | Warning | Operation continues, stderr logged | Yes |

**Important:** Exit code 2 means stdout JSON is **ignored**. Use exit 0 with JSON for structured control.

### Special Case: UserPromptSubmit & SessionStart

For these hooks, **stdout becomes context** even without JSON formatting:

```bash
#!/bin/bash
# This output is added to Claude's context!
echo "Current time: $(date)"
echo "Git status: $(git status --short)"
```

---

## 7. Matcher Patterns

### Tool Matchers (PreToolUse, PostToolUse, PermissionRequest)

**Built-in Tools:**

| Tool Name | Description |
|-----------|-------------|
| `Read` | Read file contents |
| `Write` | Write file contents |
| `Edit` | Edit file contents |
| `Bash` | Execute shell commands |
| `Glob` | File pattern matching |
| `Grep` | Content searching |
| `WebFetch` | Fetch web content |
| `WebSearch` | Search the web |
| `Task` | Launch subagents |
| `TodoWrite` | Write to todo list |
| `NotebookEdit` | Edit Jupyter notebooks |

**MCP Tools:**

| Pattern | Matches |
|---------|---------|
| `mcp__*` | All MCP tools |
| `mcp__memory__*` | Memory MCP tools |
| `mcp__context7__*` | Context7 MCP tools |
| `mcp__sequential-thinking__*` | Sequential thinking tools |

**Patterns:**

| Pattern | Matches |
|---------|---------|
| `*` | All tools |
| `""` | All tools (empty string) |
| `Write\|Edit` | Write OR Edit |
| `Bash` | Exact match |

### Notification Matchers

| Matcher | Description |
|---------|-------------|
| `permission_prompt` | Permission dialogs |
| `idle_prompt` | Idle state (~60 seconds) |
| `auth_success` | Authentication success |
| `elicitation_dialog` | MCP tool input needed |
| `""` | All notifications |

### PreCompact Matchers

| Matcher | Description |
|---------|-------------|
| `manual` | User invoked `/compact` |
| `auto` | Automatic (context full) |

### SessionStart Matchers

| Matcher | Description |
|---------|-------------|
| `startup` | New session |
| `resume` | Resuming session |
| `clear` | After `/clear` |
| `compact` | After compaction |

---

## 8. Comparison with Gemini CLI

### Hook Event Mapping

| Visual Signal | Claude Code Hook | Gemini CLI Hook |
|---------------|------------------|-----------------|
| Processing start | `UserPromptSubmit` | `BeforeAgent` |
| Tool execution | `PreToolUse` / `PostToolUse` | `BeforeTool` / `AfterTool` |
| Completion | `Stop` | `AfterAgent` |
| Permission | `PermissionRequest` + `Notification` | `Notification` (ToolPermission) |
| Idle | `Notification` (idle_prompt) | ❌ Not available |
| Compression | `PreCompact` | `PreCompress` |
| Session start | `SessionStart` | `SessionStart` |
| Session end | `SessionEnd` | `SessionEnd` |

### Key Differences

| Aspect | Claude Code | Gemini CLI |
|--------|-------------|-----------|
| Idle notification | ✅ Built-in `idle_prompt` | ❌ Not available |
| LLM hooks | None | `BeforeModel`, `AfterModel` |
| Stop blocking | ✅ Can block Stop | ✅ Can block AfterAgent |
| Enable toggle | Always enabled | Requires `enableHooks: true` |
| Hook types | `command` + `prompt` | `command` only |
| Execution | Parallel | Synchronous |
| Path expansion | ✅ Tilde works | ❌ Use absolute paths |
| Environment | `$CLAUDE_PROJECT_DIR` | `$GEMINI_PROJECT_DIR` |
| Context injection | ✅ stdout → context | ✅ `additionalContext` |

### Migration: Gemini → Claude

1. **BeforeAgent → UserPromptSubmit**
2. **BeforeTool → PreToolUse**
3. **AfterTool → PostToolUse**
4. **AfterAgent → Stop**
5. **PreCompress → PreCompact**
6. **Add idle_prompt** notification hook (Claude has it!)
7. **Path variables:** `$GEMINI_*` → `$CLAUDE_*`
8. **Remove `enableHooks`** (not needed in Claude)

---

## 9. Known Issues & Troubleshooting

### Issue: Plugin Hooks Not Executing (Bug #14410)

**Symptom:** Hooks defined in plugin `hooks/hooks.json` don't fire

**Cause:** Claude Code plugin path resolution bug

**Workaround:** Use user-level hooks in `~/.claude/settings.json` with absolute paths:
```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/terminal-agent-visual-signals/src/agents/claude/trigger.sh complete"
          }
        ]
      }
    ]
  }
}
```

### Issue: Hooks Timeout

**Symptom:** Hook execution times out (default 60 seconds)

**Solution:** Increase timeout:
```json
{
  "type": "command",
  "command": "long-running-script.sh",
  "timeout": 120
}
```

### Issue: Infinite Loop on Stop Hook

**Symptom:** Stop hook keeps blocking, Claude never stops

**Solution:** Check `stop_hook_active` flag:
```python
if data.get("stop_hook_active"):
    sys.exit(0)  # Don't block again
```

### Issue: Environment Variables Not Available

**Symptom:** `$CLAUDE_PROJECT_DIR` is empty

**Solution:** Use absolute paths or tilde expansion:
```bash
# Good
~/.claude/hooks/script.sh
/Users/me/.claude/hooks/script.sh

# May fail in some contexts
$CLAUDE_PROJECT_DIR/.claude/hooks/script.sh
```

### Issue: Stale Visual State After Crash

**Symptom:** Terminal shows wrong color after Claude Code crash

**Solution:** Clear state file:
```bash
rm /tmp/tavs/state
```

### Issue: Hook Output Not Visible

**Symptom:** Hook runs but output doesn't appear

**Solution:** Enable verbose mode with `Ctrl+O` or use debug flag:
```bash
claude --debug
```

---

## 10. Best Practices

### Performance

1. **Keep hooks fast** - Aim for <100ms execution
2. **Use specific matchers** - Avoid `*` on frequent events
3. **Cache expensive operations** - Don't repeat git status on every tool
4. **Set appropriate timeouts** - Don't let slow hooks block the agent

### Security

1. **Always quote shell variables** - `"$VAR"` not `$VAR`
2. **Use absolute paths** - Prevent path injection
3. **Validate JSON input** - Don't trust tool_input blindly
4. **Block sensitive files** - `.env`, `.git/`, secrets
5. **Never log API keys** - Check tool_input for secrets

### Development

1. **Test hooks locally** - Echo test JSON to stdin
2. **Log to files** - Not stderr (clutters output)
3. **Use jq** - Don't parse JSON with grep/sed
4. **Check exit codes** - 0=success, 2=block

### Visual Signals Specific

1. **Use UserPromptSubmit** - Fires once, perfect for "processing"
2. **Use Stop** - Fires once, perfect for "complete"
3. **Handle idle_prompt** - Claude has built-in idle detection
4. **Clear state on SessionStart** - Prevent stale visual state
5. **Test all states** - Run trigger.sh manually

### Testing Template

```bash
# Create test payload
cat > /tmp/hook-test.json << 'EOF'
{
  "session_id": "test",
  "hook_event_name": "PreToolUse",
  "tool_name": "Write",
  "tool_input": {"file_path": "/test/file.txt"}
}
EOF

# Test your hook
cat /tmp/hook-test.json | ./your-hook.sh
echo "Exit code: $?"
```

---

## 11. References

### Official Documentation

- [Claude Code Hooks Overview](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [Claude Code Settings](https://docs.anthropic.com/en/docs/claude-code/settings)
- [Claude Code CLI Reference](https://docs.anthropic.com/en/docs/claude-code)

### GitHub

- [Anthropic Claude Code](https://github.com/anthropics/claude-code)
- [Claude Code Issues](https://github.com/anthropics/claude-code/issues)

### Community Resources

- [Claude Code Hooks Mastery](https://github.com/disler/claude-code-hooks-mastery)
- [TAVS - Terminal Agent Visual Signals](https://github.com/cstelmach/terminal-agent-visual-signals)

---

*Documentation generated: 2026-01-08*
*Based on Claude Code v2.0.45+ and official documentation*
