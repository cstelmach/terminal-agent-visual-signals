#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — Title Management Module
# ==============================================================================
# Manages terminal tab/window titles with user override detection.
# Supports multiple modes: full, prefix-only, skip-processing, off
# ==============================================================================

# ==============================================================================
# SOURCE EXTRACTED MODULES
# ==============================================================================
# Title state persistence is handled by a dedicated module.
# ==============================================================================

# Resolve script directory for sourcing
# Works in both bash and zsh (matches theme-config-loader.sh pattern)
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    _TITLE_THIS_SCRIPT="${BASH_SOURCE[0]}"
elif [[ -n "${(%):-%x}" ]] 2>/dev/null; then
    _TITLE_THIS_SCRIPT="${(%):-%x}"  # zsh-specific: current script path
else
    _TITLE_THIS_SCRIPT="$0"  # Fallback (may not work when sourced)
fi
_TITLE_SCRIPT_DIR="$( cd "$( dirname "$_TITLE_THIS_SCRIPT" )" && pwd )"

source "${_TITLE_SCRIPT_DIR}/title-state-persistence.sh"

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

    # Pattern: remove face + status icon prefix
    # Faces are typically: Ǝ[...]E, ʕ...ʔ, ฅ^...^ฅ, (...)
    # Status icons: 🟠 🟢 🔴 🟣 🔄

    # Try to extract everything after the last status icon
    local base="$title"

    # Remove leading face patterns (non-greedy)
    # This handles: "Ǝ[• •]E 🟠 Base" -> "🟠 Base"
    # Face opening chars: Ǝ (uppercase schwa), ʕ (bear), ฅ (cat), (
    if [[ "$base" =~ ^[Ǝʕฅ\(].*[Eʔฅ\)][[:space:]]+(.*) ]]; then
        base="${BASH_REMATCH[1]}"
    fi

    # Remove leading status icon and space
    # Pattern: status icon followed by optional space followed by base
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

