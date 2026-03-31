# TAVS Raw Variables Reference

Complete catalog of configuration variables beyond the 28 CLI aliases. These are
set directly in `~/.tavs/user.conf` using the Edit tool. For CLI aliases, see
`references/config-options.md`.

## 1. Naming Conventions

TAVS variables follow a hierarchical naming pattern:

| Pattern | Scope | Example |
|---------|-------|---------|
| `TAVS_*` or plain name | Global setting | `TAVS_TITLE_MODE`, `THEME_MODE` |
| `DEFAULT_{SETTING}` | Default fallback for all agents | `DEFAULT_DARK_PROCESSING` |
| `{AGENT}_{SETTING}` | Per-agent override (highest priority) | `CLAUDE_DARK_PROCESSING` |

**Agents:** `CLAUDE`, `GEMINI`, `CODEX`, `OPENCODE`, `UNKNOWN`

**Resolution priority:** `{AGENT}_{SETTING}` -> `DEFAULT_{SETTING}` -> hardcoded default

**Data types:**
- Strings: double-quoted — `THEME_MODE="static"`
- Booleans: `"true"` or `"false"` — `ENABLE_IDLE="true"`
- Hex colors: 7-char — `CLAUDE_DARK_BASE="#2E3440"`
- Integers: unquoted — `IDLE_CHECK_INTERVAL=15`
- Arrays: bash syntax — `CLAUDE_FACES_PROCESSING=('Ǝ[• •]E' 'Ǝ[■ ■]E')`

**Assignment rules:** No spaces around `=`. Values with special chars must be quoted.

## 2. Per-Agent Color Overrides

Background colors per state, per mode, per agent.

**Variable pattern:** `{AGENT}_{MODE}_{STATE}`

| Dimension | Values |
|-----------|--------|
| Agent (5) | `CLAUDE`, `GEMINI`, `CODEX`, `OPENCODE`, `UNKNOWN` |
| Mode (2) | `DARK`, `LIGHT` |
| State (6) | `BASE`, `PROCESSING`, `PERMISSION`, `COMPLETE`, `IDLE`, `COMPACTING` |

That's 5 x 2 x 6 = **60 possible color variables**.

**Default fallbacks** (used when agent has no specific color):
```bash
DEFAULT_DARK_BASE="#303446"
DEFAULT_DARK_PROCESSING="#3d3b42"
DEFAULT_DARK_PERMISSION="#3d3440"
DEFAULT_DARK_COMPLETE="#374539"
DEFAULT_DARK_IDLE="#3d3850"
DEFAULT_DARK_COMPACTING="#334545"
# Same pattern for DEFAULT_LIGHT_*
```

**Example — make Claude's processing state a warmer orange:**
```bash
CLAUDE_DARK_PROCESSING="#4D3820"
```

**Mode-aware processing variants** (subtle color shifts per permission mode):
```bash
# Pattern: {AGENT}_{MODE}_PROCESSING_{PERMISSION_MODE}
CLAUDE_DARK_PROCESSING_PLAN="#48432E"      # Green-yellow (thinking)
CLAUDE_DARK_PROCESSING_ACCEPT="#493D2D"    # Barely warmer (auto-approve)
CLAUDE_DARK_PROCESSING_BYPASS="#4B312A"    # Reddish (danger)
```
Permission modes: `PLAN`, `ACCEPT`, `BYPASS`

## 3. Per-Agent Face Overrides

ASCII face expressions per state. Each is a bash array — one face picked randomly
per trigger invocation.

**Variable pattern:** `{AGENT}_FACES_{STATE}`

**States (12):** `PROCESSING`, `PERMISSION`, `COMPLETE`, `COMPACTING`, `SUBAGENT`,
`TOOL_ERROR`, `RESET`, `IDLE_0`, `IDLE_1`, `IDLE_2`, `IDLE_3`, `IDLE_4`, `IDLE_5`

**Face styles by agent:**
| Agent | Template | Example |
|-------|----------|---------|
| Claude | Pincer | `Ǝ[• •]E` |
| Gemini | Bear | `ʕ•ᴥ•ʔ` |
| Codex | Cat | `ฅ^•ﻌ•^ฅ` |
| OpenCode | Kaomoji | `(°-°)` |

**Example — add custom Claude processing faces:**
```bash
CLAUDE_FACES_PROCESSING=('Ǝ[• •]E' 'Ǝ[◔ ◔]E' 'Ǝ[★ ★]E')
```

Multiple entries in the array give variety — one is randomly selected each trigger.

## 4. Per-State Title Format Overrides

Custom title templates per trigger state, with a 4-level fallback chain:

