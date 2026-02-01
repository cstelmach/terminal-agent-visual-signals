#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Signals - Title Management Module
# ==============================================================================
# Manages terminal tab/window titles with user override detection.
# Supports multiple modes: full, prefix-only, skip-processing, off
# ==============================================================================

# ==============================================================================
# STATE FILE MANAGEMENT
# ==============================================================================
# Title state is stored per-TTY alongside other session state.
# Format: key=value pairs for safe parsing (no sourcing)
# ==============================================================================

# Title state database (separate from main state for clean separation)
TITLE_STATE_DB="/tmp/terminal-visual-signals.title"

# Get title state file path for current TTY
get_title_state_file() {
    echo "${TITLE_STATE_DB}.${TTY_SAFE:-unknown}"
}

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
clear_title_state() {
    local state_file
    state_file=$(get_title_state_file)
    rm -f "$state_file" 2>/dev/null
}

# ==============================================================================
# USER OVERRIDE DETECTION
# ==============================================================================
# Detect when user has manually changed the tab title.
#
# LIMITATION: User title detection currently only works on iTerm2.
# Other terminals (Kitty, WezTerm, Ghostty, etc.) cannot be queried for
# their current title, so user-renamed tabs will be overwritten by TAVS
# in prefix-only mode. For these terminals, users can:
#   - Use TAVS_TITLE_BASE env var to set a persistent base title
#   - Use lock_tavs_title() to prevent any changes
#   - Set TAVS_TITLE_MODE="off" to disable title management entirely
# ==============================================================================

# Check if user has locked the title (explicit lock)
is_title_locked() {
    load_title_state || return 1
    [[ "$TITLE_LOCKED" == "true" ]]
}

# Detect if user changed title externally (by comparing to last set)
# This is the generic detection that works on all terminals
# Returns: 0 if user changed title, 1 if TAVS controls it
detect_user_title_change() {
    load_title_state || return 1

    # Use enhanced iTerm2 detection if available (compares termTitle vs presentationName)
    if [[ "$TERM_PROGRAM" == "iTerm.app" ]] && type iterm2_enhanced_detect_change &>/dev/null; then
        local user_title
        if user_title=$(iterm2_enhanced_detect_change); then
            # Override detected by iTerm2's robust mechanism
            if [[ -n "$user_title" ]]; then
                # Sanitize before storing to prevent state file corruption
                if type sanitize_for_terminal &>/dev/null; then
                    user_title=$(sanitize_for_terminal "$user_title")
                fi
                TITLE_USER_BASE="$user_title"
                save_title_state
                return 0  # Override detected with valid title
            fi
            # Empty output with success code = treat as no override
            return 1
        else
            return 1  # No override detected by iTerm2
        fi
    fi

    # Generic fallback detection for terminals that can't be queried
    # If we haven't set anything yet, no change to detect
    [[ -z "$TITLE_LAST_SET" ]] && return 1

    # Try to query current title (terminal-specific)
    local current_title=""

    case "$TERM_PROGRAM" in
        "iTerm.app")
            # Fallback to simple query if enhanced detection unavailable
            if type iterm2_get_current_title &>/dev/null; then
                current_title=$(iterm2_get_current_title)
            fi
            ;;
        *)
            # For other terminals (Kitty, WezTerm, Ghostty, etc.), we can't
            # reliably query the current title. Return "no change detected"
            # to allow TAVS to proceed. See LIMITATION note above.
            return 1
            ;;
    esac

    # If we got a current title and it differs from what we set
    if [[ -n "$current_title" && "$current_title" != "$TITLE_LAST_SET" ]]; then
        # User changed it - extract their base and save it
        local user_base
        user_base=$(_extract_base_from_title "$current_title")
        if [[ -n "$user_base" ]]; then
            # Sanitize before storing to prevent state file corruption
            if type sanitize_for_terminal &>/dev/null; then
                user_base=$(sanitize_for_terminal "$user_base")
            fi
            TITLE_USER_BASE="$user_base"
            save_title_state
        fi
        return 0
    fi

    return 1
}

