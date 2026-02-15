# Dynamic Title Template System with Context Awareness — Specification

**Status:** Final
**Version:** 1.0
**Created:** 2026-02-13
**Last Updated:** 2026-02-14
**Author:** Discovery process (Opus 4.6 + user collaboration)

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Goals & Success Criteria](#2-goals--success-criteria)
3. [Background & Research](#3-background--research)
4. [Architecture & Design](#4-architecture--design)
5. [Decisions & Rationale](#5-decisions--rationale)
6. [Token Reference](#6-token-reference)
7. [Icon Scale Reference](#7-icon-scale-reference)
8. [Implementation Phases](#8-implementation-phases)
9. [File Change Inventory](#9-file-change-inventory)
10. [Constraints & Boundaries](#10-constraints--boundaries)
11. [Rejected Alternatives](#11-rejected-alternatives)
12. [Verification Strategy](#12-verification-strategy)
13. [Configuration Reference](#13-configuration-reference)
14. [Key Reusable Patterns](#14-key-reusable-patterns)
15. [Open Questions](#15-open-questions)
16. [Review Notes](#16-review-notes)

---

## 1. Project Overview

**Name:** Dynamic Title Template System with Context Awareness
**Parent Project:** TAVS (Terminal Agent Visual Signals) v2.0.0

**Summary:** TAVS currently uses a single `TAVS_TITLE_FORMAT` template string for ALL
trigger states (processing, permission, complete, idle, etc.). This means the terminal
title bar displays the same information structure regardless of what's happening. This
feature introduces **per-trigger title templates** with **context window awareness** —
enabling the title to show different, relevant information for each state. The primary
motivating use case is permission decisions (e.g., plan mode approval), where seeing
context window fill level helps decide whether to continue or compact.

**Core Purpose:** Give users contextual, actionable information in the terminal title
bar that adapts to the current agent state, with particular focus on context window
percentage during decision points.

---

## 2. Goals & Success Criteria

| Goal | Success Criterion | Priority |
|------|-------------------|----------|
| Per-state title templates | Each of 8 trigger states can have its own format string | Must Have |
| Context window display in title | Context percentage visible during permission state | Must Have |
| StatusLine bridge for data | Bridge script writes context data to state file silently | Must Have |
| Multiple context display styles | At least 10 token types for context visualization | Must Have |
| Per-agent title customization | Agent x state matrix with 4-level fallback chain | Must Have |
| Transcript fallback | Approximate context % when no StatusLine bridge exists | Should Have |
| Food emoji default | 21-stage food scale as default context indicator | Must Have |
| Session metadata tokens | {MODEL}, {COST}, {DURATION}, {LINES} available | Should Have |
| User-configurable icon arrays | Users can replace any icon scale in user.conf | Must Have |
| Zero-disruption when no data | Empty tokens collapse cleanly via existing sed logic | Must Have |

---

## 3. Background & Research

### 3.1 The Hooks / StatusLine Data Gap

Claude Code has two separate data channels with different JSON payloads:

**Hooks** (what TAVS uses for triggers):
```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/working/dir",
  "permission_mode": "plan",
  "hook_event_name": "PermissionRequest"
}
```

**StatusLine** (bottom bar of Claude Code CLI):
```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/working/dir",
  "model": {
    "id": "claude-opus-4-6",
    "display_name": "Opus"
  },
  "workspace": {
    "current_dir": "/working/dir",
    "project_dir": "/project/dir"
  },
  "cost": {
    "total_cost_usd": 0.42,
    "total_duration_ms": 300000,
    "total_api_duration_ms": 12000,
    "total_lines_added": 156,
    "total_lines_removed": 23
  },
  "context_window": {
    "total_input_tokens": 90000,
    "total_output_tokens": 12000,
    "context_window_size": 200000,
    "used_percentage": 45,
    "remaining_percentage": 55,
    "current_usage": {
      "input_tokens": 8500,
      "output_tokens": 1200,
      "cache_creation_input_tokens": 5000,
      "cache_read_input_tokens": 2000
    }
  },
  "exceeds_200k_tokens": false,
  "version": "2.1.39"
}
```

**The gap:** Hooks do NOT receive `context_window`, `model`, or `cost` fields.
Only the StatusLine mechanism gets the rich JSON. A bridge is needed to make this
data available to TAVS hooks at title-composition time.

### 3.2 StatusLine Behavior

- Configured in `~/.claude/settings.json` as `statusLine.command`
- Receives JSON on stdin, produces text on stdout for display
- Updates debounce at **300ms** — script runs at most once per 300ms
- Fires after: each assistant message, permission mode changes, vim mode toggles
- In-flight executions are cancelled if new update triggers
- If script produces no output, statusline area is empty (not an error)

### 3.3 Context Percentage Calculation

```
used_percentage = (input_tokens + cache_creation_input_tokens
                   + cache_read_input_tokens)
                  / context_window_size * 100
```

- **Output tokens do NOT count** toward context usage
- `used_percentage` may be `null` before first API call — always use fallbacks
- Context window size: 200,000 (standard) or 1,000,000 (extended context)
- Auto-compaction triggers at ~83-85% (configurable via
  `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`)

### 3.4 Current TAVS Title System

**Existing tokens (5):**
- `{FACE}` — Agent face expression (e.g., `Ǝ[• •]E`)
- `{STATUS_ICON}` — State emoji (e.g., 🟠)
- `{AGENTS}` — Subagent count (e.g., `+2`, empty when 0)
- `{SESSION_ICON}` — Unique animal emoji per TTY (e.g., 🐙)
- `{BASE}` — User-set title or fallback path

**Current format:** ONE template for all states:
```bash
TAVS_TITLE_FORMAT="{FACE} {STATUS_ICON} {AGENTS} {SESSION_ICON} {BASE}"
```

**Token collapse:** Empty tokens produce double spaces, collapsed by:
```bash
sed 's/  */ /g; s/^ *//; s/ *$//'
```
at `title-management.sh:335`.

**Key function:** `compose_title()` at `title-management.sh:242-338`
- Takes `state` and optional `base_title` parameters
- Resolves face, status_icon, agents, session_icon, base
- Substitutes into format string via `${title//\{TOKEN\}/$value}`
- Cleans spaces and returns

**Agent variable resolution:** `_resolve_agent_variables()` at
`theme-config-loader.sh:96-138`
- Takes agent name, converts to uppercase prefix
- Tries `{AGENT}_{VAR}` -> `UNKNOWN_{VAR}` -> `DEFAULT_{VAR}`
- Currently resolves ~44 color/face/spinner variables

### 3.5 Ecosystem Research Summary

Research across 10+ statusline projects, Oh My Posh, Aider, Gemini CLI, and
others found:
- Progress bars (`▓▓▓▓░░░░░░`) are the dominant context display pattern
- Color-coded thresholds: 🟢 <50% → 🟡 50-70% → 🟠 70-85% → 🔴 85-100%
- Two-layer feedback works well: ambient (background color) + precise (numbers/bars)
- Caching expensive operations with 5s TTL is near-universal in statusline scripts
- Per-window state isolation prevents cross-session interference

---

## 4. Architecture & Design

### 4.1 Three-Pillar Architecture

```
+-----------------------------------------------------------+
|                   Claude Code                              |
|                                                            |
|  StatusLine JSON -----------+   Hook JSON ----------+     |
|  (rich: context, model,     |   (basic: session_id, |     |
|   cost, tokens)             |    cwd, permission)   |     |
+-----------------------------+------------------------+-----+
                              v                        v
               +-----------------------+  +-----------------------+
               | PILLAR 1              |  | PILLAR 2 + 3          |
               | StatusLine Bridge     |  | Per-State Templates   |
               | (silent data siphon)  |  | + Context Tokens      |
               |                       |  |                       |
               | src/agents/claude/    |  | src/core/             |
               | statusline-bridge.sh  |  | title-management.sh   |
               |                       |  | context-data.sh       |
               | 1. Read JSON stdin    |  |                       |
               | 2. Extract fields     |  | 1. Load context data  |
               | 3. Write state file   |  | 2. Select per-state   |
               | 4. Exit (no output)   |  |    format template    |
               |                       |  | 3. Resolve all tokens |
               |                       |  | 4. Set terminal title |
               +-------+---------------+  +-----------+-----------+
                       |                               |
                       v                               |
               ~/.cache/tavs/                          |
               context.{TTY_SAFE}         reads -------+
               +-----------------+
               | pct=45          |
               | model=Opus      |
               | cost=0.42       |
               | duration=300000 |
               | lines_add=156   |
               | lines_rem=23    |
               | ts=1707945432   |
               +-----------------+
```

### 4.2 Context Data Fallback Chain

```
1. Bridge state file exists AND fresh (< TAVS_CONTEXT_BRIDGE_MAX_AGE seconds)?
   -> Use bridge data (accurate, real-time from StatusLine JSON)

2. No bridge data? TAVS_TRANSCRIPT_PATH set and file exists?
   -> Estimate from transcript file size
   -> Formula: file_size_bytes / 3.5 / context_window_size * 100
   -> Approximate (~20% error), but fast and requires no dependencies

3. Neither available?
   -> All context/metadata tokens resolve to empty string
   -> Collapsed by existing space cleanup — no visual disruption
```

### 4.3 Title Format Fallback Chain

Four-level resolution for maximum flexibility:

```
Level 1: {AGENT}_TITLE_FORMAT_{STATE}  (e.g., CLAUDE_TITLE_FORMAT_PERMISSION)
    | not set
Level 2: {AGENT}_TITLE_FORMAT          (e.g., CLAUDE_TITLE_FORMAT)
    | not set
Level 3: TAVS_TITLE_FORMAT_{STATE}     (e.g., TAVS_TITLE_FORMAT_PERMISSION)
    | not set
Level 4: TAVS_TITLE_FORMAT             (global default — current behavior)
```

This allows:
- Agent-specific formats per state (most specific)
- Agent-wide formats (one format for all states of that agent)
- Global per-state formats (all agents share state-specific formats)
- Global default (backward compatible, current behavior)

### 4.4 StatusLine Bridge Integration

The bridge is a **silent data siphon** — it reads the StatusLine JSON, extracts
data, writes to a state file, and produces NO stdout output. Users integrate it
into their existing statusline setup by adding one line to their script:

```bash
#!/bin/bash
# User's existing statusline.sh
input=$(cat)

# Add this one line — TAVS bridge (silent, no output)
echo "$input" | /path/to/tavs/statusline-bridge.sh

# User's existing statusline code continues with $input
MODEL=$(echo "$input" | jq -r '.model.display_name')
echo "[$MODEL] ..."
```

**Critical design property:** The bridge consumes its OWN stdin (the piped JSON),
not the parent script's `$input` variable. The user captures stdin into `$input`
first, then pipes a copy to the bridge. This avoids stdin conflicts.

### 4.5 Bridge State File Format

Location: `~/.cache/tavs/context.{TTY_SAFE}`

```
# TAVS Context Bridge - 2026-02-14T10:45:23+00:00
pct=45
model=Opus
cost=0.42
duration=300000
lines_add=156
lines_rem=23
ts=1707945432
```

- Written atomically: `mktemp` + `mv` (pattern from `session-state.sh:64`)
- Read safely: `while IFS='=' read` (pattern from `title-state-persistence.sh:104`)
- Never sourced (security: prevents code injection)
- Per-TTY isolation via `{TTY_SAFE}` suffix

---

## 5. Decisions & Rationale

### D01: Data Source Strategy

**Question:** How should TAVS obtain context window data that hooks don't provide?
**Options:**
- A) StatusLine Bridge only — user must configure
- B) Transcript parsing only — self-contained but slow
- C) Hybrid: bridge primary + transcript fallback
- D) Bridge-only, strict — no fallback

**Decision:** C) Hybrid
**Reasoning:** Provides real-time accurate data when the user has StatusLine
configured, but degrades gracefully to an approximation when they don't. No hard
dependency on external setup. The fallback is lightweight (file size check, no jq).

### D02: StatusLine Coexistence

**Question:** How should the bridge work alongside the user's existing statusline?
**Options:**
- A) Wrapper that chains to user's script
- B) Separate background sidecar process
- C) Standalone script, user integrates manually

**Decision:** C) Standalone, user integrates
**Reasoning:** User adds `echo "$input" | /path/to/bridge.sh` to their existing
statusline script. Most flexible — no assumptions about user's setup. Requires
clear documentation guiding users step-by-step.

### D03: Template Scope

**Question:** What level of per-state customization for title formats?
**Options:**
- A) Per-state format strings (`TAVS_TITLE_FORMAT_PERMISSION`, etc.)
- B) Full template engine with conditionals (`{IF:CONTEXT}...{/IF}`)
- C) Segment-based (tmux-style left/center/right sections)

**Decision:** A) Per-state format strings
**Reasoning:** Simple, follows existing TAVS variable naming patterns, powerful
enough for the use cases. Falls back gracefully to global format. Avoids parser
complexity.

### D04: Agent x State Matrix

**Question:** Should per-state formats also support per-agent customization?
**Options:**
- A) Full matrix: `{AGENT}_TITLE_FORMAT_{STATE}`
- B) Agent-generic only: `{AGENT}_TITLE_FORMAT`
- C) State-specific only: `TAVS_TITLE_FORMAT_{STATE}`