# Compose the full title with face, status icon, and base
# Usage: compose_title "processing" -> "Ǝ[• •]E 🟠 ~/projects"
compose_title() {
    local state="${1:-}"
    local base_title="${2:-}"

    # Get base if not provided
    [[ -z "$base_title" ]] && base_title=$(get_base_title)

    # Get components based on state and configuration
    local face=""
    local status_icon=""

    # Get face if enabled (skip on reset — clean title at session start)
    if [[ "$state" != "reset" && "${TAVS_TITLE_SHOW_FACE:-true}" == "true" && "$ENABLE_ANTHROPOMORPHISING" == "true" ]]; then
        if [[ "${TAVS_FACE_MODE:-standard}" == "compact" ]]; then
            # Compact mode: emoji eyes in face frame (includes subagent count)
            if type get_compact_face &>/dev/null; then
                face=$(get_compact_face "$state")
            fi
        else
            # Standard mode: text eyes with optional spinner animation
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
    fi

    # Get status icon if enabled
    # In compact mode, status icon is embedded as face emoji eyes — suppress the
    # separate {STATUS_ICON} token. But if faces are disabled, fall back to showing
    # the status icon separately (otherwise both face AND icon would be empty).
    local _compact_with_face=false
    [[ "${TAVS_FACE_MODE:-standard}" == "compact" && "$ENABLE_ANTHROPOMORPHISING" == "true" ]] && _compact_with_face=true
    if [[ "$_compact_with_face" != "true" && "${TAVS_TITLE_SHOW_STATUS_ICON:-true}" == "true" ]]; then
        case "$state" in
            processing) status_icon="$STATUS_ICON_PROCESSING" ;;
            permission) status_icon="$STATUS_ICON_PERMISSION" ;;
            complete)   status_icon="$STATUS_ICON_COMPLETE" ;;
            idle*)      status_icon="$STATUS_ICON_IDLE" ;;
            compacting) status_icon="$STATUS_ICON_COMPACTING" ;;
            subagent*)  status_icon="$STATUS_ICON_SUBAGENT" ;;
            tool_error) status_icon="$STATUS_ICON_TOOL_ERROR" ;;
            reset|*)    status_icon="" ;;
        esac
    fi

    # Get subagent count token (suppressed in compact mode — embedded as right eye)
    # Same logic: only suppress when compact mode AND faces are actually rendering
    local agents=""
    if [[ "$_compact_with_face" != "true" ]]; then
        if [[ "$state" == "processing" || "$state" == subagent* ]] && type get_subagent_title_suffix &>/dev/null; then
            agents=$(get_subagent_title_suffix 2>/dev/null)
        fi
    fi

    # Get session icon (empty when disabled or no icon assigned)
    local session_icon=""
    if [[ "${ENABLE_SESSION_ICONS:-false}" == "true" ]] && type get_session_icon &>/dev/null; then
        session_icon=$(get_session_icon 2>/dev/null)
    fi

    # Compose using format template with 4-level fallback:
    #   Level 1: {AGENT}_TITLE_FORMAT_{STATE} (agent+state specific)
    #   Level 2: {AGENT}_TITLE_FORMAT          (agent-wide)
    #   Level 3: TAVS_TITLE_FORMAT_{STATE}     (global per-state)
    #   Level 4: TAVS_TITLE_FORMAT             (global default)
    # Levels 1-2 resolved by _resolve_agent_variables() into TITLE_FORMAT_* / TITLE_FORMAT
    # Note: zsh has issues with brace expansion in ${:-} defaults, use intermediate var
    local _default_format='{FACE} {STATUS_ICON} {AGENTS} {SESSION_ICON} {BASE}'
    local state_upper
    state_upper=$(printf '%s' "$state" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

    # Level 1: Agent-specific + state-specific (e.g., CLAUDE_TITLE_FORMAT_PERMISSION)
    local _agent_state_var="TITLE_FORMAT_${state_upper}"
    local format=""
    eval "format=\${${_agent_state_var}:-}"

    # Level 2: Agent-specific all-states (e.g., CLAUDE_TITLE_FORMAT)
    [[ -z "$format" ]] && format="${TITLE_FORMAT:-}"

    # Level 3: Global state-specific (e.g., TAVS_TITLE_FORMAT_PERMISSION)
    if [[ -z "$format" ]]; then
        eval "format=\${TAVS_TITLE_FORMAT_${state_upper}:-}"
    fi

    # Level 4: Global default (backward compatible)
    [[ -z "$format" ]] && format="${TAVS_TITLE_FORMAT:-$_default_format}"

    local title="$format"

    # Substitute existing placeholders
    title="${title//\{FACE\}/$face}"
    title="${title//\{STATUS_ICON\}/$status_icon}"
    title="${title//\{AGENTS\}/$agents}"
    title="${title//\{SESSION_ICON\}/$session_icon}"
    title="${title//\{BASE\}/$base_title}"

    # Context & metadata tokens — only resolve when format contains them
    # This guard avoids unnecessary work (load_context_data, subshells) for
    # format strings that don't use these tokens.
    if [[ "$title" == *"{CONTEXT_"* || "$title" == *"{MODEL}"* || \
          "$title" == *"{COST}"* || "$title" == *"{DURATION}"* || \
          "$title" == *"{LINES}"* || "$title" == *"{MODE}"* ]]; then
        load_context_data  # From context-data.sh: bridge → transcript → empty
        # Context display tokens (10 types)
        title="${title//\{CONTEXT_PCT\}/$(resolve_context_token CONTEXT_PCT "$TAVS_CONTEXT_PCT")}"
        title="${title//\{CONTEXT_FOOD\}/$(resolve_context_token CONTEXT_FOOD "$TAVS_CONTEXT_PCT")}"
        title="${title//\{CONTEXT_FOOD_10\}/$(resolve_context_token CONTEXT_FOOD_10 "$TAVS_CONTEXT_PCT")}"
        title="${title//\{CONTEXT_BAR_H\}/$(resolve_context_token CONTEXT_BAR_H "$TAVS_CONTEXT_PCT")}"
        title="${title//\{CONTEXT_BAR_HL\}/$(resolve_context_token CONTEXT_BAR_HL "$TAVS_CONTEXT_PCT")}"
        title="${title//\{CONTEXT_BAR_V\}/$(resolve_context_token CONTEXT_BAR_V "$TAVS_CONTEXT_PCT")}"
        title="${title//\{CONTEXT_BAR_VM\}/$(resolve_context_token CONTEXT_BAR_VM "$TAVS_CONTEXT_PCT")}"
        title="${title//\{CONTEXT_BRAILLE\}/$(resolve_context_token CONTEXT_BRAILLE "$TAVS_CONTEXT_PCT")}"
        title="${title//\{CONTEXT_NUMBER\}/$(resolve_context_token CONTEXT_NUMBER "$TAVS_CONTEXT_PCT")}"
        title="${title//\{CONTEXT_ICON\}/$(resolve_context_token CONTEXT_ICON "$TAVS_CONTEXT_PCT")}"
        # Session metadata tokens
        title="${title//\{MODEL\}/${TAVS_CONTEXT_MODEL:-}}"
        title="${title//\{COST\}/$(_format_cost "${TAVS_CONTEXT_COST:-}")}"
        title="${title//\{DURATION\}/$(_format_duration "${TAVS_CONTEXT_DURATION:-}")}"
        title="${title//\{LINES\}/$(_format_lines "${TAVS_CONTEXT_LINES_ADD:-}")}"
        title="${title//\{MODE\}/${TAVS_PERMISSION_MODE:-}}"
    fi

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

    # "ignore" mode: always overwrite, never detect user titles
    if [[ "$respect_mode" != "ignore" ]]; then
        # Detect if user changed title since last set (on supported terminals)
        if detect_user_title_change; then
            # User changed title - respect their base, add our prefix
            if [[ "$respect_mode" == "full" ]]; then
                return 0
            fi
            # With "prefix" mode, we continue but use their base
        fi
    else
        # Ignore mode: clear any previously detected user title
        TITLE_USER_BASE=""
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

    # Check user override behavior
    local respect_mode="${TAVS_RESPECT_USER_TITLE:-prefix}"
    if [[ "$respect_mode" == "full" && -n "$TITLE_USER_BASE" ]]; then
        # In "full" respect mode, don't overwrite user titles even on reset
        return 0
    elif [[ "$respect_mode" == "ignore" ]]; then
        # In "ignore" mode, clear any detected user title
        TITLE_USER_BASE=""
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
