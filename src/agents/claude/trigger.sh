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

# Capture stdin (JSON payload from Claude Code hooks)
# Claude Code pipes JSON to hook commands; cat reads the full payload
# and returns when the pipe closes. [[ ! -t 0 ]] skips if stdin is a terminal.
_tavs_stdin=""
if [[ ! -t 0 ]]; then
    _tavs_stdin=$(cat 2>/dev/null)
fi

# Extract permission_mode from JSON without jq dependency
# Matches: "permission_mode":"value" or "permission_mode": "value"
if [[ -n "$_tavs_stdin" ]]; then
    _mode=$(printf '%s' "$_tavs_stdin" | \
        sed -n 's/.*"permission_mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    [[ -n "$_mode" ]] && export TAVS_PERMISSION_MODE="$_mode"

    # Extract transcript_path for context fallback estimation
    _transcript=$(printf '%s' "$_tavs_stdin" | \
        sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    [[ -n "$_transcript" ]] && export TAVS_TRANSCRIPT_PATH="$_transcript"
fi
export TAVS_PERMISSION_MODE="${TAVS_PERMISSION_MODE:-default}"

# Pass raw payload for debug logging in core trigger
export _TAVS_HOOK_PAYLOAD="$_tavs_stdin"

# Delegate to core trigger (not exec — stdin already consumed for mode extraction)
"$SCRIPT_DIR/../../core/trigger.sh" "$@"