1. `{AGENT}_TITLE_FORMAT_{STATE}` (e.g., `CLAUDE_TITLE_FORMAT_PERMISSION`)
2. `{AGENT}_TITLE_FORMAT` (e.g., `CLAUDE_TITLE_FORMAT`)
3. `TAVS_TITLE_FORMAT_{STATE}` (e.g., `TAVS_TITLE_FORMAT_PERMISSION`)
4. `TAVS_TITLE_FORMAT` (global default)

**States (8):** `PROCESSING`, `PERMISSION`, `COMPLETE`, `COMPACTING`, `IDLE`,
`SUBAGENT`, `TOOL_ERROR`, `RESET`

**Context & metadata tokens** (15 total, available in any format string):

| Token | Description | Data Source |
|-------|-------------|-------------|
| `{CONTEXT_PCT}` | Percentage number (e.g., `45%`) | Bridge or transcript |
| `{CONTEXT_FOOD}` | Food emoji 21-stage (5% steps) | Bridge or transcript |
| `{CONTEXT_FOOD_10}` | Food emoji 11-stage (10% steps) | Bridge or transcript |
| `{CONTEXT_ICON}` | Color circle scale | Bridge or transcript |
| `{CONTEXT_BAR_H}` | Horizontal bar 5-char | Bridge or transcript |
| `{CONTEXT_BAR_HL}` | Horizontal bar 10-char | Bridge or transcript |
| `{CONTEXT_BAR_V}` | Vertical block char | Bridge or transcript |
| `{CONTEXT_BAR_VM}` | Vertical + max outline | Bridge or transcript |
| `{CONTEXT_BRAILLE}` | Braille fill pattern | Bridge or transcript |
| `{CONTEXT_NUMBER}` | Number emoji (0-10) | Bridge or transcript |
| `{MODEL}` | Model display name (e.g., `Opus`) | Bridge only |
| `{COST}` | Session cost (e.g., `$0.42`) | Bridge only |
| `{DURATION}` | Session duration (e.g., `5m32s`) | Bridge only |
| `{LINES}` | Lines added (e.g., `+156`) | Bridge only |
| `{MODE}` | Permission mode (e.g., `plan`) | Always available |

**Note:** Context tokens require the StatusLine bridge for real-time data. Without
it, TAVS estimates context % from transcript file size. Model/cost/duration/lines
tokens are empty without the bridge.

**Example — show context info during permission requests:**
```bash
TAVS_TITLE_FORMAT_PERMISSION="{FACE} {STATUS_ICON} {CONTEXT_FOOD} {CONTEXT_PCT} {BASE}"
```

## 5. Compact Face Configuration

Controls emoji eye behavior when `TAVS_FACE_MODE="compact"`.

| Variable | Values | Default | Description |
|----------|--------|---------|-------------|
| `TAVS_COMPACT_CONTEXT_EYE` | `"mirror"`, `"true"`, `"false"` | `"mirror"` | What the right eye shows |
| `TAVS_COMPACT_CONTEXT_STYLE` | See below | `"food"` | Visual style for context data |
| `TAVS_COMPACT_THEME` | `"squares"`, `"semantic"`, `"circles"`, `"mixed"` | `"squares"` | Emoji set for state eyes |

**Context eye modes:**
- `"mirror"` — Both eyes show same state square: `Ǝ[🟧 🟧]E`
- `"true"` — Right eye = context fill: `Ǝ[🟧 🧀]E` (50%)
- `"false"` — Right eye = subagent count or theme fallback: `Ǝ[🟧 +2]E`

**Context styles:** `food`, `food_10`, `circle`, `block`, `block_max`, `braille`,
`number`, `percent`

**Per-agent overrides:**
```bash
CLAUDE_COMPACT_CONTEXT_STYLE="food"
GEMINI_COMPACT_CONTEXT_STYLE="block"
CODEX_COMPACT_CONTEXT_EYE="false"
```

## 6. Status Icon Customization

Per-state emoji shown in titles.

| Variable | Default | Description |
|----------|---------|-------------|
| `STATUS_ICON_PROCESSING` | `🟠` | Agent working |
| `STATUS_ICON_PERMISSION` | `🔴` | Needs approval |
| `STATUS_ICON_COMPLETE` | `🟢` | Response finished |
| `STATUS_ICON_IDLE` | `🟣` | Waiting for input |
| `STATUS_ICON_COMPACTING` | `🔄` | Context compression |
| `STATUS_ICON_SUBAGENT` | `🔀` | Subagent spawned |
| `STATUS_ICON_TOOL_ERROR` | `❌` | Tool execution failed |

**Example — use custom permission icon:**
```bash
STATUS_ICON_PERMISSION="🛑"
```