**Decision:** A) Full matrix with 4-level fallback chain
**Reasoning:** Context is agent-specific — different agents may use different
models with different context window sizes, so tokens mean different things per
agent. The existing `_resolve_agent_variables()` already handles this pattern
for colors/faces.

### D05: Context Display Approach

**Question:** How should context percentage be represented as tokens?
**Options:**
- A) Single smart `{CONTEXT}` token controlled by a style setting
- B) Individual tokens per style (`{CONTEXT_PCT}`, `{CONTEXT_BAR_H}`, etc.)
- C) Both: smart token + individual tokens

**Decision:** B) Individual tokens per style
**Reasoning:** A single token limits users to one representation. Individual
tokens let users combine freely — e.g., `{CONTEXT_FOOD} {CONTEXT_PCT}` shows
`🧀 50%`. Each token is independently useful and composable.

### D06: Default Context Display

**Question:** What should the default permission title template show for context?
**Decision:** Food emoji 21-stage + percentage as default:
```
{FACE} {STATUS_ICON} {CONTEXT_FOOD} {CONTEXT_PCT} {BASE}
```
Output: `Ǝ[• •]E 🔴 🧀 50% ~/proj`

### D07: Fallback Depth

**Question:** How much effort to put into the transcript fallback?
**Options:**
- A) Lightweight file-size estimation (~3.5 chars/token)
- B) Full JSONL parsing with jq
- C) Minimal: just detect 'near limit' threshold

