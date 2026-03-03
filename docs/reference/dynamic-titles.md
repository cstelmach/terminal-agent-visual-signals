# Dynamic Title Templates & Context Awareness

Per-state title formats with context window data, enabling the terminal title to show
different information for each trigger state — most notably, context window fill level
during permission and idle states.

## Title Presets

Quick-switch presets that configure face mode + all per-state format strings in one go.
Set `TAVS_TITLE_PRESET` in `~/.tavs/user.conf` or via `./tavs set title-preset <name>`.

| Preset | Face Mode | Style | Example |
|--------|-----------|-------|---------|
| `dashboard` | standard (text) | Info group in parentheses after face | `Ǝ[• •]E˙°(🟠\|🧀\|🇩🇪\|🦊) +2 75% ~/proj  abc123de` |
| `compact` | compact (emoji) | Emoji eyes in face, guillemet identity | `Ǝ[🟧 🧀]E +2 «🇩🇪\|🦊» abc123de ~/proj` |
| `compact_project_sorted` | compact (emoji) | Dir flag + guillemet info group | `🇩🇪 Ǝ[🟧 🧀]E «🦊\|+2\|75%» abc123de ~/proj` |

### Dashboard Preset

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

Compacting state drops food emoji (just percentage). All other states share the global
format. Agents placement and context percentage are outside parentheses.

### Compact Preset

Emoji-eye faces where left eye = state color, right eye = context food level:

```
Ǝ[🟧 🧀]E +2 «🇩🇪|🦊» abc123de ~/proj
│          │    │         │        └─ base title
│          │    │         └─ session ID
│          │    └─ guillemet identity (auto-injected)
│          └─ subagent count
└─ face with emoji eyes (status + context)
```

Permission, idle, complete, and reset states include `{CONTEXT_FOOD}{CONTEXT_PCT}` in
the title for additional context awareness. Compacting shows percentage only.

### Compact Project Sorted Preset

Dir flag as visual anchor, info group in guillemets, session ID before path:

```
🇩🇪 Ǝ[🟧 🧀]E «🦊|+2|75%» abc123de ~/proj
│   │          │               │        └─ base title
│   │          │               └─ session ID (first 8 chars)
│   │          └─ guillemet info: session animal | subagent count | context %
│   └─ face with emoji eyes (status + context food)
└─ directory flag (visual anchor — deterministic per cwd)
```

Same format used for all states. Empty tokens collapse cleanly via existing
pipe/guillemet cleanup:

| Condition | Guillemet | Resolved Example |
|-----------|-----------|-----------------|
| All present | `«🦊\|+2\|75%»` | Full info group |
| No subagents | `«🦊\|75%»` | Pipe collapsed |
| No context data | `«🦊\|+2»` | Trailing pipe removed |
| No subagents + no context | `«🦊»` | Just animal, pipes removed |
| Identity off + all empty | *(empty)* | Guillemets removed entirely |

### Configuration

```bash
# In ~/.tavs/user.conf
TAVS_TITLE_PRESET="dashboard"    # "dashboard" | "compact" | "compact_project_sorted" | ""

# Via CLI
./tavs set title-preset dashboard
./tavs set title-preset compact
./tavs set title-preset compact_project_sorted
```

### How Presets Work

When `TAVS_TITLE_PRESET` is set, the function `_apply_title_preset()` in
`theme-config-loader.sh` **unconditionally overwrites** these variables:

- `TAVS_FACE_MODE` — sets to `"standard"` or `"compact"` depending on preset
- `TAVS_TITLE_FORMAT` — the global default format (Level 4)
- `TAVS_TITLE_FORMAT_PERMISSION` — permission-specific format (Level 3)
- `TAVS_TITLE_FORMAT_IDLE` — idle-specific format (Level 3)
- `TAVS_TITLE_FORMAT_COMPACTING` — compacting-specific format (Level 3)
- (Other per-state formats as needed by the preset)

This runs **after** `user.conf` is loaded, so the preset's values take priority over
any `TAVS_TITLE_FORMAT_*` variables you set manually. However, per-agent overrides
(Levels 1-2, e.g., `CLAUDE_TITLE_FORMAT_PERMISSION`) still take priority via the
4-level fallback chain in `compose_title()`.

**To override a single state while using a preset:** use per-agent variables:
```bash
TAVS_TITLE_PRESET="compact"
# Override permission format just for Claude:
CLAUDE_TITLE_FORMAT_PERMISSION="{FACE} {STATUS_ICON} {MODEL} {CONTEXT_PCT} {BASE}"
```

