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
tavs sync — Sync source to plugin cache (developer tool)

Usage:
  tavs sync               Copy source files to plugin cache

Copies core modules, config, and agent adapter to the Claude Code plugin
cache directory. Only needed after modifying source code — changes to
~/.tavs/user.conf take effect immediately without syncing.

Cache location:
  ~/.claude/plugins/cache/terminal-agent-visual-signals/tavs/<version>/
EOF
        return 0
    fi

    local cache_base="$HOME/.claude/plugins/cache/terminal-agent-visual-signals/tavs"

    # Find the installed version directory
    local cache_dir=""
    if [[ -d "$cache_base/$TAVS_VERSION" ]]; then
        cache_dir="$cache_base/$TAVS_VERSION"
    elif [[ -d "$cache_base" ]]; then
        # Try to find any version directory
        local latest
        latest=$(ls -1d "$cache_base"/*/ 2>/dev/null | tail -1) || true
        if [[ -n "$latest" ]]; then
            cache_dir="${latest%/}"
        fi
    fi

    if [[ -z "$cache_dir" || ! -d "$cache_dir" ]]; then
        cli_error "Plugin cache not found at: $cache_base/"
        cli_info "Is the TAVS plugin installed? Try: claude plugin install tavs@terminal-agent-visual-signals"
        return 1
    fi

    echo "Syncing source → plugin cache"
    echo "  From: $TAVS_ROOT"
    echo "  To:   $cache_dir"
    echo ""

    # Core modules
    if [[ -d "$cache_dir/src/core" ]]; then
        cp "$TAVS_ROOT/src/core/"*.sh "$cache_dir/src/core/"
        echo "  Synced src/core/*.sh"
    fi

    # Config files
    mkdir -p "$cache_dir/src/config"
    cp "$TAVS_ROOT/src/config/"*.conf "$cache_dir/src/config/" 2>/dev/null
    echo "  Synced src/config/*.conf"

    # Claude agent adapter
    if [[ -d "$cache_dir/src/agents/claude" ]]; then
        cp "$TAVS_ROOT/src/agents/claude/trigger.sh" "$cache_dir/src/agents/claude/"
        echo "  Synced src/agents/claude/trigger.sh"
    fi

    # Theme files
    if [[ -d "$cache_dir/src/themes" ]]; then
        cp "$TAVS_ROOT/src/themes/"*.conf "$cache_dir/src/themes/" 2>/dev/null
        echo "  Synced src/themes/*.conf"
    fi

    echo ""
    cli_success "Plugin cache synced. Submit a prompt to test."
}
