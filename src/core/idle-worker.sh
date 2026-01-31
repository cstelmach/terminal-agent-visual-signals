#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Themes - Idle Worker
# ==============================================================================
# Contains the logic for the background idle timer.
# ==============================================================================

# Helper: Check if we should send background color in idle worker
# Returns 0 (true) if background color should be sent, 1 (false) to skip
_idle_should_send_bg_color() {
    [[ "$ENABLE_BACKGROUND_CHANGE" != "true" ]] && return 1

    # Skip tint when background images are active (if option enabled)
    if [[ "$STYLISH_SKIP_BG_TINT" == "true" ]] && \
       [[ "$ENABLE_STYLISH_BACKGROUNDS" == "true" ]] && \
       type supports_background_images &>/dev/null && \
       supports_background_images; then
        return 1
    fi

    return 0
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

            # Best effort reset
            {
                _idle_should_send_bg_color && printf "\033]111\033\\" >&3 2>/dev/null || true
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

            # Apply Background Color (respects ENABLE_BACKGROUND_CHANGE and STYLISH_SKIP_BG_TINT)
            if _idle_should_send_bg_color; then
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
