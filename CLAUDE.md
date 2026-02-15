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
# Configure with CLI (quick one-liners)
./tavs set theme nord              # Apply Nord theme
./tavs set title-mode full         # Full title control
./tavs set faces off               # Disable ASCII faces
./tavs status                      # Show current config with preview

# Full interactive setup
./tavs wizard

# Test visual signals
./tavs test --quick                # Quick 3-state test
./tavs test                        # Full 8-state cycle
./tavs test --terminal             # Show terminal capabilities

# Quick disable (run without visual signals)
TAVS_STATUS=false claude

# Install for other agents
./tavs install gemini              # Gemini CLI
./tavs install codex               # Codex CLI (limited)

# Build OpenCode plugin
cd src/agents/opencode && npm install && npm run build
```

---

## Supported Platforms

| Platform | Support | Installation |
|----------|---------|--------------|
| Claude Code | ✅ Full (14 hooks) | Plugin marketplace or manual |
| Gemini CLI | ✅ Full (8 events) | `./tavs install gemini` |
| OpenCode | ✅ Good (4 events) | npm package |
| Codex CLI | ⚠️ Limited (1 event) | `./tavs install codex` |

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
| `src/core/context-data.sh` | Context window data resolution for title tokens |
| `src/core/session-state.sh` | Session state tracking (current state, timer PID) |
| `src/core/idle-worker-background.sh` | Background process for graduated idle states |
| `src/core/palette-mode-helpers.sh` | Palette theming mode detection helpers |
| `src/agents/claude/statusline-bridge.sh` | Silent StatusLine bridge (context data siphon) |
| `src/config/defaults.conf` | **Single source of truth**: global settings + all agent colors/faces |
| `src/config/user.conf.template` | Template for user overrides (v3 format, organized sections) |
| `tavs` | CLI entry point: `./tavs set`, `./tavs status`, `./tavs wizard`, etc. |
| `src/cli/*.sh` | CLI subcommand implementations (set, status, theme, etc.) |
| `src/wizard/configure.sh` | Interactive 7-step configuration wizard |
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
- Per-state title formats: `TAVS_TITLE_FORMAT_PERMISSION`, `CLAUDE_TITLE_FORMAT_PERMISSION`, etc.

**Quick config:** `./tavs set theme nord`, `./tavs set faces off`
**Full wizard:** `./tavs wizard` (interactive 7-step setup)
**Manual edit:** Copy `src/config/user.conf.template` to `~/.tavs/user.conf` and edit directly.

---

## Documentation Reference

| About | What You'll Find | Key Concepts | Read When |
|-------|------------------|--------------|-----------|
| [Architecture](docs/reference/architecture.md) | High-level system design showing how core modules connect to agent adapters. Explains the unified trigger system, OSC sequences, and how each CLI platform hooks into the core. | core-modules, agent-adapters, OSC-sequences, state-machine | Understanding how signals flow, adding new agent support, debugging cross-platform issues |
| [Agent Themes](docs/reference/agent-themes.md) | Per-agent customization of faces, colors, and backgrounds. Explains the directory structure, file formats, override priority, and how to create custom themes without modifying source files. | faces.conf, colors.conf, random-selection, user-overrides | Customizing agent appearance, adding new agent themes, understanding face selection |
| [Palette Theming](docs/reference/palette-theming.md) | Optional 16-color ANSI palette modification for cohesive terminal theming. Explains OSC 4 sequences, TrueColor limitations, theme presets, and how to enable for Claude Code. | OSC-4, ANSI-palette, TrueColor, 256-color-mode | Enabling palette theming, understanding why colors don't change in TrueColor mode |
| [Testing](docs/reference/testing.md) | Manual and automated testing procedures for visual signals. Covers terminal compatibility, hook verification, and debug mode for troubleshooting. | manual-testing, hook-verification, debug-mode, terminal-support | Verifying changes work, testing new installations, when signals don't appear |
| [Development Testing](docs/reference/development-testing.md) | Workflow for testing code changes live. How to update the plugin cache, test locally, and see changes reflected in Claude Code immediately. | plugin-cache, live-testing, development-workflow | Making code changes, testing modifications, deploying to plugin cache |
| [Dynamic Titles](docs/reference/dynamic-titles.md) | Per-state title templates with context window awareness. Covers the 4-level fallback chain, all 15 context/metadata tokens, StatusLine bridge setup, icon scale customization, and the data fallback chain (bridge → transcript → empty). | per-state-formats, context-tokens, StatusLine-bridge, icon-scales | Setting up context data in titles, customizing per-state formats, understanding the fallback chain, configuring the StatusLine bridge |
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

1. Run `./tavs wizard` and select "Prefix Only" in Step 6, OR
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

The `TAVS_TITLE_FORMAT` template supports these core placeholders:

| Token | Description | Example |
|-------|-------------|---------|
| `{FACE}` | Agent face expression | `Ǝ[• •]E` |
| `{STATUS_ICON}` | State emoji | `🟠` |
| `{AGENTS}` | Active subagent count (empty when none) | `+2` |
| `{SESSION_ICON}` | Session icon (unique animal emoji per tab) | `🦊` |
| `{BASE}` | Base title (user-set or fallback) | `~/projects` |

**15 additional context & metadata tokens** are available for per-state formats:
`{CONTEXT_PCT}`, `{CONTEXT_FOOD}`, `{CONTEXT_ICON}`, `{CONTEXT_BAR_H}`, `{MODEL}`,
`{COST}`, `{DURATION}`, `{LINES}`, `{MODE}`, and more. These require the StatusLine
bridge for real-time data (falls back to transcript estimation, then empty).
See [Dynamic Titles Reference](docs/reference/dynamic-titles.md) for the full token list.

The `{AGENTS}` token is formatted by `TAVS_AGENTS_FORMAT` (default: `+{N}`).
The `{SESSION_ICON}` token requires `ENABLE_SESSION_ICONS="true"` (default).

### Per-State Title Formats

Each trigger state can have its own format string via a 4-level fallback chain
(agent+state → agent → state → global). By default, permission and idle states show
food emoji + context percentage, compacting shows percentage only. Other states fall
back to `TAVS_TITLE_FORMAT`.

**Example:** During permission requests, the title shows `Ǝ[° °]E 🔴 🧀50% ~/proj`.

See [Dynamic Titles Reference](docs/reference/dynamic-titles.md) for the full fallback
chain, all default formats, configuration examples, and the StatusLine bridge setup guide.

### Enabling Full Title Mode

1. Run `./tavs wizard` and select "Full" in Step 6, OR
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

Replaces text-based eyes with emoji for an information-dense title. By default, the face
is a **two-signal dashboard**: left eye = state color, right eye = context fill level.

```
STANDARD:  Ǝ[• •]E 🟠 +2 🦊 ~/proj    (face + status icon + count + session icon + path)
COMPACT:   Ǝ[🟧 🧀]E +2 🦊 ~/proj     (state + context eyes, count outside face)
RESET:     Ǝ[— —]E                     (em dash resting eyes)
```

**Enable in `~/.tavs/user.conf`:**
```bash
TAVS_FACE_MODE="compact"           # "standard" (default) | "compact"
TAVS_COMPACT_THEME="squares"       # "semantic" | "circles" | "squares" | "mixed"
TAVS_COMPACT_CONTEXT_EYE="true"    # "true" (default) | "false" to disable
TAVS_COMPACT_CONTEXT_STYLE="food"  # food, food_10, circle, block, block_max, braille, number, percent
```

| Theme | Style | Example |
|-------|-------|---------|
| squares | Bold block emoji (default) | `🟧 🟧`, `🟥 🟥`, `🟩 🟩` |
| semantic | Meaningful emoji per state | `🟧 🟠`, `✅ 🟢`, `❌ ⭕` |
| circles | Uniform round emoji | `🟠 🟠`, `🔴 🔴`, `🟢 🟢` |
| mixed | Asymmetric pairs | `🟧 🟠`, `🟥 ⭕`, `✅ 🟢` |

**Context eye** (right eye = context fill, enabled by default):
- `Ǝ[🟧 🧀]E` (processing at 50%), `Ǝ[🟥 🍔]E` (permission at 85%)
- Matching title token auto-suppressed (e.g., `{CONTEXT_FOOD}` hidden when food in eye)
- Subagent count (`+N`) moves to `{AGENTS}` token outside face
- No context data → graceful fallback to theme emoji (both eyes match)
- Disabled (`TAVS_COMPACT_CONTEXT_EYE="false"`) → original behavior restored

`{STATUS_ICON}` auto-suppressed (left eye embeds state). `{AGENTS}` shown when context
eye active, suppressed when disabled. See [Dynamic Titles](docs/reference/dynamic-titles.md).

---

## Development Notes

### Plugin System (v3.0.0)

Bug #14410 (plugin hooks not executing) was fixed in Claude Code v2.1.9. The plugin now works natively via the marketplace.

**Current plugin version:** 3.0.0

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
# Test each state (processing, permission, complete, idle, compacting, subagent, tool_error, reset)
for s in processing permission complete idle compacting subagent-start tool_error reset; do ./src/core/trigger.sh $s; done
./src/core/trigger.sh subagent-start       # Golden-Yellow, increments counter
./src/core/trigger.sh subagent-stop        # Decrements counter, returns to processing
./src/core/trigger.sh tool_error           # Orange-Red, auto-returns after 1.5s
./src/core/trigger.sh processing new-prompt # Simulates UserPromptSubmit (resets counter)

# Test light mode
FORCE_MODE=light ./src/core/trigger.sh processing && FORCE_MODE=light ./src/core/trigger.sh reset

# Test mode-aware processing colors
TAVS_PERMISSION_MODE=plan ./src/core/trigger.sh processing          # Green-yellow
TAVS_PERMISSION_MODE=bypassPermissions ./src/core/trigger.sh processing  # Reddish
./src/core/trigger.sh reset

# Test context tokens in title
TAVS_TITLE_FORMAT_PERMISSION="{FACE} {STATUS_ICON} {CONTEXT_FOOD} {CONTEXT_PCT} {BASE}" \
  ./src/core/trigger.sh permission && ./src/core/trigger.sh reset

# Test compact context eye
TAVS_FACE_MODE=compact ./src/core/trigger.sh processing   # Food emoji in right eye
TAVS_FACE_MODE=compact ./src/core/trigger.sh reset        # Em dash resting eyes

# Test StatusLine bridge (silent — no output expected)
echo '{"context_window":{"used_percentage":72}}' | ./src/agents/claude/statusline-bridge.sh

# Test palette theming (requires 256-color mode)
ENABLE_PALETTE_THEMING=true COLORTERM= ./src/core/trigger.sh processing
./src/core/trigger.sh reset

# Check terminal capabilities
bash src/core/terminal-detection.sh test
```

### Deploy Changes to Plugin Cache

**IMPORTANT:** After making code changes, you must update the plugin cache for Claude Code to use them. User config changes (`~/.tavs/user.conf`) take effect immediately — no sync needed.

```bash
# Quick sync using tavs CLI
./tavs sync

# Or manual copy:
CACHE=$(ls -d "$HOME/.claude/plugins/cache/terminal-agent-visual-signals/tavs/"* 2>/dev/null | tail -1)
cp src/core/*.sh "$CACHE/src/core/" && cp src/config/*.conf "$CACHE/src/config/" 2>/dev/null
echo "Plugin cache updated - submit a prompt to test"
```

**Key locations:**
- Source repo: `~/.claude/hooks/terminal-agent-visual-signals/`
- Plugin cache: `~/.claude/plugins/cache/terminal-agent-visual-signals/tavs/<version>/`
- User config: `~/.tavs/user.conf` (changes here work immediately)

See [Development Testing](docs/reference/development-testing.md) for the full workflow.

### Terminal Compatibility

See [Testing Reference](docs/reference/testing.md) for the full compatibility matrix and
terminal-specific setup (including Ghostty `shell-integration-features = no-title`).

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

**Theme Presets:** All presets include palettes — Catppuccin (4 variants), Nord, Dracula,
Solarized, Tokyo Night. Select with `./tavs theme <name>` or set `THEME_PRESET`.

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
