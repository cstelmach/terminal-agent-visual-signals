#!/bin/bash
# ==============================================================================
# TAVS CLI — uninstall macos-app
# ==============================================================================
# Usage: tavs uninstall macos-app [--help]
#
# Removes TAVS.app from /Applications, unregisters the login item.
# Preserves ~/.tavs/ (schedule, user config) entirely.
# ==============================================================================

source "$CLI_DIR/cli-utils.sh"

_TAVS_APP_DEST="/Applications/TAVS.app"

cmd_uninstall_macos_app() {
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        cat <<'EOF'
tavs uninstall macos-app — Remove the TAVS menu bar companion

Usage:
  tavs uninstall macos-app

What it does:
  1. Stops TAVS.app if running
  2. Unregisters the login item (no longer starts at login)
  3. Removes /Applications/TAVS.app
  4. Removes mute.state (so shells resume normal painting)

What it preserves:
  - ~/.tavs/user.conf (your settings)
  - ~/.tavs/schedule.json (your schedule rules)
  - All other ~/.tavs/ files
EOF
        return 0
    fi

    if [[ ! -d "$_TAVS_APP_DEST" ]]; then
        cli_info "TAVS.app is not installed at $_TAVS_APP_DEST"
        return 0
    fi

    cli_bold "Uninstalling TAVS.app..."

    # Stop the app
    if pgrep -x TAVSApp &>/dev/null; then
        echo "  Stopping TAVS.app..."
        killall TAVSApp 2>/dev/null || true
        sleep 1
    fi

    local app_binary="$_TAVS_APP_DEST/Contents/MacOS/TAVSApp"
    if [[ -x "$app_binary" ]]; then
        echo "  Unregistering login item..."
        if ! "$app_binary" --unregister-login-item &>/dev/null; then
            cli_info "Login item unregister failed; continuing with app removal."
        fi
    fi

    # Remove mute.state so shells resume immediately
    local mute_state="$HOME/.tavs/mute.state"
    if [[ -f "$mute_state" ]]; then
        rm -f "$mute_state"
        echo "  Removed mute.state (shells will resume normal painting)"
    fi

    # Clean up runtime dir pending caches
    local runtime_dir="/tmp/tavs-$(id -u)"
    if [[ -d "$runtime_dir/pending" ]]; then
        rm -rf "$runtime_dir/pending"
        echo "  Cleaned pending cache"
    fi

    # Remove the app bundle
    rm -rf "$_TAVS_APP_DEST"
    echo "  Removed $_TAVS_APP_DEST"

    echo ""
    cli_success "TAVS.app uninstalled."
    cli_info "Your settings (~/.tavs/user.conf) and schedule (~/.tavs/schedule.json) are preserved."
    cli_info "To reinstall: tavs install macos-app"
}
