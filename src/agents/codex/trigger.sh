#!/bin/bash
# Codex CLI trigger - delegates to unified core trigger
# NOTE: Codex CLI does not have hooks yet. This is a placeholder.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
exec "$SCRIPT_DIR/../../core/trigger.sh" "$@"
