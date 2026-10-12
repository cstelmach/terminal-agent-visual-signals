#!/bin/bash
# ==============================================================================
# Claude Code Trigger - Agent-Specific Entry Point
# ==============================================================================
# Sets agent identifier, extracts allowlisted metadata from hook JSON,
# and delegates to unified core trigger.
# This enables agent-specific theming (colors, faces, settings) and
# mode-aware processing colors (plan, acceptEdits, bypassPermissions).
# ==============================================================================

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Set agent identifier for theme loading
export TAVS_AGENT="claude"

case "${1:-}" in
    processing|permission|complete|idle|compacting|reset|subagent-start|subagent-stop|tool_error) ;;
    *) printf 'tavs: unsupported hook state\n' >&2; exit 1 ;;
esac
_tavs_args=("$1")
case "$1:${2:-}" in
    processing:new-prompt|reset:session-end) _tavs_args+=("$2") ;;
esac

unset _TAVS_HOOK_PAYLOAD
source "$SCRIPT_DIR/../../core/organizer-state.sh"
if [[ -t 0 ]]; then
    _tavs_organizer_intake claude "$PPID" </dev/null || :
else
    _tavs_organizer_intake claude "$PPID" || :
fi

exec "$SCRIPT_DIR/../../core/trigger.sh" "${_tavs_args[@]}" </dev/null
