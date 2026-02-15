# Progress Log

**Spec:** `docs/specs/SPEC-dynamic-title-templates.md`
**Plan:** `docs/specs/PLAN-dynamic-title-templates.md`
**Status:** Phase 2 Complete

---

## Phases

| Phase | Status | Started | Completed | Notes |
|-------|--------|---------|-----------|-------|
| Phase 0: Git Worktree Setup | Complete | 2026-02-15 | 2026-02-15 | Pulled main (16 commits, v3.0.0), worktree at `../tavs-dynamic-titles` |
| Phase 1: Context Data System | Complete | 2026-02-15 | 2026-02-15 | TDD: 107/107 tests pass. All 10 token types verified. |
| Phase 2: Per-State Title Format System | Complete | 2026-02-15 | 2026-02-15 | TDD: 50/50 tests pass. 4-level fallback + 16 new tokens. |
| Phase 3: StatusLine Bridge | Not Started | | | |
| Phase 4: Transcript Fallback | Not Started | | | |
| Phase 5: Configuration & Documentation | Not Started | | | |
| Phase 6: Deploy & Integration Test | Not Started | | | |

---

## Log

### 2026-02-15 — Phase 0: Git Worktree Setup

- Pulled main to latest (`0965b25`, v3.0.0) — was 16 commits behind (config-ux-overhaul, tavs CLI)
- Created branch `feature/dynamic-title-templates` and worktree at `../tavs-dynamic-titles`
- Verified all critical line numbers still match spec after v3.0.0 update
- **Deviation:** Plugin version is now 3.0.0 (spec/plan reference 2.0.0 in places). Cache path
  is `tavs/3.0.0/`. Plan Phase 6 deploy commands need adjustment.
- **Deviation:** `user.conf.template` is now 343 lines (was 463). Phase 5 will adapt.
- Committed spec, plan, and progress files as initial feature branch commit

### 2026-02-15 — Phase 1: Context Data System

- **TDD approach:** Wrote 107-assertion test script first (RED), then implemented (GREEN)
- Created `src/core/context-data.sh` (~280 lines) with:
  - `load_context_data()`: bridge state → transcript fallback chain
  - `read_bridge_state()`: safe key=value parsing (never source, per TAVS patterns)
  - `resolve_context_token()`: 10 display token types (FOOD, FOOD_10, ICON, NUMBER,
    PCT, BAR_H, BAR_HL, BAR_V, BAR_VM, BRAILLE)
  - `_estimate_from_transcript()`: file-size estimation (stub, completed in Phase 4)
  - Format helpers: `_format_cost`, `_format_duration`, `_format_lines`
- Added ~110 lines to `defaults.conf`: per-state title formats, 6 icon arrays,
  bridge config (max age, window size, bar chars)
- Sourced in `trigger.sh` after `session-icon.sh`
- Tests verify: all 21 food entries, all boundary values, edge cases (empty/stale/missing),
  clamping (>100), format helpers, bridge state parsing with mock files
- **No deviations** from plan

### 2026-02-15 — Phase 2: Per-State Title Format System

- **TDD approach:** Wrote 50-assertion test script first (RED: 37 fail, 13 pass), then implemented (GREEN: 50/50)
- Modified `compose_title()` in `title-management.sh` (lines 321-384):
  - 4-level format fallback: agent+state → agent → global+state → global
  - State name normalization: lowercase → uppercase, hyphens → underscores
  - Context token substitution (16 new tokens) guarded by string check
  - `load_context_data()` called only when context/metadata tokens present in format
- Modified `_resolve_agent_variables()` in `theme-config-loader.sh`:
  - Added 9 new vars: TITLE_FORMAT + TITLE_FORMAT_{8 states}
  - Enables {AGENT}_TITLE_FORMAT_{STATE} resolution (e.g., CLAUDE_TITLE_FORMAT_PERMISSION)
- Tests cover: fallback chain priority, all 10 context token types + 5 metadata tokens,
  empty token collapse, backward compatibility, all 8 state names, performance guard,
  full integration with mock bridge data
- **No deviations** from plan