# Extract base title by removing TAVS prefix if present
# Usage: _extract_base_from_title "Ǝ[• •]E 🟠 My Project"
# Returns: "My Project"
_extract_base_from_title() {
    local title="$1"

    # Pattern: remove face + emoji prefix
    # Faces are typically: Ǝ[...]E, ʕ...ʔ, ฅ^...^ฅ, (...)
    # Emojis: 🟠 🟢 🔴 🟣 🔄

    # Try to extract everything after the last emoji
    local base="$title"

    # Remove leading face patterns (non-greedy)
    # This handles: "Ǝ[• •]E 🟠 Base" -> "🟠 Base"
    # Face opening chars: Ǝ (uppercase schwa), ʕ (bear), ฅ (cat), (
    if [[ "$base" =~ ^[Ǝʕฅ\(].*[Eʔฅ\)][[:space:]]+(.*) ]]; then
        base="${BASH_REMATCH[1]}"
    fi

    # Remove leading emoji and space
    # Pattern: emoji followed by optional space followed by base
    if [[ "$base" =~ ^[🟠🟢🔴🟣🔄][[:space:]]*(.*) ]]; then
        base="${BASH_REMATCH[1]}"
    fi

    # If we still have something, return it
    [[ -n "$base" ]] && echo "$base"
}

# ==============================================================================
# TITLE COMPOSITION
# ==============================================================================
# Build the final title from components based on configuration
# ==============================================================================

# Get the base title (user-set or fallback)
# Returns: The base title to use (user title, session+path, or path)
get_base_title() {
    load_title_state || true

    # Priority 1: User-set base title (sanitized for terminal safety)
    if [[ -n "$TITLE_USER_BASE" ]]; then
        if type sanitize_for_terminal &>/dev/null; then
            sanitize_for_terminal "$TITLE_USER_BASE"
        else
            echo "$TITLE_USER_BASE"
        fi
        return 0
    fi

    # Priority 2: Environment variable override (sanitized for terminal safety)
    if [[ -n "${TAVS_TITLE_BASE:-}" ]]; then
        if type sanitize_for_terminal &>/dev/null; then
            sanitize_for_terminal "$TAVS_TITLE_BASE"
        else
            echo "$TAVS_TITLE_BASE"
        fi
        return 0
    fi

    # Priority 3: Fallback based on configuration (already sanitized via get_short_cwd)
    get_fallback_title
}

# Generate fallback title based on TAVS_TITLE_FALLBACK setting
# Options: session-path, path-session, session, path
get_fallback_title() {
    local fallback="${TAVS_TITLE_FALLBACK:-path}"
    local path_part
    local session_part

    # Get path component (with sanitization fallback)
    if [[ "${TAVS_TITLE_SHOW_PATH:-true}" == "true" ]]; then
        path_part=$(get_short_cwd 2>/dev/null) || {
            # Fallback: manual path shortening with sanitization
            local fallback_path="${PWD/#$HOME/\~}"
            if type sanitize_for_terminal &>/dev/null; then
                path_part=$(sanitize_for_terminal "$fallback_path")
            else
                path_part="$fallback_path"
            fi
        }
    fi

    # Get session ID component
    if [[ "${TAVS_TITLE_SHOW_SESSION:-true}" == "true" ]]; then
        # Initialize session ID if not already set
        [[ -z "$SESSION_ID" ]] && init_session_id
        session_part="$SESSION_ID"
    fi

    case "$fallback" in
        "session-path")
            # "134eed79 ~/projects"
            if [[ -n "$session_part" && -n "$path_part" ]]; then
                echo "$session_part $path_part"
            elif [[ -n "$session_part" ]]; then
                echo "$session_part"
            else
                echo "$path_part"
            fi
            ;;
        "path-session")
            # "~/projects 134eed79"
            if [[ -n "$path_part" && -n "$session_part" ]]; then
                echo "$path_part $session_part"
            elif [[ -n "$path_part" ]]; then
                echo "$path_part"
            else
                echo "$session_part"
            fi
            ;;
        "session")
            # "134eed79"
            echo "${session_part:-Terminal}"
            ;;
        "path"|*)
            # "~/projects" (current behavior, default)
            echo "${path_part:-Terminal}"
            ;;
    esac
}

