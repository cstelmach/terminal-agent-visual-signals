#!/bin/bash
# ==============================================================================
# TAVS — Shell Integration (installed to ~/.tavs/shellrc)
# ==============================================================================
# Sourced by interactive zsh/bash via the fenced block that
# `tavs install shell-integration` appends to ~/.zshrc / ~/.bashrc.
#
# Responsibilities, in cost order (builtins-first):
#   1. Register this terminal's TTY in /tmp/tavs-$UID/active-ttys/ so the
#      TAVS.app broadcaster reaches EVERY terminal, not just agent sessions.
#   2. Self-paint the lock/pause visual at shell open, so terminals opened
#      DURING a lock or pause are correct immediately without a broadcast.
#
# Paint goes to stdout: during rc sourcing of an interactive shell stdout is
# the terminal, and unlike hook contexts there is no redirection in play.
#
# Cost budget: <1ms when no state files exist (the common case). Worst case
# two forks in bash (tty + date); zero forks in zsh (zsh/datetime module).
# Must stay source-compatible with BOTH zsh and bash 3.2.
# ==============================================================================

[[ -n "${ZSH_VERSION:-}" ]] && zmodload zsh/datetime 2>/dev/null

_tavs_shellrc_main() {
    # Interactive shells only.
    case "$-" in *i*) ;; *) return 0 ;; esac

    # Kill switch: same disabled values as trigger.sh, matched case-insensitively
    # with builtins (no tr fork).
    case "${TAVS_STATUS:-}" in
        [Ff][Aa][Ll][Ss][Ee]|0|[Oo][Ff][Ff]|[Nn][Oo]|[Dd][Ii][Ss][Aa][Bb][Ll][Ee][Dd])
            return 0 ;;
    esac

    # --- TTY resolution: zsh exports $TTY; bash needs one tty(1) fork -------
    local _tty="${TTY:-}"
    if [[ -z "$_tty" ]]; then
        _tty=$(tty 2>/dev/null) || return 0
    fi
    [[ "$_tty" == /dev/* ]] || return 0
    local _tty_safe="${_tty//\//_}"

    # --- Register in the active-ttys registry (mtime is the liveness signal) -
    local _rt="${TAVS_RUNTIME_DIR:-/tmp/tavs-${UID}}"
    if [[ ! -d "$_rt/active-ttys" ]]; then
        command mkdir -m 0700 -p "$_rt" 2>/dev/null || return 0
        command mkdir -p "$_rt/active-ttys" 2>/dev/null || return 0
    fi
    : >| "$_rt/active-ttys/$_tty_safe" 2>/dev/null

    # --- Read lock.state (builtins only; absent/malformed = unlocked, D3) ---
    local _locked="" _lock_until="" _unlock_until="" _lock_bg="" _lock_fg="" _lock_ver=""
    local _k _v
    if [[ -r "$_rt/lock.state" ]]; then
        while IFS='=' read -r _k _v; do
            _v="${_v%\"}"; _v="${_v#\"}"
            case "$_k" in
                LOCKED)             _locked="$_v" ;;
                LOCK_UNTIL_EPOCH)   _lock_until="$_v" ;;
                UNLOCK_UNTIL_EPOCH) _unlock_until="$_v" ;;
                LOCK_BG)            _lock_bg="$_v" ;;
                LOCK_FG)            _lock_fg="$_v" ;;
                SCHEMA_VERSION)     _lock_ver="$_v" ;;
            esac
        done < "$_rt/lock.state"
    fi

    # --- Read mute.state (soft pause; fail-open exactly like the hook gate) -
    local _muted="" _m_until="" _m_written="" _m_pid="" _m_ver="" _pause_bg="" _pause_fg=""
    if [[ -r "$HOME/.tavs/mute.state" ]]; then
        while IFS='=' read -r _k _v; do
            _v="${_v%\"}"; _v="${_v#\"}"
            case "$_k" in
                MUTED)          _muted="$_v" ;;
                UNTIL_EPOCH)    _m_until="$_v" ;;
                WRITTEN_EPOCH)  _m_written="$_v" ;;
                APP_PID)        _m_pid="$_v" ;;
                SCHEMA_VERSION) _m_ver="$_v" ;;
                PAUSE_BG)       _pause_bg="$_v" ;;
                PAUSE_FG)       _pause_fg="$_v" ;;
            esac
        done < "$HOME/.tavs/mute.state"
    fi

    # Fast path: nothing to evaluate, nothing to paint.
    [[ "$_locked" != "true" && "$_muted" != "true" ]] && return 0

    # One time fetch: zsh/datetime EPOCHSECONDS (zero forks) or date(1).
    local _now="${EPOCHSECONDS:-}"
    [[ -z "$_now" ]] && _now=$(date +%s)

    # --- Effective-lock predicate (single definition, spec §2.2) ------------
    # effective := LOCKED && now < LOCK_UNTIL && !(now < UNLOCK_UNTIL)
    # Missing or non-numeric LOCK_UNTIL_EPOCH means NOT locked (no indefinite
    # locks, no heartbeat, no PID check: fail-closed against app death only
    # until the finite expiry).
    local _lock_effective=0
    if [[ "$_locked" == "true" && "${_lock_ver:-1}" == "1" ]]; then
        if [[ -n "$_lock_until" && "$_lock_until" != *[!0-9]* ]] && (( _now < _lock_until )); then
            _lock_effective=1
            if [[ -n "$_unlock_until" && "$_unlock_until" != *[!0-9]* ]] && (( _now < _unlock_until )); then
                _lock_effective=0
            fi
        fi
    fi

    if (( _lock_effective )); then
        local _until_hhmm=""
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            strftime -s _until_hhmm '%H:%M' "$_lock_until" 2>/dev/null
        else
            _until_hhmm=$(date -r "$_lock_until" +%H:%M 2>/dev/null)
        fi
        printf '\033]104\007'
        [[ -n "$_lock_fg" ]] && printf '\033]10;%s\007' "$_lock_fg"
        printf '\033]11;%s\007' "${_lock_bg:-#3A3A3A}"
        printf '\033]1337;SetBackgroundImageFile=\007'
        printf '\033]0;🔒 locked until %s\007' "$_until_hhmm"
        return 0
    fi

    # --- Soft pause paint: mirror the hook gate's validity rules ------------
    # (MUTED + schema 1 + live APP_PID + unexpired UNTIL + fresh heartbeat).
    [[ "$_muted" != "true" || "${_m_ver:-1}" != "1" ]] && return 0
    if [[ -n "$_m_pid" ]] && ! kill -0 "$_m_pid" 2>/dev/null; then
        return 0
    fi
    if [[ -n "$_m_until" && "$_m_until" != "0" && "$_m_until" != *[!0-9]* ]] && (( _m_until < _now )); then
        return 0
    fi
    if [[ -n "$_m_written" && "$_m_written" != *[!0-9]* ]] && (( _now - _m_written > 120 )); then
        return 0
    fi
    printf '\033]104\007'
    [[ -n "$_pause_fg" ]] && printf '\033]10;%s\007' "$_pause_fg"
    printf '\033]11;%s\007' "${_pause_bg:-#3A3A3A}"
    printf '\033]1337;SetBackgroundImageFile=\007'
    return 0
}

_tavs_shellrc_main
