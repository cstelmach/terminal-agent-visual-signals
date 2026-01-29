#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Themes - Theme Definitions & Config Loader
# ==============================================================================
# Loads configuration in hierarchical order:
#   1. Global defaults (src/config/global.conf)
#   2. Agent-specific config (src/config/{agent}.conf)
#   3. Agent-specific theme data (src/agents/{agent}/data/)
#   4. User overrides (~/.terminal-visual-signals/user.conf)
#   5. User agent overrides (~/.terminal-visual-signals/agents/{agent}/)
#
# Used by all agents (Claude, Gemini, Codex, OpenCode).
# ==============================================================================

# Resolve paths
_THEME_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CONFIG_DIR="$_THEME_SCRIPT_DIR/../config"
_THEMES_DIR="$_THEME_SCRIPT_DIR/../themes"
_USER_CONFIG_DIR="$HOME/.terminal-visual-signals"
_USER_CONFIG="$_USER_CONFIG_DIR/user.conf"

# Source agent theme system
_AGENT_THEME_SCRIPT="$_THEME_SCRIPT_DIR/agent-theme.sh"
if [[ -f "$_AGENT_THEME_SCRIPT" ]]; then
    # shellcheck source=/dev/null
    source "$_AGENT_THEME_SCRIPT"
fi

# ==============================================================================
# CONFIGURATION LOADING
# ==============================================================================

# Current agent (set via TAVS_AGENT env var or load_agent_config function)
TAVS_AGENT="${TAVS_AGENT:-claude}"

# Load a config file if it exists
_load_config_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        # shellcheck source=/dev/null
        source "$file"
        return 0
    fi
    return 1
}

# Load configuration hierarchy for specified agent
# Usage: load_agent_config [agent_id]
load_agent_config() {
    local agent="${1:-$TAVS_AGENT}"
    TAVS_AGENT="$agent"

    # 1. Load global defaults (required)
    if [[ -f "$_CONFIG_DIR/global.conf" ]]; then
        _load_config_file "$_CONFIG_DIR/global.conf"
    else
        # Fallback to inline defaults if config not found
        _set_inline_defaults
    fi

    # 2. Load agent-specific config (optional)
    _load_config_file "$_CONFIG_DIR/${agent}.conf" || true

    # 3. Load user overrides (optional)
    _load_config_file "$_USER_CONFIG" || true

    # 4. Apply theme preset if specified
    if [[ "$THEME_MODE" == "preset" ]] && [[ -n "$THEME_PRESET" ]]; then
        _load_config_file "$_THEMES_DIR/${THEME_PRESET}.conf"
    fi

    # 5. Initialize agent-specific theme (faces, colors, backgrounds)
    if type init_agent_theme &>/dev/null; then
        init_agent_theme "$agent"
    fi

    # 6. Resolve final color values based on mode
    _resolve_colors
}

