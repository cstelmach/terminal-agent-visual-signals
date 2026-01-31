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

---

## Quick Start

```bash
# Test visual signals manually
./src/core/trigger.sh processing   # Orange
./src/core/trigger.sh complete     # Green
./src/core/trigger.sh reset        # Default

# Quick disable (run without visual signals)
TAVS_STATUS=false claude

# Test terminal compatibility
./test-terminal.sh

# Install for Gemini CLI
./install-gemini.sh

# Install for Codex CLI (limited)
./install-codex.sh

# Build OpenCode plugin
cd src/agents/opencode && npm install && npm run build
```

---

## Supported Platforms

| Platform | Support | Installation |
|----------|---------|--------------|
| Claude Code | ✅ Full (9 events) | Plugin marketplace or manual |
| Gemini CLI | ✅ Full (8 events) | `./install-gemini.sh` |
| OpenCode | ✅ Good (4 events) | npm package |
| Codex CLI | ⚠️ Limited (1 event) | `./install-codex.sh` |

## Visual States

| State | Color | Emoji | Description |
|-------|-------|-------|-------------|
| Processing | Orange | 🟠 | Agent working |
| Permission | Red | 🔴 | Needs user approval |
| Complete | Green | 🟢 | Response finished |
| Idle | Purple (graduated) | 🟣 | Waiting for input |
| Compacting | Teal | 🔄 | Context compression |

---

## Key Files

| File | Purpose |
|------|---------|
| `src/core/trigger.sh` | Main signal dispatcher |
| `src/core/theme.sh` | Config loader, color/face resolution, AGENT_ prefix handling |
| `src/core/terminal.sh` | OSC sequences (OSC 4/11 for palette/background) |
| `src/core/spinner.sh` | Animated spinner system for processing state titles |
| `src/core/backgrounds.sh` | Stylish background images (iTerm2/Kitty) |
| `src/core/detect.sh` | Terminal type, capabilities, color mode detection |
| `src/config/defaults.conf` | **Single source of truth**: global settings + all agent colors/faces |
| `src/config/user.conf.template` | Template for user overrides (copy to ~/.terminal-visual-signals/) |
| `configure.sh` | Interactive configuration wizard |
| `hooks/hooks.json` | Claude Code plugin hooks |

## User Configuration

All user settings are stored in `~/.terminal-visual-signals/user.conf`:

```
~/.terminal-visual-signals/
├── user.conf              # All user overrides (global + per-agent)
└── backgrounds/           # Background images (if enabled)
    ├── dark/
    └── light/
```

**Variable naming convention:**
- Global settings: `THEME_MODE`, `ENABLE_ANTHROPOMORPHISING`, etc.
- Per-agent overrides: `CLAUDE_DARK_BASE`, `GEMINI_FACES_PROCESSING`, etc.
- Default fallbacks: `DEFAULT_DARK_BASE`, `DEFAULT_LIGHT_BASE`, etc.

**Run `./configure.sh`** to set up interactively, or copy `src/config/user.conf.template` to `~/.terminal-visual-signals/user.conf` and edit directly.

---

## Documentation Reference

| About | What You'll Find | Key Concepts | Read When |
|-------|------------------|--------------|-----------|
| [Architecture](docs/reference/architecture.md) | High-level system design showing how core modules connect to agent adapters. Explains the unified trigger system, OSC sequences, and how each CLI platform hooks into the core. | core-modules, agent-adapters, OSC-sequences, state-machine | Understanding how signals flow, adding new agent support, debugging cross-platform issues |
| [Agent Themes](docs/reference/agent-themes.md) | Per-agent customization of faces, colors, and backgrounds. Explains the directory structure, file formats, override priority, and how to create custom themes without modifying source files. | faces.conf, colors.conf, random-selection, user-overrides | Customizing agent appearance, adding new agent themes, understanding face selection |
| [Testing](docs/reference/testing.md) | Manual and automated testing procedures for visual signals. Covers terminal compatibility, hook verification, and debug mode for troubleshooting. | manual-testing, hook-verification, debug-mode, terminal-support | Verifying changes work, testing new installations, when signals don't appear |
| [Troubleshooting](docs/troubleshooting/overview.md) | Quick fixes for common problems including terminal compatibility, plugin enablement, and hook installation issues. | quick-fixes, debug-mode, terminal-compatibility | When visual signals don't work, plugin shows disabled, colors are wrong |

---

## Development Notes

### Plugin System (v1.2.0)

Bug #14410 (plugin hooks not executing) was fixed in Claude Code v2.1.9. The plugin now works natively via the marketplace.

**Current plugin version:** 1.2.0

```bash
# Install plugin
claude plugin marketplace add cstelmach/terminal-agent-visual-signals
claude plugin install terminal-visual-signals@terminal-visual-signals

# Enable plugin
/plugin → select terminal-visual-signals
```

### Async Hooks

All hooks use `async: true` for non-blocking execution:
- Processing signals: 5s timeout
- Idle/Complete signals: 10s timeout (spawn worker)

### Testing Changes

