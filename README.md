# Terminal Agent Visual Signals

> Visual terminal state indicators for Claude Code sessions using OSC escape sequences

<!-- TODO: Add GIF demos after recording -->
<!-- GIF 1: All States (12 terminals grid showing all colors) -->
<!-- GIF 2: Practical Usage (processing + permission states) -->

## Why?

When running multiple Claude Code sessions (12+ terminals side by side), you need to quickly identify which ones need attention. This hook system provides instant visual feedback:

| Color | Emoji | Meaning |
|-------|-------|---------|
| 🔴 Red | 🔴 | **Needs your attention** — Permission approval required |
| 🟠 Orange | 🟠 | **Working** — Claude is processing |
| 🟣 Purple | 🟣 | **Idle** — Waiting for input (60+ seconds) |
| 🟢 Green | 🟢 | **Done** — Task completed |

## Compatible Terminals

This script uses standard OSC escape sequences supported by many modern terminals:

| Terminal | Background | Reset | Title | Status |
|----------|-----------|-------|-------|--------|
| Ghostty | ✅ | ✅ | ✅ | Fully tested |
| Kitty | ✅ | ✅ | ✅ | Supported |
| WezTerm | ✅ | ✅ | ✅ | Supported |
| iTerm2 | ✅ | ✅ | ✅ | Tested |
| VS Code / Cursor | ✅ | ✅ | ✅ | Tested |
| GNOME Terminal | ✅ | ✅ | ✅ | Supported |
| Windows Terminal | ✅ | ✅ | ✅ | 2025+ |
| Foot | ✅ | ✅ | ✅ | Supported |
| Alacritty | ⚠️ | ⚠️ | ✅ | Untested |
| macOS Terminal.app | ❌ | ❌ | ✅ | No OSC 11 |

**Test your terminal:**
```bash
./test-terminal.sh
```

## Features

- **Background color changes** based on Claude Code state
- **Tab title prefixes** with emoji indicators (🔴 🟠 🟣 🟢)
- **Optimized performance** — ~1 external process vs ~12-15 (uses bash builtins)
- **Configurable** — enable/disable individual states, customize colors
- **Multi-terminal support** — works with most modern terminal emulators

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/cstelmach/terminal-agent-visual-signals.git ~/.claude/hooks/terminal-agent-visual-signals
```

### 2. Make executable

```bash
chmod +x ~/.claude/hooks/terminal-agent-visual-signals/claude-code-visual-signal.sh
```

### 3. Add hooks to `~/.claude/settings.json`

If you don't have existing hooks, create a `settings.json` with this content.
If you have existing hooks, **merge** these entries into your config.

```json
{
  "hooks": {
    "UserPromptSubmit": [{
      "hooks": [{
        "command": "bash ~/.claude/hooks/terminal-agent-visual-signals/claude-code-visual-signal.sh processing",
        "type": "command"
      }]
    }],
    "PermissionRequest": [{
      "hooks": [{
        "command": "bash ~/.claude/hooks/terminal-agent-visual-signals/claude-code-visual-signal.sh permission",
        "type": "command"
      }],
      "matcher": "*"
    }],
    "PostToolUse": [{
      "hooks": [{
        "command": "bash ~/.claude/hooks/terminal-agent-visual-signals/claude-code-visual-signal.sh processing",
        "type": "command"
      }],
      "matcher": "*"
    }],
    "Stop": [{
      "hooks": [{
        "command": "bash ~/.claude/hooks/terminal-agent-visual-signals/claude-code-visual-signal.sh complete",
        "type": "command"
      }]
    }],
    "Notification": [
      {
        "hooks": [{
          "command": "bash ~/.claude/hooks/terminal-agent-visual-signals/claude-code-visual-signal.sh permission",
          "type": "command"
        }],
        "matcher": "permission_prompt"
      },
      {
        "hooks": [{
          "command": "bash ~/.claude/hooks/terminal-agent-visual-signals/claude-code-visual-signal.sh idle",
          "type": "command"
        }],
        "matcher": "idle_prompt"
      }
    ],
    "SessionStart": [{
      "hooks": [{
        "command": "bash ~/.claude/hooks/terminal-agent-visual-signals/claude-code-visual-signal.sh reset",
        "type": "command"
      }]
    }],
    "SessionEnd": [{
      "hooks": [{
        "command": "bash ~/.claude/hooks/terminal-agent-visual-signals/claude-code-visual-signal.sh reset",
        "type": "command"
      }]
    }]
  }
}
```

### 4. Restart Claude Code

The visual signals will activate on your next session.

## Configuration

Edit the top of `claude-code-visual-signal.sh` to customize:

```bash
# Feature toggles
ENABLE_BACKGROUND_CHANGE=true    # Change terminal background color
ENABLE_TITLE_PREFIX=true         # Add emoji prefix to terminal title

