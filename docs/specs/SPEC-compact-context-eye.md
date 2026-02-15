# Compact Context Eye — Specification

**Status:** Draft
**Version:** 1.0
**Created:** 2026-02-15
**Last Updated:** 2026-02-15
**Author:** Discovery process (Opus 4.6 + user collaboration)

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Goals & Success Criteria](#2-goals--success-criteria)
3. [Background & Current State](#3-background--current-state)
4. [Architecture & Design](#4-architecture--design)
5. [Visual Reference](#5-visual-reference)
6. [Decisions & Rationale](#6-decisions--rationale)
7. [Implementation Phases](#7-implementation-phases)
8. [File Change Inventory](#8-file-change-inventory)
9. [Constraints & Boundaries](#9-constraints--boundaries)
10. [Rejected Alternatives](#10-rejected-alternatives)
11. [Verification Strategy](#11-verification-strategy)
12. [Configuration Reference](#12-configuration-reference)
13. [Key Reusable Patterns](#13-key-reusable-patterns)
14. [Open Questions](#14-open-questions)
15. [Review Notes](#15-review-notes)

---

## 1. Project Overview

**Name:** Compact Context Eye
**Parent Project:** TAVS (Terminal Agent Visual Signals) v3.0.0

**Summary:** TAVS compact face mode currently displays status-colored emoji in both eye
positions (e.g., `Ǝ[🟧 🟧]E`), with the right eye sometimes overridden by a subagent
count (`Ǝ[🟧 +2]E`). The right eye is underutilized — it duplicates the left eye's
status signal most of the time. This feature repurposes the right eye as a **context
window fill indicator**, turning the face into a two-signal dashboard: left eye = agent
state, right eye = context fill level. Users get instant ambient awareness of context
usage across ALL trigger states without needing to look at a separate token.

**Core Purpose:** Provide always-visible context window fill level directly in the
compact face, using the existing context data infrastructure (bridge + transcript
fallback) from the Dynamic Title Templates feature.

---

## 2. Goals & Success Criteria

| Goal | Success Criterion | Priority |
|------|-------------------|----------|
| Context in right eye | Right eye shows context fill indicator (food, circle, block, etc.) during all non-reset states | Must Have |
| 8 style options | food, food_10, circle, block, block_max, braille, number, percent all work | Must Have |
| Auto-enable in compact mode | Context eye on by default when `TAVS_FACE_MODE="compact"` | Must Have |
| Graceful fallback | When no context data available, right eye shows theme status emoji | Must Have |
| Subagent count un-suppressed | `{AGENTS}` token appears outside face when context eye active | Must Have |
| Em dash reset face | Reset state shows `Ǝ[— —]E` across all themes | Must Have |
| Default theme change | `TAVS_COMPACT_THEME` defaults to `"squares"` (was `"semantic"`) | Must Have |
| Per-agent overrides | `CLAUDE_COMPACT_CONTEXT_STYLE`, `GEMINI_COMPACT_CONTEXT_EYE`, etc. | Should Have |
| User can disable | `TAVS_COMPACT_CONTEXT_EYE="false"` restores original behavior exactly | Must Have |
| Full customizability | All icon arrays, bar characters, and style choices exposed to user.conf | Must Have |
| Zero disruption when disabled | Standard compact mode behavior unchanged when feature off | Must Have |

---

## 3. Background & Current State

### 3.1 Compact Face Mode

Compact mode replaces text-based face eyes with emoji. It's activated via
`TAVS_FACE_MODE="compact"` (default is `"standard"`).

**Current visual:**
```
Standard:  Ǝ[• •]E 🟠 +2 🦊 ~/proj    (text eyes + separate status icon + count)
Compact:   Ǝ[🟠 +2]E 🦊 ~/proj         (emoji eyes embed status + count)
```

**Four themes** define the emoji pairs per state:

| Theme | Processing | Permission | Complete | Reset |
|-------|-----------|------------|----------|-------|
| semantic | `🟠 🟠` / `🟧 🟠` | `🔴 🔴` / `🟥 ⭕` | `✅ ✅` / `🟢 🟢` | `⚪ ⚪` |
| circles | `🟠 🟠` | `🔴 🔴` | `🟢 🟢` | `⚪ ⚪` |
| squares | `🟧 🟧` | `🟥 🟥` | `🟩 🟩` | `⬜ ⬜` |
| mixed | `🟧 🟠` / `🧡 🟠` | `🟥 ⭕` / `🔴 🟥` | `✅ 🟢` / `🟩 🟢` | `⚪ ⬜` |

**Theme definitions:** `src/config/defaults.conf:286-345`
**Face building:** `src/core/face-selection.sh:145-206` (`get_compact_face()`)

### 3.2 Right Eye Override Logic

Currently at `face-selection.sh:190-197`:
```bash
# Override right eye with subagent count when active
if [[ "$state" == "processing" || "$state" == subagent* ]]; then
    if type has_active_subagents &>/dev/null && has_active_subagents 2>/dev/null; then
        local agent_count
        agent_count=$(get_subagent_count 2>/dev/null)
        [[ $agent_count -gt 0 ]] && right="+${agent_count}"
    fi
fi
```

The right eye can be:
- **Status emoji** from theme (both eyes match) — most of the time
- **`+N` subagent count** — only during processing/subagent states with active subagents

### 3.3 Token Suppression in Compact Mode

At `title-management.sh:291-313`, compact mode suppresses two title tokens:
- **`{STATUS_ICON}`** — suppressed because left eye embeds state color
- **`{AGENTS}`** — suppressed because right eye embeds subagent count

### 3.4 Context Data System (from Dynamic Title Templates)

The context data module at `src/core/context-data.sh` provides:
- `load_context_data()` (line 227) — reads bridge state or transcript estimate
- `resolve_context_token()` (line 257) — maps token name + percentage to display value
- 10 token types: CONTEXT_PCT, CONTEXT_FOOD, CONTEXT_FOOD_10, CONTEXT_ICON,
  CONTEXT_NUMBER, CONTEXT_BAR_H, CONTEXT_BAR_HL, CONTEXT_BAR_V, CONTEXT_BAR_VM,
  CONTEXT_BRAILLE
- Global state: `TAVS_CONTEXT_PCT` (0-100 integer or empty)

**Icon arrays** defined at `defaults.conf:170-251`:
- `TAVS_CONTEXT_FOOD_21` (21-stage, 5% steps) — line 182
- `TAVS_CONTEXT_FOOD_11` (11-stage, 10% steps) — line 208
- `TAVS_CONTEXT_CIRCLES_11` (11-stage, 10% steps) — line 224
- `TAVS_CONTEXT_NUMBERS` (11-stage) — line 240
- `TAVS_CONTEXT_BLOCKS` (8-stage) — line 247
- `TAVS_CONTEXT_BRAILLE` (7-stage) — line 251

### 3.5 The Gap

The context data system and compact face mode are **completely independent**. Context
tokens appear in the title format string (`{CONTEXT_FOOD}`, `{CONTEXT_PCT}`), but never
inside the face itself. The right eye wastes information bandwidth by duplicating the
left eye's status color.

---

## 4. Architecture & Design

### 4.1 Two-Signal Face Architecture

```
CURRENT:                           NEW:
Ǝ[ LEFT   RIGHT ]E               Ǝ[ LEFT    RIGHT  ]E
    │       │                          │        │
    │       └── Status color           │        └── Context fill indicator
    │           (duplicate)            │            (food/circle/block/etc.)
    └────── Status color               └────── Status color
            (state signal)                     (state signal — unchanged)
```

The face becomes a **two-channel dashboard**:
- **Left eye** = state signal (processing=🟧, permission=🟥, complete=🟩, etc.)
- **Right eye** = context fill level (scaled emoji or character from 0-100%)

### 4.2 Right Eye Resolution Chain

```
1. Is state "reset"?
   → YES: Both eyes = em dash "—" (resting face)
   → NO: Continue

2. Is TAVS_COMPACT_CONTEXT_EYE == "true"?
   → NO: Use current behavior (status pair, or +N if subagents)
   → YES: Continue

3. Call load_context_data()
   Is TAVS_CONTEXT_PCT non-empty?
   → YES: Resolve via TAVS_COMPACT_CONTEXT_STYLE mapping
          food → resolve_context_token("CONTEXT_FOOD", pct)
          circle → resolve_context_token("CONTEXT_ICON", pct)
          (square was removed — blends with squares theme left eye)
          block → resolve_context_token("CONTEXT_BAR_V", pct)
          block_max → resolve_context_token("CONTEXT_BAR_VM", pct)
          braille → resolve_context_token("CONTEXT_BRAILLE", pct)
          number → resolve_context_token("CONTEXT_NUMBER", pct)
          percent → resolve_context_token("CONTEXT_PCT", pct)
          food_10 → resolve_context_token("CONTEXT_FOOD_10", pct)
   → NO: Fallback to theme status emoji (graceful degradation)
```

### 4.3 Subagent Count Displacement

When context eye is enabled, the right eye is occupied by context. The subagent
count (`+N`) moves from the face to the `{AGENTS}` title token — the same token
used in standard mode. The `{AGENTS}` suppression logic in `compose_title()` is
lifted when context eye is active.

**Token suppression matrix:**

| Mode | `{STATUS_ICON}` | `{AGENTS}` |
|------|-----------------|------------|
| Standard mode | Shown | Shown |
| Compact, context eye OFF | Suppressed | Suppressed (in right eye) |
| Compact, context eye ON | Suppressed | **Shown** (context in right eye) |

### 4.4 Context Data Loading

`load_context_data()` at `context-data.sh:227` currently resets and reloads every
call. When compact context eye is enabled, this function is called from inside
`get_compact_face()` (for the right eye) AND potentially again from `compose_title()`
(for any `{CONTEXT_*}` title format tokens). To prevent double-loading, add a guard:

```bash
load_context_data() {
    [[ -n "${_TAVS_CONTEXT_LOADED:-}" ]] && return 0
    _TAVS_CONTEXT_LOADED=1
    # ... existing logic ...
}
```

The `_TAVS_CONTEXT_LOADED` flag is process-scoped (each trigger.sh invocation
is a fresh process, so no stale state across invocations).

---

## 5. Visual Reference

### 5.1 Style Catalog (at different context levels, squares theme)

**At 25% context (early session):**

| Style | Face | Full Title |
|-------|------|------------|
| `food` (default) | `Ǝ[🟧 🥝]E` | `Ǝ[🟧 🥝]E 🦊 ~/proj` |
| `circle` | `Ǝ[🟧 🔵]E` | `Ǝ[🟧 🔵]E 🦊 ~/proj` |
| ~~`square`~~ | ~~removed~~ | ~~blends with squares theme left eye~~ |
| `block` | `Ǝ[🟧 ▂]E` | `Ǝ[🟧 ▂]E 🦊 ~/proj` |
| `block_max` | `Ǝ[🟧 ▂▒]E` | `Ǝ[🟧 ▂▒]E 🦊 ~/proj` |
| `braille` | `Ǝ[🟧 ⠄]E` | `Ǝ[🟧 ⠄]E 🦊 ~/proj` |
| `number` | `Ǝ[🟧 2️⃣]E` | `Ǝ[🟧 2️⃣]E 🦊 ~/proj` |
| `percent` | `Ǝ[🟧 25%]E` | `Ǝ[🟧 25%]E 🦊 ~/proj` |
| `food_10` | `Ǝ[🟧 🥦]E` | `Ǝ[🟧 🥦]E 🦊 ~/proj` |

**At 50% context (mid session):**

| Style | Face | With 2 Subagents |
|-------|------|------------------|
| `food` | `Ǝ[🟧 🧀]E` | `Ǝ[🟧 🧀]E +2 🦊 ~/proj` |
| `circle` | `Ǝ[🟧 🟡]E` | `Ǝ[🟧 🟡]E +2 🦊 ~/proj` |
| `block` | `Ǝ[🟧 ▄]E` | `Ǝ[🟧 ▄]E +2 🦊 ~/proj` |
| `block_max` | `Ǝ[🟧 ▄▒]E` | `Ǝ[🟧 ▄▒]E +2 🦊 ~/proj` |
| `percent` | `Ǝ[🟧 50%]E` | `Ǝ[🟧 50%]E +2 🦊 ~/proj` |

**At 85% context (danger zone, permission state):**

| Style | Face | Notes |
|-------|------|-------|
| `food` | `Ǝ[🟥 🍔]E` | Burger = danger, permission red |
| `circle` | `Ǝ[🟥 🔴]E` | Double red = urgent |
| `block` | `Ǝ[🟥 ▇]E` | Nearly full block |
| `block_max` | `Ǝ[🟥 ▇▒]E` | Nearly full with max reference |
| `percent` | `Ǝ[🟥 85%]E` | Explicit number |

### 5.2 Per-Agent Faces (food style at 50%)

| Agent | Face | Frame Template |
|-------|------|----------------|
| Claude | `Ǝ[🟧 🧀]E` | `Ǝ[{L} {R}]E` |
| Gemini | `ʕ🟧ᴥ🧀ʔ` | `ʕ{L}ᴥ{R}ʔ` |
| Codex | `ฅ^🟧ﻌ🧀^ฅ` | `ฅ^{L}ﻌ{R}^ฅ` |
| OpenCode | `(🟧-🧀)` | `({L}-{R})` |

### 5.3 Reset Face (all themes)

| Agent | Reset Face |
|-------|------------|
| Claude | `Ǝ[— —]E` |
| Gemini | `ʕ—ᴥ—ʔ` |
| Codex | `ฅ^—ﻌ—^ฅ` |
| OpenCode | `(—-—)` |

### 5.4 Food Scale Progression (right eye only)

```
 0%  💧   fresh start
 5%  🥬   barely started
10%  🥦   getting going
15%  🥒   light usage
20%  🥗   warming up
25%  🥝   quarter full
30%  🥑   building up
35%  🍋   moderate
40%  🍌   approaching half
45%  🌽   almost half
50%  🧀   half full
55%  🥨   past halfway
60%  🍞   well used
65%  🥪   substantial
70%  🌮   getting heavy
75%  🍕   three quarters
80%  🌭   heavy usage
85%  🍔   danger zone
90%  🍟   critical
95%  🍩   almost full
100% 🍫   maxed out
```

---

## 6. Decisions & Rationale

### D01: Right Eye Priority (Context vs Subagent Count)

**Question:** When subagents are active AND context eye is enabled, what occupies the
right eye — context indicator or subagent count?
**Options:**
- A) Context always wins — subagent count moves to `{AGENTS}` token outside face
- B) Combine both in right eye: `🍕+2`
- C) Subagent wins (current behavior), context only when no subagents
- D) Configurable priority setting

**Decision:** A) Context always wins
**Reasoning:** Context % is the primary motivating use case for this feature — users
always want to see it. The subagent count is still visible via the `{AGENTS}` title
token, just not inside the face. No information is lost.

### D02: Default Context Style

**Question:** Which visualization should ship as default for the right eye?
**Options:**
- A) Food (21-stage, distinctive shapes)
- B) Circle (color gradient, matches familiar pattern)
- C) Square (matches the new squares theme)
- D) Block character (minimal, text-like)

**Decision:** A) Food
**Reasoning:** Food emoji are **visually distinct** from the left eye's status emoji.
If both eyes used the same shape (e.g., squares left + squares right), they'd blend
together at a glance. Different shape = instant "state | context" differentiation.

### D03: Auto-Enable Behavior

**Question:** Should context eye require explicit opt-in or auto-enable in compact mode?
**Options:**
- A) Auto-enable when `TAVS_FACE_MODE="compact"` (disable with `"false"`)
- B) Separate explicit opt-in: `TAVS_COMPACT_CONTEXT_EYE="true"`

**Decision:** A) Auto-enable
**Reasoning:** Compact mode is already opt-in (`TAVS_FACE_MODE="compact"` is not
default). Users who choose compact mode want the richest information density. Making
context eye opt-in would hide the feature from most users. Disable path:
`TAVS_COMPACT_CONTEXT_EYE="false"`.

### D04: No-Data Fallback

**Question:** What does the right eye show when no context data is available?
**Options:**
- A) Theme status emoji (current behavior — both eyes match)
- B) Empty/blank right eye
- C) Special "no data" indicator

