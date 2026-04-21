# Implementation Plan — Fix Broken TAVS Terminal Tab Title

**Spec:** /Users/cs/.claude/plans/serene-knitting-stardust.md
**Created:** 2026-04-07
**Agent:** execute-spec (manual mode)

---

## Problem

Terminal tab title shows raw session-icon KV pairs and standard text eyes instead
of compact emoji eyes with formatted context data.

## Pre-Execution Investigation Findings

Before starting phases, investigation revealed:
- Plugin cache matches source (no desync)
- `compose_title()` produces **correct output** when tested from shell
- Config loading works (compact_project_sorted preset applies correctly)
- `get_session_icon()` parses KV file correctly
- **But:** `LAST_TAVS_TITLE` is empty for ttys026 (title write not completing)
- **But:** Other sessions (ttys011, ttys062) show correct titles
- 149 session-icon cache files, 58 for dead TTYs
- 28 active-sessions entries, most for dead TTYs

The bug is **environmental** — specific to hook execution context, not the source code logic.

---

## Phases

| # | Phase | Dependencies | Status |
|---|-------|-------------|--------|
| 1 | Diagnostic Instrumentation | None | Not Started |
| 2 | Clean Stale State | None | Not Started |
| 3 | Fix Root Cause | Phase 1 findings | Not Started |
| 4 | Sync & Integration Test | Phase 3 | Not Started |
| 5 | Live CC Session Verification | Phase 4 | Not Started |
| 6 | Commit & Cleanup | Phase 5 | Not Started |

### Phase 1: Diagnostic Instrumentation
Add title-specific debug logging to `debug_log_invocation()` and each trigger case.
Log: config values after loading, compose_title output, title write success/failure.

### Phase 2: Clean Stale State
Remove 58 dead TTY cache files, reset active-sessions index, clear stale title state files.

### Phase 3: Fix Root Cause
Based on Phase 1 diagnostics. Most likely: title write to TTY_DEVICE failing in
hook subprocess context (printf redirect fails silently, preventing state save).

### Phase 4: Sync & Integration Test
Run `./tavs sync`, `./tavs test --quick`, `./tavs test`.

### Phase 5: Live CC Session Verification
New session + prompt interaction + permission flow + multi-session test.

### Phase 6: Commit & Cleanup
Commit fix, final sync, verify post-commit.
