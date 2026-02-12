#!/bin/bash
# ==============================================================================
# TAVS CLI — install command
# ==============================================================================
# Usage: tavs install <agent> [--help]
#
# Installs TAVS hooks for a specific agent. Delegates to agent-specific
# install scripts in src/install/.
# ==============================================================================

source "$CLI_DIR/cli-utils.sh"

cmd_install() {
    # Handle --help
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        cat <<'EOF'
tavs install — Install TAVS for an agent

Usage:
  tavs install <agent>    Install hooks for a specific agent
  tavs install            List available agents

Agents:
  gemini    Install for Gemini CLI (8 events, full support)
  codex     Install for Codex CLI (1 event, limited support)

Note: Claude Code uses the plugin system — no manual install needed.
      OpenCode uses an npm package — see docs for setup.
EOF
        return 0
    fi

    local install_dir="$TAVS_ROOT/src/install"

    # No args: list available agents
    if [[ $# -eq 0 ]]; then
        cli_bold "Available agents for installation:"
        echo ""
        echo "  gemini    Gemini CLI (full support, 8 events)"
        echo "  codex     Codex CLI (limited, 1 event)"
        echo ""
        cli_info "Usage: tavs install <agent>"
        cli_info "Claude Code uses the plugin system (no manual install needed)."
        return 0
    fi

    local agent="$1"

    # Validate agent name against known agents (prevents path traversal)
    case "$agent" in
        gemini|codex) ;;
        *)
            cli_error "Unknown agent: $agent"
            echo ""
            echo "Available agents: gemini, codex"
            return 1
            ;;
    esac

    local script="$install_dir/install-${agent}.sh"

    if [[ ! -f "$script" ]]; then
        cli_error "Install script not found: $script"
        return 1
    fi

    # Delegate to the agent-specific installer
    bash "$script"
}
