# Test Coverage Audit

**Date:** 2026-02-02
**Initial Baseline:** 30 failing tests, 206 passing tests
**After Phase 0:** 359 passing tests, 0 failing
**Branch:** refactor/modularization

## Summary

The test suite has significant gaps:
1. **30 failing tests** due to outdated face theme expectations
2. **Missing tests** for key shell functions
3. **Tests organized by file** rather than by concern

---

## Failing Tests Analysis

### Root Cause: Deprecated Face Theme System

The failing tests in `test_title_composition.py` and `test_themes.py` expect the old `FACE_THEME` variable system:

| Test Expectation | Reality |
|------------------|---------|
| `FACE_THEME=minimal` → `(°-°)` | New system uses `TAVS_AGENT=claude` → `Ǝ[• •]E` |
| `get_face(theme, state)` | Deprecated, delegates to `get_random_face(state)` |
| Static theme selection | Agent-specific faces with random selection |

### Affected Test Files

| File | Failing Tests | Root Cause |
|------|---------------|------------|
| `test_title_composition.py` | 12 | Expects minimal theme faces |
| `test_themes.py` | 18 | Tests obsolete theme system |

### Fix Strategy

1. **Update tests** to use `TAVS_AGENT=unknown` for fallback behavior (gets minimal faces)
2. **Add new tests** for agent-specific face selection
3. **Remove tests** for deprecated `FACE_THEME` system OR mark as legacy

---

## Function Coverage Matrix

### Core Module: theme.sh (787 LOC, 20 functions)

| Function | Has Test | Priority | Notes |
|----------|----------|----------|-------|
| `_load_config_file()` | ❌ | High | Config loading |
| `load_agent_config()` | ❌ | High | Main entry point |
| `_resolve_agent_variables()` | ❌ | High | Agent variable resolution |
| `_resolve_agent_faces()` | ❌ | High | Face array resolution |
| `get_random_face()` | ❌ | High | Random face selection |
| `_set_inline_defaults()` | ✅ (partial) | Medium | Tested via config tests |
| `_resolve_colors()` | ❌ | High | Color mode resolution |
| `_detect_system_mode()` | ❌ | Medium | macOS/Linux detection |
| `clear_mode_cache()` | ❌ | Low | Cache utility |
| `refresh_colors()` | ❌ | Low | Refresh utility |
| `_build_stage_arrays()` | ❌ | Medium | Stage color interpolation |
| `_interpolate_stage_color()` | ❌ | Medium | HSL interpolation |
| `apply_theme()` | ❌ | Medium | Theme preset application |
| `list_themes()` | ❌ | Low | Theme listing |
| `_source_colors_if_needed()` | ❌ | Low | Lazy loading |
| `_source_detect_if_needed()` | ❌ | Low | Lazy loading |
| `initialize_dynamic_colors()` | ❌ | Medium | Dynamic mode init |
| `load_session_colors_or_defaults()` | ❌ | Medium | Session color loading |
| `refresh_colors_if_needed()` | ❌ | Low | Auto-refresh |
| `get_effective_color()` | ❌ | Medium | Color retrieval |

### Core Module: title.sh (627 LOC, 20 functions)

| Function | Has Test | Priority | Notes |
|----------|----------|----------|-------|
| `get_title_state_file()` | ✅ | N/A | Tested |
| `_read_title_state_value()` | ❌ | Medium | Safe state parsing |
| `_escape_for_state_file()` | ❌ | Medium | Escape logic |
| `save_title_state()` | ❌ | Medium | State persistence |
| `load_title_state()` | ❌ | Medium | State loading |
| `clear_title_state()` | ❌ | Low | Cleanup |
| `init_session_id()` | ✅ | N/A | Tested |
| `_generate_session_id()` | ✅ | N/A | Tested |
| `detect_user_title_change()` | ❌ | High | User override detection |
| `set_user_title()` | ❌ | Medium | Set user title |
| `clear_user_title()` | ❌ | Low | Clear user title |
| `is_title_locked()` | ❌ | Medium | Lock check |
| `lock_tavs_title()` | ❌ | Low | Lock title |
| `unlock_tavs_title()` | ❌ | Low | Unlock title |
| `_extract_base_from_title()` | ❌ | Medium | Title parsing |
| `get_base_title()` | ❌ | Medium | Base title retrieval |
| `get_fallback_title()` | ✅ | N/A | Tested |
| `compose_title()` | ✅ | N/A | Tested (but needs fixes) |
| `set_tavs_title()` | ❌ | Medium | Title setter |
| `reset_tavs_title()` | ❌ | Medium | Title reset |

### Core Module: trigger.sh (329 LOC, 6 functions)

