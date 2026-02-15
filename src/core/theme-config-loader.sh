#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — Theme Definitions & Config Loader
# ==============================================================================
# Loads configuration from consolidated defaults and user overrides:
#   1. Master defaults (src/config/defaults.conf) - global + all agents
#   2. User overrides (~/.tavs/user.conf)
#   3. Theme preset (src/themes/{preset}.conf) if THEME_MODE="preset"
#   4. Resolve AGENT_prefixed variables to generic names
#
# Used by all agents (Claude, Gemini, Codex, OpenCode, Unknown).
# ==============================================================================

# Resolve paths - works in both bash and zsh
# BASH_SOURCE is bash-only; zsh uses different mechanisms
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    _THIS_SCRIPT="${BASH_SOURCE[0]}"
elif [[ -n "${(%):-%x}" ]] 2>/dev/null; then
    _THIS_SCRIPT="${(%):-%x}"  # zsh-specific: current script path
else
    _THIS_SCRIPT="$0"  # Fallback (may not work when sourced)
fi
_THEME_SCRIPT_DIR="$( cd "$( dirname "$_THIS_SCRIPT" )" && pwd )"
_CONFIG_DIR="$_THEME_SCRIPT_DIR/../config"
_THEMES_DIR="$_THEME_SCRIPT_DIR/../themes"
_USER_CONFIG_DIR="$HOME/.tavs"
_USER_CONFIG="$_USER_CONFIG_DIR/user.conf"

# ==============================================================================
# SOURCE EXTRACTED MODULES
# ==============================================================================
# These modules contain functions extracted from this file for modularization.
# They must be sourced before any code that calls their functions.
# ==============================================================================

source "${_THEME_SCRIPT_DIR}/face-selection.sh"
source "${_THEME_SCRIPT_DIR}/dynamic-color-calculation.sh"

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
    agent="${agent:-unknown}"  # Default to unknown if empty
    TAVS_AGENT="$agent"

    # 1. Load master defaults (required)
    if [[ -f "$_CONFIG_DIR/defaults.conf" ]]; then
        _load_config_file "$_CONFIG_DIR/defaults.conf"
    else
        # Fallback to inline defaults if config not found
        _set_inline_defaults
    fi

    # 2. Load user overrides (optional)
    _load_config_file "$_USER_CONFIG" || true

    # 3. Apply theme preset if specified
    if [[ "$THEME_MODE" == "preset" ]] && [[ -n "$THEME_PRESET" ]]; then
        _load_config_file "$_THEMES_DIR/${THEME_PRESET}.conf"
    fi

    # 4. Resolve agent-specific variables to generic names
    _resolve_agent_variables "$agent"

    # 5. Resolve agent-specific faces
    _resolve_agent_faces "$agent"

    # 6. Resolve final color values based on mode
    _resolve_colors
}

# ==============================================================================
# AGENT VARIABLE RESOLUTION
# ==============================================================================

