#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Themes - Terminal Interaction
# ==============================================================================
# Handles low-level OSC escape sequences and TTY detection.
# ==============================================================================

# Source face themes for anthropomorphising feature
TERMINAL_SH_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Note: themes.sh kept for backward compatibility, agent-theme.sh provides get_random_face()
source "$TERMINAL_SH_DIR/themes.sh"

# === BELL CONFIGURATION ===
BELL_ON_PROCESSING=false
BELL_ON_PERMISSION=true
BELL_ON_COMPLETE=true
BELL_ON_IDLE=false
BELL_ON_COMPACTING=false
BELL_ON_RESET=false

# Send audible bell if enabled for the state
send_bell_if_enabled() {
    local state="$1"
    local should_bell=false
    case "$state" in
        processing) [[ "$BELL_ON_PROCESSING" == "true" ]] && should_bell=true ;;
        permission) [[ "$BELL_ON_PERMISSION" == "true" ]] && should_bell=true ;;
        complete)   [[ "$BELL_ON_COMPLETE" == "true" ]] && should_bell=true ;;
        idle)       [[ "$BELL_ON_IDLE" == "true" ]] && should_bell=true ;;
        compacting) [[ "$BELL_ON_COMPACTING" == "true" ]] && should_bell=true ;;
        reset)      [[ "$BELL_ON_RESET" == "true" ]] && should_bell=true ;;
    esac
    [[ "$should_bell" == "true" ]] && printf "\007" > "$TTY_DEVICE"
}

# === TTY RESOLUTION ===
resolve_tty() {
    # Uses $PPID built-in
    local tty_dev
    tty_dev=$(ps -o tty= -p $PPID 2>/dev/null)
    tty_dev="${tty_dev// /}"

    if [[ -n "$tty_dev" && "$tty_dev" != "??" && "$tty_dev" != "-" ]]; then
        [[ "$tty_dev" != /dev/* ]] && tty_dev="/dev/$tty_dev"
        [[ -w "$tty_dev" ]] && echo "$tty_dev" && return 0
    fi
    
    # Fallback to /dev/tty
    if { echo -n "" > /dev/tty; } 2>/dev/null; then
        echo "/dev/tty"
        return 0
    fi
    return 1
}

# Auto-detect TTY on source if not already set
if [[ -z "$TTY_DEVICE" ]]; then
    TTY_DEVICE=$(resolve_tty)
    # If still empty, we can't do anything (exit handled by caller usually)
fi

# Create safe identifier for filenames
if [[ -n "$TTY_DEVICE" ]]; then
    TTY_SAFE="${TTY_DEVICE//\//_}"
fi

# === OSC COMMANDS ===

send_osc_bg() {
    local color="$1"
    [[ -z "$TTY_DEVICE" ]] && return
    if [[ "$color" == "reset" ]]; then
        printf "\033]111\033\\" > "$TTY_DEVICE"
    else
        printf "\033]11;%s\033\\" "$color" > "$TTY_DEVICE"
    fi
}

send_osc_title() {
    local emoji="$1"
    local text="$2"
    local state="${3:-}"
    [[ -z "$TTY_DEVICE" ]] && return

    # Get face if anthropomorphising is enabled
    local face=""
    if [[ "$ENABLE_ANTHROPOMORPHISING" == "true" && -n "$state" ]]; then
        # Use new agent-specific random face system if available, else fall back to legacy
        if type get_random_face &>/dev/null; then
            face=$(get_random_face "$state")
        elif type get_face &>/dev/null; then
            face=$(get_face "${FACE_THEME:-minimal}" "$state")
        fi
    fi

    # Compose title based on what's available
    local title=""
    if [[ -n "$emoji" && -n "$face" ]]; then
        if [[ "$FACE_POSITION" == "before" ]]; then
            title="$face $emoji $text"
        else
            title="$emoji $face $text"
        fi
    elif [[ -n "$face" ]]; then
        title="$face $text"
    elif [[ -n "$emoji" ]]; then
        title="$emoji $text"
    else
        title="$text"
    fi

    printf "\033]0;%s\033\\" "$title" > "$TTY_DEVICE"
}

# === UTILS ===

sanitize_for_terminal() {
    local input="$1"
    # Remove ASCII control characters (0x00-0x1f and 0x7f)
    # Use tr for reliable control character removal
    printf '%s' "$input" | tr -d '\000-\037\177'
}

get_short_cwd() {
    local cwd
    cwd=$(sanitize_for_terminal "$PWD")
    cwd="${cwd/#$HOME/\~}"

    # Count slashes
    local tmp="${cwd//[!\/]/}"
    local slash_count=${#tmp}

    if [[ "$slash_count" -gt 2 ]]; then
        local parent="${cwd%/*}"
        parent="${parent##*/}"
        local base="${cwd##*/}"
        cwd="…/$parent/$base"
    fi
    echo "$cwd"
}
