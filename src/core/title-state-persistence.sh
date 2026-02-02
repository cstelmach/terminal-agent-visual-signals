#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Signals - Title State Persistence Module
# ==============================================================================
# Manages title state persistence per-TTY session.
# Extracted from title.sh for modularization.
#
# Public functions:
#   get_title_state_file()    - Get state file path for current TTY
#   init_session_id()         - Initialize and return session ID
#   load_title_state()        - Load all state variables
#   save_title_state()        - Save state atomically
#   clear_title_state()       - Remove state file
#
# Internal functions:
#   _generate_session_id()    - Generate new or retrieve existing session ID
#   _read_title_state_value() - Read single value from state file
#   _escape_for_state_file()  - Escape special characters for storage
#
# State file format:
#   key="value" pairs, one per line
#   Values are escaped to prevent control character injection
#
# Dependencies:
#   - TTY_SAFE environment variable (from terminal.sh)
# ==============================================================================

# ==============================================================================
# STATE FILE CONFIGURATION
# ==============================================================================

# Title state database (separate from main state for clean separation)
TITLE_STATE_DB="/tmp/terminal-visual-signals.title"

# ==============================================================================
# STATE FILE PATH
# ==============================================================================

# Get title state file path for current TTY
# Returns: Path to state file (e.g., /tmp/terminal-visual-signals.title.dev_ttys001)
get_title_state_file() {
    echo "${TITLE_STATE_DB}.${TTY_SAFE:-unknown}"
}

# ==============================================================================
# SESSION ID GENERATION
# ==============================================================================

# Session ID generation - first 8 chars of a UUID-like identifier
# Persists for the lifetime of the TTY session
_generate_session_id() {
    # Try to get from existing state first
    local state_file
    state_file=$(get_title_state_file)
    if [[ -f "$state_file" ]]; then
        local existing_id
        existing_id=$(_read_title_state_value "SESSION_ID")
        if [[ -n "$existing_id" ]]; then
            echo "$existing_id"
            return 0
        fi
    fi

    # Generate new session ID (first 8 chars of UUID or random hex)
    if command -v uuidgen &>/dev/null; then
        uuidgen | cut -c1-8 | tr '[:upper:]' '[:lower:]'
    elif [[ -f /proc/sys/kernel/random/uuid ]]; then
        cut -c1-8 < /proc/sys/kernel/random/uuid
    elif [[ -c /dev/urandom ]]; then
        # Use /dev/urandom for better randomness (available on most Unix systems)
        head -c 4 /dev/urandom | od -An -t x4 | tr -d ' \n'
        echo  # Add newline
    else
        # Fallback: use hash-like value based on PID + timestamp
        local seed
        seed="$(( (PPID + $(date +%s)) % 0xFFFFFFFF ))"
        if command -v md5sum &>/dev/null; then
            printf '%s' "$seed" | md5sum | cut -c1-8
        elif command -v cksum &>/dev/null; then
            # cksum output format varies; use awk to reliably get first field
            printf '%08x\n' "$(printf '%s' "$seed" | cksum | awk '{print $1}')"
        else
            # Pure shell fallback: 8-digit hexadecimal representation of the seed
            printf '%08x\n' "$seed"
        fi
    fi
}

# Initialize session ID and store it
# Sets: SESSION_ID global variable
init_session_id() {
    SESSION_ID=$(_generate_session_id)
}

# ==============================================================================
# SAFE STATE FILE PARSING
# ==============================================================================
# Parse key=value files without sourcing (prevents code injection)
# ==============================================================================

# Read a single value from title state file
# Usage: _read_title_state_value "KEY"
# Returns: Value for the key, or empty string if not found
_read_title_state_value() {
    local key="$1"
    local state_file
    state_file=$(get_title_state_file)

    [[ ! -f "$state_file" ]] && return 1

    local value=""
    while IFS='=' read -r k v; do
        # Skip comments and empty lines
        [[ "$k" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$k" ]] && continue
        # Strip quotes from value (key is already clean from save_title_state)
        v="${v%\"}"
        v="${v#\"}"
        v="${v%\'}"
        v="${v#\'}"
        if [[ "$k" == "$key" ]]; then
            value="$v"
            break
        fi
    done < "$state_file"

    echo "$value"
}

# Load all title state variables
# Sets: TITLE_USER_BASE, TITLE_LAST_SET, TITLE_LOCKED, SESSION_ID
# Returns: 0 on success, 1 if state file doesn't exist
load_title_state() {
    TITLE_USER_BASE=""
    TITLE_LAST_SET=""
    TITLE_LOCKED="false"
    SESSION_ID=""

    local state_file
    state_file=$(get_title_state_file)
    [[ ! -f "$state_file" ]] && return 1

    TITLE_USER_BASE=$(_read_title_state_value "USER_BASE_TITLE")
    TITLE_LAST_SET=$(_read_title_state_value "LAST_TAVS_TITLE")
    TITLE_LOCKED=$(_read_title_state_value "TITLE_LOCKED")
    SESSION_ID=$(_read_title_state_value "SESSION_ID")

    # Ensure defaults
    TITLE_LOCKED="${TITLE_LOCKED:-false}"

    return 0
}

# ==============================================================================
# STATE FILE WRITING
# ==============================================================================

# Escape a value for safe storage in state file
# Removes/escapes characters that could break key="value" format
_escape_for_state_file() {
    local val="$1"
    # Remove newlines and carriage returns, escape double quotes and backslashes
    val="${val//$'\n'/ }"
    val="${val//$'\r'/}"
    val="${val//\\/\\\\}"
    val="${val//\"/\\\"}"
    printf '%s' "$val"
}

# Save title state atomically
# Usage: save_title_state [user_base] [last_set] [locked] [session_id]
# Uses atomic temp file + mv pattern to prevent corruption
save_title_state() {
    local user_base="${1:-$TITLE_USER_BASE}"
    local last_set="${2:-$TITLE_LAST_SET}"
    local locked="${3:-$TITLE_LOCKED}"
    local session_id="${4:-$SESSION_ID}"

    # Sanitize values to prevent state file corruption
    user_base=$(_escape_for_state_file "$user_base")
    last_set=$(_escape_for_state_file "$last_set")
    # locked and session_id are internal values, but sanitize for safety
    locked=$(_escape_for_state_file "$locked")
    session_id=$(_escape_for_state_file "$session_id")

    local state_file
    state_file=$(get_title_state_file)

    # Use mktemp for guaranteed unique temp file (avoids race conditions with $$)
    local tmp_file
    tmp_file=$(mktemp "${state_file}.tmp.XXXXXX" 2>/dev/null) || {
        # Fallback if mktemp fails
        tmp_file="${state_file}.tmp.$$"
    }

    {
        echo "# TAVS Title State - $(date -Iseconds 2>/dev/null || date)"
        echo "USER_BASE_TITLE=\"$user_base\""
        echo "LAST_TAVS_TITLE=\"$last_set\""
        echo "TITLE_LOCKED=\"$locked\""
        echo "SESSION_ID=\"$session_id\""
    } > "$tmp_file" 2>/dev/null

    mv "$tmp_file" "$state_file" 2>/dev/null || {
        rm -f "$tmp_file" 2>/dev/null
        return 1
    }

    return 0
}

# Clear title state for current TTY
# Removes the state file completely
clear_title_state() {
    local state_file
    state_file=$(get_title_state_file)
    rm -f "$state_file" 2>/dev/null
}