**Decision:** A) Theme status emoji
**Reasoning:** Graceful degradation. The face looks exactly like current compact mode
when there's no data. No visual broken state, no confusing empty eye.

### D05: Default Compact Theme

**Question:** Which theme should be the default for compact mode?
**Options:**
- A) Semantic (current default — meaningful emoji, varied)
- B) Squares (bold blocks, clean, consistent)
- C) Circles (round emoji, uniform)
- D) Mixed (asymmetric pairs)

**Decision:** B) Squares
**Reasoning:** User preference. Square emoji render consistently across platforms and
provide a bold, clean look. The contrast with food emoji in the right eye (different
shape) makes the two-signal dashboard more readable.

### D06: Reset Face Style

**Question:** What should the reset/resting face look like in compact mode?
**Options:**
- A) Em dashes: `Ǝ[— —]E` (closed eyes, AI irony)
- B) Tilde: `Ǝ[~ ~]E` (dreamy)
- C) Underscore: `Ǝ[_ _]E` (heavy lids)
- D) Theme emoji: `Ǝ[⬜ ⬜]E` (current behavior)

**Decision:** A) Em dashes
**Reasoning:** Clean "closed eyes" aesthetic. The em dash AI irony adds personality
(AI agents historically overuse em dashes, making it a meta-commentary). Text
characters also visually distinguish reset from active states that use emoji.

