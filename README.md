# Terminal Agent Visual Signals

> Visual terminal state indicators for Claude Code sessions using OSC escape sequences

<!-- TODO: Add GIF demos after recording -->
<!-- GIF 1: All States (terminals showing all colors) -->
<!-- GIF 2: Graduated Idle Timer (purple fading through stages) -->
<!-- GIF 3: Practical Usage (processing → permission → complete flow) -->

## Why?

When running multiple Claude Code sessions (12+ terminals side by side), you need to quickly identify which ones need attention. This hook system provides instant visual feedback through background colors, emoji indicators, and optional audible bells.

| State | Color | Emoji | Meaning |
|-------|-------|-------|---------|
| Permission | 🔴 Red | 🔴 | **Needs attention** — Approval required |
| Processing | 🟠 Orange | 🟠 | **Working** — Claude is processing |
| Idle | 🟣 Purple | 🟣→🕐 | **Idle** — Graduated fade over time |
| Complete | 🟢 Green | 🟢 | **Done** — Task completed |
| Compacting | 🔵 Teal | 🔄 | **Compacting** — Context being compressed |

## Features

- **Background color changes** based on Claude Code state
- **Tab title prefixes** with emoji indicators
- **Graduated idle timer** — Progressive color fade with stage indicators
- **Audible bells** — Optional per-state audio notifications
- **Multi-session support** — Works across concurrent Claude Code sessions
- **State priority system** — Higher priority states (permission) protected from override
- **Optimized performance** — Uses bash builtins, minimal subprocess spawning
- **Configurable** — Enable/disable states, customize colors, adjust timing

## Compatible Terminals

This script uses standard OSC escape sequences supported by many modern terminals:

| Terminal | Background | Reset | Title | Status |
|----------|-----------|-------|-------|--------|
| **Ghostty** | ✅ | ✅ | ✅ | **Recommended** |
| Kitty | ✅ | ✅ | ✅ | Supported |
| WezTerm | ✅ | ✅ | ✅ | Supported |
| iTerm2 | ✅ | ✅ | ✅ | Tested |
| VS Code / Cursor | ✅ | ✅ | ✅ | Tested |
| GNOME Terminal | ✅ | ✅ | ✅ | Supported |
| Windows Terminal | ✅ | ✅ | ✅ | 2025+ |
| Foot | ✅ | ✅ | ✅ | Supported |
| Alacritty | ⚠️ | ⚠️ | ✅ | Untested |
| macOS Terminal.app | ❌ | ❌ | ✅ | No OSC 11 |

### Why Ghostty?

