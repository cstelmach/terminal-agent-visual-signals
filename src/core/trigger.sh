#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Signals - Unified Trigger
# ==============================================================================
# Single entry point for all agent visual state changes.
# Used by Claude, Gemini, and (future) Codex hooks.
# ==============================================================================

# Resolve Script Directory and Project Root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CORE_DIR="$SCRIPT_DIR"

# Source Core Modules
source "$CORE_DIR/theme.sh"
source "$CORE_DIR/state.sh"
source "$CORE_DIR/terminal.sh"
source "$CORE_DIR/idle-worker.sh"

# Exit silently if no TTY available
[[ -z "$TTY_DEVICE" ]] && exit 0

# Main Logic
STATE="${1:-}"

case "$STATE" in
    processing)
        should_change_state "$STATE" || exit 0
        kill_idle_timer
        if [[ "$ENABLE_PROCESSING" == "true" ]]; then
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && send_osc_bg "$COLOR_PROCESSING"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && send_osc_title "$EMOJI_PROCESSING" "$(get_short_cwd)"
        else
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && send_osc_bg "reset"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && send_osc_title "" "$(get_short_cwd)"
        fi
        send_bell_if_enabled "$STATE"
        record_state "$STATE"
        ;;

    permission)
        kill_idle_timer
        if [[ "$ENABLE_PERMISSION" == "true" ]]; then
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && send_osc_bg "$COLOR_PERMISSION"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && send_osc_title "$EMOJI_PERMISSION" "$(get_short_cwd)"
        fi
        send_bell_if_enabled "$STATE"
        record_state "$STATE"
        ;;

    complete)
        should_change_state "$STATE" || exit 0
        kill_idle_timer
        cleanup_stale_timers

        if [[ "$ENABLE_COMPLETE" == "true" ]]; then
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && send_osc_bg "$COLOR_COMPLETE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && send_osc_title "$EMOJI_COMPLETE" "$(get_short_cwd)"
        else
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && send_osc_bg "reset"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && send_osc_title "" "$(get_short_cwd)"
        fi

        send_bell_if_enabled "$STATE"

        # Start Idle Timer
        ( unified_timer_worker "$TTY_DEVICE" ) &
        disown 2>/dev/null || true
        ;;

    idle)
        # Idle notification -> Skip signal for timer
        if [[ "$ENABLE_IDLE" == "true" ]]; then
            read_session_state || true
            if [[ -n "$SESSION_TIMER_PID" ]] && kill -0 "$SESSION_TIMER_PID" 2>/dev/null; then
                write_skip_signal
            else
                # Fallback start
                [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && send_osc_bg "${UNIFIED_STAGE_COLORS[1]}"
                [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && send_osc_title "${UNIFIED_STAGE_EMOJIS[1]}" "$(get_short_cwd)"
                ( unified_timer_worker "$TTY_DEVICE" ) &
                disown 2>/dev/null || true
            fi
        fi
        ;;

    compacting)
        should_change_state "$STATE" || exit 0
        kill_idle_timer
        if [[ "$ENABLE_COMPACTING" == "true" ]]; then
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && send_osc_bg "$COLOR_COMPACTING"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && send_osc_title "$EMOJI_COMPACTING" "$(get_short_cwd)"
        fi
        send_bell_if_enabled "$STATE"
        record_state "$STATE"
        ;;

    reset)
        kill_idle_timer
        [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && send_osc_bg "reset"
        [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && send_osc_title "" "$(get_short_cwd)"
        send_bell_if_enabled "$STATE"
        record_state "$STATE"
        ;;

    *)
        echo "Usage: $0 {permission|idle|complete|processing|compacting|reset}" >&2
        exit 1
        ;;
esac

exit 0