# Resolve AGENT_prefixed variables to generic names
# E.g., CLAUDE_DARK_BASE -> DARK_BASE when agent=claude
_resolve_agent_variables() {
    local agent="$1"
    # Convert to uppercase for prefix (Bash 3.2 compatible)
    local prefix
    prefix="$(echo "$agent" | tr '[:lower:]' '[:upper:]')_"  # CLAUDE_, GEMINI_, etc.

    # Variables to resolve (background colors)
    local vars=(
        AGENT_NAME
        DARK_BASE DARK_PROCESSING DARK_PERMISSION DARK_COMPLETE DARK_IDLE DARK_COMPACTING DARK_SUBAGENT DARK_TOOL_ERROR
        LIGHT_BASE LIGHT_PROCESSING LIGHT_PERMISSION LIGHT_COMPLETE LIGHT_IDLE LIGHT_COMPACTING LIGHT_SUBAGENT LIGHT_TOOL_ERROR
        MUTED_DARK_BASE MUTED_DARK_PROCESSING MUTED_DARK_PERMISSION MUTED_DARK_COMPLETE MUTED_DARK_IDLE MUTED_DARK_COMPACTING MUTED_DARK_SUBAGENT MUTED_DARK_TOOL_ERROR
        MUTED_LIGHT_BASE MUTED_LIGHT_PROCESSING MUTED_LIGHT_PERMISSION MUTED_LIGHT_COMPLETE MUTED_LIGHT_IDLE MUTED_LIGHT_COMPACTING MUTED_LIGHT_SUBAGENT MUTED_LIGHT_TOOL_ERROR
        # Mode-aware processing color variants (permission mode)
        DARK_PROCESSING_PLAN DARK_PROCESSING_ACCEPT DARK_PROCESSING_BYPASS
        LIGHT_PROCESSING_PLAN LIGHT_PROCESSING_ACCEPT LIGHT_PROCESSING_BYPASS
        MUTED_DARK_PROCESSING_PLAN MUTED_DARK_PROCESSING_ACCEPT MUTED_DARK_PROCESSING_BYPASS
        MUTED_LIGHT_PROCESSING_PLAN MUTED_LIGHT_PROCESSING_ACCEPT MUTED_LIGHT_PROCESSING_BYPASS
        SPINNER_FACE_FRAME
        # Per-state title format overrides (4-level fallback in compose_title)
        TITLE_FORMAT
        TITLE_FORMAT_PROCESSING TITLE_FORMAT_PERMISSION TITLE_FORMAT_COMPLETE
        TITLE_FORMAT_IDLE TITLE_FORMAT_COMPACTING TITLE_FORMAT_SUBAGENT
        TITLE_FORMAT_TOOL_ERROR TITLE_FORMAT_RESET
    )

    local var value

    for var in "${vars[@]}"; do
        # Try AGENT_prefixed first
        eval "value=\${${prefix}${var}:-}"

        # Fall back to UNKNOWN_ for unrecognized agents
        if [[ -z "$value" ]]; then
            eval "value=\${UNKNOWN_${var}:-}"
        fi

        # Fall back to DEFAULT_ if still not set (for colors and spinner frame)
        if [[ -z "$value" ]] && [[ "$var" == *_BASE || "$var" == *_PROCESSING || "$var" == *_PERMISSION || "$var" == *_COMPLETE || "$var" == *_IDLE || "$var" == *_COMPACTING || "$var" == *_SUBAGENT || "$var" == *_TOOL_ERROR || "$var" == *_PROCESSING_PLAN || "$var" == *_PROCESSING_ACCEPT || "$var" == *_PROCESSING_BYPASS || "$var" == "SPINNER_FACE_FRAME" ]]; then
            eval "value=\${DEFAULT_${var}:-}"
        fi

        # Set the generic variable if we have a value
        if [[ -n "$value" ]]; then
            eval "$var=\"\$value\""
        fi
    done
}