| Function | Has Test | Priority | Notes |
|----------|----------|----------|-------|
| `should_change_state()` | ✅ | N/A | Tested |
| `record_state()` | ✅ | N/A | Tested |
| `debug_log_invocation()` | ❌ | Low | Debug only |
| `should_send_bg_color()` | ❌ | Medium | Palette mode check |
| `_get_palette_mode()` | ❌ | Medium | Mode determination |
| `_apply_palette_if_enabled()` | ❌ | Medium | Palette application |
| `_reset_palette_if_enabled()` | ❌ | Medium | Palette reset |

### Core Module: detect.sh (454 LOC, 14 functions)

| Function | Has Test | Priority | Notes |
|----------|----------|----------|-------|
| `get_terminal_type()` | ❌ | Medium | Terminal detection |
| `get_terminal_info()` | ❌ | Low | Terminal info |
| `is_ssh_session()` | ❌ | Medium | SSH detection |
| `is_truecolor_mode()` | ❌ | Medium | TrueColor detection |
| `detect_system_dark_mode()` | ❌ | Medium | System mode |
| `get_color_mode()` | ❌ | Medium | Color mode |
| `get_system_mode()` | ❌ | Low | Wrapper |
| `query_terminal_bg()` | ❌ | Medium | Background query |
| `query_terminal_bg_with_timeout()` | ❌ | Medium | With timeout |
| `supports_background_images()` | ❌ | Low | Capability check |
| `_test_detect()` | ❌ | Low | Self-test |
| `_test_colors()` | ❌ | Low | Self-test |
| `_test_backgrounds()` | ❌ | Low | Self-test |
| `validate_integer()` | ❌ | Low | Validation |

### Core Module: colors.sh (558 LOC, 15 functions)

| Function | Has Test | Priority | Notes |
|----------|----------|----------|-------|
| `hex_to_rgb()` | ❌ | High | Core conversion |
| `rgb_to_hex()` | ❌ | High | Core conversion |
| `rgb_to_hsl()` | ❌ | High | Core conversion |
| `hsl_to_rgb()` | ❌ | High | Core conversion |
| `_hue_to_rgb()` | ❌ | Low | Helper |
| `is_dark_color()` | ❌ | Medium | Darkness check |
| `calculate_luminance()` | ❌ | Medium | Luminance calc |
| `shift_hue()` | ❌ | Medium | Hue shift |
| `adjust_saturation()` | ❌ | Medium | Saturation adjust |
| `adjust_lightness()` | ❌ | Medium | Lightness adjust |
| `interpolate_color()` | ❌ | Medium | RGB interpolation |
| `interpolate_hsl()` | ❌ | Medium | HSL interpolation |

### Core Module: terminal.sh (246 LOC, 10 functions)

| Function | Has Test | Priority | Notes |
|----------|----------|----------|-------|
| `resolve_tty()` | ❌ | Medium | TTY resolution |
| `send_bell_if_enabled()` | ❌ | Low | Bell |
| `send_osc_bg()` | ✅ (partial) | Medium | Background OSC |
| `send_osc_palette()` | ❌ | Medium | Palette OSC |
| `send_osc_palette_reset()` | ❌ | Medium | Palette reset |
| `send_osc_title()` | ✅ | N/A | Tested (but outdated) |
| `sanitize_for_terminal()` | ✅ | N/A | Tested |
| `get_short_cwd()` | ✅ | N/A | Tested |

### Core Module: idle-worker.sh (252 LOC, 8 functions)

| Function | Has Test | Priority | Notes |
|----------|----------|----------|-------|
| `get_unified_stage()` | ✅ | N/A | Tested |
| `unified_timer_worker()` | ✅ (partial) | Medium | Worker main |
| `kill_idle_timer()` | ✅ (existence) | Low | Timer kill |
| `cleanup_stale_timers()` | ✅ (existence) | Low | Cleanup |
| `_idle_get_palette_mode()` | ❌ | Medium | **Duplicate** |
| `_idle_should_send_bg_color()` | ❌ | Medium | **Duplicate** |
| `_idle_send_palette()` | ❌ | Low | Palette send |
| `_idle_reset_palette()` | ❌ | Low | Palette reset |

### Core Module: state.sh (226 LOC, 13 functions)

| Function | Has Test | Priority | Notes |
|----------|----------|----------|-------|
| `read_state_value()` | ❌ | Medium | State reading |
| `write_state_file()` | ❌ | Medium | State writing |
| `read_session_state()` | ❌ | Medium | Session state |
| `write_session_state()` | ❌ | Medium | Session state |
| `get_state_priority()` | ❌ | Medium | Priority check |
| `write_skip_signal()` | ❌ | Low | Signal file |
| `check_and_clear_skip_signal()` | ❌ | Low | Signal check |
| `has_session_colors()` | ❌ | Medium | Color check |
| `read_session_colors()` | ❌ | Medium | Color reading |
| `write_session_colors()` | ❌ | Medium | Color writing |
| `clear_session_colors()` | ❌ | Low | Color cleanup |
| `get_session_color()` | ❌ | Medium | Color retrieval |

