# CLAUDE.md - TAVS - Terminal Agent Visual Signals

## Project Tracking

**Obsidian Project:** `IPC17_tavs`
**Location:** `/Users/cs/Obsidian/_/kn/projects/IPC17_tavs.md`

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
./src/core/trigger.sh processing     # Orange
./src/core/trigger.sh complete       # Green
./src/core/trigger.sh subagent-start # Golden-Yellow (NEW)
./src/core/trigger.sh tool_error     # Orange-Red (NEW)
./src/core/trigger.sh reset          # Default

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
| Claude Code | ✅ Full (14 hooks) | Plugin marketplace or manual |
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
| Subagent | Golden-Yellow | 🔀 | Task tool spawned subagent |
| Tool Error | Orange-Red | ❌ | Tool execution failed (auto-returns after 1.5s) |

**Mode-Aware Processing:** When enabled (`ENABLE_MODE_AWARE_PROCESSING="true"`, default),
the processing color shifts subtly based on Claude Code's permission mode:

| Mode | Color Shift | Description |
|------|-------------|-------------|
| `default` | Standard orange | Normal processing (no change) |
| `plan` | Green-yellow tinge | Plan mode (read-only, thinking) |
| `acceptEdits` | Barely warmer | Auto-approve edits mode |
| `dontAsk` | Same as acceptEdits | Auto-approve all |
| `bypassPermissions` | Reddish tinge | Dangerous mode (all bypassed) |

Set `ENABLE_MODE_AWARE_PROCESSING="false"` in `~/.tavs/user.conf` to disable.

**TrueColor Mode Behavior:** When TrueColor is active (`COLORTERM=truecolor`),
light/dark switching is skipped by default. TrueColor terminals have their own
color schemes that TAVS respects. Override with `TRUECOLOR_MODE_OVERRIDE`:

| Value | Behavior |
|-------|----------|
| `"off"` | (Default) Skip auto detection, always use dark mode |
| `"muted"` | Allow light/dark switching with muted colors (reduced contrast) |
| `"full"` | Allow light/dark switching with regular colors |

Set in `~/.tavs/user.conf`.

---

## Key Files

| File | Purpose |
|------|---------|
| `src/core/trigger.sh` | Main signal dispatcher (all states including subagent/tool_error) |
| `src/core/theme-config-loader.sh` | Config loader, color/face resolution, AGENT_ prefix handling, mode-aware colors |
| `src/core/terminal-osc-sequences.sh` | OSC sequences (OSC 4/11 for palette/background) |
| `src/core/title-management.sh` | Title management with user override detection |
| `src/core/title-iterm2.sh` | iTerm2-specific title detection via OSC 1337 |
| `src/core/title-state-persistence.sh` | Title state persistence across invocations |
| `src/core/spinner.sh` | Animated spinner system for processing state titles |
| `src/core/face-selection.sh` | Face selection: standard (text) and compact (emoji eyes) modes |
| `src/core/backgrounds.sh` | Stylish background images (iTerm2/Kitty) |
| `src/core/terminal-detection.sh` | Terminal type, capabilities, color mode detection |
| `src/core/subagent-counter.sh` | Subagent count tracking for title display and state transitions |
| `src/core/session-icon.sh` | Unique animal emoji per terminal tab (registry-based dedup) |
| `src/core/session-state.sh` | Session state tracking (current state, timer PID) |
| `src/core/idle-worker-background.sh` | Background process for graduated idle states |
| `src/core/palette-mode-helpers.sh` | Palette theming mode detection helpers |
| `src/config/defaults.conf` | **Single source of truth**: global settings + all agent colors/faces |
| `src/config/user.conf.template` | Template for user overrides (copy to ~/.tavs/) |
| `configure.sh` | Interactive configuration wizard (includes title mode setup) |
| `hooks/hooks.json` | Claude Code plugin hooks (14 hook routes) |

## User Configuration

All user settings are stored in `~/.tavs/user.conf`:

```
~/.tavs/
├── user.conf              # All user overrides (global + per-agent)
└── backgrounds/           # Background images (if enabled)
    ├── dark/
    └── light/
```

**Variable naming convention:**
- Global settings: `THEME_MODE`, `ENABLE_ANTHROPOMORPHISING`, etc.
- Per-agent overrides: `CLAUDE_DARK_BASE`, `GEMINI_FACES_PROCESSING`, etc.
- Default fallbacks: `DEFAULT_DARK_BASE`, `DEFAULT_LIGHT_BASE`, etc.
- Mode-aware colors: `CLAUDE_DARK_PROCESSING_PLAN`, `DEFAULT_LIGHT_PROCESSING_BYPASS`, etc.