# Set inline defaults (fallback when config files not found)
_set_inline_defaults() {
    # Operating mode
    THEME_MODE="${THEME_MODE:-static}"
    THEME_PRESET="${THEME_PRESET:-}"

    # Backward compatibility: support old variable name ENABLE_LIGHT_DARK_SWITCHING
    if [[ -n "${ENABLE_LIGHT_DARK_SWITCHING:-}" ]] && [[ -z "${ENABLE_LIGHT_DARK_SWITCHING:-}" ]]; then
        ENABLE_LIGHT_DARK_SWITCHING="$ENABLE_LIGHT_DARK_SWITCHING"
    fi
    ENABLE_LIGHT_DARK_SWITCHING="${ENABLE_LIGHT_DARK_SWITCHING:-false}"

    FORCE_MODE="${FORCE_MODE:-auto}"
    TRUECOLOR_MODE_OVERRIDE="${TRUECOLOR_MODE_OVERRIDE:-off}"

    # Feature toggles
    ENABLE_BACKGROUND_CHANGE="${ENABLE_BACKGROUND_CHANGE:-true}"
    ENABLE_TITLE_PREFIX="${ENABLE_TITLE_PREFIX:-true}"
    ENABLE_PROCESSING="${ENABLE_PROCESSING:-true}"
    ENABLE_PERMISSION="${ENABLE_PERMISSION:-true}"
    ENABLE_COMPLETE="${ENABLE_COMPLETE:-true}"
    ENABLE_IDLE="${ENABLE_IDLE:-true}"
    ENABLE_COMPACTING="${ENABLE_COMPACTING:-true}"
    ENABLE_SUBAGENT="${ENABLE_SUBAGENT:-true}"
    ENABLE_TOOL_ERROR="${ENABLE_TOOL_ERROR:-true}"
    ENABLE_MODE_AWARE_PROCESSING="${ENABLE_MODE_AWARE_PROCESSING:-true}"

    # Anthropomorphising
    ENABLE_ANTHROPOMORPHISING="${ENABLE_ANTHROPOMORPHISING:-true}"
    FACE_POSITION="${FACE_POSITION:-before}"

    # Dark mode background colors (defaults - Catppuccin Frappé)
    DEFAULT_DARK_BASE="${DEFAULT_DARK_BASE:-#303446}"
    DEFAULT_DARK_PROCESSING="${DEFAULT_DARK_PROCESSING:-#3d3b42}"
    DEFAULT_DARK_PERMISSION="${DEFAULT_DARK_PERMISSION:-#3d3440}"
    DEFAULT_DARK_COMPLETE="${DEFAULT_DARK_COMPLETE:-#374539}"
    DEFAULT_DARK_IDLE="${DEFAULT_DARK_IDLE:-#3d3850}"
    DEFAULT_DARK_COMPACTING="${DEFAULT_DARK_COMPACTING:-#334545}"
    DEFAULT_DARK_SUBAGENT="${DEFAULT_DARK_SUBAGENT:-#42402E}"
    DEFAULT_DARK_TOOL_ERROR="${DEFAULT_DARK_TOOL_ERROR:-#4A2A1F}"

    # Light mode background colors (defaults - Catppuccin Latte)
    DEFAULT_LIGHT_BASE="${DEFAULT_LIGHT_BASE:-#eff1f5}"
    DEFAULT_LIGHT_PROCESSING="${DEFAULT_LIGHT_PROCESSING:-#f5e6dc}"
    DEFAULT_LIGHT_PERMISSION="${DEFAULT_LIGHT_PERMISSION:-#f5dde0}"
    DEFAULT_LIGHT_COMPLETE="${DEFAULT_LIGHT_COMPLETE:-#e5f0e5}"
    DEFAULT_LIGHT_IDLE="${DEFAULT_LIGHT_IDLE:-#ebe5f5}"
    DEFAULT_LIGHT_COMPACTING="${DEFAULT_LIGHT_COMPACTING:-#e0f0f0}"
    DEFAULT_LIGHT_SUBAGENT="${DEFAULT_LIGHT_SUBAGENT:-#F5F0D0}"
    DEFAULT_LIGHT_TOOL_ERROR="${DEFAULT_LIGHT_TOOL_ERROR:-#B87050}"

    # Muted dark mode colors (for TrueColor terminals with mode switching)
    DEFAULT_MUTED_DARK_BASE="${DEFAULT_MUTED_DARK_BASE:-#4a4e5c}"
    DEFAULT_MUTED_DARK_PROCESSING="${DEFAULT_MUTED_DARK_PROCESSING:-#5a5650}"
    DEFAULT_MUTED_DARK_PERMISSION="${DEFAULT_MUTED_DARK_PERMISSION:-#5a4a4c}"
    DEFAULT_MUTED_DARK_COMPLETE="${DEFAULT_MUTED_DARK_COMPLETE:-#4f5a52}"
    DEFAULT_MUTED_DARK_IDLE="${DEFAULT_MUTED_DARK_IDLE:-#544f62}"
    DEFAULT_MUTED_DARK_COMPACTING="${DEFAULT_MUTED_DARK_COMPACTING:-#4a5858}"
    DEFAULT_MUTED_DARK_SUBAGENT="${DEFAULT_MUTED_DARK_SUBAGENT:-#5a5848}"
    DEFAULT_MUTED_DARK_TOOL_ERROR="${DEFAULT_MUTED_DARK_TOOL_ERROR:-#6a4a3f}"

    # Muted light mode colors (for TrueColor terminals with mode switching)
    DEFAULT_MUTED_LIGHT_BASE="${DEFAULT_MUTED_LIGHT_BASE:-#b8bac2}"
    DEFAULT_MUTED_LIGHT_PROCESSING="${DEFAULT_MUTED_LIGHT_PROCESSING:-#c9b8a8}"
    DEFAULT_MUTED_LIGHT_PERMISSION="${DEFAULT_MUTED_LIGHT_PERMISSION:-#c9a8ac}"
    DEFAULT_MUTED_LIGHT_COMPLETE="${DEFAULT_MUTED_LIGHT_COMPLETE:-#a8c2a8}"
    DEFAULT_MUTED_LIGHT_IDLE="${DEFAULT_MUTED_LIGHT_IDLE:-#b8aac8}"
    DEFAULT_MUTED_LIGHT_COMPACTING="${DEFAULT_MUTED_LIGHT_COMPACTING:-#a8c2c2}"
    DEFAULT_MUTED_LIGHT_SUBAGENT="${DEFAULT_MUTED_LIGHT_SUBAGENT:-#c8c4a0}"
    DEFAULT_MUTED_LIGHT_TOOL_ERROR="${DEFAULT_MUTED_LIGHT_TOOL_ERROR:-#c09070}"

    # Status Icons
    STATUS_ICON_PROCESSING="${STATUS_ICON_PROCESSING:-🟠}"
    STATUS_ICON_PERMISSION="${STATUS_ICON_PERMISSION:-🔴}"
    STATUS_ICON_COMPLETE="${STATUS_ICON_COMPLETE:-🟢}"
    STATUS_ICON_IDLE="${STATUS_ICON_IDLE:-🟣}"
    STATUS_ICON_COMPACTING="${STATUS_ICON_COMPACTING:-🔄}"
    STATUS_ICON_SUBAGENT="${STATUS_ICON_SUBAGENT:-🔀}"
    STATUS_ICON_TOOL_ERROR="${STATUS_ICON_TOOL_ERROR:-❌}"

    # Dynamic mode settings
    HUE_PROCESSING="${HUE_PROCESSING:-30}"
    HUE_PERMISSION="${HUE_PERMISSION:-0}"
    HUE_COMPLETE="${HUE_COMPLETE:-120}"
    HUE_IDLE="${HUE_IDLE:-270}"
    HUE_COMPACTING="${HUE_COMPACTING:-180}"
    HUE_SUBAGENT="${HUE_SUBAGENT:-50}"
    HUE_TOOL_ERROR="${HUE_TOOL_ERROR:-15}"
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
    ENABLE_BELL_SUBAGENT="${ENABLE_BELL_SUBAGENT:-false}"
    ENABLE_BELL_TOOL_ERROR="${ENABLE_BELL_TOOL_ERROR:-false}"

    # Debug
    DEBUG_ALL="${DEBUG_ALL:-0}"
    IDLE_DEBUG="${IDLE_DEBUG:-0}"
    STATE_GRACE_PERIOD_MS="${STATE_GRACE_PERIOD_MS:-400}"

    # Unknown agent faces (inline fallback)
    UNKNOWN_FACES_PROCESSING=('(°-°)')
    UNKNOWN_FACES_PERMISSION=('(°□°)')
    UNKNOWN_FACES_COMPLETE=('(^‿^)')
    UNKNOWN_FACES_COMPACTING=('(@_@)')
    UNKNOWN_FACES_RESET=('(-_-)')
    UNKNOWN_FACES_IDLE_0=('(•‿•)')
    UNKNOWN_FACES_IDLE_1=('(‿‿)')
    UNKNOWN_FACES_IDLE_2=('(︶‿︶)')
    UNKNOWN_FACES_IDLE_3=('(¬‿¬)')
    UNKNOWN_FACES_IDLE_4=('(-.-)zzZ')
    UNKNOWN_FACES_IDLE_5=('(︶.︶)ᶻᶻ')
    UNKNOWN_FACES_SUBAGENT=('(⇆-⇆)')
    UNKNOWN_FACES_TOOL_ERROR=('(✕_✕)')
}

