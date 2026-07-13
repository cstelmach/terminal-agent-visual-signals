#!/bin/bash
# ==============================================================================
# TAVS CLI — lock command (hard lock, spec D3/D6/D7)
# ==============================================================================
# Usage:
#   tavs lock now [--for <duration>]   Engage a manual hard lock (default 1h)
#   tavs lock status                   Show lock state and remaining time
#
# The lock projection lives in /tmp/tavs-$UID/lock.state: cleared by reboot
# (D6), honored by the shell fail-closed until its FINITE expiry regardless
# of app liveness (D3). Engaging is never challenge-gated; only unlocking is.
# ==============================================================================

source "$CLI_DIR/cli-utils.sh"
source "$TAVS_ROOT/src/core/lock-state-lib.sh"

# Parses "15m", "2h", "2h30m", "1d" (units d/h/m, any combination) to seconds.
_lock_parse_duration() {
    local spec="$1"
    [[ "$spec" =~ ^([0-9]+[dhm])+$ ]] || return 1
    local total=0 rest="$spec"
    while [[ "$rest" =~ ^([0-9]+)([dhm])(.*)$ ]]; do
        local n="${BASH_REMATCH[1]}" u="${BASH_REMATCH[2]}"
        rest="${BASH_REMATCH[3]}"
        case "$u" in
            d) total=$(( total + n * 86400 )) ;;
            h) total=$(( total + n * 3600 )) ;;
            m) total=$(( total + n * 60 )) ;;
        esac
    done
    (( total > 0 )) || return 1
    echo "$total"
}

# Lock paint colors: the dark pause visual from user.conf, matching what the
# app would broadcast (PauseVisualResolver reads the same keys).
_lock_resolve_colors() {
    _LOCK_BG="" _LOCK_FG=""
    local conf="$HOME/.tavs/user.conf" k v
    if [[ -r "$conf" ]]; then
        while IFS='=' read -r k v; do
            v="${v%\"}"; v="${v#\"}"
            case "$k" in
                TAVS_PAUSE_BG_DARK) _LOCK_BG="$v" ;;
                TAVS_PAUSE_FG_DARK) _LOCK_FG="$v" ;;
            esac
        done < "$conf"
    fi
    # NOTE: plain `[[ ... ]] && ...` as the last command would return 1 when
    # the guard is false and kill the set -e dispatcher.
    if [[ -z "$_LOCK_BG" ]]; then
        _LOCK_BG="#3A3A3A"
    fi
    return 0
}

_lock_format_until() {
    date -r "$1" '+%H:%M' 2>/dev/null || echo "?"
}

_lock_now() {
    local duration_spec="1h"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --for)
                shift
                duration_spec="${1:-}"
                [[ -z "$duration_spec" ]] && { cli_error "--for requires a duration (e.g. 2h30m)"; return 1; }
                ;;
            *)
                cli_error "Unknown option: $1"
                return 1
                ;;
        esac
        shift
    done

    local seconds
    if ! seconds=$(_lock_parse_duration "$duration_spec"); then
        cli_error "Invalid duration: '$duration_spec' (use e.g. 15m, 2h, 2h30m, 1d)"
        return 1
    fi

    local now new_until
    now=$(date +%s)
    new_until=$(( now + seconds ))

    # Merge (spec 2.2): an existing unexpired lock keeps the LATER end;
    # engaging a lock always cancels any active unlock grant.
    if _tavs_lock_read && [[ "$_LS_LOCKED" == "true" ]] \
        && [[ -n "$_LS_LOCK_UNTIL" && "$_LS_LOCK_UNTIL" != *[!0-9]* ]] \
        && (( _LS_LOCK_UNTIL > new_until )) && (( _LS_LOCK_UNTIL > now )); then
        new_until="$_LS_LOCK_UNTIL"
    fi

    _lock_resolve_colors
    if ! _tavs_lock_write "true" "manual" "$new_until" "0" "$_LOCK_BG" "$_LOCK_FG"; then
        cli_error "Could not write lock state"
        return 1
    fi

    cli_success "Hard lock engaged until $(_lock_format_until "$new_until")"
    if pgrep -x TAVSApp &>/dev/null; then
        cli_info "TAVS.app will paint all registered terminals within a second."
    else
        cli_info "TAVS.app is not running: new terminals still paint via the shell"
        cli_info "integration; already-open ones keep their current look."
    fi
    cli_info "Unlock (challenge required): tavs unlock"
}

_lock_status() {
    local now
    now=$(date +%s)
    if ! _tavs_lock_read; then
        echo "Lock: none (no lock.state)"
        return 0
    fi

    echo "Lock state ($(_tavs_lock_state_file)):"
    echo "  LOCKED:       ${_LS_LOCKED:-?}"
    echo "  REASON:       ${_LS_REASON:-?}"
    if [[ -n "$_LS_LOCK_UNTIL" && "$_LS_LOCK_UNTIL" != *[!0-9]* ]]; then
        if (( _LS_LOCK_UNTIL > now )); then
            echo "  LOCK_UNTIL:   $(_lock_format_until "$_LS_LOCK_UNTIL") ($(( (_LS_LOCK_UNTIL - now + 59) / 60 )) min remaining)"
        else
            echo "  LOCK_UNTIL:   expired"
        fi
    else
        echo "  LOCK_UNTIL:   invalid (${_LS_LOCK_UNTIL:-empty}) — treated as not locked"
    fi
    if [[ -n "$_LS_UNLOCK_UNTIL" && "$_LS_UNLOCK_UNTIL" != "0" && "$_LS_UNLOCK_UNTIL" != *[!0-9]* ]] && (( _LS_UNLOCK_UNTIL > now )); then
        echo "  GRANT:        active until $(_lock_format_until "$_LS_UNLOCK_UNTIL")"
    fi

    if _tavs_lock_effective "$now"; then
        cli_info "Effective: LOCKED"
    else
        cli_info "Effective: not locked"
    fi
}

cmd_lock() {
    local subcmd="${1:-}"

    if [[ "$subcmd" == "--help" || "$subcmd" == "-h" || -z "$subcmd" ]]; then
        cat <<'EOF'
tavs lock — Manual hard lock (visual commitment device)

Usage:
  tavs lock now [--for <duration>]   Engage a hard lock (default: 1h)
  tavs lock status                   Show current lock state

Durations: 15m, 2h, 2h30m, 1d (units d/h/m in any combination).

A hard lock mutes agent signals and paints every registered terminal with the
pause visual plus a 🔒 title. It stays in force until its end time even if
TAVS.app is killed (fail-closed). It does NOT survive a reboot. Unlocking
early requires the challenge: tavs unlock [--for <duration>].
EOF
        return 0
    fi

    case "$subcmd" in
        now)
            shift
            _lock_now "$@"
            ;;
        status)
            shift
            _lock_status "$@"
            ;;
        *)
            cli_error "Unknown subcommand: $subcmd"
            cli_info "Usage: tavs lock now [--for <duration>] | tavs lock status"
            return 1
            ;;
    esac
}