### D07: Git Worktree

**Question:** Should implementation use a git worktree?
**Decision:** Yes. Branch `feature/compact-context-eye` in worktree at
`../tavs-compact-context-eye`.

---

## 7. Implementation Phases

### Phase 0: Git Worktree Setup

**Scope:** Create isolated development environment.
**Depends On:** Nothing.

**Acceptance Criteria:**
- [ ] Branch `feature/compact-context-eye` exists
- [ ] Worktree at `../tavs-compact-context-eye` is functional

---

### Phase 1: Core Implementation

**Scope:** Modify compact face building, title composition, context data, defaults,
and agent variable resolution. This is the main code phase.
**Depends On:** Phase 0

**Changes:**

**1a. `src/core/face-selection.sh` — `get_compact_face()` (lines 145-206)**

Extend the function to resolve context data into the right eye:
- After emoji pair split (line 188), add context eye resolution block
- Handle reset state with em dashes (override both eyes)
- Map `TAVS_COMPACT_CONTEXT_STYLE` to context token names
- Call `load_context_data()` + `resolve_context_token()` for right eye
- Preserve current subagent count behavior when context eye disabled
- Use agent-resolved `COMPACT_CONTEXT_STYLE` / `COMPACT_CONTEXT_EYE` variables

**1b. `src/core/title-management.sh` — `compose_title()` (lines 306-313)**

