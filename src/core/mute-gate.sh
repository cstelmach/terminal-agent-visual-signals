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
# because it runs before any source statement. Epoch comparison needs
# date +%s which is an external command. Stage-1 runs during the normal
# source pass (~57ms baseline) where one fork is negligible.
# ==============================================================================

_tavs_validate_mute_liveness() {
    [[ "${_TAVS_SUPPRESS_OUTPUT:-0}" != "1" ]] && return 0

    local now
    now=$(date +%s)

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
    local log="/tmp/tavs-mute-trace.log"
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
