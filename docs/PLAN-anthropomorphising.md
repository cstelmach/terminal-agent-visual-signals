# PLAN: Anthropomorphising Feature Implementation

**Version:** 1.1
**Last Updated:** 2026-01-11
**Companion:** [SPEC-anthropomorphising.md](./SPEC-anthropomorphising.md)

---

## Developer Handoff

> **Status:** ALL PHASES COMPLETE
> **Last Session:** 2026-01-11
> **Completed By:** Claude (executing-plans skill)

### Current Progress Overview

```
✅ Phase 1: Theme Infrastructure      [COMPLETE]
✅ Phase 2: Configuration Variables   [COMPLETE]
✅ Phase 3: Title Composition         [COMPLETE]
✅ Phase 4: Trigger Integration       [COMPLETE]
✅ Phase 5: Idle Worker Integration   [COMPLETE]
✅ Phase 6: Configure Script          [COMPLETE]
✅ Phase 7: Testing & Documentation   [COMPLETE]
```

### What Has Been Completed

#### Phase 1: Theme Infrastructure ✅

**File Created:** `src/core/themes.sh`

- Implemented 66 face definitions (6 themes × 11 states)
- Used Bash 3.2-compatible case-statement lookup (NOT associative arrays)
- Themes: `minimal`, `bear`, `cat`, `lenny`, `shrug`, `plain`
- States: `processing`, `permission`, `complete`, `compacting`, `reset`, `idle_0` through `idle_5`
- Accessor function: `get_face <theme> <state>` returns the ASCII face

**Verification Results:**
```bash
$ source src/core/themes.sh
$ get_face minimal processing  → (°-°)
$ get_face bear complete       → ʕ♥ᴥ♥ʔ
$ get_face cat idle_5          → ฅ^︶ﻌ︶^ฅᶻᶻ
$ get_face plain idle_5        → :-(zzZ
```

#### Phase 2: Configuration Variables ✅

**File Modified:** `src/core/theme.sh` (lines 20-41)

Added three configuration variables with environment override support:
```bash
ENABLE_ANTHROPOMORPHISING="${ENABLE_ANTHROPOMORPHISING:-false}"  # Master toggle
FACE_THEME="${FACE_THEME:-minimal}"                              # Theme selection
FACE_POSITION="${FACE_POSITION:-after}"                          # before|after emoji
```

**Verification Results:**
```bash
# Defaults work:
$ source src/core/theme.sh
$ echo $ENABLE_ANTHROPOMORPHISING  → false
$ echo $FACE_THEME                 → minimal

# Environment overrides work:
$ FACE_THEME=bear source src/core/theme.sh
$ echo $FACE_THEME                 → bear
```

#### Phase 3: Title Composition ✅

**File Modified:** `src/core/terminal.sh`

1. Added sourcing of themes.sh (lines 8-10)
2. Extended `send_osc_title()` with optional 3rd parameter `state` (lines 78-107)
3. Implemented face composition logic respecting `FACE_POSITION`

**Title Composition Logic:**
```
if emoji && face:
    if position == "before": face emoji text
    else:                    emoji face text
elif face:          face text
elif emoji:         emoji text
else:               text
```

**Verification Results:**
```bash
# Feature disabled (default): 🟠 ~/test
# Enabled, after:             🟠 (°-°) ~/test ✓
# Enabled, before:            (°-°) 🟠 ~/test ✓
# No emoji, with face:        (°-°) ~/test ✓
# No state param:             🟠 ~/test (graceful) ✓
```

### What Needs To Be Done Next

#### Phase 4: Trigger Integration (START HERE) ⏳

**Goal:** Update `src/core/trigger.sh` to pass state parameter to `send_osc_title()`

**Why This Is Next:**
- Phase 3 added the `state` parameter to `send_osc_title()`, but trigger.sh still calls it with only 2 arguments
- Until this is done, faces won't appear even when enabled
- This is a low-complexity change with high impact

**Key Changes Required:**

