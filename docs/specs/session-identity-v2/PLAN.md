# Implementation Plan: Session Identity System v2

**Spec:** `docs/specs/session-identity-v2/SPEC.md`
**Created:** 2026-02-18
**Agent:** Fresh agent from /plan-from-spec

---

## Context

TAVS currently assigns random animal emoji per TTY device for terminal tab identification.
This feature replaces that with a deterministic, registry-based dual-identity system that
ties icons to Claude Code session IDs (animals) and working directories (flags). Terminal
tabs become consistently identifiable: same session always shows the same animal, same
directory always shows the same flag. When collisions occur among active sessions, a
2-icon overflow pair disambiguates them.

**Problem:** Random icons change on every session restart and have no directory awareness.
Users with multiple tabs cannot quickly identify which project/conversation each represents.

**Outcome:** Titles show `«🇩🇪|🦊»` — deterministic directory flag + session animal.

---

## Prerequisites

- All work happens on a feature branch (use git worktree)
- No external dependencies needed (pure bash, uses existing `cksum`, `mkdir`, `sed`)
- Familiarity with TAVS patterns: atomic writes, safe parsing, zsh compat, TTY_SAFE

---

## Mandatory Workflow: Spec Re-Read Before Each Phase

**CRITICAL**: Before starting ANY phase, the implementing agent MUST:

1. **Re-read the relevant SPEC sections** — Open `docs/specs/session-identity-v2/SPEC.md`
   and read the specific phase description, its acceptance criteria, and the referenced
   Decisions & Rationale entries. This ensures no drift from the spec's intent.
2. **Cross-check with the plan** — Verify this plan's steps match the spec. If any
   discrepancy is found, the spec is authoritative (the plan is derived from it).
3. **Update PROGRESS.md** — Mark the phase as "In Progress" before writing code.

This prevents the implementing agent from relying on stale memory or assumptions that
may have diverged during long implementation sessions or context resets.

---

## First Steps: PLAN.md and PROGRESS.md Setup

Before any code changes, create two tracking files:

### 1. Create `docs/specs/session-identity-v2/PLAN.md`

Copy the content of THIS plan file into `docs/specs/session-identity-v2/PLAN.md`.
This becomes the canonical plan co-located with the spec. The plan file at
`/Users/cs/.claude/plans/quiet-inventing-walrus.md` is the draft; the one in the
spec directory is the living document updated during implementation.

### 2. Create `docs/specs/session-identity-v2/PROGRESS.md`

```markdown
# Progress Log

**Spec:** docs/specs/session-identity-v2/SPEC.md
**Plan:** docs/specs/session-identity-v2/PLAN.md
**Status:** Not Started

---

## Phases

| Phase | Status | Started | Completed | Notes |
|-------|--------|---------|-----------|-------|
| Phase 0: Configuration Foundation | Not Started | | | |
| Phase 1: Identity Registry Core | Not Started | | | |
| Phase 2: Directory Icon Module | Not Started | | | |
| Phase 3: Session Icon Rewrite | Not Started | | | |
| Phase 4: Hook Data Extraction | Not Started | | | |
| Phase 5: Core Trigger Integration | Not Started | | | |
| Phase 6: Title System Integration | Not Started | | | |
| Phase 7: Configuration Polish | Not Started | | | |
| Phase 8: Documentation Updates | Not Started | | | |

---

## Log

_(Updated during implementation. Each entry: date, phase, what was done, any deviations.)_
```

### 3. Commit both files before starting Phase 0

This creates a clean checkpoint. After every completed phase:
- Update PROGRESS.md (mark phase complete, add log entry)
- Commit all changes atomically
- Return to the checkpoint prompt (see bottom of this plan)

---

## Phase 0: Configuration Foundation

**Scope:** Add all new config variables, expanded icon pools, and identity system
defaults to `defaults.conf`. Prerequisite for ALL subsequent phases.

