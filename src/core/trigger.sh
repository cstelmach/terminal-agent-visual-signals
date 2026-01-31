#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Signals - Unified Trigger
# ==============================================================================
# Single entry point for all agent visual state changes.
# Used by Claude, Gemini, and (future) Codex hooks.
# ==============================================================================

# ==============================================================================
# TAVS_STATUS KILL SWITCH
# ==============================================================================
# Exit immediately if TAVS_STATUS environment variable is set to disabled.
# This allows users to run agents without visual signals by setting:
#   TAVS_STATUS=false claude
#   TAVS_STATUS=0 gemini
#
# Recognized disabled values (case-insensitive): false, 0, off, no, disabled
# ==============================================================================
_tavs_status_lower=$(printf '%s' "$TAVS_STATUS" | tr '[:upper:]' '[:lower:]')
case "$_tavs_status_lower" in
    false|0|off|no|disabled)
        exit 0
        ;;
esac
unset _tavs_status_lower

# Resolve Script Directory and Project Root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CORE_DIR="$SCRIPT_DIR"

# Source Core Modules
source "$CORE_DIR/theme.sh"
source "$CORE_DIR/state.sh"
source "$CORE_DIR/terminal.sh"
source "$CORE_DIR/idle-worker.sh"
source "$CORE_DIR/detect.sh"
source "$CORE_DIR/backgrounds.sh"

# === DEBUG LOGGING ===
debug_log_invocation() {
    [[ "$DEBUG_ALL" != "1" ]] && return 0

    mkdir -p "$DEBUG_LOG_DIR"
    local ts=$(date +%Y%m%d-%H%M%S)
    local log_file="${DEBUG_LOG_DIR}/${ts}-$$-${1:-unknown}.log"

    {
        echo "=== TERMINAL VISUAL SIGNALS DEBUG LOG ==="
        echo "Timestamp: $(date -Iseconds 2>/dev/null || date)"
        echo "PID: $$"
        echo "PPID: $PPID"
        echo ""
        echo "=== ARGUMENTS ==="
        echo "Arg count: $#"
        echo "All args: $*"
        echo "Arg 1 (state): ${1:-<empty>}"
        echo ""
        echo "=== WORKING DIRECTORY ==="
        echo "PWD env var: $PWD"
        echo "pwd command: $(pwd)"
        echo "get_short_cwd: $(get_short_cwd 2>/dev/null || echo '<function not loaded>')"
        echo ""
        echo "=== TTY INFO ==="
        echo "TTY_DEVICE: ${TTY_DEVICE:-<unset>}"
        echo "TTY_SAFE: ${TTY_SAFE:-<unset>}"
        echo "tty command: $(tty 2>/dev/null || echo '<no tty>')"
        echo ""
        echo "=== PARENT PROCESS ==="
        ps -p $PPID -o pid,ppid,comm,args 2>/dev/null || echo "ps failed"
        echo ""
        echo "=== SCRIPT PATHS ==="
        echo "SCRIPT_DIR: $SCRIPT_DIR"
        echo "CORE_DIR: $CORE_DIR"
        echo "BASH_SOURCE[0]: ${BASH_SOURCE[0]}"
        echo ""
        echo "=== STDIN ==="
        # Non-blocking stdin capture (read with 0.1s timeout)
        if read -t 0.1 -r stdin_line 2>/dev/null; then
            echo "First line: $stdin_line"
            # Capture remaining stdin (up to 100 lines)
            local count=1
            while read -t 0.1 -r stdin_line && [[ $count -lt 100 ]]; do
                echo "Line $((++count)): $stdin_line"
            done
        else
            echo "(no stdin data)"
        fi
        echo ""
        echo "=== END DEBUG LOG ==="
    } > "$log_file" 2>&1

    # Also append summary to consolidated log
    echo "${ts} pid=$$ state=${1:-?} pwd=$PWD tty=${TTY_DEVICE:-?}" >> "${DEBUG_LOG_DIR}/summary.log"
}