**Decision:** A) Lightweight estimation
**Reasoning:** Fast, no jq dependency, approximate but good enough as a fallback.
The bridge provides accurate data when configured.

### D08: Token Availability When No Data

**Question:** What happens to {MODEL}, {COST}, etc. when bridge data isn't
present?
**Decision:** Always resolve to empty string. Collapsed by existing space cleanup
(`sed 's/  */ /g'`). No visual disruption — tokens simply disappear.

### D09: Git Worktree

**Question:** Should implementation use a git worktree?
**Decision:** Yes. Create `feature/dynamic-title-templates` branch in a worktree
at `../tavs-dynamic-titles` for isolated development.

---

## 6. Token Reference

### 6.1 Existing Tokens (unchanged)

| Token | Source | Example |
|-------|--------|---------|
| `{FACE}` | `get_random_face()` / `get_compact_face()` | `Ǝ[• •]E` |
| `{STATUS_ICON}` | State-mapped emoji | `🟠` |
| `{AGENTS}` | `get_subagent_title_suffix()` | `+2` |
| `{SESSION_ICON}` | `get_session_icon()` | `🐙` |
| `{BASE}` | `get_base_title()` | `~/proj` |

### 6.2 New Session Metadata Tokens

| Token | Bridge JSON Source | Example | Format |
|-------|-------------------|---------|--------|
| `{MODEL}` | `.model.display_name` | `Opus` | Raw string |
| `{COST}` | `.cost.total_cost_usd` | `$0.42` | `$` + 2 decimal |
| `{DURATION}` | `.cost.total_duration_ms` | `5m32s` | Mins + secs |
| `{LINES}` | `.cost.total_lines_added` | `+156` | `+` prefix |
| `{MODE}` | Hook `permission_mode` | `plan` | Raw string |

`{MODE}` is special — it comes from the hook payload directly (not the bridge),
so it's always available regardless of bridge configuration.

### 6.3 New Context Display Tokens

| Token | Description | 0% | 25% | 45% | 50% | 75% | 85% | 100% |
|-------|-------------|-----|-----|-----|-----|-----|-----|------|
| `{CONTEXT_PCT}` | Percentage | `0%` | `25%` | `45%` | `50%` | `75%` | `85%` | `100%` |
| `{CONTEXT_BAR_H}` | Horiz bar 5-char | `░░░░░` | `▓░░░░` | `▓▓░░░` | `▓▓░░░` | `▓▓▓░░` | `▓▓▓▓░` | `▓▓▓▓▓` |
| `{CONTEXT_BAR_HL}` | Horiz bar 10-char | `░░░░░░░░░░` | `▓▓░░░░░░░░` | `▓▓▓▓░░░░░░` | `▓▓▓▓▓░░░░░` | `▓▓▓▓▓▓▓░░░` | `▓▓▓▓▓▓▓▓░░` | `▓▓▓▓▓▓▓▓▓▓` |
| `{CONTEXT_BAR_V}` | Vertical block | `▁` | `▂` | `▄` | `▄` | `▆` | `▇` | `█` |
| `{CONTEXT_BAR_VM}` | Vertical + max | `▁▒` | `▂▒` | `▄▒` | `▄▒` | `▆▒` | `▇▒` | `█▒` |
| `{CONTEXT_BRAILLE}` | Braille fill | `⠀` | `⠄` | `⠤` | `⠤` | `⠶` | `⠷` | `⠿` |
| `{CONTEXT_NUMBER}` | Number emoji | `0️⃣` | `2️⃣` | `4️⃣` | `5️⃣` | `7️⃣` | `8️⃣` | `🔟` |
| `{CONTEXT_ICON}` | Color circle | `⚪` | `🔵` | `🟢` | `🟡` | `🟠` | `🔴` | `⚫` |
| `{CONTEXT_FOOD}` | Food 21-stage | `💧` | `🥝` | `🌽` | `🧀` | `🍕` | `🍔` | `🍫` |
| `{CONTEXT_FOOD_10}` | Food 11-stage | `💧` | `🥦` | `🍌` | `🧀` | `🌮` | `🍔` | `🍫` |

---

## 7. Icon Scale Reference

### 7.1 Food Scale — 21-stage (5% steps) — DEFAULT

```bash
TAVS_CONTEXT_FOOD_21=(
    "💧"    # 0%
    "🥬"    # 5%
    "🥦"    # 10%
    "🥒"    # 15%
    "🥗"    # 20%
    "🥝"    # 25%
    "🥑"    # 30%
    "🍋"    # 35%
    "🍌"    # 40%
    "🌽"    # 45%
    "🧀"    # 50%
    "🥨"    # 55%
    "🍞"    # 60%
    "🥪"    # 65%
    "🌮"    # 70%
    "🍕"    # 75%
    "🌭"    # 80%
    "🍔"    # 85%
    "🍟"    # 90%
    "🍩"    # 95%
    "🍫"    # 100%
)
```

