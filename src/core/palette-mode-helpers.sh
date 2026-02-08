#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — Palette Mode Helpers Module
# ==============================================================================
# Shared palette mode detection and background color decision logic.
# Extracted from trigger.sh to eliminate duplication with idle-worker.sh.
#
# Public functions:
#   should_send_bg_color()   - Decide whether to send background color
#   _get_palette_mode()      - Get current palette mode (dark/light)
#
# These functions are used by both:
#   - trigger.sh (main signal handler)
#   - idle-worker.sh (background idle timer)
#
# Dependencies:
#   - ENABLE_BACKGROUND_CHANGE, STYLISH_SKIP_BG_TINT, ENABLE_STYLISH_BACKGROUNDS
#   - supports_background_images() from backgrounds.sh (optional)
#   - FORCE_MODE, IS_DARK_THEME, ENABLE_LIGHT_DARK_SWITCHING from theme.sh
#   - get_system_mode() from detect.sh (optional)
# ==============================================================================

# ==============================================================================
# BACKGROUND COLOR DECISION
# ==============================================================================

# Check if we should send background color
# Returns 0 (true) if background color should be sent, 1 (false) to skip
#
# Skips when:
#   - ENABLE_BACKGROUND_CHANGE is not "true"
#   - Stylish backgrounds are active AND terminal supports images AND skip option enabled
#
# Usage: should_send_bg_color && send_osc_bg "$color"
should_send_bg_color() {
    [[ "$ENABLE_BACKGROUND_CHANGE" != "true" ]] && return 1

    # Skip tint when background images are active (if option enabled)
    if [[ "$STYLISH_SKIP_BG_TINT" == "true" ]] && \
       [[ "$ENABLE_STYLISH_BACKGROUNDS" == "true" ]] && \
       type supports_background_images &>/dev/null && \
       supports_background_images; then
        return 1
    fi

    return 0
}

# ==============================================================================
# PALETTE MODE DETECTION
# ==============================================================================

# Get current palette mode based on theme resolution
# Returns "dark" or "light"
#
# Resolution order:
#   1. Explicit FORCE_MODE override (light/dark)
#   2. IS_DARK_THEME from theme.sh (respects FORCE_MODE and ENABLE_LIGHT_DARK_SWITCHING)
#   3. System mode detection (if FORCE_MODE=auto and ENABLE_LIGHT_DARK_SWITCHING=true)
#   4. Final fallback: dark mode
#
# Usage: mode=$(_get_palette_mode)
_get_palette_mode() {
    # 1. Respect explicit FORCE_MODE overrides
    if [[ "$FORCE_MODE" == "light" ]]; then
        echo "light"
        return
    elif [[ "$FORCE_MODE" == "dark" ]]; then
        echo "dark"
        return
    fi

    # 2. For auto/unset: use IS_DARK_THEME from theme.sh (if available)
    #    This ensures palette stays in sync with background colors
    if [[ "$IS_DARK_THEME" == "false" ]]; then
        echo "light"
        return
    elif [[ "$IS_DARK_THEME" == "true" ]]; then
        echo "dark"
        return
    fi

    # 3. Fallback: only use system detection if auto dark mode is enabled
    if [[ "$FORCE_MODE" == "auto" ]] && [[ "$ENABLE_LIGHT_DARK_SWITCHING" == "true" ]]; then
        # Check if get_system_mode is available (may not be in background processes)
        if type get_system_mode &>/dev/null; then
            local system_mode
            system_mode=$(get_system_mode)
            if [[ "$system_mode" == "light" ]]; then
                echo "light"
                return
            fi
        fi
    fi

    # 4. Final fallback: dark mode
    echo "dark"
}