Un-suppress `{AGENTS}` token when context eye is active:
- Add `_context_eye_active` flag based on compact mode + context eye setting
- Modify suppression condition: show `{AGENTS}` if NOT compact OR context eye active

**1c. `src/core/context-data.sh` — `load_context_data()` (line 227)**

Add double-load guard:
- `_TAVS_CONTEXT_LOADED` flag prevents re-reading state file in same invocation
- ~~Add `CONTEXT_SQUARE` to `resolve_context_token()` case statement~~ (removed — square style dropped)

**1d. `src/config/defaults.conf`**

- Change `TAVS_COMPACT_THEME` default from `"semantic"` to `"squares"` (line 284)
- Add new settings: `TAVS_COMPACT_CONTEXT_EYE="true"`, `TAVS_COMPACT_CONTEXT_STYLE="food"`
- ~~Add new array: `TAVS_CONTEXT_SQUARES_11`~~ (removed — square style dropped)
- Update all 4 `COMPACT_*_RESET` arrays to `("— —")` (lines 300, 315, 330, 345)

**1e. `src/core/theme-config-loader.sh` — `_resolve_agent_variables()` (line 122)**

Add to vars array: `COMPACT_CONTEXT_STYLE`, `COMPACT_CONTEXT_EYE`

**Acceptance Criteria:**
- [ ] `TAVS_FACE_MODE=compact ./trigger.sh processing` → food emoji in right eye
- [ ] `TAVS_FACE_MODE=compact TAVS_COMPACT_CONTEXT_STYLE=block ./trigger.sh processing` → block char
- [ ] `TAVS_FACE_MODE=compact ./trigger.sh reset` → em dashes in both eyes
- [ ] `TAVS_FACE_MODE=compact TAVS_COMPACT_CONTEXT_EYE=false ./trigger.sh processing` → old behavior
- [ ] `TAVS_FACE_MODE=compact ./trigger.sh subagent-start && ./trigger.sh subagent-start` → `+2` outside face
- [ ] All 8 context styles produce correct output at 0%, 50%, 100%
- [ ] Per-agent override: `CLAUDE_COMPACT_CONTEXT_STYLE=block ./trigger.sh processing` → block for Claude
- [ ] No context data → right eye falls back to theme status emoji
- [ ] Squares is new default theme (left eye = 🟧 for processing)

