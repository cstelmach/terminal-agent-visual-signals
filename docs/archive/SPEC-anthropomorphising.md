# SPEC: TAVS — Anthropomorphising Feature

**Version:** 1.0
**Last Updated:** 2026-01-11
**Status:** Approved for Implementation

---

## Project Overview

**Feature Name:** Anthropomorphising (ASCII Face Expressions)

**Summary:** Add optional ASCII face expressions to terminal tab titles that reflect the current state of Claude Code/Gemini CLI sessions. Faces provide a playful, at-a-glance way to understand what the agent is doing, complementing the existing emoji and color-based visual system.

**Core Purpose:** Enhance the terminal visual feedback system with personality-driven indicators that make the agent's state immediately recognizable and emotionally resonant, while remaining fully optional and configurable.

---

## Goals & Success Criteria

### Primary Goals

1. **Visual Personality:** Add expressive ASCII faces that communicate agent state with character and warmth
2. **Opt-in Enhancement:** Feature is disabled by default; users explicitly enable it
3. **Theme Variety:** Multiple face "personalities" (bear, cat, lenny, etc.) let users choose their preferred aesthetic
4. **Progressive Feedback:** Idle state shows gradual transition through sleepiness stages
5. **Configuration Simplicity:** Interactive setup script makes customization accessible

### Success Criteria

- [ ] All 6 states display appropriate faces when enabled
- [ ] Face position (before/after emoji) is configurable
- [ ] All 6 themes render correctly in terminal titles
- [ ] Idle progression shows 6 distinct sleepiness stages
- [ ] configure.sh provides interactive theme selection with previews
- [ ] ASCII fallback theme works in terminals without Unicode support
- [ ] No performance regression (face lookup is O(1))
- [ ] Existing functionality unaffected when feature is disabled

---

## Architecture & Design

### Configuration Variables

Added to `src/core/theme.sh`:

```bash
# === ANTHROPOMORPHISING (ASCII FACES) ===
ENABLE_ANTHROPOMORPHISING=false    # Master toggle (opt-in)
FACE_THEME="minimal"               # Selected theme: minimal|bear|cat|lenny|shrug|plain
FACE_POSITION="after"              # Position relative to emoji: before|after
```

### Position Behavior

| Setting | With Emoji Enabled | With Emoji Disabled |
|---------|-------------------|---------------------|
| `before` | `(°-°) 🟠 ~/path` | `(°-°) ~/path` |
| `after` | `🟠 (°-°) ~/path` | `(°-°) ~/path` |

When `ENABLE_TITLE_PREFIX=false` (emoji disabled), face position is moot—face simply prepends the path.

### Theme Structure

New file: `src/core/themes.sh`

