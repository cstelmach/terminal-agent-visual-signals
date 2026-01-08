#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Themes - State Management
# ==============================================================================
# Handles state persistence, priority locking, and TTY state tracking.
# ==============================================================================

# Consolidated state file: TTY_SAFE state priority timestamp timer_pid
STATE_DB="/tmp/terminal-visual-signals.state"
STATE_GRACE_PERIOD=2  # Seconds to protect high-priority states

# Debug logging
IDLE_DEBUG="${IDLE_DEBUG:-0}"
IDLE_DEBUG_LOG="/tmp/terminal-agent-idle-timer.log"

# Get numeric priority for a state name
get_state_priority() {
    case "$1" in
        permission) echo 100 ;;
        idle)       echo 90 ;;
        compacting) echo 50 ;;
        processing) echo 30 ;;
        complete)   echo 20 ;;
        reset)      echo 10 ;;
        *)          echo 0 ;;
    esac
}

# Read session state for the current TTY
# Sets: SESSION_STATE, SESSION_PRIORITY, SESSION_TIME, SESSION_TIMER_PID
read_session_state() {
    SESSION_STATE="" SESSION_PRIORITY=0 SESSION_TIME=0 SESSION_TIMER_PID=""
    [[ ! -f "$STATE_DB" ]] && return 1
    local line
    line=$(grep "^${TTY_SAFE} " "$STATE_DB" 2>/dev/null | tail -1)
    [[ -z "$line" ]] && return 1
    read -r _ SESSION_STATE SESSION_PRIORITY SESSION_TIME SESSION_TIMER_PID <<< "$line"
    return 0
}

# Write session state to consolidated file (atomic update)
write_session_state() {
    local state="$1"
    local timer_pid="${2:-}"
    local priority
    priority=$(get_state_priority "$state")
    local now=$EPOCHSECONDS

    [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] write_session_state: tty=$TTY_SAFE state=$state timer_pid='$timer_pid'" >> "$IDLE_DEBUG_LOG"

    local tmp_file="${STATE_DB}.tmp.$$"
    {
        grep -v "^${TTY_SAFE} " "$STATE_DB" 2>/dev/null
        echo "${TTY_SAFE} ${state} ${priority} ${now} ${timer_pid}"
    } > "$tmp_file" 2>/dev/null
    mv "$tmp_file" "$STATE_DB" 2>/dev/null
}

# Check if state change should proceed based on priority
should_change_state() {
    local new_state="$1"
    local new_priority
    new_priority=$(get_state_priority "$new_state")

    # Always allow if no state recorded yet
    read_session_state || return 0

    # Always allow same or higher priority
    [[ $new_priority -ge $SESSION_PRIORITY ]] && return 0

    # For lower priority: check if grace period has passed
    local elapsed=$(( EPOCHSECONDS - SESSION_TIME ))
    [[ $elapsed -lt $STATE_GRACE_PERIOD ]] && return 1
    return 0
}

# Wrapper to record state without a timer PID
record_state() {
    write_session_state "$1" ""
}

# === SKIP SIGNAL MECHANISM ===
# Signals timer to jump from Complete (Stage 0) to Idle (Stage 1)

write_skip_signal() {
    local skip_file="${STATE_DB}.skip.${TTY_SAFE}"
    echo "1" > "$skip_file"
    [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] write_skip_signal: created $skip_file" >> "$IDLE_DEBUG_LOG"
}

check_and_clear_skip_signal() {
    local skip_file="${STATE_DB}.skip.${TTY_SAFE}"
    if [[ -f "$skip_file" ]]; then
        rm -f "$skip_file"
        [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] check_and_clear_skip_signal: found and cleared $skip_file" >> "$IDLE_DEBUG_LOG"
        return 0
    fi
    return 1
}