---

### Phase 2: Documentation & Configuration

**Scope:** Update user-facing docs, config template, and reference documentation.
**Depends On:** Phase 1

**Changes:**

- `src/config/user.conf.template` — add compact context eye section with all 8 styles,
  visual examples, per-agent override examples, disable instructions
- `CLAUDE.md` — update compact face mode section with context eye, new default theme,
  em dash reset, visual examples
- `docs/reference/dynamic-titles.md` — add comprehensive "Compact Context Eye" section
  with full visual reference card

**Acceptance Criteria:**
- [ ] user.conf.template documents all new settings with examples
- [ ] CLAUDE.md updated with context eye overview and examples
- [ ] dynamic-titles.md has full style catalog (all 8 styles × multiple percentages)

---

### Phase 3: Deploy & Integration Test

**Scope:** Copy to plugin cache and test live with Claude Code.
**Depends On:** Phases 1-2

**Deploy:**
```bash
CACHE="$HOME/.claude/plugins/cache/terminal-agent-visual-signals/tavs/3.0.0"
cp src/core/*.sh "$CACHE/src/core/"
mkdir -p "$CACHE/src/config" && cp src/config/*.conf "$CACHE/src/config/"
cp src/agents/claude/*.sh "$CACHE/src/agents/claude/"
```