**Before starting:** Re-read SPEC.md sections: "Phase 0: Configuration Foundation"
(lines 670-726), "Appendix A: Complete Icon Pools" (lines 1537-1611),
"Appendix B: Configuration Reference" (lines 1615-1649), and Decision D10 (Default Mode).

### Implementation Steps

1. Add `# === IDENTITY SYSTEM ===` section to `src/config/defaults.conf` (after Session Icons section, ~line 268):
   - `TAVS_IDENTITY_MODE="dual"` (single/dual/off)
   - `TAVS_IDENTITY_PERSISTENCE="ephemeral"` (ephemeral/persistent)
   - `TAVS_DIR_IDENTITY_SOURCE="cwd"` (cwd/git-root)
   - `TAVS_DIR_WORKTREE_DETECTION="true"`
   - `TAVS_IDENTITY_REGISTRY_TTL=2592000` (30 days)
   - `TAVS_DIR_ICON_TYPE="flags"` (flags/plants/buildings/auto)

2. Add `TAVS_SESSION_ICON_POOL` array (~80 animals from Appendix A)
   - Keep existing `TAVS_SESSION_ICONS` (25 animals) at line 264 for backward compat
   - Add comment explaining the two arrays

3. Add `TAVS_DIR_ICON_POOL` (~190 flags), `TAVS_DIR_FALLBACK_POOL_A` (~26 plants),
   `TAVS_DIR_FALLBACK_POOL_B` (~24 buildings) from Appendix A

4. Add `ENABLE_SESSION_ICONS` → `TAVS_IDENTITY_MODE` mapping after the arrays:
   ```bash
   [[ "${ENABLE_SESSION_ICONS:-true}" == "false" ]] && TAVS_IDENTITY_MODE="off"
   ```

5. Update per-state title formats to include `{SESSION_ICON}` where missing:
   - `TAVS_TITLE_FORMAT_PERMISSION`: add `{SESSION_ICON}` before `{BASE}`
   - `TAVS_TITLE_FORMAT_COMPLETE`: already has `{SESSION_ICON}` (line 149)
   - `TAVS_TITLE_FORMAT_IDLE`: already has `{SESSION_ICON}` (line 150)

### Files to Modify
- `src/config/defaults.conf` — add ~320 lines (new config vars + pool arrays)

### Verification
- [ ] `source defaults.conf` succeeds without errors
- [ ] `${#TAVS_SESSION_ICON_POOL[@]}` ≈ 80
- [ ] `${#TAVS_DIR_ICON_POOL[@]}` ≈ 190
- [ ] Existing `TAVS_SESSION_ICONS` still has 25 items
- [ ] `ENABLE_SESSION_ICONS=false` maps to `TAVS_IDENTITY_MODE=off`
- [ ] Per-state formats for permission/complete/idle include `{SESSION_ICON}`

### Definition of Done
- [ ] All variables from Appendix B have defaults in defaults.conf
- [ ] Pool arrays populated from Appendix A
- [ ] No existing functionality broken when TAVS_IDENTITY_MODE=off

---

## Phase 1: Identity Registry Core

**Scope:** Create the shared registry foundation used by both session and directory
icon modules. Round-robin assignment, filesystem locking, active-sessions index.

**Depends on:** Phase 0 (pool arrays and config variables)

**Before starting:** Re-read SPEC.md sections: "Phase 1: Identity Registry Core"
(lines 729-828), "Key Technical Details" sections 2-4 (Registry File Format,
Round-Robin Algorithm, 2-Icon Collision Overflow, lines 206-304),
and "Key Technical Detail 8" (Persistence Mode Routing, lines 396-414).

### Implementation Steps

1. Create `src/core/identity-registry.sh` with module header following existing patterns

2. Implement `_get_registry_dir()`:
   - Route to `/tmp/tavs-identity/` (ephemeral) or `~/.cache/tavs/` (persistent)
   - Use `get_spinner_state_dir()` for persistent path
   - `mkdir -p` with `chmod 700`