**Run `./configure.sh`** to set up interactively, or copy `src/config/user.conf.template` to `~/.tavs/user.conf` and edit directly.

---

## Documentation Reference

| About | What You'll Find | Key Concepts | Read When |
|-------|------------------|--------------|-----------|
| [Architecture](docs/reference/architecture.md) | High-level system design showing how core modules connect to agent adapters. Explains the unified trigger system, OSC sequences, and how each CLI platform hooks into the core. | core-modules, agent-adapters, OSC-sequences, state-machine | Understanding how signals flow, adding new agent support, debugging cross-platform issues |
| [Agent Themes](docs/reference/agent-themes.md) | Per-agent customization of faces, colors, and backgrounds. Explains the directory structure, file formats, override priority, and how to create custom themes without modifying source files. | faces.conf, colors.conf, random-selection, user-overrides | Customizing agent appearance, adding new agent themes, understanding face selection |
| [Palette Theming](docs/reference/palette-theming.md) | Optional 16-color ANSI palette modification for cohesive terminal theming. Explains OSC 4 sequences, TrueColor limitations, theme presets, and how to enable for Claude Code. | OSC-4, ANSI-palette, TrueColor, 256-color-mode | Enabling palette theming, understanding why colors don't change in TrueColor mode |
| [Testing](docs/reference/testing.md) | Manual and automated testing procedures for visual signals. Covers terminal compatibility, hook verification, and debug mode for troubleshooting. | manual-testing, hook-verification, debug-mode, terminal-support | Verifying changes work, testing new installations, when signals don't appear |
| [Development Testing](docs/reference/development-testing.md) | Workflow for testing code changes live. How to update the plugin cache, test locally, and see changes reflected in Claude Code immediately. | plugin-cache, live-testing, development-workflow | Making code changes, testing modifications, deploying to plugin cache |
| [Troubleshooting](docs/troubleshooting/overview.md) | Quick fixes for common problems including terminal compatibility, plugin enablement, and hook installation issues. | quick-fixes, debug-mode, terminal-compatibility | When visual signals don't work, plugin shows disabled, colors are wrong |

---

## Terminal Title Mode

TAVS can control terminal tab titles with animated spinners during processing. Four modes are available:

| Mode | Description |
|------|-------------|
| `skip-processing` | **(Default)** Let Claude Code handle processing titles, TAVS handles others |
| `prefix-only` | Add face+status icon prefix while preserving user's tab names |
| `full` | TAVS owns all titles with animated spinner eyes in face |
| `off` | No title changes, only background colors/images |

### Prefix-Only Mode (Named Sessions)

Best for users who manually name their terminal tabs. TAVS adds a status prefix without losing your custom name.

**Example:** `My Project` becomes `Ǝ[• •]E 🟠 My Project` during processing.
With active subagents: `Ǝ[⇆ ⇆]E 🔀 +2 My Project`

1. Run `./configure.sh` and select "Prefix Only" in Step 6, OR
2. Add to `~/.tavs/user.conf`:
```bash
TAVS_TITLE_MODE="prefix-only"
TAVS_TITLE_FALLBACK="session-path"  # session-path|path-session|session|path

# Optional: Force a specific base title
# TAVS_TITLE_BASE="My Project"

# Optional: Customize format (default includes {AGENTS} and {SESSION_ICON})
# TAVS_TITLE_FORMAT="{FACE} {STATUS_ICON} {AGENTS} {SESSION_ICON} {BASE}"
# TAVS_AGENTS_FORMAT="+{N}"  # Format for subagent count ({N} = number)
```

**Fallback options** (when no user title is set):
- `path` - Current directory only: `~/projects`
- `session-path` - Session ID + path: `134eed79 ~/projects`
- `path-session` - Path + session ID: `~/projects 134eed79`
- `session` - Session ID only: `134eed79`

### Title Format Tokens

The `TAVS_TITLE_FORMAT` template supports these placeholders:

| Token | Description | Example |
|-------|-------------|---------|
| `{FACE}` | Agent face expression | `Ǝ[• •]E` |
| `{STATUS_ICON}` | State emoji | `🟠` |
| `{AGENTS}` | Active subagent count (empty when none) | `+2` |
| `{SESSION_ICON}` | Session icon (unique animal emoji per tab) | `🦊` |
| `{BASE}` | Base title (user-set or fallback) | `~/projects` |