**Live test sequence:**
1. Processing → context food in right eye, status square in left
2. Permission → context food + permission red in left
3. Complete → context visible
4. Idle → context stays visible (ambient awareness)
5. Compacting → watch right eye change as context drops
6. Subagent → `+N` outside face, context in right eye
7. Tool error → brief flash with context
8. Reset → em dash resting eyes
9. Test without bridge → verify fallback to theme emoji
10. Test each of 8 styles live
11. Test context eye disabled → exact old behavior

**Acceptance Criteria:**
- [ ] All 8 trigger states produce correct titles in live session
- [ ] Context updates in real-time via bridge
- [ ] Fallback works without bridge
- [ ] No regressions in standard mode (TAVS_FACE_MODE=standard unchanged)
- [ ] No regressions in compact mode with context eye disabled

---

## 8. File Change Inventory

### Modified Files

| File | Location | Change | Est. Lines |
|------|----------|--------|------------|
| `src/core/face-selection.sh` | `get_compact_face()` line 145 | Context eye resolution, em dash reset, style mapping | ~30 |
| `src/core/title-management.sh` | `compose_title()` line 306 | Un-suppress `{AGENTS}` when context eye active | ~10 |
| `src/core/context-data.sh` | `load_context_data()` line 227 | Double-load guard, shared style→token helper | ~25 |
| `src/config/defaults.conf` | Lines 284, 300, 315, 330, 345 | Theme default, new settings, squares array, em dash resets | ~25 |
| `src/core/theme-config-loader.sh` | `_resolve_agent_variables()` line 122 | Add COMPACT_CONTEXT_STYLE, COMPACT_CONTEXT_EYE to vars | ~3 |
| `src/config/user.conf.template` | After compact face section | New context eye settings, visual examples | ~40 |
| `CLAUDE.md` | Compact face mode section | Context eye, default theme, reset face | ~20 |
| `docs/reference/dynamic-titles.md` | New section | Full compact context eye reference | ~60 |

### New Files

None — all changes modify existing files.

### Unchanged Files

| File | Why Unchanged |
|------|---------------|
| `hooks/hooks.json` | No new hook events needed |
| `src/core/spinner.sh` | Spinner independent of compact eye |
| `src/core/session-icon.sh` | Session icons unchanged |
| `src/agents/claude/statusline-bridge.sh` | Bridge already writes all needed data |
| `src/agents/claude/trigger.sh` | No new data extraction needed |

---

## 9. Constraints & Boundaries

### Out of Scope

- Adding horizontal bars (5-char or 10-char) as compact eye styles — too wide for face
- Animated/changing context eye (e.g., blinking at high %) — complexity not justified
- Context-based background color shifts — separate future feature
- Gemini/Codex/OpenCode agent-specific bridges — existing bridge already works
- New trigger events or hook routes
- Changes to standard (non-compact) face mode

### Technical Constraints

