#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — Mute Gate (Stage-1 Helpers)
# ==============================================================================
# Sourced by trigger.sh AFTER stage-0 has set _TAVS_SUPPRESS_OUTPUT.
# Provides: runtime dir resolution, mute liveness validation, active-TTY
# registry, pending-cache buffer open/close, and emit_osc (the single
# choke point for all OSC writes to the TTY).
#
# Stage-0 (inline in trigger.sh) uses builtins only to read mute.state
# and set a preliminary _TAVS_SUPPRESS_OUTPUT flag. Stage-1 (this file)
# validates the time-sensitive fields (UNTIL_EPOCH, WRITTEN_EPOCH) which
# require one date(1) fork — acceptable because sourcing already costs ~ms.
# ==============================================================================

_tavs_policy_dir="${BASH_SOURCE[0]%/*}"
[[ "$_tavs_policy_dir" == "${BASH_SOURCE[0]}" ]] && _tavs_policy_dir=.
source "$_tavs_policy_dir/visual-restrictions-state.sh"
unset _tavs_policy_dir

# ==============================================================================
# RUNTIME DIRECTORY
# ==============================================================================
# UID-namespaced to avoid multi-user collisions (SPEC D22).
# Default: /tmp/tavs-$(id -u), mode 0700.
# ==============================================================================

_tavs_resolve_runtime_dir() {
    if [[ -z "${TAVS_RUNTIME_DIR:-}" ]]; then
        TAVS_RUNTIME_DIR="/tmp/tavs-$(id -u)"
        export TAVS_RUNTIME_DIR
    fi
    if [[ ! -d "$TAVS_RUNTIME_DIR" ]]; then
        mkdir -m 0700 -p "$TAVS_RUNTIME_DIR"
    fi
    [[ -d "$TAVS_RUNTIME_DIR/pending" ]] || mkdir -p "$TAVS_RUNTIME_DIR/pending"
    [[ -d "$TAVS_RUNTIME_DIR/active-ttys" ]] || mkdir -p "$TAVS_RUNTIME_DIR/active-ttys"
}

# ==============================================================================
# MUTE LIVENESS VALIDATION (Stage-1)
# ==============================================================================
# Called after stage-0 sets _TAVS_SUPPRESS_OUTPUT=1. Validates the
# time-sensitive fields that stage-0 deferred (requires date(1) fork).
# If validation fails, resets _TAVS_SUPPRESS_OUTPUT to 0.
#
# Rationale for the split: stage-0 must use bash builtins only (SPEC §4.5)
# because it runs before theme/terminal sources. Epoch comparison needs
# date +%s which is an external command. Stage-1 runs during the normal
# source pass (~57ms baseline) where one fork is negligible.
# ==============================================================================

