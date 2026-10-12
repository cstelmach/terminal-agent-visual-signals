#!/bin/bash
# ==============================================================================
# TAVS — Lock state library (shell side of LockState.swift)
# ==============================================================================
# Read/predicate/write helpers for /tmp/tavs-$UID/lock.state, shared by
# cmd-lock.sh, challenge.sh, and cmd-schedule.sh gating.
#
# NOT sourced by trigger.sh/mute-gate.sh (their stage-0/1 keep an inline
# builtins-only copy for hot-path cost, like the existing mute stage-0) nor by
# the installed shellrc (standalone file). The predicate definition is spec
# §2.2 and must stay in sync across those copies:
#   effective := LOCKED && now < LOCK_UNTIL && !(now < UNLOCK_UNTIL)
# Absent/malformed state or non-numeric LOCK_UNTIL means NOT locked (D3).
# ==============================================================================

_tavs_policy_dir="${BASH_SOURCE[0]%/*}"
[[ "$_tavs_policy_dir" == "${BASH_SOURCE[0]}" ]] && _tavs_policy_dir=.
source "$_tavs_policy_dir/visual-restrictions-state.sh"
unset _tavs_policy_dir

_tavs_lock_runtime_dir() {
    echo "${TAVS_RUNTIME_DIR:-/tmp/tavs-$(id -u)}"
}

_tavs_lock_state_file() {
    echo "$(_tavs_lock_runtime_dir)/lock.state"
}

# Populates _LS_LOCKED, _LS_REASON, _LS_LOCK_UNTIL, _LS_UNLOCK_UNTIL,
# _LS_WRITTEN, _LS_BG, _LS_FG, _LS_VER. Returns 1 when the file is absent.
_tavs_lock_read() {
    _LS_LOCKED="" _LS_REASON="" _LS_LOCK_UNTIL="" _LS_UNLOCK_UNTIL=""
    _LS_WRITTEN="" _LS_BG="" _LS_FG="" _LS_VER=""
    local f
    f=$(_tavs_lock_state_file)
    [[ -r "$f" ]] || return 1
    local k v
    while IFS='=' read -r k v; do
        v="${v%\"}"; v="${v#\"}"
        case "$k" in
            LOCKED)             _LS_LOCKED="$v" ;;
            REASON)             _LS_REASON="$v" ;;
            LOCK_UNTIL_EPOCH)   _LS_LOCK_UNTIL="$v" ;;
            UNLOCK_UNTIL_EPOCH) _LS_UNLOCK_UNTIL="$v" ;;
            WRITTEN_EPOCH)      _LS_WRITTEN="$v" ;;
            LOCK_BG)            _LS_BG="$v" ;;
            LOCK_FG)            _LS_FG="$v" ;;
            SCHEMA_VERSION)     _LS_VER="$v" ;;
        esac
    done < "$f"
    return 0
}

# Usage: _tavs_lock_effective [now_epoch]
# Reads the state fresh and evaluates the spec §2.2 predicate.
_tavs_lock_effective() {
    if _tavs_visual_restrictions_suspended; then return 1; fi
    local now="${1:-$(date +%s)}"
    _tavs_lock_read || return 1
    [[ "$_LS_LOCKED" == "true" && "${_LS_VER:-1}" == "1" ]] || return 1
    [[ -n "$_LS_LOCK_UNTIL" && "$_LS_LOCK_UNTIL" != *[!0-9]* ]] || return 1
    (( now < _LS_LOCK_UNTIL )) || return 1
    if [[ -n "$_LS_UNLOCK_UNTIL" && "$_LS_UNLOCK_UNTIL" != *[!0-9]* ]] && (( now < _LS_UNLOCK_UNTIL )); then
        return 1
    fi
    return 0
}

# Usage: _tavs_lock_write <locked> <reason> <lock_until> <unlock_until> <bg> <fg>
# Atomic tmp+mv into the runtime dir (created 0700 when missing).
_tavs_lock_write() {
    local locked="$1" reason="$2" lock_until="$3" unlock_until="$4" bg="$5" fg="$6"
    local dir
    dir=$(_tavs_lock_runtime_dir)
    [[ -d "$dir" ]] || mkdir -m 0700 -p "$dir" || return 1
    local tmp
    tmp=$(mktemp "$dir/.lock.XXXXXX") || return 1
    {
        printf 'LOCKED="%s"\n' "$locked"
        printf 'REASON="%s"\n' "$reason"
        printf 'LOCK_UNTIL_EPOCH="%s"\n' "$lock_until"
        printf 'UNLOCK_UNTIL_EPOCH="%s"\n' "$unlock_until"
        printf 'WRITTEN_EPOCH="%s"\n' "$(date +%s)"
        printf 'LOCK_BG="%s"\n' "$bg"
        printf 'LOCK_FG="%s"\n' "$fg"
        printf 'SCHEMA_VERSION="1"\n'
    } > "$tmp"
    mv -f "$tmp" "$(_tavs_lock_state_file)"
}
