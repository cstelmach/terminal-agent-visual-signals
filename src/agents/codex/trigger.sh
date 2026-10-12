#!/bin/bash
# ==============================================================================
# Codex CLI Trigger - Agent-Specific Entry Point
# ==============================================================================
# Extracts completion metadata and delegates fixed states to unified core trigger.
# This enables agent-specific theming (colors, faces, settings).
#
# NOTE: Codex CLI has limited hook support (completion event only).
# ==============================================================================

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Set agent identifier for theme loading
export TAVS_AGENT="codex"

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
# notify appends one JSON argument; a here-string keeps the intake exports in this shell.
_tavs_organizer_intake codex "$PPID" <<< "${2:-}" || :

exec "$SCRIPT_DIR/../../core/trigger.sh" "${_tavs_args[@]}" </dev/null
