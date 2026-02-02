# Plan: TAVS Codebase Modularization

## Summary

Refactor TAVS shell scripts to achieve ≤500 LOC per file with clear separation of concerns, eliminate duplication, and rename files for self-documentation.

**Branch:** `refactor/modularization`
**Worktree:** `.worktrees/refactor-modularization`

---

## 🔄 HANDOFF SECTION

### Current Status: Phase 0 COMPLETE ✅

**Last Updated:** 2026-02-02
**Last Commit:** `64ff746 test(phase0): Build comprehensive test safety harness`

### What Has Been Completed

#### Phase 0.1: Audit Current Test Coverage ✅
- Created `coverage-audit.md` documenting all functions and their test status
- Identified 30 failing tests due to deprecated face theme system
- Mapped all 100+ shell functions across 12 core modules

#### Phase 0.2: Fix Failing Tests ✅
- **test_title_composition.py**: Added `TAVS_AGENT` parameter, fixed env variable overrides (must set AFTER sourcing theme.sh)
- **test_themes.py**: Complete rewrite for `get_random_face()` and agent-specific faces
- **test_config.py**: Updated defaults expectations (ENABLE_ANTHROPOMORPHISING=true now)
- **test_configure.py**: Updated function existence checks to match current code

#### Phase 0.3: Add Missing Behavioral Tests ✅
| New Test File | LOC | Coverage |
|---------------|-----|----------|
| `test_colors.py` | 405 | hex/rgb/hsl conversions, interpolation, is_dark_color |
| `test_title_state_persistence.py` | 410 | State file save/load, session IDs, escaping |
| `test_terminal_detection.py` | 354 | Terminal type detection, SSH, TrueColor |
| `test_spinner.py` | 312 | Spinner state, eye generation, styles |

### Test Suite Status

```
Before Phase 0: 206 passing, 30 failing
After Phase 0:  359 passing, 0 failing
```

**All test files under 500 LOC ✅**

### What's Next: Phase 1 - Extract Core Module Files

Phase 1 creates new module files by COPYING (not moving) functions. This is a safe extraction that doesn't break existing code until Phase 2 wires things up.

#### Step 1.1: Create face-selection.sh
- **Source:** Extract from theme.sh (lines 173-316, ~144 LOC)
- **Functions to extract:**
  - `get_random_face()` - Main public function
  - `_resolve_agent_faces()` - Resolves agent-specific face arrays
  - `_get_face_array()` - Returns face array for given state
- **File structure:**
  ```bash
  #!/usr/bin/env bash
  # face-selection.sh - Random face selection for TAVS
  # Dependencies: None (standalone utility)
  ```

#### Step 1.2: Create dynamic-color-calculation.sh
- **Source:** Extract from theme.sh (lines 573-775, ~203 LOC)
- **Functions to extract:**
  - `_calculate_dynamic_color()` - Core calculation logic
  - `_apply_dynamic_mode()` - Applies dynamic mode to base colors
- **Dependencies:** Will need to source `colors.sh`

#### Step 1.3: Create title-state-persistence.sh
- **Source:** Extract from title.sh (lines 10-186, ~177 LOC)
- **Functions to extract:**
  - `get_state_file()` - Returns path to state file
  - `_read_state_value()` - Safely reads value from state file
  - `_escape_for_state_file()` - Escapes special characters
  - `write_state_file()` - Writes key-value to state file
  - `init_session_id()` - Generates session ID

#### Step 1.4: Create palette-mode-helpers.sh
- **Source:** Extract from trigger.sh + deduplicate from idle-worker.sh (~35 LOC)
- **Functions to extract:**
  - `_get_palette_mode()` - Determines current palette mode
  - `should_send_bg_color()` - Decides whether to send background color
- **Why:** Eliminates duplication between trigger.sh and idle-worker.sh
  - `_idle_get_palette_mode()` → replaced by shared function
  - `_idle_should_send_bg_color()` → replaced by shared function

#### Step 1.5: Verify Extraction
```bash
# Syntax check all new files
bash -n src/core/face-selection.sh
bash -n src/core/dynamic-color-calculation.sh
bash -n src/core/title-state-persistence.sh
bash -n src/core/palette-mode-helpers.sh

# Zsh compatibility
zsh -n src/core/*.sh

# All tests still pass (original code unchanged)
pytest tests/ -v
```

### Key Decisions Already Made

| Question | Decision |
|----------|----------|
| Build safety harness first? | ✅ Yes - Phase 0 complete |
| Modularize theme.sh/title.sh? | ✅ Yes, full modularization |
| Modularize configure.sh? | ✅ Yes, 9 files (Phase 4) |
| Handle idle-worker duplication? | ✅ Create palette-mode-helpers.sh |
| Rename files for clarity? | ✅ Yes, in Phase 3 |

### Important Technical Context

#### Environment Variable Override Pattern
When testing shell scripts that source `theme.sh`, environment variables set BEFORE sourcing are overwritten by `defaults.conf`. Tests must set variables AFTER sourcing:
```bash
source src/core/theme.sh
export ENABLE_ANTHROPOMORPHISING="false"  # Must be after source
```

#### Agent Face System
The old `FACE_THEME` variable is deprecated. The current system uses:
- `TAVS_AGENT` (claude, gemini, codex, opencode, unknown)
- `get_random_face(state)` for face selection
- Agent-specific faces in `defaults.conf` as `CLAUDE_FACES_PROCESSING`, etc.
- `TAVS_AGENT=unknown` gives predictable fallback faces for testing

