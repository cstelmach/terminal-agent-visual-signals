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
source "$TAVS_ROOT/src/core/challenge.sh"

# Parses "15m", "2h", "2h30m", "1d" (units d/h/m, any combination) to seconds.
_lock_parse_duration() {
    local spec="$1"
    [[ "$spec" =~ ^([0-9]+[dhm])+$ ]] || return 1
    local total=0 rest="$spec"
    while [[ "$rest" =~ ^([0-9]+)([dhm])(.*)$ ]]; do
        local n="${BASH_REMATCH[1]}" u="${BASH_REMATCH[2]}" multiplier
        rest="${BASH_REMATCH[3]}"
        n=$(_tavs_policy_decimal "$n") || return 1
        case "$u" in
            d) multiplier=86400 ;;
            h) multiplier=3600 ;;
            m) multiplier=60 ;;
        esac
        (( n <= (9223372036854775807 - total) / multiplier )) || return 1
        total=$(( total + n * multiplier ))
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
    now=$(_tavs_policy_decimal "$(date +%s)") || { cli_error "Current time unavailable"; return 1; }
    if (( seconds > 9223372036854775807 - now )); then
        cli_error "Duration exceeds supported end time"
        return 1
    fi
    new_until=$(( now + seconds ))

    _lock_resolve_colors
    if [[ "$(uname -s)" == Darwin ]]; then
        if ! new_until=$(_tavs_lock_native_update now "$new_until" "$_LOCK_BG" "$_LOCK_FG"); then
            cli_error "Could not write lock state"
            return 1
        fi
    else
        if ! _tavs_lock_read && [[ "$_LS_READ_STATUS" != absent ]]; then
            cli_error "Lock state unavailable; saved lock preserved."
            return 1
        fi
        local previous_until
        if [[ "$_LS_LOCKED" == true ]] \
            && previous_until=$(_tavs_policy_decimal "$_LS_LOCK_UNTIL") \
            && (( previous_until > new_until )); then
            new_until="$previous_until"
        fi
        if ! _tavs_lock_write true manual "$new_until" 0 "$_LOCK_BG" "$_LOCK_FG"; then
            cli_error "Could not write lock state"
            return 1
        fi
    fi

    if _tavs_visual_restrictions_suspended; then
        if [[ "$_TAVS_VISUAL_RESTRICTIONS_STATUS" == suspended ]]; then
            cli_success "Lock saved until $(_lock_format_until "$new_until"); visual restrictions are suspended."
            cli_info 'Saved rules apply after explicit resumption.'
        else
            cli_success "Lock saved until $(_lock_format_until "$new_until")."
            cli_info 'Visual restriction state unavailable; restrictive visuals disabled.'
        fi
        return 0
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
    local now lock_until grant_until remaining
    now=$(_tavs_policy_decimal "$(date +%s)") || { cli_error "Current time unavailable"; return 1; }
    _tavs_visual_restrictions_read
    case "$_TAVS_VISUAL_RESTRICTIONS_STATUS" in
        active) echo 'Visual restrictions: active.' ;;
        suspended) echo 'Visual restrictions: suspended; saved rules apply after explicit resumption.' ;;
        unavailable) echo 'Visual restriction state unavailable; restrictive visuals disabled.' ;;
    esac
    if ! _tavs_lock_read; then
        if [[ "$_LS_READ_STATUS" != absent ]]; then
            cli_error "Lock state unavailable; saved lock preserved."
            return 1
        fi
        echo "Lock: none (no lock.state)"
        return 0
    fi

    echo "Lock state ($(_tavs_lock_state_file)):"
    echo "  LOCKED:       ${_LS_LOCKED:-?}"
    echo "  REASON:       ${_LS_REASON:-?}"
    if lock_until=$(_tavs_policy_decimal "$_LS_LOCK_UNTIL"); then
        if (( lock_until > now )); then
            remaining=$(( lock_until - now ))
            echo "  LOCK_UNTIL:   $(_lock_format_until "$lock_until") ($(( remaining / 60 + (remaining % 60 != 0) )) min remaining)"
        else
            echo "  LOCK_UNTIL:   expired"
        fi
    else
        echo "  LOCK_UNTIL:   invalid (${_LS_LOCK_UNTIL:-empty}); treated as not locked"
    fi
    if grant_until=$(_tavs_policy_decimal "$_LS_UNLOCK_UNTIL") && (( grant_until > now )); then
        echo "  GRANT:        active until $(_lock_format_until "$grant_until")"
    fi

    if _tavs_lock_effective "$now"; then
        cli_info "Effective: LOCKED"
    elif [[ "$_LS_READ_STATUS" == unavailable ]]; then
        cli_error "Lock state unavailable; saved lock preserved."
        return 1
    else
        cli_info "Effective: not locked"
    fi
}

