# CLAUDE.md - Terminal Agent Visual Signals

## Project Tracking

**Obsidian Project:** `IPC17_terminal-agent-visual-signals`
**Location:** `/Users/cs/Obsidian/_/kn/projects/IPC17_terminal-agent-visual-signals.md`

### View Project Status

```bash
# Full project overview (files, tasks, status)
obsidian-view project PC17 --full

# Just the task list
obsidian-view project PC17 --tasks

# List all TaskNotes
obsidian-view project PC17 --files
```

### Current TaskNotes

| Status | TaskNote | Description |
|--------|----------|-------------|
| DONE | `tPC2_20260102-1944_terminal-visual-signals-for-claude-code` | Original Claude Code implementation |
| OPEN | `tPC17_20260105-2008_agent-themes-branding-marketing-theme-collection` | Branding, marketing, theme library |
| OPEN | `tPC17_20260105-2009_agent-themes-cross-platform-codex-gemini` | Codex + Gemini CLI support |

### View Specific TaskNote

```bash
# Render a TaskNote with full content
obsidian-view /Users/cs/Obsidian/_/todo/tasks/tPC17_20260105-2008_agent-themes-branding-marketing-theme-collection.md
```

---

## Repository Overview

Visual terminal state indicators for Claude Code sessions using OSC escape sequences.

**GitHub:** https://github.com/cstelmach/terminal-agent-visual-signals

### Key Files

| File | Purpose |
|------|---------|
| `scripts/claude-code-visual-signal.sh` | Main signal script (~430 lines) |
| `setup-hooks-workaround.sh` | Workaround for Claude Code bug #14410 |
| `test-terminal.sh` | Terminal OSC compatibility tester |
| `README.md` | Public documentation |
| `hooks/hooks.json` | Plugin hook definitions |

### States

| State | Color | Emoji | Trigger |
|-------|-------|-------|---------|
| Processing | Orange | 🟠 | UserPromptSubmit, PostToolUse |
| Permission | Red | 🔴 | PermissionRequest |
| Complete | Green | 🟢 | Stop |
| Idle | Purple | 🟣 | Notification (idle_prompt) |
| Compacting | Teal | 🔄 | PreCompact |

---

## Development Notes

### Bug Workaround

Claude Code bug #14410 causes plugin hooks to not execute. The workaround:
1. `setup-hooks-workaround.sh --install` creates a version-independent symlink
2. Hooks in `~/.claude/settings.json` use the symlink path
3. SessionStart hook auto-updates symlink when plugin version changes

### Testing Changes

```bash
# Test each state manually
./scripts/claude-code-visual-signal.sh processing
./scripts/claude-code-visual-signal.sh permission
./scripts/claude-code-visual-signal.sh complete
./scripts/claude-code-visual-signal.sh idle
./scripts/claude-code-visual-signal.sh compacting
./scripts/claude-code-visual-signal.sh reset

# Test terminal OSC support
./test-terminal.sh
```

### Performance Considerations

The script is optimized for minimal subprocess spawning:
- Uses bash builtins (`$PPID`, `$SECONDS`, parameter expansion)
- Avoids `$(command)` subshells where possible
- Timer worker spawns ~1-2 external processes per iteration

---

## Related Files

- **Settings:** `~/.claude/settings.json` (hooks configuration)
- **Symlink:** `~/.claude/hooks/terminal-visual-signals-current/`
- **Session script:** `~/.claude/hooks/terminal-visual-signals-session-start.sh`
