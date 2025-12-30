# Ghostty Visual Signals for Claude Code

Visual state indicators for Claude Code sessions in [Ghostty](https://ghostty.org/) terminal.

## Features

- **Background color changes** based on Claude Code state
- **Tab title prefixes** with emoji indicators
- **Optimized performance** - minimal external process spawns (~1 vs ~15)
- **Configurable** - enable/disable states, customize colors

## States

| State | Color | Emoji | Trigger |
|-------|-------|-------|---------|
| Processing | Orange `#473D2F` | 🟠 | Claude is working |
| Permission | Red `#4A2021` | 🔴 | Needs user approval |
| Complete | Green `#2B4636` | 🟢 | Task finished (disabled by default) |
| Idle | Purple `#3E3046` | 🟣 | Waiting 60+ seconds (disabled by default) |
| Reset | Default | — | Normal terminal state |

## Installation

The script is invoked via Claude Code hooks in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [{
      "hooks": [{
        "command": "bash ~/.claude/hooks/ghostty-visual-signals/ghostty-signal.sh processing",
        "type": "command"
      }]
    }],
    "PermissionRequest": [{
      "hooks": [{
        "command": "bash ~/.claude/hooks/ghostty-visual-signals/ghostty-signal.sh permission",
        "type": "command"
      }],
      "matcher": "*"
    }],
    "PostToolUse": [{
      "hooks": [{
        "command": "bash ~/.claude/hooks/ghostty-visual-signals/ghostty-signal.sh processing",
        "type": "command"
      }],
      "matcher": "*"
    }],
    "Stop": [{
      "hooks": [{
        "command": "bash ~/.claude/hooks/ghostty-visual-signals/ghostty-signal.sh complete",
        "type": "command"
      }]
    }],
    "Notification": [
      {
        "hooks": [{
          "command": "bash ~/.claude/hooks/ghostty-visual-signals/ghostty-signal.sh permission",
          "type": "command"
        }],
        "matcher": "permission_prompt"
      },
      {
        "hooks": [{
          "command": "bash ~/.claude/hooks/ghostty-visual-signals/ghostty-signal.sh idle",
          "type": "command"
        }],
        "matcher": "idle_prompt"
      }
    ],
    "SessionStart": [{
      "hooks": [{
        "command": "bash ~/.claude/hooks/ghostty-visual-signals/ghostty-signal.sh reset",
        "type": "command"
      }]
    }],
    "SessionEnd": [{
      "hooks": [{
        "command": "bash ~/.claude/hooks/ghostty-visual-signals/ghostty-signal.sh reset",
        "type": "command"
      }]
    }]
  }
}
```

## Configuration

Edit the top of `ghostty-signal.sh` to customize:

```bash
# Feature toggles
ENABLE_BACKGROUND_CHANGE=true    # Change terminal background color
ENABLE_TITLE_PREFIX=true         # Add emoji prefix to terminal title

# Per-state enable/disable
ENABLE_PROCESSING=true
ENABLE_PERMISSION=true
ENABLE_COMPLETE=false    # Disabled by default
ENABLE_IDLE=false        # Disabled by default

# Colors (muted tints for Catppuccin Frappe theme)
COLOR_PROCESSING="#473D2F"
COLOR_PERMISSION="#4A2021"
COLOR_COMPLETE="#2B4636"
COLOR_IDLE="#3E3046"
```

## Usage

```bash
# Manual testing
./ghostty-signal.sh processing   # Orange background + 🟠 title
./ghostty-signal.sh permission   # Red background + 🔴 title
./ghostty-signal.sh complete     # Green background + 🟢 title
./ghostty-signal.sh idle         # Purple background + 🟣 title
./ghostty-signal.sh reset        # Default background
```

## How It Works

The script uses OSC (Operating System Command) escape sequences:

- `OSC 11` - Set background color
- `OSC 111` - Reset background to default
- `OSC 0` - Set window/tab title

These are sent directly to the TTY device to bypass Claude Code's stdout capture.

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

- [Ghostty](https://ghostty.org/) terminal (v1.0+)
- [Claude Code](https://claude.ai/code) CLI
- Bash 3.2+ (macOS default)

## License

MIT
