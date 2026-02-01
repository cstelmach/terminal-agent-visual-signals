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
source "$CORE_DIR/spinner.sh"
source "$CORE_DIR/idle-worker.sh"
source "$CORE_DIR/detect.sh"
source "$CORE_DIR/backgrounds.sh"
source "$CORE_DIR/title.sh"

# Source iTerm2-specific title detection if applicable
[[ "$TERM_PROGRAM" == "iTerm.app" && -f "$CORE_DIR/title-iterm2.sh" ]] && \
    source "$CORE_DIR/title-iterm2.sh"

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

# Helper: Get current palette mode based on theme resolution
# Returns "dark" or "light"
# Uses IS_DARK_THEME from theme.sh (already respects FORCE_MODE and ENABLE_LIGHT_DARK_SWITCHING)
_get_palette_mode() {
    # 1. Respect explicit FORCE_MODE overrides
    if [[ "$FORCE_MODE" == "light" ]]; then
        echo "light"
        return
    elif [[ "$FORCE_MODE" == "dark" ]]; then
        echo "dark"
        return
    fi

    # 2. For auto/unset: use IS_DARK_THEME from theme.sh (if available)
    #    This ensures palette stays in sync with background colors
    if [[ "$IS_DARK_THEME" == "false" ]]; then
        echo "light"
        return
    elif [[ "$IS_DARK_THEME" == "true" ]]; then
        echo "dark"
        return
    fi

    # 3. Fallback: only use system detection if auto dark mode is enabled
    if [[ "$FORCE_MODE" == "auto" ]] && [[ "$ENABLE_LIGHT_DARK_SWITCHING" == "true" ]]; then
        local system_mode
        system_mode=$(get_system_mode)
        if [[ "$system_mode" == "light" ]]; then
            echo "light"
            return
        fi
    fi

    # 4. Final fallback: dark mode
    echo "dark"
}

# Helper: Apply palette if enabled (must be called BEFORE background)
# This prevents contrast flicker by setting colors before background changes
_apply_palette_if_enabled() {
    should_enable_palette_theming || return 0
    local mode
    mode=$(_get_palette_mode)
    send_osc_palette "$mode"
}

# Helper: Reset palette if enabled
_reset_palette_if_enabled() {
    should_enable_palette_theming || return 0
    send_osc_palette_reset
}

# Helper: Check if we should send title for current state
# Returns 0 (true) if title should be sent, 1 (false) to skip
# Respects TAVS_TITLE_MODE: full (all), skip-processing (skip processing), off (none)
should_send_title() {
    local state="${1:-}"

    # Master toggle must be on
    [[ "$ENABLE_TITLE_PREFIX" != "true" ]] && return 1

    # Check title mode
    case "$TAVS_TITLE_MODE" in
        "full")
            # Send title for all states
            return 0
            ;;
        "skip-processing")
            # Skip only processing state (let Claude Code handle it)
            [[ "$state" == "processing" ]] && return 1
            return 0
            ;;
        "off")
            # Never send titles
            return 1
            ;;
        *)
            # Default: skip-processing
            [[ "$state" == "processing" ]] && return 1
            return 0
            ;;
    esac
}

# Main Logic
STATE="${1:-}"

case "$STATE" in
    processing)
        should_change_state "$STATE" || exit 0
        kill_idle_timer
        if [[ "$ENABLE_PROCESSING" == "true" ]]; then
            # Apply palette FIRST (prevents contrast flicker)
            _apply_palette_if_enabled
            should_send_bg_color && send_osc_bg "$COLOR_PROCESSING"
            # Use new title system with user override detection
            should_send_title "processing" && set_tavs_title "processing"
            set_state_background_image "processing"
        else
            _reset_palette_if_enabled
            should_send_bg_color && send_osc_bg "reset"
            should_send_title "processing" && reset_tavs_title
            clear_background_image
        fi
        send_bell_if_enabled "$STATE"
        record_state "$STATE"
        ;;

    permission)
        kill_idle_timer
        if [[ "$ENABLE_PERMISSION" == "true" ]]; then
            # Apply palette FIRST (prevents contrast flicker)
            _apply_palette_if_enabled
            should_send_bg_color && send_osc_bg "$COLOR_PERMISSION"
            # Use new title system with user override detection
            should_send_title "permission" && set_tavs_title "permission"
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
            # Apply palette FIRST (prevents contrast flicker)
            _apply_palette_if_enabled
            should_send_bg_color && send_osc_bg "$COLOR_COMPLETE"
            # Use new title system with user override detection
            should_send_title "complete" && set_tavs_title "complete"
            set_state_background_image "complete"
        else
            _reset_palette_if_enabled
            should_send_bg_color && send_osc_bg "reset"
            should_send_title "complete" && reset_tavs_title
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
                # Fallback start - apply palette before background
                _apply_palette_if_enabled
                should_send_bg_color && send_osc_bg "${UNIFIED_STAGE_COLORS[1]}"
                # Use new title system with user override detection
                should_send_title "idle" && set_tavs_title "idle_1"
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
            # Apply palette FIRST (prevents contrast flicker)
            _apply_palette_if_enabled
            should_send_bg_color && send_osc_bg "$COLOR_COMPACTING"
            # Use new title system with user override detection
            should_send_title "compacting" && set_tavs_title "compacting"
            set_state_background_image "compacting"
        fi
        send_bell_if_enabled "$STATE"
        record_state "$STATE"
        ;;

    reset)
        kill_idle_timer
        # Reset palette FIRST, then background
        _reset_palette_if_enabled
        should_send_bg_color && send_osc_bg "reset"
        # Use new title system - reset to base title
        should_send_title "reset" && reset_tavs_title
        clear_background_image
        send_bell_if_enabled "$STATE"
        record_state "$STATE"
        # Initialize session spinner if session identity is enabled
        reset_spinner
        [[ "$TAVS_SESSION_IDENTITY" == "true" ]] && init_session_spinner
        # Clear title state on full reset (new session)
        clear_title_state 2>/dev/null || true
        ;;

    *)
        echo "Usage: $0 {permission|idle|complete|processing|compacting|reset}" >&2
        exit 1
        ;;
esac

exit 0
