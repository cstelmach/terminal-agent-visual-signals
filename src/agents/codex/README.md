# Codex CLI Integration

## Status: Limited Support (No Hooks System)

**Last Updated:** 2026-01-08

As of January 2026, **Codex CLI does not have a hooks system** comparable to Claude Code or Gemini CLI.

| Feature | Claude Code | Gemini CLI | Codex CLI |
|---------|-------------|------------|-----------|
| Full Hooks System | ✅ 10 events | ✅ 11 events | ❌ 1 event only |
| Visual Signal Support | Full | Full | **Complete state only** |

For comprehensive details, see [HOOKS_REFERENCE.md](./HOOKS_REFERENCE.md).

## What Works

The `notify` configuration fires on `agent-turn-complete`:

```toml
# ~/.codex/config.toml
notify = ["bash", "-lc", "~/.claude/hooks/tavs/src/agents/codex/trigger.sh complete"]
```

**Result:** Terminal turns green (🟢) when Codex completes a turn.

## What Does NOT Work

| Visual State | Hook Required | Codex Support |
|--------------|---------------|---------------|
| processing (🟠) | BeforeAgent | ❌ |
| permission (🔴) | ApprovalRequested | ❌ |
| complete (🟢) | AfterAgent | ✅ `notify` |
| idle (🟣) | Notification | ❌ |
| compacting (🔄) | PreCompress | ❌ |
| reset | SessionStart/End | ❌ |

## Available Mechanisms

### 1. notify (config.toml)

Single event: `agent-turn-complete`

```toml
notify = ["bash", "-lc", "/path/to/script.sh"]
```

Receives JSON payload:
```json
{
  "type": "agent-turn-complete",
  "thread-id": "...",
  "turn-id": "...",
  "cwd": "...",
  "input-messages": [...],
  "last-assistant-message": "..."
}
```

### 2. tui.notifications (Desktop)

```toml
[tui]
notifications = ["agent-turn-complete", "approval-requested"]
```

**Note:** Desktop notifications only, cannot trigger scripts.

### 3. codex exec --json (CI/CD)

```bash
codex exec --json "task" | jq
```

**Note:** Non-interactive only, no TUI support.

## Community Feature Requests

The community has been requesting full hooks since August 2025:

- [Discussion #2150](https://github.com/openai/codex/discussions/2150): 60+ votes
- [Issue #2109](https://github.com/openai/codex/issues/2109): 37+ thumbs up
- [Issue #3052](https://github.com/openai/codex/issues/3052): Extended events
- [Issue #2582](https://github.com/openai/codex/issues/2582): Plugin system

**OpenAI's response:** "If you'd like to see this feature, please upvote."

## Files in This Directory

| File | Purpose |
|------|---------|
| `README.md` | This overview |
| `HOOKS_REFERENCE.md` | Comprehensive documentation |
| `hooks.json` | Placeholder (empty hooks object) |
| `trigger.sh` | Wrapper to core trigger (ready for future hooks) |

## When Hooks Are Implemented

See [HOOKS_REFERENCE.md § When Hooks Are Implemented](./HOOKS_REFERENCE.md#10-when-hooks-are-implemented) for the planned update procedure.