_tavs_validate_mute_liveness() {
    if _tavs_visual_restrictions_suspended; then
        _TAVS_SUPPRESS_OUTPUT=0
        unset _TAVS_S0_MUTED _TAVS_S0_PID _TAVS_S0_VER _TAVS_S0_UNTIL _TAVS_S0_WRITTEN _TAVS_S0_REASON
        unset _TAVS_S0_LOCKED _TAVS_S0_LOCK_UNTIL _TAVS_S0_UNLOCK_UNTIL _TAVS_S0_LOCK_VER
        return 0
    fi
    if [[ "${_TAVS_SUPPRESS_OUTPUT:-0}" != "1" ]]; then
        return 0
    fi

    local now
    now=$(date +%s)

    # Hard lock first (spec D3, fail-closed): an unexpired lock without an
    # active grant keeps suppression on REGARDLESS of every mute check below
    # (dead APP_PID, stale heartbeat, absent mute.state). Expiry always wins;
    # a missing or non-numeric LOCK_UNTIL means not locked.
    if [[ "${_TAVS_S0_LOCKED:-}" == "true" ]]; then
        if [[ -n "${_TAVS_S0_LOCK_UNTIL:-}" && "${_TAVS_S0_LOCK_UNTIL}" != *[!0-9]* ]] \
            && (( now < _TAVS_S0_LOCK_UNTIL )); then
            local _grant="${_TAVS_S0_UNLOCK_UNTIL:-}"
            if ! { [[ -n "$_grant" && "$_grant" != *[!0-9]* ]] && (( now < _grant )); }; then
                _tavs_debug_mute "LOCK effective until ${_TAVS_S0_LOCK_UNTIL}"
                unset _TAVS_S0_LOCKED _TAVS_S0_LOCK_UNTIL _TAVS_S0_UNLOCK_UNTIL _TAVS_S0_LOCK_VER
                return 0
            fi
        fi
    fi

    # Lock not effective: stage-0 sets suppression for EITHER cause, so the
    # mute-only verdict must be recomputed from scratch here, including the
    # PID/version gates stage-0 applies only on the mute path.
    if [[ "${_TAVS_S0_MUTED:-}" != "true" || "${_TAVS_S0_VER:-1}" != "1" ]]; then
        _TAVS_SUPPRESS_OUTPUT=0
        unset _TAVS_S0_LOCKED _TAVS_S0_LOCK_UNTIL _TAVS_S0_UNLOCK_UNTIL _TAVS_S0_LOCK_VER
        return 0
    fi
    if [[ -n "${_TAVS_S0_PID:-}" ]] && ! kill -0 "$_TAVS_S0_PID" 2>/dev/null; then
        _TAVS_SUPPRESS_OUTPUT=0
        unset _TAVS_S0_LOCKED _TAVS_S0_LOCK_UNTIL _TAVS_S0_UNLOCK_UNTIL _TAVS_S0_LOCK_VER
        return 0
    fi

    # UNTIL_EPOCH: 0 means indefinite; non-zero means mute expires at that epoch
    if [[ -n "${_TAVS_S0_UNTIL:-}" && "${_TAVS_S0_UNTIL}" != "0" ]]; then
        if (( _TAVS_S0_UNTIL < now )); then
            _TAVS_SUPPRESS_OUTPUT=0
            return 0
        fi
    fi

    # WRITTEN_EPOCH: heartbeat must be within 120 seconds
    if [[ -n "${_TAVS_S0_WRITTEN:-}" ]]; then
        if (( now - _TAVS_S0_WRITTEN > 120 )); then
            _TAVS_SUPPRESS_OUTPUT=0
            return 0
        fi
    fi

    # Clean up stage-0 temporaries
    unset _TAVS_S0_MUTED _TAVS_S0_PID _TAVS_S0_VER _TAVS_S0_UNTIL _TAVS_S0_WRITTEN _TAVS_S0_REASON
    unset _TAVS_S0_LOCKED _TAVS_S0_LOCK_UNTIL _TAVS_S0_UNLOCK_UNTIL _TAVS_S0_LOCK_VER
}

# ==============================================================================
# FULL MUTE STATE CHECK (for idle worker re-reads)
# ==============================================================================
# The idle worker is a long-running background process that needs to
# re-check mute state each tick. This function does the full read +
# validation in one call (stage-0 + stage-1 combined).
# ==============================================================================

_tavs_check_mute_state() {
    _TAVS_SUPPRESS_OUTPUT=0
    if _tavs_visual_restrictions_suspended; then return 1; fi

    # Hard lock first (spec D3): fail-closed, no PID/heartbeat gates, finite
    # expiry always wins, an active grant suspends it.
    local lock_file="${TAVS_RUNTIME_DIR:-/tmp/tavs-$UID}/lock.state"
    if [[ -f "$lock_file" ]]; then
        local _lk="" _lv="" _l_locked="" _l_until="" _l_grant="" _l_ver=""
        while IFS='=' read -r _lk _lv; do
            _lv="${_lv%\"}"
            _lv="${_lv#\"}"
            case "$_lk" in
                LOCKED) _l_locked="$_lv" ;;
                LOCK_UNTIL_EPOCH) _l_until="$_lv" ;;
                UNLOCK_UNTIL_EPOCH) _l_grant="$_lv" ;;
                SCHEMA_VERSION) _l_ver="$_lv" ;;
            esac
        done < "$lock_file"
        if [[ "$_l_locked" == "true" && "${_l_ver:-1}" == "1" ]] \
            && [[ -n "$_l_until" && "$_l_until" != *[!0-9]* ]]; then
            local _l_now
            _l_now=$(date +%s)
            if (( _l_now < _l_until )); then
                if ! { [[ -n "$_l_grant" && "$_l_grant" != *[!0-9]* ]] && (( _l_now < _l_grant )); }; then
                    _TAVS_SUPPRESS_OUTPUT=1
                    return 0
                fi
            fi
        fi
    fi

    local mute_file="$HOME/.tavs/mute.state"

    [[ ! -f "$mute_file" ]] && return 1

    local _muted="" _until="" _written="" _app_pid="" _version=""
    while IFS='=' read -r key val; do
        val="${val%\"}"
        val="${val#\"}"
        case "$key" in
            MUTED) _muted="$val" ;;
            UNTIL_EPOCH) _until="$val" ;;
            WRITTEN_EPOCH) _written="$val" ;;
            APP_PID) _app_pid="$val" ;;
            SCHEMA_VERSION) _version="$val" ;;
        esac
    done < "$mute_file"

    # Must be explicitly muted with known schema
    [[ "$_muted" != "true" ]] && return 1
    [[ "${_version:-1}" != "1" ]] && return 1

    # PID liveness (kill -0 is a bash builtin)
    if [[ -n "$_app_pid" ]] && ! kill -0 "$_app_pid" 2>/dev/null; then
        return 1
    fi

    local now
    now=$(date +%s)

    # UNTIL_EPOCH expiry
    if [[ -n "$_until" && "$_until" != "0" ]] && (( _until < now )); then
        return 1
    fi

    # WRITTEN_EPOCH heartbeat (120s staleness window)
    if [[ -n "$_written" ]] && (( now - _written > 120 )); then
        return 1
    fi

    _TAVS_SUPPRESS_OUTPUT=1
    return 0
}