1. In each state case, add the state name as 3rd argument to `send_osc_title`:
   ```bash
   # BEFORE:
   send_osc_title "$STATUS_ICON_PROCESSING" "$(get_short_cwd)"

   # AFTER:
   send_osc_title "$STATUS_ICON_PROCESSING" "$(get_short_cwd)" "processing"
   ```

2. States to update:
   - `processing)` → pass `"processing"`
   - `permission)` → pass `"permission"`
   - `complete)` → pass `"complete"` (note: idle progression uses idle_0-5)
   - `compacting)` → pass `"compacting"`
   - `reset)` → pass `"reset"`
   - Also update `else` branches that call `send_osc_title`

3. Look for ALL calls to `send_osc_title` in trigger.sh and update them

**Validation After Phase 4:**
```bash
ENABLE_ANTHROPOMORPHISING=true ./src/core/trigger.sh processing
# Should show face in terminal title
```

#### Phase 5: Idle Worker Integration (After Phase 4)

**Goal:** Update `src/core/idle-worker.sh` to pass `idle_0` through `idle_5` for sleepiness progression

**Key Insight:** The idle timer has 6 stages (defined in theme.sh). Each stage should map to:
- Stage 0 → `idle_0` (Alert)
- Stage 1 → `idle_1` (Content)
- Stage 2 → `idle_2` (Relaxed)
- Stage 3 → `idle_3` (Drowsy)
- Stage 4 → `idle_4` (Sleepy)
- Stage 5 → `idle_5` (Deep Sleep)

#### Phase 6: Configure Script (Can Start After Phase 2)

**Goal:** Create `configure.sh` for interactive setup

**Note:** This phase is INDEPENDENT of Phases 4-5. Could be implemented in parallel.

#### Phase 7: Testing & Documentation (Final Phase)

**Goal:** Create test script, update README.md and CLAUDE.md

### Key Technical Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Bash compatibility | Case statements, not associative arrays | macOS ships Bash 3.2 which lacks associative arrays |
| Lookup format | `get_face theme state` | Simple, clean API |
| Separator in case | `theme:state` (colon) | Readable, no conflicts with face characters |
| Feature default | `ENABLE_ANTHROPOMORPHISING=false` | Opt-in to avoid surprising users |
| Theme default | `minimal` | Unobtrusive, universal rendering |
| Position default | `after` | Emoji first for color recognition |

### Files Modified/Created

| File | Status | Lines Changed |
|------|--------|---------------|
| `src/core/themes.sh` | **CREATED** | 110 lines (66 faces + function) |
| `src/core/theme.sh` | **MODIFIED** | +24 lines (config section) |
| `src/core/terminal.sh` | **MODIFIED** | +23 lines (source + title logic) |
| `src/core/trigger.sh` | **MODIFIED** | +8 state parameters |
| `src/core/idle-worker.sh` | **MODIFIED** | +idle_face_key, use send_osc_title |
| `configure.sh` | **CREATED** | Interactive config script |

### How To Resume Work

1. **Read this handoff section** to understand current state
2. **Start with Phase 4** (trigger.sh integration)
3. **Use TodoWrite** to track progress:
   ```
   Phase 4: Update trigger.sh to pass state [in_progress]
   Phase 5: Update idle-worker.sh for progression [pending]
   Phase 6: Create configure.sh script [pending]
   Phase 7: Testing and documentation [pending]
   ```
4. **Validate after each phase** using the verification steps in each phase section
5. **Commit atomically** per phase with clear messages

### Quick Verification Commands

```bash
# Test themes.sh loads correctly:
source src/core/themes.sh && get_face minimal processing

# Test full chain with face enabled:
ENABLE_ANTHROPOMORPHISING=true source src/core/theme.sh && \
source src/core/terminal.sh && \
echo "Face: $(get_face minimal processing)"

# Test trigger (after Phase 4):
ENABLE_ANTHROPOMORPHISING=true ./src/core/trigger.sh processing
```

### Uncommitted Changes