3. Implement `_acquire_lock()` / `_release_lock()`:
   - `mkdir "$lock_dir"` (atomic on POSIX)
   - Spin-wait: `sleep 0.05`, max 40 iterations (2 seconds)
   - Return 1 on timeout

4. Implement `_round_robin_next_locked(type, pool_array_name)`:
   - Acquire lock → read counter → select `pool[counter % size]` → increment → write atomically → release
   - Zsh compat: use `eval` or intermediate vars for indirect array access
   - If lock timeout: return empty (collision overflow backstop handles it)

5. Implement registry CRUD:
   - `_registry_lookup(type, key)` — safe KV parse
   - `_registry_store(type, key, primary, [secondary])` — atomic write preserving other entries
   - `_registry_remove(type, key)` — atomic removal

6. Implement active-sessions index:
   - `_active_sessions_update(tty_safe, session_key, primary_icon)` — add/update (locked)
   - `_active_sessions_remove(tty_safe)` — remove entry (locked)
   - `_active_sessions_check_collision(primary_icon, session_key)` — grep for same icon, different key
   - `_active_sessions_cleanup_stale()` — remove entries for dead TTYs

7. Implement `_registry_cleanup_expired(type, ttl_seconds)`:
   - Remove entries where `(now - timestamp) > ttl_seconds`

### Files to Create
- `src/core/identity-registry.sh` (NEW, ~200-250 lines)

### Reuse
- `get_spinner_state_dir()` from `src/core/spinner.sh:16-33`
- Atomic write pattern from `src/core/session-icon.sh:78-80`
- Safe parsing pattern from `src/core/session-icon.sh:51-55`
- Stale TTY check pattern from `src/core/session-icon.sh:134`

### Verification
```bash
source src/config/defaults.conf
source src/core/spinner.sh
source src/core/identity-registry.sh
# Round-robin: 5 sequential unique icons
for i in $(seq 1 5); do _round_robin_next_locked "test" "TAVS_SESSION_ICON_POOL"; done
# Persistence routing
TAVS_IDENTITY_PERSISTENCE=ephemeral _get_registry_dir  # /tmp/tavs-identity
TAVS_IDENTITY_PERSISTENCE=persistent _get_registry_dir  # ~/.cache/tavs
# Store/lookup
_registry_store "test" "key1" "🦊"
_registry_lookup "test" "key1"  # "🦊||timestamp"
```

### Definition of Done
- [ ] Round-robin returns sequential icons (not random)
- [ ] Counter wraps at pool_size
- [ ] mkdir-based locking works (no TOCTOU)
- [ ] Lock timeout returns empty (graceful degradation)
- [ ] Active-sessions index maintained
- [ ] Stale TTY cleanup works
- [ ] All writes are atomic (mktemp + mv)
- [ ] No `source` of state files
- [ ] Zsh compatible

---

## Phase 2: Directory Icon Module

**Scope:** Deterministic directory→flag mapping with worktree awareness and fallback pools.

**Depends on:** Phase 1 (identity-registry.sh)

**Before starting:** Re-read SPEC.md sections: "Phase 2: Directory Icon Module"
(lines 832-915), "Key Technical Detail 5" (Worktree Detection, lines 306-347),
Decisions D06 (Worktree Format), D07 (Flag Fallback), D12 (Directory Identity Source).

### Implementation Steps

1. Create `src/core/dir-icon.sh` with module header

2. Implement `_git_with_timeout()`:
   - Try `timeout 1 git "$@"`, then `gtimeout 1 git "$@"`, then bare `git "$@"`
   - Platform-aware (macOS lacks `timeout`)

3. Implement `_detect_worktree(cwd)`:
   - Guard: `command -v git` + subshell for cwd protection
   - Compare `--show-toplevel` vs `--git-common-dir` (normalized)
   - Return `"main_path worktree_path"` or fail

4. Implement `_resolve_dir_identity(cwd)`:
   - If `git-root` mode: `git rev-parse --show-toplevel` (with timeout)
   - If `cwd` mode: return as-is

