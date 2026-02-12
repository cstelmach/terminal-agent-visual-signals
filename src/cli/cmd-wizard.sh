#!/bin/bash
# ==============================================================================
# TAVS CLI — wizard command
# ==============================================================================
# Usage: tavs wizard [--help]
#
# Launches the interactive 7-step configuration wizard.
# Delegates to src/wizard/configure.sh (the existing wizard orchestrator).
# ==============================================================================

source "$CLI_DIR/cli-utils.sh"

cmd_wizard() {
    # Handle --help
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        cat <<'EOF'
tavs wizard — Interactive configuration wizard

Usage:
  tavs wizard             Run the full 7-step wizard
  tavs wizard --list      List available theme presets
  tavs wizard --current   Show current configuration
  tavs wizard --reset     Reset to default configuration

The wizard guides you through:
  Step 1: Operating mode (static, dynamic, preset)
  Step 2: Theme preset selection
  Step 3: Light/dark mode auto-detection
  Step 4: ASCII faces (anthropomorphising)
  Step 5: Stylish backgrounds (images)
  Step 6: Terminal title mode
  Step 7: Palette theming (OSC 4)

Creates user configuration in ~/.tavs/user.conf
EOF
        return 0
    fi

    local wizard_script="$TAVS_ROOT/src/wizard/configure.sh"
    if [[ ! -f "$wizard_script" ]]; then
        cli_error "Wizard not found at: $wizard_script"
        cli_info "Is TAVS installed correctly?"
        return 1
    fi

    # Delegate to the wizard with any remaining arguments
    bash "$wizard_script" "$@"
}
