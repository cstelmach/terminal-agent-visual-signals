#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Signals - Dynamic Color Calculation Module
# ==============================================================================
# Handles dynamic mode color calculations based on terminal background.
# Extracted from theme-config-loader.sh for modularization.
#
# Public functions:
#   initialize_dynamic_colors()      - Initialize session colors from terminal bg
#   load_session_colors_or_defaults() - Load session colors or use theme defaults
#   refresh_colors_if_needed()       - Refresh colors on mode change
#   get_effective_color()            - Get background color for a state
#
# Internal functions:
#   _source_colors_if_needed()       - Lazy load colors.sh
#   _source_detect_if_needed()       - Lazy load terminal-detection.sh
#
# Dependencies (from theme-config-loader.sh when sourced):
#   - _THEME_SCRIPT_DIR - path to core directory
#   - _detect_system_mode() - detect system dark/light mode
#   - _resolve_colors() - resolve color variables
#   - _build_stage_arrays() - build idle stage arrays
#   - clear_mode_cache() - clear mode detection cache
#   - COLOR_* variables - theme color values
#
# Dependencies (from other modules):
#   - colors.sh: hex_to_rgb, rgb_to_hex, is_dark_color, shift_hue, etc.
#   - terminal-detection.sh: query_terminal_bg_with_timeout, is_ssh_session, is_truecolor_mode
#   - session-state.sh: read_session_colors, write_session_colors, has_session_colors
# ==============================================================================

# ==============================================================================
# LAZY LOADING UTILITIES
# ==============================================================================

# Source color utilities if available
_source_colors_if_needed() {
    if ! type hex_to_rgb &>/dev/null; then
        local colors_script="${_THEME_SCRIPT_DIR:-$(dirname "$0")}/colors.sh"
        if [[ -f "$colors_script" ]]; then
            # shellcheck source=/dev/null
            source "$colors_script"
            return 0
        fi
        return 1
    fi
    return 0
}

# Source detection utilities if available
_source_detect_if_needed() {
    if ! type query_terminal_bg &>/dev/null; then
        local detect_script="${_THEME_SCRIPT_DIR:-$(dirname "$0")}/terminal-detection.sh"
        if [[ -f "$detect_script" ]]; then
            # shellcheck source=/dev/null
            source "$detect_script"
            return 0
        fi
        return 1
    fi
    return 0
}

# ==============================================================================
# DYNAMIC COLOR INITIALIZATION
# ==============================================================================

# Initialize dynamic session colors
# Called at session start to query terminal and calculate colors
# Usage: initialize_dynamic_colors [tty_device]
initialize_dynamic_colors() {
    local tty_device="${1:-$TTY_DEVICE}"

    # Only proceed if dynamic mode is enabled
    [[ "$THEME_MODE" != "dynamic" ]] && return 0

    # Ensure we have required utilities
    _source_colors_if_needed || {
        echo "Warning: colors.sh not available for dynamic mode" >&2
        return 1
    }
    _source_detect_if_needed || {
        echo "Warning: detect.sh not available for dynamic mode" >&2
        return 1
    }

    # Check if we should skip (SSH session with SSH disabled)
    if [[ "$DYNAMIC_DISABLE_SSH" == "true" ]] && is_ssh_session; then
        return 1
    fi

    # Query terminal background
    local base_color
    base_color=$(query_terminal_bg_with_timeout "$tty_device" "$DYNAMIC_QUERY_TIMEOUT")

    if [[ -z "$base_color" ]]; then
        # Query failed - use agent default base color
        base_color="$COLOR_BASE"
    fi

    # Determine if base is dark or light
    local is_dark="true"
    if ! is_dark_color "$base_color"; then
        is_dark="false"
    fi

    # Detect system mode for comparison
    local system_mode
    system_mode=$(_detect_system_mode)

    # Calculate state colors using hue-shift
    local color_proc color_perm color_comp color_idle color_compact color_subagent color_tool_error
    color_proc=$(shift_hue "$base_color" "$HUE_PROCESSING")
    color_perm=$(shift_hue "$base_color" "$HUE_PERMISSION")
    color_comp=$(shift_hue "$base_color" "$HUE_COMPLETE")
    color_idle=$(shift_hue "$base_color" "$HUE_IDLE")
    color_compact=$(shift_hue "$base_color" "$HUE_COMPACTING")
    color_subagent=$(shift_hue "$base_color" "${HUE_SUBAGENT:-50}")
    color_tool_error=$(shift_hue "$base_color" "${HUE_TOOL_ERROR:-15}")

    # Store in session colors
    if [[ -n "$TTY_SAFE" ]]; then
        write_session_colors "$TAVS_AGENT" "$base_color" "$is_dark" "$system_mode" \
            "$color_proc" "$color_perm" "$color_comp" "$color_idle" "$color_compact"
    fi

    # Update current COLOR_* variables with calculated values
    COLOR_BASE="$base_color"
    COLOR_PROCESSING="$color_proc"
    COLOR_PERMISSION="$color_perm"
    COLOR_COMPLETE="$color_comp"
    COLOR_IDLE="$color_idle"
    COLOR_COMPACTING="$color_compact"
    COLOR_SUBAGENT="$color_subagent"
    COLOR_TOOL_ERROR="$color_tool_error"
    IS_DARK_THEME="$is_dark"

    # Rebuild stage arrays with new colors
    _build_stage_arrays

    return 0
}

