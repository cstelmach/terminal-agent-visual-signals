#!/bin/bash
# ==============================================================================
# TAVS - Lock state library (shell side of LockState.swift)
# ==============================================================================
# Read/predicate/write helpers for /tmp/tavs-$UID/lock.state, shared by
# cmd-lock.sh, challenge.sh, and cmd-schedule.sh gating.
#
# The mute gate keeps its own legacy predicate; managed terminal writes check
# current policy independently. The predicate definition is spec §2.2:
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
# _LS_WRITTEN, _LS_BG, _LS_FG, _LS_VER and _LS_READ_STATUS.
# Returns 1 for trusted absence, 2 for unavailable state.
_tavs_lock_read() {
    _LS_LOCKED="" _LS_REASON="" _LS_LOCK_UNTIL="" _LS_UNLOCK_UNTIL=""
    _LS_WRITTEN="" _LS_BG="" _LS_FG="" _LS_VER=""
    local f rc
    f=$(_tavs_lock_state_file)
    _LS_READ_STATUS=unavailable
    if _tavs_policy_read_data "$f"; then rc=0; else rc=$?; fi
    _LS_READ_STATUS="$_TAVS_POLICY_READ_STATUS"
    [[ "$rc" == 0 ]] || return "$rc"
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
    done <<< "$_TAVS_POLICY_DATA"
    return 0
}

# Usage: _tavs_lock_effective [now_epoch]
# Reads the state fresh and evaluates the spec §2.2 predicate.
_tavs_lock_effective() {
    _LS_READ_STATUS=unchecked
    if _tavs_visual_restrictions_suspended; then return 1; fi
    local now="${1:-$(date +%s)}" lock_until grant_until
    now=$(_tavs_policy_decimal "$now") || { _LS_READ_STATUS=unavailable; return 1; }
    _tavs_lock_read || return 1
    [[ "$_LS_LOCKED" == "true" && "${_LS_VER:-1}" == "1" ]] || return 1
    lock_until=$(_tavs_policy_decimal "$_LS_LOCK_UNTIL") || return 1
    grant_until=$(_tavs_policy_decimal "$_LS_UNLOCK_UNTIL") || grant_until=0
    (( now < lock_until && now >= grant_until ))
}

# Native mutations share the app's read/merge/replace transaction, never an unlocked retry.
_tavs_lock_native_update() {
    local helper="${TAVS_TEST_HELPER_BIN-/Applications/TAVS.app/Contents/MacOS/TAVSApp}" support=""
    if [[ -x "$helper" ]]; then
        support=$(env -u TAVS_SESSIONS_TEST_ROOT -u TAVS_SESSIONS_TEST_FIXTURE \
            -u TAVS_SESSIONS_TEST_TARGETS "$helper" --validate-config --lock-state-capabilities \
            2>/dev/null) || support=""
    fi
    if [[ "$support" != tavs-lock-state-schema=1 ]]; then
        printf 'tavs: native lock state helper unavailable or unsupported\n' >&2
        return 1
    fi
    "$helper" --lock-state-update "$(_tavs_lock_state_file)" "$@"
}

# Both platforms merge fresh state while holding the same stable mutation mutex.
_tavs_lock_update() {
    if [[ "$(uname -s)" == Darwin ]]; then
        _tavs_lock_native_update "$@"
        return $?
    fi
    if ! command -v python3 >/dev/null; then
        printf 'tavs: portable lock state helper unavailable\n' >&2
        return 1
    fi
    PYTHONDONTWRITEBYTECODE=1 python3 "${BASH_SOURCE[0]%/*}/portable_lock_state.py" \
        "$(_tavs_lock_state_file)" "$@"
}

# Usage: _tavs_lock_write <locked> <reason> <lock_until> <unlock_until> <bg> <fg>
_tavs_lock_write() {
    _tavs_lock_update replace "$@" >/dev/null
}
