# Implementation Plan: Compact Context Eye

**Spec:** `docs/specs/SPEC-compact-context-eye.md`
**Created:** 2026-02-15
**Last Updated:** 2026-02-15
**Agent:** Fresh agent from /plan-from-spec
**Branch:** `feature/compact-context-eye` (worktree at `../tavs-compact-context-eye`)

---

## Context

Compact face mode shows status emoji in both eyes (`Ǝ[🟧 🟧]E`), with the right eye
sometimes overridden by subagent count (`Ǝ[🟧 +2]E`). The right eye is underutilized.
This feature repurposes the right eye as a **context window fill indicator**, turning
the face into a two-signal dashboard: left eye = state, right eye = context fill level.

Additionally: default compact theme changes to squares, reset face gets em dashes.

### Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Right eye priority | Context always wins | Primary use case; subagent count moves to `{AGENTS}` token |
| Default context style | Food (21-stage) | Visually distinct from left eye status squares |
| Auto-enable | Yes, when compact mode is active | Compact is already opt-in; fewer setup steps |
| No-data fallback | Theme status emoji (graceful degradation) | Face looks normal when no data |
| Default status theme | Squares (changed from semantic) | User preference; bold, clean look |
| Reset face | Em dashes `— —` across all themes | Clean "closed eyes" with AI irony |
| Square context style | **Removed** | Would blend with squares theme left eye, defeating two-signal purpose |
| Per-agent overrides | Supported via `_resolve_agent_variables()` | Flexible per-agent customization |

## Prerequisites