As of handoff, there are uncommitted changes from Phases 1-3. Before continuing:
```bash
git status  # Check current state
git diff    # Review changes
# Consider committing Phase 1-3 work before proceeding
```

---

## Prerequisites

### Environment Requirements

- [ ] Bash 3.2+ (macOS default)
- [ ] Working terminal-agent-visual-signals installation
- [ ] Terminal with Unicode support (recommended) or ASCII fallback

### Codebase State

- [ ] Current `main` branch with recent commits
- [ ] No uncommitted changes to core files
- [ ] Debug logging disabled (`DEBUG_ALL=0`)

### Developer Knowledge

- [ ] Understanding of OSC escape sequences
- [ ] Familiarity with bash parameter expansion
- [ ] Ability to test in Claude Code or Gemini CLI environment

---

## Implementation Phases

### Phase 1: Theme Infrastructure ✅ COMPLETE

**Scope:** Create the themes.sh file with all face definitions and accessor function.

**Deliverables:**
- New file: `src/core/themes.sh`
- Face definitions for all 6 themes
- `get_face()` accessor function (Bash 3.2 compatible)

**Implementation Steps:**

1. **Create themes.sh skeleton**
   ```bash
   touch src/core/themes.sh
   chmod +x src/core/themes.sh
   ```

2. **Implement Bash 3.2-compatible theme storage**

   Since Bash 3.2 lacks associative arrays, use function-based lookup:
   ```bash
   # Instead of associative arrays, use functions:
   get_face() {
       local theme="$1"
       local state="$2"

       case "${theme}_${state}" in
           minimal_processing) echo "(°-°)" ;;
           minimal_permission) echo "(°□°)" ;;
           # ... etc
       esac
   }
   ```

3. **Define all 6 themes with 11 states each**
   - 5 core states: processing, permission, complete, compacting, reset
   - 6 idle stages: idle_0 through idle_5

4. **Add theme list for configure.sh**
   ```bash
   AVAILABLE_THEMES=("minimal" "bear" "cat" "lenny" "shrug" "plain")
   ```

**Validation:**
- [x] `source themes.sh` succeeds without errors
- [x] `get_face minimal processing` outputs `(°-°)`
- [x] `get_face plain idle_5` outputs `:-(zzZ`
- [x] All 66 face combinations return non-empty strings

**Dependencies:** None

---

### Phase 2: Configuration Variables ✅ COMPLETE

**Scope:** Add anthropomorphising config to theme.sh

**Deliverables:**
- Three new variables in theme.sh
- Documentation comments

**Implementation Steps:**

1. **Add config variables to theme.sh (after existing feature toggles)**
   ```bash
   # === ANTHROPOMORPHISING (ASCII FACES) ===
   # Add expressive ASCII faces to terminal titles
   ENABLE_ANTHROPOMORPHISING="${ENABLE_ANTHROPOMORPHISING:-false}"
   FACE_THEME="${FACE_THEME:-minimal}"
   FACE_POSITION="${FACE_POSITION:-after}"  # before|after
   ```

2. **Add inline documentation**
   ```bash
   # ENABLE_ANTHROPOMORPHISING: Master toggle for ASCII face display
   #   - false (default): No faces shown
   #   - true: Faces appear in title per FACE_POSITION
   #
   # FACE_THEME: Which face style to use
   #   - minimal: Simple kaomoji (default)
   #   - bear: ʕ•ᴥ•ʔ family
   #   - cat: ฅ^•ﻌ•^ฅ family
   #   - lenny: ( ͡° ͜ʖ ͡°) family
   #   - shrug: ¯\_(ツ)_/¯ family
   #   - plain: ASCII-only (:-) for compatibility
   #
   # FACE_POSITION: Where face appears relative to emoji
   #   - after: 🟠 (°-°) ~/path
   #   - before: (°-°) 🟠 ~/path
   ```

**Validation:**
- [x] Variables have correct defaults when not set
- [x] Environment variable overrides work: `FACE_THEME=bear ./trigger.sh`
- [x] Invalid values don't cause errors (use defaults)

