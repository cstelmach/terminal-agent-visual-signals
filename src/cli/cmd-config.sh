#!/bin/bash
# ==============================================================================
# TAVS CLI — config command
# ==============================================================================
# Usage: tavs config <action> [--help]
#
# Manage the user configuration file (~/.tavs/user.conf).
# ==============================================================================

source "$CLI_DIR/cli-utils.sh"

cmd_config() {
    local action="${1:-}"

    # Handle --help
    if [[ "$action" == "--help" || "$action" == "-h" ]]; then
        cat <<'EOF'
tavs config — Manage configuration file

Usage:
  tavs config show        Display current user.conf contents
  tavs config edit        Open user.conf in your editor
  tavs config reset       Backup and reset to defaults
  tavs config validate    Check for common configuration errors
  tavs config path        Print the config file path

Environment:
  $EDITOR or $VISUAL controls which editor opens (default: vi)
EOF
        return 0
    fi

    case "$action" in
        show)
            _config_show
            ;;
        edit)
            _config_edit
            ;;
        reset)
            _config_reset
            ;;
        validate)
            _config_validate
            ;;
        path)
            echo "$TAVS_USER_CONFIG"
            ;;
        "")
            cli_bold "tavs config — Manage configuration"
            echo ""
            echo "  show        Display current user.conf"
            echo "  edit        Open in editor"
            echo "  reset       Backup and reset to defaults"
            echo "  validate    Check for errors"
            echo "  path        Print config file path"
            echo ""
            cli_info "Usage: tavs config <action>"
            ;;
        *)
            cli_error "Unknown action: $action"
            cli_info "Try: tavs config --help"
            return 1
            ;;
    esac
}

_config_show() {
    if [[ -f "$TAVS_USER_CONFIG" ]]; then
        echo "# File: $TAVS_USER_CONFIG"
        echo ""
        cat "$TAVS_USER_CONFIG"
    else
        cli_info "No user configuration found (using defaults)."
        cli_info "Create one with: tavs set <key> <value>"
        cli_info "Or run: tavs wizard"
    fi
}

_config_edit() {
    ensure_user_config

    local editor="${EDITOR:-${VISUAL:-vi}}"
    cli_info "Opening $TAVS_USER_CONFIG with $editor"
    "$editor" "$TAVS_USER_CONFIG"
}

_config_reset() {
    if [[ ! -f "$TAVS_USER_CONFIG" ]]; then
        cli_info "No user configuration to reset (already using defaults)."
        return 0
    fi

    echo "This will reset your configuration to defaults."
    echo "Current config: $TAVS_USER_CONFIG"
    echo ""

    if ! cli_confirm "Create backup and reset?"; then
        cli_info "Cancelled."
        return 0
    fi

    # Create backup with timestamp
    local backup="${TAVS_USER_CONFIG}.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$TAVS_USER_CONFIG" "$backup"
    rm "$TAVS_USER_CONFIG"

    cli_success "Configuration reset to defaults."
    cli_info "Backup saved: $backup"
}

_config_validate() {
    if [[ ! -f "$TAVS_USER_CONFIG" ]]; then
        cli_info "No user configuration to validate (using defaults)."
        return 0
    fi

    source "$CLI_DIR/aliases.sh"

    local errors=0
    local warnings=0

    echo "Validating: $TAVS_USER_CONFIG"
    echo ""

    # Check each active setting
    while IFS='=' read -r var value; do
        # Skip comments and empty lines
        [[ "$var" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$var" ]] && continue

        # Strip quotes from value
        value="${value%\"}"
        value="${value#\"}"

        # Try to validate
        local valid_values
        valid_values=$(get_valid_values "$var")
        if [[ -n "$valid_values" ]]; then
            if ! validate_value "$var" "$value"; then
                echo "  ERROR: $var=\"$value\" — valid: $valid_values"
                ((errors++))
            fi
        fi
    done < "$TAVS_USER_CONFIG"

    echo ""
    if [[ $errors -eq 0 ]]; then
        cli_success "No errors found."
    else
        cli_error "$errors error(s) found."
    fi

    local _count
    _count=$(count_active_settings)
    cli_info "$_count active setting(s) in config."
}