# Next local midnight ("rest of day" grant end).
_lock_next_midnight() {
    date -v+1d -v0H -v0M -v0S +%s 2>/dev/null
}

_lock_unlock() {
    local duration_spec=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --for)
                shift
                duration_spec="${1:-}"
                [[ -z "$duration_spec" ]] && { cli_error "--for requires a duration (e.g. 1h)"; return 1; }
                ;;
            *)
                cli_error "Unknown option: $1"
                return 1
                ;;
        esac
        shift
    done

    local now
    now=$(_tavs_policy_decimal "$(date +%s)") || { cli_error "Current time unavailable"; return 1; }
    if ! _tavs_lock_effective "$now"; then
        case "$_TAVS_VISUAL_RESTRICTIONS_STATUS" in
            suspended) cli_info 'Visual restrictions are suspended; the saved lock is preserved without an unlock.' ;;
            unavailable) cli_info 'Visual restriction state unavailable; restrictive visuals disabled and the saved lock is preserved.' ;;
            active)
                if [[ "$_LS_READ_STATUS" == unavailable ]]; then
                    cli_error "Lock state unavailable; saved lock preserved."
                    return 1
                fi
                cli_info "No effective lock right now. Nothing to unlock."
                ;;
        esac
        return 0
    fi

    if ! _tavs_challenge_verify; then
        cli_error "Challenge failed. The lock stays."
        return 1
    fi

    local grant_until seconds=""
    if [[ -n "$duration_spec" ]]; then
        if [[ "$duration_spec" == "rest-of-day" ]]; then
            grant_until=$(_lock_next_midnight)
        else
            if ! seconds=$(_lock_parse_duration "$duration_spec"); then
                cli_error "Invalid duration: '$duration_spec' (use e.g. 15m, 2h30m, rest-of-day)"
                return 1
            fi
        fi
    else
        printf 'Unlock for:  1) 15m   2) 1h   3) 4h   4) rest of day\n' >&2
        printf 'Choice [1-4]: ' >&2
        local choice
        IFS= read -r choice || return 1
        case "$choice" in
            1) seconds=900 ;;
            2) seconds=3600 ;;
            3) seconds=14400 ;;
            4) grant_until=$(_lock_next_midnight) ;;
            *) cli_error "Invalid choice."; return 1 ;;
        esac
    fi

    if [[ -n "$seconds" ]]; then
        if (( seconds > 9223372036854775807 - now )); then
            cli_error "Duration exceeds supported end time"
            return 1
        fi
        grant_until=$(( now + seconds ))
    fi
    if ! grant_until=$(_tavs_policy_decimal "$grant_until") || (( grant_until <= now )); then
        cli_error "Could not compute the unlock end time."
        return 1
    fi

    # The challenge may take minutes; merge into the current state after it finishes.
    if [[ "$(uname -s)" == Darwin ]]; then
        if ! _LS_LOCK_UNTIL=$(_tavs_lock_native_update grant "$grant_until"); then
            cli_error "Could not write lock state"
            return 1
        fi
    else
        if ! _tavs_lock_read || ! _tavs_lock_write "$_LS_LOCKED" "$_LS_REASON" \
            "$_LS_LOCK_UNTIL" "$grant_until" "$_LS_BG" "$_LS_FG"; then
            cli_error "Could not write lock state"
            return 1
        fi
    fi

    cli_success "Unlocked until $(_lock_format_until "$grant_until")."
    local lock_until
    if lock_until=$(_tavs_policy_decimal "$_LS_LOCK_UNTIL") && (( lock_until > grant_until )); then
        cli_info "The lock re-engages automatically at $(_lock_format_until "$grant_until")."
    fi
    if ! pgrep -x TAVSApp &>/dev/null; then
        cli_info "TAVS.app is not running: painted terminals clear on their next repaint."
    fi
    return 0
}

