#!/bin/bash
# ==============================================================================
# TAVS - Shell Integration (installed to ~/.tavs/shellrc)
# ==============================================================================
# Sourced by interactive zsh/bash via the fenced block that
# `tavs install shell-integration` appends to ~/.zshrc / ~/.bashrc.
#
# Responsibilities:
#   1. Register this terminal's validated target binding through the managed helper
#      so broadcasts/recovery can reach plain shells without an agent observation.
#   2. Self-paint the lock/pause visual at shell open, so terminals opened
#      DURING a lock or pause are correct immediately without a broadcast.
#
# The managed helper paints the resolved TTY under shared output serialization.
#
# Enabled active startup selects one helper, then requests registration and current policy.
# Suspension omits current-policy. Bash may invoke tty; the helper owns all registration I/O.
# Latency depends on helper startup and cached targets, including when no rules exist.
# Must stay source-compatible with BOTH zsh and bash 3.2.
# ==============================================================================

[[ -n "${ZSH_VERSION:-}" ]] && zmodload zsh/datetime 2>/dev/null

# The installed shellrc is standalone; keep these readers identical to the core module.
_tavs_visual_restrictions_trusted() {
    local metadata owner mode kind="${2:-leaf}"
    case "$OSTYPE" in
        darwin*) metadata=$(stat -f '%u:%Op' "$1" 2>/dev/null) || return 1 ;;
        linux*) metadata=$(stat -c '%u:%a' "$1" 2>/dev/null) || return 1 ;;
        *) return 1 ;;
    esac
    owner="${metadata%%:*}" mode="${metadata#*:}"
    [[ -n "$owner" && "$owner" != *[!0-9]* && -n "$mode" && "$mode" != *[!0-7]* ]] || return 1
    case "$kind" in
        leaf) [[ "$owner" == "$EUID" ]] || return 1 ;;
        alias|system) [[ "$owner" == 0 ]] || return 1 ;;
        ancestor) [[ "$owner" == 0 || "$owner" == "$EUID" ]] || return 1 ;;
        *) return 1 ;;
    esac
    [[ "$kind" == alias ]] && return 0
    (( (8#$mode & 8#22) == 0 )) && return 0
    if [[ "$kind" == ancestor && "$owner" == 0 ]] && (( (8#$mode & 8#1000) != 0 )); then
        case "$OSTYPE:$1" in
            darwin*:/private/tmp|darwin*:/private/var/tmp|linux*:/tmp|linux*:/var/tmp) return 0 ;;
        esac
    fi
    return 1
}

# Match native directory trust, and use the checked physical spelling after system aliases.
_tavs_visual_restrictions_path() {
    local file="$1" create="${2:-0}" LC_ALL=C remaining current="" part kind missing=0 target
    local doubles="//" single="/"
    [[ "$file" == /* && "$file" != */ && "$file" != *[[:cntrl:]]* && ${#file} -le 4096 ]] || return 1
    while [[ "$file" == *"$doubles"* ]]; do file="${file//$doubles/$single}"; done
    case "$file/" in *'/./'*|*'/../'*) return 1 ;; esac
    remaining="${file%/*}"
    remaining="${remaining#/}"
    [[ -n "$remaining" ]] || return 1
    while [[ -n "$remaining" ]]; do
        part="${remaining%%/*}"
        if [[ "$remaining" == */* ]]; then remaining="${remaining#*/}"; else remaining=""; fi
        current="${current}/${part}"
        [[ "$missing" == 0 ]] || continue
        if [[ ! -e "$current" && ! -L "$current" ]]; then
            if [[ "$create" == 1 ]]; then
                (umask 077; mkdir "$current") 2>/dev/null || [[ -d "$current" ]] || return 1
            else
                missing=1
                continue
            fi
        fi
        kind=ancestor
        [[ -n "$remaining" ]] || kind=leaf
        if [[ -L "$current" ]]; then
            [[ "$kind" == ancestor && "$OSTYPE" == darwin* ]] || return 1
            case "$current" in /tmp|/var) ;; *) return 1 ;; esac
            _tavs_visual_restrictions_trusted "$current" alias || return 1
            target=$(readlink "$current" 2>/dev/null) || return 1
            [[ "$target" == "/private$current" || "$target" == "private$current" ]] || return 1
            [[ -d /private && ! -L /private && -x /private ]] || return 1
            _tavs_visual_restrictions_trusted /private system || return 1
            current="/private$current"
        fi
        [[ -d "$current" && ! -L "$current" && -x "$current" ]] || return 1
        _tavs_visual_restrictions_trusted "$current" "$kind" || return 1
    done
    printf '%s/%s' "$current" "${file##*/}"
}

_tavs_visual_restrictions_read() {
    local file="${1:-$HOME/.tavs/visual-restrictions.state}" data="" full=0 LC_ALL=C
    _TAVS_VISUAL_RESTRICTIONS_STATUS=unavailable
    file=$(_tavs_visual_restrictions_path "$file") || return 0
    if [[ ! -e "$file" && ! -L "$file" ]]; then
        _TAVS_VISUAL_RESTRICTIONS_STATUS=active
        return 0
    fi
    [[ -f "$file" && ! -L "$file" && -r "$file" ]] || return 0
    _tavs_visual_restrictions_trusted "$file" || return 0
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        IFS= read -r -k 128 -u 0 data < "$file" && full=1
    else
        IFS= read -r -d '' -n 128 data < "$file" && full=1
    fi
    [[ "$full" == 0 ]] || return 0
    case "$data" in
        $'SCHEMA_VERSION="1"\nSUSPENDED="true"\n') _TAVS_VISUAL_RESTRICTIONS_STATUS=suspended ;;
        $'SCHEMA_VERSION="1"\nSUSPENDED="false"\n') _TAVS_VISUAL_RESTRICTIONS_STATUS=active ;;
    esac
    return 0
}

_tavs_visual_restrictions_suspended() {
    _tavs_visual_restrictions_read
    # An unavailable marker cannot authorize restrictive painting.
    [[ "$_TAVS_VISUAL_RESTRICTIONS_STATUS" != active ]]
}


_tavs_shellrc_managed_helper() {
    local location selector
    if [[ -n "${BASH_VERSION:-}" ]]; then location="${BASH_SOURCE[0]}"
    else location="${(%):-%x}"
    fi
    [[ "$location" == */* ]] || location="./$location"
    case "${location##*/}" in
        tavs-shellrc.sh) selector="${location%/*}/../core/helper-selection.sh" ;;
        shellrc) selector="${location%/*}/shell-helper/helper-selection.sh" ;;
        *) return 1 ;;
    esac
    [[ -r "$selector" ]] || return 1
    source "$selector" || return 1
    _tavs_helper_select || return 1
    _TAVS_SHELLRC_MANAGED_HELPER="$_TAVS_HELPER_BIN"
}

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
    local _rt="${TAVS_RUNTIME_DIR:-/tmp/tavs-${UID}}"

    if ! _tavs_shellrc_managed_helper; then
        printf 'tavs: managed output helper unavailable or unsupported.\n' >&2
        return 0
    fi
    # The selected helper rechecks the opened TTY under the shared output lock.
    if ! _tavs_helper_call --managed-register "$HOME/.tavs/visual-restrictions.state" \
        "$_rt" "$_tty" "$$" >/dev/null; then
        printf 'tavs: terminal registration unavailable.\n' >&2
        return 0
    fi
    if _tavs_visual_restrictions_suspended; then
        if [[ "$_TAVS_VISUAL_RESTRICTIONS_STATUS" == unavailable ]]; then
            printf 'tavs: visual restriction state unavailable; restrictive visuals disabled.\n' >&2
        fi
        return 0
    fi
    _tavs_helper_call --managed-current "$HOME/.tavs/visual-restrictions.state" \
        "$_rt" "$_tty" "$$" >/dev/null || printf 'tavs: current visual policy unavailable.\n' >&2
    return 0
}

_tavs_shellrc_main