5. Implement `_select_dir_pool()` / `_get_worktree_pool()`:
   - Route to flags/plants/buildings based on `TAVS_DIR_ICON_TYPE`
   - Worktree uses alternate pool from main

6. Implement `assign_dir_icon()`:
   - Get cwd: `TAVS_CWD` or `$PWD`
   - Resolve via `_resolve_dir_identity()`
   - Hash path: `printf '%s' "$path" | cksum | cut -d' ' -f1`
   - Registry lookup → round-robin if new → store
   - If worktree: repeat for worktree path
   - Write per-TTY cache: `dir-icon.{TTY_SAFE}` (KV format)

7. Implement `get_dir_icon()`:
   - Read per-TTY cache
   - Worktree → return `"main_flag→worktree_flag"`
   - Single → return `"flag"`

8. Implement `release_dir_icon()`:
   - Remove per-TTY cache file

### Files to Create
- `src/core/dir-icon.sh` (NEW, ~200-250 lines)

### Verification
```bash
TAVS_CWD=/tmp/test1 assign_dir_icon && get_dir_icon  # some flag
TAVS_CWD=/tmp/test2 assign_dir_icon && get_dir_icon  # different flag
TAVS_CWD=/tmp/test1 assign_dir_icon && get_dir_icon  # same as first
# In actual git worktree:
cd /path/to/worktree && assign_dir_icon && get_dir_icon  # main→worktree
```

### Definition of Done
- [ ] Same cwd → same flag (deterministic)
- [ ] Worktree shows `main_flag→worktree_flag`
- [ ] Non-git directory works (no errors, single flag)
- [ ] Fallback pools work (`TAVS_DIR_ICON_TYPE=plants`)
- [ ] Git commands have timeout protection
- [ ] Path hashing is stable across invocations

---

## Phase 3: Session Icon Rewrite

**Scope:** Replace random-per-TTY with deterministic-per-session_id using registry.

**Depends on:** Phase 1 (identity-registry.sh)

**Before starting:** Re-read SPEC.md sections: "Phase 3: Session Icon Rewrite"
(lines 919-1014), "Key Technical Detail 4" (2-Icon Collision Overflow, lines 274-304),
"Key Technical Detail 7" (Per-TTY Cache File Formats, lines 365-394),
Decisions D01 (Collision Priority), D08 (Pool Size), D11 (Non-Claude Agents), D13 (2nd Icon).

### Implementation Steps

1. Rewrite `src/core/session-icon.sh` preserving the 3 public function signatures:
   `assign_session_icon()`, `get_session_icon()`, `release_session_icon()`

2. Add `_get_session_key()`:
   - If `TAVS_SESSION_ID` set: return first 8 chars
   - Else: return `TTY_SAFE` (backward compat for non-Claude agents)

3. Add `_detect_legacy_icon_file(icon_file)`:
   - Check if file exists and first line lacks `=`
   - If legacy: `rm -f` (allows clean re-assignment)

4. Add `_legacy_random_assign()`:
   - Preserve EXACT current behavior from existing session-icon.sh
   - Uses `TAVS_SESSION_ICONS` (25 animals), random selection, dedup via registry
   - Only called when `TAVS_IDENTITY_MODE=off`

5. Rewrite `assign_session_icon()`:
   - If `TAVS_IDENTITY_MODE=off`: delegate to `_legacy_random_assign()`
   - Detect and remove legacy file format
   - Get session key, check per-TTY cache for idempotency
   - Registry lookup → round-robin if new → store
   - Check collision via `_active_sessions_check_collision()`
   - If collision: assign secondary via round-robin
   - Write per-TTY cache (structured KV format)
   - Update active-sessions index

6. Rewrite `get_session_icon()`:
   - Read per-TTY cache (KV format)
   - If `collision_active=true`: return `"primary secondary"` (two animals)
   - Else: return `"primary"`

7. Rewrite `release_session_icon()`:
   - Remove per-TTY cache
   - Remove from active-sessions index
   - Do NOT remove from registry (mapping persists)

