# Session Identity System v2 — Specification

**Status:** Under Review
**Created:** 2026-02-15
**Last Updated:** 2026-02-16
**Author:** spec-architect (Discovery Q&A with user, 4 rounds, 15 decisions)
**Target Location:** `docs/specs/session-identity-v2/SPEC.md`

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Goals & Success Criteria](#goals--success-criteria)
3. [Architecture & Design](#architecture--design)
4. [Decisions & Rationale](#decisions--rationale)
5. [Implementation Phases](#implementation-phases)
6. [Constraints & Boundaries](#constraints--boundaries)
7. [Rejected Alternatives](#rejected-alternatives)
8. [Verification Strategy](#verification-strategy)
9. [Open Questions](#open-questions)

---

## Project Overview

**Name:** Session Identity System v2
**Summary:** Replace TAVS's random per-TTY animal emoji icons with a deterministic,
registry-based dual-identity system that ties icons to Claude Code session IDs and
working directories. Terminal tabs become consistently identifiable: same session always
shows the same animal, same directory always shows the same flag. When collisions occur
among active sessions, a 2-icon overflow pair disambiguates them.
**Core Purpose:** Make terminal tabs semantically identifiable — at a glance, you know
which project (directory flag) and which conversation (session animal) each tab represents.

### What Exists Today

The current session icon system (`src/core/session-icon.sh`, 167 lines) assigns a
**random** animal emoji from a pool of 25 to each terminal tab, avoiding duplicates
across active tabs via a cross-session registry. Icons are tied to TTY devices
(`/dev/ttys001`), not to Claude Code sessions. The system has no concept of directory
identity. When a session switches tabs or is resumed elsewhere, the icon changes.

### What This Spec Changes

1. Icons become **deterministic per session_id** — same session always gets same animal
2. New **directory icons** (flags) — same project always gets same flag
3. **Round-robin assignment** replaces random selection — cycles through full pool before
   repeating, minimizing collisions
4. **2-icon overflow** for active collisions — deterministic pairs like `🦊🐙`
5. **Dual mode as default** — titles show `«🇩🇪|🦊»` (directory|session)
6. **Session ID in title** — `{SESSION_ID}` token shows first 8 chars
7. **Worktree awareness** — detects git worktrees and shows `🇩🇪→🇯🇵` (main→worktree)
8. **Configurable persistence** — ephemeral (clears on reboot) or persistent (forever)

---

## Goals & Success Criteria

| # | Goal | Success Criterion | Priority |
|---|------|-------------------|----------|
| G1 | Deterministic session identity | Same `session_id` always produces same animal icon, across restarts (persistent mode) or within session (ephemeral mode) | Must Have |
| G2 | Deterministic directory identity | Same `cwd` always produces same flag icon | Must Have |
| G3 | Dual-icon display | Title shows `«flag\|animal»` by default with proper formatting | Must Have |
| G4 | Collision avoidance | Round-robin assignment cycles through full pool before repeating; first 80 sessions get unique animals, first 200+ directories get unique flags | Must Have |
| G5 | 2-icon overflow | When primary icon collides with another ACTIVE session, a deterministic pair is shown | Must Have |
| G6 | Worktree awareness | Git worktrees show `main_flag→worktree_flag` | Should Have |
| G7 | Session ID token | `{SESSION_ID}` displays first 8 chars of Claude Code's session_id in title | Should Have |
| G8 | Backward compatibility | `TAVS_IDENTITY_MODE=off` restores current random-per-TTY behavior | Must Have |
| G9 | Non-Claude agent support | Gemini/OpenCode/Codex get directory icon from PWD + TTY-based random session icon | Should Have |
| G10 | Configurable persistence | Users choose ephemeral (/tmp) or persistent (~/.cache/tavs/) storage | Should Have |
| G11 | Flag fallback pools | When flags don't render, plants/buildings pools substitute automatically | Should Have |
| G12 | Empty token cleanup | Guillemet formatting degrades gracefully when tokens are empty | Must Have |

---

## Architecture & Design

### Overview

The identity system introduces two parallel icon assignment pipelines (session and
directory), each backed by a shared **identity registry** that provides round-robin
assignment, persistent mappings, and TTL-based cleanup. The registry replaces the
current random-with-dedup approach.

```
                          Hook JSON (stdin)
                               │
                    ┌──────────┴──────────┐
                    │ Claude Agent Trigger │  ← Extracts session_id, cwd
                    │ (trigger.sh)        │    (alongside existing permission_mode,
                    └──────────┬──────────┘     transcript_path)
                               │
                    ┌──────────┴──────────┐
                    │   Core Trigger      │  ← Calls identity registration
                    │   (trigger.sh)      │    at SessionStart + UserPromptSubmit
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              ▼                ▼                 ▼
    ┌─────────────┐  ┌──────────────┐  ┌──────────────┐
    │ Session Icon │  │  Dir Icon    │  │   Title      │
    │ Module       │  │  Module      │  │   Management │
    │ (session-    │  │ (dir-icon.sh)│  │ (title-      │
    │  icon.sh)    │  │   NEW FILE   │  │  management  │
    │  REWRITE     │  │              │  │  .sh)        │
    └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
           │                 │                  │
           ▼                 ▼                  │
    ┌──────────────────────────────┐            │
    │    Identity Registry         │            │
    │    (identity-registry.sh)    │ ◄──────────┘
    │    NEW FILE                  │   (token resolution
    │                              │    reads cached icons)
    │  - Round-robin counter       │
    │  - Key→icon mappings         │
    │  - Active collision check    │
    │  - TTL cleanup               │
    │  - Persistence mode          │
    └──────────────┬───────────────┘
                   │
         ┌─────────┴─────────┐
         ▼                   ▼
    /tmp/tavs-identity/  ~/.cache/tavs/
    (ephemeral)          (persistent)
```

### Key Components

| Component | Purpose | Location |
|-----------|---------|----------|
| Identity Registry | Shared round-robin (locked), registry CRUD, active-sessions index, TTL cleanup, persistence routing | `src/core/identity-registry.sh` (NEW) |
| Directory Icon Module | cwd→flag mapping, worktree detection, fallback pool selection | `src/core/dir-icon.sh` (NEW) |
| Session Icon Module | session_id→animal mapping, collision detection, overflow pairs | `src/core/session-icon.sh` (REWRITE) |
| Claude Agent Trigger | Extracts session_id + cwd from hook JSON stdin | `src/agents/claude/trigger.sh` (MODIFY) |
| Core Trigger | Wires identity registration into state machine | `src/core/trigger.sh` (MODIFY) |
| Title Management | New token resolution + guillemet cleanup | `src/core/title-management.sh` (MODIFY) |
| Defaults Config | New settings, expanded pools, title format defaults | `src/config/defaults.conf` (MODIFY) |
| User Config Template | Documents new settings and format presets | `src/config/user.conf.template` (MODIFY) |

### Component Interactions

```
SessionStart Hook
    │
    ├─ claude/trigger.sh: reads stdin JSON
    │   ├─ extracts session_id → exports TAVS_SESSION_ID
    │   ├─ extracts cwd → exports TAVS_CWD
    │   ├─ extracts permission_mode → exports TAVS_PERMISSION_MODE (existing)
    │   └─ extracts transcript_path → exports TAVS_TRANSCRIPT_PATH (existing)
    │
    └─ core/trigger.sh "reset" state:
        ├─ identity-registry.sh: _get_registry_dir() determines storage path
        ├─ session-icon.sh: assign_session_icon()
        │   ├─ _get_session_key() → TAVS_SESSION_ID or TTY_SAFE
        │   ├─ _registry_lookup("session", key) → existing icon or empty
        │   ├─ If empty: _round_robin_next_locked("session", TAVS_SESSION_ICON_POOL)
        │   ├─ _check_session_collision(icon, key) → extend to pair if needed
        │   └─ Write to per-TTY cache + active-sessions index
        ├─ NOTE: Dir icon NOT assigned here — cwd absent from SessionStart JSON
        │   (dir icon deferred to first UserPromptSubmit)
        └─ title-management.sh: set_tavs_title("reset")
            ├─ compose_title() resolves all tokens:
            │   ├─ {DIR_ICON} → get_dir_icon() (empty at reset, populated after prompt)
            │   ├─ {SESSION_ICON} → get_session_icon() from per-TTY cache
            │   ├─ {SESSION_ID} → TAVS_SESSION_ID[:8]
            │   └─ (all existing tokens: FACE, STATUS_ICON, AGENTS, BASE, context...)
            ├─ Guillemet cleanup: «|🦊» → «🦊», «🇩🇪|» → «🇩🇪», «|» → (empty)
            └─ Space collapse + trim (existing sed)

UserPromptSubmit Hook
    │
    └─ core/trigger.sh "processing new-prompt":
        ├─ reset_subagent_count (existing)
        └─ _revalidate_identity()
            ├─ Check if session_id changed → re-assign session icon if so
            ├─ Assign/update dir icon (cwd now available from UserPromptSubmit JSON)
            └─ Re-check collision status

SessionEnd Hook
    │
    └─ core/trigger.sh "reset session-end":
        ├─ release_session_icon()  # Remove per-TTY cache, update active-sessions index
        ├─ release_dir_icon()      # Remove per-TTY dir cache
        └─ (existing reset logic continues: bg reset, title reset, etc.)
```

### Key Technical Details

#### 1. Session ID Source

Claude Code sends JSON to every hook via stdin. The `session_id` field is present in
ALL hook events (confirmed in `src/agents/claude/HOOKS_REFERENCE.md`, lines 305, 397,
479, 545, 618, 679, 780, 823, 893). Format: UUID-like string (e.g., `"abc123-def456"`).

The Claude agent trigger (`src/agents/claude/trigger.sh`) already extracts
`permission_mode` (line 27-29) and `transcript_path` (line 32-34) from this JSON
using `sed`. Adding `session_id` and `cwd` extraction follows the exact same pattern.

**Note:** There is NO `$CLAUDE_SESSION_ID` environment variable yet (feature request
[#17188](https://github.com/anthropics/claude-code/issues/17188) pending). The hook
JSON stdin is the only reliable source.

#### 2. Registry File Format

```
# ~/.cache/tavs/session-registry (or /tmp/tavs-identity/session-registry)
# Format: key=primary_icon|secondary_icon|timestamp
# secondary_icon is empty unless 2-icon overflow was triggered at assignment time
abc123de=🦊||1708000000
def456gh=🐙|🐢|1708000001
```

```
# dir-registry
# Format: path_hash=icon|timestamp
a1b2c3d4=🇩🇪|1708000000
e5f6g7h8=🇯🇵|1708000001
```

```
# session-counter (or dir-counter)
# Single integer: next index into pool
42
```

**Parsing**: `while IFS='=' read -r key value` loops — NEVER source files
(established TAVS security pattern).

**Atomic writes**: Always `mktemp` + `mv` pattern (established TAVS pattern from
`session-icon.sh:78-80`, `title-state-persistence.sh:189-207`).

#### 3. Round-Robin Assignment Algorithm (with Locking)

The counter read-modify-write is protected by a filesystem lock to prevent TOCTOU
races under concurrent async hooks (both reviewers flagged this).

```
_round_robin_next_locked(type, pool_array_name):
    1. Acquire lock: mkdir {registry_dir}/.lock-{type} (atomic on POSIX)
       - Spin-wait up to 2 seconds if locked (sleep 0.05 intervals)
       - Break on timeout (collision overflow backstop handles edge case)
    2. Read counter from {registry_dir}/{type}-counter (default: 0)
    3. Get pool array by name (indirect reference)
    4. selected = pool[counter % pool_size]
    5. Increment counter: (counter + 1) % pool_size
    6. Write new counter atomically (mktemp + mv)
    7. Release lock: rmdir {registry_dir}/.lock-{type}
    8. Return selected
```

Lock implementation (macOS + Linux compatible, no external dependencies):
```bash
_acquire_lock() {
    local lock_dir="$1" max_wait=2 waited=0
    while ! mkdir "$lock_dir" 2>/dev/null; do
        sleep 0.05
        waited=$((waited + 1))
        [[ $waited -gt $((max_wait * 20)) ]] && return 1  # Timeout
    done
    return 0
}
```

This guarantees all 80 animals are assigned before any repeats. With ~80 animals and
typical usage of 3-10 concurrent sessions, collision probability is near-zero until
the 80th unique session. If locking fails (timeout), the collision overflow mechanism
(Section 4) serves as backstop.

Compared to random selection (birthday paradox: ~50% collision by session 10 with
25-icon pool), round-robin with 80 icons provides collision-free assignment for the
first 80 sessions.

#### 4. 2-Icon Collision Overflow (with Active-Sessions Index)

**Trigger**: A session's primary icon matches another ACTIVE session's primary icon.

**Detection**: Instead of scanning N per-TTY files (O(n) I/O, flagged by Gemini review),
use a single **active-sessions index** file:

```
# {registry_dir}/active-sessions
# Format: tty_safe=session_key|primary_icon
_dev_ttys001=abc123de|🦊
_dev_ttys002=def456gh|🐙
```

Collision check is a single `grep` on one file: O(1) file opens.

- **Updated on**: `assign_session_icon()` (add entry), `release_session_icon()` (remove)
- **Atomic writes**: Same `mktemp` + `mv` pattern with same lock as counter operations
- **Stale entry cleanup**: At SessionStart, remove entries for dead TTYs
  (check `[[ -c "${tty_key//_//}" ]]` — existing TAVS pattern)

**Resolution**:
1. At assignment time, grep active-sessions for same primary from different session_key
2. If collision: assign secondary via next round-robin (locked)
3. Both primary and secondary stored in registry
4. Per-TTY cache records `collision_active=true`
5. Display shows `🦊🐙` (two animals adjacent) during collision
6. When the other session ends (SessionEnd releases entry), collision clears
7. Display reverts to `🦊` (primary only)

**Re-check timing**: Collision status re-evaluated at SessionStart and UserPromptSubmit.

#### 5. Worktree Detection (with Platform-Aware Timeout)

```bash
# Platform-aware git timeout helper (macOS lacks `timeout` by default)
_git_with_timeout() {
    if command -v timeout &>/dev/null; then timeout 1 git "$@" 2>/dev/null
    elif command -v gtimeout &>/dev/null; then gtimeout 1 git "$@" 2>/dev/null
    else git "$@" 2>/dev/null
    fi
}

_detect_worktree(cwd):
    # Guard: fast fail for non-git directories
    command -v git &>/dev/null || return 1
    (  # Subshell to protect caller's cwd
        cd "$cwd" || return 1
        _git_with_timeout rev-parse --is-inside-work-tree &>/dev/null || return 1
        toplevel=$(_git_with_timeout rev-parse --show-toplevel)
        common_dir=$(_git_with_timeout rev-parse --git-common-dir)
        # Normalize common_dir to absolute path
        [[ "$common_dir" != /* ]] && common_dir="$toplevel/$common_dir"
        common_dir=$(cd "$common_dir" && pwd)
        main_repo="${common_dir%/.git}"
        if [[ "$main_repo" != "$toplevel" ]]; then
            # We're in a worktree
            printf '%s %s' "$main_repo" "$toplevel"
            return 0
        fi
        return 1  # Not a worktree
    )
```

When in a worktree:
- Main repo path gets its own flag from registry (e.g., `🇩🇪`)
- Worktree path gets its own flag from registry (e.g., `🇯🇵`)
- `get_dir_icon()` returns `🇩🇪→🇯🇵` (arrow separator)

When using fallback pools (plants/buildings instead of flags):
- Main directory uses one pool (e.g., plants: `🌳`)
- Worktree uses the other pool (e.g., buildings: `🏠`)
- Result: `🌳→🏠`

#### 6. Guillemet Cleanup in compose_title()

After all token substitution, before the existing space collapse:

```bash
# Empty token cleanup around guillemets/pipes
title=$(printf '%s\n' "$title" | sed \
    -e 's/«|/«/g' \         # «|🦊» → «🦊» (no dir icon)
    -e 's/|»/»/g' \         # «🇩🇪|» → «🇩🇪» (no session icon)
    -e 's/«»//g' \          # «» → (empty)
    -e 's/  */ /g; s/^ *//; s/ *$//')  # Existing space collapse
```

This ensures the title degrades gracefully when either icon is absent.

#### 7. Per-TTY Cache File Formats

**Session icon cache** (`{state_dir}/session-icon.{TTY_SAFE}`):
```
# session-icon.{TTY_SAFE}
session_key=abc123de
primary=🦊
secondary=🐙
collision_active=false
```

**Directory icon cache** (`{state_dir}/dir-icon.{TTY_SAFE}`):
```
# dir-icon.{TTY_SAFE}
dir_path=/Users/cs/projects/myapp
dir_hash=a1b2c3d4
primary=🇩🇪
worktree_path=/Users/cs/projects/myapp-feature-x
worktree_hash=e5f6g7h8
worktree_icon=🇯🇵
```

Both use safe KV parsing (`while IFS='=' read`) and atomic writes (`mktemp` + `mv`).

**Legacy file migration**: Current `session-icon.{TTY_SAFE}` files contain a raw emoji
string (no `=` delimiter). On first access, detect and remove:
```bash
if [[ -f "$icon_file" ]]; then
    local first_line; read -r first_line < "$icon_file"
    [[ "$first_line" != *"="* ]] && rm -f "$icon_file"  # Legacy single-emoji format
fi
```

#### 8. Persistence Mode Routing

```bash
_get_registry_dir():
    case "$TAVS_IDENTITY_PERSISTENCE" in
        persistent)
            # Use secure cache dir (same as spinner state)
            dir=$(get_spinner_state_dir)  # ~/.cache/tavs/ or $XDG_RUNTIME_DIR/tavs
            ;;
        ephemeral|*)
            dir="/tmp/tavs-identity"
            ;;
    esac
    mkdir -p "$dir" && chmod 700 "$dir"
    echo "$dir"
```

Ephemeral mode: OS clears `/tmp/` on reboot → fresh icons every restart.
Persistent mode: `~/.cache/tavs/` survives reboots → same session always has same icon.

#### 9. Title Format Presets

Instead of composite tokens, offer format presets in wizard/docs:

```bash
# Preset: Minimal (backward compatible)
TAVS_TITLE_FORMAT="{FACE} {STATUS_ICON} {AGENTS} {SESSION_ICON} {BASE}"

# Preset: Standard (new default)
TAVS_TITLE_FORMAT="{FACE} {STATUS_ICON} {AGENTS} «{DIR_ICON}|{SESSION_ICON}» {BASE}"

# Preset: Full Identity
TAVS_TITLE_FORMAT="{FACE} {STATUS_ICON} {AGENTS} «{DIR_ICON}|{SESSION_ICON}» {SESSION_ID} {BASE}"

# Preset: Bubble (future — supported by individual tokens)
TAVS_TITLE_FORMAT="{FACE} «{STATUS_ICON}|{CONTEXT_FOOD}{CONTEXT_PCT}|{AGENTS}|{SESSION_ICON}|{DIR_ICON}»"
```

---

## Decisions & Rationale

### D01: Collision Resolution Priority

**Question:** When deterministic mapping (same session_id → same icon) conflicts with
active deduplication (no two open tabs share an icon), which wins?

**Options Considered:**
- A) Determinism first — same session always gets same icon, even if duplicate
- B) Dedup first — no duplicates, but icon may change per context
- C) Determinism + 2-icon overflow — deterministic primary, extend to pair on collision

**Decision:** C) Determinism + 2-icon overflow
**Reasoning:** Provides both properties. Same session always recognizable by primary icon.
Active collisions are rare (round-robin minimizes them) and visually resolved by showing
a pair. When collision clears, display reverts to single icon.

### D02: Dual Icon Display Format

**Question:** How should directory + session icons appear in the title?

**Options Considered:**
- A) Adjacent pair: `🦊🐙`
- B) Separate tokens: `{DIR_ICON}` and `{SESSION_ICON}` placed independently
- C) Bracketed pair: `[🦊|🐙]`

**Decision:** Guillemet-wrapped pair with pipe separator: `«🇩🇪|🦊»`
**Reasoning:** User specified guillemets (`«»`) over brackets (`[]`) because the Claude
Code agent face already uses brackets (`Ǝ[• •]E`). Pipe separator clearly delineates
directory from session. This is implemented as literal characters in the format string,
not as token behavior — keeping tokens individual (D09).

### D03: Icon Pool Separation

**Question:** Should directory and session icons use the same or separate pools?

**Options Considered:**
- A) Same pool (simpler config)
- B) Separate pools (visually distinct categories)
- C) Same pool with visual separator

