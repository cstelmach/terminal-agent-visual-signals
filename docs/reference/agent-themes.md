# Agent-Specific Theming

## Overview

Each CLI agent (Claude Code, Gemini, OpenCode, Codex) has its own visual identity through agent-specific face themes, colors, and background images. Faces are randomly selected from a pool on each trigger, giving agents personality while maintaining consistent brand identity.

## Agent Theme Assignments

| Agent | Face Style | Processing | Subagent | Tool Error | Variants |
|-------|------------|------------|----------|------------|----------|
| Claude Code | Pincer | `Ǝ[• •]E` | `Ǝ[⇆ ⇆]E` | `Ǝ[✕ ✕]E` | 6 per state |
| Gemini CLI | Bear | `ʕ•ᴥ•ʔ` | `ʕ⇆ᴥ⇆ʔ` | `ʕ✕ᴥ✕ʔ` | 1 per state |
| OpenCode | Minimal kaomoji | `(°-°)` | `(⇆-⇆)` | `(✕_✕)` | 1 per state |
| Codex CLI | Cat | `ฅ^•ﻌ•^ฅ` | `ฅ^⇆ﻌ⇆^ฅ` | `ฅ^✕ﻌ✕^ฅ` | 1 per state |

## Directory Structure

### Source Defaults

```
src/agents/
├── claude/
│   ├── data/
│   │   ├── faces.conf          # Face arrays per state
│   │   ├── colors.conf         # Optional color overrides
│   │   └── backgrounds/
│   │       ├── dark/           # Dark mode images
│   │       │   ├── processing.png
│   │       │   ├── permission.png
│   │       │   ├── complete.png
│   │       │   ├── idle.png
│   │       │   ├── compacting.png
│   │       │   └── reset.png
│   │       └── light/          # Light mode images
│   ├── hooks.json
│   └── trigger.sh
├── gemini/
│   └── data/...
├── opencode/
│   └── data/...
└── codex/
    └── data/...
```

### User Overrides

User customizations go in `~/.tavs/agents/`:

```
~/.tavs/
├── user.conf                   # Global settings
└── agents/
    ├── claude/
    │   ├── faces.conf          # Override Claude faces
    │   ├── colors.conf         # Override Claude colors
    │   └── backgrounds/        # Override Claude images
    │       ├── dark/
    │       └── light/
    ├── gemini/
    ├── opencode/
    └── codex/
```

**Override priority:** User agent override → Source agent data → Fallback

## Face Configuration

### File Format

Faces are defined as bash arrays in `faces.conf`:

```bash
#!/bin/bash
# Example: src/agents/claude/data/faces.conf

# Processing state - one face randomly selected per trigger
FACES_PROCESSING=(
    'Ǝ[• •]E'    # variant 1
    'Ǝ[• ◕]E'    # variant 2
    'Ǝ[■ ■]E'    # variant 3
)

# Permission state
FACES_PERMISSION=(
    'Ǝ[° °]E'
    'Ǝ[○ ○]E'
)

# Complete state
FACES_COMPLETE=(
    'Ǝ[✦ ✦]E'
    'Ǝ[★ ★]E'
)

# Subagent state - parallel/arrow indicators
FACES_SUBAGENT=(
    'Ǝ[⇆ ⇆]E'
    'Ǝ[↔ ↔]E'
    'Ǝ[⟺ ⟺]E'
)

# Tool error state - X-mark variants
FACES_TOOL_ERROR=(
    'Ǝ[✕ ✕]E'
    'Ǝ[× ×]E'
    'Ǝ[✗ ✗]E'
)

# ... arrays for: compacting, reset, idle_0 through idle_5
```

### Supported States

Each agent defines face arrays for these 13 states:

| Array Name | State | Expression Type |
|------------|-------|-----------------|
| `FACES_PROCESSING` | Working | Focused |
| `FACES_PERMISSION` | Needs approval | Alert |
| `FACES_COMPLETE` | Finished | Happy |
| `FACES_COMPACTING` | Compressing context | Busy |
| `FACES_SUBAGENT` | Subagent spawned | Parallel/arrows |
| `FACES_TOOL_ERROR` | Tool execution failed | X-marks/error |
| `FACES_RESET` | Neutral | Resting |
| `FACES_IDLE_0` | Alert after completion | Attentive |
| `FACES_IDLE_1` | Content | Relaxed |
| `FACES_IDLE_2` | More relaxed | Calm |
| `FACES_IDLE_3` | Drowsy | Sleepy |
| `FACES_IDLE_4` | Sleepy (with zZ) | Dozing |
| `FACES_IDLE_5` | Deep sleep (with ᶻᶻ) | Sleeping |

### Random Selection

Each trigger randomly selects one face from the array:

```bash
# Multiple triggers may show different faces:
Ǝ[• •]E  →  Ǝ[■ ■]E  →  Ǝ[• ◕]E  →  Ǝ[• •]E
```

Single-item arrays (Gemini, OpenCode, Codex) always show the same face.

## Color Configuration

### File Format

Colors are optional overrides in `colors.conf`:

```bash
#!/bin/bash
# Example: ~/.tavs/agents/claude/colors.conf

# Dark mode overrides
DARK_PROCESSING="#473D2F"
DARK_PERMISSION="#4A2021"
DARK_COMPLETE="#2D4A3D"
DARK_IDLE="#443147"
DARK_COMPACTING="#2B4645"

# Light mode overrides
LIGHT_PROCESSING="#F5E0D0"
LIGHT_PERMISSION="#F5D0D0"
LIGHT_COMPLETE="#D0F0E0"
LIGHT_IDLE="#E8E0F0"
LIGHT_COMPACTING="#D8F0F0"

# OR: Uniform colors (ignore dark/light mode)
UNIFORM_PROCESSING="#FF8C00"
```

### Resolution Priority

1. Agent-specific color (if defined)
2. Global config color (`src/config/global.conf`)
3. Terminal default (for reset state)

## Background Images

### Supported Terminals

| Terminal | Support | Method |
|----------|---------|--------|
| iTerm2 | ✅ Full | OSC 1337 SetBackgroundImageFile |
| Kitty | ✅ Full | `kitten @` remote control |
| Others | ○ Fallback | Solid colors via OSC 11 |

### Image Resolution Priority

1. User agent override: `~/.tavs/agents/{agent}/backgrounds/{mode}/{state}.png`
2. Source agent data: `src/agents/{agent}/data/backgrounds/{mode}/{state}.png`
3. Global user backgrounds: `~/.tavs/backgrounds/{mode}/{state}.png`
4. Single image fallback: `STYLISH_SINGLE_IMAGE` config
5. Default image: `{dir}/{mode}/default.png`

### Generating Placeholder Images

```bash
# Generate solid-color placeholders for all agents
./assets/backgrounds/generate-agent-backgrounds.sh

# Force regenerate (overwrite existing)
./assets/backgrounds/generate-agent-backgrounds.sh --force
```

## Customization Guide

### Adding Custom Faces

**Do:** Override in `~/.tavs/user.conf`:
```bash
# Override Claude's subagent faces
CLAUDE_FACES_SUBAGENT=('Ǝ[⟷ ⟷]E' 'Ǝ[⇔ ⇔]E')

# Override Claude's tool error faces
CLAUDE_FACES_TOOL_ERROR=('Ǝ[✘ ✘]E')
```

Or create a user override file:
```bash
mkdir -p ~/.tavs/agents/claude
cp src/agents/claude/data/faces.conf ~/.tavs/agents/claude/
# Edit the copy with your custom faces
```

**Don't:** Edit files in `src/agents/*/data/` directly - they'll be overwritten on updates.

### Creating a New Agent Theme

1. Create data directory:
   ```bash
   mkdir -p src/agents/myagent/data/backgrounds/{dark,light}
   ```

2. Create `faces.conf` with all 11 state arrays

3. Create `colors.conf` (optional)

4. Create `trigger.sh`:
   ```bash
   #!/bin/bash
   SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
   export TAVS_AGENT="myagent"
   exec "$SCRIPT_DIR/../../core/trigger.sh" "$@"
   ```

5. Generate background placeholders or add custom images

### Disabling Agent Faces

To use global defaults instead of agent-specific faces:

```bash
# In ~/.tavs/user.conf
ENABLE_ANTHROPOMORPHISING="false"
```

Or to use faces but disable per-agent theming, delete the agent's faces.conf - it will fall back to minimal kaomoji.

## Technical Details

### Module: face-selection.sh

The `src/core/face-selection.sh` module provides:

| Function | Purpose |
|----------|---------|
| `get_random_face()` | Select random face from AGENT_FACES_ pool for a state |

Face pools are defined in `src/config/defaults.conf` as arrays:
- `CLAUDE_FACES_PROCESSING`, `CLAUDE_FACES_SUBAGENT`, `CLAUDE_FACES_TOOL_ERROR`, etc.
- `GEMINI_FACES_*`, `CODEX_FACES_*`, `OPENCODE_FACES_*`
- `UNKNOWN_FACES_*` (fallback for unrecognized agents)

### Module: theme-config-loader.sh

Loads configuration hierarchy and resolves agent-specific variables:

| Function | Purpose |
|----------|---------|
| `load_agent_config()` | Load full config for specified agent |
| `_resolve_agent_variables()` | Resolve AGENT_PREFIX_ vars to generic names |
| `_resolve_agent_faces()` | Resolve agent-specific face arrays |
| `_resolve_colors()` | Resolve final COLOR_* values based on mode |
| `apply_theme()` | Apply a named theme preset |

### Bash 3.2 Compatibility

The face selection uses `eval` for array access to maintain compatibility with macOS default bash (3.2). This is intentional - do not refactor to use bash 4+ features.

### Unknown Agents

Agents without a data directory fall back to minimal kaomoji faces:
```
(°-°)  (°□°)  (^‿^)  (⇆-⇆)  (✕_✕)  etc.
```

## Related

- [Architecture](architecture.md) - How agent adapters connect to core
- [Testing](testing.md) - Testing face and theme changes
- [Troubleshooting](../troubleshooting/overview.md) - Theme not working?
