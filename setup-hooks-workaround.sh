#!/usr/bin/env bash
# setup-hooks-workaround.sh
# Workaround for Claude Code plugin hooks bug (Issue #14410)
# Run with --install to set up, --uninstall to remove
#
# This creates a stable symlink + auto-updater that survives plugin version updates.
# The SessionStart hook automatically updates the symlink if version changed.

set -euo pipefail

STABLE_LINK="$HOME/.claude/hooks/tavs-current"
PLUGIN_BASE="$HOME/.claude/plugins/cache/tavs/tavs"
HOOKS_DIR="$HOME/.claude/hooks"

print_hooks_json() {
    cat << 'HOOKS_EOF'

Add these hooks to ~/.claude/settings.json (merge with existing hooks).
Put visual signal hooks FIRST in each category for immediate feedback.

"hooks": {
  "Notification": [
    {
      "matcher": "permission_prompt",
      "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/tavs-current/scripts/claude-code-visual-signal.sh permission" }]
    },
    {
      "matcher": "idle_prompt",
      "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/tavs-current/scripts/claude-code-visual-signal.sh idle" }]
    }
  ],
  "PermissionRequest": [
    {
      "matcher": "*",
      "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/tavs-current/scripts/claude-code-visual-signal.sh permission" }]
    }
  ],
  "PostToolUse": [
    {
      "matcher": "*",
      "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/tavs-current/scripts/claude-code-visual-signal.sh processing" }]
    }
  ],
  "PreCompact": [
    {
      "matcher": "auto",
      "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/tavs-current/scripts/claude-code-visual-signal.sh compacting" }]
    },
    {
      "matcher": "manual",
      "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/tavs-current/scripts/claude-code-visual-signal.sh compacting" }]
    }
  ],
  "SessionEnd": [
    {
      "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/tavs-current/scripts/claude-code-visual-signal.sh reset" }]
    }
  ],
  "SessionStart": [
    {
      "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/tavs-session-start.sh" }]
    }
  ],
  "Stop": [
    {
      "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/tavs-current/scripts/claude-code-visual-signal.sh complete" }]
    }
  ],
  "UserPromptSubmit": [
    {
      "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/tavs-current/scripts/claude-code-visual-signal.sh processing" }]
    }
  ]
}

HOOKS_EOF
}

create_session_start_script() {
    cat > "$HOOKS_DIR/tavs-session-start.sh" << 'SESSION_EOF'
#!/usr/bin/env bash
# Auto-updates symlink if plugin version changed, then calls reset
# Runs once per session - very fast if symlink already current

STABLE_LINK="$HOME/.claude/hooks/tavs-current"
PLUGIN_BASE="$HOME/.claude/plugins/cache/tavs/tavs"

# Find current installed version
VERSION_DIR=$(find "$PLUGIN_BASE" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -1)

if [[ -n "$VERSION_DIR" && -d "$VERSION_DIR/scripts" ]]; then
    # Check if symlink needs update
    if [[ -L "$STABLE_LINK" ]]; then
        CURRENT_TARGET=$(readlink "$STABLE_LINK")
        if [[ "$CURRENT_TARGET" != "$VERSION_DIR" ]]; then
            # Version changed - update symlink
            rm -f "$STABLE_LINK"
            ln -s "$VERSION_DIR" "$STABLE_LINK"
        fi
    elif [[ ! -e "$STABLE_LINK" ]]; then
        # Symlink missing - create it
        ln -s "$VERSION_DIR" "$STABLE_LINK"
    fi
fi

# Call reset script
if [[ -x "$STABLE_LINK/scripts/claude-code-visual-signal.sh" ]]; then
    exec "$STABLE_LINK/scripts/claude-code-visual-signal.sh" reset
fi
SESSION_EOF
    chmod +x "$HOOKS_DIR/tavs-session-start.sh"
}

do_install() {
    echo "Setting up TAVS workaround..."
    echo ""

    # Check if plugin is installed
    if [[ ! -d "$PLUGIN_BASE" ]]; then
        echo "Error: Plugin not found at $PLUGIN_BASE"
        echo ""
        echo "Install the plugin first:"
        echo "  claude plugin marketplace add cstelmach/tavs"
        echo "  claude plugin install tavs@tavs"
        exit 1
    fi

    VERSION_DIR=$(find "$PLUGIN_BASE" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -1)

    if [[ -z "$VERSION_DIR" ]]; then
        echo "Error: No version directory found in $PLUGIN_BASE"
        exit 1
    fi

    VERSION=$(basename "$VERSION_DIR")

    # Create initial symlink
    if [[ -L "$STABLE_LINK" ]]; then
        rm -f "$STABLE_LINK"
    elif [[ -e "$STABLE_LINK" ]]; then
        echo "Error: $STABLE_LINK exists but is not a symlink. Remove it manually."
        exit 1
    fi
    ln -s "$VERSION_DIR" "$STABLE_LINK"
    echo "✓ Created symlink: tavs-current → $VERSION"

    # Create session start script (auto-updates symlink on version change)
    create_session_start_script
    echo "✓ Created auto-updater: tavs-session-start.sh"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "NEXT STEP: Add hooks to ~/.claude/settings.json"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_hooks_json
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "After adding hooks, restart Claude Code."
    echo ""
    echo "The symlink auto-updates on SessionStart when plugin version changes."
    echo "When bug #14410 is fixed, run: $0 --uninstall"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

do_uninstall() {
    echo "Removing TAVS workaround..."
    echo ""

    # Remove symlink
    if [[ -L "$STABLE_LINK" ]]; then
        rm -f "$STABLE_LINK"
        echo "✓ Removed symlink: tavs-current"
    else
        echo "✓ Symlink already removed"
    fi

    # Remove session start script
    if [[ -f "$HOOKS_DIR/tavs-session-start.sh" ]]; then
        rm -f "$HOOKS_DIR/tavs-session-start.sh"
        echo "✓ Removed auto-updater: tavs-session-start.sh"
    else
        echo "✓ Auto-updater already removed"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "NEXT STEP: Remove hooks from ~/.claude/settings.json"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Remove all hooks containing 'tavs' from:"
    echo "  • Notification (permission_prompt, idle_prompt)"
    echo "  • PermissionRequest"
    echo "  • PostToolUse"
    echo "  • PreCompact (auto, manual)"
    echo "  • SessionEnd"
    echo "  • SessionStart"
    echo "  • Stop"
    echo "  • UserPromptSubmit"
    echo ""
    echo "After removing hooks, restart Claude Code."
    echo "Native plugin hooks should now work (if bug #14410 is fixed)."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

show_help() {
    echo "Usage: $0 [--install|--uninstall|--help]"
    echo ""
    echo "Workaround for Claude Code plugin hooks bug (Issue #14410)"
    echo "Creates a stable symlink that auto-updates when plugin version changes."
    echo ""
    echo "Options:"
    echo "  --install    Set up workaround (default)"
    echo "  --uninstall  Remove workaround"
    echo "  --help       Show this help"
}

# Main
case "${1:---install}" in
    --install|-i)
        do_install
        ;;
    --uninstall|-u|--remove)
        do_uninstall
        ;;
    --help|-h)
        show_help
        ;;
    *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
