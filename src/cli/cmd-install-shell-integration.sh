#!/bin/bash
# ==============================================================================
# TAVS CLI — install shell-integration
# ==============================================================================
# Usage: tavs install shell-integration [--remove] [--help]
#
# Installs src/shell/tavs-shellrc.sh to ~/.tavs/shellrc and appends a fenced
# source block to ~/.zshrc (and ~/.bashrc when present). The shellrc registers
# every interactive terminal's TTY for the broadcaster and self-paints the
# lock/pause visual at shell open (all-terminal coverage, spec D4).
# ==============================================================================

source "$CLI_DIR/cli-utils.sh"

_TAVS_SHELLRC_SRC="$TAVS_ROOT/src/shell/tavs-shellrc.sh"
_TAVS_SHELLRC_DEST="$HOME/.tavs/shellrc"
_TAVS_FENCE_BEGIN="# >>> tavs shell integration >>>"
_TAVS_FENCE_END="# <<< tavs shell integration <<<"

_tavs_shell_rc_files() {
    # zshrc is always a target (created if missing: zsh is the macOS default
    # shell). bashrc only when the user already has one.
    echo "$HOME/.zshrc"
    [[ -f "$HOME/.bashrc" ]] && echo "$HOME/.bashrc"
    return 0
}

_tavs_fence_present() {
    [[ -f "$1" ]] && grep -qF "$_TAVS_FENCE_BEGIN" "$1"
}

_tavs_append_fence() {
    local rc="$1"
    if _tavs_fence_present "$rc"; then
        echo "  Already integrated: $rc"
        return 0
    fi
    {
        echo ""
        echo "$_TAVS_FENCE_BEGIN"
        # shellcheck disable=SC2016
        echo '[[ -r "$HOME/.tavs/shellrc" ]] && source "$HOME/.tavs/shellrc"'
        echo "$_TAVS_FENCE_END"
    } >> "$rc"
    echo "  Added source block: $rc"
}

_tavs_remove_fence() {
    local rc="$1"
    _tavs_fence_present "$rc" || return 0
    local tmp
    tmp=$(mktemp)
    # Delete the fenced block inclusive; keep everything else byte-identical.
    sed "/^$_TAVS_FENCE_BEGIN\$/,/^$_TAVS_FENCE_END\$/d" "$rc" > "$tmp"
    mv "$tmp" "$rc"
    echo "  Removed source block: $rc"
}

cmd_install_shell_integration() {
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        cat <<'EOF'
tavs install shell-integration — All-terminal coverage for lock/pause visuals

Usage:
  tavs install shell-integration            Install (idempotent, re-run to update)
  tavs install shell-integration --remove   Remove the rc blocks and ~/.tavs/shellrc

What it does:
  1. Copies the TAVS shellrc to ~/.tavs/shellrc
  2. Adds a fenced source block to ~/.zshrc (and ~/.bashrc if present)

Every new interactive terminal then registers itself with TAVS and paints the
current lock/pause state immediately at open, even without any agent session.
Cost: native helper calls at shell startup; latency depends on runtime and cached targets.
EOF
        return 0
    fi

    if [[ "${1:-}" == "--remove" ]]; then
        cli_bold "Removing TAVS shell integration..."
        local rc
        while IFS= read -r rc; do
            _tavs_remove_fence "$rc"
        done < <(_tavs_shell_rc_files)
        if [[ -f "$_TAVS_SHELLRC_DEST" ]]; then
            rm -f "$_TAVS_SHELLRC_DEST"
            echo "  Removed $_TAVS_SHELLRC_DEST"
        fi
        cli_success "Shell integration removed. Open terminals keep their current shell."
        return 0
    fi

    if [[ ! -f "$_TAVS_SHELLRC_SRC" ]]; then
        cli_error "Source shellrc not found: $_TAVS_SHELLRC_SRC"
        return 1
    fi

    cli_bold "Installing TAVS shell integration..."
    mkdir -p "$HOME/.tavs"
    cp "$_TAVS_SHELLRC_SRC" "$_TAVS_SHELLRC_DEST"
    echo "  Installed $_TAVS_SHELLRC_DEST"

    local rc
    while IFS= read -r rc; do
        _tavs_append_fence "$rc"
    done < <(_tavs_shell_rc_files)

    echo ""
    cli_success "Shell integration installed."
    cli_info "New terminals register + self-paint from now on. Re-run after TAVS updates,"
    cli_info "or use ./tavs sync (it refreshes ~/.tavs/shellrc too)."
}
