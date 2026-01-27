#!/bin/bash
# ==============================================================================
# Codex CLI Trigger - Agent-Specific Entry Point
# ==============================================================================
# Sets agent identifier and delegates to unified core trigger.
# This enables agent-specific theming (colors, faces, settings).
#
# NOTE: Codex CLI has limited hook support (completion event only).
# ==============================================================================

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Set agent identifier for theme loading
export TAVS_AGENT="codex"

# Delegate to core trigger
exec "$SCRIPT_DIR/../../core/trigger.sh" "$@"