# ==============================================================================
# MODE-AWARE PROCESSING COLORS
# ==============================================================================
# Override COLOR_PROCESSING based on Claude Code permission mode.
# Uses TAVS_PERMISSION_MODE env var (set by agent trigger from stdin JSON).
# Modes: default (no change), plan, acceptEdits, dontAsk, bypassPermissions.

_apply_mode_aware_processing() {
    [[ "${ENABLE_MODE_AWARE_PROCESSING:-true}" != "true" ]] && return 0

    local mode="${TAVS_PERMISSION_MODE:-default}"
    # dontAsk uses same colors as acceptEdits (both auto-approve)
    [[ "$mode" == "dontAsk" ]] && mode="acceptEdits"
    # Default mode uses standard COLOR_PROCESSING (no override)
    [[ "$mode" == "default" ]] && return 0

    # Map mode to variable suffix
    local suffix=""
    case "$mode" in
        plan)              suffix="PLAN" ;;
        acceptEdits)       suffix="ACCEPT" ;;
        bypassPermissions) suffix="BYPASS" ;;
        *)                 return 0 ;;  # Unknown mode, no change
    esac

    # Select the right color variant based on current brightness/muted state
    local mode_color=""
    if [[ "${IS_MUTED_THEME:-false}" == "true" ]]; then
        if [[ "${IS_DARK_THEME:-true}" == "true" ]]; then
            eval "mode_color=\${MUTED_DARK_PROCESSING_${suffix}:-}"
        else
            eval "mode_color=\${MUTED_LIGHT_PROCESSING_${suffix}:-}"
        fi
    else
        if [[ "${IS_DARK_THEME:-true}" == "true" ]]; then
            eval "mode_color=\${DARK_PROCESSING_${suffix}:-}"
        else
            eval "mode_color=\${LIGHT_PROCESSING_${suffix}:-}"
        fi
    fi

    # Apply override if a mode-specific color was found
    [[ -n "$mode_color" ]] && COLOR_PROCESSING="$mode_color"
}