**Lookup formula:** `index = pct / 5` (clamped to 0-20)

### 7.2 Food Scale — 11-stage (10% steps)

```bash
TAVS_CONTEXT_FOOD_11=(
    "💧"    # 0%
    "🥬"    # 10%
    "🥦"    # 20%
    "🥑"    # 30%
    "🍌"    # 40%
    "🧀"    # 50%
    "🍞"    # 60%
    "🌮"    # 70%
    "🍔"    # 80%
    "🍟"    # 90%
    "🍫"    # 100%
)
```

**Lookup formula:** `index = pct / 10` (clamped to 0-10)

### 7.3 Color Circle Scale — 11-stage (10% steps)

```bash
TAVS_CONTEXT_CIRCLES_11=(
    "⚪"    # 0%
    "🔵"    # 10%
    "🔵"    # 20%
    "🟢"    # 30%
    "🟢"    # 40%
    "🟡"    # 50%
    "🟠"    # 60%
    "🟠"    # 70%
    "🔴"    # 80%
    "🔴"    # 90%
    "⚫"    # 100%
)
```

**Lookup formula:** `index = pct / 10` (clamped to 0-10)

### 7.4 Number Emoji Scale — 11-stage (10% steps)

```bash
TAVS_CONTEXT_NUMBERS=(
    "0️⃣" "1️⃣" "2️⃣" "3️⃣" "4️⃣"
    "5️⃣" "6️⃣" "7️⃣" "8️⃣" "9️⃣" "🔟"
)
```

**Lookup formula:** `index = pct / 10` (clamped to 0-10)

### 7.5 Block Characters — 8-stage

```bash
TAVS_CONTEXT_BLOCKS=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
```

**Lookup formula:** `index = pct * 7 / 100` (clamped to 0-7)

### 7.6 Braille Characters — 7-stage (bottom to top fill)

```bash
TAVS_CONTEXT_BRAILLE=("⠀" "⠄" "⠤" "⠴" "⠶" "⠷" "⠿")
```

**Lookup formula:** `index = pct * 6 / 100` (clamped to 0-6)

### 7.7 User Customization

All icon arrays can be overridden in `~/.tavs/user.conf`:

```bash
# Replace the food scale with custom emoji
TAVS_CONTEXT_FOOD_21=("🌱" "🌿" ... "🔥")

# Replace circle icons
TAVS_CONTEXT_CIRCLES_11=("⬜" "🟦" "🟩" "🟨" "🟧" "🟥" ... "⬛")

# Custom bar characters
TAVS_CONTEXT_BAR_FILL="█"
TAVS_CONTEXT_BAR_EMPTY="░"
```

---

## 8. Implementation Phases

### Phase 0: Git Worktree Setup

**Scope:** Create isolated development environment.
**Depends On:** Nothing.

**Commands:**
```bash
cd /Users/cs/.claude/hooks/terminal-agent-visual-signals
git checkout -b feature/dynamic-title-templates
git worktree add ../tavs-dynamic-titles feature/dynamic-title-templates
cd ../tavs-dynamic-titles
```

**Acceptance Criteria:**
- [ ] Branch `feature/dynamic-title-templates` exists
- [ ] Worktree at `../tavs-dynamic-titles` is functional
- [ ] All source files accessible in worktree

---

### Phase 1: Context Data System

**Scope:** Create the core context data resolution module with all token
resolvers.
**Depends On:** Phase 0
**Estimated:** ~250 lines in new file + ~80 lines in defaults.conf

**Create:** `src/core/context-data.sh`

**Functions to implement:**

| Function | Purpose | Signature |
|----------|---------|-----------|
| `load_context_data` | Read bridge state or transcript estimate | `load_context_data()` |
| `read_bridge_state` | Safe key=value parsing from state file | `read_bridge_state()` |
| `_estimate_from_transcript` | File-size based token estimation | `_estimate_from_transcript "$path"` |
| `resolve_context_token` | Map token name to formatted value | `resolve_context_token "TOKEN_NAME" "$pct"` |
| `_get_icon_from_array` | Lookup icon by percentage in array | `_get_icon_from_array "ARRAY_NAME" "$pct" "$step"` |
| `_get_bar_horizontal` | Generate horizontal progress bar | `_get_bar_horizontal "$pct" "$width"` |
| `_get_bar_vertical` | Single block character for percentage | `_get_bar_vertical "$pct"` |
| `_get_bar_vertical_max` | Block + max outline character | `_get_bar_vertical_max "$pct"` |
| `_get_braille` | Single braille character for percentage | `_get_braille "$pct"` |
| `_get_number_emoji` | First digit as emoji number | `_get_number_emoji "$pct"` |
| `_get_percentage` | Formatted percentage string | `_get_percentage "$pct"` |

**Pattern to follow:** `_read_title_state_value()` at
`title-state-persistence.sh:104-128` for safe key=value parsing.
Never `source` state files.

**Add to `defaults.conf`:** All icon arrays (see Section 7), bar/braille
character arrays, bridge staleness threshold.

**Also create:** `src/agents/claude/statusline-bridge.sh` (the silent bridge)

**Acceptance Criteria:**
- [ ] `resolve_context_token CONTEXT_FOOD 45` returns `🌽`
- [ ] `resolve_context_token CONTEXT_PCT 85` returns `85%`
- [ ] `resolve_context_token CONTEXT_BAR_H 50` returns `▓▓░░░`
- [ ] `resolve_context_token CONTEXT_ICON 0` returns `⚪`
- [ ] `resolve_context_token CONTEXT_NUMBER 90` returns `9️⃣`
- [ ] All 10 token types produce correct output for edge cases (0%, 50%, 100%)
- [ ] Bridge reads JSON from stdin and writes state file atomically
- [ ] Bridge produces NO stdout output
- [ ] State file uses safe key=value format (no executable content)
- [ ] Icon arrays defined in defaults.conf match Section 7 exactly

**Verification:**
```bash
source src/core/context-data.sh
for pct in 0 5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100; do
    echo "$pct%: FOOD=$(resolve_context_token CONTEXT_FOOD $pct)"
done
# Verify each matches the 21-stage food scale exactly
```

---

### Phase 2: Per-State Title Format System

**Scope:** Modify title composition to use per-state format templates with
fallback.
**Depends On:** Phase 1
**Estimated:** ~100 lines across modified files

**Modify:** `src/core/title-management.sh` — `compose_title()` at line 242

**Current code** (lines 322-324):
```bash
local _default_format='{FACE} {STATUS_ICON} {AGENTS} {BASE}'
local format="${TAVS_TITLE_FORMAT:-$_default_format}"
local title="$format"
```

