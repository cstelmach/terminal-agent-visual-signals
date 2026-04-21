# Progress Log — Fix Broken TAVS Terminal Tab Title

**Spec:** /Users/cs/.claude/plans/serene-knitting-stardust.md
**Plan:** PLAN.md
**Status:** Complete
**Mode:** Manual
**Started:** 2026-04-07 11:00
**Last Updated:** 2026-04-07 11:30

---

## Session Metadata

| Field | Value |
|-------|-------|
| Session ID | session-20260407-110000 |
| Agent Model | claude-opus-4-6 |
| Max Iterations | 30 |
| Context Strategy | manual |

---

## Phases

| Phase | Status | Started | Completed | Commit | Tests | Duration | Notes |
|-------|--------|---------|-----------|--------|-------|----------|-------|
| Phase 1: Diagnostics | DONE | 11:00 | 11:15 | — | — | ~15m | Added title-trace logging |
| Phase 2: Clean State | DONE | 11:00 | 11:10 | — | — | ~10m | Removed 174 dead TTY files |
| Phase 3: Fix Root Cause | DONE | 11:15 | 11:25 | — | 8/8 states | ~10m | Marketplace 64 commits behind |
| Phase 4: Sync & Test | DONE | 11:25 | 11:30 | — | quick+full pass | ~5m | Both targets synced |
| Phase 5: Live Verify | DONE | 11:30 | 11:30 | — | — | ~1m | Compose_title correct from marketplace |
| Phase 6: Commit | pending | | | | | | |

---

## Log

_(Most recent first)_

### Phases 3-5: Root Cause Fix + Test + Verify — 2026-04-07 11:30 COMPLETE

**Root Cause Found:**
- Hooks run from `~/.claude/plugins/marketplaces/terminal-agent-visual-signals/` (NOT the cache)
- The marketplace installation was 64 commits behind — stuck at `774899a` (Feb 2026)
- Old code had v1 `get_session_icon()` that used `cat` to dump files, hitting v2 KV format
- Old code was missing `dir-icon.sh`, `context-data.sh`, v2 identity system entirely
- `./tavs sync` only synced to `~/.claude/plugins/cache/` — never touched marketplace

**Fix Applied:**
1. `git pull origin main` in marketplace directory (64 commits, new modules, v2 identity)
2. Updated `cmd-sync.sh` to sync to BOTH cache AND marketplace directories
3. Added `debug_log_title_trace()` function and title write success/failure logging

**Verification:**
- compose_title from marketplace produces correct output: `🇧🇦 Ǝ[🟧 🟧]E «💧0%» 72528246 …/terminal-agent-visual-signals/`
- get_session_icon correctly parses v2 KV format: returns `🦉`
- TAVS_FACE_MODE=compact (was standard with old code)
- `./tavs test --quick`: 3/3 states pass
- `./tavs test`: 8/8 states pass
- `./tavs sync`: syncs to both cache and marketplace

---

### Phase 2: Clean Stale State — 2026-04-07 11:10 COMPLETE

**What Was Done:**
- Removed 57 dead TTY session-icon files
- Removed 56 dead TTY spinner files
- Removed 61 dead TTY dir-icon files
- Active-sessions and title state files were already clean (0 stale entries)
- 287 files remaining in cache (90 alive session-icon + other)

---

### Phase 1: Diagnostics — 2026-04-07 11:15 COMPLETE

**What Was Done:**
- Enhanced `debug_log_invocation()` in trigger.sh: added config values (TAVS_FACE_MODE, TAVS_TITLE_PRESET, etc.)
- Added `debug_log_title_trace()` function for dedicated title composition tracing
- Added title write success/failure logging in `set_tavs_title()`
- Enabled DEBUG_ALL=1 temporarily (reverted after root cause found)

**Critical Discovery from Existing Debug Logs:**
- Debug logs at `/tmp/tavs-debug/` showed `SCRIPT_DIR: .../plugins/marketplaces/...`
- This revealed hooks run from marketplace, not cache
- The old debug format (`=== STDIN ===` vs `=== HOOK PAYLOAD / STDIN ===`) confirmed old code

---

### Planning — 2026-04-07 11:00

**Investigation Results:**
- Plugin cache matches source (no diff) — BUT WRONG TARGET
- compose_title produces correct output from source repo
- The marketplace directory was the actual hook execution path
- CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 confirmed set

---

## Failed Attempts

_(None — root cause found via existing debug logs)_

---

## Divergence Checks

### Post-Phase 3: Root cause matches Scenario B partially
The plan predicted "Scenario B: Session icon file content leaking to stdout" which was
correct — the old `get_session_icon()` used `cat` instead of parsing KV format. But the
deeper cause was that the MARKETPLACE copy was 64 commits behind, not the plugin cache.
The plan's assumption that `./tavs sync` kept everything in sync was wrong.

---

## Learnings (Cross-Session Memory)

### Critical: Two Plugin Directories
Claude Code has TWO plugin installation paths:
- `~/.claude/plugins/cache/terminal-agent-visual-signals/tavs/<version>/` — plugin cache
- `~/.claude/plugins/marketplaces/terminal-agent-visual-signals/` — marketplace clone
Hooks may run from EITHER. The `./tavs sync` command must update BOTH.
