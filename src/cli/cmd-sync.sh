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
tavs sync - Sync source to plugin installations (developer tool)

Usage:
  tavs sync               Copy source files to all plugin installations

Copies the CLI, core modules, Claude/Codex adapters, hook definitions,
Codex installer and shell integration to existing plugin installations.
Only needed after modifying source code. user.conf changes apply immediately.
Sync does not build/install the native helper. Missing render/metadata
capabilities are reported separately from successful source copying.

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
        _sync_to_target "$cache_dir" "plugin cache" || return 1
        synced_any=true
    fi

    # --- Target 2: Marketplace installation ---
    local market_dir="$HOME/.claude/plugins/marketplaces/terminal-agent-visual-signals"
    if [[ -d "$market_dir/src/core" ]]; then
        _sync_to_target "$market_dir" "marketplace" || return 1
        synced_any=true
    fi

    if [[ "$synced_any" != "true" ]]; then
        cli_error "No plugin installation found"
        cli_info "Is the TAVS plugin installed? Try: claude plugin install tavs@terminal-agent-visual-signals"
        return 1
    fi

    # --- Target 3: Installed shell integration (only when present) ---
    if [[ -f "$HOME/.tavs/shellrc" && -f "$TAVS_ROOT/src/shell/tavs-shellrc.sh" ]]; then
        cp "$TAVS_ROOT/src/shell/tavs-shellrc.sh" "$HOME/.tavs/shellrc" || return 1
        echo "  Synced ~/.tavs/shellrc"
    fi

    echo ""
    # shellcheck source=../core/organizer-state.sh
    source "$TAVS_ROOT/src/core/organizer-state.sh" || return 1
    if _tavs_managed_helper && _tavs_organizer_helper; then
        cli_success "Plugin cache synced. Submit a prompt to test."
    else
        cli_warn "Sources copied; native render/metadata helper unavailable or unsupported."
        cli_info "Sync copies sources only; it does not build/install a compatible helper."
        cli_success "Plugin cache synced."
    fi
}

# Internal: sync source files to a target directory
_sync_to_target() {
    local target_dir="$1"
    local target_name="$2"

    echo "Syncing source → $target_name"
    echo "  From: $TAVS_ROOT"
    echo "  To:   $target_dir"
    echo ""

    mkdir -p "$target_dir/src/core" "$target_dir/src/config" "$target_dir/src/cli" || return 1
    cp "$TAVS_ROOT/tavs" "$target_dir/tavs" || return 1
    local file
    for file in src/agents/claude/trigger.sh src/agents/codex/trigger.sh \
        src/agents/claude/hooks.json hooks/hooks.json src/shell/tavs-shellrc.sh src/install/install-codex.sh; do
        mkdir -p "$target_dir/${file%/*}" || return 1
        cp "$TAVS_ROOT/$file" "$target_dir/$file" || return 1
    done

    # Core modules and their required challenge data.
    cp "$TAVS_ROOT/src/core/"*.sh "$target_dir/src/core/" || return 1
    cp "$TAVS_ROOT/src/core/"*.txt "$target_dir/src/core/" || return 1
    for file in portable_helper.py portable_context.py portable_metadata.py portable_observation.py \
        portable_intent.py portable_records.py portable_record_io.py portable_render.py \
        portable_renderer.py portable_ownership.py portable_policy.py portable_device_writer.py \
        portable_process_identity.py; do
        cp "$TAVS_ROOT/src/core/$file" "$target_dir/src/core/$file" || return 1
    done
    chmod +x "$target_dir/src/core/portable_helper.py" || return 1
    echo "  Synced src/core/*.sh (+ data and ordinary helper modules)"

    # Config files
    cp "$TAVS_ROOT/src/config/"*.conf "$target_dir/src/config/" || return 1
    echo "  Synced src/config/*.conf"

    # CLI subcommands
    cp "$TAVS_ROOT/src/cli/"*.sh "$target_dir/src/cli/" || return 1
    chmod +x "$target_dir/tavs" "$target_dir/src/core/trigger.sh" \
        "$target_dir/src/agents/claude/trigger.sh" "$target_dir/src/agents/codex/trigger.sh" \
        "$target_dir/src/install/install-codex.sh" || return 1
    echo "  Synced CLI, adapters, hooks, Codex installer and shell integration"

    # Theme files
    if [[ -d "$target_dir/src/themes" ]]; then
        cp "$TAVS_ROOT/src/themes/"*.conf "$target_dir/src/themes/" || return 1
        echo "  Synced src/themes/*.conf"
    fi

    echo ""
}