# ==============================================================================
# ACTIVE-TTY REGISTRY
# ==============================================================================
# Every trigger.sh / idle-worker invocation touches a file here so the
# broadcaster (Mac app) knows which TTYs are alive. Mtime is the signal.
# ==============================================================================

register_active_tty() {
    [[ -z "${TTY_SAFE:-}" ]] && return 0
    _tavs_resolve_runtime_dir
    touch "$TAVS_RUNTIME_DIR/active-ttys/$TTY_SAFE"
}

# Sweep entries older than 24 hours (called by broadcaster or debug CLI)
clean_active_tty_registry() {
    _tavs_resolve_runtime_dir
    local dir="$TAVS_RUNTIME_DIR/active-ttys"
    [[ ! -d "$dir" ]] && return 0
    find "$dir" -type f -mmin +1440 -delete 2>/dev/null || true
}

# ==============================================================================
# PENDING-CACHE BUFFER LIFECYCLE
# ==============================================================================
# When _TAVS_SUPPRESS_OUTPUT=1, emit_osc appends bytes to a temp buffer.
# At dispatch end, the buffer is atomically renamed to the per-TTY pending
# cache. On crash, the EXIT trap cleans up the temp file.
# ==============================================================================

_tavs_mute_buffer_open() {
    [[ "${_TAVS_SUPPRESS_OUTPUT:-0}" != "1" ]] && return 0
    [[ -z "${TTY_SAFE:-}" ]] && return 0
    _tavs_resolve_runtime_dir
    _TAVS_PENDING_BUFFER=$(mktemp "$TAVS_RUNTIME_DIR/pending/.tmp.XXXXXX")
    export _TAVS_PENDING_BUFFER
}

_tavs_mute_buffer_close() {
    local buf="${_TAVS_PENDING_BUFFER:-}"
    [[ -z "$buf" ]] && return 0

    local tty_safe="${TTY_SAFE:-}"
    if [[ -z "$tty_safe" ]]; then
        rm -f "$buf"
        unset _TAVS_PENDING_BUFFER
        return 0
    fi

    _tavs_resolve_runtime_dir
    local target="$TAVS_RUNTIME_DIR/pending/${tty_safe}.osc"

    if [[ -s "$buf" ]]; then
        mv -f "$buf" "$target"
    else
        rm -f "$buf"
    fi
    unset _TAVS_PENDING_BUFFER
}

# ==============================================================================
# DEBUG MUTE LOGGING
# ==============================================================================

_tavs_debug_mute() {
    [[ "${DEBUG_MUTE:-}" != "1" && "${DEBUG_ALL:-}" != "1" ]] && return 0
    local msg="$1"
    local log="${TAVS_RUNTIME_DIR:-/tmp/tavs-$UID}/mute-trace.log"
    [[ -d "${log%/*}" ]] || return 0
    printf '%s [%d] %s\n' "$(date +%H:%M:%S 2>/dev/null || echo '?')" "$$" "$msg" >> "$log"
}

# ==============================================================================
# INITIALIZATION
# ==============================================================================
# Called explicitly by trigger.sh AFTER TTY_DEVICE/TTY_SAFE are resolved
# (terminal-osc-sequences.sh must be sourced first). Do NOT auto-init on
# source — TTY_SAFE is not available at source time in trigger.sh.
# ==============================================================================

_tavs_mute_gate_init() {
    _tavs_resolve_runtime_dir
    _tavs_validate_mute_liveness
    register_active_tty

    if [[ "${_TAVS_SUPPRESS_OUTPUT:-0}" == "1" ]]; then
        _tavs_mute_buffer_open
        _tavs_debug_mute "MUTED: buffer=${_TAVS_PENDING_BUFFER:-} tty=${TTY_SAFE:-}"
    fi
}
