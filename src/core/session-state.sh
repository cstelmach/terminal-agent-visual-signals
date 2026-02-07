#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Themes - State Management
# ==============================================================================
# Handles state persistence, priority locking, and TTY state tracking.
# ==============================================================================

# Consolidated state file: TTY_SAFE state priority timestamp timer_pid
STATE_DB="/tmp/terminal-visual-signals.state"
STATE_GRACE_PERIOD_MS=400  # Milliseconds to protect high-priority states

# Get current time in milliseconds (for sub-second grace period)
# macOS doesn't support %N, so we use perl or python as fallback
get_time_ms() {
    if command -v gdate &>/dev/null; then
        gdate +%s%3N
    elif command -v perl &>/dev/null; then
        perl -MTime::HiRes=time -e 'printf "%.0f\n", time*1000'
    else
        # Fallback: seconds * 1000 (loses millisecond precision)
        echo "$(( $(date +%s) * 1000 ))"
    fi
}

# Debug logging
IDLE_DEBUG="${IDLE_DEBUG:-0}"
IDLE_DEBUG_LOG="/tmp/terminal-agent-idle-timer.log"

# === FULL DEBUG LOGGING ===
# Set to 1 to capture complete invocation context for all triggers
DEBUG_ALL="${DEBUG_ALL:-0}"  # Set to 1 to enable debug logging
DEBUG_LOG_DIR="/tmp/terminal-visual-signals-debug"

# Get numeric priority for a state name
# Higher priority = harder to override (requires grace period to pass)
# Lower priority = easily overridden by any higher state
get_state_priority() {
    case "$1" in
        permission)  echo 100 ;;  # Highest - waiting for user input
        compacting)  echo 50 ;;   # Mid - system operation
        tool_error)  echo 35 ;;   # Brief error flash, above processing
        processing)  echo 30 ;;   # Active work
        subagent)    echo 25 ;;   # Subagent work, between processing and complete
        complete)    echo 20 ;;   # Just finished
        idle)        echo 15 ;;   # Lowest active - any activity overrides immediately
        reset)       echo 10 ;;   # Baseline
        *)           echo 0 ;;
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
    local now_ms
    now_ms=$(get_time_ms)

    [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] write_session_state: tty=$TTY_SAFE state=$state timer_pid='$timer_pid'" >> "$IDLE_DEBUG_LOG"

    local tmp_file="${STATE_DB}.tmp.$$"
    {
        grep -v "^${TTY_SAFE} " "$STATE_DB" 2>/dev/null
        echo "${TTY_SAFE} ${state} ${priority} ${now_ms} ${timer_pid}"
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

    # For lower priority: check if grace period has passed (using milliseconds)
    local now_ms
    now_ms=$(get_time_ms)
    local elapsed_ms=$(( now_ms - SESSION_TIME ))
    [[ $elapsed_ms -lt $STATE_GRACE_PERIOD_MS ]] && return 1
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

# ==============================================================================
# SESSION COLORS (Extended State)
# ==============================================================================
# Store calculated session colors for dynamic theming.
# Separate file to avoid breaking existing state parsing.
#
# Format: TTY_SAFE agent base_color is_dark system_mode proc perm comp idle compact
# ==============================================================================

SESSION_COLORS_DB="/tmp/terminal-visual-signals.colors"

# Write session colors for the current TTY
# Usage: write_session_colors agent base_color is_dark system_mode proc perm comp idle compact
write_session_colors() {
    local agent="${1:-claude}"
    local base_color="${2:-}"
    local is_dark="${3:-true}"
    local system_mode="${4:-dark}"
    local color_proc="${5:-}"
    local color_perm="${6:-}"
    local color_comp="${7:-}"
    local color_idle="${8:-}"
    local color_compact="${9:-}"

    [[ -z "$TTY_SAFE" ]] && return 1

    local tmp_file="${SESSION_COLORS_DB}.tmp.$$"
    {
        grep -v "^${TTY_SAFE} " "$SESSION_COLORS_DB" 2>/dev/null
        echo "${TTY_SAFE} ${agent} ${base_color} ${is_dark} ${system_mode} ${color_proc} ${color_perm} ${color_comp} ${color_idle} ${color_compact}"
    } > "$tmp_file" 2>/dev/null
    mv "$tmp_file" "$SESSION_COLORS_DB" 2>/dev/null

    [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] write_session_colors: tty=$TTY_SAFE agent=$agent base=$base_color" >> "$IDLE_DEBUG_LOG"
}

# Read session colors for the current TTY
# Sets: SESSION_AGENT, SESSION_BASE_COLOR, SESSION_IS_DARK, SESSION_SYSTEM_MODE
#       SESSION_COLOR_PROCESSING, SESSION_COLOR_PERMISSION, SESSION_COLOR_COMPLETE
#       SESSION_COLOR_IDLE, SESSION_COLOR_COMPACTING
# Returns 0 if colors found, 1 if not
read_session_colors() {
    SESSION_AGENT=""
    SESSION_BASE_COLOR=""
    SESSION_IS_DARK=""
    SESSION_SYSTEM_MODE=""
    SESSION_COLOR_PROCESSING=""
    SESSION_COLOR_PERMISSION=""
    SESSION_COLOR_COMPLETE=""
    SESSION_COLOR_IDLE=""
    SESSION_COLOR_COMPACTING=""

    [[ ! -f "$SESSION_COLORS_DB" ]] && return 1
    [[ -z "$TTY_SAFE" ]] && return 1

    local line
    line=$(grep "^${TTY_SAFE} " "$SESSION_COLORS_DB" 2>/dev/null | tail -1)
    [[ -z "$line" ]] && return 1

    read -r _ SESSION_AGENT SESSION_BASE_COLOR SESSION_IS_DARK SESSION_SYSTEM_MODE \
         SESSION_COLOR_PROCESSING SESSION_COLOR_PERMISSION SESSION_COLOR_COMPLETE \
         SESSION_COLOR_IDLE SESSION_COLOR_COMPACTING <<< "$line"

    return 0
}

# Check if session has stored colors
has_session_colors() {
    [[ -f "$SESSION_COLORS_DB" ]] || return 1
    [[ -z "$TTY_SAFE" ]] && return 1
    grep -q "^${TTY_SAFE} " "$SESSION_COLORS_DB" 2>/dev/null
}

# Clear session colors for the current TTY
clear_session_colors() {
    [[ ! -f "$SESSION_COLORS_DB" ]] && return 0
    [[ -z "$TTY_SAFE" ]] && return 1

    local tmp_file="${SESSION_COLORS_DB}.tmp.$$"
    grep -v "^${TTY_SAFE} " "$SESSION_COLORS_DB" > "$tmp_file" 2>/dev/null
    mv "$tmp_file" "$SESSION_COLORS_DB" 2>/dev/null

    [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] clear_session_colors: tty=$TTY_SAFE" >> "$IDLE_DEBUG_LOG"
}

# Get a specific color from session storage, with fallback to theme default
# Usage: get_session_color processing -> returns color or empty
get_session_color() {
    local state="$1"

    # Try to read session colors first
    if has_session_colors && read_session_colors; then
        case "$state" in
            processing) echo "$SESSION_COLOR_PROCESSING" ;;
            permission) echo "$SESSION_COLOR_PERMISSION" ;;
            complete)   echo "$SESSION_COLOR_COMPLETE" ;;
            idle)       echo "$SESSION_COLOR_IDLE" ;;
            compacting) echo "$SESSION_COLOR_COMPACTING" ;;
            base)       echo "$SESSION_BASE_COLOR" ;;
            *)          echo "" ;;
        esac
    fi
}
