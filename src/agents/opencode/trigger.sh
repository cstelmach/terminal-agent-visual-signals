#!/bin/bash
# OpenCode trigger - delegates to unified core trigger
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
exec "$SCRIPT_DIR/../../core/trigger.sh" "$@"
