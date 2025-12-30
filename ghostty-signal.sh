#!/bin/bash
# ==============================================================================
# Ghostty Visual Signal Controller for Claude Code
# ==============================================================================
#
# Changes Ghostty terminal background color and tab title based on Claude Code
# state, making it easy to identify which terminals need attention.
#
# Repository: https://github.com/cstelmach/ghostty-claude-signals
# License:    MIT
#
# Requirements:
#   - Ghostty terminal (v1.0+)
#   - Claude Code CLI
#   - Bash 3.2+ (macOS default)
#
# Usage: ghostty-signal.sh {permission|idle|complete|processing|reset}
#
# Performance: Optimized to spawn ~1 external process (vs ~12-15 previously)
#              using bash builtins and parameter expansion.
# ==============================================================================

# === CONFIGURATION ===
ENABLE_BACKGROUND_CHANGE=true
ENABLE_TITLE_PREFIX=true

ENABLE_PROCESSING=true
ENABLE_PERMISSION=true
ENABLE_COMPLETE=false
ENABLE_IDLE=false

COLOR_PROCESSING="#473D2F"
COLOR_PERMISSION="#4A2021"
COLOR_COMPLETE="#2B4636"
COLOR_IDLE="#3E3046"

EMOJI_PROCESSING="🟠"
EMOJI_PERMISSION="🔴"
EMOJI_COMPLETE="🟢"
EMOJI_IDLE="🟣"

# === TTY RESOLUTION (optimized) ===
# Uses $PPID built-in instead of ps -o ppid= call
tty_device=$(ps -o tty= -p $PPID 2>/dev/null)
tty_device="${tty_device// /}"  # Remove spaces with parameter expansion (no tr)

if [[ -n "$tty_device" && "$tty_device" != "??" && "$tty_device" != "-" ]]; then
    [[ "$tty_device" != /dev/* ]] && tty_device="/dev/$tty_device"
    [[ -w "$tty_device" ]] && TTY_DEVICE="$tty_device"
fi

# Fallback to /dev/tty (test actual write, not just -w flag)
[[ -z "$TTY_DEVICE" ]] && { echo -n "" > /dev/tty; } 2>/dev/null && TTY_DEVICE="/dev/tty"

# Exit silently if no TTY
[[ -z "$TTY_DEVICE" ]] && exit 0

# === HELPER: Get short CWD (optimized - no external commands) ===
get_short_cwd() {
    local cwd="$PWD"
    cwd="${cwd/#$HOME/\~}"

    # Count slashes with pure bash (no tr/wc pipeline)
    local tmp="${cwd//[!\/]/}"
    local slash_count=${#tmp}

    if [[ "$slash_count" -gt 2 ]]; then
        # Get parent and base with parameter expansion (no basename/dirname)
        local parent="${cwd%/*}"
        parent="${parent##*/}"
        local base="${cwd##*/}"
        cwd="…/$parent/$base"
    fi
    echo "$cwd"
}

# === MAIN LOGIC ===
STATE="${1:-}"

case "$STATE" in
    processing)
        if [[ "$ENABLE_PROCESSING" == "true" ]]; then
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]11;%s\007" "$COLOR_PROCESSING" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s %s\007" "$EMOJI_PROCESSING" "$(get_short_cwd)" > "$TTY_DEVICE"
        else
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]111\007" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s\007" "$(get_short_cwd)" > "$TTY_DEVICE"
        fi
        ;;
    permission)
        if [[ "$ENABLE_PERMISSION" == "true" ]]; then
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]11;%s\007" "$COLOR_PERMISSION" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s %s\007" "$EMOJI_PERMISSION" "$(get_short_cwd)" > "$TTY_DEVICE"
        fi
        # Permission fallback: do nothing (stay in current state)
        ;;
    complete)
        if [[ "$ENABLE_COMPLETE" == "true" ]]; then
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]11;%s\007" "$COLOR_COMPLETE" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s %s\007" "$EMOJI_COMPLETE" "$(get_short_cwd)" > "$TTY_DEVICE"
        else
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]111\007" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s\007" "$(get_short_cwd)" > "$TTY_DEVICE"
        fi
        ;;
    idle)
        if [[ "$ENABLE_IDLE" == "true" ]]; then
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]11;%s\007" "$COLOR_IDLE" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s %s\007" "$EMOJI_IDLE" "$(get_short_cwd)" > "$TTY_DEVICE"
        else
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]111\007" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s\007" "$(get_short_cwd)" > "$TTY_DEVICE"
        fi
        ;;
    reset)
        [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]111\007" > "$TTY_DEVICE"
        [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s\007" "$(get_short_cwd)" > "$TTY_DEVICE"
        ;;
    *)
        echo "Usage: $0 {permission|idle|complete|processing|reset}" >&2
        exit 1
        ;;
esac

exit 0
