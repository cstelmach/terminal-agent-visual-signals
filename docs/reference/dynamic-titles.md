# Dynamic Title Templates & Context Awareness

Per-state title formats with context window data, enabling the terminal title to show
different information for each trigger state — most notably, context window fill level
during permission and idle states.

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

Only three states have per-state formats by default (others fall back to
`TAVS_TITLE_FORMAT`):

| State | Default Format | Example Output |
|-------|---------------|----------------|
| Permission | `{FACE} {STATUS_ICON} {CONTEXT_FOOD}{CONTEXT_PCT} {BASE}` | `Ǝ[° °]E 🔴 🧀50% ~/proj` |
| Idle | `{FACE} {STATUS_ICON} {CONTEXT_FOOD}{CONTEXT_PCT} {SESSION_ICON} {BASE}` | `Ǝ[· ·]E 🟣 🌽45% 🦊 ~/proj` |
| Compacting | `{FACE} {STATUS_ICON} {CONTEXT_PCT} {BASE}` | `Ǝ[~ ~]E 🔄 83% ~/proj` |

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

Fifteen new tokens display context window data and session metadata in titles.

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

### Data Availability

| Token | With Bridge | Without Bridge | Without Either |
|-------|-------------|----------------|----------------|
| Context tokens | Real-time % from StatusLine | Estimated from transcript | Empty (collapses) |
| `{MODEL}`, `{COST}`, `{DURATION}`, `{LINES}` | Real-time from StatusLine | Empty | Empty |
| `{MODE}` | Always available | Always available | Always available |

`{MODE}` comes from the hook payload directly, not the bridge — it's always available.

When tokens resolve to empty, the existing space cleanup (`sed 's/  */ /g'`) collapses
double spaces, so titles look clean regardless of data availability.

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
   → All context/metadata tokens resolve to empty string
   → Collapsed by existing space cleanup — no visual disruption
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

## Key Files

| File | Purpose |
|------|---------|
| `src/core/context-data.sh` | Context data resolution, token resolvers, fallback chain |
| `src/agents/claude/statusline-bridge.sh` | Silent StatusLine bridge (reads JSON, writes state) |
| `src/core/title-management.sh` | `compose_title()` — per-state format selection + token substitution |
| `src/core/theme-config-loader.sh` | `_resolve_agent_variables()` — agent-prefixed TITLE_FORMAT_* resolution |
| `src/config/defaults.conf` | Icon arrays, per-state format defaults, bridge config |

## Related

- [Architecture](architecture.md) — System design and data flow
- [Testing](testing.md) — Verification commands for context tokens and bridge
- [Troubleshooting](../troubleshooting/overview.md) — Common issues with context data