**To stop using a preset:** clear the variable:
```bash
TAVS_TITLE_PRESET=""
```
This restores manual configuration — your `TAVS_TITLE_FORMAT_*` variables take effect.

---

## Per-State Title Formats

Instead of one global `TAVS_TITLE_FORMAT` for all states, each trigger state can have
its own format string. This uses a **4-level fallback chain**:

```
Level 1: {AGENT}_TITLE_FORMAT_{STATE}  (e.g., CLAUDE_TITLE_FORMAT_PERMISSION)
Level 2: {AGENT}_TITLE_FORMAT          (e.g., CLAUDE_TITLE_FORMAT)
Level 3: TAVS_TITLE_FORMAT_{STATE}     (e.g., TAVS_TITLE_FORMAT_PERMISSION)
Level 4: TAVS_TITLE_FORMAT             (global default — current behavior)
```

States use UPPERCASE with hyphens converted to underscores: `subagent-start` becomes
`SUBAGENT_START`.

### Default Per-State Formats

Three states have per-state formats by default. The remaining five fall back to the
global `TAVS_TITLE_FORMAT` (`{FACE} {STATUS_ICON} {AGENTS} {SESSION_ICON} {BASE}`):

**States with custom default formats:**

| State | Default Format | Example Output |
|-------|---------------|----------------|
| Permission | `{FACE} {STATUS_ICON} {SESSION_ICON} {CONTEXT_FOOD}{CONTEXT_PCT} {BASE}` | `Ǝ[° °]E 🔴 «🇩🇪\|🦊» 🧀50% ~/proj` |
| Idle | `{FACE} {STATUS_ICON} {CONTEXT_FOOD}{CONTEXT_PCT} {SESSION_ICON} {BASE}` | `Ǝ[· ·]E 🟣 🌽45% «🇩🇪\|🦊» ~/proj` |
| Compacting | `{FACE} {STATUS_ICON} {CONTEXT_PCT} {BASE}` | `Ǝ[~ ~]E 🔄 83% ~/proj` |

**States using global format (examples at 50% context, dual identity):**

| State | Example Output |
|-------|----------------|
| Processing | `Ǝ[• •]E 🟠 «🇩🇪\|🦊» ~/proj` |
| Processing (+2 subagents) | `Ǝ[• •]E 🟠 +2 «🇩🇪\|🦊» ~/proj` |
| Complete | `Ǝ[◠ ◠]E 🟢 «🇩🇪\|🦊» ~/proj` |
| Subagent | `Ǝ[⇆ ⇆]E 🔀 +2 «🇩🇪\|🦊» ~/proj` |
| Tool Error | `Ǝ[✕ ✕]E ❌ «🇩🇪\|🦊» ~/proj` |
| Reset (start) | `Ǝ[• •]E ⚪ «🇩🇪\|🦊» ~/proj` |
| Reset (end) | `Ǝ[— —]E ⚪ ~/proj` |

### Configuration Examples

Set in `~/.tavs/user.conf`:

```bash
# Show context on processing too
TAVS_TITLE_FORMAT_PROCESSING="{FACE} {STATUS_ICON} {CONTEXT_FOOD}{CONTEXT_PCT} {AGENTS} {BASE}"

# Show cost on completion
TAVS_TITLE_FORMAT_COMPLETE="{FACE} {STATUS_ICON} {COST} {SESSION_ICON} {BASE}"

# Agent-specific: show model name during Claude permission
CLAUDE_TITLE_FORMAT_PERMISSION="{FACE} {STATUS_ICON} {CONTEXT_FOOD}{CONTEXT_PCT} {MODEL} {BASE}"

# Gemini: same format for all states (Level 2 — agent-wide)
GEMINI_TITLE_FORMAT="{FACE} {STATUS_ICON} {BASE}"
```

### Fallback Chain Walk-Through

When TAVS composes a title for `permission` state with `TAVS_AGENT=claude`:

1. Check `CLAUDE_TITLE_FORMAT_PERMISSION` — if set, use it
2. Check `CLAUDE_TITLE_FORMAT` — if set, use it for all Claude states
3. Check `TAVS_TITLE_FORMAT_PERMISSION` — if set, use it (global per-state)
4. Fall back to `TAVS_TITLE_FORMAT` (current behavior, backward compatible)

