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
| Phase 2: Directory Icon Module | Not Started | | | |
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
