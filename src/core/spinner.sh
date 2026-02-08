#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — Spinner Module
# ==============================================================================
# Manages animated spinner frames for processing state eye display.
# Used when TAVS_TITLE_MODE="full" to replace face eyes with spinners.
# ==============================================================================

# ==============================================================================
# SECURE STATE FILE LOCATION
# ==============================================================================
# Uses XDG_RUNTIME_DIR if available (Linux, user-only writable), otherwise
# falls back to user's home directory cache to avoid /tmp security issues.
# ==============================================================================

get_spinner_state_dir() {
    local state_dir
    if [[ -n "$XDG_RUNTIME_DIR" && -d "$XDG_RUNTIME_DIR" ]]; then
        # Linux: use XDG runtime dir (per-user, secure)
        state_dir="$XDG_RUNTIME_DIR/tavs"
    else
        # macOS/fallback: use user cache directory
        state_dir="${HOME}/.cache/tavs"
    fi

    # Create directory if it doesn't exist (with secure permissions)
    if [[ ! -d "$state_dir" ]]; then
        mkdir -p "$state_dir" 2>/dev/null
        chmod 700 "$state_dir" 2>/dev/null
    fi

    echo "$state_dir"
}

# Session spinner state file location
get_session_spinner_file() {
    local state_dir
    state_dir=$(get_spinner_state_dir)
    echo "${state_dir}/session-spinner.${TTY_SAFE:-unknown}"
}

# Spinner index file (separate from session file for simple index tracking)
get_spinner_index_file() {
    local state_dir
    state_dir=$(get_spinner_state_dir)
    echo "${state_dir}/spinner-idx.${TTY_SAFE:-unknown}"
}

# ==============================================================================
# SAFE FILE PARSING
# ==============================================================================
# Parse key=value files safely without sourcing (prevents code injection)
# ==============================================================================

# Read a value from a key=value file safely
# Usage: read_state_value "filename" "KEY"
read_state_value() {
    local file="$1"
    local key="$2"
    local value=""

    [[ ! -f "$file" ]] && return 1

    # Read file line by line, match key, extract value
    while IFS='=' read -r k v; do
        # Strip any quotes from value
        v="${v%\"}"
        v="${v#\"}"
        if [[ "$k" == "$key" ]]; then
            value="$v"
            break
        fi
    done < "$file"

    echo "$value"
}

# Validate that a value is a non-negative integer
# Returns 0 if valid, 1 if invalid
validate_integer() {
    local val="$1"
    [[ "$val" =~ ^[0-9]+$ ]]
}

# ==============================================================================
# ATOMIC FILE OPERATIONS
# ==============================================================================
# Cross-platform atomic writes using temp file + mv pattern
# ==============================================================================

# Write state file atomically (cross-platform)
# Usage: write_state_file "filename" "STYLE" "EYE_MODE" "LEFT_INDEX" "RIGHT_INDEX"
write_state_file() {
    local file="$1"
    local style="$2"
    local eye_mode="$3"
    local left_idx="$4"
    local right_idx="$5"

    local tmp_file="${file}.tmp.$$"

    {
        echo "STYLE=$style"
        echo "EYE_MODE=$eye_mode"
        echo "LEFT_INDEX=$left_idx"
        echo "RIGHT_INDEX=$right_idx"
    } > "$tmp_file" 2>/dev/null

    # Atomic rename (cross-platform)
    mv "$tmp_file" "$file" 2>/dev/null || {
        rm -f "$tmp_file" 2>/dev/null
        return 1
    }

    return 0
}

