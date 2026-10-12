#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — Terminal Interaction
# ==============================================================================
# Handles low-level OSC escape sequences and TTY detection.
# ==============================================================================

# Source face themes for anthropomorphising feature
TERMINAL_SH_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$TERMINAL_SH_DIR/organizer-state.sh"
# Note: themes.sh kept for backward compatibility, agent-theme.sh provides get_random_face()
source "$TERMINAL_SH_DIR/themes.sh"

# === BELL CONFIGURATION ===
BELL_ON_PROCESSING=false
BELL_ON_PERMISSION=true
BELL_ON_COMPLETE=true
BELL_ON_IDLE=false
BELL_ON_COMPACTING=false
BELL_ON_RESET=false
BELL_ON_SUBAGENT=false
BELL_ON_TOOL_ERROR=false

# Send audible bell if enabled for the state
send_bell_if_enabled() {
    local state="$1"
    local should_bell=false
    case "$state" in
        processing)  [[ "$BELL_ON_PROCESSING" == "true" ]] && should_bell=true ;;
        permission)  [[ "$BELL_ON_PERMISSION" == "true" ]] && should_bell=true ;;
        complete)    [[ "$BELL_ON_COMPLETE" == "true" ]] && should_bell=true ;;
        idle)        [[ "$BELL_ON_IDLE" == "true" ]] && should_bell=true ;;
        compacting)  [[ "$BELL_ON_COMPACTING" == "true" ]] && should_bell=true ;;
        reset)       [[ "$BELL_ON_RESET" == "true" ]] && should_bell=true ;;
        subagent)    [[ "$BELL_ON_SUBAGENT" == "true" ]] && should_bell=true ;;
        tool_error)  [[ "$BELL_ON_TOOL_ERROR" == "true" ]] && should_bell=true ;;
    esac
    [[ "$should_bell" == "true" ]] && _tavs_render_queue bell
}