# ==============================================================================
# SESSION COLOR LOADING
# ==============================================================================

# Load session colors if available, otherwise use theme defaults
# Returns 0 if session colors were loaded, 1 if using defaults
load_session_colors_or_defaults() {
    # Source session-state.sh if needed for session color functions
    if ! type read_session_colors &>/dev/null; then
        local state_script="${_THEME_SCRIPT_DIR:-$(dirname "$0")}/session-state.sh"
        if [[ -f "$state_script" ]]; then
            # shellcheck source=/dev/null
            source "$state_script"
        fi
    fi

    # Try to load session colors
    if type has_session_colors &>/dev/null && has_session_colors && read_session_colors; then
        # Session colors found - apply them
        COLOR_BASE="$SESSION_BASE_COLOR"
        COLOR_PROCESSING="$SESSION_COLOR_PROCESSING"
        COLOR_PERMISSION="$SESSION_COLOR_PERMISSION"
        COLOR_COMPLETE="$SESSION_COLOR_COMPLETE"
        COLOR_IDLE="$SESSION_COLOR_IDLE"
        COLOR_COMPACTING="$SESSION_COLOR_COMPACTING"
        IS_DARK_THEME="$SESSION_IS_DARK"

        # Check if system mode changed (for auto-dark mode switching)
        if [[ "$ENABLE_LIGHT_DARK_SWITCHING" == "true" ]]; then
            local current_mode
            current_mode=$(_detect_system_mode)
            if [[ "$current_mode" != "$SESSION_SYSTEM_MODE" ]]; then
                # System mode changed - trigger a refresh
                # This will use the new mode with agent defaults
                clear_mode_cache
                _resolve_colors
                return 1
            fi
        fi

        # Rebuild stage arrays with session colors
        _build_stage_arrays
        return 0
    fi

    # No session colors - use theme defaults
    return 1
}

# ==============================================================================
# COLOR REFRESH
# ==============================================================================

# Refresh colors based on current state and settings
# Called at key check events (permission, complete)
refresh_colors_if_needed() {
    # Only check if auto-dark mode is enabled
    [[ "$ENABLE_LIGHT_DARK_SWITCHING" != "true" ]] && return 0

    # Check if system mode changed
    local current_mode
    current_mode=$(_detect_system_mode)

    if [[ "$current_mode" != "$_CACHED_SYSTEM_MODE" ]]; then
        _CACHED_SYSTEM_MODE="$current_mode"
        _resolve_colors

        # Update session colors with new mode if we have them
        if type has_session_colors &>/dev/null && has_session_colors; then
            # Re-calculate and store with new mode
            if read_session_colors; then
                write_session_colors "$SESSION_AGENT" "$SESSION_BASE_COLOR" \
                    "$IS_DARK_THEME" "$current_mode" \
                    "$COLOR_PROCESSING" "$COLOR_PERMISSION" "$COLOR_COMPLETE" \
                    "$COLOR_IDLE" "$COLOR_COMPACTING"
            fi
        fi
    fi
}

# ==============================================================================
# COLOR RETRIEVAL
# ==============================================================================

# Get the effective background color for a state
# Checks session colors first, then falls back to theme colors
get_effective_color() {
    local state="$1"

    # Try session color first
    local session_color
    if type get_session_color &>/dev/null; then
        session_color=$(get_session_color "$state")
        if [[ -n "$session_color" ]]; then
            echo "$session_color"
            return
        fi
    fi

    # Fall back to theme color
    case "$state" in
        processing)  echo "$COLOR_PROCESSING" ;;
        permission)  echo "$COLOR_PERMISSION" ;;
        complete)    echo "$COLOR_COMPLETE" ;;
        idle)        echo "$COLOR_IDLE" ;;
        compacting)  echo "$COLOR_COMPACTING" ;;
        subagent*)   echo "$COLOR_SUBAGENT" ;;
        tool_error)  echo "$COLOR_TOOL_ERROR" ;;
        base)        echo "$COLOR_BASE" ;;
        *)           echo "" ;;
    esac
}
