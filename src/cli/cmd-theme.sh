#!/bin/bash
# ==============================================================================
# TAVS CLI — theme command
# ==============================================================================
# Usage: tavs theme [name] [--preview] [--help]
#
# Quick theme switching. Lists available themes or applies one.
# ==============================================================================

source "$CLI_DIR/cli-utils.sh"
source "$CLI_DIR/aliases.sh"

# Extract description from a theme .conf file header
_get_theme_description() {
    local theme_file="$1"
    # Look for "# Description:" line in the first 10 lines
    local desc
    desc=$(head -10 "$theme_file" | grep -i '# Description:' | sed 's/^#[[:space:]]*Description:[[:space:]]*//')
    if [[ -n "$desc" ]]; then
        echo "$desc"
    else
        echo "(no description)"
    fi
}

# List all available themes
_list_themes() {
    local themes_dir="$TAVS_ROOT/src/themes"
    if [[ ! -d "$themes_dir" ]]; then
        cli_error "Themes directory not found: $themes_dir"
        return 1
    fi

    cli_bold "Available themes:"
    echo ""

    local theme_file theme_name desc
    for theme_file in "$themes_dir"/*.conf; do
        [[ -f "$theme_file" ]] || continue
        theme_name=$(basename "$theme_file" .conf)
        desc=$(_get_theme_description "$theme_file")

        # Mark active theme
        local marker="  "
        if [[ "${THEME_MODE:-}" == "preset" ]] && [[ "${THEME_PRESET:-}" == "$theme_name" ]]; then
            marker="* "
        fi

        printf "  %s%-24s %s\n" "$marker" "$theme_name" "$desc"
    done

    echo ""
    if [[ "${THEME_MODE:-}" == "preset" ]] && [[ -n "${THEME_PRESET:-}" ]]; then
        cli_info "* = currently active"
    fi
    cli_info "Usage: tavs theme <name> to apply a theme"
}

# Preview all themes with color swatches
_preview_themes() {
    local themes_dir="$TAVS_ROOT/src/themes"
    if [[ ! -d "$themes_dir" ]]; then
        cli_error "Themes directory not found: $themes_dir"
        return 1
    fi

    cli_bold "Theme Color Preview (dark mode)"
    echo ""

    local theme_file theme_name
    for theme_file in "$themes_dir"/*.conf; do
        [[ -f "$theme_file" ]] || continue
        theme_name=$(basename "$theme_file" .conf)

        # Source defaults first, then theme to get colors
        (
            # Run in subshell to not pollute parent
            source "$TAVS_ROOT/src/config/defaults.conf" 2>/dev/null
            source "$theme_file" 2>/dev/null

            local _base="${DARK_BASE:-${DEFAULT_DARK_BASE:-#303446}}"
            local _proc="${DARK_PROCESSING:-${DEFAULT_DARK_PROCESSING:-#3d3b42}}"
            local _perm="${DARK_PERMISSION:-${DEFAULT_DARK_PERMISSION:-#3d3440}}"
            local _comp="${DARK_COMPLETE:-${DEFAULT_DARK_COMPLETE:-#374539}}"
            local _idle="${DARK_IDLE:-${DEFAULT_DARK_IDLE:-#3d3850}}"

            printf "  %-24s " "$theme_name"
            render_swatch "$_base"
            printf " "
            render_swatch "$_proc"
            printf " "
            render_swatch "$_perm"
            printf " "
            render_swatch "$_comp"
            printf " "
            render_swatch "$_idle"
            echo ""
        )
    done

    echo ""
    cli_info "Labels: base | processing | permission | complete | idle"
}

cmd_theme() {
    # Handle --help
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        cat <<'EOF'
tavs theme — List or apply theme presets

Usage:
  tavs theme              List available themes
  tavs theme <name>       Apply a theme preset
  tavs theme --preview    Show color swatches for all themes

Available themes:
  catppuccin-frappe, catppuccin-latte, catppuccin-macchiato, catppuccin-mocha,
  nord, dracula, solarized-dark, solarized-light, tokyo-night

Examples:
  tavs theme nord         Apply the Nord theme
  tavs theme --preview    Preview all theme colors
EOF
        return 0
    fi

    # Load current config for status display
    if [[ -f "$TAVS_ROOT/src/config/defaults.conf" ]]; then
        source "$TAVS_ROOT/src/config/defaults.conf" 2>/dev/null
    fi
    load_user_config 2>/dev/null || true

    # Handle --preview
    if [[ "${1:-}" == "--preview" ]]; then
        _preview_themes
        return $?
    fi

    # No args: list themes
    if [[ $# -eq 0 ]]; then
        _list_themes
        return 0
    fi

    # Apply theme
    local theme_name="$1"
    local theme_file="$TAVS_ROOT/src/themes/${theme_name}.conf"

    if [[ ! -f "$theme_file" ]]; then
        cli_error "Unknown theme: $theme_name"
        echo ""
        _list_themes
        return 1
    fi

    # Set the theme
    set_config_value "THEME_MODE" "preset"
    set_config_value "THEME_PRESET" "$theme_name"

    local desc
    desc=$(_get_theme_description "$theme_file")
    cli_success "Applied theme: $theme_name"
    cli_info "$desc"
    cli_info "Takes effect on next state change."
}