- **Bash 3.2 compatibility** — no namerefs (`local -n`), no `${var^^}`, use `eval` + `tr`
- **Zsh compatibility** — intermediate vars for brace defaults
- **Atomic writes** — state files use mktemp+mv pattern
- **No jq dependency** — sed-based extraction only
- **Per-TTY isolation** — all state files use `{TTY_SAFE}` suffix
- **Double-load guard** — `_TAVS_CONTEXT_LOADED` prevents redundant state file reads

### Dependencies

- Dynamic Title Templates feature (merged — provides context data infrastructure)
- StatusLine bridge (optional — has transcript fallback)
- `~/.cache/tavs/` directory (created by `get_spinner_state_dir()`)

---

## 10. Rejected Alternatives

| Alternative | Why Rejected |
|-------------|--------------|
| Horizontal bar in eye (`▓▓░░░`) | 5+ characters too wide for eye position — distorts face frame |
| Context replaces left eye too | Left eye state signal is essential — users need to know processing vs permission |
| Separate `{CONTEXT_EYE}` title token | Adds complexity; embedding in face is simpler and always visible |
| Subagent count + context combined (`🍕+2`) | Makes face wider, harder to scan, two different data types crammed together |
| Context eye only for certain states | User explicitly requested "during all hooks" — always visible |
| Tilde or underscore for reset | User chose em dash for the AI irony and clean aesthetic |
| Keep semantic as default theme | User explicitly requested squares |

---

## 11. Verification Strategy

### Unit-Level Testing

```bash
# Source modules
source src/config/defaults.conf
source src/core/context-data.sh
source src/core/face-selection.sh

# Test each style resolves correctly
for style in food food_10 circle block block_max braille number percent; do
    echo "$style at 50%: ..."
    # Verify resolve_context_token produces expected output
done

# Test edge cases
resolve_context_token CONTEXT_FOOD 0    # → 💧
resolve_context_token CONTEXT_FOOD 100  # → 🍫
resolve_context_token CONTEXT_BAR_VM 85 # → ▇▒
```

### Integration Testing

```bash
# Test compact context eye with mock data
TAVS_FACE_MODE=compact ./src/core/trigger.sh processing
# → Verify food emoji in right eye if bridge data exists

# Test all 8 styles
for style in food food_10 circle block block_max braille number percent; do
    TAVS_FACE_MODE=compact TAVS_COMPACT_CONTEXT_STYLE=$style \
        ./src/core/trigger.sh processing
done

# Test em dash reset
TAVS_FACE_MODE=compact ./src/core/trigger.sh reset
# → Ǝ[— —]E (or similar with current title mode)

# Test no-data fallback
# (remove bridge state file, ensure no transcript)
TAVS_FACE_MODE=compact ./src/core/trigger.sh processing
# → Should show theme status pair (🟧 🟧)

# Test context eye disabled
TAVS_FACE_MODE=compact TAVS_COMPACT_CONTEXT_EYE=false \
    ./src/core/trigger.sh processing
# → Old behavior exactly

# Test subagent count displacement
TAVS_FACE_MODE=compact ./src/core/trigger.sh subagent-start
TAVS_FACE_MODE=compact ./src/core/trigger.sh subagent-start
# → Context in right eye, +2 as separate {AGENTS} token
```

### Live Claude Code Testing

1. Deploy to plugin cache
2. Start Claude Code with `TAVS_FACE_MODE=compact` in user.conf
3. Submit prompt → observe processing face with context right eye
4. Wait for permission → observe permission red + context food
5. Complete response → observe complete + context
6. Test each style by changing user.conf and restarting
7. Remove bridge → verify fallback to status emoji
8. Disable context eye → verify original compact behavior

---

## 12. Configuration Reference

### New Settings

```bash
# Compact Context Eye (auto-enabled in compact mode)
# Shows context fill level in the right eye of compact faces.
TAVS_COMPACT_CONTEXT_EYE="true"       # "true" | "false"

# Context style for the right eye.
# Available: food, food_10, circle, block, block_max, braille, number, percent
TAVS_COMPACT_CONTEXT_STYLE="food"

# Default compact theme (changed from "semantic")
TAVS_COMPACT_THEME="squares"
```

### ~~New Icon Array~~ (Removed)

The `square` context style and `TAVS_CONTEXT_SQUARES_11` array were removed during
implementation because square context icons blend with the squares theme left eye,
defeating the two-signal dashboard purpose. Food (default) provides visual distinction.

### Per-Agent Overrides

