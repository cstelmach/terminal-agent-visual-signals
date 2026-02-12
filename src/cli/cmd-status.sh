#!/bin/bash
# ==============================================================================
# TAVS CLI — status command
# ==============================================================================
# Usage: tavs status [--colors|--faces|--help]
#
# Shows a rich visual summary of the current TAVS configuration, including
# resolved colors (with swatches), face previews, and active overrides.
# ==============================================================================

source "$CLI_DIR/cli-utils.sh"

cmd_status() {
    # Handle --help
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        cat <<'EOF'
tavs status — Show current configuration with visual preview

Usage:
  tavs status             Full status display
  tavs status --colors    Color swatches only
  tavs status --faces     Face preview only

Shows resolved configuration including theme, colors, faces, and title settings.
EOF
        return 0
    fi

    # Load the full config chain
    load_full_config "claude"

    # Also load user config separately for override counting
    local _override_count
    _override_count=$(count_active_settings)

    local section_filter="${1:-}"

    # =========================================================================
    # HEADER
    # =========================================================================
    echo ""
    echo -e "${_CLR_BOLD}TAVS v${TAVS_VERSION:-3.0.0} — Configuration Status${_CLR_RESET}"
    echo -e "${_CLR_DIM}$(printf '═%.0s' $(seq 1 50))${_CLR_RESET}"

    # =========================================================================
    # ESSENTIAL SETTINGS
    # =========================================================================
    if [[ -z "$section_filter" ]]; then
        cli_section "Essential Settings"

        local _default_mode="static"
        local theme_mode="${THEME_MODE:-$_default_mode}"
        printf "    %-20s %s\n" "Theme mode" "$theme_mode"

        if [[ "$theme_mode" == "preset" ]] && [[ -n "${THEME_PRESET:-}" ]]; then
            printf "    %-20s %s\n" "Theme preset" "$THEME_PRESET"
        fi

        local _default_switching="false"
        printf "    %-20s %s\n" "Light/dark" "${ENABLE_LIGHT_DARK_SWITCHING:-$_default_switching}"

        local _default_force="auto"
        local force_mode="${FORCE_MODE:-$_default_force}"
        if [[ "$force_mode" != "auto" ]]; then
            printf "    %-20s %s\n" "Force mode" "$force_mode"
        fi

        local _default_dark="true"
        printf "    %-20s %s\n" "Active mode" "$(
            if [[ "${IS_DARK_THEME:-$_default_dark}" == "true" ]]; then
                echo "dark"
            else
                echo "light"
            fi
        )$(
            if [[ "${IS_MUTED_THEME:-false}" == "true" ]]; then
                echo " (muted)"
            fi
        )"
    fi

    # =========================================================================
    # VISUAL FEATURES
    # =========================================================================
    if [[ -z "$section_filter" ]]; then
        cli_section "Visual Features"

        local _default_faces="true"
        printf "    %-20s %s\n" "Faces" "${ENABLE_ANTHROPOMORPHISING:-$_default_faces}"

        local _default_face_mode="standard"
        printf "    %-20s %s\n" "Face mode" "${TAVS_FACE_MODE:-$_default_face_mode}"

        if [[ "${TAVS_FACE_MODE:-standard}" == "compact" ]]; then
            local _default_compact="semantic"
            printf "    %-20s %s\n" "Compact theme" "${TAVS_COMPACT_THEME:-$_default_compact}"
        fi

        local _default_bg="false"
        printf "    %-20s %s\n" "Backgrounds" "${ENABLE_STYLISH_BACKGROUNDS:-$_default_bg}"

        local _default_palette="false"
        printf "    %-20s %s\n" "Palette theming" "${ENABLE_PALETTE_THEMING:-$_default_palette}"

        local _default_mode_aware="true"
        printf "    %-20s %s\n" "Mode-aware" "${ENABLE_MODE_AWARE_PROCESSING:-$_default_mode_aware}"
    fi

    # =========================================================================
    # TITLE SYSTEM
    # =========================================================================
    if [[ -z "$section_filter" ]]; then
        cli_section "Title System"

        local _default_title_mode="skip-processing"
        printf "    %-20s %s\n" "Title mode" "${TAVS_TITLE_MODE:-$_default_title_mode}"

        local _default_fallback="path"
        printf "    %-20s %s\n" "Fallback" "${TAVS_TITLE_FALLBACK:-$_default_fallback}"

        local _default_icons="true"
        printf "    %-20s %s\n" "Session icons" "${ENABLE_SESSION_ICONS:-$_default_icons}"

        local _default_title_fmt='{FACE} {STATUS_ICON} {AGENTS} {SESSION_ICON} {BASE}'
        local title_fmt="${TAVS_TITLE_FORMAT:-$_default_title_fmt}"
        printf "    %-20s %s\n" "Title format" "$title_fmt"

        if [[ "${TAVS_TITLE_MODE:-skip-processing}" == "full" ]]; then
            local _default_spinner="random"
            printf "    %-20s %s\n" "Spinner style" "${TAVS_SPINNER_STYLE:-$_default_spinner}"
            local _default_eye="random"
            printf "    %-20s %s\n" "Eye mode" "${TAVS_SPINNER_EYE_MODE:-$_default_eye}"
        fi
    fi

    # =========================================================================
    # COLOR PREVIEW
    # =========================================================================
    if [[ -z "$section_filter" || "$section_filter" == "--colors" ]]; then
        cli_section "Colors (resolved for current mode)"

        render_color_line "Base" "${COLOR_BASE:-#303446}"
        render_color_line "Processing" "${COLOR_PROCESSING:-#3d3b42}"
        render_color_line "Permission" "${COLOR_PERMISSION:-#3d3440}"
        render_color_line "Complete" "${COLOR_COMPLETE:-#374539}"
        render_color_line "Idle" "${COLOR_IDLE:-#3d3850}"
        render_color_line "Compacting" "${COLOR_COMPACTING:-#334545}"
        render_color_line "Subagent" "${COLOR_SUBAGENT:-#42402E}"
        render_color_line "Tool Error" "${COLOR_TOOL_ERROR:-#4A2A1F}"

        # Show status icons alongside
        echo ""
        printf "    %-14s %s  %s  %s  %s  %s  %s  %s\n" \
            "Status icons" \
            "${STATUS_ICON_PROCESSING:-🟠}" \
            "${STATUS_ICON_PERMISSION:-🔴}" \
            "${STATUS_ICON_COMPLETE:-🟢}" \
            "${STATUS_ICON_IDLE:-🟣}" \
            "${STATUS_ICON_COMPACTING:-🔄}" \
            "${STATUS_ICON_SUBAGENT:-🔀}" \
            "${STATUS_ICON_TOOL_ERROR:-❌}"
    fi

    # =========================================================================
    # FACE PREVIEW
    # =========================================================================
    if [[ -z "$section_filter" || "$section_filter" == "--faces" ]]; then
        local _default_faces_val="true"
        if [[ "${ENABLE_ANTHROPOMORPHISING:-$_default_faces_val}" == "true" ]]; then
            cli_section "Face Preview (agent: ${TAVS_AGENT:-claude})"

            # Show first face from each state array
            _show_face "Processing" "FACES_PROCESSING"
            _show_face "Permission" "FACES_PERMISSION"
            _show_face "Complete" "FACES_COMPLETE"
            _show_face "Compacting" "FACES_COMPACTING"
            _show_face "Subagent" "FACES_SUBAGENT"
            _show_face "Tool Error" "FACES_TOOL_ERROR"
            _show_face "Reset" "FACES_RESET"
            _show_face "Idle (0)" "FACES_IDLE_0"
        fi
    fi

    # =========================================================================
    # CONFIG FILES
    # =========================================================================
    if [[ -z "$section_filter" ]]; then
        cli_section "Configuration"

        printf "    %-20s %s\n" "Defaults" "$TAVS_ROOT/src/config/defaults.conf"
        printf "    %-20s %s\n" "User config" "$TAVS_USER_CONFIG"

        if [[ -f "$TAVS_USER_CONFIG" ]]; then
            printf "    %-20s %s overrides\n" "Active settings" "$_override_count"
        else
            printf "    %-20s %s\n" "Active settings" "(no user config — using defaults)"
        fi

        local _default_agent="claude"
        printf "    %-20s %s\n" "Agent" "${TAVS_AGENT:-$_default_agent}"
    fi

    echo ""
}

# Helper: show a face from a named array variable
_show_face() {
    local label="$1"
    local array_var="$2"

    # Use eval to access the array by name
    local face
    eval "face=\"\${${array_var}[0]:-}\""

    if [[ -n "$face" ]]; then
        printf "    %-14s %s\n" "$label" "$face"
    fi
}