### Files to Modify
- `src/core/session-icon.sh` (MAJOR REWRITE, ~250-300 lines)

### Verification
```bash
# Determinism
TAVS_SESSION_ID=test1234 assign_session_icon && get_session_icon  # animal X
# Different TTY, same session_id → same animal
TTY_SAFE=_dev_ttys002 TAVS_SESSION_ID=test1234 assign_session_icon && get_session_icon
# Legacy mode
TAVS_IDENTITY_MODE=off assign_session_icon && get_session_icon  # random
```

### Definition of Done
- [ ] Same session_id → same primary icon (deterministic)
- [ ] Round-robin cycles through all ~80 animals
- [ ] 2-icon overflow shows pair during active collision
- [ ] Overflow reverts when collision clears
- [ ] Non-Claude agents use TTY_SAFE as key
- [ ] `TAVS_IDENTITY_MODE=off` uses exact legacy random behavior
- [ ] Legacy single-emoji files auto-detected and removed
- [ ] `release_session_icon()` keeps registry mapping

---

## Phase 4: Hook Data Extraction

**Scope:** Extract `session_id` and `cwd` from Claude Code hook JSON stdin.

**Depends on:** Nothing (independent, can parallel with Phases 1-3)

**Before starting:** Re-read SPEC.md sections: "Phase 4: Hook Data Extraction"
(lines 1018-1066), "Key Technical Detail 1" (Session ID Source, lines 192-202).
Also re-read `src/agents/claude/trigger.sh` to confirm current extraction pattern.

### Implementation Steps

1. Add to `src/agents/claude/trigger.sh` after line 34 (after transcript_path extraction):
   ```bash
   # Extract session_id from JSON
   _session_id=$(printf '%s' "$_tavs_stdin" | \
       sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
   [[ -n "$_session_id" ]] && export TAVS_SESSION_ID="$_session_id"

   # Extract cwd from JSON
   _cwd=$(printf '%s' "$_tavs_stdin" | \
       sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
   [[ -n "$_cwd" ]] && export TAVS_CWD="$_cwd"
   ```

### Files to Modify
- `src/agents/claude/trigger.sh` — add 8 lines after line 34

### Verification
```bash
echo '{"session_id":"abc123-def","cwd":"/tmp/test","permission_mode":"plan"}' | \
    bash -c 'source src/agents/claude/trigger.sh processing 2>/dev/null; echo "SID=$TAVS_SESSION_ID CWD=$TAVS_CWD"'
# Expected: SID=abc123-def CWD=/tmp/test
```

### Definition of Done
- [ ] `TAVS_SESSION_ID` populated from `session_id` field
- [ ] `TAVS_CWD` populated from `cwd` field
- [ ] Empty/missing fields → empty vars (no errors)
- [ ] No jq dependency
- [ ] Existing `TAVS_PERMISSION_MODE` and `TAVS_TRANSCRIPT_PATH` still work

---

## Phase 5: Core Trigger Integration

**Scope:** Wire identity registration into the core trigger state machine, including
hooks.json fix for SessionEnd differentiation.

**Depends on:** Phases 1, 2, 3, 4

**Before starting:** Re-read SPEC.md sections: "Phase 5: Core Trigger Integration"
(lines 1070-1167), "Component Interactions" flow diagram (lines 143-186),
Decision D14 (Re-validation Timing). Also re-read current `src/core/trigger.sh`
to understand the `reset)` and `processing)` case blocks.

### Implementation Steps

1. **Fix hooks.json** (spec gap): Change SessionEnd command from
   `trigger.sh reset` to `trigger.sh reset session-end`
   - File: `hooks/hooks.json` line 107

2. Add `_load_identity_modules()` helper to `src/core/trigger.sh` (before case block):
   ```bash
   _load_identity_modules() {
       [[ "${_TAVS_IDENTITY_LOADED:-}" == "true" ]] && return 0
       source "$CORE_DIR/identity-registry.sh"
       source "$CORE_DIR/dir-icon.sh"
       _TAVS_IDENTITY_LOADED="true"
   }
   ```

