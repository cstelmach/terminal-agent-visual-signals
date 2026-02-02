# Plan: TAVS Codebase Modularization

## Summary

Refactor TAVS shell scripts to achieve ≤500 LOC per file with clear separation of concerns, eliminate duplication, and rename files for self-documentation.

**Branch:** `refactor/modularization`
**Worktree:** `.worktrees/refactor-modularization`

---

## 🔄 HANDOFF SECTION

### Current Status: Phase 1 COMPLETE ✅

**Last Updated:** 2026-02-02
**Last Commit:** Pending commit of Phase 1 work

### What Has Been Completed

#### Phase 0: Test Safety Harness ✅ COMPLETE
- **Phase 0.1**: Created `coverage-audit.md` documenting all functions and test status
- **Phase 0.2**: Fixed 30 failing tests (TAVS_AGENT, env override pattern, face system)
- **Phase 0.3**: Added 4 new test files (test_colors.py, test_title_state_persistence.py, test_terminal_detection.py, test_spinner.py)
- **Result**: 359 passing tests, 0 failing

#### Phase 1: Extract Core Module Files ✅ COMPLETE

| New File | LOC | Functions Extracted |
|----------|-----|---------------------|
| `src/core/face-selection.sh` | 112 | `_resolve_agent_faces()`, `get_random_face()` |
| `src/core/dynamic-color-calculation.sh` | 249 | `_source_colors_if_needed()`, `_source_detect_if_needed()`, `initialize_dynamic_colors()`, `load_session_colors_or_defaults()`, `refresh_colors_if_needed()`, `get_effective_color()` |
| `src/core/title-state-persistence.sh` | 218 | `get_title_state_file()`, `_generate_session_id()`, `init_session_id()`, `_read_title_state_value()`, `load_title_state()`, `_escape_for_state_file()`, `save_title_state()`, `clear_title_state()` |
| `src/core/palette-mode-helpers.sh` | 98 | `should_send_bg_color()`, `_get_palette_mode()` |

**All new files pass bash -n and zsh -n syntax checks ✅**
**All 359 tests still pass ✅**
**Total new LOC: 677 (all under 500 LOC per file) ✅**

### Test Suite Status

```
Before Phase 0: 206 passing, 30 failing
After Phase 0:  359 passing, 0 failing
After Phase 1:  359 passing, 0 failing (unchanged - no breaking changes)
```

### What's Next: Phase 2 - Update Core Source Files

Phase 2 wires up the new modules by adding source statements and removing duplicates.

#### Step 2.1: Update theme.sh to source extracted modules
- Add at top of theme.sh:
  ```bash
  source "${_THEME_SCRIPT_DIR}/face-selection.sh"
  source "${_THEME_SCRIPT_DIR}/dynamic-color-calculation.sh"
  ```
- Remove the now-duplicated functions from theme.sh
- Run tests: `pytest tests/ -v`

#### Step 2.2: Update title.sh to source title-state-persistence.sh
- Add source line at top of title.sh
- Remove duplicated functions from title.sh
- Run tests

#### Step 2.3: Update trigger.sh and idle-worker.sh for shared palette helpers
- Add source line to both files: `source "$CORE_DIR/palette-mode-helpers.sh"`
- Remove `should_send_bg_color()` and `_get_palette_mode()` from trigger.sh
- Remove `_idle_should_send_bg_color()` and `_idle_get_palette_mode()` from idle-worker.sh
- Run tests

#### Step 2.4: Verify All Source Wiring
```bash
bash -n src/core/*.sh
zsh -n src/core/*.sh
pytest tests/ -v
./src/core/trigger.sh processing && sleep 1 && ./src/core/trigger.sh reset
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