# Log this invocation
debug_log_invocation "$@"

# Exit silently if no TTY available
[[ -z "$TTY_DEVICE" ]] && exit 0

# Helper: Check if we should send background color
# Returns 0 (true) if background color should be sent, 1 (false) to skip
# Skips when: stylish backgrounds are active AND terminal supports images AND skip option enabled
should_send_bg_color() {
    [[ "$ENABLE_BACKGROUND_CHANGE" != "true" ]] && return 1

    # Skip tint when background images are active (if option enabled)
    if [[ "$STYLISH_SKIP_BG_TINT" == "true" ]] && \
       [[ "$ENABLE_STYLISH_BACKGROUNDS" == "true" ]] && \
       supports_background_images; then
        return 1
    fi

    return 0
}

# Main Logic
STATE="${1:-}"

case "$STATE" in
    processing)
        should_change_state "$STATE" || exit 0
        kill_idle_timer
        if [[ "$ENABLE_PROCESSING" == "true" ]]; then
            should_send_bg_color && send_osc_bg "$COLOR_PROCESSING"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && send_osc_title "$EMOJI_PROCESSING" "$(get_short_cwd)" "processing"
            set_state_background_image "processing"
        else
            should_send_bg_color && send_osc_bg "reset"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && send_osc_title "" "$(get_short_cwd)" "reset"
            clear_background_image
        fi
        send_bell_if_enabled "$STATE"
        record_state "$STATE"
        ;;

    permission)
        kill_idle_timer
        if [[ "$ENABLE_PERMISSION" == "true" ]]; then
            should_send_bg_color && send_osc_bg "$COLOR_PERMISSION"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && send_osc_title "$EMOJI_PERMISSION" "$(get_short_cwd)" "permission"
            set_state_background_image "permission"
        fi
        send_bell_if_enabled "$STATE"
        record_state "$STATE"
        ;;

    complete)
        should_change_state "$STATE" || exit 0
        kill_idle_timer
        cleanup_stale_timers

        if [[ "$ENABLE_COMPLETE" == "true" ]]; then
            should_send_bg_color && send_osc_bg "$COLOR_COMPLETE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && send_osc_title "$EMOJI_COMPLETE" "$(get_short_cwd)" "complete"
            set_state_background_image "complete"
        else
            should_send_bg_color && send_osc_bg "reset"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && send_osc_title "" "$(get_short_cwd)" "reset"
            clear_background_image
        fi

        send_bell_if_enabled "$STATE"

        # Start Idle Timer (redirect fds to prevent parent blocking)
        ( unified_timer_worker "$TTY_DEVICE" ) </dev/null >/dev/null 2>&1 &
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
                should_send_bg_color && send_osc_bg "${UNIFIED_STAGE_COLORS[1]}"
                [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && send_osc_title "${UNIFIED_STAGE_EMOJIS[1]}" "$(get_short_cwd)" "idle_1"
                set_state_background_image "idle"
                ( unified_timer_worker "$TTY_DEVICE" ) </dev/null >/dev/null 2>&1 &
                disown 2>/dev/null || true
            fi
        fi
        ;;

    compacting)
        should_change_state "$STATE" || exit 0
        kill_idle_timer
        if [[ "$ENABLE_COMPACTING" == "true" ]]; then
            should_send_bg_color && send_osc_bg "$COLOR_COMPACTING"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && send_osc_title "$EMOJI_COMPACTING" "$(get_short_cwd)" "compacting"
            set_state_background_image "compacting"
        fi
        send_bell_if_enabled "$STATE"
        record_state "$STATE"
        ;;

    reset)
        kill_idle_timer
        should_send_bg_color && send_osc_bg "reset"
        [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && send_osc_title "" "$(get_short_cwd)" "reset"
        clear_background_image
        send_bell_if_enabled "$STATE"
        record_state "$STATE"
        ;;

    *)
        echo "Usage: $0 {permission|idle|complete|processing|compacting|reset}" >&2
        exit 1
        ;;
esac

exit 0
