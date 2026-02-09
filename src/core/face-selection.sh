#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — Face Selection Module
# ==============================================================================
# Provides agent-specific face selection with randomization.
# Extracted from theme-config-loader.sh for modularization.
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

    # Security: Validate agent name to prevent shell injection via eval
    # Only allow known agents or alphanumeric names
    case "$agent" in
        claude|gemini|codex|opencode|unknown) ;;  # Known agents - OK
        *)
            # Reject any name with non-alphanumeric characters
            if [[ ! "$agent" =~ ^[a-zA-Z0-9_]+$ ]]; then
                echo "Warning: Invalid agent name '$agent', using 'unknown'" >&2
                agent="unknown"
            fi
            ;;
    esac

    # Convert to uppercase for prefix (Bash 3.2 compatible)
    local prefix
    prefix="$(echo "$agent" | tr '[:lower:]' '[:upper:]')_"  # CLAUDE_, GEMINI_, etc.

    # Face states to resolve
    local states=(
        PROCESSING PERMISSION COMPLETE COMPACTING RESET
        IDLE_0 IDLE_1 IDLE_2 IDLE_3 IDLE_4 IDLE_5
        SUBAGENT TOOL_ERROR
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
                    SUBAGENT)    eval "FACES_${state}=('(⇆-⇆)')" ;;
                    TOOL_ERROR)  eval "FACES_${state}=('(✕_✕)')" ;;
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
        subagent*)  array_name="FACES_SUBAGENT" ;;
        tool_error) array_name="FACES_TOOL_ERROR" ;;
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
    # Use [@]:offset:1 slice syntax for zsh compatibility (zsh arrays are 1-based,
    # so direct ${arr[0]} returns empty; slice syntax works in both shells)
    eval "echo \"\${${array_name}[@]:$index:1}\""
}

# ==============================================================================
# COMPACT FACE SELECTION (Emoji Eyes)
# ==============================================================================
# Returns a face with emoji eyes from compact theme pools.
# Embeds state info (emoji color) and optionally subagent count in the face.
#
# Usage: get_compact_face <state>
# Returns: Face with emoji eyes (e.g., "Ǝ[🟠 🟠]E" or "Ǝ[🔶 +2]E")
# ==============================================================================

get_compact_face() {
    local state="$1"
    local theme="${TAVS_COMPACT_THEME:-semantic}"
    local theme_upper
    theme_upper="$(echo "$theme" | tr '[:lower:]' '[:upper:]')"

    # Map state to array suffix (Bash 3.2 compatible - use tr instead of ^^)
    local state_upper
    case "$state" in
        processing) state_upper="PROCESSING" ;;
        permission) state_upper="PERMISSION" ;;
        complete)   state_upper="COMPLETE" ;;
        compacting) state_upper="COMPACTING" ;;
        reset)      state_upper="RESET" ;;
        idle_0)     state_upper="IDLE_0" ;;
        idle_1)     state_upper="IDLE_1" ;;
        idle_2)     state_upper="IDLE_2" ;;
        idle_3)     state_upper="IDLE_3" ;;
        idle_4)     state_upper="IDLE_4" ;;
        idle_5)     state_upper="IDLE_5" ;;
        idle)       state_upper="IDLE_1" ;;
        subagent*)  state_upper="SUBAGENT" ;;
        tool_error) state_upper="TOOL_ERROR" ;;
        *)          echo ""; return ;;
    esac

    # Look up emoji eye pool: COMPACT_SEMANTIC_PROCESSING, etc.
    local array_name="COMPACT_${theme_upper}_${state_upper}"
    local count
    eval "count=\${#${array_name}[@]}"

    if [[ $count -eq 0 ]]; then
        # Fallback: return standard face
        get_random_face "$state"
        return
    fi

    # Random pair selection from pool
    # Use [@]:offset:1 slice for zsh compatibility (1-based arrays)
    local index=$((RANDOM % count))
    local pair
    eval "pair=\"\${${array_name}[@]:$index:1}\""
    local left="${pair%% *}"
    local right="${pair##* }"

    # Override right eye with subagent count when active
    if [[ "$state" == "processing" || "$state" == subagent* ]]; then
        if type has_active_subagents &>/dev/null && has_active_subagents 2>/dev/null; then
            local agent_count
            agent_count=$(get_subagent_count 2>/dev/null)
            [[ $agent_count -gt 0 ]] && right="+${agent_count}"
        fi
    fi

    # Substitute into agent frame template (reuses spinner face frames)
    local _default_frame='[{L} {R}]'
    local frame="${SPINNER_FACE_FRAME:-$_default_frame}"
    local face
    face="${frame//\{L\}/$left}"
    face="${face//\{R\}/$right}"
    echo "$face"
}