# Compose the full title with face, emoji, and base
# Usage: compose_title "processing" -> "Ǝ[• •]E 🟠 ~/projects"
compose_title() {
    local state="${1:-}"
    local base_title="${2:-}"

    # Get base if not provided
    [[ -z "$base_title" ]] && base_title=$(get_base_title)

    # Get components based on state and configuration
    local face=""
    local emoji=""

    # Get face if enabled
    if [[ "${TAVS_TITLE_SHOW_FACE:-true}" == "true" && "$ENABLE_ANTHROPOMORPHISING" == "true" ]]; then
        # Use animated spinner eyes for processing state in full mode
        if [[ "$state" == "processing" && "${TAVS_TITLE_MODE:-skip-processing}" == "full" ]]; then
            if type get_spinner_eyes &>/dev/null; then
                local spinner_result
                spinner_result=$(get_spinner_eyes)
                if [[ "$spinner_result" != "FACE_VARIANT" && -n "$spinner_result" ]]; then
                    # Build face with spinner eyes using agent-specific frame
                    local left_eye="${spinner_result%% *}"
                    local right_eye="${spinner_result##* }"
                    # Use intermediate variable to avoid zsh brace expansion issues
                    local _default_frame='[{L} {R}]'
                    local frame="${SPINNER_FACE_FRAME:-$_default_frame}"
                    # Substitute placeholders with spinner eyes
                    face="${frame//\{L\}/$left_eye}"
                    face="${face//\{R\}/$right_eye}"
                fi
            fi
        fi
        # Fallback to static random face if spinner not used/available
        if [[ -z "$face" ]] && type get_random_face &>/dev/null; then
            face=$(get_random_face "$state")
        fi
    fi

    # Get emoji if enabled
    if [[ "${TAVS_TITLE_SHOW_EMOJI:-true}" == "true" ]]; then
        case "$state" in
            processing) emoji="$EMOJI_PROCESSING" ;;
            permission) emoji="$EMOJI_PERMISSION" ;;
            complete)   emoji="$EMOJI_COMPLETE" ;;
            idle*)      emoji="$EMOJI_IDLE" ;;
            compacting) emoji="$EMOJI_COMPACTING" ;;
            reset|*)    emoji="" ;;
        esac
    fi

    # Compose using format template or default
    # Note: zsh has issues with brace expansion in ${:-} defaults, use intermediate var
    local _default_format='{FACE} {EMOJI} {BASE}'
    local format="${TAVS_TITLE_FORMAT:-$_default_format}"
    local title="$format"

    # Substitute placeholders
    title="${title//\{FACE\}/$face}"
    title="${title//\{EMOJI\}/$emoji}"
    title="${title//\{BASE\}/$base_title}"

    # Clean up multiple spaces and trim (use printf for safe string handling)
    title=$(printf '%s\n' "$title" | sed 's/  */ /g; s/^ *//; s/ *$//')

    printf '%s\n' "$title"
}

# ==============================================================================
# MAIN API FUNCTIONS
# ==============================================================================
# These are the public functions called by trigger.sh
# ==============================================================================