```bash
# Test each state
./src/core/trigger.sh processing
./src/core/trigger.sh permission
./src/core/trigger.sh complete
./src/core/trigger.sh idle
./src/core/trigger.sh compacting
./src/core/trigger.sh reset

# Test light mode explicitly
FORCE_MODE=light ./src/core/trigger.sh processing
FORCE_MODE=light ./src/core/trigger.sh reset

# Test palette theming (requires 256-color mode)
ENABLE_PALETTE_THEMING=true COLORTERM= ./src/core/trigger.sh processing
ls --color=auto  # Check if ls colors match theme
./src/core/trigger.sh reset

# Check terminal capabilities
bash src/core/detect.sh test
```

### Terminal Compatibility

| Terminal | OSC 4 (palette) | OSC 11 (bg) | OSC 1337 (images) |
|----------|-----------------|-------------|-------------------|
| Ghostty | ✅ | ✅ | ❌ |
| iTerm2 | ✅ | ✅ | ✅ |
| Kitty | ✅ | ✅ | ❌* |
| WezTerm | ✅ | ✅ | ❌** |
| Terminal.app | ❌ | ❌ | ❌ |

\* Kitty uses its own image protocol, not OSC 1337.
\** WezTerm has partial OSC 1337 support, but TAVS only uses OSC 1337 backgrounds on iTerm2.

**Note:** OSC 4 palette theming only affects applications using ANSI palette indices.
Claude Code uses TrueColor (24-bit RGB) by default, which bypasses the palette.

### Agent-Specific Face Themes

Each agent has its own face theme with random selection per trigger:

| Agent | Face Style | Example | Variants |
|-------|------------|---------|----------|
| Claude Code | Pincer | `Ǝ[• •]E` | 6 per state |
| Gemini CLI | Bear | `ʕ•ᴥ•ʔ` | 1 per state |
| OpenCode | Minimal kaomoji | `(°-°)` | 1 per state |
| Codex CLI | Cat | `ฅ^•ﻌ•^ฅ` | 1 per state |
| Unknown | Kaomoji fallback | `(°-°)` | 1 per state |

**All faces defined in:** `src/config/defaults.conf` (search for `AGENT_FACES_`)
**User overrides:** Add `CLAUDE_FACES_PROCESSING=('custom' 'faces')` to `~/.terminal-visual-signals/user.conf`

See [Agent Themes Reference](docs/reference/agent-themes.md) for customization guide.

### Stylish Backgrounds (Images)

Background images per state, with automatic fallback:

| Terminal | Support | Prerequisites |
|----------|---------|---------------|
| iTerm2 | ✅ Full | Enable background images in preferences (see below) |
| Kitty | ✅ Full | `allow_remote_control=yes` in kitty.conf |
| Others | ○ Fallback | None - uses solid colors via OSC 11 |

**iTerm2 Setup (required):**
1. iTerm2 → Preferences → Profiles → (your profile) → Window
2. Enable "Background Image" (can leave path empty)
3. Without this, OSC 1337 background commands are ignored

**Enable in `~/.terminal-visual-signals/user.conf`:**
```bash
ENABLE_STYLISH_BACKGROUNDS="true"
STYLISH_BACKGROUNDS_DIR="$HOME/.terminal-visual-signals/backgrounds"
```

**Generate sample images:**
```bash
./assets/backgrounds/generate-samples.sh ~/.terminal-visual-signals/backgrounds
```

This is a global setting - supported terminals show images, unsupported terminals automatically fall back to solid colors.

### Palette Theming (Optional)

TAVS can modify the terminal's 16-color ANSI palette for cohesive light/dark themes.
This affects shell prompts, `ls` output, `git status`, and other CLI tools.

**Enable in `~/.terminal-visual-signals/user.conf`:**
```bash
ENABLE_PALETTE_THEMING="auto"  # or "true"
```

**Options:**
- `"false"` (default) - Background colors only
- `"auto"` - Enable when NOT in TrueColor mode
- `"true"` - Always apply palette (affects shell tools)

**Limitation: TrueColor Applications**

Applications using TrueColor (24-bit RGB) bypass the palette entirely.
Claude Code uses TrueColor by default (`COLORTERM=truecolor`).

**To enable palette theming for Claude Code:**
```bash
# Launch with 256-color mode
TERM=xterm-256color COLORTERM= claude

# Or add alias to your shell profile
alias claude='TERM=xterm-256color COLORTERM= claude'
```

**How It Works:**

| Mode | Background (OSC 11) | Palette (OSC 4) | Affects |
|------|---------------------|-----------------|---------|
| `ENABLE_PALETTE_THEMING=false` | ✅ | ❌ | Background only |
| `ENABLE_PALETTE_THEMING=auto` + TrueColor | ✅ | ❌ | Background only |
| `ENABLE_PALETTE_THEMING=auto` + 256-color | ✅ | ✅ | Background + all text |
| `ENABLE_PALETTE_THEMING=true` | ✅ | ✅ | Background + shell tools |

**Theme Presets with Palettes:**

All theme presets include 16-color ANSI palettes:
- Catppuccin (Frappé, Latte, Macchiato, Mocha)
- Nord
- Dracula
- Solarized (Dark, Light)
- Tokyo Night

Select in `configure.sh` or set `THEME_PRESET` in user.conf.

---

## Verification

```bash
# Verify plugin installed
claude plugin list | grep visual

# Verify hooks in settings
grep -A5 "terminal-visual-signals" ~/.claude/settings.json

# Verify signals work
./src/core/trigger.sh processing && sleep 2 && ./src/core/trigger.sh reset
```