# Set inline defaults (fallback when config files not found)
_set_inline_defaults() {
    # Operating mode
    THEME_MODE="${THEME_MODE:-static}"
    THEME_PRESET="${THEME_PRESET:-}"
    ENABLE_AUTO_DARK_MODE="${ENABLE_AUTO_DARK_MODE:-false}"
    FORCE_MODE="${FORCE_MODE:-auto}"

    # Feature toggles
    ENABLE_BACKGROUND_CHANGE="${ENABLE_BACKGROUND_CHANGE:-true}"
    ENABLE_TITLE_PREFIX="${ENABLE_TITLE_PREFIX:-true}"
    ENABLE_PROCESSING="${ENABLE_PROCESSING:-true}"
    ENABLE_PERMISSION="${ENABLE_PERMISSION:-true}"
    ENABLE_COMPLETE="${ENABLE_COMPLETE:-true}"
    ENABLE_IDLE="${ENABLE_IDLE:-true}"
    ENABLE_COMPACTING="${ENABLE_COMPACTING:-true}"

    # Anthropomorphising
    ENABLE_ANTHROPOMORPHISING="${ENABLE_ANTHROPOMORPHISING:-false}"
    FACE_POSITION="${FACE_POSITION:-before}"
    # Note: FACE_THEME is deprecated - faces are now agent-specific

    # Dark mode colors (defaults)
    DARK_BASE="${DARK_BASE:-#2E3440}"
    DARK_PROCESSING="${DARK_PROCESSING:-#473D2F}"
    DARK_PERMISSION="${DARK_PERMISSION:-#4A2021}"
    DARK_COMPLETE="${DARK_COMPLETE:-#473046}"
    DARK_IDLE="${DARK_IDLE:-#443147}"
    DARK_COMPACTING="${DARK_COMPACTING:-#2B4645}"

    # Light mode colors (defaults)
    LIGHT_BASE="${LIGHT_BASE:-#ECEFF4}"
    LIGHT_PROCESSING="${LIGHT_PROCESSING:-#F5E0D0}"
    LIGHT_PERMISSION="${LIGHT_PERMISSION:-#F5D0D0}"
    LIGHT_COMPLETE="${LIGHT_COMPLETE:-#E0F0E0}"
    LIGHT_IDLE="${LIGHT_IDLE:-#E8E0F0}"
    LIGHT_COMPACTING="${LIGHT_COMPACTING:-#D8F0F0}"

    # Emojis
    EMOJI_PROCESSING="${EMOJI_PROCESSING:-🟠}"
    EMOJI_PERMISSION="${EMOJI_PERMISSION:-🔴}"
    EMOJI_COMPLETE="${EMOJI_COMPLETE:-🟢}"
    EMOJI_IDLE="${EMOJI_IDLE:-🟣}"
    EMOJI_COMPACTING="${EMOJI_COMPACTING:-🔄}"

    # Dynamic mode settings
    HUE_PROCESSING="${HUE_PROCESSING:-30}"
    HUE_PERMISSION="${HUE_PERMISSION:-0}"
    HUE_COMPLETE="${HUE_COMPLETE:-120}"
    HUE_IDLE="${HUE_IDLE:-270}"
    HUE_COMPACTING="${HUE_COMPACTING:-180}"
    DYNAMIC_QUERY_TIMEOUT="${DYNAMIC_QUERY_TIMEOUT:-0.1}"
    DYNAMIC_DISABLE_SSH="${DYNAMIC_DISABLE_SSH:-true}"

    # Idle timer
    ENABLE_STAGE_INDICATORS="${ENABLE_STAGE_INDICATORS:-true}"
    STAGE_DURATIONS=(60 30 30 30 30 30 30)
    IDLE_CHECK_INTERVAL="${IDLE_CHECK_INTERVAL:-15}"

    # Bell
    ENABLE_BELL_PROCESSING="${ENABLE_BELL_PROCESSING:-false}"
    ENABLE_BELL_PERMISSION="${ENABLE_BELL_PERMISSION:-true}"
    ENABLE_BELL_COMPLETE="${ENABLE_BELL_COMPLETE:-false}"
    ENABLE_BELL_COMPACTING="${ENABLE_BELL_COMPACTING:-false}"

    # Debug
    DEBUG_ALL="${DEBUG_ALL:-0}"
    IDLE_DEBUG="${IDLE_DEBUG:-0}"
    STATE_GRACE_PERIOD_MS="${STATE_GRACE_PERIOD_MS:-400}"
}

# ==============================================================================
# COLOR RESOLUTION
# ==============================================================================

# Cached system mode (to avoid repeated detection)
_CACHED_SYSTEM_MODE=""

# Resolve final COLOR_* values based on mode settings
_resolve_colors() {
    local use_dark="true"

    # Determine if we should use dark or light colors
    if [[ "$FORCE_MODE" == "dark" ]]; then
        use_dark="true"
    elif [[ "$FORCE_MODE" == "light" ]]; then
        use_dark="false"
    elif [[ "$ENABLE_AUTO_DARK_MODE" == "true" ]]; then
        # Auto-detect system mode
        if [[ -z "$_CACHED_SYSTEM_MODE" ]]; then
            _CACHED_SYSTEM_MODE=$(_detect_system_mode)
        fi
        [[ "$_CACHED_SYSTEM_MODE" == "dark" ]] && use_dark="true" || use_dark="false"
    fi

    # Set active colors based on mode
    if [[ "$use_dark" == "true" ]]; then
        COLOR_BASE="${DARK_BASE}"
        COLOR_PROCESSING="${DARK_PROCESSING}"
        COLOR_PERMISSION="${DARK_PERMISSION}"
        COLOR_COMPLETE="${DARK_COMPLETE}"
        COLOR_IDLE="${DARK_IDLE}"
        COLOR_COMPACTING="${DARK_COMPACTING}"
        IS_DARK_THEME="true"
    else
        COLOR_BASE="${LIGHT_BASE}"
        COLOR_PROCESSING="${LIGHT_PROCESSING}"
        COLOR_PERMISSION="${LIGHT_PERMISSION}"
        COLOR_COMPLETE="${LIGHT_COMPLETE}"
        COLOR_IDLE="${LIGHT_IDLE}"
        COLOR_COMPACTING="${LIGHT_COMPACTING}"
        IS_DARK_THEME="false"
    fi

    # Build unified stage arrays for backward compatibility
    _build_stage_arrays
}