# Set terminal title with full state tracking
# Usage: set_tavs_title "processing"
set_tavs_title() {
    local state="${1:-}"

    [[ -z "$TTY_DEVICE" ]] && return 0

    # Check title mode
    case "${TAVS_TITLE_MODE:-skip-processing}" in
        "off")
            # Title changes disabled
            return 0
            ;;
        "skip-processing")
            # Skip processing state (let Claude Code handle it)
            [[ "$state" == "processing" ]] && return 0
            ;;
        "prefix-only"|"full")
            # Process all states
            ;;
    esac

    # Load current state
    load_title_state || true
    [[ -z "$SESSION_ID" ]] && init_session_id

    # Always respect explicit title lock (regardless of mode)
    if [[ "$TITLE_LOCKED" == "true" ]]; then
        return 0
    fi

    # Check user override behavior
    local respect_mode="${TAVS_RESPECT_USER_TITLE:-prefix}"

    if [[ "$respect_mode" == "full" ]]; then
        # Full respect: if user set title, don't change anything
        if [[ -n "$TITLE_USER_BASE" ]]; then
            return 0
        fi
    fi

    # Detect if user changed title since last set (on supported terminals)
    if detect_user_title_change; then
        # User changed title - respect their base, add our prefix
        if [[ "$respect_mode" == "full" ]]; then
            return 0
        fi
        # With "prefix" mode, we continue but use their base
    fi

    # Get base title
    local base_title
    base_title=$(get_base_title)

    # Compose full title
    local full_title
    full_title=$(compose_title "$state" "$base_title")

    # Send to terminal (only save state if write succeeds)
    if printf "\033]0;%s\033\\" "$full_title" > "$TTY_DEVICE" 2>/dev/null; then
        # Save state only after successful write
        TITLE_LAST_SET="$full_title"
        save_title_state "$TITLE_USER_BASE" "$TITLE_LAST_SET" "$TITLE_LOCKED" "$SESSION_ID"
    fi
}

# Reset terminal title to base (remove TAVS prefix)
# Usage: reset_tavs_title
reset_tavs_title() {
    [[ -z "$TTY_DEVICE" ]] && return 0

    # Check title mode
    [[ "${TAVS_TITLE_MODE:-skip-processing}" == "off" ]] && return 0

    # Load state
    load_title_state || true
    [[ -z "$SESSION_ID" ]] && init_session_id

    # Always respect explicit title lock (regardless of mode)
    if [[ "$TITLE_LOCKED" == "true" ]]; then
        return 0
    fi

    # In "full" respect mode, don't overwrite user titles even on reset
    local respect_mode="${TAVS_RESPECT_USER_TITLE:-prefix}"
    if [[ "$respect_mode" == "full" && -n "$TITLE_USER_BASE" ]]; then
        return 0
    fi

    # Get base title (no prefix)
    local base_title
    base_title=$(get_base_title)

    # Send to terminal (only save state if write succeeds)
    if printf "\033]0;%s\033\\" "$base_title" > "$TTY_DEVICE" 2>/dev/null; then
        # Save state only after successful write
        TITLE_LAST_SET="$base_title"
        save_title_state "$TITLE_USER_BASE" "$TITLE_LAST_SET" "$TITLE_LOCKED" "$SESSION_ID"
    fi
}

# Lock title (prevent TAVS from changing it)
lock_tavs_title() {
    load_title_state || true
    TITLE_LOCKED="true"
    save_title_state
}

# Unlock title (allow TAVS to change it again)
unlock_tavs_title() {
    load_title_state || true
    TITLE_LOCKED="false"
    save_title_state
}

# Set user's preferred base title explicitly
# Usage: set_user_title "My Project"
set_user_title() {
    local user_title="$1"
    load_title_state || true
    [[ -z "$SESSION_ID" ]] && init_session_id
    # Sanitize user input to prevent control character injection
    if type sanitize_for_terminal &>/dev/null; then
        TITLE_USER_BASE=$(sanitize_for_terminal "$user_title")
    else
        TITLE_USER_BASE="$user_title"
    fi
    save_title_state
}

# Clear user's base title (return to fallback)
clear_user_title() {
    load_title_state || true
    TITLE_USER_BASE=""
    save_title_state
}

# ==============================================================================
# INITIALIZATION
# ==============================================================================

# Initialize session ID on source (if TTY available)
if [[ -n "${TTY_SAFE:-}" ]]; then
    load_title_state || true
    [[ -z "$SESSION_ID" ]] && init_session_id && save_title_state
fi
