#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — State Management
# ==============================================================================
# Handles state persistence, priority locking, and TTY state tracking.
# ==============================================================================

# ==============================================================================
# EPHEMERAL STATE DIRECTORY
# ==============================================================================
# All ephemeral TAVS state files live under /tmp/tavs/ (or TAVS_TMP_DIR).
# Mirrors get_spinner_state_dir() pattern from spinner.sh for persistent state.
# Directory is created with 700 permissions on first call.
# ==============================================================================

get_tavs_tmp_dir() {
    local tmp_dir="${TAVS_TMP_DIR:-/tmp/tavs}"

    if [[ ! -d "$tmp_dir" ]]; then
        mkdir -p "$tmp_dir" 2>/dev/null
        chmod 700 "$tmp_dir" 2>/dev/null
    fi

    printf '%s' "$tmp_dir"
}

# Initialize ephemeral state directory (called once at source time)
_TAVS_TMP_DIR=$(get_tavs_tmp_dir)

# Consolidated state file: TTY_SAFE state priority timestamp timer_pid
STATE_DB="${_TAVS_TMP_DIR}/state"
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
IDLE_DEBUG_LOG="${_TAVS_TMP_DIR}/idle-timer.log"

# === FULL DEBUG LOGGING ===
# Set to 1 to capture complete invocation context for all triggers
DEBUG_ALL="${DEBUG_ALL:-0}"  # Set to 1 to enable debug logging
DEBUG_LOG_DIR="${_TAVS_TMP_DIR}/debug"

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

# Existing private roots and leaves must not permit another user to replace lock/state files.
_tavs_session_table_private_path() {
    local metadata owner mode
    [[ ! -L "$1" ]] || return 1
    case "$OSTYPE" in
        darwin*) metadata=$(stat -f '%u:%Op' "$1") || return 1 ;;
        linux*)  metadata=$(stat -c '%u:%a' "$1") || return 1 ;;
        *) return 1 ;;
    esac
    owner="${metadata%%:*}" mode="${metadata#*:}"
    [[ "$owner" == "$EUID" || ( "${2:-}" == ancestor && "$owner" == 0 ) ]] || return 1
    [[ -n "$mode" && "$mode" != *[!0-7]* ]] || return 1
    (( (8#$mode & 8#22) == 0 )) && return 0
    # A trusted sticky ancestor protects the next owned directory, as /tmp does.
    [[ "${2:-}" == ancestor ]] && (( (8#$mode & 8#1000) != 0 ))
}

# Keep the descriptor and cleanup scoped to this invocation, preserving caller traps/FDs.
_tavs_update_session_table() (
    local db="$1" operation="$2"
    shift 2
    local lock_file tmp_file="" row priority now_ms directory parent
    [[ -n "$TTY_SAFE" && "$TTY_SAFE" != *[[:space:]]* ]] || return 1
    [[ -d "${db%/*}" && ! -L "${db%/*}" ]] || return 1
    directory=$(cd -P -- "${db%/*}" && pwd -P) || return 1
    parent="$directory"
    while :; do
        _tavs_session_table_private_path "$parent" ancestor || return 1
        [[ "$parent" == / ]] && break
        parent="${parent%/*}"
        [[ -n "$parent" ]] || parent=/
    done
    _tavs_session_table_private_path "$directory" || return 1
    db="${directory}/${db##*/}" lock_file="${directory}/${db##*/}.lock"
    umask 077

    # Never unlink this stable inode. Kernel ownership ends when the shell's FD closes.
    if [[ ! -e "$lock_file" ]]; then
        (set -C; : > "$lock_file") 2>/dev/null || [[ -f "$lock_file" ]] || return 1
    fi
    [[ -f "$lock_file" ]] && _tavs_session_table_private_path "$lock_file" || return 1
    exec 9>> "$lock_file" || return 1
    case "$OSTYPE" in
        darwin*) lockf -s -t 1 9 || return 1 ;;
        linux*)
            python3 -c 'import fcntl, signal
def expired(*_):
    raise SystemExit(75)
signal.signal(signal.SIGALRM, expired)
signal.alarm(1)
fcntl.flock(9, fcntl.LOCK_EX)
signal.alarm(0)' || return 1
            ;;
        *) return 1 ;;
    esac

    trap '[[ -z "$tmp_file" ]] || rm -f -- "$tmp_file"' EXIT
    trap 'exit 1' HUP INT TERM
    if [[ -e "$db" || -L "$db" ]]; then
        [[ -f "$db" ]] && _tavs_session_table_private_path "$db" || return 1
    elif [[ "$operation" == clear ]]; then
        return 0
    fi
    tmp_file=$(mktemp "${db}.tmp.XXXXXX") || return 1
    if [[ -f "$db" ]]; then
        TAVS_TABLE_TTY="$TTY_SAFE" awk '$1 != ENVIRON["TAVS_TABLE_TTY"]' "$db" > "$tmp_file" || return 1
    fi
    case "$operation" in
        state)
            priority=$(get_state_priority "$1") || return 1
            now_ms=$(get_time_ms) || return 1
            row="${TTY_SAFE} $1 ${priority} ${now_ms} $2"
            ;;
        colors) row="${TTY_SAFE} $1" ;;
        clear) ;;
        *) return 1 ;;
    esac
    if [[ "$operation" != clear ]]; then
        printf '%s\n' "$row" >> "$tmp_file" || return 1
    fi
    mv -- "$tmp_file" "$db" || return 1
    tmp_file=""
    return 0
)

# Serialize the full read/modify/rename; atomic rename alone loses concurrent TTY updates.
write_session_state() {
    local state="$1"
    local timer_pid="${2:-}"
    [[ -n "$state" && "$state" != *[[:space:]]* && "$timer_pid" != *[[:space:]]* ]] || return 1
    _tavs_update_session_table "$STATE_DB" state "$state" "$timer_pid" || return 1
    [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] write_session_state: tty=$TTY_SAFE state=$state timer_pid='$timer_pid'" >> "$IDLE_DEBUG_LOG"
    return 0
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

SESSION_COLORS_DB="${_TAVS_TMP_DIR}/colors"

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

    _tavs_update_session_table "$SESSION_COLORS_DB" colors \
        "${agent} ${base_color} ${is_dark} ${system_mode} ${color_proc} ${color_perm} ${color_comp} ${color_idle} ${color_compact}" || return 1
    [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] write_session_colors: tty=$TTY_SAFE agent=$agent base=$base_color" >> "$IDLE_DEBUG_LOG"
    return 0
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
    _tavs_update_session_table "$SESSION_COLORS_DB" clear || return 1
    [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] clear_session_colors: tty=$TTY_SAFE" >> "$IDLE_DEBUG_LOG"
    return 0
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