- Dynamic Title Templates feature merged (confirmed — PR #7)
- Context data module (`src/core/context-data.sh`) with `load_context_data()` (line 227)
  and `resolve_context_token()` (line 257) — confirmed
- Worktree at `../tavs-compact-context-eye` — confirmed (Phase 0 complete)

---

## Phase 0: Git Worktree Setup — COMPLETE

Branch `feature/compact-context-eye` created, worktree functional, spec/plan/progress
committed as `cd7723c`.

---

## Phase 1: Core Implementation

Five sub-steps modifying 5 existing files. No new files created.
**8 context styles** (not 9 — `square` removed to avoid blending with squares theme).

Available styles: `food`, `food_10`, `circle`, `block`, `block_max`, `braille`, `number`, `percent`

### 1d. Update `src/config/defaults.conf` (DO FIRST)

This step defines the settings and arrays referenced by all other files.

**4 changes:**

**Change 1 — Default theme** (line 300 in worktree):
```bash
# Before:
TAVS_COMPACT_THEME="semantic"
# After:
TAVS_COMPACT_THEME="squares"
```

**Change 2 — New settings** (insert after the `TAVS_COMPACT_THEME` line):
```bash
# Compact Context Eye — shows context fill level in the right eye
# Auto-enabled when TAVS_FACE_MODE="compact". Disable with "false".
TAVS_COMPACT_CONTEXT_EYE="true"

# Context visualization style for the right eye.
# Available: food, food_10, circle, block, block_max, braille, number, percent
# (NOT "square" — would blend with squares theme left eye)
TAVS_COMPACT_CONTEXT_STYLE="food"
```

**Change 3 — Em dash reset arrays** (4 lines across the file):
```bash
# Line 316 (was '⚪ ⚪'):
COMPACT_SEMANTIC_RESET=("— —")

# Line 331 (was '⚪ ⚪'):
COMPACT_CIRCLES_RESET=("— —")

# Line 346 (was '⬜ ⬜'):
COMPACT_SQUARES_RESET=("— —")

# Line 361 (was '⚪ ⬜'):
COMPACT_MIXED_RESET=("— —")
```

**Change 4 — Update section header comment** (lines 292-298):
Update to mention context eye and the squares default.

**No TAVS_CONTEXT_SQUARES_11 array** — square context style removed.

### 1c. Add `_TAVS_CONTEXT_LOADED` guard to `src/core/context-data.sh`

**Purpose:** Prevent double-loading when `load_context_data()` is called from both
`get_compact_face()` (for right eye) AND `compose_title()` (for `{CONTEXT_*}` tokens).

**Guard** — add at top of `load_context_data()` (line 228, before globals reset):
```bash
load_context_data() {
    # Prevent re-reading state file in same trigger invocation
    # (_TAVS_CONTEXT_LOADED is process-scoped — fresh per trigger.sh run)
    [[ -n "${_TAVS_CONTEXT_LOADED:-}" ]] && return 0
    _TAVS_CONTEXT_LOADED=1

    # Reset globals (existing code continues here)
    TAVS_CONTEXT_PCT=""
    ...
```

**No CONTEXT_SQUARE token** — square context style removed. The existing
`resolve_context_token()` case statement at line 268 is unchanged.

### 1a. Modify `get_compact_face()` in `src/core/face-selection.sh`

**Target:** Lines 145-206 of `get_compact_face()`

**Current flow** (verified):
1. Map state → `state_upper`, build array name `COMPACT_{theme}_{state}` (lines 152-172)
2. Random pair selection, split into `left`/`right` (lines 182-188)
3. Override right eye with `+N` if subagents active (lines 190-197)
4. Substitute into `{L}`/`{R}` frame template (lines 199-205)

**New flow** — REPLACE lines 190-197 (the existing subagent override block) with:

```bash
    # --- Context eye resolution ---
    # Two-signal dashboard: left eye = state color, right eye = context fill level
    local _ctx_eye="${TAVS_COMPACT_CONTEXT_EYE:-true}"

    # Reset state: em dash resting eyes (override both, regardless of context eye)
    if [[ "$state" == "reset" ]]; then
        left="—"
        right="—"
    elif [[ "$_ctx_eye" == "true" ]]; then
        # Context eye enabled: resolve right eye from context data
        if type load_context_data &>/dev/null; then
            load_context_data 2>/dev/null
        fi

        if [[ -n "${TAVS_CONTEXT_PCT:-}" ]]; then
            # Map style name to context token for resolve_context_token()
            local _ctx_style="${TAVS_COMPACT_CONTEXT_STYLE:-food}"
            local _ctx_token=""
            case "$_ctx_style" in
                food)      _ctx_token="CONTEXT_FOOD" ;;
                food_10)   _ctx_token="CONTEXT_FOOD_10" ;;
                circle)    _ctx_token="CONTEXT_ICON" ;;
                block)     _ctx_token="CONTEXT_BAR_V" ;;
                block_max) _ctx_token="CONTEXT_BAR_VM" ;;
                braille)   _ctx_token="CONTEXT_BRAILLE" ;;
                number)    _ctx_token="CONTEXT_NUMBER" ;;
                percent)   _ctx_token="CONTEXT_PCT" ;;
            esac

            if [[ -n "$_ctx_token" ]]; then
                local _ctx_val
                _ctx_val=$(resolve_context_token "$_ctx_token" "$TAVS_CONTEXT_PCT")
                [[ -n "$_ctx_val" ]] && right="$_ctx_val"
            fi
        fi
        # If TAVS_CONTEXT_PCT is empty → right keeps theme emoji (graceful fallback)
    else
        # Context eye DISABLED: preserve current subagent count behavior exactly
        if [[ "$state" == "processing" || "$state" == subagent* ]]; then
            if type has_active_subagents &>/dev/null && has_active_subagents 2>/dev/null; then
                local agent_count
                agent_count=$(get_subagent_count 2>/dev/null)
                [[ $agent_count -gt 0 ]] && right="+${agent_count}"
            fi
        fi
    fi
```

**Key points:**
- The existing subagent override block (lines 190-197) is **completely replaced**
- Original subagent logic moves into the `else` branch (context eye disabled)
- When context eye is enabled, subagent count appears via `{AGENTS}` title token instead
- Reset state overrides BOTH eyes with em dash `—`, regardless of context eye setting
- The `type load_context_data` guard prevents errors if context-data.sh wasn't loaded
- No `square` in the case statement — intentionally excluded

### 1b. Modify `compose_title()` in `src/core/title-management.sh`

**Target:** Lines 306-313 (agents suppression block)

**Current code** (verified at lines 308-313):
```bash
    # Get subagent count token (suppressed in compact mode — embedded as right eye)
    # Same logic: only suppress when compact mode AND faces are actually rendering
    local agents=""
    if [[ "$_compact_with_face" != "true" ]]; then
        if [[ "$state" == "processing" || "$state" == subagent* ]] && type get_subagent_title_suffix &>/dev/null; then
            agents=$(get_subagent_title_suffix 2>/dev/null)
        fi
    fi
```

**New code** — un-suppress `{AGENTS}` when context eye is active:
```bash
    # Get subagent count token
    # In compact mode without context eye: suppressed (embedded as right eye)
    # In compact mode WITH context eye: shown (right eye = context, not +N)
    local agents=""
    local _context_eye_active=false
    [[ "$_compact_with_face" == "true" && "${TAVS_COMPACT_CONTEXT_EYE:-true}" == "true" ]] && _context_eye_active=true

    if [[ "$_compact_with_face" != "true" ]] || [[ "$_context_eye_active" == "true" ]]; then
        if [[ "$state" == "processing" || "$state" == subagent* ]] && type get_subagent_title_suffix &>/dev/null; then
            agents=$(get_subagent_title_suffix 2>/dev/null)
        fi
    fi
```

**`{STATUS_ICON}` stays suppressed** (lines 291-293) — left eye still embeds state color.

**Token suppression matrix after change:**

| Mode | `{STATUS_ICON}` | `{AGENTS}` |
|------|-----------------|------------|
| Standard mode | Shown | Shown |
| Compact, context eye OFF | Suppressed | Suppressed (in right eye) |
| Compact, context eye ON | Suppressed | **Shown** (context in right eye) |

### 1e. Add vars to `_resolve_agent_variables()` in `src/core/theme-config-loader.sh`

**Target:** vars array at lines 103-122

**Add after** `TITLE_FORMAT_RESET` (line 121):
```bash
        # Per-agent compact context eye overrides
        COMPACT_CONTEXT_STYLE
        COMPACT_CONTEXT_EYE
```

**How this enables per-agent customization:**
```bash
# In user.conf:
CLAUDE_COMPACT_CONTEXT_STYLE="food"      # Resolves → COMPACT_CONTEXT_STYLE="food"
GEMINI_COMPACT_CONTEXT_STYLE="block"     # Resolves → COMPACT_CONTEXT_STYLE="block"
CODEX_COMPACT_CONTEXT_EYE="false"        # Resolves → COMPACT_CONTEXT_EYE="false"
```

**Note:** These won't match the `DEFAULT_` fallback condition (line 136) which only
triggers for `*_BASE`, `*_PROCESSING`, etc. This is correct — `TAVS_COMPACT_CONTEXT_*`
globals act as the default; per-agent vars only need `PREFIX_` resolution.

### Files Modified (Phase 1 Summary)

| File | Function/Section | Change | Est. Lines |
|------|------------------|--------|------------|
| `src/config/defaults.conf` | Compact section, reset arrays | Theme default, new settings, em dash resets | ~15 |
| `src/core/context-data.sh` | `load_context_data()` | Add `_TAVS_CONTEXT_LOADED` guard (2 lines) | ~3 |
| `src/core/face-selection.sh` | `get_compact_face()` | Context eye resolution, em dash reset, style mapping | ~35 |
| `src/core/title-management.sh` | `compose_title()` | Un-suppress `{AGENTS}` when context eye active | ~8 |
| `src/core/theme-config-loader.sh` | `_resolve_agent_variables()` | Add 2 vars to resolution array | ~3 |

### Phase 1 Verification

```bash
# --- Basic functionality ---

# Test context eye with food (default) — needs bridge data or transcript
TAVS_FACE_MODE=compact ./src/core/trigger.sh processing
# → Food emoji in right eye (if data) or 🟧 theme emoji (if no data)

# Test reset em dashes (all 4 themes)
for theme in semantic circles squares mixed; do
    TAVS_FACE_MODE=compact TAVS_COMPACT_THEME=$theme \
        ./src/core/trigger.sh reset
done
# → All should show — — in eyes

# --- All 8 styles ---

for style in food food_10 circle block block_max braille number percent; do
    echo "=== Style: $style ==="
    TAVS_FACE_MODE=compact TAVS_COMPACT_CONTEXT_STYLE=$style \
        ./src/core/trigger.sh processing
done

# --- Disabled context eye (exact old behavior) ---

TAVS_FACE_MODE=compact TAVS_COMPACT_CONTEXT_EYE=false \
    ./src/core/trigger.sh processing
# → Status emoji pair in both eyes (🟧 🟧 with squares theme)

# Test disabled + subagent count (old behavior preserved)
TAVS_FACE_MODE=compact TAVS_COMPACT_CONTEXT_EYE=false \
    ./src/core/trigger.sh subagent-start
TAVS_FACE_MODE=compact TAVS_COMPACT_CONTEXT_EYE=false \
    ./src/core/trigger.sh subagent-start
# → Should show +N in right eye

# --- Subagent count displacement ---

TAVS_FACE_MODE=compact ./src/core/trigger.sh subagent-start
TAVS_FACE_MODE=compact ./src/core/trigger.sh subagent-start
# → Context in right eye, +2 as separate {AGENTS} token outside face

# --- Default theme verification ---

TAVS_FACE_MODE=compact ./src/core/trigger.sh processing
# → Left eye = 🟧 (orange square, NOT 🟠 circle)

# --- Per-agent override ---

CLAUDE_COMPACT_CONTEXT_STYLE=block TAVS_FACE_MODE=compact \
    ./src/core/trigger.sh processing
# → Block char (▄) in right eye for Claude

# --- Standard mode unaffected ---

TAVS_FACE_MODE=standard ./src/core/trigger.sh processing
# → Text face as before (no change)

# --- All 8 trigger states ---

for state in processing permission complete idle compacting subagent-start tool_error reset; do
    echo "=== State: $state ==="
    TAVS_FACE_MODE=compact ./src/core/trigger.sh $state
done

# --- Double-load guard test ---
# (Verify context data isn't read twice in a single trigger invocation)
# The _TAVS_CONTEXT_LOADED guard is process-scoped, so this is implicit —
# just verify there are no errors or performance issues in the above tests.

./src/core/trigger.sh reset  # Clean up after all tests
```

### Definition of Done

- [ ] All 8 context styles produce correct right eye for 0%, 50%, 100%
- [ ] Em dash reset face works across all 4 compact themes
- [ ] Subagent count appears as `{AGENTS}` token when context eye active
- [ ] Graceful fallback to theme emoji when no context data
- [ ] Context eye disabled → old behavior preserved exactly (including +N in right eye)
- [ ] Squares is the new default compact theme (left eye = 🟧 for processing)
- [ ] Per-agent override of `COMPACT_CONTEXT_STYLE` works
- [ ] No double-loading of context data (`_TAVS_CONTEXT_LOADED` guard)
- [ ] Standard face mode (`TAVS_FACE_MODE=standard`) completely unaffected
- [ ] No `square` context style available (intentionally excluded)

---

## Phase 2: Documentation & Config Template

### 2a. `src/config/user.conf.template`

Add compact context eye section after existing compact face mode settings:

- `TAVS_COMPACT_CONTEXT_EYE` with enable/disable documentation
- `TAVS_COMPACT_CONTEXT_STYLE` with all 8 style options and visual table
- Per-agent override examples (`CLAUDE_COMPACT_CONTEXT_STYLE`, etc.)
- Note about combining face + title tokens (e.g., food in eye + percentage in title)
- Note that `square` is intentionally excluded (blends with left eye)

### 2b. `CLAUDE.md`

Update compact face mode section:

- Add context eye explanation: "right eye = context fill level"
- Update default theme mention: squares (was semantic)
- Add em dash reset face: `Ǝ[— —]E`
- Show visual examples: `Ǝ[🟧 🧀]E` (processing at 50%)
- Show subagent count displacement: `Ǝ[🟧 🧀]E +2 ~/proj`
- List all 8 available styles
- Configuration settings reference

### 2c. `docs/reference/dynamic-titles.md`

Add "Compact Context Eye" section:

- Full visual reference card (all 8 styles at 0%, 25%, 50%, 75%, 100%)
- Per-agent face examples (Claude, Gemini, Codex, OpenCode)
- Configuration guide with examples
- Interaction with subagent count
- Per-agent customization instructions
- Troubleshooting: no data → fallback behavior
- Why `square` is not available as a context style

### Definition of Done

- [ ] user.conf.template documents all new settings with visual examples
- [ ] CLAUDE.md updated with context eye overview, new default theme, reset face
- [ ] dynamic-titles.md has comprehensive visual reference for all 8 styles
- [ ] All files stay under 500 lines

---

## Phase 3: Deploy & Integration Test

### Implementation Steps

1. Deploy to plugin cache: `./tavs sync`
2. Live test in Claude Code with `TAVS_FACE_MODE=compact` in `~/.tavs/user.conf`
3. Walk through all 8 trigger states verifying correct faces
4. Test without bridge → verify fallback to theme emoji
5. Test each of 8 styles by changing `TAVS_COMPACT_CONTEXT_STYLE` in user.conf
6. Test context eye disabled → verify exact old behavior
7. Commit all changes and create PR

### Live Test Sequence

| # | Test | Expected |
|---|------|----------|
| 1 | Processing | Context food in right eye, 🟧 in left |
| 2 | Permission | Context food + 🟥 in left |
| 3 | Complete | Context visible + 🟩 in left |
| 4 | Idle | Context stays visible (ambient awareness) |
| 5 | Compacting | Context visible, 🟦 in left, watch right eye change |
| 6 | Subagent start ×2 | `+N` outside face, context in right eye |
| 7 | Tool error | Brief flash with context |
| 8 | Reset | `Ǝ[— —]E` em dash resting eyes |
| 9 | No bridge data | Theme emoji pair (🟧 🟧) fallback |
| 10 | Each of 8 styles | Correct visualization per style |
| 11 | Context eye disabled | Exact old compact behavior |
| 12 | Standard mode | Completely unchanged |

### Definition of Done

- [ ] All 8 trigger states produce correct titles in live session
- [ ] Context updates in real-time via bridge
- [ ] Fallback works without bridge
- [ ] No regressions in standard mode
- [ ] No regressions in compact mode with context eye disabled

---

## Risk Areas

| Risk | Mitigation |
|------|------------|
| `load_context_data()` called in face + title | `_TAVS_CONTEXT_LOADED` guard prevents double read |
| Block chars render differently per terminal | Already validated by existing CONTEXT_BAR_V token |
| Em dash width varies by font | Standard Unicode U+2014; tested in all agent frames |
| `resolve_context_token` not available in face-selection | Verified: context-data.sh sourced at trigger.sh:45, functions available when `get_compact_face()` called |
| Bash 3.2 compatibility | No namerefs used; case statement and string ops only |
| Zsh compatibility | Using intermediate vars for brace defaults (`_ctx_eye`, `_ctx_style`) |

## Sequencing & Dependencies

- **Phase 0** → Complete (worktree + docs committed)
- **Phase 1d** first (defines settings/arrays other files reference)
- **Phase 1c** next (guard needed before 1a calls `load_context_data`)
- **Phase 1a** (core face logic, largest change)
- **Phase 1b** (title composition, depends on understanding 1a's behavior)
- **Phase 1e** (per-agent vars, independent but logically follows 1a/1b)
- **Phase 2** after Phase 1 (docs describe the implementation)
- **Phase 3** after Phase 2 (deploy includes everything)