**Decision:** B) Separate pools
**Reasoning:** User's conceptual model — "sessions are animals because like features,
they need to be raised and cared for; directories are flags because they are the nations
we build on." Separate categories make it immediately clear which icon means what.

### D04: Session ID Token Format

**Question:** What format for the `{SESSION_ID}` title token?

**Options Considered:**
- A) First 8 chars of Claude's session_id
- B) First segment before hyphen
- C) Configurable length

**Decision:** A) First 8 characters
**Reasoning:** Matches existing TAVS session ID length convention (from
`title-state-persistence.sh:66`). Compact and sufficient for identification. Consistent
with the 8-char UUIDs already generated by `_generate_session_id()`.

### D05: Registry Persistence

**Question:** How should identity registries be persisted, and how should cleanup work?

**Options Considered:**
- A) Auto-expire after 30 days
- B) Keep forever, cap at pool size
- C) Keep forever, no cap

**Decision:** Two configurable modes — ephemeral (default) and persistent (no cap)
**Reasoning:** User wants BOTH options. Ephemeral stores in `/tmp/` — cleared on reboot
for fresh icons. Persistent stores in `~/.cache/tavs/` — same icon forever. The
functionality is identical; only the storage path differs. Ephemeral is default because
most users want lightweight, fresh-feeling identity. Power users who want "my project is
always the German flag" enable persistent mode.