# Per-state enable/disable
ENABLE_PROCESSING=true
ENABLE_PERMISSION=true
ENABLE_COMPLETE=false    # Disabled by default (green flash on every completion)
ENABLE_IDLE=false        # Disabled by default

# Colors (muted tints for dark themes like Catppuccin Frappe)
COLOR_PROCESSING="#473D2F"   # Muted orange
COLOR_PERMISSION="#4A2021"   # Muted red
COLOR_COMPLETE="#2B4636"     # Muted green
COLOR_IDLE="#3E3046"         # Muted purple
```

### Alternative Color Themes

**Brighter colors (more noticeable):**
```bash
COLOR_PROCESSING="#5C4A28"
COLOR_PERMISSION="#5C2828"
COLOR_COMPLETE="#285C3D"
COLOR_IDLE="#4A285C"
```

**Light theme compatible:**
```bash
COLOR_PROCESSING="#FFF3CD"
COLOR_PERMISSION="#F8D7DA"
COLOR_COMPLETE="#D4EDDA"
COLOR_IDLE="#E2D9F3"
```

## Manual Testing

```bash
# Test each state
~/.claude/hooks/terminal-agent-visual-signals/claude-code-visual-signal.sh processing  # 🟠 Orange
~/.claude/hooks/terminal-agent-visual-signals/claude-code-visual-signal.sh permission  # 🔴 Red
~/.claude/hooks/terminal-agent-visual-signals/claude-code-visual-signal.sh complete    # 🟢 Green
~/.claude/hooks/terminal-agent-visual-signals/claude-code-visual-signal.sh idle        # 🟣 Purple
~/.claude/hooks/terminal-agent-visual-signals/claude-code-visual-signal.sh reset       # Default
```

## How It Works

The script uses OSC (Operating System Command) escape sequences:

| Sequence | Purpose |
|----------|---------|
| `OSC 11` | Set terminal background color |
| `OSC 111` | Reset background to default |
| `OSC 0` | Set window/tab title |

These are sent directly to the TTY device (`/dev/ttysXXX`) to bypass Claude Code's stdout capture.

### Hook Event Flow

```
UserPromptSubmit → processing (orange)
    ↓
Claude working...
    ↓
PermissionRequest → permission (red)
    ↓
User approves → PostToolUse → processing (orange)
    ↓
Stop → complete (green) or reset
    ↓
60+ sec idle → Notification → idle (purple)
```

## Troubleshooting

### Colors not appearing

1. **Test your terminal** — Run `./test-terminal.sh` to verify OSC support
2. **Check the script path** — Ensure paths in `settings.json` match your install location
3. **Test manually** — Run `~/.claude/hooks/terminal-agent-visual-signals/claude-code-visual-signal.sh processing`
4. **Check TTY detection** — The script needs to find the parent process TTY

### Permission errors

```bash
# Ensure script is executable
chmod +x ~/.claude/hooks/terminal-agent-visual-signals/claude-code-visual-signal.sh
```

### Title not updating

- Some window managers may override OSC 0 titles
- Try toggling `ENABLE_TITLE_PREFIX` in the script

### Hooks not firing

- Ensure `settings.json` is valid JSON (use a JSON validator)
- Check Claude Code logs for hook errors
- For fastest response, place these hooks **first** in each hook array

## Performance

Optimized using bash builtins instead of external commands:

| Operation | Before | After |
|-----------|--------|-------|
| Get parent PID | `ps -o ppid=` | `$PPID` built-in |
| Remove spaces | `\| tr -d ' '` | `${var// /}` |
| Count slashes | `echo \| tr \| wc \| tr` | `${cwd//[!\/]/}` |
| basename/dirname | External commands | Parameter expansion |

**Result: ~1 external process vs ~12-15 previously**

## Requirements

- A [compatible terminal](#compatible-terminals) with OSC 11/111 support
- [Claude Code](https://claude.ai/code) CLI
- Bash 3.2+ (macOS default works)
- macOS or Linux

## Security

This script sanitizes `$PWD` before writing to the terminal to prevent [terminal escape sequence injection](https://dgl.cx/2023/09/ansi-terminal-security).

**Threat model:** On Unix, directory names can contain escape bytes (0x1B). A malicious directory name could inject OSC sequences to manipulate clipboard (OSC 52) or spoof UI.

**Mitigation:** The `sanitize_for_terminal()` function strips all ASCII control characters (0x00-0x1F, 0x7F) while preserving Unicode for international path support.

## Contributing

Issues and PRs welcome! If you've tested on additional terminals or have alternative color schemes to share, please contribute.

## License

MIT — see [LICENSE](LICENSE) file