**New code** — implement the 4-level fallback chain:
```bash
# 4-level format fallback: agent+state → agent → state → global
local _default_format='{FACE} {STATUS_ICON} {AGENTS} {SESSION_ICON} {BASE}'
local state_upper
state_upper=$(echo "$state" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

# Level 1: Agent-specific + state-specific
local _agent_state_var="TITLE_FORMAT_${state_upper}"
local format=""
eval "format=\${${_agent_state_var}:-}"

# Level 2: Agent-specific (all states)
[[ -z "$format" ]] && format="${TITLE_FORMAT:-}"

# Level 3: Global state-specific
if [[ -z "$format" ]]; then
    eval "format=\${TAVS_TITLE_FORMAT_${state_upper}:-}"
fi

# Level 4: Global default
[[ -z "$format" ]] && format="${TAVS_TITLE_FORMAT:-$_default_format}"

local title="$format"
```

Note: `TITLE_FORMAT` and `TITLE_FORMAT_*` are resolved by
`_resolve_agent_variables()` from `{AGENT}_TITLE_FORMAT` /
`{AGENT}_TITLE_FORMAT_{STATE}`.

**Add new token substitutions** after existing ones (lines 327-332):
```bash
# Existing tokens (unchanged)
title="${title//\{FACE\}/$face}"
title="${title//\{STATUS_ICON\}/$status_icon}"
title="${title//\{AGENTS\}/$agents}"
title="${title//\{SESSION_ICON\}/$session_icon}"
title="${title//\{BASE\}/$base_title}"

# NEW: Context tokens
if [[ "$title" == *"{CONTEXT_"* || "$title" == *"{MODEL}"* || \
      "$title" == *"{COST}"* || "$title" == *"{DURATION}"* || \
      "$title" == *"{LINES}"* || "$title" == *"{MODE}"* ]]; then
    load_context_data  # Loads from bridge or transcript fallback
    # Context display tokens
    title="${title//\{CONTEXT_PCT\}/$(resolve_context_token CONTEXT_PCT "$TAVS_CONTEXT_PCT")}"
    title="${title//\{CONTEXT_FOOD\}/$(resolve_context_token CONTEXT_FOOD "$TAVS_CONTEXT_PCT")}"
    title="${title//\{CONTEXT_FOOD_10\}/$(resolve_context_token CONTEXT_FOOD_10 "$TAVS_CONTEXT_PCT")}"
    title="${title//\{CONTEXT_BAR_H\}/$(resolve_context_token CONTEXT_BAR_H "$TAVS_CONTEXT_PCT")}"
    title="${title//\{CONTEXT_BAR_HL\}/$(resolve_context_token CONTEXT_BAR_HL "$TAVS_CONTEXT_PCT")}"
    title="${title//\{CONTEXT_BAR_V\}/$(resolve_context_token CONTEXT_BAR_V "$TAVS_CONTEXT_PCT")}"
    title="${title//\{CONTEXT_BAR_VM\}/$(resolve_context_token CONTEXT_BAR_VM "$TAVS_CONTEXT_PCT")}"
    title="${title//\{CONTEXT_BRAILLE\}/$(resolve_context_token CONTEXT_BRAILLE "$TAVS_CONTEXT_PCT")}"
    title="${title//\{CONTEXT_NUMBER\}/$(resolve_context_token CONTEXT_NUMBER "$TAVS_CONTEXT_PCT")}"
    title="${title//\{CONTEXT_ICON\}/$(resolve_context_token CONTEXT_ICON "$TAVS_CONTEXT_PCT")}"
    # Session metadata tokens
    title="${title//\{MODEL\}/$TAVS_CONTEXT_MODEL}"
    title="${title//\{COST\}/$(_format_cost "$TAVS_CONTEXT_COST")}"
    title="${title//\{DURATION\}/$(_format_duration "$TAVS_CONTEXT_DURATION")}"
    title="${title//\{LINES\}/$(_format_lines "$TAVS_CONTEXT_LINES_ADD")}"
    title="${title//\{MODE\}/$TAVS_PERMISSION_MODE}"
fi
```

**Optimization:** Only call `load_context_data` and resolve context tokens when
the format string actually contains context/metadata tokens. The
`*"{CONTEXT_"*` check avoids unnecessary work for format strings that don't use
these tokens.

**Modify:** `src/core/theme-config-loader.sh` — `_resolve_agent_variables()`
at line 96.

Add to the `vars` array (after line 114, alongside SPINNER_FACE_FRAME):
```bash
TITLE_FORMAT
TITLE_FORMAT_PROCESSING TITLE_FORMAT_PERMISSION TITLE_FORMAT_COMPLETE
TITLE_FORMAT_IDLE TITLE_FORMAT_COMPACTING TITLE_FORMAT_SUBAGENT
TITLE_FORMAT_TOOL_ERROR TITLE_FORMAT_RESET
```

**Add to `defaults.conf`:** Per-state format defaults:
```bash
# Per-state title formats (override with TAVS_TITLE_FORMAT_{STATE})
# Empty = fall back to TAVS_TITLE_FORMAT
TAVS_TITLE_FORMAT_PROCESSING=""
TAVS_TITLE_FORMAT_PERMISSION="{FACE} {STATUS_ICON} {CONTEXT_FOOD} {CONTEXT_PCT} {BASE}"
TAVS_TITLE_FORMAT_COMPLETE=""
TAVS_TITLE_FORMAT_IDLE=""
TAVS_TITLE_FORMAT_COMPACTING="{FACE} {STATUS_ICON} {CONTEXT_PCT} {BASE}"
TAVS_TITLE_FORMAT_SUBAGENT=""
TAVS_TITLE_FORMAT_TOOL_ERROR=""
TAVS_TITLE_FORMAT_RESET=""
```

**Acceptance Criteria:**
- [ ] `TAVS_TITLE_FORMAT_PERMISSION="{FACE} {CONTEXT_PCT}" ./src/core/trigger.sh permission` shows face + percentage
- [ ] With no per-state format set, falls back to `TAVS_TITLE_FORMAT` (backward compat)
- [ ] `CLAUDE_TITLE_FORMAT_PERMISSION="{FACE} {CONTEXT_FOOD} {MODEL}"` overrides global
- [ ] Empty tokens collapse — no double spaces in output
- [ ] Existing title behavior unchanged for states without per-state formats

---

### Phase 3: StatusLine Bridge

**Scope:** Create the silent bridge script and extract transcript_path from
hooks.
**Depends On:** Phase 1
**Estimated:** ~60 lines new file + ~5 lines modified

