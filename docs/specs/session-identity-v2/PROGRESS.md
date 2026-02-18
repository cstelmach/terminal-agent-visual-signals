# Progress Log

**Spec:** docs/specs/session-identity-v2/SPEC.md
**Plan:** docs/specs/session-identity-v2/PLAN.md
**Status:** In Progress

---

## Phases

| Phase | Status | Started | Completed | Notes |
|-------|--------|---------|-----------|-------|
| Phase 0: Configuration Foundation | Completed | 2026-02-18 | 2026-02-18 | All pools, config vars, backward compat mapping |
| Phase 1: Identity Registry Core | Completed | 2026-02-18 | 2026-02-18 | 429 lines, 12 functions, all tests pass |
| Phase 2: Directory Icon Module | Completed | 2026-02-18 | 2026-02-18 | 275 lines, 9 functions, 20 tests pass |
| Phase 3: Session Icon Rewrite | Completed | 2026-02-18 | 2026-02-18 | 433 lines, major rewrite, 31 tests pass |
| Phase 4: Hook Data Extraction | Completed | 2026-02-18 | 2026-02-18 | 8 lines, 6 tests pass |
| Phase 5: Core Trigger Integration | Completed | 2026-02-18 | 2026-02-18 | 27 tests pass, all 10 acceptance criteria met |
| Phase 6: Title System Integration | Not Started | | | |
| Phase 7: Configuration Polish | Not Started | | | |
| Phase 8: Documentation Updates | Not Started | | | |

---

## Log

### 2026-02-18 — Phase 0: Configuration Foundation

**What was done:**
- Added `# === IDENTITY SYSTEM ===` section to `defaults.conf` after Session Icons
- All 6 config variables with defaults per Appendix B
- `TAVS_SESSION_ICON_POOL` (77 animals from Appendix A)
- `TAVS_DIR_ICON_POOL` (190 flags from Appendix A)
- `TAVS_DIR_FALLBACK_POOL_A` (26 plants), `TAVS_DIR_FALLBACK_POOL_B` (24 buildings)
- Backward compat: `ENABLE_SESSION_ICONS=false` → `TAVS_IDENTITY_MODE=off`
- Updated `TAVS_TITLE_FORMAT_PERMISSION` to include `{SESSION_ICON}`

**Deviations:**
- Changed `ENABLE_SESSION_ICONS="true"` → `"${ENABLE_SESSION_ICONS:-true}"` to preserve
  env var overrides (matches `ENABLE_MODE_AWARE_PROCESSING` pattern on line 85).
  Without this, the backward compat mapping would never trigger within defaults.conf.
  Full user.conf-based mapping deferred to Phase 7 (theme-config-loader.sh integration).
- Session icon pool count is 77 (not ~80). All animals from Appendix A included;
  the spec estimate was approximate.

### 2026-02-18 — Phase 1: Identity Registry Core

**What was done:**
- Created `src/core/identity-registry.sh` (429 lines, 12 functions)
- `_get_registry_dir()`: routes ephemeral → `/tmp/tavs-identity/`, persistent → `~/.cache/tavs/`
- `_acquire_lock()`/`_release_lock()`: mkdir-based POSIX locks, 2s timeout, spin-wait 50ms
- `_round_robin_next_locked()`: locked counter read-modify-write with pool selection via eval
- `_registry_lookup()`/`_registry_store()`/`_registry_remove()`: safe KV parsing, atomic writes
- `_active_sessions_update()`/`_active_sessions_remove()`: locked index modifications
- `_active_sessions_check_collision()`: read-only scan for same icon from different key
- `_active_sessions_cleanup_stale()`: removes dead TTY entries (same pattern as session-icon.sh)
- `_registry_cleanup_expired()`: TTL-based entry removal

**Locking strategy:**
- `.lock-{type}` protects counter read-modify-write (session, dir counters)
- `.lock-active` protects active-sessions index modifications
- No lock for registry store/remove (accepts concurrent-write risk per spec)