#### Files Being Touched

**Core files to be split:**
| Current File | Target LOC | Split Into |
|--------------|------------|------------|
| theme.sh (787) | ~440 | + face-selection.sh (~144) + dynamic-color-calculation.sh (~203) |
| title.sh (627) | ~450 | + title-state-persistence.sh (~177) |
| configure.sh (1,059) | ~200 | + 8 step modules (Phase 4) |

**Files to be renamed (Phase 3):**
| Current | New Name |
|---------|----------|
| theme.sh | theme-config-loader.sh |
| title.sh | title-management.sh |
| detect.sh | terminal-detection.sh |
| terminal.sh | terminal-osc-sequences.sh |
| state.sh | session-state.sh |
| idle-worker.sh | idle-worker-background.sh |

### Verification Commands

```bash
# Run full test suite (should be 359 passing)
pytest tests/ -v

# Test visual signals manually
./src/core/trigger.sh processing && sleep 1 && ./src/core/trigger.sh reset

# Syntax check all shell scripts
for f in src/core/*.sh; do bash -n "$f" || echo "FAIL: $f"; done
```

### Git State

```bash
# Current branch
git branch --show-current  # refactor/modularization

# Recent commits
git log --oneline -5

# Check for uncommitted changes
git status
```

### Files Created/Modified in Phase 0

**Created:**
- `coverage-audit.md` - Test coverage documentation
- `tests/test_colors.py` - Color math tests (405 LOC)
- `tests/test_terminal_detection.py` - Detection tests (354 LOC)
- `tests/test_title_state_persistence.py` - State persistence tests (410 LOC)
- `tests/test_spinner.py` - Spinner tests (312 LOC)

**Modified:**
- `tests/test_themes.py` - Rewritten for agent face system
- `tests/test_title_composition.py` - Fixed for TAVS_AGENT
- `tests/test_config.py` - Updated default expectations
- `tests/test_configure.py` - Updated function checks

---

## Full Implementation Phases

### Phase 0: Test Coverage & Safety Harness ✅ COMPLETE

See "What Has Been Completed" above.

### Phase 1: Extract Core Module Files (No Breaking Changes)

**Goal:** Create new module files by copying functions. Original files unchanged.

See "What's Next" above for detailed steps.

### Phase 2: Update Core Source Files

**Goal:** Wire up new modules by adding source statements; remove duplicates.

1. Update theme.sh to source face-selection.sh and dynamic-color-calculation.sh
2. Update title.sh to source title-state-persistence.sh
3. Update trigger.sh and idle-worker.sh for shared palette helpers
4. Remove duplicated functions from idle-worker.sh

### Phase 3: Rename Core Files

**Goal:** Rename 6 core files for self-documentation.

```bash
git mv src/core/theme.sh src/core/theme-config-loader.sh
git mv src/core/title.sh src/core/title-management.sh
git mv src/core/detect.sh src/core/terminal-detection.sh
git mv src/core/terminal.sh src/core/terminal-osc-sequences.sh
git mv src/core/state.sh src/core/session-state.sh
git mv src/core/idle-worker.sh src/core/idle-worker-background.sh
```

Then update all internal source statements.

### Phase 4: Modularize configure.sh

**Goal:** Split 1,059 LOC configure.sh into 9 focused modules.

| File | Purpose | LOC |
|------|---------|-----|
| configure.sh | Main orchestrator | ~200 |
| configure-utilities.sh | Shared helpers | ~200 |
| configure-step-operating-mode.sh | Step 1 | ~50 |
| configure-step-theme-preset.sh | Step 2 | ~60 |
| configure-step-light-dark-mode.sh | Step 3 | ~50 |
| configure-step-ascii-faces.sh | Step 4 | ~60 |
| configure-step-backgrounds.sh | Step 5 | ~90 |
| configure-step-terminal-title.sh | Step 6 | ~270 |
| configure-step-palette-theming.sh | Step 7 | ~80 |

### Phase 5: Update All Source Statements

**Goal:** Ensure all source paths are correct after renames and extractions.

### Phase 6: Verify and Deploy

**Goal:** Comprehensive verification and plugin cache update.

```bash
# Syntax checks
for f in src/core/*.sh; do bash -n "$f"; done
for f in src/core/*.sh; do zsh -n "$f"; done

# Test suite
pytest tests/ -v

# Manual test
./src/core/trigger.sh processing && sleep 1 && ./src/core/trigger.sh reset

# Update plugin cache
CACHE="$HOME/.claude/plugins/cache/terminal-visual-signals/terminal-visual-signals/1.2.0"
cp src/core/*.sh "$CACHE/src/core/"
```

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Refactoring introduces bugs | Phase 0 test harness catches regressions |
| Breaking source paths | Update all references in single commit, test immediately |
| Circular dependencies | New files are pure utilities with no cross-sourcing |
| Zsh compatibility | Run zsh syntax check and full test suite |
| Plugin cache out of sync | Document cache update, test after deployment |

---

## Exit Criteria

- [ ] All core shell scripts pass `bash -n` syntax check
- [ ] All core shell scripts pass `zsh -n` syntax check
- [ ] All tests pass: `pytest tests/ -v`
- [ ] Manual test: `./src/core/trigger.sh processing` works
- [ ] Configure wizard: `./configure.sh` runs through all steps
- [ ] Plugin cache updated with new file structure
- [ ] All files under 500 LOC
