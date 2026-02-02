# Plan: TAVS Codebase Modularization

## Summary

Refactor TAVS shell scripts to achieve ≤500 LOC per file with clear separation of concerns, eliminate duplication, and rename files for self-documentation.

**Branch:** `refactor/modularization`
**Worktree:** `.worktrees/refactor-modularization`

---

## 🔄 HANDOFF SECTION

### Current Status: Phase 4 COMPLETE ✅ | Ready for Phase 5/6

**Last Updated:** 2026-02-02
**Last Commit:** `0a707f6 refactor(phase4): Modularize configure.sh into 9 focused modules`

---

### Progress Overview

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 0 | ✅ COMPLETE | Test safety harness (359 tests passing) |
| Phase 1 | ✅ COMPLETE | Extract core module files (4 new files created) |
| Phase 2 | ✅ COMPLETE | Wire up modules, remove duplicates (-540 lines) |
| Phase 3 | ✅ COMPLETE | Rename 6 core files for self-documentation |
| Phase 4 | ✅ COMPLETE | Modularize configure.sh (9 modules, 1,059→352 LOC) |
| Phase 5 | 🔲 NEXT | Update all source statements |
| Phase 6 | 🔲 Pending | Verify and deploy |

---

### What Has Been Completed

#### Phase 0: Test Safety Harness ✅

**Purpose:** Build comprehensive test coverage as a safety net BEFORE touching production code.

| Step | Work Done |
|------|-----------|
| 0.1 Audit | Created `coverage-audit.md` mapping all 100+ shell functions |
| 0.2 Fix Tests | Fixed 30 failing tests (TAVS_AGENT system, env override pattern) |
| 0.3 Add Tests | Created 4 new test files with 153 new tests |

**Test files created:**
- `tests/test_colors.py` (405 LOC) - hex/rgb/hsl conversions, interpolation
- `tests/test_title_state_persistence.py` (410 LOC) - state file operations
- `tests/test_terminal_detection.py` (354 LOC) - terminal type, SSH, TrueColor
- `tests/test_spinner.py` (312 LOC) - spinner state, eye generation

**Test files modified:**
- `tests/test_themes.py` - Rewritten for agent-based face system
- `tests/test_title_composition.py` - Added TAVS_AGENT parameter
- `tests/test_config.py` - Updated default expectations
- `tests/test_configure.py` - Updated function existence checks

**Commit:** `64ff746 test(phase0): Build comprehensive test safety harness`

---

#### Phase 1: Extract Core Module Files ✅

**Purpose:** Create new module files by COPYING (not moving) functions. Original files unchanged - this is a safe extraction that doesn't break existing code.

**Why copy first?**
- No breaking changes during extraction
- Tests continue to pass throughout
- Can verify new files work before removing from originals
- Rollback is trivial (just delete new files)

**Files created:**

| New File | LOC | Functions Extracted | Source File |
|----------|-----|---------------------|-------------|
| `src/core/face-selection.sh` | 112 | `_resolve_agent_faces()`, `get_random_face()` | theme.sh |
| `src/core/dynamic-color-calculation.sh` | 249 | `_source_colors_if_needed()`, `_source_detect_if_needed()`, `initialize_dynamic_colors()`, `load_session_colors_or_defaults()`, `refresh_colors_if_needed()`, `get_effective_color()` | theme.sh |
| `src/core/title-state-persistence.sh` | 218 | `get_title_state_file()`, `_generate_session_id()`, `init_session_id()`, `_read_title_state_value()`, `load_title_state()`, `_escape_for_state_file()`, `save_title_state()`, `clear_title_state()` | title.sh |
| `src/core/palette-mode-helpers.sh` | 98 | `should_send_bg_color()`, `_get_palette_mode()` | trigger.sh |

**Verification performed:**
- ✅ All 4 files pass `bash -n` syntax check
- ✅ All 4 files pass `zsh -n` syntax check
- ✅ All 359 tests still pass
- ✅ Manual trigger test works