3. Modify `reset)` case (~line 269-286) to differentiate SessionStart vs SessionEnd:
   - SessionEnd (`$2 == "session-end"`): release both icons
   - SessionStart: assign session icon only (no dir icon — cwd absent)
   - Also try `assign_dir_icon` at reset for non-Claude agents (uses `$PWD`)

4. Add `_revalidate_identity()` helper:
   - Check if session_id changed → re-assign session icon
   - Always re-check dir icon (cwd may have changed)
   - Called from `processing)` case when `$2 == "new-prompt"`

5. Modify `processing)` case (~line 172-174):
   ```bash
   if [[ "${2:-}" == "new-prompt" ]]; then
       reset_subagent_count
       _load_identity_modules
       _revalidate_identity
   fi
   ```

### Files to Modify
- `hooks/hooks.json` — line 107: add `session-end` arg
- `src/core/trigger.sh` — add ~40 lines (helper functions + case modifications)

### Verification
```bash
# Full lifecycle
TAVS_SESSION_ID=test1234 ./src/core/trigger.sh reset              # session icon assigned
TAVS_SESSION_ID=test1234 TAVS_CWD=/tmp/proj ./src/core/trigger.sh processing new-prompt  # dir icon assigned
./src/core/trigger.sh reset session-end                             # both released
# Backward compat
TAVS_IDENTITY_MODE=off ./src/core/trigger.sh reset                 # legacy behavior
```

### Definition of Done
- [ ] SessionStart assigns session icon only (NOT dir icon)
- [ ] Dir icon assigned on first `new-prompt`
- [ ] SessionEnd releases both icons
- [ ] `_revalidate_identity()` catches session_id changes and cwd changes
- [ ] Identity modules lazy-loaded (only on reset and new-prompt)
- [ ] `TAVS_IDENTITY_MODE=off` skips all identity logic
- [ ] `TAVS_IDENTITY_MODE=single` assigns session only, no dir
- [ ] hooks.json SessionEnd sends `reset session-end`
- [ ] No regression in existing state machine

---

## Phase 6: Title System Integration

**Scope:** New token resolution, dynamic guillemet injection, guillemet cleanup.

**Depends on:** Phases 2, 3 (for get_dir_icon, get_session_icon)

**Before starting:** Re-read SPEC.md sections: "Phase 6: Title System Integration"
(lines 1170-1258), "Key Technical Detail 6" (Guillemet Cleanup, lines 348-361),
"Key Technical Detail 9" (Title Format Presets, lines 418-432),
Decisions D02 (Dual Display Format), D09 (Token Structure), D15 (No Composite Token).
Also re-read current `compose_title()` in `src/core/title-management.sh`.

### Implementation Steps

1. In `compose_title()` at `src/core/title-management.sh`, before token resolution
   (before line 369), add dynamic guillemet injection:
   ```bash
   # Dynamic guillemet injection for dual mode
   if [[ "${TAVS_IDENTITY_MODE:-dual}" == "dual" && \
         "$title" == *"{SESSION_ICON}"* && \
         "$title" != *"{DIR_ICON}"* ]]; then
       title="${title//\{SESSION_ICON\}/«{DIR_ICON}|{SESSION_ICON}»}"
   fi
   ```

2. After existing `{SESSION_ICON}` substitution (line 372), add:
   ```bash
   # Resolve {DIR_ICON}
   local dir_icon=""
   if [[ "${TAVS_IDENTITY_MODE:-dual}" == "dual" ]] && type get_dir_icon &>/dev/null; then
       dir_icon=$(get_dir_icon 2>/dev/null)
   fi
   title="${title//\{DIR_ICON\}/$dir_icon}"

   # Resolve {SESSION_ID}
   local session_id_display=""
   if [[ -n "${TAVS_SESSION_ID:-}" ]]; then
       session_id_display="${TAVS_SESSION_ID:0:8}"
   fi
   title="${title//\{SESSION_ID\}/$session_id_display}"
   ```

