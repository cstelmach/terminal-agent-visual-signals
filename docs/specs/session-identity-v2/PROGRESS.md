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
| Phase 3: Session Icon Rewrite | Not Started | | | |
| Phase 4: Hook Data Extraction | Not Started | | | |
| Phase 5: Core Trigger Integration | Not Started | | | |
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
