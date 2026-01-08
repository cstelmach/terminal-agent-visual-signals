#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Themes - Terminal Interaction
# ==============================================================================
# Handles low-level OSC escape sequences and TTY detection.
# ==============================================================================

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
    [[ -z "$TTY_DEVICE" ]] && return
    
    if [[ -n "$emoji" ]]; then
        printf "\033]0;%s %s\033\\" "$emoji" "$text" > "$TTY_DEVICE"
    else
        printf "\033]0;%s\033\\" "$text" > "$TTY_DEVICE"
    fi
}

# === UTILS ===

sanitize_for_terminal() {
    local input="$1"
    # Remove ASCII control characters
    printf '%s' "${input//[$'\x00'-$'\x1f'$'\x7f']/}"
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
