#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — Mute Gate (Stage-1 Helpers)
# ==============================================================================
# Reads current mute/lock policy without publishing unverified legacy TTY hints.
# ==============================================================================

_tavs_policy_dir="${BASH_SOURCE[0]%/*}"
[[ "$_tavs_policy_dir" == "${BASH_SOURCE[0]}" ]] && _tavs_policy_dir=.
source "$_tavs_policy_dir/visual-restrictions-state.sh"
unset _tavs_policy_dir

# ==============================================================================
# RUNTIME DIRECTORY
# ==============================================================================
# UID-namespaced to avoid multi-user collisions (SPEC D22).
# Default: /tmp/tavs-$(id -u). Managed output creates and validates its storage.
# ==============================================================================

_tavs_resolve_runtime_dir() {
    if [[ -z "${TAVS_RUNTIME_DIR:-}" ]]; then
        TAVS_RUNTIME_DIR="/tmp/tavs-$(id -u)"
        export TAVS_RUNTIME_DIR
    fi
}

# ==============================================================================
# MUTE LIVENESS VALIDATION
# ==============================================================================
# Always recompute from current files so a hard mirror cannot retain a past lock.

_tavs_validate_mute_liveness() {
    _tavs_check_mute_state || true
}

# ==============================================================================
# FULL MUTE STATE CHECK (for idle worker re-reads)
# ==============================================================================
# The idle worker is a long-running background process that needs to
# re-check mute state each tick. This function does the full read +
# validation in one call.
# ==============================================================================

_tavs_check_mute_state() {
    _TAVS_SUPPRESS_OUTPUT=0
    if _tavs_visual_restrictions_suspended; then return 1; fi

    # Hard lock first (spec D3): fail-closed, no PID/heartbeat gates, finite
    # expiry always wins, an active grant suspends it.
    local lock_file="${TAVS_RUNTIME_DIR:-/tmp/tavs-$UID}/lock.state"
    if _tavs_policy_read_data "$lock_file"; then
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
        done <<< "$_TAVS_POLICY_DATA"
        if [[ "$_l_locked" == "true" && "${_l_ver:-1}" == "1" ]] \
            && _l_until=$(_tavs_policy_decimal "$_l_until"); then
            local _l_now
            _l_now=$(_tavs_policy_decimal "$(date +%s)") || return 1
            _l_grant=$(_tavs_policy_decimal "$_l_grant") || _l_grant=0
            if (( _l_now < _l_until )); then
                if (( _l_now >= _l_grant )); then
                    _TAVS_SUPPRESS_OUTPUT=1
                    return 0
                fi
            fi
        fi
    elif [[ "$_TAVS_POLICY_READ_STATUS" != absent ]]; then
        return 1
    fi

    local mute_file="$HOME/.tavs/mute.state"

    _tavs_policy_read_data "$mute_file" || return 1

    local _muted="" _requested="" _requested_present=0 _level="" _reason=""
    local _until="" _written="" _app_pid="" _version=1
    while IFS='=' read -r key val; do
        val="${val%\"}"
        val="${val#\"}"
        case "$key" in
            MUTED) _muted="$val" ;;
            REQUESTED_MUTED) _requested="$val"; _requested_present=1 ;;
            MUTE_LEVEL) _level="$val" ;;
            REASON) _reason="$val" ;;
            UNTIL_EPOCH) _until="$val" ;;
            WRITTEN_EPOCH) _written="$val" ;;
            APP_PID) _app_pid="$val" ;;
            SCHEMA_VERSION) _version="$val" ;;
        esac
    done <<< "$_TAVS_POLICY_DATA"

    # A hard-lock mirror must not outlive the finite lock or its unlock grant.
    [[ "$_level" == hard ]] && return 1
    [[ "$_muted" == true || "$_muted" == false ]] || return 1
    [[ "$_requested_present" == 1 ]] && _muted="$_requested"
    [[ "$_muted" != "true" ]] && return 1
    [[ -z "$_level" || "$_level" == soft ]] || return 1
    case "$_reason" in schedule_window|quiet_period|master_paused|hard_lock|"") ;; *) return 1 ;; esac
    [[ -z "$_level" && "$_reason" == hard_lock ]] && return 1
    [[ "$_version" == 1 ]] || return 1
    _until=$(_tavs_policy_decimal "$_until") || return 1
    _written=$(_tavs_policy_decimal "$_written") || return 1
    _app_pid=$(_tavs_policy_decimal "$_app_pid") || return 1
    (( _until >= 0 && _written > 0 && _app_pid > 0 && _app_pid <= 2147483647 )) || return 1
    kill -0 "$_app_pid" 2>/dev/null || return 1

    local now
    now=$(_tavs_policy_decimal "$(date +%s)") || return 1

    # UNTIL_EPOCH expiry
    if (( _until != 0 && _until < now )); then
        return 1
    fi

    # WRITTEN_EPOCH heartbeat (120s staleness window)
    if (( _written > now || now - _written > 120 )); then
        return 1
    fi

    _TAVS_SUPPRESS_OUTPUT=1
    return 0
}

# ==============================================================================
# ACTIVE-TTY REGISTRY
# ==============================================================================
# Existing entries remain diagnostic hints. Managed registration/rendering caches
# the validated bindings used by current broadcasts and recovery.
# ==============================================================================

# Age and transient write failures do not establish that a TTY owner exited.
clean_active_tty_registry() { return 0; }

# Compatibility callers cannot create or republish opaque historical output.
_tavs_mute_buffer_open() { unset _TAVS_PENDING_BUFFER; }
_tavs_mute_buffer_close() { unset _TAVS_PENDING_BUFFER; }

# ==============================================================================
# DEBUG MUTE LOGGING
# ==============================================================================

_tavs_debug_mute() {
    [[ "${DEBUG_MUTE:-}" != "1" && "${DEBUG_ALL:-}" != "1" ]] && return 0
    local msg="$1"
    local log="${TAVS_RUNTIME_DIR:-/tmp/tavs-$UID}/mute-trace.log"
    [[ -d "${log%/*}" ]] || return 0
    _tavs_debug_append "$log" "$(date +%H:%M:%S 2>/dev/null || echo '?') [$$] $msg"
}

# ==============================================================================
# INITIALIZATION
# ==============================================================================
# Called explicitly after TTY_DEVICE/TTY_SAFE are resolved.
# ==============================================================================

_tavs_mute_gate_init() {
    _tavs_resolve_runtime_dir
    _tavs_validate_mute_liveness

    if [[ "${_TAVS_SUPPRESS_OUTPUT:-0}" == "1" ]]; then
        _tavs_debug_mute "MUTED: tty=${TTY_SAFE:-}"
    fi
}
