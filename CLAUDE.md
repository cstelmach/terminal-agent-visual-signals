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
| `src/core/theme.sh` | Colors, toggles, config loader |
| `src/core/backgrounds.sh` | Stylish background images (iTerm2/Kitty) |
| `src/core/detect.sh` | Terminal type and dark mode detection |
| `src/core/themes.sh` | ASCII face themes library |
| `src/config/global.conf` | Default configuration |
| `configure.sh` | Interactive configuration wizard |
| `hooks/hooks.json` | Claude Code plugin hooks |

## User Configuration

All user settings are stored in `~/.terminal-visual-signals/`:

```
~/.terminal-visual-signals/
├── user.conf              # User configuration overrides
└── backgrounds/           # Background images (if enabled)
    ├── dark/              # Dark mode images
    └── light/             # Light mode images
```

**Run `./configure.sh`** to set up interactively, or edit `user.conf` directly.

---

## Documentation Reference

| About | What You'll Find | Key Concepts | Read When |
|-------|------------------|--------------|-----------|
| [Architecture](docs/reference/architecture.md) | High-level system design showing how core modules connect to agent adapters. Explains the unified trigger system, OSC sequences, and how each CLI platform hooks into the core. | core-modules, agent-adapters, OSC-sequences, state-machine | Understanding how signals flow, adding new agent support, debugging cross-platform issues |
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
```

### Face Themes

Available themes: `minimal`, `bear`, `cat`, `lenny`, `shrug`, `plain`, `claudA`-`claudF`

Default: `claudA` with anthropomorphising enabled.

### Stylish Backgrounds (Images)

Background images per state, with automatic fallback:

| Terminal | Support | Implementation |
|----------|---------|----------------|
| iTerm2 | ✅ Full | OSC 1337 protocol |
| Kitty | ✅ Full | Remote control API (requires `allow_remote_control=yes`) |
| Others | ○ Fallback | Solid colors via OSC 11 |

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