**Deviations:**
- Used separate `.lock-active` for active-sessions instead of sharing `.lock-session`.
  Spec says "same lock as counter operations" but separate lock avoids contention and
  simplifies the API (active-sessions functions don't need a `type` parameter).
  Functionally equivalent — both serialize writes.

### 2026-02-18 — Phase 2: Directory Icon Module

**What was done:**
- Created `src/core/dir-icon.sh` (275 lines, 9 functions)
- `_git_with_timeout()`: platform-aware git with 1s timeout (timeout → gtimeout → bare)
- `_detect_worktree()`: subshell-protected worktree detection via git-common-dir comparison
- `_resolve_dir_identity()`: configurable cwd/git-root resolution mode
- `_hash_path()`: stable numeric path hash via cksum
- `_select_dir_pool()` / `_get_worktree_pool()`: pool routing with fallback alternation
- `_assign_icon_for_path()`: registry lookup → round-robin → hash-based fallback
- `assign_dir_icon()`: idempotent assignment with cwd-based cache hit detection
- `get_dir_icon()`: returns single flag or `main→worktree` format (Decision D06)
- `release_dir_icon()`: removes per-TTY cache, preserves registry mapping

**Per-TTY cache format:**
- Added `cwd` field (not in spec) for reliable idempotency checking. Without it,
  comparing against `dir_path` fails in worktree scenarios where dir_path stores the
  main repo path but the cwd is the worktree directory.

**Verified (20 tests):**
- Pool selection (flags/plants/buildings), worktree pool alternation
- Path hashing stability (same path → same hash, different paths → different hashes)
- Deterministic assignment (same cwd → same icon across calls)
- Idempotency (cache hit detection, cwd change detection)
- Non-git directory handling (single flag, no errors)
- Worktree detection with real git worktree (main→worktree format)
- Worktree detection disabled via config (single flag only)
- Git timeout protection (non-git dir returns empty)
- Git-root resolution mode (subdirectories normalized to same icon)
- Full source chain compatibility (no function name collisions)
- Registry persistence across release+reassign
- Sequential round-robin (5 dirs get first 5 flags in pool order)
- Cache file format (KV format, atomic writes)

**Deviations:**
- Added `cwd` field to per-TTY cache format (not in spec's cache format example).
  This stores the raw cwd for idempotency comparison. Without it, the worktree case
  breaks because `dir_path` stores the main repo path, not the cwd the user is in.

### 2026-02-18 — Phase 3: Session Icon Rewrite

**What was done:**
- Major rewrite of `src/core/session-icon.sh` (433 lines, up from 167)
- Preserved all 3 public function signatures: `assign_session_icon()`,
  `get_session_icon()`, `release_session_icon()` (backward compatible API)
- Added internal functions: `_get_session_key()`, `_detect_legacy_icon_file()`,
  `_legacy_random_assign()`, `_legacy_cleanup_stale()`, `_legacy_register()`

**Architecture:**
- **Dual code paths**: `TAVS_IDENTITY_MODE=off` → legacy v1 path (exact original behavior);
  `dual`/`single` → v2 deterministic path using identity-registry.sh
- **Session key resolution** (`_get_session_key`): `TAVS_SESSION_ID[:8]` for Claude Code,
  `TTY_SAFE` fallback for non-Claude agents (Decision D11)
- **Idempotency with collision re-check** (lines 233-289): On cache hit (key matches),
  collision status is re-evaluated. This handles the case where another session ends
  between prompts, clearing a 2-icon pair back to single. Per spec D14: re-evaluated
  at SessionStart + UserPromptSubmit.
- **Hash-based fallback** (lines 323-327): When round-robin lock timeout occurs,
  cksum hash selects from pool as backstop (spec: "collision overflow backstop")
- **Graceful degradation**: Uses `type func &>/dev/null` guards before calling
  identity-registry functions. Module works even if identity-registry.sh isn't sourced.

**Collision overflow (Decision D01, D13):**
- At assignment time, grep active-sessions for same primary from different session_key
- If collision: assign secondary via round-robin, both stored in registry
- Per-TTY cache records `collision_active=true`
- `get_session_icon()` returns `"primary secondary"` (space-separated pair)
- When other session ends → next `assign_session_icon()` detects no collision →
  updates cache to `collision_active=false` → single icon display

**Legacy format migration (spec Key Technical Detail 7):**
- v1→v2: `_detect_legacy_icon_file()` checks first line for `=` delimiter.
  If v1 format detected, file is removed and fresh v2 assignment occurs.
- v2→v1: When mode switches to `off`, existing v2 files are detected (first line
  contains `=`) and removed before legacy random assignment.
- `get_session_icon()`: Auto-detects format on read — supports both v1 (single emoji)
  and v2 (structured KV) transparently.

**Per-TTY cache format (v2):**
```
session_key=abc123de
primary=🦊
secondary=🐙
collision_active=false
```

**Release behavior (Decision D13):**
- `release_session_icon()` removes per-TTY cache and active-sessions entry
- Does NOT remove registry mapping (session keeps its assigned icon for reuse)
- Also handles legacy format: detects v1 files and cleans legacy registry too

**Verified (31 tests):**
- `_get_session_key()`: first 8 chars of session_id, TTY_SAFE fallback (Tests 1-2)
- `_detect_legacy_icon_file()`: v1=true, v2=false, missing=false (Tests 3-5)
- Legacy mode: random assign, v1 format, idempotent, release (Tests 6-8)
- v2 assignment: deterministic icon, KV format, 4 fields present (Tests 9-11)
- v2 determinism: same session_id → same icon, cross-TTY (Tests 12-13)
- v2 idempotency: re-call preserves icon (Test 14)
- v2 uniqueness: different session_id → different icon (Test 15)
- v2 release: registry preserved, active-sessions cleared (Tests 16-17)
- Sequential round-robin: 5 unique IDs → first 5 pool entries in order (Test 18)
- Legacy v1→v2 migration: v1 file replaced with v2 KV format (Test 19)
- v2→v1 migration: mode switch to off replaces v2 with v1 format (Test 20)
- Collision 2-icon overflow: pair shown during active collision (Test 21)
- Collision clear: single icon restored, primary preserved (Test 22)
- Non-Claude agent: TTY_SAFE as session key, single mode (Test 23)
- `get_session_icon()` auto-format: reads v1, v2-collision, v2-single (Test 24)
- Full source chain: all modules load without error or collisions (Test 25)

**Deviations from spec/plan:**
- `dir-icon.sh` is NOT sourced by `session-icon.sh` — they are peer modules sourced
  separately by trigger.sh. The plan mentioned `_assign_icon_for_path()` in dir-icon.sh
  but session-icon.sh has no dependency on it.
- File is 433 lines (plan estimated 250-300). The additional lines come from thorough
  documentation headers, the legacy code path preservation (89 lines), and robust
  collision re-check on the idempotent path.

### 2026-02-18 — Phase 4: Hook Data Extraction

**What was done:**
- Added 8 lines to `src/agents/claude/trigger.sh` (lines 36-44) extracting
  `session_id` and `cwd` from Claude Code hook JSON stdin
- Follows exact same `sed` pattern as existing `permission_mode` (line 27-29)
  and `transcript_path` (line 32-34) extractions
- Both fields exported as `TAVS_SESSION_ID` and `TAVS_CWD` environment variables
- Conditional export: only set when field is non-empty (graceful for missing fields)

**Verified (6 tests):**
- All fields present: session_id, cwd, permission_mode, transcript_path all extracted
- Whitespace around colons: `"session_id" : "value"` handled correctly
- Missing session_id and cwd: empty vars, no errors
- Empty stdin: no vars set, no errors
- CWD with spaces in path: `/Users/cs/My Projects/cool app` preserved
- Only session_id present (no cwd): session_id extracted, cwd empty

**Deviations:** None. Implementation matches spec exactly.

### 2026-02-18 — Phase 5: Core Trigger Integration

**What was done:**
- Modified `hooks/hooks.json`: SessionEnd now sends `trigger.sh reset session-end`
- Added `_load_identity_modules()` helper to `src/core/trigger.sh` (lazy-loads
  identity-registry.sh + dir-icon.sh; guarded by `_TAVS_IDENTITY_LOADED` flag)
- Added `_revalidate_identity()` helper: calls `assign_session_icon` (idempotent,
  handles key changes + collision re-check) then `assign_dir_icon` (dual mode only)
- Modified `processing)` case: on `new-prompt`, calls `_load_identity_modules` +
  `_revalidate_identity` (unless `TAVS_IDENTITY_MODE=off`)
- Rewrote `reset)` case with SessionStart/SessionEnd differentiation:
  - SessionEnd (`$2 == "session-end"`): releases both icons before normal cleanup
  - SessionStart: assigns session icon (v2 or legacy depending on mode)
  - Non-Claude agents: also assigns dir icon at reset (no UserPromptSubmit hook)
  - Legacy fallback: `ENABLE_SESSION_ICONS=true` → `assign_session_icon` in off mode

**Key design decisions:**
- `_revalidate_identity()` always calls `assign_session_icon()` instead of explicitly
  comparing session keys. This is simpler than the spec's code example while providing
  identical behavior — `assign_session_icon()` already handles key mismatch (re-assign)
  and cache hit (collision re-check only). This satisfies spec D14 requirement of
  collision re-evaluation at both SessionStart and UserPromptSubmit.
- Non-Claude agent dir icon assignment at reset guarded by `TAVS_AGENT != "claude"`.
  Claude defers dir icon to `new-prompt` where `TAVS_CWD` is available from hook JSON.
- Zsh compat: intermediate vars for brace defaults throughout (`_default_mode_p`,
  `_default_mode_r`, `_id_mode_r`)

**Files modified:**
- `hooks/hooks.json` — 1 line changed (SessionEnd command)
- `src/core/trigger.sh` — ~60 lines added/changed (2 helpers + modified processing + reset)

**Verified (27 tests):**
- Static (14): hooks.json correctness, function existence, processing/reset case structure,
  lazy loading, session-icon.sh unconditional sourcing, legacy fallback, off mode guard,
  dual mode guard for dir icon
- Functional (13): full source chain, session icon assignment, dir icon deferral for Claude,
  dir icon on new-prompt, idempotency, cwd change detection, session_id change re-assignment,
  SessionEnd release, registry persistence, legacy v1 format, single mode, ENABLE_SESSION_ICONS=false,
  non-Claude agent dir icon at reset

**Deviations from spec:**
- Simplified `_revalidate_identity()` to always call `assign_session_icon()` instead
  of explicit key comparison. Same behavior (idempotent path handles it), simpler code.
  Spec's explicit comparison is an optimization that skips file I/O when key matches,
  but the idempotent path reads one small file (~4 lines) which is negligible for a
  once-per-prompt operation.