**Create:** `src/agents/claude/statusline-bridge.sh`

```bash
#!/bin/bash
# StatusLine Bridge — Silent data siphon for TAVS
# Reads Claude Code StatusLine JSON from stdin, writes context data
# to TAVS state file. Produces NO output.
# User integrates by adding to their statusline script:
#   echo "$input" | /path/to/statusline-bridge.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ... (read stdin, extract with sed, write atomic state file)
```

**Extraction pattern** (no jq dependency, matching existing TAVS patterns):
```bash
_extract() {
    sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\",$]*\).*/\1/p" \
    | head -1
}
pct=$(printf '%s' "$input" | _extract 'used_percentage')
model=$(printf '%s' "$input" | _extract 'display_name')
cost=$(printf '%s' "$input" | _extract 'total_cost_usd')
duration=$(printf '%s' "$input" | _extract 'total_duration_ms')
lines_add=$(printf '%s' "$input" | _extract 'total_lines_added')
lines_rem=$(printf '%s' "$input" | _extract 'total_lines_removed')
```

**Modify:** `src/agents/claude/trigger.sh` — add transcript_path extraction.

After line 28 (permission_mode extraction), add:
```bash
_transcript=$(printf '%s' "$_tavs_stdin" | \
    sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -1)
[[ -n "$_transcript" ]] && export TAVS_TRANSCRIPT_PATH="$_transcript"
```

**Acceptance Criteria:**
- [ ] Bridge produces zero bytes of stdout
- [ ] Bridge writes atomic state file to `~/.cache/tavs/context.{TTY_SAFE}`
- [ ] State file readable by `read_bridge_state()`
- [ ] transcript_path extracted from Claude hook payload
- [ ] `TAVS_TRANSCRIPT_PATH` exported and available to context-data.sh

**Verification:**
```bash
echo '{"context_window":{"used_percentage":72},"model":{"display_name":"Opus"},"cost":{"total_cost_usd":1.23,"total_duration_ms":300000,"total_lines_added":42,"total_lines_removed":7}}' \
  | ./src/agents/claude/statusline-bridge.sh
# Verify: empty stdout
test -z "$(echo '{"context_window":{"used_percentage":72}}' \
  | ./src/agents/claude/statusline-bridge.sh)"
echo "Bridge is silent: $?"  # Should print 0
```

---

### Phase 4: Transcript Fallback

**Scope:** Implement lightweight file-size estimation when bridge data
unavailable.
**Depends On:** Phase 1
**Estimated:** ~40 lines added to context-data.sh

**Implementation in `_estimate_from_transcript()`:**
```bash
_estimate_from_transcript() {
    local transcript_path="${1:-$TAVS_TRANSCRIPT_PATH}"
    [[ -z "$transcript_path" || ! -f "$transcript_path" ]] && return 1

    local file_size
    # macOS stat vs Linux stat
    file_size=$(stat -f%z "$transcript_path" 2>/dev/null \
        || stat -c%s "$transcript_path" 2>/dev/null)
    [[ -z "$file_size" || "$file_size" -eq 0 ]] && return 1

    # ~3.5 chars/token (Anthropic heuristic), context_window default 200000
    local _default_ctx=200000
    local ctx_size="${TAVS_CONTEXT_WINDOW_SIZE:-$_default_ctx}"
    local estimated_tokens=$((file_size * 10 / 35))  # file_size / 3.5
    local pct=$((estimated_tokens * 100 / ctx_size))
    [[ $pct -gt 100 ]] && pct=100

    TAVS_CONTEXT_PCT="$pct"
    return 0
}
```

**Acceptance Criteria:**
- [ ] Returns estimated percentage from transcript file size
- [ ] Handles missing/empty transcript file gracefully
- [ ] Works on both macOS (`stat -f%z`) and Linux (`stat -c%s`)
- [ ] Clamps result to 0-100 range
- [ ] Used only when bridge state file is missing or stale

---

### Phase 5: Configuration & Documentation

**Scope:** Update user configuration template and create usage documentation.
**Depends On:** Phases 1-4
**Estimated:** ~60 lines in user.conf.template

**Update:** `src/config/user.conf.template` — add sections for per-state
formats, context icon customization, StatusLine bridge setup, per-agent
overrides.

**Documentation:** Update `CLAUDE.md` with new title format section, bridge
setup guide, icon customization guide.

**Acceptance Criteria:**
- [ ] `user.conf.template` includes all new settings as commented examples
- [ ] Bridge setup documented with concrete shell script examples
- [ ] Icon customization documented with copy-paste ready arrays
- [ ] CLAUDE.md updated with new section

---

### Phase 6: Deploy & Integration Test

**Scope:** Copy to plugin cache and test live with Claude Code.
**Depends On:** All previous phases

**Deploy:**
```bash
CACHE="$HOME/.claude/plugins/cache/terminal-agent-visual-signals/tavs/2.0.0"
cp src/core/*.sh "$CACHE/src/core/"
mkdir -p "$CACHE/src/config" && cp src/config/*.conf "$CACHE/src/config/"
cp src/agents/claude/*.sh "$CACHE/src/agents/claude/"
echo "Plugin cache updated"
```

**Live test sequence:**
1. Configure bridge in `~/.claude/settings.json`
2. Start Claude Code -> SessionStart -> verify reset title
3. Submit prompt -> UserPromptSubmit -> verify processing title
4. Wait for permission -> PermissionRequest -> verify context food + percentage
5. Complete response -> Stop -> verify complete title
6. Wait 60s -> Notification idle -> verify idle title
7. Run /compact -> PreCompact -> verify compacting title with context %
8. Test without bridge (remove from settings) -> verify graceful fallback

**Acceptance Criteria:**
- [ ] All 8 trigger states produce correct titles in live session
- [ ] Context percentage updates in real-time via bridge
- [ ] Fallback works when bridge not configured
- [ ] Per-agent overrides work (test with different TAVS_AGENT values)
- [ ] No regressions in existing title behavior

---

## 9. File Change Inventory

### New Files

| File | Lines | Purpose |
|------|-------|---------|
| `src/core/context-data.sh` | ~250 | Context data resolution, all token resolvers |
| `src/agents/claude/statusline-bridge.sh` | ~60 | Silent StatusLine bridge |

### Modified Files