```bash
#!/bin/bash
# ==============================================================================
# TAVS — Face Themes
# ==============================================================================
# Defines ASCII face expressions for each state, organized by theme.
# ==============================================================================

# Theme: minimal — Simple, unobtrusive kaomoji
declare -A THEME_MINIMAL=(
    [processing]="(°-°)"
    [permission]="(°□°)"
    [complete]="(^‿^)"
    [compacting]="(°◡°)"
    [reset]="(-_-)"
    [idle_0]="(•‿•)"      # Alert
    [idle_1]="(‿‿)"       # Content
    [idle_2]="(︶‿︶)"     # Relaxed
    [idle_3]="(¬‿¬)"      # Drowsy
    [idle_4]="(-.-)zzZ"   # Sleepy
    [idle_5]="(︶.︶)ᶻᶻ"  # Deep Sleep
)

# Theme: bear — Cute bear faces ʕ•ᴥ•ʔ
declare -A THEME_BEAR=(
    [processing]="ʕ•ᴥ•ʔ"
    [permission]="ʕ๏ᴥ๏ʔ"
    [complete]="ʕ♥ᴥ♥ʔ"
    [compacting]="ʕ•̀ᴥ•́ʔ"
    [reset]="ʕ-ᴥ-ʔ"
    [idle_0]="ʕ•ᴥ•ʔ"      # Alert
    [idle_1]="ʕ‾ᴥ‾ʔ"      # Content
    [idle_2]="ʕ︶ᴥ︶ʔ"     # Relaxed
    [idle_3]="ʕ¬ᴥ¬ʔ"      # Drowsy
    [idle_4]="ʕ-ᴥ-ʔzZ"    # Sleepy
    [idle_5]="ʕ︶ᴥ︶ʔᶻᶻ"  # Deep Sleep
)

# Theme: cat — Playful cat faces
declare -A THEME_CAT=(
    [processing]="ฅ^•ﻌ•^ฅ"
    [permission]="ฅ^◉ﻌ◉^ฅ"
    [complete]="ฅ^♥ﻌ♥^ฅ"
    [compacting]="ฅ^•̀ﻌ•́^ฅ"
    [reset]="ฅ^-ﻌ-^ฅ"
    [idle_0]="ฅ^•ﻌ•^ฅ"    # Alert
    [idle_1]="ฅ^‾ﻌ‾^ฅ"    # Content
    [idle_2]="ฅ^︶ﻌ︶^ฅ"   # Relaxed
    [idle_3]="ฅ^¬ﻌ¬^ฅ"    # Drowsy
    [idle_4]="ฅ^-ﻌ-^ฅzZ"  # Sleepy
    [idle_5]="ฅ^︶ﻌ︶^ฅᶻᶻ" # Deep Sleep
)

# Theme: lenny — Expressive lenny faces
declare -A THEME_LENNY=(
    [processing]="( ͡° ͜ʖ ͡°)"
    [permission]="( ͡⊙ ͜ʖ ͡⊙)"
    [complete]="( ͡♥ ͜ʖ ͡♥)"
    [compacting]="( ͡~ ͜ʖ ͡°)"
    [reset]="( ͡_ ͜ʖ ͡_)"
    [idle_0]="( ͡° ͜ʖ ͡°)"  # Alert
    [idle_1]="( ͡‾ ͜ʖ ͡‾)"  # Content
    [idle_2]="( ͡︶ ͜ʖ ͡︶)" # Relaxed
    [idle_3]="( ͡¬ ͜ʖ ͡¬)"  # Drowsy
    [idle_4]="( ͡- ͜ʖ ͡-)zZ" # Sleepy
    [idle_5]="( ͡︶ ͜ʖ ͡︶)ᶻᶻ" # Deep Sleep
)

# Theme: shrug — Shrug-style faces ¯\_(ツ)_/¯
declare -A THEME_SHRUG=(
    [processing]="¯\_(°‿°)_/¯"
    [permission]="¯\_(°□°)_/¯"
    [complete]="¯\_(^‿^)_/¯"
    [compacting]="¯\_(°◡°)_/¯"
    [reset]="¯\_(-_-)_/¯"
    [idle_0]="¯\_(•‿•)_/¯"    # Alert
    [idle_1]="¯\_(‾‿‾)_/¯"    # Content
    [idle_2]="¯\_(︶‿︶)_/¯"   # Relaxed
    [idle_3]="¯\_(¬‿¬)_/¯"    # Drowsy
    [idle_4]="¯\_(-.-)_/¯zZ"  # Sleepy
    [idle_5]="¯\_(︶.︶)_/¯ᶻᶻ" # Deep Sleep
)

# Theme: plain — ASCII-only fallback for compatibility
declare -A THEME_PLAIN=(
    [processing]=":-|"
    [permission]=":-O"
    [complete]=":-)"
    [compacting]=":-/"
    [reset]=":-|"
    [idle_0]=":-)"      # Alert
    [idle_1]=":-|"      # Content
    [idle_2]=":-)"      # Relaxed
    [idle_3]=":-/"      # Drowsy
    [idle_4]=":-("      # Sleepy
    [idle_5]=":-(zzZ"   # Deep Sleep
)

# === THEME ACCESSOR FUNCTION ===
get_face() {
    local state="$1"
    local theme_var="THEME_${FACE_THEME^^}"

    # Use nameref for indirect array access
    local -n theme_array="$theme_var"
    echo "${theme_array[$state]:-}"
}
```

### Title Composition Logic

Modified `send_osc_title()` in `terminal.sh`:

```bash
send_osc_title() {
    local emoji="$1"
    local text="$2"
    local state="$3"  # New parameter
    [[ -z "$TTY_DEVICE" ]] && return

    local face=""
    if [[ "$ENABLE_ANTHROPOMORPHISING" == "true" ]]; then
        face=$(get_face "$state")
    fi

    local title=""
    if [[ -n "$emoji" && -n "$face" ]]; then
        if [[ "$FACE_POSITION" == "before" ]]; then
            title="$face $emoji $text"
        else
            title="$emoji $face $text"
        fi
    elif [[ -n "$face" ]]; then
        title="$face $text"
    elif [[ -n "$emoji" ]]; then
        title="$emoji $text"
    else
        title="$text"
    fi

    printf "\033]0;%s\033\\" "$title" > "$TTY_DEVICE"
}
```

### Idle Stage Integration

The existing `UNIFIED_STAGE_STATUS_ICONS` array handles idle progression. Face progression is handled separately via `idle_0` through `idle_5` keys in each theme.