### D06: Worktree Dual-Flag Format

**Question:** How should two directory flags appear when in a git worktree?

**Options Considered:**
- A) Stacked: `🇩🇪🇯🇵` (adjacent)
- B) Separated: `🇩🇪→🇯🇵` (arrow)
- C) Only worktree flag

**Decision:** B) Arrow separator: `🇩🇪→🇯🇵`
**Reasoning:** Arrow explicitly communicates the main→worktree relationship. More readable
than adjacent flags. The relationship direction (main→branch) maps naturally to `→`.

### D07: Flag Rendering Fallback

**Question:** Country flag emoji don't render on all terminals. What fallback?

**Options Considered:**
- A) Flags with auto-fallback to universal emoji
- B) Flags only, user handles it
- C) Universal emoji instead of flags

**Decision:** Plants/trees AND buildings as TWO separate fallback pools
**Reasoning:** When flags can't render, one category (plants, the larger pool) serves
main directories, the other (buildings) serves worktrees. This preserves the visual
distinction between main-dir and worktree even in fallback mode. When there's no
worktree, just one pool is used. Alternation between pools provides variety.

### D08: Pool Size

**Question:** How many animals and flags in the default pools?

**Options Considered:**
- A) Full pools (~80 animals, ~190 flags)
- B) Curated (~40 animals, ~60 flags)
- C) Small (~25 animals, ~30 flags)

**Decision:** A) Full pools
**Reasoning:** Maximum collision avoidance. With round-robin, 80 sessions before any
animal repeats, 200 directories before any flag repeats. The pools are user-overridable
for those who want smaller, more memorable sets.

### D09: Token Structure

**Question:** Should there be a composite `{IDENTITY}` token or only individual tokens?

**Options Considered:**
- A) Smart `{IDENTITY}` composite + individual tokens
- B) Only individual tokens: `{DIR_ICON}`, `{SESSION_ICON}`, `{SESSION_ID}`
- C) Replace `{SESSION_ICON}` entirely

**Decision:** B) Only individual tokens
**Reasoning:** Future "bubble" format (`∃[. .]E «🔥|📦75%|🤖|📁»`) requires all tokens
to be independently positionable. Composite tokens would conflict with this vision.
Format presets in wizard/docs provide the convenience of pre-composed layouts without
limiting flexibility. The `compose_title()` guillemet cleanup handles empty-state
formatting for the default preset.

### D10: Default Mode

**Question:** Should dual-icon identity be the new default or opt-in?

**Options Considered:**
- A) Opt-in, single animal remains default
- B) Dual mode as new default
- C) Deterministic single as default, dual opt-in

**Decision:** B) Dual mode as new default
**Reasoning:** Bold but justified — the identity system is the major value-add of this
feature. Users who update get the full experience immediately. Those who prefer the old
behavior can revert with `TAVS_IDENTITY_MODE=single` or `./tavs set identity-mode single`.

**Mode definitions (clarified per review feedback):**
- `dual` (default): Deterministic session icon (round-robin) + deterministic dir icon.
  Title format dynamically injects `«{DIR_ICON}|{SESSION_ICON}»`.
- `single`: Deterministic session icon (round-robin) only. No dir icon. Title format
  unchanged from current default (no guillemets). This is "v2 deterministic without dir."
- `off`: Legacy random per-TTY behavior. Exact current behavior. 25-icon pool.
  `ENABLE_SESSION_ICONS="false"` automatically maps to this mode.

### D11: Non-Claude Agent Handling

**Question:** Gemini CLI, OpenCode, Codex don't have session_id in hook data. What do they get?

**Options Considered:**
- A) TTY-based for session, PWD-based for directory
- B) Generate our own session ID from PID/timestamp
- C) Use transcript path as session key

**Decision:** A) Directory icon from PWD + TTY-based random session icon
**Reasoning:** Directory icons work for any agent (just needs PWD). Session icons
fall back to current TTY-based random behavior since there's no session_id available.
When `$CLAUDE_SESSION_ID` env var becomes available (issue #17188), this becomes moot.

### D12: Directory Identity Source

**Question:** Should directory identity be based on git root or CWD?

**Options Considered:**
- A) Git root preferred, CWD fallback
- B) Always use CWD
- C) Configurable with default

**Decision:** C) Configurable via `TAVS_DIR_IDENTITY_SOURCE`, default `cwd`
**Reasoning:** CWD is simpler (no git dependency, no processing overhead). For most
Claude Code usage, the CWD from hook JSON IS the project root. Users who want
normalization across subdirectories can switch to `git-root`. The config provides
flexibility without imposing overhead.

### D13: 2nd Icon Determination Method

**Question:** When collision overflow triggers, how is the secondary icon determined?

**Options Considered:**
- A) Next in round-robin (stored at assignment time)
- B) Always store and show pair permanently
- C) Derive from hash of session_id

**Decision:** A) Next in round-robin
**Reasoning:** At assignment time, if primary collides, assign secondary via round-robin.
Both stored in registry. Display shows pair ONLY during active collision, reverts when
other session ends. This means 2-icon pairs are temporary visual disambiguators, not
permanent identifiers. The session's "true" identity is its primary icon.

### D14: Re-validation Timing

**Question:** When should session identity be checked/refreshed?

**Options Considered:**
- A) SessionStart + PreCompact
- B) Every hook invocation
- C) SessionStart only

**Decision:** SessionStart + UserPromptSubmit
**Reasoning:** Session_id doesn't change mid-session, so checking on every hook is
wasteful. SessionStart captures new sessions. UserPromptSubmit catches CWD changes
(user might have `cd`'d to a different project). PreCompact is unnecessary because
compaction always follows a user prompt, which already triggers re-validation.

### D15: No Composite Token / Format Presets

**Question:** Should an `{IDENTITY}` composite token handle guillemet wrapping?

**Options Considered:**
- A) Add `{IDENTITY}` composite that auto-formats
- B) Individual tokens only, format presets in docs/wizard

**Decision:** B) Individual tokens only with format presets
**Reasoning:** Future "bubble" format vision requires all tokens to be independently
composable. Composite tokens create formatting lock-in. Format presets in the wizard
give users ready-made layouts (Standard, Minimal, Full Identity, Bubble) without
constraining the token system. The `compose_title()` guillemet cleanup handles empty
states for any format string containing `«` and `|` and `»`.

---

## Implementation Phases

### Phase 0: Configuration Foundation

**Scope:** Add all new config variables, expanded icon pools, and identity system
defaults to `defaults.conf`. This is a prerequisite for ALL subsequent phases —
Phases 1-6 reference these pools and variables.

**Depends On:** Nothing (must be first)

**File:** `src/config/defaults.conf` (MODIFY)

**Changes:**

1. Add `# === IDENTITY SYSTEM ===` section with all new config variables:
   - `TAVS_IDENTITY_MODE="dual"` (single/dual/off)
   - `TAVS_IDENTITY_PERSISTENCE="ephemeral"` (ephemeral/persistent)
   - `TAVS_DIR_IDENTITY_SOURCE="cwd"` (cwd/git-root)
   - `TAVS_DIR_WORKTREE_DETECTION="true"`
   - `TAVS_IDENTITY_REGISTRY_TTL=2592000` (30 days)
   - `TAVS_DIR_ICON_TYPE="flags"` (flags/plants/buildings/auto)

2. Add `TAVS_SESSION_ICON_POOL` array (~80 animals from Appendix A)

3. Keep backward compat: `TAVS_SESSION_ICONS` remains as original 25-icon array.
   After user.conf loads, the config loader will check if user overrode
   `TAVS_SESSION_ICONS` and propagate to `TAVS_SESSION_ICON_POOL`:
   ```bash
   # In theme-config-loader.sh, after user.conf sourced:
   if [[ ${#TAVS_SESSION_ICONS[@]} -gt 0 && \
         "${_TAVS_SESSION_ICONS_HASH:-}" != "$(_tavs_array_hash TAVS_SESSION_ICONS)" ]]; then
       TAVS_SESSION_ICON_POOL=("${TAVS_SESSION_ICONS[@]}")
   fi
   ```

