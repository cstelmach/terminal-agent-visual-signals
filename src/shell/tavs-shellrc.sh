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
# The managed helper paints the resolved TTY under shared output serialization.
#
# Enabled active startup invokes capability, registration and current-policy helpers.
# Suspension omits current-policy. Bash may invoke tty; registry creation invokes mkdir.
# Latency depends on helper startup and cached targets, including when no rules exist.
# Must stay source-compatible with BOTH zsh and bash 3.2.
# ==============================================================================

[[ -n "${ZSH_VERSION:-}" ]] && zmodload zsh/datetime 2>/dev/null

# The installed shellrc is standalone; keep these readers identical to the core module.
_tavs_visual_restrictions_read() {
    local file="${1:-$HOME/.tavs/visual-restrictions.state}" data="" full=0
    _TAVS_VISUAL_RESTRICTIONS_STATUS=unavailable
    [[ "$file" == /* ]] || return 0
    if [[ ! -e "$file" && ! -L "$file" ]]; then
        local parent="${file%/*}"
        [[ -n "$parent" ]] || parent=/
        while [[ ! -e "$parent" && ! -L "$parent" ]]; do
            parent="${parent%/*}"
            [[ -n "$parent" ]] || parent=/
        done
        if [[ -d "$parent" && -x "$parent" ]]; then
            _TAVS_VISUAL_RESTRICTIONS_STATUS=active
        fi
        return 0
    fi
    [[ -f "$file" && ! -L "$file" && -r "$file" ]] || return 0
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
    local helper support=""
    if [[ "${TAVS_TEST_HELPER_BIN+x}" == x ]]; then helper="$TAVS_TEST_HELPER_BIN"
    else helper=/Applications/TAVS.app/Contents/MacOS/TAVSApp
    fi
    if [[ -x "$helper" ]]; then
        support=$(env -u TAVS_SESSIONS_TEST_ROOT -u TAVS_SESSIONS_TEST_FIXTURE \
            -u TAVS_SESSIONS_TEST_TARGETS "$helper" --validate-config --managed-output-capabilities \
            2>/dev/null) || support=""
    fi
    [[ "$support" == tavs-managed-output-schema=1 ]] || return 1
    _TAVS_SHELLRC_MANAGED_HELPER="$helper"
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
    local _tty_safe="${_tty//\//_}"

    # --- Register in the active-ttys registry (mtime is the liveness signal) -
    local _rt="${TAVS_RUNTIME_DIR:-/tmp/tavs-${UID}}"
    if [[ ! -d "$_rt/active-ttys" ]]; then
        command mkdir -m 0700 -p "$_rt" 2>/dev/null || return 0
        command mkdir -p "$_rt/active-ttys" 2>/dev/null || return 0
    fi
    : >| "$_rt/active-ttys/$_tty_safe" 2>/dev/null

    if ! _tavs_shellrc_managed_helper; then
        printf 'tavs: managed output helper unavailable or unsupported.\n' >&2
        return 0
    fi
    # The native helper rechecks current policy and the opened TTY under one output lock.
    "$_TAVS_SHELLRC_MANAGED_HELPER" --managed-register "$HOME/.tavs/visual-restrictions.state" \
        "$_rt" "$_tty" "$$" >/dev/null || printf 'tavs: terminal registration unavailable.\n' >&2
    if _tavs_visual_restrictions_suspended; then
        if [[ "$_TAVS_VISUAL_RESTRICTIONS_STATUS" == unavailable ]]; then
            printf 'tavs: visual restriction state unavailable; restrictive visuals disabled.\n' >&2
        fi
        return 0
    fi
    "$_TAVS_SHELLRC_MANAGED_HELPER" --managed-current "$HOME/.tavs/visual-restrictions.state" \
        "$_rt" "$_tty" "$$" >/dev/null || printf 'tavs: current visual policy unavailable.\n' >&2
    return 0
}

_tavs_shellrc_main