### Core Module: spinner.sh (388 LOC, 12 functions)

| Function | Has Test | Priority | Notes |
|----------|----------|----------|-------|
| `get_spinner_state_dir()` | ❌ | Low | Dir path |
| `get_spinner_index_file()` | ❌ | Low | File path |
| `get_session_spinner_file()` | ❌ | Low | File path |
| `init_session_spinner()` | ❌ | Medium | Init spinner |
| `is_spinner_active()` | ❌ | Medium | Active check |
| `get_spinner_index()` | ❌ | Low | Index read |
| `write_index_file()` | ❌ | Low | Index write |
| `get_single_spinner()` | ❌ | Medium | Single char |
| `get_spinner_eyes()` | ❌ | High | Main API |
| `reset_spinner()` | ❌ | Low | Reset |

### Core Module: backgrounds.sh (357 LOC, 9 functions)

| Function | Has Test | Priority | Notes |
|----------|----------|----------|-------|
| `supports_background_images()` | ❌ | Low | Capability |
| `get_background_info()` | ❌ | Low | Image info |
| `set_state_background_image()` | ❌ | Medium | Set image |
| `clear_background_image()` | ❌ | Low | Clear image |
| `_set_bg_image_kitty()` | ❌ | Low | Kitty-specific |
| `_clear_bg_image_kitty()` | ❌ | Low | Kitty-specific |

---

## Test File Structure Analysis

### Current Structure (by source file)

| Test File | LOC | Tests | What It Tests |
|-----------|-----|-------|---------------|
| `test_config.py` | 188 | Config loading, defaults | ✅ Good |
| `test_configure.py` | 117 | Configure wizard | ✅ Good |
| `test_idle_worker.py` | 195 | Idle worker behavior | ✅ Good |
| `test_shell_compatibility.py` | 311 | Bash/Zsh parity | ✅ Good |
| `test_themes.py` | 151 | **DEPRECATED** theme system | ❌ Outdated |
| `test_title.py` | 327 | Title management | ✅ Good |
| `test_title_composition.py` | 241 | Title composition | ⚠️ Face tests outdated |
| `test_trigger.py` | 214 | Trigger states | ✅ Good |

### Target Structure (by concern)

| New Test File | From | Tests What |
|---------------|------|------------|
| `test_theme_config_loader.py` | test_themes.py (refactored) | Config loading, agent resolution |
| `test_face_selection.py` | new | get_random_face(), agent faces |
| `test_dynamic_color_calculation.py` | new | Dynamic mode, color interpolation |
| `test_title_management.py` | test_title.py | Title composition, API |
| `test_title_state_persistence.py` | new | State file operations |
| `test_terminal_detection.py` | new | detect.sh functions |
| `test_palette_mode_helpers.py` | new | Shared palette logic |
| `test_configure_wizard.py` | test_configure.py | Wizard steps |
| `test_colors.py` | new | Color math functions |

---

## Priority Actions

### Phase 0.2: Fix Failing Tests

1. Update `test_title_composition.py`:
   - Set `TAVS_AGENT=unknown` to get fallback minimal faces
   - OR update expectations to match claude agent faces

2. Update `test_themes.py`:
   - Remove tests for deprecated `FACE_THEME` variable
   - Add tests for `get_random_face()` with agent-specific faces

### Phase 0.3: Add Missing High-Priority Tests

| Function | Priority | Test File |
|----------|----------|-----------|
| `load_agent_config()` | High | test_theme_config_loader.py |
| `_resolve_agent_variables()` | High | test_theme_config_loader.py |
| `_resolve_agent_faces()` | High | test_face_selection.py |
| `get_random_face()` | High | test_face_selection.py |
| `hex_to_rgb()` / `rgb_to_hex()` | High | test_colors.py |
| `get_spinner_eyes()` | High | test_spinner.py |
| `detect_user_title_change()` | High | test_title_management.py |

---

## Duplication Issues

### idle-worker.sh Duplicates trigger.sh

| Duplicate in idle-worker.sh | Original in trigger.sh |
|-----------------------------|------------------------|
| `_idle_get_palette_mode()` | `_get_palette_mode()` |
| `_idle_should_send_bg_color()` | `should_send_bg_color()` |

**Action:** Extract to `palette-mode-helpers.sh` in Phase 1

---

## Exit Criteria for Phase 0

- [ ] All 30 failing tests fixed (expectations updated)
- [ ] Test files reorganized to match target structure
- [ ] Every high-priority function has at least one test
- [ ] Test files under 300 LOC each
- [ ] All tests have docstrings