4. Add `TAVS_DIR_ICON_POOL` array (~190 flags from Appendix A)
5. Add `TAVS_DIR_FALLBACK_POOL_A` (plants) and `TAVS_DIR_FALLBACK_POOL_B` (buildings)
6. Add `ENABLE_SESSION_ICONS` → `TAVS_IDENTITY_MODE` mapping:
   ```bash
   [[ "${ENABLE_SESSION_ICONS:-true}" == "false" ]] && TAVS_IDENTITY_MODE="off"
   ```

**Title format defaults** — apply guillemets dynamically based on mode, NOT by changing
the static default format. The global default remains:
```bash
TAVS_TITLE_FORMAT="{FACE} {STATUS_ICON} {AGENTS} {SESSION_ICON} {BASE}"
```
When `TAVS_IDENTITY_MODE=dual`, `compose_title()` will dynamically inject
`«{DIR_ICON}|{SESSION_ICON}»` in place of `{SESSION_ICON}` if no per-state format
overrides it (see Phase 6 for details).

**Acceptance Criteria:**
- [ ] All new config variables have defaults
- [ ] `TAVS_SESSION_ICON_POOL` contains ~80 animals
- [ ] `TAVS_SESSION_ICONS` preserved as original 25 for backward compat
- [ ] `ENABLE_SESSION_ICONS=false` maps to `TAVS_IDENTITY_MODE=off`
- [ ] All pools populated from Appendix A
- [ ] No impact on existing config when `TAVS_IDENTITY_MODE=off`

---

### Phase 1: Identity Registry Core

**Scope:** Create the shared registry foundation used by both session and directory
icon modules.

**Depends On:** Nothing (foundational)

**File:** `src/core/identity-registry.sh` (NEW)

**Inputs:**
- Existing patterns from `session-icon.sh` (atomic writes, safe parsing)
- Existing `get_spinner_state_dir()` from `spinner.sh:16-33`
- `TAVS_IDENTITY_PERSISTENCE` config value

**Outputs:**
- New module with public API: `_get_registry_dir()`, `_round_robin_next()`,
  `_registry_lookup()`, `_registry_store()`, `_registry_remove()`,
  `_registry_list_active()`, `_registry_cleanup_expired()`
- Registry files in chosen persistence directory
- Counter files for round-robin tracking

**Key Functions:**

```bash
_get_registry_dir()
    # Routes to /tmp/tavs-identity/ or ~/.cache/tavs/ based on TAVS_IDENTITY_PERSISTENCE
    # Creates dir with chmod 700 if missing

_acquire_lock(lock_dir)
    # mkdir-based lock (atomic on POSIX, no external deps)
    # Spin-wait up to 2 seconds, return 1 on timeout

_release_lock(lock_dir)
    # rmdir lock directory

_round_robin_next_locked(type, pool_array_name)
    # Acquires mkdir lock → reads counter → selects pool[counter % size]
    # → increments → writes atomically → releases lock
    # If lock timeout: returns empty (caller falls back to collision overflow)
    # Zsh compat: use intermediate vars for array access

_registry_lookup(type, key)
    # Reads {registry_dir}/{type}-registry
    # Returns "primary|secondary|timestamp" for key, or empty
    # Safe parsing: while IFS='=' read

_registry_store(type, key, primary, [secondary])
    # Atomic write to registry: key=primary|secondary|timestamp
    # Preserves existing entries for other keys
    # Accepts concurrent-write risk (self-healing on next session start)

_registry_remove(type, key)
    # Atomic removal of key from registry

_active_sessions_update(tty_safe, session_key, primary_icon)
    # Add/update entry in active-sessions index (locked)
    # Format: tty_safe=session_key|primary_icon

_active_sessions_remove(tty_safe)
    # Remove entry from active-sessions index (locked)

_active_sessions_check_collision(primary_icon, session_key)
    # Grep active-sessions for same icon from different key
    # Returns 0 (collision) or 1 (unique)
    # O(1) file opens vs O(n) per-TTY scanning

_active_sessions_cleanup_stale()
    # Remove entries for dead TTYs (check /dev/ttysXXX existence)

_registry_cleanup_expired(type, ttl_seconds)
    # Removes entries where (now - timestamp) > ttl_seconds
    # Called at SessionStart
```

**Acceptance Criteria:**
- [ ] Round-robin returns sequential icons from pool (not random)
- [ ] Counter wraps at pool_size (modular arithmetic)
- [ ] Counter operations use mkdir-based locking (TOCTOU protection)
- [ ] Lock timeout gracefully degrades (collision overflow backstop)
- [ ] Active-sessions index maintained with add/remove/check operations
- [ ] Active-sessions stale cleanup removes dead TTY entries
- [ ] Registry store/lookup is idempotent
- [ ] TTL cleanup removes entries older than threshold
- [ ] Ephemeral mode creates files in `/tmp/tavs-identity/`
- [ ] Persistent mode creates files in `~/.cache/tavs/`
- [ ] All file operations use atomic `mktemp` + `mv`
- [ ] No `source` of any state file (safe parsing only)
- [ ] Zsh compatible (intermediate vars for brace defaults)

**Verification:**
```bash
# Test round-robin
source src/core/identity-registry.sh
for i in $(seq 1 5); do _round_robin_next "test" "TAVS_SESSION_ICON_POOL"; done
# Should return 5 different, sequential icons

# Test persistence routing
TAVS_IDENTITY_PERSISTENCE=ephemeral _get_registry_dir  # → /tmp/tavs-identity
TAVS_IDENTITY_PERSISTENCE=persistent _get_registry_dir  # → ~/.cache/tavs
```

---

### Phase 2: Directory Icon Module

**Scope:** Deterministic directory→flag mapping with worktree awareness and fallback pools.

**Depends On:** Phase 1 (identity-registry.sh)

**File:** `src/core/dir-icon.sh` (NEW)

**Inputs:**
- `TAVS_CWD` from hook JSON (or `$PWD`)
- `TAVS_DIR_IDENTITY_SOURCE` config (`cwd` or `git-root`)
- `TAVS_DIR_WORKTREE_DETECTION` config
- `TAVS_DIR_ICON_POOL` (flags), `TAVS_DIR_FALLBACK_POOL_A` (plants),
  `TAVS_DIR_FALLBACK_POOL_B` (buildings)
- Identity registry from Phase 1

**Outputs:**
- Per-TTY cache file: `{state_dir}/dir-icon.{TTY_SAFE}`
- Entries in `{registry_dir}/dir-registry`
- Public functions: `assign_dir_icon()`, `get_dir_icon()`, `release_dir_icon()`

**Key Functions:**

```bash
assign_dir_icon()
    # 1. Get cwd: TAVS_CWD or $PWD
    # 2. If git-root mode: _resolve_dir_identity() normalizes via git
    # 3. Hash path for registry key: printf '%s' "$path" | cksum | cut -d' ' -f1
    # 4. _registry_lookup("dir", hash) → existing flag or empty
    # 5. If empty: _round_robin_next("dir", pool_name) → new flag
    #    _registry_store("dir", hash, flag)
    # 6. If worktree: repeat for worktree path with same pool
    # 7. Write to per-TTY cache: dir-icon.{TTY_SAFE}

get_dir_icon()
    # Read from per-TTY cache
    # If worktree: return "main_flag→worktree_flag"
    # If single: return "flag"

_detect_worktree(cwd)
    # git rev-parse --git-common-dir vs --show-toplevel
    # Returns "main_path worktree_path" or empty

_resolve_dir_identity(cwd)
    # If git-root: git rev-parse --show-toplevel (with timeout)
    # If cwd: return as-is

_select_dir_pool()
    # Checks TAVS_DIR_ICON_TYPE setting
    # "flags" → TAVS_DIR_ICON_POOL
    # "plants" → TAVS_DIR_FALLBACK_POOL_A
    # "buildings" → TAVS_DIR_FALLBACK_POOL_B
    # "auto" → detect terminal capability, fall back if needed

_get_worktree_pool()
    # Returns the alternate pool from main
    # If main uses POOL_A → worktree uses POOL_B (and vice versa)
```

