#!/bin/bash
# ==============================================================================
# Claude Code Trigger - Agent-Specific Entry Point
# ==============================================================================
# Sets agent identifier, extracts permission mode from hook JSON payload,
# and delegates to unified core trigger.
# This enables agent-specific theming (colors, faces, settings) and
# mode-aware processing colors (plan, acceptEdits, bypassPermissions).
# ==============================================================================

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Set agent identifier for theme loading
export TAVS_AGENT="claude"

# Capture stdin (JSON payload from Claude Code hooks) with short timeout
# Non-blocking: if no stdin available, proceed with defaults
_tavs_stdin=""
if read -t 0.1 -r _tavs_line 2>/dev/null; then
    _tavs_stdin="$_tavs_line"
    while read -t 0.01 -r _tavs_line 2>/dev/null; do
        _tavs_stdin="${_tavs_stdin}${_tavs_line}"
    done
fi

# Extract permission_mode from JSON without jq dependency
# Matches: "permission_mode":"value" or "permission_mode": "value"
if [[ -n "$_tavs_stdin" ]]; then
    _mode=$(printf '%s' "$_tavs_stdin" | \
        sed -n 's/.*"permission_mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    [[ -n "$_mode" ]] && export TAVS_PERMISSION_MODE="$_mode"
fi
export TAVS_PERMISSION_MODE="${TAVS_PERMISSION_MODE:-default}"

# Pass raw payload for debug logging in core trigger
export _TAVS_HOOK_PAYLOAD="$_tavs_stdin"

# Delegate to core trigger (not exec — stdin already consumed for mode extraction)
"$SCRIPT_DIR/../../core/trigger.sh" "$@"