# === TTY RESOLUTION ===
resolve_tty() {
    # Walk up the process ancestry to find a TTY.
    # Hook processes often have an intermediate shell (no TTY) between
    # them and the CLI agent that owns the terminal. Claude Code uses 1
    # intermediate level; other agents (Gemini, Codex, OpenCode) may nest
    # deeper. 5 is the empirically sufficient cap: enough headroom for
    # realistic wrappers, low enough to bound ps(1) invocations.
    local p=$PPID tty_dev i=0
    while (( i < 5 )); do
        tty_dev=$(ps -o tty= -p $p 2>/dev/null)
        tty_dev="${tty_dev// /}"
        if [[ -n "$tty_dev" && "$tty_dev" != "??" && "$tty_dev" != "-" ]]; then
            [[ "$tty_dev" != /dev/* ]] && tty_dev="/dev/$tty_dev"
            [[ -w "$tty_dev" ]] && echo "$tty_dev" && return 0
        fi
        p=$(ps -o ppid= -p $p 2>/dev/null)
        p="${p// /}"
        [[ -z "$p" || "$p" == "0" || "$p" == "1" ]] && break
        (( i++ ))
    done

    if { echo -n "" > /dev/tty; } 2>/dev/null; then
        echo "/dev/tty"
        return 0
    fi
    return 1
}

# Auto-detect TTY on source if not already set
if [[ -z "${TTY_DEVICE:-}" ]]; then
    TTY_DEVICE=$(resolve_tty || true)
    # If still empty, we can't do anything (exit handled by caller usually)
fi

# Create safe identifier for filenames
if [[ -n "${TTY_DEVICE:-}" ]]; then
    TTY_SAFE="${TTY_DEVICE//\//_}"
fi

# === OSC COMMANDS ===

# Send OSC 11 (background color)
send_osc_bg() {
    local color="$1"
    [[ -z "$TTY_DEVICE" ]] && return
    local result=0
    _tavs_render_queue background "$color" || result=$?
    [[ "$result" == 3 ]] && return 0
    return "$result"
}

# === OSC 4 PALETTE COMMANDS ===
# OSC 4 modifies the terminal's 16-color ANSI palette.
# This affects applications that use palette indices (256-color mode).
# Note: TrueColor (24-bit RGB) applications bypass the palette entirely.

# Queue typed palette colors for one managed render.
# Usage: send_osc_palette "dark" or send_osc_palette "light"
# Palette colors are read from PALETTE_DARK_0..15 or PALETTE_LIGHT_0..15
send_osc_palette() {
    local mode="$1"
    [[ -z "$TTY_DEVICE" ]] && return

    local mode_upper var_name color i has_colors=0
    local colors=()
    mode_upper=$(printf '%s' "$mode" | tr '[:lower:]' '[:upper:]')
    for ((i=0; i<16; i++)); do
        var_name="PALETTE_${mode_upper}_${i}"
        color="${!var_name}"
        colors[i]="$color"
        [[ -n "$color" ]] && has_colors=1
    done
    [[ "$has_colors" == 1 ]] && _tavs_render_queue palette set "${colors[@]}"
}

# Reset palette to terminal defaults (OSC 104)
send_osc_palette_reset() {
    [[ -z "$TTY_DEVICE" ]] && return
    _tavs_render_queue palette reset
}

send_osc_title() {
    local status_icon="$1"
    local text="$2"
    local state="${3:-}"
    [[ -z "$TTY_DEVICE" ]] && return

    local title=""
    local face=""

    # Handle processing state with spinner when TAVS_TITLE_MODE="full"
    if [[ "$state" == "processing" && "$TAVS_TITLE_MODE" == "full" ]]; then
        # Get spinner eyes (requires spinner.sh to be sourced)
        local spinner_result=""
        if type get_spinner_eyes &>/dev/null; then
            spinner_result=$(get_spinner_eyes)
        fi

        if [[ "$spinner_result" == "FACE_VARIANT" ]]; then
            # "none" style - use existing face selection
            if [[ "$ENABLE_ANTHROPOMORPHISING" == "true" ]]; then
                if type get_random_face &>/dev/null; then
                    face=$(get_random_face "$state")
                fi
                title="$status_icon $face $text"
            else
                title="$status_icon $text"
            fi
        elif [[ -n "$spinner_result" && "$ENABLE_ANTHROPOMORPHISING" == "true" ]]; then
            # With face: build face with spinner eyes using agent-specific frame
            # SPINNER_FACE_FRAME is resolved per-agent (e.g., "Ǝ[{L} {R}]E" for Claude)
            # {L} and {R} are placeholders for left and right spinner eyes
            local left_eye="${spinner_result%% *}"
            local right_eye="${spinner_result##* }"
            local frame="${SPINNER_FACE_FRAME:-[{L} {R}]}"
            # Substitute placeholders with spinner eyes
            face="${frame//\{L\}/$left_eye}"
            face="${face//\{R\}/$right_eye}"
            if [[ "$FACE_POSITION" == "before" ]]; then
                title="$face $status_icon $text"
            else
                title="$status_icon $face $text"
            fi
        elif [[ -n "$spinner_result" ]]; then
            # No face (ENABLE_ANTHROPOMORPHISING=false): just spinner + path
            # Extract first eye character for single spinner
            local single_spinner="${spinner_result%% *}"
            title="$status_icon $single_spinner $text"
        else
            # Fallback if spinner not available
            title="$status_icon $text"
        fi
    else
        # Non-processing states OR skip-processing mode - use normal face selection
        if [[ "$ENABLE_ANTHROPOMORPHISING" == "true" && -n "$state" ]]; then
            # Use new agent-specific random face system if available, else fall back to legacy
            if type get_random_face &>/dev/null; then
                face=$(get_random_face "$state")
            elif type get_face &>/dev/null; then
                face=$(get_face "${FACE_THEME:-minimal}" "$state")
            fi
        fi

        # Compose title based on what's available
        if [[ -n "$status_icon" && -n "$face" ]]; then
            if [[ "$FACE_POSITION" == "before" ]]; then
                title="$face $status_icon $text"
            else
                title="$status_icon $face $text"
            fi
        elif [[ -n "$face" ]]; then
            title="$face $text"
        elif [[ -n "$status_icon" ]]; then
            title="$status_icon $text"
        else
            title="$text"
        fi
    fi

    _tavs_render_queue title "$title"
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