Via `_resolve_agent_variables()`:
```bash
# Different context style per agent
CLAUDE_COMPACT_CONTEXT_STYLE="food"
GEMINI_COMPACT_CONTEXT_STYLE="block"

# Disable context eye for specific agent
CODEX_COMPACT_CONTEXT_EYE="false"
```

### Style ↔ Token Mapping

| Style Value | Token Name | Source Array | Steps |
|-------------|------------|-------------|-------|
| `food` | `CONTEXT_FOOD` | `TAVS_CONTEXT_FOOD_21` | 21 (5%) |
| `food_10` | `CONTEXT_FOOD_10` | `TAVS_CONTEXT_FOOD_11` | 11 (10%) |
| `circle` | `CONTEXT_ICON` | `TAVS_CONTEXT_CIRCLES_11` | 11 (10%) |
| ~~`square`~~ | ~~`CONTEXT_SQUARE`~~ | ~~removed~~ | — |
| `block` | `CONTEXT_BAR_V` | `TAVS_CONTEXT_BLOCKS` | 8 |
| `block_max` | `CONTEXT_BAR_VM` | `TAVS_CONTEXT_BLOCKS` + `BAR_MAX` | 8 |
| `braille` | `CONTEXT_BRAILLE` | `TAVS_CONTEXT_BRAILLE` | 7 |
| `number` | `CONTEXT_NUMBER` | `TAVS_CONTEXT_NUMBERS` | 11 (10%) |
| `percent` | `CONTEXT_PCT` | N/A (text format) | Continuous |

### Customizability Layers

Users can customize at every level:

1. **Enable/disable**: `TAVS_COMPACT_CONTEXT_EYE="false"`
2. **Style selection**: 9 built-in options
3. **Replace icon arrays**: `TAVS_CONTEXT_FOOD_21=(custom emoji)` in user.conf
4. **Bar characters**: `TAVS_CONTEXT_BAR_FILL`, `TAVS_CONTEXT_BAR_EMPTY`, `TAVS_CONTEXT_BAR_MAX`
5. **Per-agent style**: `CLAUDE_COMPACT_CONTEXT_STYLE="block"`
6. **Combine face + title**: `TAVS_TITLE_FORMAT_PERMISSION="{FACE} {CONTEXT_PCT} {BASE}"`
   gives `Ǝ[🟥 🍔]E 85% ~/proj` (food in eye + percentage in title)

---

## 13. Key Reusable Patterns

### Pattern: Context Token Resolution (existing)
**Source:** `context-data.sh:257-281`
```bash
resolve_context_token() {
    local token="$1"
    local pct="${2:-}"
    [[ -z "$pct" ]] && echo "" && return 0
    case "$token" in
        CONTEXT_FOOD)     _get_icon_from_array "TAVS_CONTEXT_FOOD_21" "$pct" 5 ;;
        CONTEXT_ICON)     _get_icon_from_array "TAVS_CONTEXT_CIRCLES_11" "$pct" 10 ;;
        # ... etc
    esac
}
```

### Pattern: Style-to-Token Mapping (shared helper in context-data.sh)
```bash
# Single source of truth — used by face-selection.sh and title-management.sh
_ctx_token=$(_context_style_to_token "$_ctx_style")
right=$(resolve_context_token "$_ctx_token" "$TAVS_CONTEXT_PCT")
```

### Pattern: Agent Variable Resolution (existing)
**Source:** `theme-config-loader.sh:96-138`
```bash
# Prefix: CLAUDE_ → try CLAUDE_{VAR}, then UNKNOWN_{VAR}, then DEFAULT_{VAR}
eval "value=\${${prefix}${var}:-}"
```

### Pattern: Compact Token Suppression (existing, to be modified)
**Source:** `title-management.sh:306-313`
```bash
local agents=""
if [[ "$_compact_with_face" != "true" ]]; then
    # Show agents token
fi
```

---

## 14. Open Questions

None — all decisions resolved during brainstorming Q&A.

**Future considerations** (not blocking implementation):
- Context-based background color gradient (shift bg color as context fills)
- Animated context eye (blink or pulse at high percentages)
- Horizontal bar as title token combined with context eye
- Compact face mode preset gallery (pre-configured style bundles)

---

## 15. Review Notes

_This section is reserved for reviewer feedback after the mandatory review phase._

- **Review Status:** Pending
- **Reviewer(s):** TBD
- **Date:** TBD