**Commit:** `b229279 feat(phase1): Extract core module files (no breaking changes)`

---

### Test Suite Status

```
Before Phase 0: 206 passing, 30 failing
After Phase 0:  359 passing, 0 failing
After Phase 1:  359 passing, 0 failing (no changes - copy approach)
After Phase 2:  359 passing, 0 failing (1 test path updated)
After Phase 3:  359 passing, 0 failing (8 test files updated for new names)
After Phase 4:  362 passing, 0 failing (3 new tests for modular structure)
```

---

#### Phase 2: Wire Up Modules ✅

**Purpose:** Wire up the new modules by adding source statements and removing duplicate code from original files.

**Steps completed:**
1. ✅ theme.sh: Added source statements, removed 8 duplicated functions
2. ✅ title.sh: Added source statement, removed 9 duplicated functions
3. ✅ trigger.sh: Added source statement, removed 2 duplicated functions
4. ✅ idle-worker.sh: Removed 2 duplicated functions, updated function calls

**LOC reduction achieved:**

| File | Before | After | Reduction |
|------|--------|-------|-----------|
| theme.sh | 787 | 509 | -278 |
| title.sh | 627 | 465 | -162 |
| trigger.sh | 329 | 277 | -52 |
| idle-worker.sh | 252 | 204 | -48 |
| **Total** | **1,995** | **1,455** | **-540** |

**Verification performed:**
- ✅ All 16 core files pass `bash -n` syntax check
- ✅ All 16 core files pass `zsh -n` syntax check
- ✅ All 359 tests still pass
- ✅ Manual trigger test works

**Commit:** `32e9ef7 refactor(phase2): Wire up extracted modules, remove duplicates`

---

#### Phase 3: Rename Core Files ✅

**Purpose:** Rename 6 core files for self-documentation and LLM discoverability.

**Files renamed:**

| Old Name | New Name | Purpose |
|----------|----------|---------|
| `theme.sh` | `theme-config-loader.sh` | Config loading + color resolution |
| `title.sh` | `title-management.sh` | Title composition + API |
| `detect.sh` | `terminal-detection.sh` | Terminal capability detection |
| `terminal.sh` | `terminal-osc-sequences.sh` | OSC escape sequence output |
| `state.sh` | `session-state.sh` | Session persistence |
| `idle-worker.sh` | `idle-worker-background.sh` | Background idle timer |

**Files updated with new paths:**
- `src/core/trigger.sh` - Main orchestrator
- `src/core/backgrounds.sh` - Test function
- `configure.sh` - Configuration wizard
- 8 test files with source statement updates
- Comments in extracted modules

**Verification performed:**
- ✅ All 16 core files pass `bash -n` syntax check
- ✅ All 16 core files pass `zsh -n` syntax check
- ✅ All 359 tests pass
- ✅ Manual trigger test works

**Commit:** `4352a7a refactor(phase3): Rename 6 core files for self-documentation`

---

#### Phase 4: Modularize configure.sh ✅

**Purpose:** Split 1,059 LOC configure.sh into 9 focused modules.

**Files created:**

| New File | Purpose | LOC |
|----------|---------|-----|
| `configure.sh` | Main orchestrator, sources modules | 352 |
| `configure-utilities.sh` | Shared helpers (colors, prompts) | 100 |
| `configure-step-operating-mode.sh` | Step 1: static/dynamic/preset | 46 |
| `configure-step-theme-preset.sh` | Step 2: Theme selection | 65 |
| `configure-step-light-dark-mode.sh` | Step 3: Light/dark switching | 55 |
| `configure-step-ascii-faces.sh` | Step 4: Anthropomorphising | 68 |
| `configure-step-backgrounds.sh` | Step 5: Stylish backgrounds | 95 |
| `configure-step-terminal-title.sh` | Step 6: Title mode + spinner | 289 |
| `configure-step-palette-theming.sh` | Step 7: OSC 4 palette | 88 |