**Implementation:** `compose_title()` in `src/core/title-management.sh` handles format
selection. Agent-prefixed variables (Levels 1-2) are resolved by
`_resolve_agent_variables()` in `src/core/theme-config-loader.sh`.

---

## Context Tokens

Eighteen tokens display context window data, session metadata, and identity in titles.

### Context Display Tokens

These visualize the context window fill percentage in different styles:

| Token | Description | 0% | 25% | 50% | 75% | 100% |
|-------|-------------|-----|-----|-----|-----|------|
| `{CONTEXT_PCT}` | Percentage | `0%` | `25%` | `50%` | `75%` | `100%` |
| `{CONTEXT_FOOD}` | Food 21-stage (5% steps) | `💧` | `🥝` | `🧀` | `🍕` | `🍫` |
| `{CONTEXT_FOOD_10}` | Food 11-stage (10% steps) | `💧` | `🥦` | `🧀` | `🌮` | `🍫` |
| `{CONTEXT_ICON}` | Color circles | `⚪` | `🔵` | `🟡` | `🔴` | `⚫` |
| `{CONTEXT_BAR_H}` | Horizontal bar (5 char) | `░░░░░` | `▓░░░░` | `▓▓░░░` | `▓▓▓░░` | `▓▓▓▓▓` |
| `{CONTEXT_BAR_HL}` | Horizontal bar (10 char) | `░░░░░░░░░░` | `▓▓░░░░░░░░` | `▓▓▓▓▓░░░░░` | `▓▓▓▓▓▓▓░░░` | `▓▓▓▓▓▓▓▓▓▓` |
| `{CONTEXT_BAR_V}` | Vertical block | `▁` | `▂` | `▄` | `▆` | `█` |
| `{CONTEXT_BAR_VM}` | Vertical + max | `▁▒` | `▂▒` | `▄▒` | `▆▒` | `█▒` |
| `{CONTEXT_BRAILLE}` | Braille fill | `⠀` | `⠄` | `⠤` | `⠷` | `⠿` |
| `{CONTEXT_NUMBER}` | Number emoji | `0️⃣` | `2️⃣` | `5️⃣` | `7️⃣` | `🔟` |

### Session Metadata Tokens

| Token | Source | Example | Format |
|-------|--------|---------|--------|
| `{MODEL}` | StatusLine `.model.display_name` | `Opus` | Raw string |
| `{COST}` | StatusLine `.cost.total_cost_usd` | `$0.42` | `$` + 2 decimals |
| `{DURATION}` | StatusLine `.cost.total_duration_ms` | `5m32s` | Minutes + seconds |
| `{LINES}` | StatusLine `.cost.total_lines_added` | `+156` | `+` prefix |
| `{MODE}` | Hook `permission_mode` payload | `plan` | Raw string |

### Identity Tokens

| Token | Source | Example | Available When |
|-------|--------|---------|----------------|
| `{SESSION_ICON}` | `get_session_icon()` | `🦊` or `🦊🐙` | `TAVS_IDENTITY_MODE` != `off` |
| `{DIR_ICON}` | `get_dir_icon()` | `🇩🇪` or `🇩🇪→🇯🇵` | `TAVS_IDENTITY_MODE=dual` |
| `{SESSION_ID}` | `TAVS_SESSION_ID[:8]` | `abc123de` | Claude Code (session_id in hook JSON) |

In dual mode, `compose_title()` dynamically injects guillemets around `{SESSION_ICON}`:
`{SESSION_ICON}` → `«{DIR_ICON}|{SESSION_ICON}»`. This only happens when the format
contains `{SESSION_ICON}` but not `{DIR_ICON}` (to avoid double-injection). Guillemet
cleanup handles empty tokens: `«|🦊»` → `«🦊»`, `«🇩🇪|»` → `«🇩🇪»`, `«|»` → empty.

### Data Availability

| Token | With Bridge | Without Bridge | Without Either |
|-------|-------------|----------------|----------------|
| Context tokens | Real-time % from StatusLine | Estimated from transcript | Defaults to 0% |
| `{MODEL}`, `{COST}`, `{DURATION}`, `{LINES}` | Real-time from StatusLine | Empty | Empty |
| `{MODE}` | Always available | Always available | Always available |

`{MODE}` comes from the hook payload directly, not the bridge — it's always available.

When tokens resolve to empty, guillemet-aware cleanup (`«|` → `«`, `|»` → `»`,
`«»` → empty) and space collapse (`sed 's/  */ /g'`) keep titles clean regardless of
data availability.

---

## StatusLine Bridge