**Acceptance Criteria:**
- [ ] Same cwd always produces same flag (deterministic)
- [ ] Different cwds produce different flags (until pool exhaustion)
- [ ] Worktree detection correctly identifies git worktrees
- [ ] Worktree shows `main_flag→worktree_flag` format
- [ ] Non-worktree shows single flag
- [ ] Fallback pools engage when `TAVS_DIR_ICON_TYPE` is set
- [ ] Worktree uses alternate fallback pool from main dir
- [ ] Non-git directory works (no worktree, single flag)
- [ ] `git` commands have timeout protection (don't block hooks)
- [ ] Path hashing is stable (same path → same hash across invocations)

**Verification:**
```bash
# Test deterministic assignment
TAVS_CWD=/tmp/test1 assign_dir_icon && get_dir_icon  # → some flag
TAVS_CWD=/tmp/test2 assign_dir_icon && get_dir_icon  # → different flag
TAVS_CWD=/tmp/test1 assign_dir_icon && get_dir_icon  # → same as first

# Test worktree (in an actual worktree)
cd /path/to/worktree && assign_dir_icon && get_dir_icon  # → main→worktree flags

# Test fallback
TAVS_DIR_ICON_TYPE=plants assign_dir_icon && get_dir_icon  # → plant emoji
```

---

### Phase 3: Session Icon Rewrite

**Scope:** Replace random-per-TTY with deterministic-per-session_id using registry,
including 2-icon collision overflow.

**Depends On:** Phase 1 (identity-registry.sh)

**File:** `src/core/session-icon.sh` (MAJOR REWRITE)

**Inputs:**
- `TAVS_SESSION_ID` from hook JSON (or `TTY_SAFE` for non-Claude agents)
- `TAVS_SESSION_ICON_POOL` (expanded ~80 animals)
- `TAVS_IDENTITY_MODE` config
- Identity registry from Phase 1

**Outputs:**
- Per-TTY cache file: `{state_dir}/session-icon.{TTY_SAFE}` (new format)
- Entries in `{registry_dir}/session-registry`
- Public functions: `assign_session_icon()`, `get_session_icon()`,
  `release_session_icon()` (signatures preserved, behavior changed)

**Key Changes from Current:**

| Aspect | Current (session-icon.sh) | New |
|--------|--------------------------|-----|
| Assignment | Random from pool | Round-robin from registry |
| Identity key | TTY_SAFE | session_id (or TTY_SAFE fallback) |
| Collision handling | Allow duplicates when pool exhausted | 2-icon overflow pair |
| Persistence | Per-TTY file only | Registry + per-TTY cache |
| Pool size | 25 animals | ~80 animals |
| Cache format | Single emoji | Structured KV (key, primary, secondary, collision) |

**Key Functions:**

```bash
assign_session_icon()
    # 0. Detect and remove legacy single-emoji format files
    # 1. If TAVS_IDENTITY_MODE=off: delegate to _legacy_random_assign()
    # 2. key = _get_session_key()
    # 3. Check per-TTY cache: if key matches, return (idempotent)
    # 4. _registry_lookup("session", key)
    #    → If found: use existing primary (+ secondary if stored)
    #    → If not found: _round_robin_next_locked → _registry_store
    # 5. _active_sessions_check_collision(primary, key) [via index, not per-TTY scan]
    #    → If collision: assign secondary via _round_robin_next_locked, store both
    # 6. Write per-TTY cache: session-icon.{TTY_SAFE}
    # 7. _active_sessions_update(TTY_SAFE, key, primary)

get_session_icon()
    # Read per-TTY cache
    # If collision_active=true: return "primary secondary" (two animals)
    # If collision_active=false: return "primary" (one animal)

release_session_icon()
    # Remove per-TTY cache
    # _active_sessions_remove(TTY_SAFE)
    # Do NOT remove from registry (mapping persists)

_get_session_key()
    # If TAVS_SESSION_ID set: return first 8 chars
    # Else: return TTY_SAFE (backward compat for non-Claude agents)

_detect_legacy_icon_file(icon_file)
    # If file exists and first line lacks '=': legacy format → remove
    # Allows clean re-assignment via new structured format

_legacy_random_assign()
    # Current random-with-dedup logic for TAVS_IDENTITY_MODE=off
    # Preserves existing behavior exactly
```

**Acceptance Criteria:**
- [ ] Same session_id always gets same primary icon (deterministic)
- [ ] Round-robin cycles through all 80 animals before repeating
- [ ] 2-icon overflow shows pair when collision is active
- [ ] Overflow reverts to single when collision clears
- [ ] Non-Claude agents (no session_id) use TTY_SAFE as key
- [ ] `TAVS_IDENTITY_MODE=off` uses legacy random behavior
- [ ] `release_session_icon()` removes per-TTY cache but keeps registry mapping
- [ ] Per-TTY cache format is backward-incompatible (old files safely ignored)

**Verification:**
```bash
# Test deterministic assignment
TAVS_SESSION_ID=test1234 assign_session_icon && get_session_icon  # → some animal
# In different TTY:
TAVS_SESSION_ID=test1234 assign_session_icon && get_session_icon  # → SAME animal

# Test collision overflow
TAVS_SESSION_ID=session_a assign_session_icon  # → 🦊
# Manually set another TTY's cache to same primary with different key
TAVS_SESSION_ID=session_b assign_session_icon  # → check if 🦊🐙 when collision

# Test legacy mode
TAVS_IDENTITY_MODE=off assign_session_icon && get_session_icon  # → random animal
```

---

### Phase 4: Hook Data Extraction

**Scope:** Extract `session_id` and `cwd` from Claude Code hook JSON stdin.

**Depends On:** Nothing (independent, can parallel with Phases 2-3)

**File:** `src/agents/claude/trigger.sh` (MODIFY lines 26-35)

**Inputs:**
- Hook JSON via stdin (already captured in `_tavs_stdin` at line 21)
- Existing extraction pattern for `permission_mode` (line 27-29) and
  `transcript_path` (line 32-34)

**Outputs:**
- `TAVS_SESSION_ID` environment variable (exported)
- `TAVS_CWD` environment variable (exported)

**Changes:** Add 8 lines after existing extraction block (lines 26-35):

```bash
# After existing permission_mode and transcript_path extraction:

# Extract session_id from JSON
_session_id=$(printf '%s' "$_tavs_stdin" | \
    sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[[ -n "$_session_id" ]] && export TAVS_SESSION_ID="$_session_id"

# Extract cwd from JSON
_cwd=$(printf '%s' "$_tavs_stdin" | \
    sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[[ -n "$_cwd" ]] && export TAVS_CWD="$_cwd"
```

**No changes to `hooks/hooks.json`** — all hooks already pipe JSON to stdin.

**Acceptance Criteria:**
- [ ] `TAVS_SESSION_ID` populated from hook JSON `session_id` field
- [ ] `TAVS_CWD` populated from hook JSON `cwd` field
- [ ] Extraction works with and without whitespace around `:` in JSON
- [ ] Empty/missing fields result in empty vars (not errors)
- [ ] No jq dependency (sed-only, matching existing pattern)
- [ ] No impact on existing `TAVS_PERMISSION_MODE` and `TAVS_TRANSCRIPT_PATH`

**Verification:**
```bash
echo '{"session_id":"abc123-def","cwd":"/tmp/test","permission_mode":"plan"}' | \
    ./src/agents/claude/trigger.sh processing
# Verify env vars are set in core trigger's debug log
```

---

### Phase 5: Core Trigger Integration

**Scope:** Wire identity registration into the core trigger state machine, including
lazy-loading identity modules and SessionEnd cleanup.

**Depends On:** Phases 1, 2, 3, 4

**File:** `src/core/trigger.sh` (MODIFY)

**Changes:**

1. **Lazy-load identity modules** — only source on `reset` and `new-prompt`, NOT on
   every hook invocation (~10+ hooks per prompt don't need identity):
```bash
# Add helper function before case block:
_load_identity_modules() {
    [[ "${_TAVS_IDENTITY_LOADED:-}" == "true" ]] && return 0
    source "$CORE_DIR/identity-registry.sh"
    source "$CORE_DIR/dir-icon.sh"
    _TAVS_IDENTITY_LOADED="true"
}
```

   **Source order matters**: `identity-registry.sh` before `session-icon.sh` (rewritten)
   before `dir-icon.sh`. The rewritten `session-icon.sh` is sourced unconditionally
   (it replaces the existing source), but `identity-registry.sh` and `dir-icon.sh`
   are loaded on demand.

2. **Reset state** (`reset)` case) — session icon only, dir icon deferred:
```bash
# Differentiate SessionStart from SessionEnd
if [[ "${2:-}" == "session-end" ]]; then
    _load_identity_modules
    release_session_icon 2>/dev/null || true
    release_dir_icon 2>/dev/null || true
    # Continue with existing reset logic (bg reset, title reset, etc.)
else
    # SessionStart: assign session icon only (cwd not in SessionStart JSON)
    if [[ "${TAVS_IDENTITY_MODE:-dual}" != "off" ]]; then
        _load_identity_modules
        assign_session_icon    # Registry-based (Phase 3)
        # NOTE: dir icon NOT assigned — cwd absent from SessionStart payload
        # Dir icon will be assigned on first UserPromptSubmit (new-prompt)
    fi
fi
```

3. **Processing new-prompt** (~line 173-174):
```bash
if [[ "${2:-}" == "new-prompt" ]]; then
    reset_subagent_count
    _load_identity_modules
    _revalidate_identity  # New function
fi
```

4. **New helper function** (add before `case "$STATE"` block):
```bash
_revalidate_identity() {
    [[ "${TAVS_IDENTITY_MODE:-dual}" == "off" ]] && return 0

    # Session: check if session_id changed (handles --resume edge case)
    local state_dir cached_key current_key
    state_dir=$(get_spinner_state_dir)
    local cache_file="${state_dir}/session-icon.${TTY_SAFE:-unknown}"
    if [[ -f "$cache_file" ]]; then
        cached_key=""
        while IFS='=' read -r k v; do
            [[ "$k" == "session_key" ]] && cached_key="$v"
        done < "$cache_file"
    fi
    current_key=$(_get_session_key 2>/dev/null)
    if [[ -n "$current_key" && "$cached_key" != "$current_key" ]]; then
        release_session_icon
        assign_session_icon
    fi

    # Directory: always re-check (cwd may have changed between prompts)
    # This is the PRIMARY path for dir icon assignment — cwd is available
    # in UserPromptSubmit JSON but NOT in SessionStart JSON
    if [[ "${TAVS_IDENTITY_MODE:-dual}" == "dual" ]]; then
        assign_dir_icon
    fi
}
```

**Acceptance Criteria:**
- [ ] SessionStart (reset) assigns session icon only (NOT dir icon)
- [ ] Dir icon assigned on first UserPromptSubmit (new-prompt) when cwd is available
- [ ] SessionEnd (reset session-end) releases both session and dir icons
- [ ] UserPromptSubmit (new-prompt) re-validates identity
- [ ] Session re-assignment triggers when session_id changes
- [ ] Dir icon updates when cwd changes between prompts
- [ ] Identity modules lazy-loaded (only on reset and new-prompt)
- [ ] `TAVS_IDENTITY_MODE=off` skips all identity logic
- [ ] `TAVS_IDENTITY_MODE=single` assigns session icon only, no dir icon
- [ ] No regression in existing state machine behavior

---

### Phase 6: Title System Integration

**Scope:** Add new token resolution, dynamic guillemet injection for dual mode,
guillemet cleanup, and updated per-state format defaults.

**Depends On:** Phases 2, 3 (for get_dir_icon, get_session_icon)

**File:** `src/core/title-management.sh` (MODIFY)

**Changes to `compose_title()` function:**

1. **Dynamic guillemet injection for dual mode** — Instead of changing the static
   default `TAVS_TITLE_FORMAT`, dynamically replace `{SESSION_ICON}` with
   `«{DIR_ICON}|{SESSION_ICON}»` when dual mode is active. This preserves the
   existing format for `single`/`off` users (review fix for Gemini S4).

```bash
# Before token resolution, if dual mode: inject guillemet wrapper
# Only if format contains {SESSION_ICON} but not already {DIR_ICON}
if [[ "${TAVS_IDENTITY_MODE:-dual}" == "dual" && \
      "$title" == *"{SESSION_ICON}"* && \
      "$title" != *"{DIR_ICON}"* ]]; then
    title="${title//\{SESSION_ICON\}/«{DIR_ICON}|{SESSION_ICON}»}"
fi
```

2. **Resolve `{DIR_ICON}` token** (add after `{SESSION_ICON}` substitution):
```bash
# Resolve {DIR_ICON}
local dir_icon=""
if [[ "${TAVS_IDENTITY_MODE:-dual}" == "dual" ]] && type get_dir_icon &>/dev/null; then
    dir_icon=$(get_dir_icon 2>/dev/null)
fi
title="${title//\{DIR_ICON\}/$dir_icon}"
```

3. **Resolve `{SESSION_ID}` token** (add after `{DIR_ICON}`):
```bash
# Resolve {SESSION_ID}
local session_id_display=""
if [[ -n "${TAVS_SESSION_ID:-}" ]]; then
    session_id_display="${TAVS_SESSION_ID:0:8}"
fi
title="${title//\{SESSION_ID\}/$session_id_display}"
```

4. **Guillemet cleanup** (REPLACE the existing space collapse sed):
```bash
# Clean up empty tokens around guillemets and pipes, then collapse spaces
title=$(printf '%s\n' "$title" | sed \
    -e 's/«|/«/g' \
    -e 's/|»/»/g' \
    -e 's/«»//g' \
    -e 's/  */ /g; s/^ *//; s/ *$//')
```

5. **Per-state format defaults update** — Ensure per-state formats that currently
   include `{SESSION_ICON}` also participate in the dynamic guillemet injection.
   Since the injection targets `{SESSION_ICON}` in any format string, existing
   per-state formats like `TAVS_TITLE_FORMAT_PERMISSION` will automatically gain
   identity icons IF they contain `{SESSION_ICON}`. Formats that omit it (like
   the current `{FACE} {STATUS_ICON} {CONTEXT_FOOD}{CONTEXT_PCT} {BASE}`) will
   remain unchanged — identity icons intentionally hidden in those states.

   To ensure identity tokens appear in permission/idle/complete states, add
   `{SESSION_ICON}` to per-state defaults that currently lack it:
```bash
# Updated per-state defaults (add {SESSION_ICON} before {BASE}):
TAVS_TITLE_FORMAT_PERMISSION="{FACE} {STATUS_ICON} {SESSION_ICON} {CONTEXT_FOOD}{CONTEXT_PCT} {BASE}"
TAVS_TITLE_FORMAT_COMPLETE="{FACE} {STATUS_ICON} {SESSION_ICON} {BASE}"
TAVS_TITLE_FORMAT_IDLE="{FACE} {STATUS_ICON} {SESSION_ICON} {BASE}"
```

**Acceptance Criteria:**
- [ ] `{DIR_ICON}` resolves to flag emoji when dual mode
- [ ] `{DIR_ICON}` resolves to empty when single mode or off
- [ ] Dynamic guillemet injection replaces `{SESSION_ICON}` with `«{DIR_ICON}|{SESSION_ICON}»`
- [ ] Injection only happens in dual mode and only when `{DIR_ICON}` not already present
- [ ] Existing format string is unchanged for `single`/`off` users
- [ ] `{SESSION_ICON}` continues to work (existing behavior)
- [ ] `{SESSION_ID}` shows first 8 chars of session_id
- [ ] `{SESSION_ID}` is empty when no session_id available
- [ ] `«|🦊»` cleans to `«🦊»` (no dir icon)
- [ ] `«🇩🇪|»` cleans to `«🇩🇪»` (no session icon)
- [ ] `«|»` cleans to empty string (neither icon)
- [ ] `«»` cleans to empty string
- [ ] Per-state formats include `{SESSION_ICON}` for dynamic injection
- [ ] No regression in existing token resolution

---

### Phase 7: Configuration Polish & User Template

**Scope:** Update `user.conf.template` with new settings documentation, format presets,
and add identity variables to `_resolve_agent_variables()` for per-agent overrides.
(Pool definitions and defaults.conf changes are in Phase 0.)

**Depends On:** Phase 0, Phase 6

**Files:** `src/config/user.conf.template` (MODIFY), `src/core/theme-config-loader.sh` (MODIFY)

**Changes to user.conf.template:**

1. Add Identity System section with all new settings commented out
2. Add Format Presets section with 4 preset examples:
   - Minimal: `{FACE} {STATUS_ICON} {AGENTS} {SESSION_ICON} {BASE}`
   - Standard (default with dual): auto-injected guillemets
   - Full Identity: `{FACE} {STATUS_ICON} {AGENTS} «{DIR_ICON}|{SESSION_ICON}» {SESSION_ID} {BASE}`
   - Bubble (future): `{FACE} «{STATUS_ICON}|{CONTEXT_FOOD}{CONTEXT_PCT}|{AGENTS}|{SESSION_ICON}|{DIR_ICON}»`
3. Document new tokens: `{DIR_ICON}`, `{SESSION_ID}`
4. Document persistence modes with examples
5. Document `TAVS_IDENTITY_MODE` values: `dual`, `single`, `off`

**Changes to theme-config-loader.sh:**

1. Add identity variables to `_resolve_agent_variables()` for per-agent overrides:
   - `TAVS_DIR_ICON_TYPE`
   - `TAVS_IDENTITY_MODE`

**Acceptance Criteria:**
- [ ] user.conf.template documents all new settings
- [ ] Format presets documented with examples
- [ ] Identity mode values (`dual`/`single`/`off`) documented
- [ ] Per-agent overrides for identity variables work
- [ ] `./tavs set identity-mode <mode>` added to CLI (tavs script)

---

### Phase 8: Documentation & CLAUDE.md Updates

**Scope:** Update project documentation to reflect new identity system.

**Depends On:** All previous phases

**Files:** `CLAUDE.md`, relevant `docs/reference/` files

**Changes:**
1. Add identity system to CLAUDE.md visual states table
2. Document new tokens in title format section
3. Update session icon documentation
4. Add identity system to testing commands
5. Document worktree detection behavior
6. Update user.conf.template references

**Acceptance Criteria:**
- [ ] CLAUDE.md reflects new identity system
- [ ] Testing commands include identity verification
- [ ] Token documentation includes `{DIR_ICON}`, `{SESSION_ICON}`, `{SESSION_ID}`

---

## Constraints & Boundaries

### Out of Scope

- **"Bubble" format implementation** — The future `∃[. .]E «🔥|📦75%|🤖|📁»` format
  is a SEPARATE feature. This spec only ensures individual tokens SUPPORT it.
- **Wizard step for identity** — The wizard update is a follow-up task (adding a step
  for identity mode, persistence, pool selection).
- **StatusLine bridge changes** — The bridge already provides context data. Session_id
  comes from hook JSON, not StatusLine. No bridge changes needed.
- **`$CLAUDE_SESSION_ID` environment variable** — Depends on Claude Code issue #17188.
  This spec uses hook JSON stdin as the source. If/when the env var appears, it can be
  used as an additional source with minimal changes.
- **Gemini/OpenCode session_id extraction** — Their hook formats differ. This spec
  focuses on Claude Code. Other agents get TTY-based fallback for session identity.

### Technical Constraints

- **No jq dependency** — All JSON extraction via `sed` (matching existing patterns in
  `src/agents/claude/trigger.sh:27-34`)
- **Hook timeout: 5 seconds** — All hook operations must complete within 5s. Git commands
  (worktree detection) must have timeout protection.
- **Async hooks** — All hooks are `async: true`. Identity operations must be idempotent
  and handle concurrent invocations safely. Counter operations use `mkdir`-based locking.
- **macOS compatibility** — `timeout` command not available by default. Use platform-aware
  helper: `timeout` → `gtimeout` → bare command fallback.
- **Zsh compatibility** — Use intermediate variables for brace defaults. No bashisms
  that fail in zsh. (Established pattern, see MEMORY.md)
- **No file sourcing** — All state files parsed with `while IFS='=' read` loops.
  Never `source` a state file. (Security pattern, established in TAVS)
- **Atomic writes** — All state file modifications use `mktemp` + `mv` pattern.
  (Established pattern from `session-icon.sh:78-80`)
- **TTY_SAFE naming** — All per-TTY files use `${TTY_SAFE}` suffix.
  (Derivation: `${TTY_DEVICE//\//_}`, reversal: `${tty_key//_//}`)

### Dependencies

- **Claude Code hooks system** — JSON payload via stdin to hook commands
- **`session_id` field in hook JSON** — Confirmed present in all events
- **`cwd` field in hook JSON** — Confirmed present in most events
- **`git` command** — Required only for worktree detection (optional feature)
- **`cksum` or `md5sum`** — For path hashing (both widely available)
- **`get_spinner_state_dir()`** from `spinner.sh` — For persistent storage directory

---

## Rejected Alternatives

| Alternative | Why Rejected |
|-------------|--------------|
| **Hash-based determinism** (MD5 mod pool_size) | Birthday paradox: ~50% collision by session 10 with 25-pool. Round-robin gives collision-free first 80 sessions. (D01) |
| **`[brackets]` for dual icon display** | Claude Code agent face `Ǝ[• •]E` already uses brackets. Guillemets `«»` avoid visual confusion. (D02) |
| **Same icon pool for dirs and sessions** | Separate pools make it instantly clear which icon means what. "Animals are features, flags are nations." (D03) |
| **Composite `{IDENTITY}` token** | Future bubble format requires independent token positioning. Composite creates formatting lock-in. (D09, D15) |
| **Opt-in dual mode** | The identity system IS the value proposition. Default on ensures all users benefit immediately. (D10) |
| **Hash-based secondary icon** (for 2-icon overflow) | Hash doesn't guarantee uniqueness of secondary either. Round-robin secondary is more controlled. (D13) |
| **`$CLAUDE_SESSION_ID` env var** | Not yet available (feature request #17188). Hook JSON is the only reliable source today. |
| **Always show 2-icon pair** | Permanent pairs waste visual space when collision clears. Dynamic display shows pair only when needed. (D13) |
| **Single persistence mode** | Users have different needs: some want fresh icons per reboot, others want lifetime consistency. Two modes serves both. (D05) |
| **PreCompact re-validation** | Compaction always follows user prompt which already triggers re-validation. Redundant check. (D14) |

---

## Verification Strategy

### Code Testing

Each phase has specific acceptance criteria (see phases above). Key testing patterns:

**Registry Core (Phase 1):**
```bash
# Round-robin sequential output
source src/core/identity-registry.sh
icons=()
for i in $(seq 1 10); do
    icons+=("$(_round_robin_next "test" "TAVS_SESSION_ICON_POOL")")
done
# Verify: all 10 are different, sequential from pool

# TTL cleanup
_registry_store "test" "old_key" "🦊"
# Manually backdate timestamp in registry file
_registry_cleanup_expired "test" 1  # 1-second TTL
_registry_lookup "test" "old_key"  # Should be empty
```

**Determinism (Phase 3):**
```bash
# Same session_id → same icon, different TTYs
export TTY_SAFE="_dev_ttys001" TAVS_SESSION_ID="test1234"
assign_session_icon && icon1=$(get_session_icon)
release_session_icon
rm -f "${state_dir}/session-icon._dev_ttys001"  # Clear cache, keep registry

export TTY_SAFE="_dev_ttys002"  # Different TTY
assign_session_icon && icon2=$(get_session_icon)
[[ "$icon1" == "$icon2" ]]  # Must be true (deterministic)
```

**Collision Overflow (Phase 3):**
```bash
# Force collision
export TTY_SAFE="_dev_ttys001" TAVS_SESSION_ID="session_a"
assign_session_icon  # Gets primary 🦊
export TTY_SAFE="_dev_ttys002" TAVS_SESSION_ID="session_b"
# Manually store session_b with same primary in registry
assign_session_icon  # Should detect collision, get secondary
icon=$(get_session_icon)
[[ "$icon" == *" "* ]]  # Should be two animals (e.g., "🦊 🐙")
```

**Title Cleanup (Phase 6):**
```bash
# Test guillemet cleanup
echo '«|🦊»' | sed -e 's/«|/«/g' -e 's/|»/»/g' -e 's/«»//g'
# Expected: «🦊»

echo '«🇩🇪|»' | sed -e 's/«|/«/g' -e 's/|»/»/g' -e 's/«»//g'
# Expected: «🇩🇪»

echo '«|»' | sed -e 's/«|/«/g' -e 's/|»/»/g' -e 's/«»//g'
# Expected: (empty)
```

### Integration Testing

```bash
# Full lifecycle with identity — note: dir icon NOT at reset (no cwd in SessionStart)
TAVS_SESSION_ID=test1234 \
    ./src/core/trigger.sh reset
# Verify title shows «🦊» (session icon only, no dir icon yet)

# First prompt — dir icon assigned now (cwd available in UserPromptSubmit)
TAVS_SESSION_ID=test1234 TAVS_CWD=/tmp/testproject \
    ./src/core/trigger.sh processing new-prompt
# Verify title shows «flag|animal»

./src/core/trigger.sh processing
# Verify icons persist across state changes

./src/core/trigger.sh complete
# Verify icons in complete state title

# Re-validation on prompt submit — dir changes, session stays
TAVS_SESSION_ID=test1234 TAVS_CWD=/tmp/different-project \
    ./src/core/trigger.sh processing new-prompt
# Verify dir icon changed, session icon same

# SessionEnd cleanup
./src/core/trigger.sh reset session-end
# Verify icons released from active-sessions index

# Persistence mode test
TAVS_IDENTITY_PERSISTENCE=ephemeral ./src/core/trigger.sh reset
ls /tmp/tavs-identity/  # Files here

TAVS_IDENTITY_PERSISTENCE=persistent ./src/core/trigger.sh reset
ls ~/.cache/tavs/  # Registry files here

# Worktree test (requires actual git worktree)
cd /path/to/worktree
./src/core/trigger.sh reset
# Verify title shows main→worktree flag pair

# Backward compatibility
TAVS_IDENTITY_MODE=off ./src/core/trigger.sh reset
# Verify random animal icon (current behavior)

# Deploy and live test
./tavs sync
# Submit prompt in Claude Code, verify title shows «flag|animal»
```

### Edge Cases

| Edge Case | Expected Behavior |
|-----------|-------------------|
| No `session_id` in hook JSON | Falls back to TTY_SAFE as session key |
| Empty `cwd` in hook JSON | Dir icon deferred to first UserPromptSubmit; guillemet cleanup handles gracefully |
| SessionStart lacks `cwd` field | Dir icon NOT assigned at reset; assigned on first `new-prompt` |
| All 80 animals assigned to active sessions | Round-robin wraps; collision triggers 2-icon overflow |
| Reboot clears `/tmp/` (ephemeral mode) | Fresh icons on next session start; round-robin restarts |
| Same session reopened after reboot (persistent) | Registry lookup finds existing mapping |
| Git not installed (worktree detection) | `command -v git` fails; single flag only, no arrow |
| Non-git directory | `git rev-parse` fails; single flag from cwd hash |
| Worktree of a worktree | `git-common-dir` still points to original main repo |
| Concurrent hook invocations | Atomic writes prevent corruption; idempotent assignment |
| `TAVS_IDENTITY_MODE=off` + `«{DIR_ICON}|{SESSION_ICON}»` in format | Both tokens empty; guillemet cleanup removes `«|»` |
| Flag emoji on Linux terminal | User sets `TAVS_DIR_ICON_TYPE=plants`; plants pool used |
| `session_id` contains special chars | `sed` extraction handles quotes; registry stores escaped |

---

## Open Questions

1. **Flag emoji auto-detection**: The spec mentions `TAVS_DIR_ICON_TYPE="auto"` but
   does not specify HOW to detect if flags render. Simple approaches: check `$TERM_PROGRAM`
   (iTerm2/Kitty → flags OK, others → fallback), or check locale for UTF-8. Deferred to
   implementation — the manual `"flags"|"plants"|"buildings"` settings work immediately.

2. **`$CLAUDE_SESSION_ID` env var**: When Claude Code implements issue #17188, the
   session_id will be available as an environment variable. At that point, the hook JSON
   extraction becomes a fallback rather than primary source. No spec change needed —
   `_get_session_key()` can simply prefer the env var when present.

3. **Pool curation**: The spec includes the full pools (~80 animals, ~190 flags) as
   provided by the user. Some emoji may not render well at small font sizes or in
   certain terminals. A future pass could curate for rendering quality, but this is
   out of scope for initial implementation.

4. **Wizard integration**: Adding identity mode selection to `./tavs wizard` (Step 8?)
   is a natural follow-up but not part of this spec. The settings can be configured
   manually via `user.conf` or `./tavs set` commands.

---

## Appendix A: Complete Icon Pools

### Session Icons (~80 Animals)

```bash
TAVS_SESSION_ICON_POOL=(
    # Mammals
    "🐕" "🐶" "🐺" "🦊" "🐩" "🐈" "🐱" "🐆" "🐅" "🐯"
    "🦍" "🐒" "🐵" "🐖" "🐷" "🐎" "🐴" "🐐" "🐏" "🐑"
    "🐗" "🦏" "🐘" "🐼" "🐨" "🐪" "🐫" "🐄" "🐮" "🐂"
    "🐻" "🐃" "🐇" "🐰" "🐿" "🐹" "🐭"
    # Birds
    "🐓" "🐔" "🐣" "🐤" "🦃" "🐦" "🕊" "🦅" "🦉" "🦆" "🐧"
    # Aquatic
    "🐢" "🐙" "🦀" "🦐" "🦈" "🐬" "🐳" "🐋" "🐟" "🐠" "🐡"
    # Reptiles & Bugs
    "🐍" "🐊" "🦎" "🐛" "🐜" "🐌" "🐝" "🐞" "🦋"
    # Additional (from existing pool)
    "🦭" "🪲" "🦑" "🪼" "🦔" "🐸" "🦩" "🦚" "🦥"
)
```

### Directory Icons (~190 Flags)

```bash
TAVS_DIR_ICON_POOL=(
    # Europe (47)
    "🇦🇩" "🇦🇱" "🇦🇲" "🇦🇹" "🇧🇦" "🇧🇪" "🇧🇬" "🇧🇾" "🇨🇭" "🇨🇾"
    "🇨🇿" "🇩🇪" "🇩🇰" "🇪🇪" "🇪🇸" "🇫🇮" "🇫🇷" "🇬🇧" "🇬🇪" "🇬🇷"
    "🇭🇷" "🇭🇺" "🇮🇪" "🇮🇸" "🇮🇹" "🇱🇮" "🇱🇹" "🇱🇺" "🇱🇻" "🇲🇨"
    "🇲🇩" "🇲🇪" "🇲🇰" "🇲🇹" "🇳🇱" "🇳🇴" "🇵🇱" "🇵🇹" "🇷🇴" "🇷🇸"
    "🇸🇪" "🇸🇮" "🇸🇰" "🇸🇲" "🇺🇦" "🇻🇦" "🇽🇰"
    # The Americas (33)
    "🇦🇬" "🇦🇷" "🇧🇧" "🇧🇴" "🇧🇷" "🇧🇸" "🇧🇿" "🇨🇦" "🇨🇱" "🇨🇴"
    "🇨🇷" "🇨🇺" "🇩🇲" "🇩🇴" "🇪🇨" "🇬🇩" "🇬🇹" "🇬🇾" "🇭🇳" "🇭🇹"
    "🇯🇲" "🇲🇽" "🇳🇮" "🇵🇦" "🇵🇪" "🇵🇷" "🇵🇾" "🇸🇷" "🇸🇻" "🇹🇹"
    "🇺🇸" "🇺🇾" "🇻🇪"
    # Asia & Middle East (47)
    "🇦🇪" "🇦🇫" "🇧🇩" "🇧🇭" "🇧🇳" "🇧🇹" "🇨🇳" "🇭🇰" "🇮🇩" "🇮🇱"
    "🇮🇳" "🇮🇶" "🇮🇷" "🇯🇴" "🇯🇵" "🇰🇬" "🇰🇭" "🇰🇵" "🇰🇷" "🇰🇼"
    "🇰🇿" "🇱🇦" "🇱🇧" "🇱🇰" "🇲🇲" "🇲🇳" "🇲🇻" "🇲🇾" "🇳🇵" "🇴🇲"
    "🇵🇭" "🇵🇰" "🇵🇸" "🇶🇦" "🇷🇺" "🇸🇦" "🇸🇬" "🇸🇾" "🇹🇭" "🇹🇯"
    "🇹🇱" "🇹🇲" "🇹🇷" "🇹🇼" "🇺🇿" "🇻🇳" "🇾🇪"
    # Africa (49)
    "🇦🇴" "🇧🇫" "🇧🇮" "🇧🇯" "🇧🇼" "🇨🇩" "🇨🇫" "🇨🇬" "🇨🇮" "🇨🇲"
    "🇨🇻" "🇩🇯" "🇩🇿" "🇪🇬" "🇪🇷" "🇪🇹" "🇬🇦" "🇬🇭" "🇬🇲" "🇬🇳"
    "🇬🇶" "🇰🇪" "🇱🇷" "🇱🇸" "🇱🇾" "🇲🇦" "🇲🇬" "🇲🇱" "🇲🇷" "🇲🇺"
    "🇲🇼" "🇲🇿" "🇳🇦" "🇳🇪" "🇳🇬" "🇷🇼" "🇸🇩" "🇸🇱" "🇸🇳" "🇸🇴"
    "🇸🇸" "🇹🇩" "🇹🇬" "🇹🇳" "🇹🇿" "🇺🇬" "🇿🇦" "🇿🇲" "🇿🇼"
    # Oceania (14)
    "🇦🇺" "🇫🇯" "🇫🇲" "🇰🇮" "🇲🇭" "🇳🇷" "🇳🇿" "🇵🇬" "🇵🇼" "🇸🇧"
    "🇹🇴" "🇹🇻" "🇻🇺" "🇼🇸"
)
# Total: ~190 flags
```

### Fallback Pool A: Plants/Trees (~26)

```bash
TAVS_DIR_FALLBACK_POOL_A=(
    "🌳" "🌴" "🌵" "🌲" "🌾" "🌿" "🍀" "🎋" "🎍" "🪴"
    "🌸" "🌺" "🌻" "🌹" "🌼" "🌷" "💐" "🪷" "🌱" "🎄"
    "🍁" "🍂" "🍃" "🪻" "🌽" "🌶"
)
```

### Fallback Pool B: Buildings (~24)

```bash
TAVS_DIR_FALLBACK_POOL_B=(
    "🏠" "🏡" "🏢" "🏣" "🏤" "🏥" "🏦" "🏨" "🏩" "🏪"
    "🏫" "🏬" "🏭" "🏯" "🏰" "⛪" "🕌" "🕍" "🛕" "⛩"
    "🗼" "🗽" "🏗" "🏛"
)
```

---

## Appendix B: Configuration Reference

### All New Configuration Variables

| Variable | Default | Values | Description |
|----------|---------|--------|-------------|
| `TAVS_IDENTITY_MODE` | `"dual"` | `"single"`, `"dual"`, `"off"` | Identity system mode |
| `TAVS_IDENTITY_PERSISTENCE` | `"ephemeral"` | `"ephemeral"`, `"persistent"` | Registry storage location |
| `TAVS_DIR_IDENTITY_SOURCE` | `"cwd"` | `"cwd"`, `"git-root"` | How directory path is resolved |
| `TAVS_DIR_WORKTREE_DETECTION` | `"true"` | `"true"`, `"false"` | Enable git worktree detection |
| `TAVS_IDENTITY_REGISTRY_TTL` | `2592000` | Integer (seconds) | Registry entry TTL (30 days) |
| `TAVS_DIR_ICON_TYPE` | `"flags"` | `"flags"`, `"plants"`, `"buildings"`, `"auto"` | Directory icon pool type |
| `TAVS_SESSION_ICON_POOL` | (~80 animals) | Array of emoji | Session icon pool |
| `TAVS_DIR_ICON_POOL` | (~190 flags) | Array of emoji | Directory icon pool |
| `TAVS_DIR_FALLBACK_POOL_A` | (~26 plants) | Array of emoji | Fallback pool A |
| `TAVS_DIR_FALLBACK_POOL_B` | (~24 buildings) | Array of emoji | Fallback pool B |

### New Title Tokens

| Token | Source | Example | Available When |
|-------|--------|---------|----------------|
| `{DIR_ICON}` | `get_dir_icon()` | `🇩🇪` or `🇩🇪→🇯🇵` | `TAVS_IDENTITY_MODE=dual` |
| `{SESSION_ICON}` | `get_session_icon()` | `🦊` or `🦊🐙` | `TAVS_IDENTITY_MODE` != `off` |
| `{SESSION_ID}` | `TAVS_SESSION_ID[:8]` | `abc123de` | Claude Code (session_id in hook JSON) |

### Backward Compatibility

| Setting | Behavior |
|---------|----------|
| `TAVS_IDENTITY_MODE=off` | Exact current behavior (random per-TTY, 25 animals) |
| `TAVS_IDENTITY_MODE=single` | Deterministic session icon (round-robin, 80 animals), no dir icon, no guillemets |
| `TAVS_SESSION_ICONS=(...)` | User override detected and propagated to `TAVS_SESSION_ICON_POOL` after config load |
| `ENABLE_SESSION_ICONS="true"` | Still works; `=false` automatically maps to `TAVS_IDENTITY_MODE=off` |
| No `session_id` available | Falls back to TTY_SAFE as session key (non-Claude agents) |
| Legacy `session-icon.{TTY_SAFE}` files | Auto-detected (no `=` in first line) and removed for re-assignment |

---

## Review Notes

**Reviewed by:** gemini-orchestrator, codex-orchestrator (Claude Opus 4.6)
**Date:** 2026-02-16

### Changes from Review

**Critical Fixes Applied:**

1. **Dir icon deferred to UserPromptSubmit** — SessionStart JSON lacks `cwd` field.
   Dir icon now assigned on first `new-prompt`, not at `reset`. Guillemet cleanup
   handles the `«|🦊»` → `«🦊»` transition gracefully. (Gemini C1 + Codex C1)

2. **mkdir-based locking for round-robin counter** — TOCTOU race under concurrent
   async hooks resolved with `mkdir`-as-lock pattern. Spin-wait up to 2s with timeout
   fallback to collision overflow backstop. (Gemini C2 + Codex B1)

3. **Active-sessions index for O(1) collision check** — Replaced per-TTY file scanning
   (O(n) I/O) with single `active-sessions` index file. Collision check is now one
   file read + grep. (Gemini C3)

4. **`TAVS_IDENTITY_MODE=single` fully defined** — Single mode = deterministic session
   icon (round-robin, 80 animals), no dir icon, title format unchanged, no guillemets.
   (Gemini C4 + Codex C4)

5. **Backward compat alias fix** — `TAVS_SESSION_ICONS` user override detected after
   config load and propagated to `TAVS_SESSION_ICON_POOL`. (Codex B2)

6. **Phase 7 split into Phase 0 + Phase 7** — Config foundation (pool arrays, new vars)
   moved to Phase 0 as prerequisite for all subsequent phases. Phase 7 reduced to
   user.conf.template polish. (Codex B3)

**Significant Fixes Applied:**

7. **Platform-aware git timeout** — `_git_with_timeout()` helper tries `timeout`,
   `gtimeout`, then bare `git`. Worktree detection uses subshell + `--is-inside-work-tree`
   guard for fast non-git-dir rejection. (Gemini S1 + Codex C2, S2)

8. **Dynamic guillemet injection** — Instead of changing static default format, dual mode
   dynamically injects `«{DIR_ICON}|{SESSION_ICON}»` in place of `{SESSION_ICON}` in
   `compose_title()`. Existing format unchanged for `single`/`off` users. (Gemini S4)

9. **Per-state format defaults updated** — Permission, complete, and idle states now
   include `{SESSION_ICON}` so dynamic guillemet injection works across all states.
   (Gemini S6 + Codex C5)

10. **SessionEnd differentiation** — `reset session-end` releases icons instead of
    re-assigning them. (Codex C6)

11. **Legacy file migration** — First-line detection (`*"="*` check) auto-removes
    old single-emoji format files for clean re-assignment. (Gemini S7)

12. **`ENABLE_SESSION_ICONS=false` mapping** — Automatically sets
    `TAVS_IDENTITY_MODE=off` for backward compatibility. (Codex S5)

13. **Lazy-loaded identity modules** — `identity-registry.sh` and `dir-icon.sh` only
    sourced on `reset` and `new-prompt`, not every hook invocation. (Codex S3)

14. **Identity variables in `_resolve_agent_variables()`** — Added for per-agent
    overrides. (Codex S1)

### Accepted Risks

1. **Path hashing collision (cksum 32-bit)** — ~0.4% collision chance with 190 entries.
   Two dirs sharing a flag is cosmetically minor, not functional. Accepted. (Gemini S3)

2. **Registry store concurrent-write for different keys** — Last-writer-wins risk.
   Entries self-heal on next session start. Counter locking protects the critical path;
   registry store accepts the minor risk. Accepted. (Codex C3)

3. **Registry unbounded growth in persistent mode** — 30-day TTL cleanup at SessionStart
   is sufficient. Even 1000 entries ≈ 80KB. Accepted. (Gemini S2)

4. **Guillemet cleanup simplistic for future bubble format** — Current sed handles
   `«A|B»` correctly. Multi-pipe cleanup deferred to bubble format implementation
   (explicitly out of scope). Accepted. (Gemini S5)

5. **Guillemet chars in user titles** — Low risk since `«` and `»` are rare in
   terminal tab titles. Accepted. (Codex C7)
