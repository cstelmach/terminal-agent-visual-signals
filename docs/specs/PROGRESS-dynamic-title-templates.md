# Progress Log

**Spec:** `docs/specs/SPEC-dynamic-title-templates.md`
**Plan:** `docs/specs/PLAN-dynamic-title-templates.md`
**Status:** Phase 5 Complete

---

## Phases

| Phase | Status | Started | Completed | Notes |
|-------|--------|---------|-----------|-------|
| Phase 0: Git Worktree Setup | Complete | 2026-02-15 | 2026-02-15 | Pulled main (16 commits, v3.0.0), worktree at `../tavs-dynamic-titles` |
| Phase 1: Context Data System | Complete | 2026-02-15 | 2026-02-15 | TDD: 107/107 tests pass. All 10 token types verified. |
| Phase 2: Per-State Title Format System | Complete | 2026-02-15 | 2026-02-15 | TDD: 50/50 tests pass. 4-level fallback + 16 new tokens. |
| Phase 3: StatusLine Bridge | Complete | 2026-02-15 | 2026-02-15 | TDD: 47/47 tests pass. Bridge + transcript_path. |
| Phase 4: Transcript Fallback | Complete | 2026-02-15 | 2026-02-15 | TDD: 31/31 tests pass. Verified existing implementation. |
| Phase 5: Configuration & Documentation | Complete | 2026-02-15 | 2026-02-15 | 164 lines added across 2 files. All 235 tests still pass. |
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

### 2026-02-15 — Phase 3: StatusLine Bridge

- **TDD approach:** Wrote 47-assertion test script first (RED: 25 fail, 10 pass), then implemented (GREEN: 47/47)
- Created `src/agents/claude/statusline-bridge.sh` (109 lines):
  - Silent data siphon — reads StatusLine JSON from stdin, writes state file, zero stdout
  - Inlined `resolve_tty()` from `terminal-osc-sequences.sh:41-58` (avoids sourcing heavy deps)
  - Inlined state dir logic from `spinner.sh:16-24`
  - sed-based JSON extraction (no jq), filters literal "null" values
  - Atomic mktemp+mv write to `~/.cache/tavs/context.{TTY_SAFE}`
  - Test overrides: `_TAVS_BRIDGE_STATE_DIR`, `_TAVS_BRIDGE_TTY_SAFE`
- Modified `src/agents/claude/trigger.sh` (+4 lines):
  - Extracts `transcript_path` from hook JSON payload (same sed pattern as permission_mode)
  - Exports as `TAVS_TRANSCRIPT_PATH` for context fallback estimation
- Initial GREEN had 7 failures: sed `_extract` regex captured trailing `}`
  from JSON values like `45}`. Fixed by adding `}` to exclusion set: `[^\",}]*`
- Tests cover: bridge silence, field extraction, partial/null/empty JSON,
  integration with `read_bridge_state()`, atomic write, state dir creation,
  overwrite behavior, realistic Claude Code JSON, trigger.sh transcript_path
- **No deviations** from plan
- Cumulative: 204/204 tests pass (Phase 1: 107 + Phase 2: 50 + Phase 3: 47)

### 2026-02-15 — Phase 4: Transcript Fallback

- **Verification phase:** `_estimate_from_transcript()` was fully implemented in Phase 1 (not
  a stub as plan anticipated). Phase 4 adds thorough TDD test coverage.
- Created `tests/test-transcript-fallback.sh` (31 assertions):
  - Correct percentage calculation: 350K→50%, 700K→100%, 35K→5%, 35B→0%
  - Clamping: 1.4M file → clamps to 100% (not 200%)
  - Custom context window: 350K with 1M window → 10%
  - Graceful handling: missing file, empty file, empty path all return 1 without error
  - Env var: uses `TAVS_TRANSCRIPT_PATH` when no argument given
  - Isolation: only sets `TAVS_CONTEXT_PCT`, does NOT touch model/cost/duration/lines
  - Fallback chain: load_context_data with no bridge → transcript → correct PCT
  - Priority: bridge preferred over transcript when both available
  - Stale bridge: stale bridge data skipped → transcript fallback used
  - No data: both missing → all context vars empty, returns 1
- **No code changes needed** — Phase 1 implementation passed all 31 tests immediately
- **No deviations** from plan
- Cumulative: 235/235 tests pass (Phase 1: 107 + Phase 2: 50 + Phase 3: 47 + Phase 4: 31)

### 2026-02-15 — Phase 5: Configuration & Documentation

- Updated `src/config/user.conf.template` (+68 lines):
  - Per-state title formats section with all 15 new token descriptions
  - Per-agent title format overrides section with 4-level fallback chain
  - Context icon customization section (copy-paste arrays for food and circles)
  - StatusLine bridge setup section with step-by-step instructions
  - Bridge staleness configuration
- Updated `CLAUDE.md` (+96 lines):
  - Key Files table: added `context-data.sh` and `statusline-bridge.sh`
  - Variable naming convention: added per-state title format entry
  - Title Format Tokens table: expanded from 5 to 20 tokens (all context + metadata)
  - New "Per-State Title Formats" section: 4-level fallback chain with examples
  - New "StatusLine Bridge" section: setup guide with shell script examples
  - Testing commands: added per-state format and bridge test examples
- All 235/235 tests pass (no regressions)
- **No deviations** from plan
- Commit: `e136cfd`
