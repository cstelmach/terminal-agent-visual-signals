#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Signals - Face Selection Module
# ==============================================================================
# Provides agent-specific face selection with randomization.
# Extracted from theme.sh for modularization.
#
# Public functions:
#   get_random_face()        - Get random face for current state/agent
#   _resolve_agent_faces()   - Resolve agent-specific face arrays
#
# Dependencies:
#   - FACES_* arrays must be populated (by _resolve_agent_faces or config)
#   - UNKNOWN_FACES_* arrays for fallback (from defaults.conf)
#
# Usage:
#   source face-selection.sh
#   _resolve_agent_faces "claude"  # Populate FACES_* from CLAUDE_FACES_*
#   face=$(get_random_face "processing")
# ==============================================================================

# ==============================================================================
# AGENT FACE RESOLUTION
# ==============================================================================

# Resolve AGENT_FACES_* arrays to generic FACES_* arrays
# E.g., CLAUDE_FACES_PROCESSING -> FACES_PROCESSING when agent=claude
# Usage: _resolve_agent_faces <agent>
_resolve_agent_faces() {
    local agent="$1"
    # Convert to uppercase for prefix (Bash 3.2 compatible)
    local prefix
    prefix="$(echo "$agent" | tr '[:lower:]' '[:upper:]')_"  # CLAUDE_, GEMINI_, etc.

    # Face states to resolve
    local states=(
        PROCESSING PERMISSION COMPLETE COMPACTING RESET
        IDLE_0 IDLE_1 IDLE_2 IDLE_3 IDLE_4 IDLE_5
    )

    local state count

    for state in "${states[@]}"; do
        # Check if agent-specific array exists and has elements
        eval "count=\${#${prefix}FACES_${state}[@]}"

        if [[ $count -gt 0 ]]; then
            # Copy agent-specific faces to generic
            eval "FACES_${state}=(\"\${${prefix}FACES_${state}[@]}\")"
        else
            # Fall back to UNKNOWN agent faces
            eval "count=\${#UNKNOWN_FACES_${state}[@]}"
            if [[ $count -gt 0 ]]; then
                eval "FACES_${state}=(\"\${UNKNOWN_FACES_${state}[@]}\")"
            else
                # Ultimate fallback: minimal face
                case "$state" in
                    PROCESSING)  eval "FACES_${state}=('(°-°)')" ;;
                    PERMISSION)  eval "FACES_${state}=('(°□°)')" ;;
                    COMPLETE)    eval "FACES_${state}=('(^‿^)')" ;;
                    COMPACTING)  eval "FACES_${state}=('(@_@)')" ;;
                    RESET)       eval "FACES_${state}=('(-_-)')" ;;
                    IDLE_0)      eval "FACES_${state}=('(•‿•)')" ;;
                    IDLE_1)      eval "FACES_${state}=('(‿‿)')" ;;
                    IDLE_2)      eval "FACES_${state}=('(︶‿︶)')" ;;
                    IDLE_3)      eval "FACES_${state}=('(¬‿¬)')" ;;
                    IDLE_4)      eval "FACES_${state}=('(-.-)zzZ')" ;;
                    IDLE_5)      eval "FACES_${state}=('(︶.︶)ᶻᶻ')" ;;
                esac
            fi
        fi
    done
}

# ==============================================================================
# RANDOM FACE SELECTION
# ==============================================================================

# Get a random face for the given state
# Usage: get_random_face <state>
# Returns: A face string appropriate for the state
get_random_face() {
    local state="$1"
    local array_name

    # Map state to array name
    case "$state" in
        processing) array_name="FACES_PROCESSING" ;;
        permission) array_name="FACES_PERMISSION" ;;
        complete)   array_name="FACES_COMPLETE" ;;
        compacting) array_name="FACES_COMPACTING" ;;
        reset)      array_name="FACES_RESET" ;;
        idle_0)     array_name="FACES_IDLE_0" ;;
        idle_1)     array_name="FACES_IDLE_1" ;;
        idle_2)     array_name="FACES_IDLE_2" ;;
        idle_3)     array_name="FACES_IDLE_3" ;;
        idle_4)     array_name="FACES_IDLE_4" ;;
        idle_5)     array_name="FACES_IDLE_5" ;;
        idle)       array_name="FACES_IDLE_1" ;;  # Default idle to stage 1
        *)          echo ""; return ;;
    esac

    # Get array count and select random element
    local count
    eval "count=\${#${array_name}[@]}"
    if [[ $count -eq 0 ]]; then
        echo ""
        return
    fi
    local index=$((RANDOM % count))
    eval "echo \"\${${array_name}[$index]}\""
}
