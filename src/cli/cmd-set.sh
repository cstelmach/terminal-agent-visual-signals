#!/bin/bash
# ==============================================================================
# TAVS CLI — set command
# ==============================================================================
# Usage: tavs set <key> [value]
#
# Quick config for TAVS settings. Supports friendly aliases (e.g., "theme",
# "faces") and raw variable names (e.g., "TAVS_TITLE_MODE").
#
# When value is omitted, shows an interactive picker for valid options.
# Compound aliases (e.g., "theme") set multiple variables at once.
# ==============================================================================

source "$CLI_DIR/cli-utils.sh"
source "$CLI_DIR/aliases.sh"

# Handle compound alias: title-preset
# Sets TAVS_TITLE_PRESET (preset expansion happens at load time in theme-config-loader.sh)
_handle_title_preset_set() {
    local value="$1"

    if [[ -z "$value" ]]; then
        local presets_str
        presets_str=$(get_valid_values "TAVS_TITLE_PRESET")
        local presets
        IFS=' ' read -ra presets <<< "$presets_str"
        value=$(interactive_pick "Select title preset" "${presets[@]}") || return 1
    fi

    if ! validate_value "TAVS_TITLE_PRESET" "$value"; then
        cli_error "Unknown preset: $value"
        echo "  Valid options: $(get_valid_values "TAVS_TITLE_PRESET")"
        return 1
    fi

    set_config_value "TAVS_TITLE_PRESET" "$value"
    case "$value" in
        compact)
            cli_success "Set title-preset = compact (emoji eyes + guillemet identity)"
            ;;
        compact_project_sorted)
            cli_success "Set title-preset = compact_project_sorted (dir flag + guillemet info group)"
            ;;
        dashboard)
            cli_success "Set title-preset = dashboard (text faces + info group)"
            ;;
    esac
    cli_info "Takes effect on next state change."
}

# Handle compound alias: theme
# Sets both THEME_PRESET and THEME_MODE
_handle_theme_set() {
    local value="$1"

    if [[ -z "$value" ]]; then
        # Interactive: pick from available themes
        local themes_str
        themes_str=$(get_valid_values "THEME_PRESET")
        local themes
        IFS=' ' read -ra themes <<< "$themes_str"
        value=$(interactive_pick "Select theme preset" "${themes[@]}") || return 1
    fi

    # Validate the theme name
    if ! validate_value "THEME_PRESET" "$value"; then
        cli_error "Unknown theme: $value"
        echo ""
        echo "Available themes:"
        local themes_str
        themes_str=$(get_valid_values "THEME_PRESET")
        local t
        for t in $themes_str; do
            echo "  $t"
        done
        return 1
    fi

    # Set both variables
    set_config_value "THEME_MODE" "preset"
    set_config_value "THEME_PRESET" "$value"
    cli_success "Set theme to $value (takes effect on next state change)"
}

# Main set command
cmd_set() {
    # Handle --help
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        cat <<'EOF'
tavs set — Set a configuration value

Usage:
  tavs set <key> <value>    Set directly
  tavs set <key>            Interactive picker (if valid values defined)
  tavs set                  List all available settings

Aliases:
EOF
        list_aliases_with_descriptions
        return 0
    fi

    # No args: show available settings
    if [[ $# -eq 0 ]]; then
        cli_bold "Available settings:"
        echo ""
        list_aliases_with_descriptions
        echo ""
        cli_info "Usage: tavs set <key> [value]"
        cli_info "Omit value for interactive picker. Raw variable names also work."
        return 0
    fi

    local key="$1"
    local value="${2:-}"

    # Resolve the alias
    local resolved
    resolved=$(resolve_alias "$key") || {
        cli_error "Unknown setting: $key"
        echo ""
        echo "Available settings:"
        list_aliases_with_descriptions
        return 1
    }

    # Handle compound aliases
    if is_compound_alias "$resolved"; then
        case "$key" in
            theme)
                _handle_theme_set "$value"
                return $?
                ;;
            title-preset)
                _handle_title_preset_set "$value"
                return $?
                ;;
            *)
                cli_error "Unsupported compound alias: $key"
                return 1
                ;;
        esac
    fi

    # Simple alias: resolved is a variable name
    local var="$resolved"

    # If no value provided, try interactive picker
    if [[ -z "$value" ]]; then
        local valid_str
        valid_str=$(get_valid_values "$var")

        if [[ -n "$valid_str" ]]; then
            local valid_opts
            IFS=' ' read -ra valid_opts <<< "$valid_str"

            # Show current value
            local current
            current=$(get_config_value "$var")
            if [[ -n "$current" ]]; then
                cli_info "Current value: $current"
            fi

            value=$(interactive_pick "Select value for $key" "${valid_opts[@]}") || return 1
        else
            cli_error "No value specified and no valid options defined for $key"
            cli_info "Usage: tavs set $key <value>"
            return 1
        fi
    fi

    # Validate value (if validation rules exist)
    if ! validate_value "$var" "$value"; then
        cli_error "Invalid value for $key: $value"
        local valid_str
        valid_str=$(get_valid_values "$var")
        if [[ -n "$valid_str" ]]; then
            echo "  Valid options: $valid_str"
        fi
        return 1
    fi

    # Set the value
    set_config_value "$var" "$value"

    # Friendly description for confirmation
    local desc
    desc=$(get_description "$key")
    cli_success "Set $key = $value"
    cli_info "$desc"
    cli_info "Takes effect on next state change."
}
