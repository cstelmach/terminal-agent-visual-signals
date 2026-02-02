# Plan: TAVS Codebase Modularization

## Summary

Refactor TAVS shell scripts to achieve ≤500 LOC per file with clear separation of concerns, eliminate duplication, and rename files for self-documentation.

**Branch:** `refactor/modularization`
**Worktree:** `.worktrees/refactor-modularization`

---

## 🔄 HANDOFF SECTION

### Current Status: Phase 1 COMPLETE ✅ | Ready for Phase 2

**Last Updated:** 2026-02-02
**Last Commit:** `b229279 feat(phase1): Extract core module files (no breaking changes)`

---

### Progress Overview

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 0 | ✅ COMPLETE | Test safety harness (359 tests passing) |
| Phase 1 | ✅ COMPLETE | Extract core module files (4 new files created) |
| Phase 2 | 🔲 NEXT | Wire up modules, remove duplicates |
| Phase 3 | 🔲 Pending | Rename core files |
| Phase 4 | 🔲 Pending | Modularize configure.sh |
| Phase 5 | 🔲 Pending | Update all source statements |
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
```

---

### What's Next: Phase 2 - Update Core Source Files

**Purpose:** Wire up the new modules by adding source statements and removing duplicate code from original files.

**This is where the actual modularization takes effect.** After Phase 2:
- theme.sh LOC: 787 → ~440 (removing ~347 lines)
- title.sh LOC: 627 → ~450 (removing ~177 lines)
- trigger.sh LOC: 329 → ~280 (removing ~49 lines)
- idle-worker.sh LOC: 252 → ~217 (removing ~35 lines)

---

#### Step 2.1: Update theme.sh to source extracted modules

**Current state:** theme.sh (787 LOC) contains functions that are now duplicated in face-selection.sh and dynamic-color-calculation.sh.

**Actions:**
1. Add source statements after line 27 (after `_USER_CONFIG` definition):
   ```bash
   # Source extracted modules
   source "${_THEME_SCRIPT_DIR}/face-selection.sh"
   source "${_THEME_SCRIPT_DIR}/dynamic-color-calculation.sh"
   ```

2. Remove these functions from theme.sh (they now live in face-selection.sh):
   - `_resolve_agent_faces()` (lines 126-170)
   - `get_random_face()` (lines 178-208)

3. Remove these functions from theme.sh (they now live in dynamic-color-calculation.sh):
   - `_source_colors_if_needed()` (lines 577-588)
   - `_source_detect_if_needed()` (lines 591-602)
   - `initialize_dynamic_colors()` (lines 607-674)
   - `load_session_colors_or_defaults()` (lines 678-719)
   - `refresh_colors_if_needed()` (lines 723-746)
   - `get_effective_color()` (lines 750-773)

4. Verify: `pytest tests/ -v` (should still be 359 passing)

**Important:** The function `load_agent_config()` calls `_resolve_agent_faces()` at line 74. After sourcing face-selection.sh, this will work because the function is defined before it's called.

---

#### Step 2.2: Update title.sh to source title-state-persistence.sh

**Current state:** title.sh (627 LOC) contains state persistence functions that are now duplicated in title-state-persistence.sh.

**Actions:**
1. Add source statement near the top (after shebang and header comments):
   ```bash
   # Source extracted modules
   _TITLE_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
   source "${_TITLE_SCRIPT_DIR}/title-state-persistence.sh"
   ```

2. Remove these items from title.sh (they now live in title-state-persistence.sh):
   - `TITLE_STATE_DB` variable (line 17)
   - `get_title_state_file()` (lines 20-22)
   - `_generate_session_id()` (lines 26-62)
   - `init_session_id()` (lines 65-67)
   - `_read_title_state_value()` (lines 77-101)
   - `load_title_state()` (lines 105-124)
   - `_escape_for_state_file()` (lines 128-136)
   - `save_title_state()` (lines 140-177)
   - `clear_title_state()` (lines 180-184)

3. Verify: `pytest tests/ -v`

---

#### Step 2.3: Update trigger.sh and idle-worker.sh for shared palette helpers

**Current state:** trigger.sh has `should_send_bg_color()` and `_get_palette_mode()`. idle-worker.sh has nearly identical `_idle_should_send_bg_color()` and `_idle_get_palette_mode()`. Both are now in palette-mode-helpers.sh.

**Actions for trigger.sh:**
1. Add source statement after other module sources (around line 38):
   ```bash
   source "$CORE_DIR/palette-mode-helpers.sh"
   ```

2. Remove these functions from trigger.sh:
   - `should_send_bg_color()` (lines 111-122)
   - `_get_palette_mode()` (lines 127-159)

3. Keep `_apply_palette_if_enabled()` and `_reset_palette_if_enabled()` - they call the shared functions.

**Actions for idle-worker.sh:**
1. The idle-worker.sh file doesn't source modules directly (it's sourced by trigger.sh). The shared functions will be available because trigger.sh sources palette-mode-helpers.sh before sourcing idle-worker.sh.

2. Remove these duplicate functions from idle-worker.sh:
   - `_idle_should_send_bg_color()` (lines 10-22)
   - `_idle_get_palette_mode()` (lines 26-60)

3. Update function calls in `unified_timer_worker()`:
   - Change `_idle_should_send_bg_color` → `should_send_bg_color`
   - Change `_idle_get_palette_mode` → `_get_palette_mode`

4. Verify: `pytest tests/ -v`

---

#### Step 2.4: Verify All Source Wiring

```bash
# Syntax checks
bash -n src/core/*.sh
zsh -n src/core/*.sh

# Full test suite
pytest tests/ -v

# Manual verification
./src/core/trigger.sh processing && sleep 1 && ./src/core/trigger.sh reset
```

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
1. theme.sh (sources face-selection.sh, dynamic-color-calculation.sh)
2. state.sh
3. terminal.sh
4. spinner.sh
5. idle-worker.sh (uses functions from above)
6. detect.sh
7. backgrounds.sh
8. title.sh (sources title-state-persistence.sh)
9. palette-mode-helpers.sh (NEW - add here)

#### 4. Idle Worker Runs in Background
`idle-worker.sh` functions run in a background subshell spawned by trigger.sh. They use file descriptor `>&3` for output. The `_idle_*` prefix was used to distinguish duplicate functions - after Phase 2, we use the shared functions directly.

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