The bridge enables **real-time** context window data in titles by reading Claude Code's
StatusLine JSON. It's a silent script — reads JSON from stdin, writes a state file,
produces **no stdout output**.

### How It Works

```
Claude Code StatusLine → JSON on stdin → statusline-bridge.sh → ~/.cache/tavs/context.{TTY_SAFE}
                                                                        ↑
                                                              (read by compose_title)
```

The bridge extracts `used_percentage`, `display_name`, `total_cost_usd`,
`total_duration_ms`, `total_lines_added`, `total_lines_removed` from the JSON and
writes them as key=value pairs. The state file is written atomically (mktemp+mv) and
per-TTY isolated via `{TTY_SAFE}` suffix.

### Setup

**Step 1:** Create `~/.claude/statusline.sh`:

```bash
#!/bin/bash
input=$(cat)
# TAVS bridge — silent, no output
echo "$input" | ~/.claude/plugins/cache/terminal-agent-visual-signals/tavs/*/src/agents/claude/statusline-bridge.sh
# Your statusline output (optional):
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

### Coexistence With Existing StatusLine

The bridge is designed to coexist. Your script captures stdin into `$input` first, then
pipes a copy to the bridge. The bridge consumes its own stdin (the piped JSON), not the
parent script's `$input`. Your existing statusline output continues to work normally.

### Staleness & Freshness

Bridge data is considered stale after `TAVS_CONTEXT_BRIDGE_MAX_AGE` seconds (default: 30).
Stale data is ignored and TAVS falls back to transcript estimation.

---

## Context Data Fallback Chain

Three-tier data resolution ensures context tokens work with or without the bridge:

```
1. Bridge state file exists AND fresh (< 30 seconds)?
   → Use bridge data (accurate, real-time from StatusLine JSON)

2. No bridge data? TAVS_TRANSCRIPT_PATH set and file exists?
   → Parse JSONL transcript for token counts
   → Per-agent context window sizing (200k Claude, 1M Gemini)
   → Approximate but fast, no external dependencies

3. Neither available?
   → Context percentage defaults to 0% (session start / no activity yet)
   → Metadata tokens (MODEL, COST, etc.) resolve to empty string
   → Empty metadata collapsed by space cleanup — no visual disruption
```

### Transcript Estimation Details

When no bridge is configured, TAVS parses the JSONL transcript file (path from hook
payload) to count actual token usage. It reads `usage` entries in the transcript and sums
`input_tokens`, `cache_creation_input_tokens`, and `cache_read_input_tokens`. This is
more accurate than file-size heuristics but requires the transcript file to exist.

Context window size is per-agent: Claude uses 200k, Gemini uses 1M (configurable via
`CLAUDE_CONTEXT_WINDOW_SIZE`, `GEMINI_CONTEXT_WINDOW_SIZE` in `defaults.conf`).

---

## Icon Scale Customization

All icon arrays can be overridden in `~/.tavs/user.conf`:

```bash
# Replace the 21-stage food scale
TAVS_CONTEXT_FOOD_21=("🌱" "🌿" "🍃" "🌾" "🥬" "🥦" "🥒" "🥗" "🥝" "🥑" "🍋" "🍌" "🌽" "🧀" "🍞" "🌮" "🍕" "🍔" "🍟" "🍩" "🔥")

# Replace color circles
TAVS_CONTEXT_CIRCLES_11=("⬜" "🟦" "🟦" "🟩" "🟩" "🟨" "🟧" "🟧" "🟥" "🟥" "⬛")

