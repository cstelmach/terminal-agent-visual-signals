#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Signals - Spinner Module
# ==============================================================================
# Manages animated spinner frames for processing state eye display.
# Used when TAVS_TITLE_MODE="full" to replace face eyes with spinners.
# ==============================================================================

# Session spinner state file location
# Uses TTY_SAFE which should be set by terminal.sh before sourcing this
get_session_spinner_file() {
    echo "/tmp/terminal-visual-signals.session-spinner.${TTY_SAFE:-unknown}"
}

# ==============================================================================
# Session Identity Management
# ==============================================================================

# Initialize session identity with random selections
# Called at SessionStart/reset when TAVS_SESSION_IDENTITY="true"
init_session_spinner() {
    [[ "$TAVS_SESSION_IDENTITY" != "true" ]] && return 0

    local session_file
    session_file=$(get_session_spinner_file)

    # Available styles (excluding 'random' which is resolved here)
    local styles=("braille" "circle" "block" "eye-animate" "none")
    # Available eye modes
    local eye_modes=("sync" "opposite" "stagger" "clockwise" "counter" "mirror" "mirror_inv")

    # Pick random style and mode for this session
    local style="${styles[$RANDOM % ${#styles[@]}]}"
    local eye_mode="${eye_modes[$RANDOM % ${#eye_modes[@]}]}"

    # Store session choices
    {
        echo "STYLE=$style"
        echo "EYE_MODE=$eye_mode"
        echo "LEFT_INDEX=0"
        echo "RIGHT_INDEX=0"
    } > "$session_file"
}

# Reset/cleanup spinner state
reset_spinner() {
    local session_file index_file
    session_file=$(get_session_spinner_file)
    index_file=$(get_spinner_index_file)
    rm -f "$session_file" 2>/dev/null || true
    rm -f "$index_file" 2>/dev/null || true
}

# ==============================================================================
# Spinner Frame Management
# ==============================================================================

# Spinner index file (separate from session file for simple index tracking)
get_spinner_index_file() {
    echo "/tmp/terminal-visual-signals.spinner-idx.${TTY_SAFE:-unknown}"
}