[Ghostty](https://ghostty.org/) is recommended for Claude Code sessions because:

- **Excellent performance** — GPU-accelerated rendering handles rapid output smoothly
- **No flickering** — Unlike many terminals, Ghostty rarely exhibits the "flickering bug" that can occur with Claude Code's rapid screen updates
- **Full OSC support** — Native support for OSC 11/111 background color changes

**Test your terminal:**
```bash
./test-terminal.sh
```

## Quick Start

### Option 1: Plugin Install (Recommended)

Install as a Claude Code plugin in two steps:

**Step 1:** Add the marketplace (one-time setup)
```bash
claude plugin marketplace add cstelmach/terminal-agent-visual-signals
```

**Step 2:** Install the plugin
```bash
claude plugin install terminal-visual-signals@terminal-visual-signals
```

That's it! Restart Claude Code to apply the visual signals.

> **⚠️ Known Issue:** Due to [Claude Code bug #14410](https://github.com/anthropics/claude-code/issues/14410), plugin hooks may not execute automatically. If visual signals don't work after plugin install, see [Workaround for Bug #14410](#workaround-for-bug-14410) below.

### Option 2: Manual Install

If you prefer manual setup or need to customize hooks:

**1. Clone the repository:**

```bash
git clone https://github.com/cstelmach/terminal-agent-visual-signals.git ~/.claude/hooks/terminal-agent-visual-signals
```

**2. Make executable:**

```bash
chmod +x ~/.claude/hooks/terminal-agent-visual-signals/scripts/claude-code-visual-signal.sh
```

**3. Add hooks to `~/.claude/settings.json`:**

Copy the hook configuration from `hooks/hooks.json` in this repository into your `settings.json`. Replace `${CLAUDE_PLUGIN_ROOT}` with the full path: `~/.claude/hooks/terminal-agent-visual-signals`.

**4. Restart Claude Code**

The visual signals will activate on your next session.

---

## Quick Disable (Environment Variable)

Temporarily disable visual signals without changing configuration:

```bash
# Disable for a single session
TAVS_STATUS=false claude

# Disable for all sessions in current terminal
export TAVS_STATUS=false

# Re-enable
unset TAVS_STATUS
# or
export TAVS_STATUS=true
```

Recognized disabled values (case-insensitive): `false`, `0`, `off`, `no`, `disabled`

Useful for presentations, screen sharing, or when you need a "quiet" terminal.

---

## Graduated Idle Timer

When Claude enters idle state, the terminal progressively fades through stages instead of showing a static color. This provides a visual sense of how long Claude has been waiting.

```
Stage 0 → Stage 1 → Stage 2 → Stage 3 → Stage 4 → Stage 5 (reset)
  🟣        🟣        🟣        🟣        🟣      (clear)
 dark     fading...                              default
purple                                          background
```

### Configuration

```bash
# Enable/disable stage indicators in title (emoji progression)
ENABLE_IDLE_STAGE_INDICATORS=true

# Colors for each stage (final stage = "reset" returns to terminal default)
IDLE_COLORS=("#443147" "#423148" "#3f3248" "#3a3348" "#373348" "reset")

# Emojis for each stage (can use clock faces for time indication)
IDLE_STATUS_ICONS=("🟣" "🟣" "🟣" "🟣" "🟣" "")        # Subtle
# IDLE_STATUS_ICONS=("🕐" "🕑" "🕒" "🕓" "🕔" "")      # Clock progression

# Duration per stage (seconds) - total idle time = sum of all durations
IDLE_STAGE_DURATIONS=(180 180 180 180 180 180)  # 18 minutes total

# How often timer checks for stage transitions
# Must be <= shortest stage duration for smooth transitions
IDLE_CHECK_INTERVAL=60  # Check every minute
```

**Testing configuration:**
```bash
# Quick testing (5 seconds per stage, 30 seconds total)
IDLE_STAGE_DURATIONS=(5 5 5 5 5 5)
IDLE_CHECK_INTERVAL=2
```

---

## Bell Configuration

Optional audible notifications for specific states. Useful for getting attention when working on other tasks.

```bash
# Enable/disable bell per state
BELL_ON_PROCESSING=false
BELL_ON_PERMISSION=true     # Alert: Claude needs permission
BELL_ON_COMPLETE=true       # Alert: Claude finished responding
BELL_ON_IDLE=false
BELL_ON_COMPACTING=false
BELL_ON_RESET=false
```

**Note:** Bells work best with terminals that support audio notifications. Some terminals may need configuration to enable sound.

---

## Configuration Reference

Edit the top of `scripts/claude-code-visual-signal.sh` to customize:

### Feature Toggles

```bash
ENABLE_BACKGROUND_CHANGE=true    # Change terminal background color
ENABLE_TITLE_PREFIX=true         # Add emoji prefix to terminal title

# Per-state enable/disable
ENABLE_PROCESSING=true
ENABLE_PERMISSION=true
ENABLE_COMPLETE=true
ENABLE_IDLE=true
ENABLE_COMPACTING=true
```

### Colors

Default colors are muted tints designed for the [Catppuccin Frappe](https://github.com/catppuccin/catppuccin) dark theme. They blend subtly with the background while remaining distinguishable:

```bash
COLOR_PROCESSING="#473D2F"   # Muted orange
COLOR_PERMISSION="#4A2021"   # Muted red
COLOR_COMPLETE="#473046"     # Muted purple-green
COLOR_IDLE="#473046"         # Muted purple
COLOR_COMPACTING="#2B4645"   # Muted teal
```

> **Tip:** If using a different theme, adjust colors to complement your terminal's background. The goal is subtle tinting, not jarring color changes.

### Status Icons

```bash
STATUS_ICON_PROCESSING="🟠"
STATUS_ICON_PERMISSION="🔴"
STATUS_ICON_COMPLETE="🟢"
STATUS_ICON_IDLE="🟣"
STATUS_ICON_COMPACTING="🔄"
```

### Alternative Color Themes

**Brighter colors (more noticeable):**
```bash
COLOR_PROCESSING="#5C4A28"
COLOR_PERMISSION="#5C2828"
COLOR_COMPLETE="#285C3D"
COLOR_IDLE="#4A285C"
COLOR_COMPACTING="#28525C"
```

**Light theme compatible:**
```bash
COLOR_PROCESSING="#FFF3CD"
COLOR_PERMISSION="#F8D7DA"
COLOR_COMPLETE="#D4EDDA"
COLOR_IDLE="#E2D9F3"
COLOR_COMPACTING="#D1ECF1"
```

---

## Manual Testing

```bash
# Test each state
./scripts/claude-code-visual-signal.sh processing   # 🟠 Orange
./scripts/claude-code-visual-signal.sh permission   # 🔴 Red
./scripts/claude-code-visual-signal.sh complete     # 🟢 Green
./scripts/claude-code-visual-signal.sh idle         # 🟣 Purple (starts timer)
./scripts/claude-code-visual-signal.sh compacting   # 🔄 Teal
./scripts/claude-code-visual-signal.sh reset        # Default background
```

---

## How It Works

### OSC Escape Sequences

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
PreToolUse (compact) → compacting (teal)
    ↓
PermissionRequest → permission (red)
    ↓
User approves → PostToolUse → processing (orange)
    ↓
Stop → complete (green)
    ↓
60+ sec idle → Notification → idle (purple, starts graduated timer)
    ↓
Stage transitions every N seconds → color fades → reset
```

### State Priority System

Higher priority states are protected from being overwritten for a brief period:

| State | Priority | Notes |
|-------|----------|-------|
| Permission | 100 | Highest - never overwritten |
| Idle | 90 | Protected during idle |
| Compacting | 50 | Medium priority |
| Processing | 30 | Common state |
| Complete | 20 | Brief flash |
| Reset | 10 | Lowest |

### Multi-Session Support

A consolidated state file (`/tmp/claude-visual-signals.state`) tracks all active sessions by their TTY identifier. Each session maintains its own state independently.

---

## Troubleshooting

### Colors not appearing

1. **Test your terminal** — Run `./test-terminal.sh` to verify OSC support
2. **Check the script path** — Ensure paths in `settings.json` match your install location
3. **Test manually** — Run `./scripts/claude-code-visual-signal.sh processing`
4. **Check TTY detection** — The script needs to find the parent process TTY

### Permission errors

```bash
# Ensure script is executable
chmod +x ~/.claude/hooks/terminal-agent-visual-signals/scripts/claude-code-visual-signal.sh
```

### Title not updating

- Some window managers may override OSC 0 titles
- Try toggling `ENABLE_TITLE_PREFIX` in the script

### Idle timer not progressing

- Ensure `IDLE_CHECK_INTERVAL` is less than or equal to the shortest `IDLE_STAGE_DURATIONS` value
- For testing, use short durations (5s) with matching check interval (2-5s)

### Hooks not firing

- Ensure `settings.json` is valid JSON (use a JSON validator)
- Check Claude Code logs for hook errors
- For fastest response, place these hooks **first** in each hook array

---

## Workaround for Bug #14410

Due to [Claude Code bug #14410](https://github.com/anthropics/claude-code/issues/14410), plugin hooks defined in `hooks/hooks.json` may be matched but never executed. This affects all hook types when installed via the plugin system.

### Symptoms

- Plugin installs successfully
- Visual signals don't appear
- No errors in Claude Code logs

### Solution

Run the setup script to create a version-independent symlink and add hooks directly to `settings.json`:

**Step 1:** Run the setup script (after plugin install)
```bash
# Find and run the setup script from the plugin cache
bash ~/.claude/plugins/cache/terminal-visual-signals/terminal-visual-signals/*/setup-hooks-workaround.sh --install
```

This creates:
- A stable symlink at `~/.claude/hooks/terminal-visual-signals-current/`
- A session-start script that auto-updates the symlink when the plugin version changes

**Step 2:** Copy the hooks output to `~/.claude/settings.json`

The script prints the exact JSON to add. Merge these hooks with your existing `settings.json` hooks, placing the visual signal hooks **first** in each array for fastest response.

**Step 3:** Restart Claude Code

### How It Works

```
SessionStart hook runs
    ↓
Checks if symlink points to current plugin version
    ↓
Updates symlink if version changed (plugin update)
    ↓
Calls reset script
    ↓
All other hooks use the stable symlink path
```

**Benefits:**
- **Version-independent** — Symlink auto-updates when plugin updates
- **One-time setup** — No manual intervention needed after plugin updates
- **Easy removal** — When bug is fixed, run `--uninstall`

### Removing the Workaround

When Claude Code bug #14410 is fixed:

```bash
bash ~/.claude/plugins/cache/terminal-visual-signals/terminal-visual-signals/*/setup-hooks-workaround.sh --uninstall
```

Then remove the visual signal hooks from your `settings.json`. The native plugin hooks will take over.

---

## Performance

Optimized using bash builtins to minimize subprocess spawning:

| Operation | Before | After |
|-----------|--------|-------|
| Get parent PID | `ps -o ppid=` | `$PPID` built-in |
| Remove spaces | `\| tr -d ' '` | `${var// /}` |
| Count slashes | `echo \| tr \| wc \| tr` | `${cwd//[!\/]/}` |
| basename/dirname | External commands | Parameter expansion |
| Elapsed time | `$(date +%s)` | `$SECONDS` built-in |
| Function returns | `$(func)` subshell | Global variable |

**Result:** Timer worker spawns ~1-2 external processes per iteration vs ~6-8 previously.

---

## Requirements

- A [compatible terminal](#compatible-terminals) with OSC 11/111 support
- [Claude Code](https://claude.ai/code) CLI
- Bash 3.2+ (macOS default works)
- macOS or Linux

---

## Security

This script sanitizes `$PWD` before writing to the terminal to prevent [terminal escape sequence injection](https://dgl.cx/2023/09/ansi-terminal-security).

**Threat model:** On Unix, directory names can contain escape bytes (0x1B). A malicious directory name could inject OSC sequences to manipulate clipboard (OSC 52) or spoof UI.

**Mitigation:** The `sanitize_for_terminal()` function strips all ASCII control characters (0x00-0x1F, 0x7F) while preserving Unicode for international path support.

---

## Contributing

Issues and PRs welcome! If you've tested on additional terminals or have alternative color schemes to share, please contribute.

**Ideas for contribution:**
- Additional color themes
- Terminal compatibility reports
- Alternative emoji sets
- Integration with other AI coding tools

---

## License

MIT — see [LICENSE](LICENSE) file

---

## Credits

Created for the Claude Code community. Share your setups on [r/ClaudeAI](https://reddit.com/r/ClaudeAI)!
