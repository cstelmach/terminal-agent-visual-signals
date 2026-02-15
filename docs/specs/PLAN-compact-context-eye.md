# Implementation Plan: Compact Context Eye

**Spec:** `docs/specs/SPEC-compact-context-eye.md`
**Created:** 2026-02-15
**Agent:** Fresh agent from /plan-from-spec
**Branch:** `feature/compact-context-eye` (worktree at `../tavs-compact-context-eye`)

---

## Context

Compact face mode shows status emoji in both eyes (`Ǝ[🟧 🟧]E`), with the right eye
sometimes overridden by subagent count (`Ǝ[🟧 +2]E`). The right eye is underutilized.
This feature repurposes the right eye as a **context window fill indicator**, turning
the face into a two-signal dashboard: left eye = state, right eye = context fill level.

Additionally: default compact theme changes to squares, reset face gets em dashes.

## Prerequisites

- Dynamic Title Templates feature must be merged (confirmed — PR #7 merged to main)
- Context data module (`src/core/context-data.sh`) must exist with `load_context_data()` and
  `resolve_context_token()` (confirmed at lines 227, 257)
- Git worktree support (for isolated development)

---

## Phase 0: Git Worktree Setup

### Implementation Steps
1. Create branch `feature/compact-context-eye` from `main`
2. Create worktree at `../tavs-compact-context-eye`
3. Create `docs/specs/PLAN-compact-context-eye.md` (copy of this plan)
4. Create `docs/specs/PROGRESS-compact-context-eye.md` (progress log)

### Verification
- [ ] Branch exists and worktree is functional
- [ ] Can run `./src/core/trigger.sh processing` from worktree

---

## Phase 1: Core Implementation

Five sub-steps modifying 5 existing files. No new files created.

### 1a. Modify `get_compact_face()` in `src/core/face-selection.sh`

**Target:** Lines 145-206 of `get_compact_face()`

**Current flow** (verified):
1. Map state → `state_upper`, build array name `COMPACT_{theme}_{state}` (lines 152-172)
2. Random pair selection, split into `left`/`right` (lines 182-188)
3. Override right eye with `+N` if subagents active (lines 190-197)
4. Substitute into `{L}`/`{R}` frame template (lines 199-205)

**New flow** — insert new logic between step 2 (line 188) and step 3 (line 190):

```bash
# After line 188: local right="${pair##* }"

# --- Context eye resolution ---
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
        local _ctx_style="${TAVS_COMPACT_CONTEXT_STYLE:-food}"
        local _ctx_token=""
        case "$_ctx_style" in
            food)      _ctx_token="CONTEXT_FOOD" ;;
            food_10)   _ctx_token="CONTEXT_FOOD_10" ;;
            circle)    _ctx_token="CONTEXT_ICON" ;;
            square)    _ctx_token="CONTEXT_SQUARE" ;;
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
    # If TAVS_CONTEXT_PCT empty: right keeps theme emoji (graceful fallback)
else
    # Context eye disabled: preserve current subagent count behavior
    if [[ "$state" == "processing" || "$state" == subagent* ]]; then
        if type has_active_subagents &>/dev/null && has_active_subagents 2>/dev/null; then
            local agent_count
            agent_count=$(get_subagent_count 2>/dev/null)
            [[ $agent_count -gt 0 ]] && right="+${agent_count}"
        fi
    fi
fi
```

**Key:** The existing subagent override block (lines 190-197) is **replaced** — it moves
inside the `else` branch (context eye disabled). When context eye is enabled, subagent
count goes to the `{AGENTS}` title token instead (handled in step 1b).

### 1b. Modify `compose_title()` in `src/core/title-management.sh`

**Target:** Lines 306-313 (agents suppression block)

**Current code** (verified at lines 308-313):
```bash
local agents=""
if [[ "$_compact_with_face" != "true" ]]; then
    if [[ "$state" == "processing" || "$state" == subagent* ]] && type get_subagent_title_suffix &>/dev/null; then
        agents=$(get_subagent_title_suffix 2>/dev/null)
    fi
fi
```

**New code:**
```bash
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

### 1c. Add `_TAVS_CONTEXT_LOADED` guard + `CONTEXT_SQUARE` to `src/core/context-data.sh`

**Guard** — add at top of `load_context_data()` (line 228, before globals reset):
```bash
load_context_data() {
    [[ -n "${_TAVS_CONTEXT_LOADED:-}" ]] && return 0
    _TAVS_CONTEXT_LOADED=1
    # ... existing logic (reset globals, bridge, transcript fallback) ...
}
```

**New token** — add to `resolve_context_token()` case statement (after line 272):
```bash
CONTEXT_SQUARE)   _get_icon_from_array "TAVS_CONTEXT_SQUARES_11" "$pct" 10 ;;
```

### 1d. Update `src/config/defaults.conf`

4 changes:

1. **Change default theme** (line 284):
   `TAVS_COMPACT_THEME="squares"` (was `"semantic"`)

2. **Add new settings** (after line 284):
   ```bash
   TAVS_COMPACT_CONTEXT_EYE="true"
   TAVS_COMPACT_CONTEXT_STYLE="food"
   ```

3. **Add squares icon array** (after existing context arrays, ~line 255):
   ```bash
   TAVS_CONTEXT_SQUARES_11=(
       "⬜"  "🟦"  "🟦"  "🟩"  "🟩"  "🟨"  "🟧"  "🟧"  "🟥"  "🟥"  "⬛"
   )
   ```

4. **Change all 4 RESET arrays to em dashes:**
   - Line 300: `COMPACT_SEMANTIC_RESET=("— —")` (was `('⚪ ⚪')`)
   - Line 315: `COMPACT_CIRCLES_RESET=("— —")` (was `('⚪ ⚪')`)
   - Line 330: `COMPACT_SQUARES_RESET=("— —")` (was `('⬜ ⬜')`)
   - Line 345: `COMPACT_MIXED_RESET=("— —")` (was `('⚪ ⬜')`)

### 1e. Add vars to `_resolve_agent_variables()` in `src/core/theme-config-loader.sh`

**Target:** vars array at lines 103-122

Add after `TITLE_FORMAT_RESET` (line 121):
```bash
# Per-agent compact context eye overrides
COMPACT_CONTEXT_STYLE
COMPACT_CONTEXT_EYE
```

**Note:** These won't match the `DEFAULT_` fallback condition (line 136) which only
triggers for `*_BASE`, `*_PROCESSING`, etc. This is correct — the TAVS_ global setting
acts as the default; per-agent vars only need PREFIX_ resolution.

### Files to Modify
- `src/core/face-selection.sh` — `get_compact_face()` (~30 lines replaced/added)
- `src/core/title-management.sh` — `compose_title()` (~6 lines changed)
- `src/core/context-data.sh` — `load_context_data()` guard + `CONTEXT_SQUARE` token (~5 lines)
- `src/config/defaults.conf` — theme default + settings + array + 4 reset arrays (~20 lines)
- `src/core/theme-config-loader.sh` — 2 vars added to resolution array

### Verification
```bash
# Test context eye with food (default)
TAVS_FACE_MODE=compact ./src/core/trigger.sh processing
# → Food emoji in right eye (if bridge data) or theme emoji (if no data)