The `{AGENTS}` token is formatted by `TAVS_AGENTS_FORMAT` (default: `+{N}`).
It only appears when subagents are active (count > 0).

The `{SESSION_ICON}` token requires `ENABLE_SESSION_ICONS="true"` (default).
Each terminal tab gets a unique animal emoji from a pool of 25, persisting across `/clear`.

### Enabling Full Title Mode

1. Run `./configure.sh` and select "Full" in Step 6, OR
2. Add to `~/.tavs/user.conf`:
```bash
TAVS_TITLE_MODE="full"
TAVS_SPINNER_STYLE="random"      # braille, circle, block, eye-animate, none, random
TAVS_SPINNER_EYE_MODE="random"   # sync, opposite, stagger, mirror, random
TAVS_SESSION_IDENTITY="true"     # Consistent visual identity per session
```

3. **Required for Claude Code:** Add to `~/.claude/settings.json`:
```json
{
  "env": {
    "CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1"
  }
}
```
Then restart Claude Code.

### Per-Agent Spinner Faces

Each agent's face style is preserved during spinner animations:

| Agent | Spinner Face | Example |
|-------|--------------|---------|
| Claude | `Ǝ[{L} {R}]E` | `Ǝ[⠋ ⠙]E` |
| Gemini | `ʕ{L}ᴥ{R}ʔ` | `ʕ⠋ᴥ⠙ʔ` |
| Codex | `ฅ^{L}ﻌ{R}^ฅ` | `ฅ^⠋ﻌ⠙^ฅ` |
| OpenCode | `({L}-{R})` | `(⠋-⠙)` |

The `{L}` and `{R}` placeholders are replaced with animated spinner characters.

### Compact Face Mode (Emoji Eyes)

Replaces text-based eyes with emoji. State info and subagent count are embedded directly in the face, producing a more information-dense title.

```
STANDARD:  Ǝ[• •]E 🟠 +2 🦊 ~/proj    (face + status icon + count + session icon + path)
COMPACT:   Ǝ[🟧 +2]E 🦊 ~/proj         (emoji eyes + count as right eye)
```

**Enable in `~/.tavs/user.conf`:**
```bash
TAVS_FACE_MODE="compact"           # "standard" (default) | "compact"
TAVS_COMPACT_THEME="semantic"      # "semantic" | "circles" | "squares" | "mixed"
```

| Theme | Style | Example |
|-------|-------|---------|
| semantic | Meaningful emoji per state | `🟧 🟠`, `✅ 🟢`, `❌ ⭕` |
| circles | Uniform round emoji | `🟠 🟠`, `🔴 🔴`, `🟢 🟢` |
| squares | Bold block emoji | `🟧 🟧`, `🟥 🟥`, `🟩 🟩` |
| mixed | Asymmetric pairs | `🟧 🟠`, `🟥 ⭕`, `✅ 🟢` |

In compact mode, `{STATUS_ICON}` and `{AGENTS}` tokens are auto-suppressed since that info is embedded in the face. The right eye becomes `+N` when subagents are active.

---

## Development Notes

### Plugin System (v2.0.0)

Bug #14410 (plugin hooks not executing) was fixed in Claude Code v2.1.9. The plugin now works natively via the marketplace.

**Current plugin version:** 2.0.0

```bash
# Install plugin
claude plugin marketplace add cstelmach/terminal-agent-visual-signals
claude plugin install tavs@terminal-agent-visual-signals

# Enable plugin
/plugin → select tavs
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
./src/core/trigger.sh subagent-start       # Golden-Yellow, increments counter
./src/core/trigger.sh subagent-stop        # Decrements counter, returns to processing
./src/core/trigger.sh tool_error           # Orange-Red, auto-returns after 1.5s
./src/core/trigger.sh processing new-prompt # Simulates UserPromptSubmit (resets counter)
./src/core/trigger.sh reset

# Test light mode explicitly
FORCE_MODE=light ./src/core/trigger.sh processing
FORCE_MODE=light ./src/core/trigger.sh reset

# Test mode-aware processing colors
TAVS_PERMISSION_MODE=plan ./src/core/trigger.sh processing          # Green-yellow
TAVS_PERMISSION_MODE=acceptEdits ./src/core/trigger.sh processing   # Barely warmer
TAVS_PERMISSION_MODE=bypassPermissions ./src/core/trigger.sh processing  # Reddish
./src/core/trigger.sh reset

# Test palette theming (requires 256-color mode)
ENABLE_PALETTE_THEMING=true COLORTERM= ./src/core/trigger.sh processing
ls --color=auto  # Check if ls colors match theme
./src/core/trigger.sh reset

# Check terminal capabilities
bash src/core/terminal-detection.sh test
```