# Replace bar characters
TAVS_CONTEXT_BAR_FILL="█"
TAVS_CONTEXT_BAR_EMPTY="░"
```

### Default Icon Scales

All defaults are defined in `src/config/defaults.conf`:

| Array | Stages | Step | Token |
|-------|--------|------|-------|
| `TAVS_CONTEXT_FOOD_21` | 21 entries | 5% | `{CONTEXT_FOOD}` |
| `TAVS_CONTEXT_FOOD_11` | 11 entries | 10% | `{CONTEXT_FOOD_10}` |
| `TAVS_CONTEXT_CIRCLES_11` | 11 entries | 10% | `{CONTEXT_ICON}` |
| `TAVS_CONTEXT_NUMBERS` | 11 entries | 10% | `{CONTEXT_NUMBER}` |
| `TAVS_CONTEXT_BLOCKS` | 8 entries | ~14% | `{CONTEXT_BAR_V}` |
| `TAVS_CONTEXT_BRAILLE` | 7 entries | ~17% | `{CONTEXT_BRAILLE}` |

---

## Compact Context Eye

When compact face mode is active (`TAVS_FACE_MODE="compact"`), the right eye shows the
context window fill level — turning the face into a **two-signal dashboard**: left eye =
state color, right eye = context fill.

```
Ǝ[🟧 🧀]E +2 «🇩🇪|🦊» ~/proj  processing at 50%, 2 subagents
Ǝ[🟥 🍔]E «🇩🇪|🦊» ~/proj     permission at 85% — danger zone!
Ǝ[🟩 🥝]E «🇩🇪|🦊» ~/proj     complete at 25%
Ǝ[— —]E                    reset — em dash resting eyes
```

### Configuration

```bash
# In ~/.tavs/user.conf
TAVS_COMPACT_CONTEXT_EYE="true"     # "true" (default) | "false"
TAVS_COMPACT_CONTEXT_STYLE="food"   # See style catalog below
```

### Style Catalog

All styles at different context levels (left eye = 🟧 processing, squares theme):

| Style | 0% | 25% | 50% | 75% | 100% |
|-------|----|-----|-----|-----|------|
| `food` (default) | `Ǝ[🟧 💧]E` | `Ǝ[🟧 🥝]E` | `Ǝ[🟧 🧀]E` | `Ǝ[🟧 🍕]E` | `Ǝ[🟧 🍫]E` |
| `food_10` | `Ǝ[🟧 💧]E` | `Ǝ[🟧 🥦]E` | `Ǝ[🟧 🧀]E` | `Ǝ[🟧 🌮]E` | `Ǝ[🟧 🍫]E` |
| `circle` | `Ǝ[🟧 ⚪]E` | `Ǝ[🟧 🔵]E` | `Ǝ[🟧 🟡]E` | `Ǝ[🟧 🔴]E` | `Ǝ[🟧 ⚫]E` |
| `block` | `Ǝ[🟧 ▁]E` | `Ǝ[🟧 ▂]E` | `Ǝ[🟧 ▄]E` | `Ǝ[🟧 ▆]E` | `Ǝ[🟧 █]E` |
| `block_max` | `Ǝ[🟧 ▁▒]E` | `Ǝ[🟧 ▂▒]E` | `Ǝ[🟧 ▄▒]E` | `Ǝ[🟧 ▆▒]E` | `Ǝ[🟧 █▒]E` |
| `braille` | `Ǝ[🟧 ⠀]E` | `Ǝ[🟧 ⠄]E` | `Ǝ[🟧 ⠤]E` | `Ǝ[🟧 ⠷]E` | `Ǝ[🟧 ⠿]E` |
| `number` | `Ǝ[🟧 0️⃣]E` | `Ǝ[🟧 2️⃣]E` | `Ǝ[🟧 5️⃣]E` | `Ǝ[🟧 7️⃣]E` | `Ǝ[🟧 🔟]E` |
| `percent` | `Ǝ[🟧 0%]E` | `Ǝ[🟧 25%]E` | `Ǝ[🟧 50%]E` | `Ǝ[🟧 75%]E` | `Ǝ[🟧 100%]E` |

### Per-Agent Faces

Each agent's face frame wraps the same two-signal pattern:

| Agent | 50% Context | Reset |
|-------|-------------|-------|
| Claude | `Ǝ[🟧 🧀]E` | `Ǝ[— —]E` |
| Gemini | `ʕ🟧ᴥ🧀ʔ` | `ʕ—ᴥ—ʔ` |
| Codex | `ฅ^🟧ﻌ🧀^ฅ` | `ฅ^—ﻌ—^ฅ` |
| OpenCode | `(🟧-🧀)` | `(—-—)` |

### Subagent Count Displacement

When context eye is active, the subagent count (`+N`) moves from the right eye to the
`{AGENTS}` title token outside the face:

| Mode | Face | Title |
|------|------|-------|
| Context eye ON + 2 subagents | `Ǝ[🟧 🧀]E` | `Ǝ[🟧 🧀]E +2 «🇩🇪\|🦊» ~/proj` |
| Context eye OFF + 2 subagents | `Ǝ[🟧 +2]E` | `Ǝ[🟧 +2]E «🇩🇪\|🦊» ~/proj` |

Token suppression matrix:

| Mode | `{STATUS_ICON}` | `{AGENTS}` |
|------|-----------------|------------|
| Standard mode | Shown | Shown |
| Compact, context eye OFF | Suppressed | Suppressed (in right eye) |
| Compact, context eye ON | Suppressed | **Shown** (context in right eye) |

### No-Data Fallback

When no context data is available (no bridge, no transcript), the right eye falls back
to the theme status emoji — the face looks identical to standard compact mode. No broken
visual state.

### Reset State Faces

The reset state distinguishes between session-start and session-end:

| Trigger | Face | Status Icon | Purpose |
|---------|------|-------------|---------|
| `reset` (SessionStart) | Standard eyes (`Ǝ[• •]E`) | ⚪ | Fresh session — inviting |
| `reset session-end` (SessionEnd) | Em dash eyes (`Ǝ[— —]E`) | ⚪ | Session closing — muted |

Each agent has both `FACES_RESET` (session-start, multiple variants) and
`FACES_RESET_FINAL` (session-end, single em dash variant). In compact mode, session-end
shows `Ǝ[— —]E` while session-start shows theme emoji eyes with context.

### Per-Agent Customization

Via `_resolve_agent_variables()` in `theme-config-loader.sh`:

```bash
# Different context style per agent
CLAUDE_COMPACT_CONTEXT_STYLE="food"
GEMINI_COMPACT_CONTEXT_STYLE="block"