**Dependencies:** None (can run parallel with Phase 1)

---

### Phase 3: Title Composition

**Scope:** Modify terminal.sh to compose titles with faces

**Deliverables:**
- Updated `send_osc_title()` function
- New helper for face-aware title building

**Implementation Steps:**

1. **Source themes.sh in terminal.sh**
   ```bash
   # At top of terminal.sh, after shebang
   SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
   source "$SCRIPT_DIR/themes.sh"
   ```

2. **Modify send_osc_title() signature**
   ```bash
   # Old: send_osc_title emoji text
   # New: send_osc_title emoji text [state]
   send_osc_title() {
       local emoji="$1"
       local text="$2"
       local state="${3:-}"
   ```

3. **Add face composition logic**
   ```bash
   send_osc_title() {
       local emoji="$1"
       local text="$2"
       local state="${3:-}"
       [[ -z "$TTY_DEVICE" ]] && return

       local face=""
       if [[ "$ENABLE_ANTHROPOMORPHISING" == "true" && -n "$state" ]]; then
           face=$(get_face "$FACE_THEME" "$state")
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

**Validation:**
- [ ] `ENABLE_ANTHROPOMORPHISING=false`: Titles unchanged from before
- [ ] `ENABLE_ANTHROPOMORPHISING=true FACE_POSITION=after`: `🟠 (°-°) path`
- [ ] `ENABLE_ANTHROPOMORPHISING=true FACE_POSITION=before`: `(°-°) 🟠 path`
- [ ] `ENABLE_TITLE_PREFIX=false ENABLE_ANTHROPOMORPHISING=true`: `(°-°) path`
- [ ] Empty state parameter: Gracefully shows no face

**Dependencies:** Phase 1 (themes.sh must exist)

---

### Phase 4: Trigger Integration

**Scope:** Update trigger.sh to pass state to send_osc_title()

**Deliverables:**
- Updated trigger.sh with state parameter passing
- All 5 states + reset passing correct state keys

**Implementation Steps:**

1. **Update processing case**
   ```bash
   processing)
       should_change_state "$STATE" || exit 0
       kill_idle_timer
       if [[ "$ENABLE_PROCESSING" == "true" ]]; then
           [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && send_osc_bg "$COLOR_PROCESSING"
           [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && send_osc_title "$STATUS_ICON_PROCESSING" "$(get_short_cwd)" "processing"
       # ... rest unchanged
   ```

2. **Update all other cases similarly**
   - permission → "permission"
   - complete → "complete"
   - compacting → "compacting"
   - reset → "reset"

3. **Ensure else branches also pass state**
   ```bash
   else
       [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && send_osc_bg "reset"
       [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && send_osc_title "" "$(get_short_cwd)" "reset"
   fi
   ```

**Validation:**
- [ ] Manual test: `./trigger.sh processing` shows face when enabled
- [ ] Manual test: `./trigger.sh permission` shows permission face
- [ ] All 5 states + reset display correct faces
- [ ] Disabled feature: No change to current behavior

**Dependencies:** Phase 3 (send_osc_title signature change)

---

### Phase 5: Idle Worker Integration

**Scope:** Update idle-worker.sh to show progressive sleepiness faces

**Deliverables:**
- Idle stages pass correct face keys (idle_0 through idle_5)
- Progressive face transitions during idle

**Implementation Steps:**

1. **Identify stage transition code in idle-worker.sh**
   Look for where `UNIFIED_STAGE_STATUS_ICONS[$stage]` is used

2. **Add idle stage face key**
   ```bash
   local stage_index=$current_stage
   local idle_face_key="idle_${stage_index}"

   # Update title with stage emoji and face
   [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && \
       send_osc_title "${UNIFIED_STAGE_STATUS_ICONS[$stage_index]}" "$(get_short_cwd)" "$idle_face_key"
   ```

3. **Verify stage 0 (complete) maps to idle_0**
   The complete state should transition to idle_0 face

**Validation:**
- [ ] Trigger complete, wait 60s → idle_1 face appears
- [ ] Full progression through 6 stages shows different faces
- [ ] Final stage (idle_5) shows deep sleep face
- [ ] Timer kill resets face correctly

**Dependencies:** Phase 4 (trigger.sh changes)

---

### Phase 6: Configure Script

**Scope:** Create interactive configuration script

**Deliverables:**
- New file: `configure.sh` at project root
- Interactive menu with theme previews
- Writes configuration to theme.sh

**Implementation Steps:**

1. **Create configure.sh skeleton**
   ```bash
   #!/bin/bash
   # Terminal Agent Visual Signals - Configuration Script

   SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
   THEME_FILE="$SCRIPT_DIR/src/core/theme.sh"

   source "$SCRIPT_DIR/src/core/themes.sh"
   ```

2. **Add theme preview function**
   ```bash
   show_theme_preview() {
       local theme="$1"
       echo "Theme: $theme"
       echo "  Processing: $(get_face "$theme" processing)"
       echo "  Permission: $(get_face "$theme" permission)"
       echo "  Complete:   $(get_face "$theme" complete)"
       echo "  Idle (sleeping): $(get_face "$theme" idle_5)"
   }
   ```

3. **Add interactive menu**
   ```bash
   select_theme() {
       echo "Select a face theme:"
       echo ""
       local i=1
       for theme in "${AVAILABLE_THEMES[@]}"; do
           echo "  $i) $theme"
           show_theme_preview "$theme" | sed 's/^/     /'
           echo ""
           ((i++))
       done

       read -p "Enter number (1-${#AVAILABLE_THEMES[@]}): " choice
       # Validate and return selection
   }
   ```

4. **Add config writer function**
   ```bash
   update_config() {
       local var="$1"
       local value="$2"

       # Use sed to update or append
       if grep -q "^${var}=" "$THEME_FILE"; then
           sed -i.bak "s/^${var}=.*/${var}=\"${value}\"/" "$THEME_FILE"
       else
           echo "${var}=\"${value}\"" >> "$THEME_FILE"
       fi
   }
   ```

5. **Add position selection**
   ```bash
   select_position() {
       echo "Where should faces appear relative to emoji?"
       echo "  1) After emoji:  🟠 (°-°) ~/path"
       echo "  2) Before emoji: (°-°) 🟠 ~/path"
       read -p "Enter choice (1-2): " choice
       # Return before/after
   }
   ```

6. **Main flow**
   ```bash
   main() {
       echo "=== Terminal Visual Signals Configuration ==="
       echo ""

       # Step 1: Enable feature?
       read -p "Enable anthropomorphising (ASCII faces)? [y/N]: " enable
       if [[ "$enable" =~ ^[Yy] ]]; then
           update_config "ENABLE_ANTHROPOMORPHISING" "true"

           # Step 2: Select theme
           theme=$(select_theme)
           update_config "FACE_THEME" "$theme"

           # Step 3: Select position
           position=$(select_position)
           update_config "FACE_POSITION" "$position"
       else
           update_config "ENABLE_ANTHROPOMORPHISING" "false"
       fi

       echo ""
       echo "Configuration saved to $THEME_FILE"
       echo "Restart your Claude Code session to apply changes."
   }

   main
   ```

**Validation:**
- [ ] Script runs without errors
- [ ] Theme previews display correctly
- [ ] Config changes persist in theme.sh
- [ ] Invalid inputs handled gracefully
- [ ] Can re-run to change settings

**Dependencies:** Phase 1, Phase 2

---

### Phase 7: Testing & Documentation

**Scope:** Comprehensive testing and README updates

**Deliverables:**
- Test script for all states/themes
- Updated README with feature documentation
- Updated CLAUDE.md with testing instructions

**Implementation Steps:**

1. **Create test script**
   ```bash
   #!/bin/bash
   # test-faces.sh - Test all face themes and states

   for theme in minimal bear cat lenny shrug plain; do
       echo "=== Theme: $theme ==="
       FACE_THEME=$theme ENABLE_ANTHROPOMORPHISING=true \
           ./src/core/trigger.sh processing
       sleep 1
       # ... test all states
   done
   ```

2. **Update README.md**
   - Add "Anthropomorphising" section
   - Document configuration options
   - Show example terminal screenshots
   - Link to SPEC document

3. **Update CLAUDE.md**
   - Add face testing instructions
   - Document new files

**Validation:**
- [ ] Test script passes for all 6 themes × 11 states
- [ ] README clearly explains feature
- [ ] No broken links in documentation

**Dependencies:** Phases 1-6 complete

---

## Risk Areas

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Unicode rendering issues | Medium | Low | Plain ASCII theme as fallback |
| Bash 3.2 compatibility | High | High | Use case-based lookup, not associative arrays |
| Title truncation with long faces | Low | Low | Test face lengths; keep under 15 chars |
| Performance overhead | Low | Medium | get_face() is O(1); faces cached per state |
| Breaking existing behavior | Medium | High | Feature disabled by default; extensive testing |

### Bash 3.2 Mitigation Detail

macOS ships Bash 3.2 which lacks associative arrays. The SPEC shows associative arrays for clarity, but implementation MUST use:

```bash
# Bash 3.2 compatible approach
get_face() {
    local theme="$1"
    local state="$2"

    # Use case statement for O(1) lookup
    case "${theme}:${state}" in
        minimal:processing) echo "(°-°)" ;;
        minimal:permission) echo "(°□°)" ;;
        # ... 66 total cases
        *) echo "" ;;
    esac
}
```

This is verbose but guaranteed compatible and fast.

---

## Sequencing & Dependencies

```
Phase 1 ──────────────────┐
(themes.sh)               │
                          ├──► Phase 3 ──► Phase 4 ──► Phase 5
Phase 2 ──────────────────┤    (terminal) (trigger)   (idle)
(config vars)             │
                          └──► Phase 6
                               (configure.sh)

                          All ──► Phase 7 (testing/docs)
```

**Parallel Opportunities:**
- Phase 1 and Phase 2 can run simultaneously
- Phase 6 can start after Phases 1 & 2

**Sequential Requirements:**
- Phase 3 requires Phase 1
- Phase 4 requires Phase 3
- Phase 5 requires Phase 4
- Phase 7 requires all others

---

## Definition of Done

### Feature Complete

- [ ] All 6 themes implemented with 11 states each
- [ ] ENABLE_ANTHROPOMORPHISING toggle works correctly
- [ ] FACE_POSITION (before/after) works correctly
- [ ] Idle progression shows all 6 sleepiness stages
- [ ] configure.sh provides interactive setup
- [ ] Plain theme works in ASCII-only terminals

### Quality Verified

- [ ] No regressions when feature disabled
- [ ] All manual tests pass
- [ ] Works in both Claude Code and Gemini CLI
- [ ] No performance degradation observed
- [ ] Debug logging still works (when enabled)

### Documentation Updated

- [ ] SPEC document complete
- [ ] PLAN document complete
- [ ] README updated with feature docs
- [ ] CLAUDE.md updated with testing info

### Git Hygiene

- [ ] Atomic commits per phase
- [ ] Clear commit messages
- [ ] No debug code left in
- [ ] No commented-out code

---

## Estimated Effort

| Phase | Complexity | Files Changed |
|-------|------------|---------------|
| Phase 1: Theme Infrastructure | Medium | 1 new |
| Phase 2: Configuration Variables | Low | 1 modified |
| Phase 3: Title Composition | Medium | 1 modified |
| Phase 4: Trigger Integration | Low | 1 modified |
| Phase 5: Idle Worker Integration | Medium | 1 modified |
| Phase 6: Configure Script | Medium | 1 new |
| Phase 7: Testing & Docs | Low | 2-3 modified |

**Total: ~7 files touched, 2 new files created**

---

*Implementation plan generated from Discovery Architect specification.*