3. Replace the existing space-collapse sed (line 402) with enhanced guillemet cleanup:
   ```bash
   title=$(printf '%s\n' "$title" | sed \
       -e 's/«|/«/g' \
       -e 's/|»/»/g' \
       -e 's/«»//g' \
       -e 's/  */ /g; s/^ *//; s/ *$//')
   ```

### Files to Modify
- `src/core/title-management.sh` — modify `compose_title()` (~20 lines added/changed)

### Verification
```bash
# Test guillemet cleanup directly
echo '«|🦊»' | sed -e 's/«|/«/g' -e 's/|»/»/g' -e 's/«»//g'  # «🦊»
echo '«🇩🇪|»' | sed -e 's/«|/«/g' -e 's/|»/»/g' -e 's/«»//g'  # «🇩🇪»
echo '«|»' | sed -e 's/«|/«/g' -e 's/|»/»/g' -e 's/«»//g'      # (empty)

# Integration test
TAVS_IDENTITY_MODE=dual TAVS_SESSION_ID=test \
    ./src/core/trigger.sh processing new-prompt
# Verify title contains guillemets
```

### Definition of Done
- [ ] `{DIR_ICON}` resolves to flag in dual mode, empty otherwise
- [ ] Dynamic guillemet injection works (only in dual, only when needed)
- [ ] `{SESSION_ID}` shows first 8 chars
- [ ] Guillemet cleanup handles all 4 cases (|icon», «icon|, «|», «»)
- [ ] Existing format unchanged for single/off modes
- [ ] No regression in existing token resolution
- [ ] Per-state formats with `{SESSION_ICON}` get dynamic injection

---

## Phase 7: Configuration Polish & User Template

**Scope:** Update user.conf.template and theme-config-loader.sh for per-agent overrides.

**Depends on:** Phases 0, 6

**Before starting:** Re-read SPEC.md sections: "Phase 7: Configuration Polish"
(lines 1261-1296), "Appendix B: Configuration Reference" (lines 1615-1649),
and "Backward Compatibility" table (lines 1640-1649).

### Implementation Steps

1. Update `src/config/user.conf.template`:
   - Add Identity System section with all new settings (commented out)
   - Add Format Presets section (Minimal, Standard, Full Identity, Bubble)
   - Document new tokens: `{DIR_ICON}`, `{SESSION_ID}`
   - Document persistence modes

2. Update `src/core/theme-config-loader.sh` `_resolve_agent_variables()`:
   - Add to vars array: `IDENTITY_MODE`, `DIR_ICON_TYPE`
   - This enables per-agent overrides like `CLAUDE_IDENTITY_MODE=single`

### Files to Modify
- `src/config/user.conf.template` — add ~40 lines
- `src/core/theme-config-loader.sh` — add 2 entries to vars array (~line 125)

### Definition of Done
- [ ] user.conf.template documents all new settings
- [ ] Format presets documented with examples
- [ ] Per-agent overrides for identity variables work

---

## Phase 8: Documentation & CLAUDE.md Updates

**Scope:** Update project documentation to reflect new identity system.

**Depends on:** All previous phases

**Before starting:** Re-read SPEC.md sections: "Phase 8: Documentation"
(lines 1298-1318) and the full "New Title Tokens" table (lines 1632-1638).
Also review CLAUDE.md to identify all sections that need updates.

### Implementation Steps

1. Update `CLAUDE.md`:
   - Add identity system to Key Files table
   - Document new tokens in Title Format Tokens table
   - Update Session Icons section
   - Add identity testing commands
   - Document `TAVS_IDENTITY_MODE` settings

2. Update relevant `docs/reference/` files if they reference session icons

### Files to Modify
- `CLAUDE.md` — update ~5 sections
- `docs/reference/dynamic-titles.md` — add new tokens

### Definition of Done
- [ ] CLAUDE.md reflects new identity system
- [ ] Testing commands include identity verification
- [ ] Token docs include `{DIR_ICON}`, `{SESSION_ICON}`, `{SESSION_ID}`

