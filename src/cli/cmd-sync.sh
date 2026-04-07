#!/bin/bash
# ==============================================================================
# TAVS CLI — sync command
# ==============================================================================
# Usage: tavs sync [--help]
#
# Developer tool: copies source files to the Claude Code plugin cache.
# Only needed after code changes — user.conf changes take effect immediately.
# ==============================================================================

source "$CLI_DIR/cli-utils.sh"

cmd_sync() {
    # Handle --help
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        cat <<'EOF'
tavs sync — Sync source to plugin installations (developer tool)

Usage:
  tavs sync               Copy source files to all plugin installations

Copies core modules, config, and agent adapter to both the Claude Code
plugin cache and marketplace directories. Only needed after modifying
source code — changes to ~/.tavs/user.conf take effect immediately.

Sync targets:
  ~/.claude/plugins/cache/terminal-agent-visual-signals/tavs/<version>/
  ~/.claude/plugins/marketplaces/terminal-agent-visual-signals/
EOF
        return 0
    fi

    local synced_any=false

    # --- Target 1: Plugin cache ---
    local cache_base="$HOME/.claude/plugins/cache/terminal-agent-visual-signals/tavs"
    local cache_dir=""
    if [[ -d "$cache_base/$TAVS_VERSION" ]]; then
        cache_dir="$cache_base/$TAVS_VERSION"
    elif [[ -d "$cache_base" ]]; then
        local latest
        latest=$(ls -1d "$cache_base"/*/ 2>/dev/null | tail -1) || true
        [[ -n "$latest" ]] && cache_dir="${latest%/}"
    fi

    if [[ -n "$cache_dir" && -d "$cache_dir" ]]; then
        _sync_to_target "$cache_dir" "plugin cache"
        synced_any=true
    fi

    # --- Target 2: Marketplace installation ---
    local market_dir="$HOME/.claude/plugins/marketplaces/terminal-agent-visual-signals"
    if [[ -d "$market_dir/src/core" ]]; then
        _sync_to_target "$market_dir" "marketplace"
        synced_any=true
    fi

    if [[ "$synced_any" != "true" ]]; then
        cli_error "No plugin installation found"
        cli_info "Is the TAVS plugin installed? Try: claude plugin install tavs@terminal-agent-visual-signals"
        return 1
    fi

    echo ""
    cli_success "Plugin cache synced. Submit a prompt to test."
}

# Internal: sync source files to a target directory
_sync_to_target() {
    local target_dir="$1"
    local target_name="$2"

    echo "Syncing source → $target_name"
    echo "  From: $TAVS_ROOT"
    echo "  To:   $target_dir"
    echo ""

    # Core modules
    if [[ -d "$target_dir/src/core" ]]; then
        cp "$TAVS_ROOT/src/core/"*.sh "$target_dir/src/core/"
        echo "  Synced src/core/*.sh"
    fi

    # Config files
    mkdir -p "$target_dir/src/config"
    cp "$TAVS_ROOT/src/config/"*.conf "$target_dir/src/config/" 2>/dev/null
    echo "  Synced src/config/*.conf"

    # Claude agent adapter
    if [[ -d "$target_dir/src/agents/claude" ]]; then
        cp "$TAVS_ROOT/src/agents/claude/trigger.sh" "$target_dir/src/agents/claude/"
        echo "  Synced src/agents/claude/trigger.sh"
    fi

    # Theme files
    if [[ -d "$target_dir/src/themes" ]]; then
        cp "$TAVS_ROOT/src/themes/"*.conf "$target_dir/src/themes/" 2>/dev/null
        echo "  Synced src/themes/*.conf"
    fi

    echo ""
}