## 7. Context Data Customization

Custom emoji/character scales for context window visualization.

| Variable | Type | Elements | Description |
|----------|------|----------|-------------|
| `TAVS_CONTEXT_FOOD_21` | Array | 21 | Food emoji scale (5% steps) |
| `TAVS_CONTEXT_CIRCLES_11` | Array | 11 | Color circle scale (10% steps) |
| `TAVS_CONTEXT_BAR_FILL` | String | 1 char | Bar fill character (default `▓`) |
| `TAVS_CONTEXT_BAR_EMPTY` | String | 1 char | Bar empty character (default `░`) |

**Example — custom food scale:**
```bash
TAVS_CONTEXT_FOOD_21=("💧" "🥬" "🥦" "🥒" "🥗" "🥝" "🥑" "🍋" "🍌" "🌽" "🧀" "🥨" "🍞" "🥪" "🌮" "🍕" "🌭" "🍔" "🍟" "🍩" "🍫")
```

## 8. Spinner Customization

Only active when `TAVS_TITLE_MODE="full"`.

| Variable | Type | Description |
|----------|------|-------------|
| `TAVS_SPINNER_FRAMES_BRAILLE` | Array | Braille animation frames |
| `TAVS_SPINNER_FRAMES_CIRCLE` | Array | Circle animation frames |
| `TAVS_SPINNER_FRAMES_BLOCK` | Array | Block animation frames |
| `{AGENT}_SPINNER_FACE_FRAME` | String | Face template with `{L}` and `{R}` eye placeholders |

**Example — custom spinner face for Claude:**
```bash
CLAUDE_SPINNER_FACE_FRAME='Ǝ[{L} {R}]E'
```

`{L}` and `{R}` are replaced with animated spinner characters during processing.

## 9. Feature Toggles & Timers

**Per-state enables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_PROCESSING` | `"true"` | Processing state signals |
| `ENABLE_PERMISSION` | `"true"` | Permission state signals |
| `ENABLE_COMPLETE` | `"true"` | Complete state signals |
| `ENABLE_IDLE` | `"true"` | Idle state signals |
| `ENABLE_COMPACTING` | `"true"` | Compacting state signals |
| `ENABLE_BACKGROUND_CHANGE` | `"true"` | Background color changes |
| `ENABLE_TITLE_PREFIX` | `"true"` | Title prefix updates |

**Bell notifications:**

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_BELL_PROCESSING` | `"false"` | Bell on processing start |
| `ENABLE_BELL_PERMISSION` | `"true"` | Bell on permission requests |
| `ENABLE_BELL_COMPLETE` | `"false"` | Bell on task completion |
| `ENABLE_BELL_COMPACTING` | `"false"` | Bell on context compaction |

**Idle timing:**

| Variable | Default | Description |
|----------|---------|-------------|
| `STAGE_DURATIONS` | `(60 30 30 30 30 30 30)` | Seconds per idle stage (array) |
| `IDLE_CHECK_INTERVAL` | `15` | Seconds between idle checks |
| `ENABLE_STAGE_INDICATORS` | `"true"` | Graduated idle stages |

## 10. Advanced / Rarely Changed

| Variable | Default | Description |
|----------|---------|-------------|
| `HUE_PROCESSING` | `30` | Dynamic mode hue angle |
| `HUE_PERMISSION` | `0` | Dynamic mode hue angle |
| `HUE_COMPLETE` | `120` | Dynamic mode hue angle |
| `HUE_IDLE` | `270` | Dynamic mode hue angle |
| `HUE_COMPACTING` | `180` | Dynamic mode hue angle |
| `DYNAMIC_QUERY_TIMEOUT` | `"0.1"` | Terminal query timeout (seconds) |
| `DYNAMIC_DISABLE_SSH` | `"true"` | Disable dynamic mode over SSH |
| `DEBUG_ALL` | `"0"` | Enable debug logging |
| `IDLE_DEBUG` | `"0"` | Idle-specific debug logging |
| `STATE_GRACE_PERIOD_MS` | `400` | Debounce rapid state changes (ms) |
| `TAVS_CONTEXT_BRIDGE_MAX_AGE` | `30` | Bridge data staleness threshold (seconds) |
| `TAVS_IDENTITY_REGISTRY_TTL` | `2592000` | Identity mapping TTL (seconds, default 30 days) |
| `TAVS_DIR_IDENTITY_SOURCE` | `"cwd"` | Dir path resolution: `"cwd"` or `"git-root"` |
| `TAVS_DIR_WORKTREE_DETECTION` | `"true"` | Detect git worktrees for dir identity |