# ==============================================================================
# COLOR RESOLUTION
# ==============================================================================

# Cached system mode (to avoid repeated detection)
_CACHED_SYSTEM_MODE=""

# Resolve final COLOR_* values based on mode settings
_resolve_colors() {
    local use_dark="true"
    local use_muted="false"
    local in_truecolor="false"

    # Check if we're in TrueColor mode
    if _source_detect_if_needed && is_truecolor_mode; then
        in_truecolor="true"
    fi

    # Determine if we should use dark or light colors
    if [[ "$FORCE_MODE" == "dark" ]]; then
        use_dark="true"
    elif [[ "$FORCE_MODE" == "light" ]]; then
        use_dark="false"
    elif [[ "$ENABLE_LIGHT_DARK_SWITCHING" == "true" ]]; then
        # Handle TrueColor mode based on override setting
        if [[ "$in_truecolor" == "true" ]]; then
            case "$TRUECOLOR_MODE_OVERRIDE" in
                "muted")
                    # Allow switching with muted colors
                    use_muted="true"
                    if [[ -z "$_CACHED_SYSTEM_MODE" ]]; then
                        _CACHED_SYSTEM_MODE=$(_detect_system_mode)
                    fi
                    [[ "$_CACHED_SYSTEM_MODE" == "dark" ]] && use_dark="true" || use_dark="false"
                    ;;
                "full")
                    # Allow switching with regular colors (same as non-TrueColor)
                    if [[ -z "$_CACHED_SYSTEM_MODE" ]]; then
                        _CACHED_SYSTEM_MODE=$(_detect_system_mode)
                    fi
                    [[ "$_CACHED_SYSTEM_MODE" == "dark" ]] && use_dark="true" || use_dark="false"
                    ;;
                *)
                    # "off" (default) - skip auto detection, use dark mode
                    use_dark="true"
                    ;;
            esac
        else
            # Non-TrueColor: always auto-detect system mode
            if [[ -z "$_CACHED_SYSTEM_MODE" ]]; then
                _CACHED_SYSTEM_MODE=$(_detect_system_mode)
            fi
            [[ "$_CACHED_SYSTEM_MODE" == "dark" ]] && use_dark="true" || use_dark="false"
        fi
    fi

    # Set active colors based on mode and muted preference
    if [[ "$use_muted" == "true" ]]; then
        # Use muted colors for TrueColor terminals
        if [[ "$use_dark" == "true" ]]; then
            COLOR_BASE="${MUTED_DARK_BASE}"
            COLOR_PROCESSING="${MUTED_DARK_PROCESSING}"
            COLOR_PERMISSION="${MUTED_DARK_PERMISSION}"
            COLOR_COMPLETE="${MUTED_DARK_COMPLETE}"
            COLOR_IDLE="${MUTED_DARK_IDLE}"
            COLOR_COMPACTING="${MUTED_DARK_COMPACTING}"
            COLOR_SUBAGENT="${MUTED_DARK_SUBAGENT}"
            COLOR_TOOL_ERROR="${MUTED_DARK_TOOL_ERROR}"
            IS_DARK_THEME="true"
            IS_MUTED_THEME="true"
        else
            COLOR_BASE="${MUTED_LIGHT_BASE}"
            COLOR_PROCESSING="${MUTED_LIGHT_PROCESSING}"
            COLOR_PERMISSION="${MUTED_LIGHT_PERMISSION}"
            COLOR_COMPLETE="${MUTED_LIGHT_COMPLETE}"
            COLOR_IDLE="${MUTED_LIGHT_IDLE}"
            COLOR_COMPACTING="${MUTED_LIGHT_COMPACTING}"
            COLOR_SUBAGENT="${MUTED_LIGHT_SUBAGENT}"
            COLOR_TOOL_ERROR="${MUTED_LIGHT_TOOL_ERROR}"
            IS_DARK_THEME="false"
            IS_MUTED_THEME="true"
        fi
    else
        # Use regular colors
        if [[ "$use_dark" == "true" ]]; then
            COLOR_BASE="${DARK_BASE}"
            COLOR_PROCESSING="${DARK_PROCESSING}"
            COLOR_PERMISSION="${DARK_PERMISSION}"
            COLOR_COMPLETE="${DARK_COMPLETE}"
            COLOR_IDLE="${DARK_IDLE}"
            COLOR_COMPACTING="${DARK_COMPACTING}"
            COLOR_SUBAGENT="${DARK_SUBAGENT}"
            COLOR_TOOL_ERROR="${DARK_TOOL_ERROR}"
            IS_DARK_THEME="true"
            IS_MUTED_THEME="false"
        else
            COLOR_BASE="${LIGHT_BASE}"
            COLOR_PROCESSING="${LIGHT_PROCESSING}"
            COLOR_PERMISSION="${LIGHT_PERMISSION}"
            COLOR_COMPLETE="${LIGHT_COMPLETE}"
            COLOR_IDLE="${LIGHT_IDLE}"
            COLOR_COMPACTING="${LIGHT_COMPACTING}"
            COLOR_SUBAGENT="${LIGHT_SUBAGENT}"
            COLOR_TOOL_ERROR="${LIGHT_TOOL_ERROR}"
            IS_DARK_THEME="false"
            IS_MUTED_THEME="false"
        fi
    fi

    # Apply mode-aware processing color override (plan/acceptEdits/bypassPermissions)
    _apply_mode_aware_processing

    # Build unified stage arrays for backward compatibility
    _build_stage_arrays
}