Modified `idle-worker.sh` to pass stage index:

```bash
# In stage transition:
local idle_face_key="idle_${stage_index}"
send_osc_title "${UNIFIED_STAGE_STATUS_ICONS[$stage_index]}" "$(get_short_cwd)" "$idle_face_key"
```

---

## State-Face Mappings

### Core States (5)

| State | Emotional Intent | Example (minimal) |
|-------|-----------------|-------------------|
| `processing` | Focused, working | `(°-°)` |
| `permission` | Surprised, questioning | `(°□°)` |
| `complete` | Happy, satisfied | `(^‿^)` |
| `compacting` | Determined, busy | `(°◡°)` |
| `reset` | Neutral, resting | `(-_-)` |

### Idle Stages (6)

| Stage | Duration | Emotional State | Example (minimal) |
|-------|----------|-----------------|-------------------|
| 0 (Complete) | 60s | Alert | `(•‿•)` |
| 1 | 30s | Content | `(‿‿)` |
| 2 | 30s | Relaxed | `(︶‿︶)` |
| 3 | 30s | Drowsy | `(¬‿¬)` |
| 4 | 30s | Sleepy | `(-.-)zzZ` |
| 5 | 30s | Deep Sleep | `(︶.︶)ᶻᶻ` |

---

## Decisions & Rationale

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Opt-in default | `ENABLE_ANTHROPOMORPHISING=false` | Avoid surprising existing users; feature is enhancement |
| Single themes.sh | All themes in one file | Simpler maintenance, easy to add themes |
| 6 themes for MVP | minimal, bear, cat, lenny, shrug, plain | Variety without overwhelm; plain for compatibility |
| Default theme | `minimal` | Unobtrusive, works everywhere, non-distracting |
| Position options | before/after | User preference varies; flexibility is key |
| Single face per state | No randomization | Predictable, clear meaning, simpler implementation |
| 6 idle stages | Full progression | Maximum expressiveness matches color fade |
| Interactive configure.sh | Optional customization | Defaults work; script for power users |
| Global toggle only | No per-state toggles | Simpler config, consistent behavior |

---

## Rejected Alternatives

| Alternative | Why Rejected |
|-------------|--------------|
| JSON theme files | Adds jq dependency, unnecessary complexity |
| Auto-detect terminal capabilities | Unreliable; user selection is clearer |
| Random face per invocation | Unpredictable, harder to learn meanings |
| Per-state face toggles | Over-engineering; global toggle sufficient |
| Separate file per theme | File proliferation without benefit |
| Environment variable for theme | Less discoverable than config file |

---

## Constraints & Boundaries

### In Scope

- ASCII face display in terminal title bar
- 6 face themes with full state coverage
- Interactive configuration script
- Idle stage progression with unique faces
- Position flexibility (before/after emoji)

### Out of Scope (Future Phases)

- Console output faces (printing to terminal body)
- Substate faces (different faces per tool/subagent)
- Per-session random theme selection
- Animated face transitions
- Custom user-defined themes (via config)
- Integration with notification systems

### Technical Constraints

- Bash 3.2+ compatibility (macOS default)
- Associative arrays require Bash 4.0+ — **Note:** Need to verify or provide fallback
- Terminal must support Unicode for non-plain themes
- Title bar length limits vary by terminal (~255 chars typical)

---

## Open Questions

1. **Bash 4.0 Requirement:** Associative arrays need Bash 4+. macOS ships Bash 3.2. Options:
   - Require Homebrew bash
   - Use indexed arrays with naming convention
   - Source different implementation based on bash version

   *Recommendation:* Use indexed arrays with helper function for portability.

2. **Theme Hot-Reload:** Should changing theme require restarting the session?
   *Recommendation:* Yes for MVP; hot-reload adds complexity.

---

## File Changes Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `src/core/theme.sh` | Modify | Add ENABLE_ANTHROPOMORPHISING, FACE_THEME, FACE_POSITION |
| `src/core/themes.sh` | Create | All face theme definitions + get_face() |
| `src/core/terminal.sh` | Modify | Update send_osc_title() for face composition |
| `src/core/trigger.sh` | Modify | Pass state to send_osc_title() |
| `src/core/idle-worker.sh` | Modify | Pass idle stage key to send_osc_title() |
| `configure.sh` | Create | Interactive configuration script |
| `docs/SPEC-anthropomorphising.md` | Create | This document |
| `docs/PLAN-anthropomorphising.md` | Create | Implementation plan |

---

*Document generated through Discovery Architect Q&A process.*
