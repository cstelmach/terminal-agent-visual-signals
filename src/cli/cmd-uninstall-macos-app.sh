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
source "$CLI_DIR/login-item-doctor.sh"

_TAVS_APP_DEST="${TAVS_APP_DEST_OVERRIDE:-/Applications/TAVS.app}"

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
  5. Sweeps for stale debug login items (runs even if the bundle is
     already gone, so leftover registrations can always be cleaned)

What it preserves:
  - ~/.tavs/user.conf (your settings)
  - ~/.tavs/schedule.json (your schedule rules)
  - All other ~/.tavs/ files
EOF
        return 0
    fi

    # Bundle missing is NOT an early exit: a stale login item (e.g. a debug
    # binary registered before the 127e648 policy gate) can outlive the bundle
    # and must still be cleaned up.
    if [[ ! -d "$_TAVS_APP_DEST" ]]; then
        cli_info "TAVS.app is not installed at $_TAVS_APP_DEST"
        cli_bold "Checking for leftover TAVS login items..."
        if pgrep -x TAVSApp &>/dev/null; then
            echo "  Stopping running TAVSApp process..."
            killall TAVSApp 2>/dev/null || true
            sleep 1
        fi
        _tavs_login_item_doctor
        local orphan_mute_state="$HOME/.tavs/mute.state"
        if [[ -f "$orphan_mute_state" ]]; then
            rm -f "$orphan_mute_state"
            echo "  Removed mute.state (shells will resume normal painting)"
        fi
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

    # Sweep for stale login items (debug binaries etc.) now that the real
    # registration is gone.
    _tavs_login_item_doctor

    echo ""
    cli_success "TAVS.app uninstalled."
    cli_info "Your settings (~/.tavs/user.conf) and schedule (~/.tavs/schedule.json) are preserved."
    cli_info "To reinstall: tavs install macos-app"
}