| File | Location | Change | Lines |
|------|----------|--------|-------|
| `src/config/defaults.conf` | After title settings (~line 170) | Icon arrays, per-state formats, context config | ~120 |
| `src/core/title-management.sh` | `compose_title()` at line 242 | Per-state format lookup + new token resolution | ~40 |
| `src/core/theme-config-loader.sh` | `_resolve_agent_variables()` at line 103 | Add TITLE_FORMAT_* to vars array | ~10 |
| `src/core/trigger.sh` | Module sourcing (~line 30) | Source context-data.sh | ~2 |
| `src/agents/claude/trigger.sh` | After line 28 | Extract transcript_path | ~5 |
| `src/config/user.conf.template` | New sections | Per-state formats, icons, bridge docs | ~60 |

### Unchanged Files

| File | Why Unchanged |
|------|---------------|
| `hooks/hooks.json` | Existing hooks already provide needed trigger points |
| `src/core/spinner.sh` | Spinner system independent of title format |
| `src/core/session-icon.sh` | Session icon system unchanged |
| `src/core/face-selection.sh` | Face system unchanged, consumed by compose_title |

---

## 10. Constraints & Boundaries

### Out of Scope

- Modifying Claude Code's hook system to pass context data directly
- Modifying the StatusLine rendering mechanism
- Real-time context tracking without StatusLine bridge
- Adding context-based background color shifts (possible future feature)
- Gemini/Codex/OpenCode StatusLine bridges (Claude-only for now, extensible)
- Interactive configuration wizard updates (configure.sh)

### Technical Constraints

- **No jq dependency** — TAVS uses `sed` for JSON extraction (Bash 3.2 compat)
- **Zsh compatibility** — Must use intermediate vars for brace defaults
- **Atomic writes** — All state files use mktemp+mv pattern
- **No sourcing state files** — Always use `while IFS='=' read` loops
- **Per-TTY isolation** — All state files use `{TTY_SAFE}` suffix
- **StatusLine debounce** — Bridge data may be up to 300ms stale
- **Bridge staleness** — State file considered stale after 30s (configurable)

### Dependencies

- Claude Code StatusLine feature (for bridge data — optional, has fallback)
- `~/.cache/tavs/` directory (created by existing `get_spinner_state_dir()`)
- Existing TAVS module loading in `trigger.sh`

---

## 11. Rejected Alternatives