**Verification performed:**
- ✅ All 9 configure*.sh files pass `bash -n` syntax check
- ✅ All 9 configure*.sh files pass `zsh -n` syntax check
- ✅ All 362 tests pass (3 new tests added)
- ✅ ./configure.sh --help works
- ✅ ./configure.sh --list shows all presets
- ✅ Manual trigger test works

**Commit:** `0a707f6 refactor(phase4): Modularize configure.sh into 9 focused modules`

---

### What's Next: Phase 5 & 6 - Final Verification and Deploy

Phase 5 (Update All Source Statements) may be unnecessary as all source paths were updated during Phases 2-4.

Phase 6 (Verify and Deploy):
1. Final syntax verification
2. Full test suite
3. Manual testing
4. Update plugin cache
5. Live test in Claude Code

---

### Key Technical Context for Next Developer

#### 1. Environment Variable Override Pattern (CRITICAL)
When testing shell scripts that source `theme.sh`, environment variables set BEFORE sourcing are overwritten by `defaults.conf`. Tests must set variables AFTER sourcing:
```bash
source src/core/theme.sh
export ENABLE_ANTHROPOMORPHISING="false"  # Must be AFTER source
```

#### 2. Agent Face System
The old `FACE_THEME` variable is **deprecated**. Current system uses:
- `TAVS_AGENT` environment variable (claude, gemini, codex, opencode, unknown)
- `get_random_face(state)` for face selection
- Agent-specific faces in `defaults.conf` as `CLAUDE_FACES_PROCESSING`, etc.
- `TAVS_AGENT=unknown` gives predictable fallback faces for testing

#### 3. Source Order Matters
In shell scripts, functions must be defined before they're called. The source order in trigger.sh is:
1. theme-config-loader.sh (sources face-selection.sh, dynamic-color-calculation.sh)
2. session-state.sh
3. terminal-osc-sequences.sh
4. spinner.sh
5. idle-worker-background.sh (uses shared functions from palette-mode-helpers.sh)
6. terminal-detection.sh
7. backgrounds.sh
8. title-management.sh (sources title-state-persistence.sh)
9. palette-mode-helpers.sh

#### 4. Idle Worker Runs in Background
`idle-worker-background.sh` functions run in a background subshell spawned by trigger.sh. They use file descriptor `>&3` for output. After Phase 2, idle-worker-background.sh uses the shared `should_send_bg_color()` and `_get_palette_mode()` functions from palette-mode-helpers.sh instead of its own `_idle_*` prefixed duplicates.

#### 5. File Locations
- **Working directory:** `/Users/cs/.claude/hooks/terminal-agent-visual-signals/.worktrees/refactor-modularization`
- **Branch:** `refactor/modularization`
- **Tests:** `tests/` directory, run with `pytest tests/ -v`
- **Core modules:** `src/core/`
- **Config:** `src/config/defaults.conf`

---

### Verification Commands

```bash
# Navigate to worktree
cd /Users/cs/.claude/hooks/terminal-agent-visual-signals/.worktrees/refactor-modularization

# Check branch
git branch --show-current  # Should be: refactor/modularization

# Check for uncommitted changes
git status

# Run full test suite (MUST be 359 passing)
pytest tests/ -v

# Syntax check all shell scripts
for f in src/core/*.sh; do bash -n "$f" || echo "FAIL: $f"; done
for f in src/core/*.sh; do zsh -n "$f" || echo "FAIL: $f"; done

# Manual visual test
./src/core/trigger.sh processing && sleep 1 && ./src/core/trigger.sh reset

# Check LOC counts
wc -l src/core/*.sh | sort -n
```

---

### Git Commit History (Most Recent First)

```
b229279 feat(phase1): Extract core module files (no breaking changes)
904af95 docs: Add modularization plan with handoff section
64ff746 test(phase0): Build comprehensive test safety harness
aba7838 Merge pull request #3 from cstelmach/feature/intelligent-title-management
```