# Test each of 9 styles
for style in food food_10 circle square block block_max braille number percent; do
    TAVS_FACE_MODE=compact TAVS_COMPACT_CONTEXT_STYLE=$style \
        ./src/core/trigger.sh processing
done

# Test reset em dashes
TAVS_FACE_MODE=compact ./src/core/trigger.sh reset
# → Ǝ[— —]E

# Test context eye disabled (exact old behavior)
TAVS_FACE_MODE=compact TAVS_COMPACT_CONTEXT_EYE=false ./src/core/trigger.sh processing
# → Status pair in both eyes

# Test subagent count appears as {AGENTS} token
TAVS_FACE_MODE=compact ./src/core/trigger.sh subagent-start
TAVS_FACE_MODE=compact ./src/core/trigger.sh subagent-start
# → Context in right eye, +2 outside face

# Verify squares is new default
TAVS_FACE_MODE=compact ./src/core/trigger.sh processing
# → Left eye should be 🟧 (square), not 🟠 (circle)

# Test per-agent override
CLAUDE_COMPACT_CONTEXT_STYLE=block TAVS_FACE_MODE=compact ./src/core/trigger.sh processing
# → Block char in right eye for Claude
```

### Definition of Done
- [ ] All 9 context styles produce correct right eye for 0%, 50%, 100%
- [ ] Em dash reset face works across all 4 themes
- [ ] Subagent count appears as `{AGENTS}` token when context eye active
- [ ] Graceful fallback to theme emoji when no context data
- [ ] Context eye disabled → old behavior preserved exactly
- [ ] Squares is the new default compact theme
- [ ] Per-agent override of COMPACT_CONTEXT_STYLE works
- [ ] No double-loading of context data (guard works)
- [ ] Standard face mode (`TAVS_FACE_MODE=standard`) completely unaffected

---

## Phase 2: Documentation & Config Template

### Implementation Steps

**2a. `src/config/user.conf.template`** — Add compact context eye section:
- `TAVS_COMPACT_CONTEXT_EYE` with enable/disable doc
- `TAVS_COMPACT_CONTEXT_STYLE` with all 9 style options, visual table
- Per-agent override examples (`CLAUDE_COMPACT_CONTEXT_STYLE`, etc.)
- Note about combining with title tokens for extra info

**2b. `CLAUDE.md`** — Update compact face mode section:
- Add context eye explanation and visual examples
- Update default theme mention (semantic → squares)
- Add em dash reset face
- Show subagent count displacement

**2c. `docs/reference/dynamic-titles.md`** — Add "Compact Context Eye" section:
- Full visual reference card (all 9 styles at 0%, 25%, 50%, 75%, 100%)
- Configuration guide with examples
- Per-agent customization instructions
- Troubleshooting: no data → fallback behavior

### Definition of Done
- [ ] user.conf.template documents all new settings with examples
- [ ] CLAUDE.md updated with context eye overview and default theme change
- [ ] dynamic-titles.md has comprehensive visual reference for all 9 styles
- [ ] All files stay under 500 lines

---

## Phase 3: Deploy & Integration Test

### Implementation Steps
1. Deploy to plugin cache: `./tavs sync`
2. Live test in Claude Code with `TAVS_FACE_MODE=compact` in `~/.tavs/user.conf`
3. Walk through all 8 trigger states verifying correct faces
4. Test without bridge → verify fallback
5. Test each of 9 styles by changing user.conf
6. Test context eye disabled → exact old behavior
7. Commit and create PR

### Live Test Sequence
1. Processing → context food in right eye, 🟧 in left
2. Permission → context food + 🟥 in left
3. Complete → context + 🟩 in left
4. Idle → context stays visible (ambient awareness)
5. Compacting → context visible, 🟦 in left
6. Subagent → `+N` outside face, context in right eye
7. Tool error → brief flash with context
8. Reset → `Ǝ[— —]E`
9. No bridge data → theme emoji pair (graceful)
10. Each of 9 styles live
11. Disabled → exact old behavior

### Definition of Done
- [ ] All 8 states correct in live session
- [ ] Context updates in real-time via bridge
- [ ] Fallback works without bridge
- [ ] No regressions in standard mode
- [ ] No regressions in compact mode with context eye disabled

---

## Risk Areas

| Risk | Mitigation |
|------|------------|
| `load_context_data()` called in face + title | `_TAVS_CONTEXT_LOADED` guard |
| Block chars render differently per terminal | Already validated by existing CONTEXT_BAR_V |
| Em dash width varies by font | Standard Unicode U+2014, tested in all agent frames |
| Square context blends with squares theme left eye | Food is default; square style is opt-in |
| `resolve_context_token` not available in face-selection | Verified: context-data.sh sourced at trigger.sh:45, before face-selection functions called |

## Sequencing & Dependencies

- Phase 0 must complete before Phase 1 (need worktree)
- Phase 1 must complete before Phase 2 (docs describe the implementation)
- Phase 2 must complete before Phase 3 (deploy includes docs)
- Phase 1 sub-steps can be done in any order but 1d (defaults.conf) should come first
  since it defines the settings and arrays that other files reference
