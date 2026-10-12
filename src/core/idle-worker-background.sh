#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — Idle Worker
# ==============================================================================
# Contains the logic for the background idle timer.
#
# Note: This file uses shared helper functions from palette-mode-helpers.sh:
#   - should_send_bg_color()  - Decides whether to send background color
#   - _get_palette_mode()     - Gets current palette mode (dark/light)
#
# These are sourced by trigger.sh before idle-worker-background.sh, so they are available.
#
# Mute integration: The worker re-reads mute.state each tick via
# _tavs_check_mute_state() and routes all OSC writes through emit_osc.
# When muted, bytes go to the pending cache; when unmuted, directly to TTY.
# ==============================================================================

# Helper: Send OSC 4 palette in idle worker via emit_osc
# Uses shared _build_osc_palette_seq from terminal-osc-sequences.sh
_idle_send_palette() {
    local mode="$1"

    type should_enable_palette_theming &>/dev/null || return 0
    should_enable_palette_theming || return 0

    type _build_osc_palette_seq &>/dev/null || return 0

    local seq
    seq=$(_build_osc_palette_seq "$mode")
    [[ -n "$seq" ]] && emit_osc "%b" "$seq"
}

# Helper: Reset OSC 4 palette in idle worker via emit_osc
_idle_reset_palette() {
    type should_enable_palette_theming &>/dev/null || return 0
    should_enable_palette_theming || return 0
    emit_osc "\033]104\033\\"
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
    export TAVS_ORGANIZER_SYNTHETIC=1
    local start_seconds=$SECONDS
    local current_stage=0
    local last_applied_stage=-1

    local max_runtime=${MAX_TIMER_RUNTIME:-450}

    trap 'exit 0' TERM INT

    local my_pid
    my_pid=$( sh -c 'echo $PPID' )

    # Set TTY_DEVICE + TTY_SAFE for emit_osc and pending cache naming.
    # Replaces the old fd-3 pattern. emit_osc opens/closes TTY_DEVICE
    # per write — works fine from background subshells.
    TTY_DEVICE="$tty_device"
    TTY_SAFE="${TTY_DEVICE//\//_}"

    local SHORT_CWD
    SHORT_CWD=$(get_short_cwd)

    local SESSION_ICON=""
    if [[ "${ENABLE_SESSION_ICONS:-false}" == "true" ]] && type get_session_icon &>/dev/null; then
        SESSION_ICON=$(get_session_icon 2>/dev/null)
    fi

    # Initial state: complete
    write_session_state "complete" "$my_pid"

    [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] Unified timer started, tty=$tty_device, pid=$my_pid" >> "$IDLE_DEBUG_LOG"

    while true; do
        sleep "$UNIFIED_CHECK_INTERVAL"

        [[ ! -w "$tty_device" ]] && continue

        # Re-check mute state each tick (mute can change during worker lifetime)
        if type _tavs_check_mute_state &>/dev/null; then
            _tavs_check_mute_state || true
        fi

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
            # Force unmuted for reset — we want the visual reset to reach the TTY
            _TAVS_SUPPRESS_OUTPUT=0
            {
                _idle_reset_palette 2>/dev/null || true
                should_send_bg_color && send_osc_bg reset 2>/dev/null || true
                emit_osc "\033]0;%s\033\\" "$SHORT_CWD" 2>/dev/null || true
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

            # Open pending buffer for this tick's OSC writes (if muted)
            if type _tavs_mute_buffer_open &>/dev/null; then
                _tavs_mute_buffer_open
            fi

            local stage_color="${UNIFIED_STAGE_COLORS[$current_stage]}"
            local stage_status_icon="${UNIFIED_STAGE_STATUS_ICONS[$current_stage]}"

            # Apply Palette FIRST (prevents contrast flicker)
            if [[ "$stage_color" == "reset" ]]; then
                _idle_reset_palette
            else
                _idle_send_palette "$(_get_palette_mode)"
            fi

            # Apply Background Color
            if should_send_bg_color; then
                send_osc_bg "$stage_color"
            fi

            # Apply Title using compose_title()
            if [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && type compose_title &>/dev/null; then
                _TAVS_CONTEXT_LOADED=""

                local title_state
                if [[ $current_stage -eq 0 ]]; then
                    title_state="complete"
                else
                    title_state="idle_${current_stage}"
                fi

                local title
                title=$(compose_title "$title_state" "$SHORT_CWD")
                emit_osc "\033]0;%s\033\\" "$title"
            fi

            # Close pending buffer: atomic-rename to per-TTY cache
            if type _tavs_mute_buffer_close &>/dev/null; then
                _tavs_mute_buffer_close
            fi
        fi
    done
}
