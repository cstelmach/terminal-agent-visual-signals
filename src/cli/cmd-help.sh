#!/bin/bash
# ==============================================================================
# TAVS CLI — help command
# ==============================================================================
# Usage: tavs help [command]
#
# Shows general help or command-specific help.
# ==============================================================================

source "$CLI_DIR/cli-utils.sh"

cmd_help() {
    local topic="${1:-}"

    # No topic: show general help (same as tavs with no args)
    if [[ -z "$topic" || "$topic" == "--help" || "$topic" == "-h" ]]; then
        # Re-use the main usage display from the tavs dispatcher
        cat <<'EOF'
tavs - Terminal Agent Visual Signals CLI

Usage: tavs <command> [options]

Commands:
  set <key> [value]     Set a configuration value (interactive if no value)
  status                Show current configuration with visual preview
  wizard                Run interactive configuration wizard
  theme [name]          List or apply a theme preset
  test [--quick]        Test visual signals in current terminal
  migrate               Migrate old config to v3 format
  config <action>       Manage configuration (show, edit, reset, validate)
  install <agent>       Install TAVS for an agent (gemini, codex)
  sync                  Sync source to plugin cache (developer tool)
  help [command]        Show help for a command
  version               Show version information

Quick Start:
  tavs set theme nord              Set theme to Nord preset
  tavs set title-mode full         Enable full title control
  tavs set faces off               Disable ASCII faces
  tavs status                      Show current config with preview
  tavs wizard                      Run full configuration wizard

See 'tavs help <command>' for more information on a specific command.
EOF
        return 0
    fi

    # Topic-specific help: delegate to the command's --help
    # Validate topic contains only lowercase letters and hyphens (no path traversal)
    local _sanitized_topic="${topic//[a-z-]/}"
    if [[ -n "$_sanitized_topic" ]]; then
        cli_error "Invalid command name: $topic"
        cli_info "Run 'tavs help' for a list of commands."
        return 1
    fi

    local cmd_file="$CLI_DIR/cmd-${topic}.sh"
    if [[ -f "$cmd_file" ]]; then
        source "$cmd_file"
        "cmd_${topic}" --help
    else
        cli_error "Unknown command: $topic"
        cli_info "Run 'tavs help' for a list of commands."
        return 1
    fi
}
