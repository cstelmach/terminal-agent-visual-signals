# TAVS - Terminal Agent Visual Signals

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-3.0.0-green.svg)](CHANGELOG.md)
[![Bash 3.2+](https://img.shields.io/badge/bash-3.2%2B-orange.svg)](#requirements)
[![Platforms](https://img.shields.io/badge/agents-Claude%20%7C%20Gemini%20%7C%20Codex%20%7C%20OpenCode-purple.svg)](#supported-platforms)

> Visual terminal feedback for AI coding sessions — background colors, tab titles, and faces that show you what's happening at a glance.

## Why?

When running multiple AI sessions (12+ terminals side by side), you need to instantly see which ones need attention. TAVS provides visual feedback through background colors, emoji indicators, animated faces, and optional audible bells.

| State | Color | Icon | Meaning |
|-------|-------|------|---------|
| Processing | Orange | 🟠 | Agent is working |
| Permission | Red | 🔴 | Needs your approval |
| Complete | Green | 🟢 | Response finished |
| Idle | Purple | 🟣 | Waiting for input (fades over time) |
| Compacting | Teal | 🔄 | Context being compressed |
| Subagent | Golden | 🔀 | Spawned a subagent |
| Tool Error | Orange-Red | ❌ | Tool execution failed |

Works with **Claude Code**, **Gemini CLI**, **OpenCode**, and **Codex CLI**.

---

## Install

### Plugin (Recommended — Claude Code)

```bash
# Add marketplace (one-time)
claude plugin marketplace add cstelmach/terminal-agent-visual-signals

# Install
claude plugin install tavs@terminal-agent-visual-signals
```

Then enable via `/plugin` in Claude Code and restart.

### Other Agents

```bash
# Gemini CLI (full support, 8 events)
./tavs install gemini

# Codex CLI (limited, 1 event)
./tavs install codex

# OpenCode (npm package — see docs/)
cd src/agents/opencode && npm install && npm run build
```

### Manual Install (Claude Code)

```bash
# Clone
git clone https://github.com/cstelmach/terminal-agent-visual-signals.git \
    ~/.claude/hooks/terminal-agent-visual-signals

# Make executable
chmod +x ~/.claude/hooks/terminal-agent-visual-signals/src/core/trigger.sh
```

Copy hooks from `hooks/hooks.json` into `~/.claude/settings.json`, replacing
`${CLAUDE_PLUGIN_ROOT}` with the full clone path. Restart Claude Code.

---

## Configuration — Three Ways

TAVS works in three tiers. Pick the one that fits you.

### 1. Just Use the Defaults

**Do nothing.** After installing, TAVS works immediately with sensible defaults:

- Catppuccin Frappe dark theme (muted, professional colors)
- ASCII faces in tab titles: `Ǝ[• •]E 🟠 ~/project`
- Background color changes per state
- Session icons (unique animal emoji per tab)
- Mode-aware processing (subtle color shift in plan mode)

This is enough for most users. The colors are designed to be noticeable but not
distracting — subtle tints that blend with your terminal background.

**Check what you're running:**
```bash
./tavs status
```

### 2. Change a Setting

One command to tweak anything. No files to edit.

**Switch theme:**
```bash
./tavs set theme nord           # Arctic blue palette
./tavs set theme dracula        # Vibrant dark theme
./tavs set theme tokyo-night    # City lights aesthetic
```

**Switch face mode:**
```bash
./tavs set face-mode compact    # Emoji eyes: Ǝ[🟧 +2]E instead of Ǝ[• •]E 🟠 +2
```

**Turn faces off:**
```bash
./tavs set faces off            # Colors only, no faces in titles
```

**Control titles:**
```bash
./tavs set title-mode full      # TAVS owns all titles with animated spinners
./tavs set title-mode off       # No title changes, colors only
```

**See all available settings:**
```bash
./tavs set                      # Lists all 23 settings with descriptions
```

**Interactive picker** — omit the value to choose from a menu:
```bash
./tavs set theme                # Shows all 9 themes → pick one
./tavs set spinner              # Shows all spinner styles → pick one
```

**Preview your changes:**
```bash
./tavs status                   # Visual summary with color swatches
./tavs status --colors          # Just the color preview
```

### 3. Customize Everything

For full control over all 65+ settings, use the interactive wizard:

```bash
./tavs wizard
```

This walks you through 7 steps:

**Step 1 — Operating Mode**
Choose how colors are determined:
- `static` — Fixed colors from defaults (simplest)
- `dynamic` — Query your terminal's current background, compute matching colors
- `preset` — Use a named theme (Nord, Dracula, etc.)

**Step 2 — Theme Preset** (if you chose `preset`)
Pick from 9 built-in themes. Each includes dark colors, light colors, and a 16-color
ANSI palette. Preview them first:
```bash
./tavs theme --preview          # Side-by-side color swatches for all themes
```

**Step 3 — Light/Dark Mode**
- Auto-detect your system appearance (macOS dark mode → dark colors)
- Or force a specific mode

**Step 4 — ASCII Faces**
Enable/disable the character faces in titles. Choose standard text eyes or
compact emoji eyes:
```
Standard:  Ǝ[• •]E 🟠 +2 🦊 ~/project
Compact:   Ǝ[🟧 +2]E 🦊 ~/project
```
Compact mode embeds the status icon and subagent count directly into the face.

**Step 5 — Background Images** (iTerm2/Kitty only)
Use images instead of solid colors for state backgrounds.

**Step 6 — Terminal Titles**
Four modes:

| Mode | What happens |
|------|-------------|
| `skip-processing` | (Default) TAVS handles non-processing states, Claude handles processing |
| `prefix-only` | Adds face + status to your existing tab name |
| `full` | TAVS owns all titles with animated spinner eyes |
| `off` | No title changes at all |

For `full` mode, choose a spinner style (braille, circle, block, eye-animate) and
eye sync mode (sync, opposite, mirror, stagger).

**Step 7 — Palette Theming**
Optionally modify your terminal's 16-color ANSI palette to match the theme. This
affects `ls` colors, `git status`, shell prompts, etc.

#### Direct Config Editing

After the wizard (or instead of it), you can edit the config file directly:

```bash
./tavs config edit              # Opens ~/.tavs/user.conf in your $EDITOR
```

The config file is organized into 5 sections with inline documentation.
Every setting is commented with valid values and what it does.

```bash
./tavs config validate          # Check for typos or invalid values
./tavs config show              # Print current config
./tavs config reset             # Backup and start fresh
```

---

## Available Themes

All themes include dark colors, light colors, and a 16-color ANSI palette.

| Theme | Style |
|-------|-------|
| `catppuccin-frappe` | Muted, subdued dark (default) |
| `catppuccin-latte` | Warm, light pastels |
| `catppuccin-macchiato` | Medium contrast dark |
| `catppuccin-mocha` | The darkest Catppuccin |
| `nord` | Arctic blue palette |
| `dracula` | Vibrant high-contrast dark |
| `solarized-dark` | Precision colors for readability |
| `solarized-light` | Light variant of Solarized |
| `tokyo-night` | Inspired by Tokyo city lights |

```bash
./tavs theme                    # List all with descriptions
./tavs theme --preview          # Color swatches for each
./tavs set theme nord           # Apply one
```

---

## Compatible Terminals

| Terminal | Background | Titles | Images | Status |
|----------|-----------|--------|--------|--------|
| **Ghostty** | ✅ | ✅ | ❌ | **Recommended** |
| Kitty | ✅ | ✅ | ✅ | Full support |
| iTerm2 | ✅ | ✅ | ✅ | Full support |
| WezTerm | ✅ | ✅ | ❌ | Supported |
| VS Code / Cursor | ✅ | ✅ | ❌ | Tested |
| GNOME Terminal | ✅ | ✅ | ❌ | Supported |
| Windows Terminal | ✅ | ✅ | ❌ | 2025+ |
| Foot | ✅ | ✅ | ❌ | Supported |
| Alacritty | ⚠️ | ✅ | ❌ | Untested |
| macOS Terminal.app | ❌ | ✅ | ❌ | No OSC 11 |

**Test your terminal:**
```bash
./tavs test --terminal          # Show capabilities
./tavs test                     # Full 8-state visual cycle
./tavs test --quick             # Quick 3-state test
```

### Ghostty Users

Ghostty's shell integration manages tab titles, which conflicts with TAVS titles.
Add to your Ghostty config:

```ini
# ~/Library/Application Support/com.mitchellh.ghostty/config
shell-integration-features = no-title
```

This only disables title management — cursor shapes and other integrations stay active.

---

## Quick Disable

Temporarily disable without changing configuration:

```bash
TAVS_STATUS=false claude        # Single session
export TAVS_STATUS=false        # All sessions in current terminal
unset TAVS_STATUS               # Re-enable
```

---

## Migrating from v2

If you have an existing `~/.tavs/user.conf` from before v3:

```bash
./tavs migrate                  # Detects old config, backs up, migrates
```

Your settings are preserved — the migration reorganizes the file into the new
5-section v3 format while keeping your values intact.

---

## How It Works

TAVS uses [OSC escape sequences](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html)
sent directly to the TTY device (`/dev/ttysXXX`), bypassing stdout capture:

| Sequence | Purpose |
|----------|---------|
| `OSC 11` | Set terminal background color |
| `OSC 111` | Reset background to default |
| `OSC 4` | Modify 16-color ANSI palette (optional) |
| `OSC 0` | Set window/tab title |

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
Stop → complete (green) → idle timer starts
    ↓
60+ sec idle → graduated purple fade → reset
```

### State Priority

Higher priority states are protected from being overwritten:

| State | Priority | Notes |
|-------|----------|-------|
| Permission | 100 | Never overwritten |
| Idle | 90 | Protected during idle |
| Compacting | 50 | Medium |
| Processing | 30 | Common state |
| Complete | 20 | Brief flash |
| Reset | 10 | Lowest |

---

## Supported Platforms

| Platform | Support | Events | Install |
|----------|---------|--------|---------|
| Claude Code | Full | 14 hooks | Plugin marketplace |
| Gemini CLI | Full | 8 events | `./tavs install gemini` |
| OpenCode | Good | 4 events | npm package |
| Codex CLI | Limited | 1 event | `./tavs install codex` |

---

## Troubleshooting

### Colors not appearing

1. Run `./tavs test --terminal` to verify OSC support
2. Run `./src/core/trigger.sh processing` to test manually
3. Check that paths in `settings.json` match your install location
4. Ensure the script is executable: `chmod +x src/core/trigger.sh`

### Titles not updating

- **Ghostty**: Add `shell-integration-features = no-title` to config
- **Full mode**: Add `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` to Claude Code env
- Some window managers may override OSC 0 titles

### Idle timer not progressing

- Ensure `IDLE_CHECK_INTERVAL` <= shortest `IDLE_STAGE_DURATIONS` value
- For testing, use short durations: `IDLE_STAGE_DURATIONS=(5 5 5 5 5 5)`

### Hooks not firing

- Validate `settings.json` is valid JSON
- Check Claude Code logs for hook errors
- Place TAVS hooks **first** in each hook array for fastest response

---

## Performance

Optimized using bash builtins to minimize subprocess spawning:

| Operation | Method |
|-----------|--------|
| Parent PID | `$PPID` built-in |
| String manipulation | Parameter expansion (`${var// /}`) |
| Elapsed time | `$SECONDS` built-in |
| Function returns | Global variable (no subshell) |

All hooks run asynchronously with timeouts (5s processing, 10s idle/complete).

---

## Requirements

- A [compatible terminal](#compatible-terminals) with OSC 11/111 support
- Bash 3.2+ (macOS default works)
- macOS or Linux
- Optional: [fzf](https://github.com/junegunn/fzf) for interactive pickers

---

## Security

Path values are sanitized before writing to the terminal to prevent
[terminal escape sequence injection](https://dgl.cx/2023/09/ansi-terminal-security).
All ASCII control characters (0x00-0x1F, 0x7F) are stripped while preserving Unicode.

Config input is validated — variable names are restricted to `[A-Za-z0-9_]`, values
are escaped before writing, and command names are validated against allowlists.

---

## FAQ

**Will TAVS slow down my AI agent?**
No. All hooks run asynchronously with timeouts (5s processing, 10s idle). TAVS uses
bash builtins to minimize subprocess spawning. Your agent never waits for TAVS.

**Can I use TAVS with multiple agents at the same time?**
Yes. Each agent writes to its own TTY device, so signals don't interfere. You can run
Claude Code, Gemini CLI, and Codex CLI simultaneously with independent visual feedback.

**My terminal doesn't change colors — what's wrong?**
Run `./tavs test --terminal` to check OSC support. If your terminal doesn't support
OSC 11, background colors won't work (e.g., macOS Terminal.app). See
[Troubleshooting](#troubleshooting).

**Can I disable it temporarily without uninstalling?**
Yes: `TAVS_STATUS=false claude` for a single session. See [Quick Disable](#quick-disable).

**How do I create a custom theme?**
Copy an existing theme from `src/themes/` (e.g., `nord.conf`), modify the colors,
and set `THEME_PRESET` to your filename. See [CONTRIBUTING.md](CONTRIBUTING.md#adding-themes).

---

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:

- Reporting bugs and requesting features
- Adding themes, terminals, or agent support
- Code style (Bash 3.2 compatibility)
- Testing and commit conventions

---

## License

MIT — see [LICENSE](LICENSE)

---

## Credits

Created for the AI coding community. Feedback and setups welcome on
[r/ClaudeAI](https://reddit.com/r/ClaudeAI) and
[GitHub Discussions](https://github.com/cstelmach/terminal-agent-visual-signals/discussions).
