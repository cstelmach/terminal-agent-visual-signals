#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Signals — Agent Theme System
# ==============================================================================
# Loads agent-specific faces, colors, and backgrounds.
# Each agent has its own theme bundle with face arrays for random selection.
#
# Configuration priority:
#   1. User override: ~/.terminal-visual-signals/agents/{agent}/
#   2. Source default: src/agents/{agent}/data/
#   3. Fallback: minimal faces + terminal defaults
# ==============================================================================

# Resolve paths
_AGENT_THEME_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_AGENTS_DIR="$_AGENT_THEME_SCRIPT_DIR/../agents"
_USER_AGENTS_DIR="$HOME/.terminal-visual-signals/agents"

# Track if agent theme is loaded
_AGENT_THEME_LOADED=""

# ==============================================================================
# FALLBACK FACES (Minimal theme for unknown agents)
# ==============================================================================

_set_fallback_faces() {
    FACES_PROCESSING=('(°-°)')
    FACES_PERMISSION=('(°□°)')
    FACES_COMPLETE=('(^‿^)')
    FACES_COMPACTING=('(@_@)')
    FACES_RESET=('(-_-)')
    FACES_IDLE_0=('(•‿•)')
    FACES_IDLE_1=('(‿‿)')
    FACES_IDLE_2=('(︶‿︶)')
    FACES_IDLE_3=('(¬‿¬)')
    FACES_IDLE_4=('(-.-)zzZ')
    FACES_IDLE_5=('(︶.︶)ᶻᶻ')
}

# ==============================================================================
# FACE LOADING
# ==============================================================================

# Load faces.conf for the specified agent
# Usage: load_agent_faces [agent_id]
load_agent_faces() {
    local agent="${1:-$TAVS_AGENT}"
    agent="${agent:-claude}"

    # Reset to fallback first
    _set_fallback_faces

    # Try user override first
    local user_faces="$_USER_AGENTS_DIR/$agent/faces.conf"
    if [[ -f "$user_faces" ]]; then
        # shellcheck source=/dev/null
        source "$user_faces"
        _AGENT_THEME_LOADED="$agent:user"
        return 0
    fi

    # Try source default
    local source_faces="$_AGENTS_DIR/$agent/data/faces.conf"
    if [[ -f "$source_faces" ]]; then
        # shellcheck source=/dev/null
        source "$source_faces"
        _AGENT_THEME_LOADED="$agent:source"
        return 0
    fi

    # Keep fallback faces
    _AGENT_THEME_LOADED="$agent:fallback"
    return 0
}

# ==============================================================================
# COLOR LOADING
# ==============================================================================

# Load colors.conf for the specified agent (optional overrides)
# Usage: load_agent_colors [agent_id]
load_agent_colors() {
    local agent="${1:-$TAVS_AGENT}"
    agent="${agent:-claude}"

    # Try user override first
    local user_colors="$_USER_AGENTS_DIR/$agent/colors.conf"
    if [[ -f "$user_colors" ]]; then
        # shellcheck source=/dev/null
        source "$user_colors"
        return 0
    fi

    # Try source default
    local source_colors="$_AGENTS_DIR/$agent/data/colors.conf"
    if [[ -f "$source_colors" ]]; then
        # shellcheck source=/dev/null
        source "$source_colors"
        return 0
    fi

    # No agent-specific colors - use global defaults
    return 0
}

# ==============================================================================
# RANDOM FACE SELECTION
# ==============================================================================

# Get a random face for the given state
# Usage: get_random_face <state>
# Returns: A face string, randomly selected from the array for that state
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

    # Use eval for Bash 3.2 compatibility (macOS default)
    local count
    eval "count=\${#${array_name}[@]}"
    if [[ $count -eq 0 ]]; then
        echo ""
        return
    fi
    local index=$((RANDOM % count))
    eval "echo \"\${${array_name}[$index]}\""
}

# ==============================================================================
# BACKGROUND PATH RESOLUTION
# ==============================================================================

# Get the background image path for the given state
# Usage: get_agent_background_path <state> [mode]
# Returns: Path to background image or empty string if not found
get_agent_background_path() {
    local state="$1"
    local mode="${2:-dark}"  # dark or light
    local agent="${TAVS_AGENT:-claude}"

    # Map state to filename
    local filename
    case "$state" in
        processing|permission|complete|compacting|reset)
            filename="${state}.png"
            ;;
        idle_*)
            filename="idle.png"  # Use single idle image for all stages
            ;;
        idle)
            filename="idle.png"
            ;;
        *)
            filename="default.png"
            ;;
    esac

    # Priority 1: User agent override with mode
    local path="$_USER_AGENTS_DIR/$agent/backgrounds/$mode/$filename"
    if [[ -f "$path" ]]; then
        echo "$path"
        return 0
    fi

    # Priority 2: User agent override without mode
    path="$_USER_AGENTS_DIR/$agent/backgrounds/$filename"
    if [[ -f "$path" ]]; then
        echo "$path"
        return 0
    fi

    # Priority 3: Source agent data with mode
    path="$_AGENTS_DIR/$agent/data/backgrounds/$mode/$filename"
    if [[ -f "$path" ]]; then
        echo "$path"
        return 0
    fi

    # Priority 4: Source agent data without mode
    path="$_AGENTS_DIR/$agent/data/backgrounds/$filename"
    if [[ -f "$path" ]]; then
        echo "$path"
        return 0
    fi

    # Priority 5: Global user backgrounds (legacy location)
    path="$HOME/.terminal-visual-signals/backgrounds/$mode/$filename"
    if [[ -f "$path" ]]; then
        echo "$path"
        return 0
    fi

    # No image found
    echo ""
    return 1
}

# ==============================================================================
# INITIALIZATION
# ==============================================================================

# Initialize agent theme (call after TAVS_AGENT is set)
# Usage: init_agent_theme [agent_id]
init_agent_theme() {
    local agent="${1:-$TAVS_AGENT}"
    agent="${agent:-claude}"

    # Load faces and colors
    load_agent_faces "$agent"
    load_agent_colors "$agent"
}

# Auto-initialize if TAVS_AGENT is already set and faces not loaded
if [[ -n "$TAVS_AGENT" ]] && [[ -z "$_AGENT_THEME_LOADED" ]]; then
    init_agent_theme "$TAVS_AGENT"
fi