# Detect system dark mode (simplified inline version)
# Full detection is in detect.sh
_detect_system_mode() {
    case "$(uname -s)" in
        Darwin)
            if defaults read -g AppleInterfaceStyle &>/dev/null; then
                echo "dark"
            else
                echo "light"
            fi
            ;;
        Linux)
            if command -v gsettings &>/dev/null; then
                local scheme
                scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)
                if [[ "$scheme" == *"dark"* ]]; then
                    echo "dark"
                    return
                fi
            fi
            echo "light"
            ;;
        *)
            echo "dark"  # Default to dark
            ;;
    esac
}

# Clear cached system mode (call when mode might have changed)
clear_mode_cache() {
    _CACHED_SYSTEM_MODE=""
}

# Force refresh colors with current system mode
refresh_colors() {
    clear_mode_cache
    _resolve_colors
}

# ==============================================================================
# STAGE ARRAYS (Backward Compatibility)
# ==============================================================================

# Build the UNIFIED_STAGE_* arrays from current settings
_build_stage_arrays() {
    # Try to load colors.sh for interpolation
    _source_colors_if_needed 2>/dev/null || true

    # Colors: Complete -> Idle stages -> Reset
    # Stage 0: Complete color
    # Stages 1-5: Interpolate from Idle color toward Base color
    # Stage 6: Reset (terminal default)
    UNIFIED_STAGE_COLORS=(
        "${IDLE_STAGE_0_COLOR:-$COLOR_COMPLETE}"
        "${IDLE_STAGE_1_COLOR:-$COLOR_IDLE}"
        "${IDLE_STAGE_2_COLOR:-$(_interpolate_stage_color 2)}"
        "${IDLE_STAGE_3_COLOR:-$(_interpolate_stage_color 3)}"
        "${IDLE_STAGE_4_COLOR:-$(_interpolate_stage_color 4)}"
        "${IDLE_STAGE_5_COLOR:-$(_interpolate_stage_color 5)}"
        "${IDLE_STAGE_6_COLOR:-reset}"
    )

    # Emojis: Complete -> Idle stages -> Empty (reset)
    UNIFIED_STAGE_EMOJIS=(
        "${IDLE_STAGE_0_EMOJI:-$EMOJI_COMPLETE}"
        "${IDLE_STAGE_1_EMOJI:-$EMOJI_IDLE}"
        "${IDLE_STAGE_2_EMOJI:-$EMOJI_IDLE}"
        "${IDLE_STAGE_3_EMOJI:-$EMOJI_IDLE}"
        "${IDLE_STAGE_4_EMOJI:-$EMOJI_IDLE}"
        "${IDLE_STAGE_5_EMOJI:-$EMOJI_IDLE}"
        "${IDLE_STAGE_6_EMOJI:-}"
    )

    # Durations from config or defaults
    if [[ ${#STAGE_DURATIONS[@]} -gt 0 ]]; then
        UNIFIED_STAGE_DURATIONS=("${STAGE_DURATIONS[@]}")
    else
        UNIFIED_STAGE_DURATIONS=(60 30 30 30 30 30 30)
    fi

    # Check interval
    UNIFIED_CHECK_INTERVAL="${IDLE_CHECK_INTERVAL:-15}"
}

# Interpolate idle stage color using HSL interpolation
# Stage 2-5 interpolate from IDLE toward BASE color
# The interpolation factor increases linearly: stage 2 = 20%, stage 5 = 80%
_interpolate_stage_color() {
    local stage=$1

    # Stages 2-5 interpolate from idle (stage 1) toward base
    # We interpolate in HSL space for smooth hue transitions
    # Stage 2: 20% toward base, Stage 3: 40%, Stage 4: 60%, Stage 5: 80%
    local t=$(( (stage - 1) * 200 ))  # 200, 400, 600, 800 for stages 2-5

    # If we have colors.sh loaded, use proper HSL interpolation
    if type interpolate_hsl &>/dev/null; then
        interpolate_hsl "$COLOR_IDLE" "$COLOR_BASE" "$t"
        return
    fi

    # Fallback: simple RGB interpolation if we have hex_to_rgb
    if type hex_to_rgb &>/dev/null && type rgb_to_hex &>/dev/null; then
        local rgb1 rgb2
        rgb1=$(hex_to_rgb "$COLOR_IDLE")
        rgb2=$(hex_to_rgb "$COLOR_BASE")
        read -r r1 g1 b1 <<< "$rgb1"
        read -r r2 g2 b2 <<< "$rgb2"

        local r=$(( r1 + (r2 - r1) * t / 1000 ))
        local g=$(( g1 + (g2 - g1) * t / 1000 ))
        local b=$(( b1 + (b2 - b1) * t / 1000 ))

        rgb_to_hex "$r" "$g" "$b"
        return
    fi

    # Ultra-simple fallback: return idle color for all stages
    # (no interpolation without color utilities)
    echo "$COLOR_IDLE"
}

# ==============================================================================
# THEME PRESET FUNCTIONS
# ==============================================================================

# Apply a named theme preset
# Usage: apply_theme "nord"
apply_theme() {
    local preset_name="$1"

    if [[ -z "$preset_name" ]]; then
        echo "Error: No theme preset specified" >&2
        return 1
    fi

    local preset_file="$_THEMES_DIR/${preset_name}.conf"

    if [[ ! -f "$preset_file" ]]; then
        echo "Error: Theme preset '$preset_name' not found at $preset_file" >&2
        return 1
    fi

    _load_config_file "$preset_file"
    _resolve_colors
    return 0
}

# List available theme presets
list_themes() {
    if [[ -d "$_THEMES_DIR" ]]; then
        find "$_THEMES_DIR" -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort
    fi
}

# ==============================================================================
# DYNAMIC MODE FUNCTIONS
# ==============================================================================

# Source color utilities if available
_source_colors_if_needed() {
    if ! type hex_to_rgb &>/dev/null; then
        local colors_script="$_THEME_SCRIPT_DIR/colors.sh"
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
        local detect_script="$_THEME_SCRIPT_DIR/detect.sh"
        if [[ -f "$detect_script" ]]; then
            # shellcheck source=/dev/null
            source "$detect_script"
            return 0
        fi
        return 1
    fi
    return 0
}

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
    local color_proc color_perm color_comp color_idle color_compact
    color_proc=$(shift_hue "$base_color" "$HUE_PROCESSING")
    color_perm=$(shift_hue "$base_color" "$HUE_PERMISSION")
    color_comp=$(shift_hue "$base_color" "$HUE_COMPLETE")
    color_idle=$(shift_hue "$base_color" "$HUE_IDLE")
    color_compact=$(shift_hue "$base_color" "$HUE_COMPACTING")

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
    IS_DARK_THEME="$is_dark"

    # Rebuild stage arrays with new colors
    _build_stage_arrays

    return 0
}

# Load session colors if available, otherwise use theme defaults
# Returns 0 if session colors were loaded, 1 if using defaults
load_session_colors_or_defaults() {
    # Source state.sh if needed for session color functions
    if ! type read_session_colors &>/dev/null; then
        local state_script="$_THEME_SCRIPT_DIR/state.sh"
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
        if [[ "$ENABLE_AUTO_DARK_MODE" == "true" ]]; then
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

# Refresh colors based on current state and settings
# Called at key check events (permission, complete)
refresh_colors_if_needed() {
    # Only check if auto-dark mode is enabled
    [[ "$ENABLE_AUTO_DARK_MODE" != "true" ]] && return 0

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

# Get the effective color for a state
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
        processing) echo "$COLOR_PROCESSING" ;;
        permission) echo "$COLOR_PERMISSION" ;;
        complete)   echo "$COLOR_COMPLETE" ;;
        idle)       echo "$COLOR_IDLE" ;;
        compacting) echo "$COLOR_COMPACTING" ;;
        base)       echo "$COLOR_BASE" ;;
        *)          echo "" ;;
    esac
}

# ==============================================================================
# INITIALIZATION
# ==============================================================================

# Auto-load configuration on source
# This ensures backward compatibility - existing code that sources theme.sh
# will get colors loaded automatically

# Only auto-load if not already loaded (prevent double-loading)
if [[ -z "$_THEME_LOADED" ]]; then
    _THEME_LOADED="1"
    load_agent_config "$TAVS_AGENT"
fi
