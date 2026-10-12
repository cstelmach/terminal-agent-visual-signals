# Codex CLI Integration

## Status: Completion-only Integration

**Last Updated:** 2026-10-12

TAVS consumes the existing Codex `agent-turn-complete` notify signal. Coverage remains partial;
it does not infer processing or add lifecycle hooks. The comparison below is from January 2026.

| Feature | Claude Code | Gemini CLI | Codex CLI |
|---------|-------------|------------|-----------|
| Full Hooks System | ✅ 10 events | ✅ 11 events | ❌ 1 event only |
| Visual Signal Support | Full | Full | **Complete state only** |

For comprehensive details, see [HOOKS_REFERENCE.md](./HOOKS_REFERENCE.md).

## What Works

The `notify` configuration fires on `agent-turn-complete`:

```toml
# ~/.codex/config.toml
notify = ["bash", "/absolute/path/to/tavs/src/agents/codex/trigger.sh", "complete"]
```

**Result:** Terminal turns green (🟢) when Codex completes a turn.

Use an absolute path. Codex appends one JSON argument, which reaches the adapter as `$2`.
The adapter retains only supported completion/thread/turn/directory metadata and discards bodies
before invoking core. Missing turn IDs remain missing. An unavailable helper reports unavailable
metadata while preserving the fixed complete signal.

The installer writes `notify` at TOML root before existing tables and saves `config.toml.bak`.
It refuses an existing multiline `notify` array without changing the config; edit that array
manually instead of allowing a partial replacement.

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
notify = ["bash", "/absolute/path/to/script.sh"]
```

Receives one JSON argument appended to the command array:
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
| `trigger.sh` | Allowlisted completion metadata intake and fixed-state core delegation |

## When Hooks Are Implemented

See [HOOKS_REFERENCE.md § When Hooks Are Implemented](./HOOKS_REFERENCE.md#10-when-hooks-are-implemented) for the planned update procedure.