---

### Files Summary

#### Files Created in Phase 0-1

| File | Purpose | LOC |
|------|---------|-----|
| `coverage-audit.md` | Test coverage documentation | ~290 |
| `PLAN-modularization.md` | This plan file | ~350 |
| `tests/test_colors.py` | Color math tests | 405 |
| `tests/test_terminal_detection.py` | Terminal detection tests | 354 |
| `tests/test_title_state_persistence.py` | State persistence tests | 410 |
| `tests/test_spinner.py` | Spinner tests | 312 |
| `src/core/face-selection.sh` | Face selection module | 112 |
| `src/core/dynamic-color-calculation.sh` | Dynamic color module | 249 |
| `src/core/title-state-persistence.sh` | Title state module | 218 |
| `src/core/palette-mode-helpers.sh` | Palette helpers module | 98 |

#### Files to be Modified in Phase 2

| File | Current LOC | Target LOC | Change |
|------|-------------|------------|--------|
| `src/core/theme.sh` | 787 | ~440 | -347 |
| `src/core/title.sh` | 627 | ~450 | -177 |
| `src/core/trigger.sh` | 329 | ~280 | -49 |
| `src/core/idle-worker.sh` | 252 | ~217 | -35 |

---

### Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Breaking source paths | Update all references in single commit, test immediately |
| Circular dependencies | New files are pure utilities with no cross-sourcing |
| Function not found errors | Verify source order; functions must be defined before use |
| Zsh compatibility | Run `zsh -n` syntax check on all files |
| Test regressions | Run full test suite after each step |

---

### Phase 2 Commit Strategy

After completing each step, verify tests pass, then commit atomically:

1. After Step 2.1: `git commit -m "refactor(theme): Wire up face-selection.sh and dynamic-color-calculation.sh"`
2. After Step 2.2: `git commit -m "refactor(title): Wire up title-state-persistence.sh"`
3. After Step 2.3: `git commit -m "refactor(trigger,idle): Wire up palette-mode-helpers.sh, eliminate duplication"`

Or combine into single commit if all steps completed together:
```bash
git commit -m "refactor(phase2): Wire up extracted modules, remove duplicates

- theme.sh now sources face-selection.sh and dynamic-color-calculation.sh
- title.sh now sources title-state-persistence.sh
- trigger.sh and idle-worker.sh now use shared palette-mode-helpers.sh
- Removed duplicate functions from original files
- All 359 tests pass
"
```

---

## Remaining Phases (After Phase 2)

### Phase 3: Rename Core Files

**Purpose:** Rename 6 core files for self-documentation and LLM discoverability.

```bash
git mv src/core/theme.sh src/core/theme-config-loader.sh
git mv src/core/title.sh src/core/title-management.sh
git mv src/core/detect.sh src/core/terminal-detection.sh
git mv src/core/terminal.sh src/core/terminal-osc-sequences.sh
git mv src/core/state.sh src/core/session-state.sh
git mv src/core/idle-worker.sh src/core/idle-worker-background.sh
```

Then update all internal source statements to use new names.

### Phase 4: Modularize configure.sh

Split 1,059 LOC configure.sh into 9 focused modules (~50-270 LOC each).

### Phase 5: Update All Source Statements

Ensure all source paths are correct after all renames and extractions.

### Phase 6: Verify and Deploy

Comprehensive verification, update plugin cache, test in Claude Code.

---

## Exit Criteria

- [ ] All core shell scripts pass `bash -n` syntax check
- [ ] All core shell scripts pass `zsh -n` syntax check
- [ ] All tests pass: `pytest tests/ -v` (359 tests)
- [ ] Manual test: `./src/core/trigger.sh processing` works
- [ ] Configure wizard: `./configure.sh` runs through all steps
- [ ] Plugin cache updated with new file structure
- [ ] All files under 500 LOC
