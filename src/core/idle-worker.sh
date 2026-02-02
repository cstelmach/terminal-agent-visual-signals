#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Themes - Idle Worker
# ==============================================================================
# Contains the logic for the background idle timer.
#
# Note: This file uses shared helper functions from palette-mode-helpers.sh:
#   - should_send_bg_color()  - Decides whether to send background color
#   - _get_palette_mode()     - Gets current palette mode (dark/light)
#
# These are sourced by trigger.sh before idle-worker.sh, so they are available.
# ==============================================================================

# Helper: Send OSC 4 palette in idle worker (using file descriptor)
# Usage: _idle_send_palette "dark" or "light" via fd 3
# Uses shared _build_osc_palette_seq from terminal.sh to avoid code duplication
_idle_send_palette() {
    local mode="$1"

    # Check if palette theming is enabled
    type should_enable_palette_theming &>/dev/null || return 0
    should_enable_palette_theming || return 0

    # Check if shared builder function is available
    type _build_osc_palette_seq &>/dev/null || return 0

    # Build and send palette sequence via fd 3
    local seq
    seq=$(_build_osc_palette_seq "$mode")
    [[ -n "$seq" ]] && printf "%b" "$seq" >&3
}

# Helper: Reset OSC 4 palette in idle worker (using file descriptor)
_idle_reset_palette() {
    type should_enable_palette_theming &>/dev/null || return 0
    should_enable_palette_theming || return 0
    printf "\033]104\033\\" >&3
}

# Calculate current stage from elapsed seconds
get_unified_stage() {
    local elapsed=$1
    local cumulative=0
    RESULT_STAGE=0

    for duration in "${UNIFIED_STAGE_DURATIONS[@]}"; do
        cumulative=$((cumulative + duration))
        if [[ $elapsed -lt $cumulative ]]; then
            return
        fi
        RESULT_STAGE=$((RESULT_STAGE + 1))
    done
}

kill_idle_timer() {
    read_session_state || return 0
    if [[ -n "$SESSION_TIMER_PID" ]] && kill -0 "$SESSION_TIMER_PID" 2>/dev/null; then
        kill "$SESSION_TIMER_PID" 2>/dev/null || true
        [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] kill_idle_timer: killed PID $SESSION_TIMER_PID" >> "$IDLE_DEBUG_LOG"
    fi
}

cleanup_stale_timers() {
    local stale_pids
    # Match against the function name or script name in process list
    stale_pids=$(pgrep -f "unified_timer_worker.*${TTY_DEVICE}" 2>/dev/null) || true

    if [[ -n "$stale_pids" ]]; then
        for pid in $stale_pids;
 do
            kill "$pid" 2>/dev/null || true
            [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] cleanup_stale_timers: killed stale PID $pid" >> "$IDLE_DEBUG_LOG"
        done
    fi
}

# The main worker function
unified_timer_worker() {
    local tty_device="$1"
    local start_seconds=$SECONDS
    local current_stage=0
    local last_applied_stage=-1
    
    # MAX_TIMER_RUNTIME definition (defaults if not set)
    local max_runtime=${MAX_TIMER_RUNTIME:-450}

    trap 'exec 3>&-; exit 0' TERM INT

    local my_pid
    my_pid=$( sh -c 'echo $PPID' )

    exec 3>"$tty_device"

    local SHORT_CWD
    SHORT_CWD=$(get_short_cwd)

    # Initial state: complete
    write_session_state "complete" "$my_pid"

    [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] Unified timer started, tty=$tty_device, pid=$my_pid" >> "$IDLE_DEBUG_LOG"

    while true; do
        sleep "$UNIFIED_CHECK_INTERVAL"

        [[ ! -w "$tty_device" ]] && continue

        # Check for skip signal (Jump form Complete -> Idle)
        if check_and_clear_skip_signal && [[ $current_stage -eq 0 ]]; then
            [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] Skip signal received" >> "$IDLE_DEBUG_LOG"
            start_seconds=$((SECONDS - UNIFIED_STAGE_DURATIONS[0]))
        fi

        local elapsed=$(( SECONDS - start_seconds ))
        get_unified_stage $elapsed
        current_stage=$RESULT_STAGE

        # Safety Timeout
        if [[ $elapsed -ge $max_runtime ]]; then
            [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] Max runtime reached" >> "$IDLE_DEBUG_LOG"

            # Best effort reset (palette + background + title)
            {
                _idle_reset_palette 2>/dev/null || true
                should_send_bg_color && printf "\033]111\033\\" >&3 2>/dev/null || true
                printf "\033]0;%s\033\\" "$SHORT_CWD" >&3 2>/dev/null || true
            } &
            local reset_pid=$!
            sleep 1
            kill $reset_pid 2>/dev/null || true

            kill -TERM $my_pid 2>/dev/null
            exit 0
        fi

        # Completion Check
        if [[ $current_stage -ge ${#UNIFIED_STAGE_COLORS[@]} ]]; then
            write_session_state "reset" "$my_pid"
            continue
        fi

        # State Transition
        if [[ $current_stage -ne $last_applied_stage ]]; then
            last_applied_stage=$current_stage

            if [[ $current_stage -eq 0 ]]; then
                write_session_state "complete" "$my_pid"
            else
                write_session_state "idle" "$my_pid"
            fi

            local stage_color="${UNIFIED_STAGE_COLORS[$current_stage]}"
            local stage_emoji="${UNIFIED_STAGE_EMOJIS[$current_stage]}"

            # Apply Palette FIRST (prevents contrast flicker)
            if [[ "$stage_color" == "reset" ]]; then
                _idle_reset_palette
            else
                _idle_send_palette "$(_get_palette_mode)"
            fi

            # Apply Background Color (respects ENABLE_BACKGROUND_CHANGE and STYLISH_SKIP_BG_TINT)
            if should_send_bg_color; then
                if [[ "$stage_color" == "reset" ]]; then
                    printf "\033]111\033\\" >&3
                else
                    printf "\033]11;%s\033\\" "$stage_color" >&3
                fi
            fi

            # Apply Title (with face if anthropomorphising enabled)
            # Uses >&3 directly to avoid blocking - consistent with color writes
            local title_face=""
            if [[ "$ENABLE_ANTHROPOMORPHISING" == "true" ]]; then
                # Use new agent-specific random face system if available, else fall back to legacy
                if type get_random_face &>/dev/null; then
                    title_face=$(get_random_face "idle_${current_stage}")
                elif type get_face &>/dev/null; then
                    title_face=$(get_face "${FACE_THEME:-minimal}" "idle_${current_stage}")
                fi
            fi

            # Apply Title (respects ENABLE_TITLE_PREFIX setting)
            if [[ "$ENABLE_TITLE_PREFIX" == "true" ]]; then
                local title=""
                if [[ -n "$stage_emoji" && "$ENABLE_STAGE_INDICATORS" == "true" ]]; then
                    if [[ -n "$title_face" ]]; then
                        if [[ "$FACE_POSITION" == "before" ]]; then
                            title="$title_face $stage_emoji $SHORT_CWD"
                        else
                            title="$stage_emoji $title_face $SHORT_CWD"
                        fi
                    else
                        title="$stage_emoji $SHORT_CWD"
                    fi
                elif [[ -n "$title_face" ]]; then
                    title="$title_face $SHORT_CWD"
                else
                    title="$SHORT_CWD"
                fi
                printf "\033]0;%s\033\\" "$title" >&3
            fi
        fi
    done
}