---

## Risk Areas

| Risk | Impact | Mitigation |
|------|--------|------------|
| defaults.conf grows ~320 lines (to ~1250) | Config file bloat | Pool arrays are static data; acceptable for single-source-of-truth |
| Session icon rewrite breaks existing users | High — title changes for everyone | `TAVS_IDENTITY_MODE=off` preserves exact current behavior |
| Dynamic guillemet injection in compose_title | Could affect custom format strings | Only triggers when format has `{SESSION_ICON}` but not `{DIR_ICON}` |
| Concurrent hook races on registry | Counter corruption | mkdir-based locking; 2-icon overflow as backstop |
| Git commands in dir-icon.sh block hooks | 5-second timeout exceeded | Platform-aware timeout helper; fast-fail for non-git dirs |
| Legacy session-icon files cause confusion | Old format silently ignored | Explicit detection and removal of single-emoji format files |

## Sequencing & Dependencies

```
Phase 0 ──────────────────────────────────┐
     │                                     │
     ├─→ Phase 1 ─→ Phase 2 ─────────────┤
     │        └────→ Phase 3 ─────────────┤
     └────────────→ Phase 4 ─────────────┤
                                          │
                                    Phase 5 (needs 1,2,3,4)
                                          │
                                    Phase 6 (needs 2,3)
                                          │
                                    Phase 7 (needs 0,6)
                                          │
                                    Phase 8 (needs all)
```

- Phase 0 MUST be first (all others reference its config vars)
- Phases 1, 4 can start immediately after Phase 0
- Phases 2, 3 depend on Phase 1 but are independent of each other
- Phase 4 is independent — can parallel with Phases 1-3
- Phase 5 is the integration bottleneck (needs 1, 2, 3, 4)
- Phases 6, 7, 8 are sequential after Phase 5

## Verification: End-to-End Test

```bash
# After all phases complete:

# 1. Deploy to plugin cache
./tavs sync

# 2. Open Claude Code, submit a prompt
# Verify title shows: «flag|animal» format

# 3. Open second tab, same project
# Verify: same flag (same dir), different animal (different session)

# 4. Test backward compat
# In user.conf: TAVS_IDENTITY_MODE="off"
# Verify: random animal, no flags, no guillemets

# 5. Test worktree (if git worktree exists)
# Verify: main_flag→worktree_flag in dir icon

# 6. Test SessionEnd cleanup
# Close Claude Code session
# Verify: active-sessions index entry removed
```

---

## Checkpoint Protocol

After completing each phase, the implementing agent MUST:

1. **Update `docs/specs/session-identity-v2/PROGRESS.md`**:
   - Mark phase status as "Completed" with date
   - Add a log entry describing what was done and any deviations from plan/spec
   - Note any issues encountered or risks discovered

2. **Commit all changes atomically** using `/general:commit-atomic`

3. **Print the checkpoint**:
   ```
   ================================================================
   CHECKPOINT — Phase N Complete

   Spec:     docs/specs/session-identity-v2/SPEC.md
   Plan:     docs/specs/session-identity-v2/PLAN.md
   Progress: docs/specs/session-identity-v2/PROGRESS.md

   What would you like to do?

     → "Implement phase N+1"
     → "Review the changes so far"
     → Something else

   If context gets full (>60%) during implementation, start fresh:
     "Read docs/specs/session-identity-v2/PROGRESS.md and continue
      from the last completed phase"
   ================================================================
   ```

4. **STOP and wait for user instruction** — do not proceed to the next phase
   without explicit user approval.

### Context Reset Recovery

If a new agent picks up from a context reset:
1. Read `docs/specs/session-identity-v2/PROGRESS.md` to see current status
2. Read `docs/specs/session-identity-v2/SPEC.md` for the spec
3. Read `docs/specs/session-identity-v2/PLAN.md` for the plan
4. Re-read the SPEC section for the next incomplete phase
5. Continue implementation from where the previous agent left off