# Get current spinner eyes for processing state
# Returns: "left_char right_char" (e.g., "⠋ ⠙" or "◐ ◑")
# Special returns:
#   "FACE_VARIANT" - Signal to caller to use existing face selection (none style)
get_spinner_eyes() {
    local style eye_mode left_idx right_idx
    local session_file index_file
    session_file=$(get_session_spinner_file)
    index_file=$(get_spinner_index_file)

    # Load session identity or use config
    if [[ -f "$session_file" ]]; then
        source "$session_file"
        style="${STYLE:-braille}"
        eye_mode="${EYE_MODE:-sync}"
        left_idx="${LEFT_INDEX:-0}"
        right_idx="${RIGHT_INDEX:-0}"
    else
        # Use config values, resolving "random" if needed
        style="${TAVS_SPINNER_STYLE:-random}"
        eye_mode="${TAVS_SPINNER_EYE_MODE:-random}"

        # Load index from simple index file
        if [[ -f "$index_file" ]]; then
            left_idx=$(cat "$index_file" 2>/dev/null || echo "0")
        else
            left_idx=0
        fi
        right_idx=0

        # Resolve "random" selections (but keep consistent within session if possible)
        if [[ "$style" == "random" ]]; then
            local styles=("braille" "circle" "block" "eye-animate" "none")
            style="${styles[$RANDOM % ${#styles[@]}]}"
        fi
        if [[ "$eye_mode" == "random" ]]; then
            local eye_modes=("sync" "opposite" "stagger" "clockwise" "counter" "mirror" "mirror_inv")
            eye_mode="${eye_modes[$RANDOM % ${#eye_modes[@]}]}"
        fi
    fi

    # Handle "none" style - signal to use existing face selection
    if [[ "$style" == "none" ]]; then
        echo "FACE_VARIANT"
        return 0
    fi

    # Handle "eye-animate" style - random eye from variety pool
    if [[ "$style" == "eye-animate" ]]; then
        local eye_chars=("${TAVS_SPINNER_FRAMES_EYE_ANIMATE[@]}")
        if [[ ${#eye_chars[@]} -eq 0 ]]; then
            # Fallback if not defined
            eye_chars=("•" "◦" "·" "°" "○" "◌" "◎" "●" "◉" "⊙" "⊚" "⦿")
        fi
        local left_eye="${eye_chars[$RANDOM % ${#eye_chars[@]}]}"
        local right_eye="${eye_chars[$RANDOM % ${#eye_chars[@]}]}"
        echo "$left_eye $right_eye"
        return 0
    fi

    # Get frames array based on style
    local frames=()
    case "$style" in
        braille)
            frames=("${TAVS_SPINNER_FRAMES_BRAILLE[@]}")
            [[ ${#frames[@]} -eq 0 ]] && frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
            ;;
        circle)
            frames=("${TAVS_SPINNER_FRAMES_CIRCLE[@]}")
            [[ ${#frames[@]} -eq 0 ]] && frames=("○" "◔" "◑" "◕" "●" "◕" "◑" "◔")
            ;;
        block)
            frames=("${TAVS_SPINNER_FRAMES_BLOCK[@]}")
            [[ ${#frames[@]} -eq 0 ]] && frames=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█" "▇" "▆" "▅" "▄" "▃" "▂")
            ;;
        *)
            # Default to braille
            frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
            ;;
    esac

    local frame_count=${#frames[@]}
    [[ $frame_count -eq 0 ]] && frame_count=1  # Safety

    # Calculate eye positions based on sync mode
    local left_frame right_frame
    case "$eye_mode" in
        sync)
            # Both eyes same frame
            left_frame="${frames[$left_idx]}"
            right_frame="${frames[$left_idx]}"
            right_idx=$left_idx
            ;;
        opposite)
            # Eyes half-cycle apart (opposite states)
            right_idx=$(( (left_idx + frame_count/2) % frame_count ))
            left_frame="${frames[$left_idx]}"
            right_frame="${frames[$right_idx]}"
            ;;
        stagger)
            # Right eye is 2 frames behind left
            right_idx=$(( (left_idx - 2 + frame_count) % frame_count ))
            left_frame="${frames[$left_idx]}"
            right_frame="${frames[$right_idx]}"
            ;;
        clockwise)
            # Both rotate clockwise (standard direction)
            left_frame="${frames[$left_idx]}"
            right_frame="${frames[$left_idx]}"
            right_idx=$left_idx
            ;;
        counter)
            # Both rotate counter-clockwise (use CCW array if available)
            local ccw_frames=("${TAVS_SPINNER_FRAMES_BRAILLE_CCW[@]}")
            if [[ ${#ccw_frames[@]} -gt 0 && "$style" == "braille" ]]; then
                left_frame="${ccw_frames[$left_idx]}"
                right_frame="${ccw_frames[$left_idx]}"
            else
                # Fallback: reverse index
                local rev_idx=$(( (frame_count - 1 - left_idx + frame_count) % frame_count ))
                left_frame="${frames[$rev_idx]}"
                right_frame="${frames[$rev_idx]}"
            fi
            right_idx=$left_idx
            ;;
        mirror)
            # Left increases, right decreases
            right_idx=$(( (frame_count - left_idx) % frame_count ))
            left_frame="${frames[$left_idx]}"
            right_frame="${frames[$right_idx]}"
            ;;
        mirror_inv)
            # Left decreases, right increases
            local temp_idx=$(( (frame_count - left_idx) % frame_count ))
            left_frame="${frames[$temp_idx]}"
            right_frame="${frames[$left_idx]}"
            ;;
        *)
            # Default: sync
            left_frame="${frames[$left_idx]}"
            right_frame="${frames[$left_idx]}"
            right_idx=$left_idx
            ;;
    esac

    echo "$left_frame $right_frame"

    # Advance index for next call
    local next_left=$(( (left_idx + 1) % frame_count ))

    # Update state for next call
    if [[ -f "$session_file" ]]; then
        # Use sed to update session file in place (macOS compatible)
        sed -i '' "s/^LEFT_INDEX=.*/LEFT_INDEX=$next_left/" "$session_file" 2>/dev/null || true
        sed -i '' "s/^RIGHT_INDEX=.*/RIGHT_INDEX=$right_idx/" "$session_file" 2>/dev/null || true
    else
        # Use simple index file when session identity not active
        echo "$next_left" > "$index_file" 2>/dev/null || true
    fi
}

# ==============================================================================
# Utility Functions
# ==============================================================================

# Get single spinner character (for ENABLE_ANTHROPOMORPHISING=false mode)
# Returns first character from spinner eyes
get_single_spinner() {
    local eyes
    eyes=$(get_spinner_eyes)

    if [[ "$eyes" == "FACE_VARIANT" ]]; then
        # No spinner for "none" style
        echo ""
    else
        # Return first character (left eye)
        echo "${eyes%% *}"
    fi
}

# Check if spinner is active for current configuration
is_spinner_active() {
    [[ "$TAVS_TITLE_MODE" == "full" ]] && return 0
    return 1
}
