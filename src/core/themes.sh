#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — Face Themes (Legacy Compatibility)
# ==============================================================================
# This file provides backward compatibility for code using the old get_face()
# function. New code should use get_random_face() from agent-theme.sh instead.
#
# The old system (deprecated):
#   - Single face per state per theme
#   - Generic themes: minimal, bear, cat, lenny, shrug, plain
#   - Claude themes: claudA-F
#
# The new system (agent-theme.sh):
#   - Multiple faces per state (randomly selected)
#   - Agent-specific themes (claude, gemini, opencode, codex)
#   - Faces defined in src/agents/{agent}/data/faces.conf
#
# Migration: Replace get_face "$FACE_THEME" "$state" with get_random_face "$state"
# ==============================================================================

# Legacy face accessor function (DEPRECATED)
# Usage: get_face <theme> <state>
# Returns: ASCII face for the given theme and state
#
# DEPRECATED: Use get_random_face() from agent-theme.sh instead.
# This function exists only for backward compatibility during migration.
get_face() {
    local theme="$1"
    local state="$2"

    # If agent-theme.sh is loaded, delegate to it
    if type get_random_face &>/dev/null; then
        get_random_face "$state"
        return
    fi

    # Fallback to minimal faces for backward compatibility
    case "$state" in
        processing)  echo "(°-°)" ;;
        permission)  echo "(°□°)" ;;
        complete)    echo "(^‿^)" ;;
        compacting)  echo "(@_@)" ;;
        reset)       echo "(-_-)" ;;
        idle_0)      echo "(•‿•)" ;;
        idle_1)      echo "(‿‿)" ;;
        idle_2)      echo "(︶‿︶)" ;;
        idle_3)      echo "(¬‿¬)" ;;
        idle_4)      echo "(-.-)zzZ" ;;
        idle_5)      echo "(︶.︶)ᶻᶻ" ;;
        idle)        echo "(‿‿)" ;;
        *)           echo "" ;;
    esac
}