_lock_set_password() {
    local challenge_type="password"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)
                shift
                challenge_type="${1:-}"
                case "$challenge_type" in
                    password|both) ;;
                    *) cli_error "--type must be 'password' or 'both'"; return 1 ;;
                esac
                ;;
            *)
                cli_error "Unknown option: $1"
                return 1
                ;;
        esac
        shift
    done

    local p1 p2
    printf 'New unlock password: ' >&2
    IFS= read -rs p1 || return 1
    printf '\n' >&2
    printf 'Repeat password: ' >&2
    IFS= read -rs p2 || return 1
    printf '\n' >&2

    if [[ -z "$p1" ]]; then
        cli_error "Password must not be empty."
        return 1
    fi
    if [[ "$p1" != "$p2" ]]; then
        cli_error "Passwords do not match."
        return 1
    fi

    local salt hash conf tmp
    salt=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')
    hash=$(_tavs_challenge_hash "$salt" "$p1")
    conf="$HOME/.tavs/challenge.conf"
    mkdir -p "$HOME/.tavs"
    tmp=$(mktemp "$HOME/.tavs/.challenge.XXXXXX") || return 1
    {
        printf 'CHALLENGE_TYPE="%s"\n' "$challenge_type"
        printf 'PASSWORD_SALT_HEX="%s"\n' "$salt"
        printf 'PASSWORD_HASH_HEX="%s"\n' "$hash"
        printf 'PUZZLE_SENTENCES_FILE=""\n'
        printf 'SCHEMA_VERSION="1"\n'
    } > "$tmp"
    chmod 600 "$tmp"
    mv -f "$tmp" "$conf"

    cli_success "Unlock challenge set (type: $challenge_type)."
    if [[ "$challenge_type" == "both" ]]; then
        cli_info "Unlocking now requires the password AND the typing puzzle."
    fi
    cli_info "Deleting ~/.tavs/challenge.conf falls back to the typing puzzle."
    return 0
}

cmd_lock() {
    local subcmd="${1:-}"

    if [[ "$subcmd" == "--help" || "$subcmd" == "-h" || -z "$subcmd" ]]; then
        cat <<'EOF'
tavs lock — Manual hard lock (visual commitment device)

Usage:
  tavs lock now [--for <duration>]      Engage a hard lock (default: 1h)
  tavs lock status                      Show current lock state
  tavs lock unlock [--for <duration>]   Challenge-gated, time-boxed unlock
                                        (also: tavs unlock)
  tavs lock set-password [--type both]  Set the unlock password (default type
                                        'password'; 'both' adds the puzzle)

Durations: 15m, 2h, 2h30m, 1d (units d/h/m), plus 'rest-of-day' for unlock.

A hard lock mutes agent signals and paints every registered terminal with the
pause visual plus a 🔒 title. It stays in force until its end time even if
TAVS.app is killed (fail-closed). It does NOT survive a reboot. Unlocking
early requires the challenge; without a configured password the challenge is
a typing puzzle (retype a sentence with each word's first letter moved to
the word's end). After the unlock grant expires the lock re-engages.
Persistent visual suspension keeps saved locks inert until explicit resumption.
While suspended or unavailable, unlocking needs no challenge and preserves the saved lock.
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
        unlock)
            shift
            _lock_unlock "$@"
            ;;
        set-password)
            shift
            _lock_set_password "$@"
            ;;
        *)
            cli_error "Unknown subcommand: $subcmd"
            cli_info "Usage: tavs lock now|status|unlock|set-password (see tavs lock --help)"
            return 1
            ;;
    esac
}