| Alternative | Why Rejected |
|-------------|--------------|
| Single `{CONTEXT}` smart token | Limits users to one representation; individual tokens allow combining |
| Template engine with conditionals | Adds parser complexity; per-state formats achieve same goal simply |
| Segment-based (tmux-style) | Over-engineered for terminal title; segments better suit status bars |
| Background sidecar process | Adds process management complexity; bridge script is simpler |
| StatusLine wrapper (chain user's script) | Assumes too much about user's setup; manual integration more flexible |
| Full JSONL transcript parsing | Too slow (~100ms+), requires jq; file-size estimation sufficient |
| StatusLine-only (no fallback) | Creates hard dependency; graceful degradation preferred |
| Modify Claude Code hooks | Not possible — external project, no control over hook payloads |

---

## 12. Verification Strategy

### Unit-Level Testing

```bash
# Test each context token resolver with boundary values
source src/core/context-data.sh

# Test all food scale entries (21-stage)
for pct in 0 5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100; do
    result=$(resolve_context_token CONTEXT_FOOD "$pct")
    echo "$pct% -> $result"
done
# Verify: 0%->💧, 5%->🥬, 10%->🥦 ... 100%->🍫

# Test horizontal bar at boundaries
for pct in 0 10 20 50 80 100; do
    echo "$pct% -> $(resolve_context_token CONTEXT_BAR_H "$pct")"
done
# Verify: 0%->░░░░░, 50%->▓▓░░░, 100%->▓▓▓▓▓

# Test number emoji
for pct in 0 15 25 55 85 99 100; do
    echo "$pct% -> $(resolve_context_token CONTEXT_NUMBER "$pct")"
done
# Verify: 0%->0️⃣, 15%->1️⃣, 55%->5️⃣, 100%->🔟
```

### Integration Testing

```bash
# Test per-state format selection
TAVS_TITLE_FORMAT_PERMISSION="{FACE} {CONTEXT_FOOD} {CONTEXT_PCT} {BASE}" \
  ./src/core/trigger.sh permission
# Verify title contains food emoji and percentage

# Test fallback chain
unset TAVS_TITLE_FORMAT_PERMISSION
./src/core/trigger.sh permission
# Verify falls back to TAVS_TITLE_FORMAT

# Test bridge silent behavior
output=$(echo '{"context_window":{"used_percentage":45}}' \
  | ./src/agents/claude/statusline-bridge.sh)
[[ -z "$output" ]] && echo "PASS: bridge is silent" \
  || echo "FAIL: bridge produced output"
```

### Live Claude Code Testing

1. Deploy to plugin cache
2. Add bridge to statusline configuration
3. Start Claude Code session
4. Submit various prompts and observe title changes per state
5. Check permission title shows food emoji + percentage
6. Verify compacting title shows percentage
7. Remove bridge from statusline -> verify fallback works
8. Test per-agent overrides with different `TAVS_AGENT` values

---

## 13. Configuration Reference

### defaults.conf Additions

```bash
# ==============================================================================
# PER-STATE TITLE FORMATS
# ==============================================================================
# Override TAVS_TITLE_FORMAT for specific states.
# Empty string = fall back to TAVS_TITLE_FORMAT.
# Available tokens: {FACE} {STATUS_ICON} {AGENTS} {SESSION_ICON} {BASE}
#   plus new: {CONTEXT_PCT} {CONTEXT_FOOD} {CONTEXT_FOOD_10} {CONTEXT_ICON}
#   {CONTEXT_BAR_H} {CONTEXT_BAR_HL} {CONTEXT_BAR_V} {CONTEXT_BAR_VM}
#   {CONTEXT_BRAILLE} {CONTEXT_NUMBER} {MODEL} {COST} {DURATION} {LINES}
#   {MODE}

TAVS_TITLE_FORMAT_PROCESSING=""
TAVS_TITLE_FORMAT_PERMISSION="{FACE} {STATUS_ICON} {CONTEXT_FOOD} {CONTEXT_PCT} {BASE}"
TAVS_TITLE_FORMAT_COMPLETE=""
TAVS_TITLE_FORMAT_IDLE=""
TAVS_TITLE_FORMAT_COMPACTING="{FACE} {STATUS_ICON} {CONTEXT_PCT} {BASE}"
TAVS_TITLE_FORMAT_SUBAGENT=""
TAVS_TITLE_FORMAT_TOOL_ERROR=""
TAVS_TITLE_FORMAT_RESET=""

# ==============================================================================
# CONTEXT DATA BRIDGE
# ==============================================================================
TAVS_CONTEXT_BRIDGE_MAX_AGE=30        # Seconds before bridge data stale
TAVS_CONTEXT_WINDOW_SIZE=200000       # Default context window (fallback)
TAVS_CONTEXT_BAR_FILL="▓"
TAVS_CONTEXT_BAR_EMPTY="░"
TAVS_CONTEXT_BAR_MAX="▒"             # Max outline for BAR_VM token
```

### user.conf.template Additions

```bash
# ==============================================================================
# PER-STATE TITLE FORMATS
# ==============================================================================
# Different title template for each trigger state.
# Tokens: {FACE} {STATUS_ICON} {AGENTS} {SESSION_ICON} {BASE}
#         {CONTEXT_PCT} {CONTEXT_FOOD} {CONTEXT_ICON} {CONTEXT_BAR_H}
#         {CONTEXT_BAR_HL} {CONTEXT_BAR_V} {CONTEXT_BAR_VM}
#         {CONTEXT_BRAILLE} {CONTEXT_NUMBER} {CONTEXT_FOOD_10}
#         {MODEL} {COST} {DURATION} {LINES} {MODE}
#
# TAVS_TITLE_FORMAT_PROCESSING="{FACE} {STATUS_ICON} {CONTEXT_FOOD} {CONTEXT_PCT} {AGENTS} {SESSION_ICON} {BASE}"
# TAVS_TITLE_FORMAT_PERMISSION="{FACE} {STATUS_ICON} {CONTEXT_FOOD} {CONTEXT_PCT} {BASE}"
# TAVS_TITLE_FORMAT_COMPLETE="{FACE} {STATUS_ICON} {COST} {SESSION_ICON} {BASE}"
# TAVS_TITLE_FORMAT_COMPACTING="{FACE} {STATUS_ICON} {CONTEXT_PCT} {BASE}"

# ==============================================================================
# PER-AGENT TITLE FORMATS
# ==============================================================================
# Agent-specific overrides (highest priority)
# CLAUDE_TITLE_FORMAT_PERMISSION="{FACE} {STATUS_ICON} {CONTEXT_FOOD} {CONTEXT_PCT} {MODEL} {BASE}"
# GEMINI_TITLE_FORMAT="{FACE} {STATUS_ICON} {BASE}"  # Gemini uses same format for all states

# ==============================================================================
# CONTEXT ICON CUSTOMIZATION
# ==============================================================================
# Replace default food scale (21-stage, 5% steps):
# TAVS_CONTEXT_FOOD_21=("💧" "🥬" "🥦" "🥒" "🥗" "🥝" "🥑" "🍋" "🍌" "🌽" "🧀" "🥨" "🍞" "🥪" "🌮" "🍕" "🌭" "🍔" "🍟" "🍩" "🍫")
#
# Replace color circles (11-stage, 10% steps):
# TAVS_CONTEXT_CIRCLES_11=("⚪" "🔵" "🔵" "🟢" "🟢" "🟡" "🟠" "🟠" "🔴" "🔴" "⚫")

# ==============================================================================
# STATUSLINE BRIDGE
# ==============================================================================
# To enable context data in titles, add the bridge to your statusline script:
#
# Step 1: Add this line to your ~/.claude/statusline.sh:
#   echo "$input" | ~/.claude/plugins/cache/terminal-agent-visual-signals/tavs/2.0.0/src/agents/claude/statusline-bridge.sh
#
# Step 2: (if no statusline exists) Create ~/.claude/statusline.sh:
#   #!/bin/bash
#   input=$(cat)
#   echo "$input" | ~/.cache/tavs/statusline-bridge.sh
#   echo "$input" | jq -r '"[\(.model.display_name)] \(.context_window.used_percentage // 0)%"'
#
# TAVS_CONTEXT_BRIDGE_MAX_AGE=30    # Seconds before bridge data is stale
```

---

## 14. Key Reusable Patterns

These existing TAVS patterns MUST be followed during implementation:

### Pattern: Atomic State File Writes
**Source:** `session-state.sh:64-79`, `title-state-persistence.sh:173-210`
```bash
local tmp_file
tmp_file=$(mktemp "${state_file}.tmp.XXXXXX" 2>/dev/null)
# ... write to tmp_file ...
mv "$tmp_file" "$state_file" 2>/dev/null
```

### Pattern: Safe Key=Value Parsing (Never Source)
**Source:** `title-state-persistence.sh:104-128`
```bash
while IFS='=' read -r k v; do
    [[ "$k" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$k" ]] && continue
    v="${v%\"}" ; v="${v#\"}"
    if [[ "$k" == "$key" ]]; then value="$v"; break; fi
done < "$state_file"
```

### Pattern: Zsh-Compatible Brace Defaults
**Source:** `title-management.sh:323`, MEMORY.md
```bash
# WRONG: format="${TAVS_TITLE_FORMAT:-{FACE} {STATUS_ICON}}"
# RIGHT:
local _default_format='{FACE} {STATUS_ICON} {AGENTS} {BASE}'
local format="${TAVS_TITLE_FORMAT:-$_default_format}"
```

### Pattern: TTY-Safe State File Isolation
**Source:** `terminal-osc-sequences.sh:68`, MEMORY.md
```bash
# Derive: ${TTY_DEVICE//\//_}  -> _dev_ttys001
# Reverse: ${tty_key//_//}     -> /dev/ttys001 (NOT /dev/${...})
```

### Pattern: Agent Variable Resolution
**Source:** `theme-config-loader.sh:96-138`
```bash
# Prefix: CLAUDE_ -> try CLAUDE_{VAR}, then UNKNOWN_{VAR}, then DEFAULT_{VAR}
eval "value=\${${prefix}${var}:-}"
```

### Pattern: sed-Based JSON Extraction (No jq)
**Source:** `src/agents/claude/trigger.sh:27-28`
```bash
_mode=$(printf '%s' "$_tavs_stdin" | \
    sed -n 's/.*"permission_mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -1)
```

---

## 15. Open Questions

None — all decisions resolved during Q&A process.

**Future considerations** (not blocking implementation):
- Context-based background color gradient (shift bg as context fills)
- Gemini CLI StatusLine bridge (when Gemini adds StatusLine support)
- MCP server exposing TAVS state data back to Claude Code
- Oh My Posh segment integration for TAVS
- Predictive context depletion ("N turns until compaction")

---

## 16. Review Notes

_This section is reserved for reviewer feedback after the mandatory review
phase. Findings from Gemini and Codex reviewers will be consolidated here._

- **Review Status:** Pending
- **Reviewer(s):** TBD
- **Date:** TBD