# Detect system dark mode (simplified inline version)
# Full detection is in terminal-detection.sh
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

    # Status Icons: Complete -> Idle stages -> Empty (reset)
    UNIFIED_STAGE_STATUS_ICONS=(
        "${IDLE_STAGE_0_STATUS_ICON:-$STATUS_ICON_COMPLETE}"
        "${IDLE_STAGE_1_STATUS_ICON:-$STATUS_ICON_IDLE}"
        "${IDLE_STAGE_2_STATUS_ICON:-$STATUS_ICON_IDLE}"
        "${IDLE_STAGE_3_STATUS_ICON:-$STATUS_ICON_IDLE}"
        "${IDLE_STAGE_4_STATUS_ICON:-$STATUS_ICON_IDLE}"
        "${IDLE_STAGE_5_STATUS_ICON:-$STATUS_ICON_IDLE}"
        "${IDLE_STAGE_6_STATUS_ICON:-}"
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
# INITIALIZATION
# ==============================================================================

# Auto-load configuration on source
# This ensures backward compatibility - existing code that sources theme-config-loader.sh
# will get colors loaded automatically

# Only auto-load if not already loaded (prevent double-loading)
if [[ -z "${_THEME_LOADED:-}" ]]; then
    _THEME_LOADED="1"
    load_agent_config "$TAVS_AGENT"
fi
