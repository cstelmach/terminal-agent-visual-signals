# TAVS - Terminal Agent Visual Signals

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-3.0.0-green.svg)](CHANGELOG.md)
[![Bash 3.2+](https://img.shields.io/badge/bash-3.2%2B-orange.svg)](#requirements)
[![Platforms](https://img.shields.io/badge/agents-Claude%20%7C%20Gemini%20%7C%20Codex%20%7C%20OpenCode-purple.svg)](#supported-platforms)

> Visual terminal feedback for AI coding sessions — background colors, tab titles, and faces that show you what's happening at a glance.

<!-- TODO: Replace with actual recording. Short loop (~10s) showing 3-4 tabs cycling through states. -->
<p align="center">
  <img src="assets/media/demo.gif" alt="TAVS demo — terminal tabs changing color as Claude Code processes, asks permission, and completes" width="720">
</p>

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

At scale, TAVS turns terminal chaos into a glanceable dashboard. Each tab's background
color and title icon tells you its state without switching — reducing the cognitive load
of tracking what every session is doing. Here's 20+ concurrent Claude Code sessions
during a real multi-project work session:

<!-- TODO: Replace with actual screen recording. Full-screen capture showing 20+ terminal tabs with different TAVS states. -->
<p align="center">
  <img src="assets/media/multisession.gif" alt="20+ concurrent Claude Code sessions with TAVS — each tab shows its state at a glance" width="720">
  <br>
  <em>20+ sessions, zero tab-switching needed to know what's happening.</em>
</p>

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

## Configuration — Four Ways

TAVS works in four tiers. Pick the one that fits you.

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
./tavs set face-mode compact    # Emoji eyes: Ǝ[🟧 🧀]E instead of Ǝ[• •]E 🟠
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
./tavs set                      # Lists all 28 settings with descriptions
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
Standard:  Ǝ[• •]E 🟠 +2 «🇩🇪|🦊» ~/project
Compact:   Ǝ[🟧 🧀]E +2 «🇩🇪|🦊» ~/project
```
Compact mode embeds the status icon into the left eye and context fill level
into the right eye. See [Compact Face Mode](#compact-face-mode) for details.

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

### 4. AI-Assisted Configuration (Claude Code Skill)

The `tavs-setup` skill lets your AI agent handle configuration for you — with
backup, preview, and verification at every step.

**Setup wizard** — guided first-time configuration:
> "tavs setup" or "set up visual signals"

**Config changes** — modify individual settings safely:
> "change my tavs theme to nord" or "tavs config"

**Profile management** — save and switch named configurations:
> "save my tavs config as a profile" or "tavs profile"

The skill automatically backs up `~/.tavs/user.conf` before changes, shows a
diff preview, applies via `tavs set` (for the 28 CLI aliases) or direct file
editing (for 50+ advanced raw variables like per-agent colors and faces), and
verifies with `tavs status`.

Profiles are stored in `~/.tavs/profiles/<name>.conf` and can be applied
additively — switching between "presentation", "coding", and "minimal" setups
with a single command.

The skill ships with the TAVS plugin and activates automatically in Claude Code.

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

## Terminal Title System

<!-- TODO: Replace with actual screenshot. Wide crop of a terminal tab bar showing multiple TAVS titles with faces, icons, and context data. -->
<p align="center">
  <img src="assets/media/titlebar.png" alt="TAVS title bar — multiple tabs with faces, session icons, and context percentages" width="720">
</p>

TAVS can control your terminal tab titles to show agent state, identity, and context
information. There are four title modes, three presets, and animated spinners.

### Title Modes

| Mode | What It Does | Best For |
|------|-------------|----------|
| `skip-processing` | **(Default)** TAVS sets titles for permission, complete, idle, etc. Claude Code handles processing titles. | Most users — minimal config |
| `prefix-only` | Adds a face + status prefix to your existing tab name. Your custom name is preserved. | Users who manually name tabs |
| `full` | TAVS owns all titles with animated spinner eyes during processing. | Power users, multi-terminal setups |
| `off` | No title changes. Background colors only. | Minimal visual footprint |

```bash
./tavs set title-mode full            # Enable full title control
./tavs set title-mode prefix-only     # Preserve your custom tab names
./tavs set title-mode off             # Disable titles entirely
```

#### Setting Up Full Title Mode

Full mode requires disabling Claude Code's built-in title management:

**Step 1:** Enable full mode in TAVS:
```bash
./tavs set title-mode full
```

**Step 2:** Disable Claude Code's title management — add to `~/.claude/settings.json`:
```json
{
  "env": {
    "CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1"
  }
}
```

**Step 3:** For Ghostty users, add to your Ghostty config:
```ini
shell-integration-features = no-title
```

**Step 4:** Restart Claude Code.

### Title Presets

Presets configure face mode + all per-state format strings in one command. They provide
ready-made title layouts optimized for different workflows.

```bash
./tavs set title-preset dashboard     # Text faces with info group
./tavs set title-preset compact       # Emoji eyes with guillemet identity
./tavs set title-preset compact_project_sorted  # Dir flag anchor + info guillemets
```

#### Dashboard Preset

Text-based faces with a parenthesized info group connected by `˙°`:

```
Ǝ[• •]E˙°(🟠|🧀|🇩🇪|🦊) +2 75% ~/proj  abc123de
│         │               │    │   │        └─ session ID
│         │               │    │   └─ base title
│         │               │    └─ context percentage
│         │               └─ subagent count
│         └─ info group: status | food | dir flag | session animal
└─ face (standard text eyes)
```

#### Compact Preset

Emoji-eye faces where left eye = state color, right eye = context food level:

```
Ǝ[🟧 🧀]E +2 «🇩🇪|🦊» abc123de ~/proj
│          │    │         │        └─ base title
│          │    │         └─ session ID
│          │    └─ guillemet identity (dir flag + session animal)
│          └─ subagent count
└─ face with emoji eyes (status + context)
```

#### Compact Project Sorted Preset

Dir flag as visual anchor, info group in guillemets, session ID before path:

```
🇩🇪 Ǝ[🟧 🧀]E «🦊|+2|75%» abc123de ~/proj
│   │          │               │        └─ base title
│   │          │               └─ session ID (first 8 chars)
│   │          └─ guillemet info: session animal | subagent count | context %
│   └─ face with emoji eyes (status + context food)
└─ directory flag (visual anchor — deterministic per cwd)
```

Empty tokens collapse cleanly — if there are no subagents, `«🦊|+2|75%»` becomes
`«🦊|75%»`. If no context data either, it becomes `«🦊»`.

### Animated Spinners

When `title-mode` is `full`, processing state shows animated spinner characters as
the face's eyes. Each agent's face frame is preserved:

| Agent | Spinner Face | Example |
|-------|--------------|---------|
| Claude | `Ǝ[{L} {R}]E` | `Ǝ[⠋ ⠙]E` |
| Gemini | `ʕ{L}ᴥ{R}ʔ` | `ʕ⠋ᴥ⠙ʔ` |
| Codex | `ฅ^{L}ﻌ{R}^ฅ` | `ฅ^⠋ﻌ⠙^ฅ` |
| OpenCode | `({L}-{R})` | `(⠋-⠙)` |

**Spinner styles:** `braille`, `circle`, `block`, `eye-animate`, `none`, `random`

**Eye sync modes:** `sync`, `opposite`, `stagger`, `mirror`, `clockwise`, `counter`

```bash
./tavs set spinner braille            # Braille dots: ⠋ ⠙ ⠹ ⠸ ⠼ ...
./tavs set spinner circle             # Unicode circles
./tavs set spinner block              # Block characters
./tavs set eye-mode opposite          # Left and right eyes animate in opposite phase
```

### Per-State Title Formats

Each trigger state can have its own title format string using a **4-level fallback chain**:

```
Level 1: {AGENT}_TITLE_FORMAT_{STATE}   →  CLAUDE_TITLE_FORMAT_PERMISSION
Level 2: {AGENT}_TITLE_FORMAT           →  CLAUDE_TITLE_FORMAT
Level 3: TAVS_TITLE_FORMAT_{STATE}      →  TAVS_TITLE_FORMAT_PERMISSION
Level 4: TAVS_TITLE_FORMAT              →  (global default)
```

Three states have per-state formats by default:

| State | Default Format | Example |
|-------|---------------|---------|
| Permission | `{FACE} {STATUS_ICON} {SESSION_ICON} {CONTEXT_FOOD}{CONTEXT_PCT} {BASE}` | `Ǝ[° °]E 🔴 «🇩🇪\|🦊» 🧀50% ~/proj` |
| Idle | `{FACE} {STATUS_ICON} {CONTEXT_FOOD}{CONTEXT_PCT} {SESSION_ICON} {BASE}` | `Ǝ[· ·]E 🟣 🌽45% «🇩🇪\|🦊» ~/proj` |
| Compacting | `{FACE} {STATUS_ICON} {CONTEXT_PCT} {BASE}` | `Ǝ[~ ~]E 🔄 83% ~/proj` |

All other states use the global format: `{FACE} {STATUS_ICON} {AGENTS} {SESSION_ICON} {BASE}`.

**Custom per-state formats** — add to `~/.tavs/user.conf`:
```bash
# Show context on processing too
TAVS_TITLE_FORMAT_PROCESSING="{FACE} {STATUS_ICON} {CONTEXT_FOOD}{CONTEXT_PCT} {AGENTS} {BASE}"

# Show cost on completion
TAVS_TITLE_FORMAT_COMPLETE="{FACE} {STATUS_ICON} {COST} {SESSION_ICON} {BASE}"

# Agent-specific: show model name during Claude permission
CLAUDE_TITLE_FORMAT_PERMISSION="{FACE} {STATUS_ICON} {CONTEXT_FOOD}{CONTEXT_PCT} {MODEL} {BASE}"
```

See [Dynamic Titles Reference](docs/reference/dynamic-titles.md) for the full token list
and fallback chain details.

### Prefix-Only Mode

Best for users who manually name their terminal tabs. TAVS adds a face + status prefix
without losing your custom name.

```
Your tab name: "My Project"
During processing: Ǝ[• •]E 🟠 «🇩🇪|🦊» My Project
With subagents:   Ǝ[⇆ ⇆]E 🔀 +2 «🇩🇪|🦊» My Project
```

```bash
./tavs set title-mode prefix-only
```

**Fallback options** when no user title is detected:

| Fallback | Format | Example |
|----------|--------|---------|
| `path` | Current directory | `~/projects` |
| `session-path` | Session ID + path | `134eed79 ~/projects` |
| `path-session` | Path + session ID | `~/projects 134eed79` |
| `session` | Session ID only | `134eed79` |

```bash
# In ~/.tavs/user.conf
TAVS_TITLE_FALLBACK="session-path"
```

---

## Session Identity

TAVS assigns deterministic visual identifiers to each terminal session, making tabs
instantly recognizable even with many sessions open.

### Identity Modes

| Mode | Session Icon | Dir Icon | Format | Pool |
|------|-------------|----------|--------|------|
| `dual` (default) | Animal per session_id | Flag per working directory | `«🇩🇪\|🦊»` | 77 animals, 190 flags |
| `single` | Animal per session_id | None | `🦊` | 77 animals |
| `off` | Random per TTY (legacy) | None | `🐸` | 25 animals |

```bash
./tavs set identity-mode dual         # Full identity (default)
./tavs set identity-mode single       # Session animal only
./tavs set identity-mode off          # Legacy random per-TTY
```

### How It Works

- **Session icon (animal):** Assigned deterministically per Claude Code `session_id`
  via round-robin. The same session always gets the same animal, even across `/clear`.
- **Dir icon (flag):** Assigned deterministically per working directory. The same
  project directory always shows the same flag.
- Both icons persist for the session lifetime and are released on session end.

```
Session start:  Ǝ[• •]E ⚪ «🇩🇪|🦊» ~/my-project      (animal + flag assigned)
Processing:     Ǝ[• •]E 🟠 «🇩🇪|🦊» ~/my-project      (same icons throughout)
New prompt in different dir:  Ǝ[• •]E 🟠 «🇯🇵|🦊» ~/other-project  (flag changes, animal stays)
Session end:    Ǝ[— —]E ⚪ ~/my-project                  (icons released)
```

### Dir Icon Types

In dual mode, you can choose different emoji pools for directory icons:

| Type | Pool Size | Example | Sample Icons |
|------|-----------|---------|--------------|
| `flags` (default) | 190 | `«🇩🇪\|🦊»` | 🇺🇸 🇬🇧 🇯🇵 🇫🇷 🇩🇪 🇧🇷 🇰🇷 🇮🇹 |
| `plants` | 26 | `«🌲\|🦊»` | 🌳 🌴 🌵 🌲 🌸 🌺 🪴 🎋 |
| `buildings` | 24 | `«🏢\|🦊»` | 🏠 🏡 🏢 🏰 🏭 ⛪ 🕌 🗼 |
| `auto` | varies | auto-detect | Falls back to flags |

```bash
./tavs set dir-icon-type plants       # Use plant emoji for directories
./tavs set dir-icon-type buildings    # Use building emoji for directories
```

### Worktree Detection

When working in a git worktree, TAVS shows both the main repo flag and the worktree
flag with an arrow:

```
Main repo:      «🇩🇪|🦊» ~/my-project
Git worktree:   «🇩🇪→🇯🇵|🦊» ~/my-project/.claude/worktrees/feature-x
```

This helps distinguish which worktree you're in at a glance.

### Collision Handling

When two concurrent sessions happen to get the same animal (unlikely with a pool of 77),
both sessions display a 2-icon pair to stay distinguishable:

```
Session A: «🇩🇪|🦊🐙» ~/project-a    (primary + overflow icon)
Session B: «🇫🇷|🦊🐙» ~/project-b    (same pair, different dir flag)
```

### Persistence

```bash
./tavs set identity-persistence ephemeral    # (Default) Icons in /tmp, cleared on reboot
./tavs set identity-persistence persistent   # Icons in ~/.cache/tavs, survive reboots
```

---

## Compact Face Mode

Compact mode replaces text-based face eyes with emoji, creating an information-dense
title where the face itself conveys state and context.

### Standard vs Compact

```
STANDARD:  Ǝ[• •]E 🟠 +2 «🇩🇪|🦊» ~/proj    (face + status + count + identity + path)
COMPACT:   Ǝ[🟧 🧀]E +2 «🇩🇪|🦊» ~/proj     (state + context in eyes, count outside)
RESET:     Ǝ[— —]E                              (em dash resting eyes)
```

```bash
./tavs set face-mode compact          # Enable compact mode
./tavs set face-mode standard         # Back to text eyes
```

### Compact Themes

Four themes control which emoji appear in the face eyes:

| Theme | Style | Processing | Permission | Complete | Tool Error |
|-------|-------|-----------|-----------|---------|------------|
| `squares` (default) | Bold block emoji | `Ǝ[🟧 🟧]E` | `Ǝ[🟥 🟥]E` | `Ǝ[🟩 🟩]E` | `Ǝ[🟧 🟧]E` |
| `semantic` | Meaningful emoji | `Ǝ[🟠 🟠]E` | `Ǝ[🔴 🔴]E` | `Ǝ[✅ ✅]E` | `Ǝ[❌ ❌]E` |
| `circles` | Round emoji | `Ǝ[🟠 🟠]E` | `Ǝ[🔴 🔴]E` | `Ǝ[🟢 🟢]E` | `Ǝ[🔴 🔴]E` |
| `mixed` | Asymmetric pairs | `Ǝ[🟧 🟠]E` | `Ǝ[🟥 ⭕]E` | `Ǝ[✅ 🟢]E` | `Ǝ[❌ ⭕]E` |

```bash
./tavs set compact-theme squares      # Bold blocks (default)
./tavs set compact-theme semantic     # Meaningful emoji per state
```

### Context Eye (Two-Signal Dashboard)

By default, the face is a **two-signal dashboard**: left eye = state color, right eye =
context window fill level. This turns the face into a real-time indicator of both what
the agent is doing and how much context is used.

```
Ǝ[🟧 💧]E   processing, context at 0% (fresh session)
Ǝ[🟧 🧀]E   processing, context at 50% (halfway)
Ǝ[🟥 🍔]E   permission needed, context at 85% (danger zone!)
Ǝ[🟩 🌽]E   complete, context at 45%
Ǝ[— —]E     reset — em dash resting eyes
```

**Context eye styles** — choose how the right eye visualizes context fill:

| Style | 0% | 25% | 50% | 75% | 100% |
|-------|----|-----|-----|-----|------|
| `food` (default) | `💧` | `🥝` | `🧀` | `🍕` | `🍫` |
| `food_10` | `💧` | `🥦` | `🧀` | `🌮` | `🍫` |
| `circle` | `⚪` | `🔵` | `🟡` | `🔴` | `⚫` |
| `block` | `▁` | `▂` | `▄` | `▆` | `█` |
| `braille` | `⠀` | `⠄` | `⠤` | `⠷` | `⠿` |
| `number` | `0️⃣` | `2️⃣` | `5️⃣` | `7️⃣` | `🔟` |
| `percent` | `0%` | `25%` | `50%` | `75%` | `100%` |

```bash
./tavs set compact-context-style food     # Food emoji (default)
./tavs set compact-context-style circle   # Color circles
./tavs set compact-context-eye false      # Disable context eye (both eyes show state)
```

### Per-Agent Face Frames

Each agent's face frame wraps the same two-signal pattern:

| Agent | Processing at 50% | Reset |
|-------|-------------------|-------|
| Claude | `Ǝ[🟧 🧀]E` | `Ǝ[— —]E` |
| Gemini | `ʕ🟧ᴥ🧀ʔ` | `ʕ—ᴥ—ʔ` |
| Codex | `ฅ^🟧ﻌ🧀^ฅ` | `ฅ^—ﻌ—^ฅ` |
| OpenCode | `(🟧-🧀)` | `(—-—)` |

### Subagent Count in Compact Mode

When the context eye is active (default), the subagent count (`+N`) moves outside
the face to the `{AGENTS}` title token. When context eye is off, subagent count
goes into the right eye:

| Mode | Face | Title |
|------|------|-------|
| Context eye ON + 2 subagents | `Ǝ[🟧 🧀]E` | `Ǝ[🟧 🧀]E +2 «🇩🇪\|🦊» ~/proj` |
| Context eye OFF + 2 subagents | `Ǝ[🟧 +2]E` | `Ǝ[🟧 +2]E «🇩🇪\|🦊» ~/proj` |

### Automatic Token Suppression

When context eye is active, the matching `{CONTEXT_*}` token is automatically suppressed
from the title format to avoid showing the same info twice. For example, with `food` style
the `{CONTEXT_FOOD}` token resolves to empty — but `{CONTEXT_PCT}` still shows:

```
Context eye ON (food):   Ǝ[🟥 🧀]E 50% ~/proj     ← food only in eye, pct in title
Context eye OFF:         Ǝ[🟥 🟥]E 🧀50% ~/proj   ← food in title
```

---

## Context-Aware Titles

TAVS can display real-time context window data in terminal titles — showing how much of
the agent's context window is used, what model is active, session cost, and more.

### Context Tokens

Use these tokens in title format strings:

**Context window display** — visualize the context fill percentage:

| Token | Description | 0% | 50% | 100% |
|-------|-------------|-----|-----|------|
| `{CONTEXT_PCT}` | Percentage | `0%` | `50%` | `100%` |
| `{CONTEXT_FOOD}` | Food emoji (21 stages) | `💧` | `🧀` | `🍫` |
| `{CONTEXT_FOOD_10}` | Food emoji (11 stages) | `💧` | `🧀` | `🍫` |
| `{CONTEXT_ICON}` | Color circles | `⚪` | `🟡` | `⚫` |
| `{CONTEXT_BAR_H}` | Horizontal bar (5 char) | `░░░░░` | `▓▓░░░` | `▓▓▓▓▓` |
| `{CONTEXT_BAR_V}` | Vertical block | `▁` | `▄` | `█` |
| `{CONTEXT_BRAILLE}` | Braille fill | `⠀` | `⠤` | `⠿` |
| `{CONTEXT_NUMBER}` | Number emoji | `0️⃣` | `5️⃣` | `🔟` |

**Session metadata:**

| Token | Source | Example |
|-------|--------|---------|
| `{MODEL}` | Active model name | `Opus` |
| `{COST}` | Session cost | `$0.42` |
| `{DURATION}` | Session duration | `5m32s` |
| `{LINES}` | Lines added | `+156` |
| `{MODE}` | Permission mode | `plan` |

**Identity:**

| Token | Example | Requires |
|-------|---------|----------|
| `{SESSION_ICON}` | `🦊` | Identity mode != `off` |
| `{DIR_ICON}` | `🇩🇪` | Identity mode = `dual` |
| `{SESSION_ID}` | `abc123de` | Claude Code |
| `{FACE}` | `Ǝ[• •]E` | Faces enabled |
| `{STATUS_ICON}` | `🟠` | Always available |
| `{AGENTS}` | `+2` | Active subagents |
| `{BASE}` | `~/project` | Always available |

### Data Sources — Fallback Chain

Context tokens get their data through a three-tier fallback:

```
1. StatusLine bridge (real-time, accurate)
   → Reads Claude Code's StatusLine JSON
   → Provides context %, model, cost, duration, lines

2. Transcript estimation (approximate)
   → Parses JSONL transcript for actual token counts
   → Per-agent context window sizing (200k Claude, 1M Gemini)
   → No external dependencies

3. Empty/default (session start)
   → Context defaults to 0%
   → Metadata tokens resolve to empty (collapsed by space cleanup)
```

### Setting Up the StatusLine Bridge

The StatusLine bridge provides real-time context data. It's a silent script that reads
Claude Code's StatusLine JSON and writes a state file — no stdout output.

**Step 1:** Create `~/.claude/statusline.sh`:

```bash
#!/bin/bash
input=$(cat)
# TAVS bridge — silent, no output
echo "$input" | ~/.claude/plugins/cache/terminal-agent-visual-signals/tavs/*/src/agents/claude/statusline-bridge.sh
# Your statusline output (optional — this is what Claude Code displays):
echo "$input" | jq -r '"[\(.model.display_name)] \(.context_window.used_percentage // 0)%"'
```

**Step 2:** Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "command": "bash ~/.claude/statusline.sh"
  }
}
```

**Step 3:** Restart Claude Code. Context tokens will now show real-time data in titles.

The bridge coexists with your existing statusline — your script captures stdin first,
then pipes a copy to the bridge. Both work independently.

**Verify the bridge is working:**
```bash
# Should produce zero output (bridge is silent)
echo '{"context_window":{"used_percentage":72}}' \
  | ./src/agents/claude/statusline-bridge.sh

# Check state file was written
cat ~/.cache/tavs/context.* 2>/dev/null
```

### Customizing Icon Scales

Override any icon array in `~/.tavs/user.conf`:

```bash
# Custom food scale
TAVS_CONTEXT_FOOD_21=("🌱" "🌿" "🍃" "🌾" "🥬" "🥦" "🥒" "🥗" "🥝" "🥑" "🍋" "🍌" "🌽" "🧀" "🍞" "🌮" "🍕" "🍔" "🍟" "🍩" "🔥")

# Custom color circles
TAVS_CONTEXT_CIRCLES_11=("⬜" "🟦" "🟦" "🟩" "🟩" "🟨" "🟧" "🟧" "🟥" "🟥" "⬛")
```

---

## Mode-Aware Processing

When enabled (default), the processing background color shifts subtly based on Claude
Code's current permission mode. This gives you a visual hint of what mode you're in
without checking the status bar.

| Mode | Color Shift | Description |
|------|-------------|-------------|
| `default` | Standard orange | Normal processing |
| `plan` | Green-yellow tinge | Plan mode (read-only, thinking) |
| `acceptEdits` | Barely warmer | Auto-approve edits mode |
| `dontAsk` | Same as acceptEdits | Auto-approve all |
| `bypassPermissions` | Reddish tinge | Dangerous mode (all bypassed) |

The color shifts are subtle — you'll notice them when switching modes but they won't
distract during normal work.

**Test mode-aware colors:**
```bash
TAVS_PERMISSION_MODE=plan ./src/core/trigger.sh processing
./src/core/trigger.sh reset

TAVS_PERMISSION_MODE=bypassPermissions ./src/core/trigger.sh processing
./src/core/trigger.sh reset
```

**Disable if not wanted:**
```bash
# In ~/.tavs/user.conf
ENABLE_MODE_AWARE_PROCESSING="false"
```

---

## ASCII Faces & Agent Identity

Each AI agent has its own face style with random eye variants selected per trigger.
This gives agents personality while maintaining consistent brand identity.

| Agent | Face Style | Processing | Permission | Complete | Subagent | Variants |
|-------|------------|-----------|-----------|---------|----------|----------|
| Claude Code | Pincer | `Ǝ[• •]E` | `Ǝ[° °]E` | `Ǝ[◠ ◠]E` | `Ǝ[⇆ ⇆]E` | 6 per state |
| Gemini CLI | Bear | `ʕ•ᴥ•ʔ` | `ʕ°ᴥ°ʔ` | `ʕ◠ᴥ◠ʔ` | `ʕ⇆ᴥ⇆ʔ` | 1 per state |
| OpenCode | Kaomoji | `(°-°)` | `(°□°)` | `(^‿^)` | `(⇆-⇆)` | 1 per state |
| Codex CLI | Cat | `ฅ^•ﻌ•^ฅ` | `ฅ^°ﻌ°^ฅ` | `ฅ^◠ﻌ◠^ฅ` | `ฅ^⇆ﻌ⇆^ฅ` | 1 per state |

Claude's faces have multiple variants per state — each trigger randomly picks one,
so you'll see different eyes on each state change.

### Reset Face Distinction

Session start and session end show different faces:

| Event | Face | Purpose |
|-------|------|---------|
| Session start | `Ǝ[• •]E ⚪` | Fresh session — inviting, standard eyes |
| Session end | `Ǝ[— —]E ⚪` | Session closing — muted, em dash eyes |

### Idle Faces (Graduated)

After completion, faces gradually become sleepier through 6 stages:

```
Stage 0: Ǝ[• •]E    alert after completion
Stage 1: Ǝ[· ·]E    content
Stage 2: Ǝ[- -]E    relaxed
Stage 3: Ǝ[~ ~]E    drowsy
Stage 4: Ǝ[_ _]E zZ  sleepy
Stage 5: Ǝ[_ _]E ᶻᶻ  deep sleep
```

### Customizing Faces

Override faces in `~/.tavs/user.conf`:

```bash
# Custom Claude processing faces
CLAUDE_FACES_PROCESSING=('Ǝ[★ ★]E' 'Ǝ[✦ ✦]E' 'Ǝ[◆ ◆]E')

# Custom Gemini permission face
GEMINI_FACES_PERMISSION=('ʕ⊙ᴥ⊙ʔ')

# Disable faces entirely
ENABLE_ANTHROPOMORPHISING="false"
```

See [Agent Themes Reference](docs/reference/agent-themes.md) for the full customization guide.

---

## Background Images

Supported terminals (iTerm2, Kitty) can show background images per state instead of
solid colors.

| Terminal | Support | Method |
|----------|---------|--------|
| iTerm2 | Full | OSC 1337 (requires enabling in preferences) |
| Kitty | Full | `kitten @` remote control (`allow_remote_control=yes`) |
| Others | Fallback | Solid colors via OSC 11 |

**Enable:**
```bash
# In ~/.tavs/user.conf
ENABLE_STYLISH_BACKGROUNDS="true"
STYLISH_BACKGROUNDS_DIR="$HOME/.tavs/backgrounds"
```

**Generate sample images:**
```bash
./assets/backgrounds/generate-samples.sh ~/.tavs/backgrounds
```

**iTerm2 prerequisite:** iTerm2 → Preferences → Profiles → (your profile) → Window →
enable "Background Image" (can leave path empty). Without this, OSC 1337 background
commands are silently ignored.

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

## Testing

### Quick Tests

```bash
./tavs test --quick             # 3-state quick test (processing → complete → reset)
./tavs test                     # Full 8-state visual cycle
./tavs test --terminal          # Show terminal capabilities (OSC support)
```

### Manual State Testing

```bash
# Test each state individually
./src/core/trigger.sh processing       # Orange background
./src/core/trigger.sh permission       # Red background
./src/core/trigger.sh complete         # Green background
./src/core/trigger.sh idle             # Purple background
./src/core/trigger.sh compacting       # Teal background
./src/core/trigger.sh subagent-start   # Golden-Yellow (increments counter)
./src/core/trigger.sh subagent-stop    # Decrements counter
./src/core/trigger.sh tool_error       # Orange-Red (auto-returns after 1.5s)
./src/core/trigger.sh reset            # Reset to default

# Test light mode
FORCE_MODE=light ./src/core/trigger.sh processing
FORCE_MODE=light ./src/core/trigger.sh reset
```

### Automated Test Suites

The `tests/` directory contains bash-based automated test suites:

| Suite | Tests | Covers |
|-------|-------|--------|
| `tests/test-context-data.sh` | 107 | Context token resolvers, icon lookups, edge cases |
| `tests/test-per-state-titles.sh` | 50 | Per-state format selection, 4-level fallback chain |
| `tests/test-statusline-bridge.sh` | 47 | StatusLine bridge silence, atomic writes, JSON extraction |
| `tests/test-transcript-fallback.sh` | 45 | Transcript estimation, JSONL parsing |
| `tests/test-integration-phase6.sh` | 94 | End-to-end: trigger → title output with context data |

```bash
# Run all test suites
for t in tests/test-*.sh; do bash "$t"; done

# Run a specific suite with verbose output
DEBUG=1 bash tests/test-context-data.sh
```

### Debug Mode

Enable detailed logging for any trigger:

```bash
export DEBUG_ALL=1
./src/core/trigger.sh processing
# Logs saved to: debug/
```

See [Testing Reference](docs/reference/testing.md) for the full verification checklist
and terminal compatibility matrix.

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

**What's the difference between compact face mode and standard?**
Standard mode shows text eyes in the face (`Ǝ[• •]E`) with status info as separate
tokens. Compact mode uses emoji eyes (`Ǝ[🟧 🧀]E`) where the left eye = state color and
right eye = context fill level. See [Compact Face Mode](#compact-face-mode).

**How do I get context percentage in the title?**
Set up the [StatusLine bridge](#setting-up-the-statusline-bridge). Without it, TAVS
estimates from the transcript file. See [Context-Aware Titles](#context-aware-titles).

**What do the food emoji mean?**
They represent context window fill level — from `💧` (0%, empty) through `🧀` (50%,
halfway) to `🍫` (100%, full). Higher = more context used. The scale has 21 stages at
5% increments.

**Can I use different title formats for different states?**
Yes. Use per-state format variables like `TAVS_TITLE_FORMAT_PERMISSION` or agent-specific
ones like `CLAUDE_TITLE_FORMAT_COMPLETE`. See [Per-State Title Formats](#per-state-title-formats).

**How do session icons work?**
Each Claude Code session gets a deterministic animal emoji (🦊, 🐙, etc.) and each
working directory gets a flag emoji (🇩🇪, 🇯🇵, etc.). These are consistent — same session
always shows the same animal. See [Session Identity](#session-identity).

**I see `«🇩🇪|🦊»` in my title — what does that mean?**
That's dual identity mode. `🇩🇪` is your directory flag (deterministic per working
directory) and `🦊` is your session animal (deterministic per session). The guillemets
(`« »`) wrap both with a pipe separator.

---

## Documentation

For detailed reference material beyond this README:

| About | What You'll Find | Key Concepts | Read When |
|-------|------------------|--------------|-----------|
| [Architecture](docs/reference/architecture.md) | High-level system design showing how core modules connect to agent adapters. Explains the unified trigger system, OSC sequences, state machine, and data flow from hooks to terminal. | core-modules, agent-adapters, OSC-sequences, state-machine | Understanding how signals flow, adding new agent support, debugging cross-platform issues |
| [Agent Themes](docs/reference/agent-themes.md) | Per-agent customization of faces, colors, and backgrounds. Explains the variable naming convention, override priority, and how to create custom themes without modifying source files. | faces, colors, overrides, per-agent | Customizing agent appearance, adding new agent themes, understanding face selection |
| [Dynamic Titles](docs/reference/dynamic-titles.md) | Per-state title formats, context tokens, title presets, and StatusLine bridge setup. Full token reference with examples at every context level, fallback chain details, and icon scale customization. | per-state-formats, context-tokens, StatusLine-bridge, presets | Customizing title content per state, setting up the bridge, switching presets, understanding the data fallback chain |
| [Palette Theming](docs/reference/palette-theming.md) | Optional 16-color ANSI palette modification for cohesive terminal theming. Explains OSC 4 sequences, TrueColor limitations, theme presets, and how to enable for Claude Code. | OSC-4, ANSI-palette, TrueColor, 256-color-mode | Enabling palette theming, understanding why colors don't change in TrueColor mode |
| [Testing](docs/reference/testing.md) | Manual and automated testing procedures, terminal compatibility matrix, and verification checklist. Covers all states, identity, compact mode, context tokens, and bridge testing. | manual-testing, automated-suites, verification-checklist | Verifying changes work, testing new installations, debugging visual issues |
| [Development Testing](docs/reference/development-testing.md) | Workflow for testing code changes live. How to update the plugin cache, test locally, and see changes reflected in Claude Code immediately. | plugin-cache, live-testing, development-workflow | Making code changes, testing modifications, deploying updates |
| [Troubleshooting](docs/troubleshooting/overview.md) | Quick fixes for 27 common problems including terminal compatibility, plugin enablement, hook installation, spinner issues, identity problems, and context token debugging. | quick-fixes, debug-mode, terminal-compatibility | When visual signals don't work, plugin shows disabled, colors are wrong, titles missing |

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