### Deploy Changes to Plugin Cache

**IMPORTANT:** After making code changes, you must update the plugin cache for Claude Code to use them.

```bash
# Quick update: Copy all core files to plugin cache
CACHE="$HOME/.claude/plugins/cache/terminal-agent-visual-signals/tavs/2.0.0"
cp src/core/*.sh "$CACHE/src/core/" && cp src/config/*.conf "$CACHE/src/config/" 2>/dev/null
echo "Plugin cache updated - submit a prompt to test"
```

**Full update script:**
```bash
CACHE="$HOME/.claude/plugins/cache/terminal-agent-visual-signals/tavs/2.0.0"
REPO="/Users/cs/.claude/hooks/terminal-agent-visual-signals"
cp "$REPO/src/core/"*.sh "$CACHE/src/core/"
mkdir -p "$CACHE/src/config" && cp "$REPO/src/config/"*.conf "$CACHE/src/config/"
cp "$REPO/src/agents/claude/trigger.sh" "$CACHE/src/agents/claude/"
```

**Key locations:**
- Source repo: `/Users/cs/.claude/hooks/terminal-agent-visual-signals/`
- Plugin cache: `~/.claude/plugins/cache/terminal-agent-visual-signals/tavs/2.0.0/`
- User config: `~/.tavs/user.conf` (changes here work immediately)

See [Development Testing](docs/reference/development-testing.md) for the full workflow.

### Terminal Compatibility

| Terminal | OSC 4 (palette) | OSC 11 (bg) | OSC 1337 (images) | Title Detection |
|----------|-----------------|-------------|-------------------|-----------------|
| Ghostty | ✅ | ✅ | ❌ | State file* |
| iTerm2 | ✅ | ✅ | ✅ | OSC 1337 query |
| Kitty | ✅ | ✅ | ❌** | State file |
| WezTerm | ✅ | ✅ | ❌*** | State file |
| Terminal.app | ❌ | ❌ | ❌ | State file |

\* Ghostty requires `shell-integration-features = no-title` in config (see below).
\** Kitty uses its own image protocol, not OSC 1337.
\*** WezTerm has partial OSC 1337 support, but TAVS only uses OSC 1337 backgrounds on iTerm2.

**Note:** OSC 4 palette theming only affects applications using ANSI palette indices.
Claude Code uses TrueColor (24-bit RGB) by default, which bypasses the palette.

### Ghostty Shell Integration (Required for Titles)

Ghostty's shell integration automatically manages tab titles, which conflicts with TAVS.
**For TAVS title features to work**, you must disable Ghostty's title management.

**Add to your Ghostty config:**
```ini
# macOS: ~/Library/Application Support/com.mitchellh.ghostty/config
# Linux: ~/.config/ghostty/config

shell-integration-features = no-title
```

This disables ONLY title management while keeping:
- Cursor shape integration
- Sudo wrapping
- Other modern shell features

**Without this setting:** Ghostty will overwrite TAVS titles after every command.

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
**User overrides:** Add `CLAUDE_FACES_PROCESSING=('custom' 'faces')` to `~/.tavs/user.conf`

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

**Enable in `~/.tavs/user.conf`:**
```bash
ENABLE_STYLISH_BACKGROUNDS="true"
STYLISH_BACKGROUNDS_DIR="$HOME/.tavs/backgrounds"
```

**Generate sample images:**
```bash
./assets/backgrounds/generate-samples.sh ~/.tavs/backgrounds
```

This is a global setting - supported terminals show images, unsupported terminals automatically fall back to solid colors.

### Palette Theming (Optional)

TAVS can modify the terminal's 16-color ANSI palette for cohesive light/dark themes.
This affects shell prompts, `ls` output, `git status`, and other CLI tools.

**Enable in `~/.tavs/user.conf`:**
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
grep -A5 "tavs" ~/.claude/settings.json

# Verify signals work
./src/core/trigger.sh processing && sleep 2 && ./src/core/trigger.sh reset
```