# Write simple index file atomically
write_index_file() {
    local file="$1"
    local index="$2"

    local tmp_file="${file}.tmp.$$"
    echo "$index" > "$tmp_file" 2>/dev/null
    mv "$tmp_file" "$file" 2>/dev/null || {
        rm -f "$tmp_file" 2>/dev/null
        return 1
    }
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

    # Store session choices atomically
    write_state_file "$session_file" "$style" "$eye_mode" "0" "0"
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

# Get current spinner eyes for processing state
# Returns: "left_char right_char" (e.g., "⠋ ⠙" or "◐ ◑")
# Special returns:
#   "FACE_VARIANT" - Signal to caller to use existing face selection (none style)
get_spinner_eyes() {
    local style eye_mode left_idx right_idx
    local session_file index_file
    local need_cache_random=false

    session_file=$(get_session_spinner_file)
    index_file=$(get_spinner_index_file)

    # Load session identity or use config
    if [[ -f "$session_file" ]]; then
        # Safe parsing - read values without sourcing
        style=$(read_state_value "$session_file" "STYLE")
        eye_mode=$(read_state_value "$session_file" "EYE_MODE")
        left_idx=$(read_state_value "$session_file" "LEFT_INDEX")
        right_idx=$(read_state_value "$session_file" "RIGHT_INDEX")

        # Apply defaults for missing values
        style="${style:-braille}"
        eye_mode="${eye_mode:-sync}"
        left_idx="${left_idx:-0}"
        right_idx="${right_idx:-0}"
    else
        # Use config values, resolving "random" if needed
        style="${TAVS_SPINNER_STYLE:-random}"
        eye_mode="${TAVS_SPINNER_EYE_MODE:-random}"

        # Load index from simple index file
        if [[ -f "$index_file" ]]; then
            left_idx=$(cat "$index_file" 2>/dev/null)
        else
            left_idx=0
        fi
        right_idx=0

        # Resolve "random" selections and cache them for consistency
        # This prevents jarring style changes on every call
        if [[ "$style" == "random" || "$eye_mode" == "random" ]]; then
            need_cache_random=true
            if [[ "$style" == "random" ]]; then
                local styles=("braille" "circle" "block" "eye-animate" "none")
                style="${styles[$RANDOM % ${#styles[@]}]}"
            fi
            if [[ "$eye_mode" == "random" ]]; then
                local eye_modes=("sync" "opposite" "stagger" "clockwise" "counter" "mirror" "mirror_inv")
                eye_mode="${eye_modes[$RANDOM % ${#eye_modes[@]}]}"
            fi
        fi
    fi

    # Validate index is a non-negative integer
    if ! validate_integer "$left_idx"; then
        left_idx=0
    fi
    if ! validate_integer "$right_idx"; then
        right_idx=0
    fi

    # Handle "none" style - signal to use existing face selection
    if [[ "$style" == "none" ]]; then
        # Cache the resolved style if random was used
        if [[ "$need_cache_random" == "true" ]]; then
            write_state_file "$session_file" "$style" "$eye_mode" "$left_idx" "$right_idx"
        fi
        echo "FACE_VARIANT"
        return 0
    fi

    # Handle "eye-animate" style - random eye from variety pool
    # NOTE: This style intentionally selects random eyes each call for variety,
    # rather than animating through a sequence like other styles.
    if [[ "$style" == "eye-animate" ]]; then
        local eye_chars=("${TAVS_SPINNER_FRAMES_EYE_ANIMATE[@]}")
        if [[ ${#eye_chars[@]} -eq 0 ]]; then
            # Fallback if not defined
            eye_chars=("•" "◦" "·" "°" "○" "◌" "◎" "●" "◉" "⊙" "⊚" "⦿")
        fi
        local left_eye="${eye_chars[$RANDOM % ${#eye_chars[@]}]}"
        local right_eye="${eye_chars[$RANDOM % ${#eye_chars[@]}]}"

        # Cache the resolved style if random was used
        if [[ "$need_cache_random" == "true" ]]; then
            write_state_file "$session_file" "$style" "$eye_mode" "0" "0"
        fi

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

    # Ensure index is within bounds (handles corrupted state files)
    left_idx=$(( left_idx % frame_count ))

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
                local ccw_idx=$(( left_idx % ${#ccw_frames[@]} ))
                left_frame="${ccw_frames[$ccw_idx]}"
                right_frame="${ccw_frames[$ccw_idx]}"
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

    # Update state for next call (atomic write, cross-platform)
    if [[ -f "$session_file" || "$need_cache_random" == "true" ]]; then
        # Use full state file (session identity or cached random)
        write_state_file "$session_file" "$style" "$eye_mode" "$next_left" "$right_idx"
    else
        # Use simple index file when session identity not active
        write_index_file "$index_file" "$next_left"
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