# Disable context eye for specific agent
CODEX_COMPACT_CONTEXT_EYE="false"
```

### Automatic Token Suppression

When context eye is active, the matching `{CONTEXT_*}` token is **automatically suppressed**
from the title format to avoid showing the same info twice. For example, with `food` style
the `{CONTEXT_FOOD}` token resolves to empty in the title — but `{CONTEXT_PCT}` still shows:

```
Default permission format: {FACE} {STATUS_ICON} {CONTEXT_FOOD}{CONTEXT_PCT} {BASE}
Context eye ON (food):     Ǝ[🟥 🧀]E 50% ~/proj     ← food only in eye, pct in title
Context eye OFF:           Ǝ[🟥 🟥]E 🧀50% ~/proj   ← food in title (no eye)
```

Which token is suppressed depends on the style:

| Style | Suppressed Token | Still Available |
|-------|-----------------|-----------------|
| `food` | `{CONTEXT_FOOD}` | `{CONTEXT_PCT}`, all others |
| `percent` | `{CONTEXT_PCT}` | `{CONTEXT_FOOD}`, all others |
| `block` | `{CONTEXT_BAR_V}` | `{CONTEXT_PCT}`, `{CONTEXT_FOOD}`, etc. |

### Combining Eye + Title Tokens

Use a different token in the title from what's in the eye for maximum info density:

```bash
# Food in eye + percentage in title (default behavior — no config needed)
# Result: Ǝ[🟥 🍔]E 85% ~/proj  (food in eye + number in title)

# Block in eye + food in title (custom)
TAVS_COMPACT_CONTEXT_STYLE="block"
TAVS_TITLE_FORMAT_PERMISSION="{FACE} {STATUS_ICON} {CONTEXT_FOOD}{CONTEXT_PCT} {BASE}"
# Result: Ǝ[🟥 ▇]E 🍔85% ~/proj  (block in eye + food in title)
```

---

## Key Files

| File | Purpose |
|------|---------|
| `src/core/context-data.sh` | Context data resolution, token resolvers, fallback chain |
| `src/agents/claude/statusline-bridge.sh` | Silent StatusLine bridge (reads JSON, writes state) |
| `src/core/title-management.sh` | `compose_title()` — per-state format selection, token substitution, guillemet injection, context eye suppression |
| `src/core/idle-worker-background.sh` | Background idle timer — uses `compose_title()` for idle/complete titles |
| `src/core/theme-config-loader.sh` | `_resolve_agent_variables()` — agent-prefixed TITLE_FORMAT_*, IDENTITY_MODE, DIR_ICON_TYPE resolution |
| `src/core/session-icon.sh` | Deterministic session identity (animal per session_id, 2-icon collision overflow) |
| `src/core/dir-icon.sh` | Directory identity (flag per cwd, worktree detection, fallback pools) |
| `src/core/identity-registry.sh` | Shared registry: round-robin assignment, mkdir locking, active-sessions index |
| `src/config/defaults.conf` | Icon arrays, per-state format defaults, identity config, bridge config |

## Related

- [Architecture](architecture.md) — System design and data flow
- [Testing](testing.md) — Verification commands for context tokens and bridge
- [Troubleshooting](../troubleshooting/overview.md) — Common issues with context data
