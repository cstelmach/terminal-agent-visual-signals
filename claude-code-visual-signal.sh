#!/bin/bash
# ==============================================================================
# Terminal Visual Signal Controller for Claude Code
# ==============================================================================
#
# Changes terminal background color and tab title based on Claude Code state,
# making it easy to identify which terminals need attention.
#
# Repository: https://github.com/cstelmach/terminal-agent-visual-signals
# License:    MIT
#
# Compatible Terminals:
#   Ghostty, Kitty, WezTerm, iTerm2, VS Code, Cursor, GNOME Terminal,
#   Windows Terminal (2025+), Foot, and others with OSC 11/111 support.
#
# Requirements:
#   - Terminal with OSC 11/111 support
#   - Claude Code CLI
#   - Bash 3.2+ (macOS default)
#
# Usage: claude-code-visual-signal.sh {permission|idle|complete|processing|compacting|reset}
#
# Performance: Optimized to spawn ~1 external process (vs ~12-15 previously)
#              using bash builtins and parameter expansion.
# ==============================================================================

# === CONFIGURATION ===
ENABLE_BACKGROUND_CHANGE=true
ENABLE_TITLE_PREFIX=true

ENABLE_PROCESSING=true
ENABLE_PERMISSION=true
ENABLE_COMPLETE=true
ENABLE_IDLE=true
ENABLE_COMPACTING=true

COLOR_PROCESSING="#473D2F"
COLOR_PERMISSION="#4A2021"
COLOR_COMPLETE="#473046" #"#2B4639"
COLOR_IDLE="#473046"
COLOR_COMPACTING="#2B4645"  

EMOJI_PROCESSING="🟠"
EMOJI_PERMISSION="🔴"
EMOJI_COMPLETE="🟢"
EMOJI_IDLE="🟣"
EMOJI_COMPACTING="🔄"

# === BELL CONFIGURATION ===
# Enable/disable audible bell for each state (separate from visual changes)
BELL_ON_PROCESSING=false
BELL_ON_PERMISSION=true     # Alert: Claude needs permission
BELL_ON_COMPLETE=true       # Alert: Claude finished responding
BELL_ON_IDLE=false          # No bell for idle transitions
BELL_ON_COMPACTING=false
BELL_ON_RESET=false

# Helper function to send bell if enabled for a state
send_bell_if_enabled() {
    local state="$1"
    local should_bell=false
    case "$state" in
        processing) [[ "$BELL_ON_PROCESSING" == "true" ]] && should_bell=true ;;
        permission) [[ "$BELL_ON_PERMISSION" == "true" ]] && should_bell=true ;;
        complete)   [[ "$BELL_ON_COMPLETE" == "true" ]] && should_bell=true ;;
        idle)       [[ "$BELL_ON_IDLE" == "true" ]] && should_bell=true ;;
        compacting) [[ "$BELL_ON_COMPACTING" == "true" ]] && should_bell=true ;;
        reset)      [[ "$BELL_ON_RESET" == "true" ]] && should_bell=true ;;
    esac
    [[ "$should_bell" == "true" ]] && printf "\007" > "$TTY_DEVICE"
}

# === CONSOLIDATED STATE FILE ===
# Single file tracks all sessions: /tmp/claude-visual-signals.state
# Format per line: TTY_SAFE state priority timestamp timer_pid
# This prevents creating multiple files per session
STATE_DB="/tmp/claude-visual-signals.state"
STATE_GRACE_PERIOD=2  # Seconds to protect high-priority states

# Get priority for a state (Bash 3.2 compatible - no associative arrays)
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

# Read session state from consolidated file
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
    local now
    now=$(date +%s)

    # Debug logging for state writes
    [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] write_session_state: tty=$TTY_SAFE state=$state timer_pid='$timer_pid'" >> "$IDLE_DEBUG_LOG"

    # Create temp file, remove old entry for this TTY, add new entry
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

    # Always allow if no state for this session
    read_session_state || return 0

    # Always allow same or higher priority
    [[ $new_priority -ge $SESSION_PRIORITY ]] && return 0

    # For lower priority: check if grace period has passed
    local now elapsed
    now=$(date +%s)
    elapsed=$((now - SESSION_TIME))
    [[ $elapsed -lt $STATE_GRACE_PERIOD ]] && return 1
    return 0
}

# Record current state (wrapper for write_session_state)
record_state() {
    write_session_state "$1" ""
}

# === GRADUATED IDLE TIMER CONFIGURATION ===

# Toggle for showing stage progression with distinct colors/emojis
ENABLE_IDLE_STAGE_INDICATORS=true  # Set to false to use subtle color fade only

# Stage colors - distinct colors for testing (purple → blue → teal → olive → dim)
# Final stage uses "reset" marker to trigger OSC 111 (reset to terminal default)
IDLE_COLORS=("#443147" "#423148" "#3f3248" "#3a3348" "#373348" "reset")  # Stage 0-5

# Stage emojis - shows progression visually in title
# Final stage has empty emoji (back to normal title)
IDLE_EMOJIS=("🟣" "🟣" "🟣" "🟣" "🟣" "")  # Stage 0-5

# Duration in seconds to stay at each stage before transitioning to next
IDLE_STAGE_DURATIONS=(120 120 120 120 120 120)  # durations of phases in seconds

# How often the timer checks for stage transitions (in seconds)
# Should be <= shortest stage duration to ensure smooth transitions
# Testing: 2-5s | Production: 60s (when using 180s stage durations)
IDLE_CHECK_INTERVAL=30

# === TTY RESOLUTION (optimized) ===
# Uses $PPID built-in instead of ps -o ppid= call
tty_device=$(ps -o tty= -p $PPID 2>/dev/null)
tty_device="${tty_device// /}"  # Remove spaces with parameter expansion (no tr)

if [[ -n "$tty_device" && "$tty_device" != "??" && "$tty_device" != "-" ]]; then
    [[ "$tty_device" != /dev/* ]] && tty_device="/dev/$tty_device"
    [[ -w "$tty_device" ]] && TTY_DEVICE="$tty_device"
fi

# Fallback to /dev/tty (test actual write, not just -w flag)
[[ -z "$TTY_DEVICE" ]] && { echo -n "" > /dev/tty; } 2>/dev/null && TTY_DEVICE="/dev/tty"

# Exit silently if no TTY
[[ -z "$TTY_DEVICE" ]] && exit 0

# === PER-SESSION IDENTIFIER ===
# Create unique identifier per TTY for consolidated state file
# e.g., /dev/ttys005 → _dev_ttys005
TTY_SAFE="${TTY_DEVICE//\//_}"

# === SECURITY: Sanitize input for terminal output ===
# Strips control characters (0x00-0x1F, 0x7F) to prevent terminal escape injection
# Preserves Unicode characters for international path support
# See: https://dgl.cx/2023/09/ansi-terminal-security
sanitize_for_terminal() {
    local input="$1"
    # Remove ASCII control characters (0x00-0x1F and 0x7F)
    # This prevents injection of ESC (0x1B), BEL (0x07), and other control sequences
    printf '%s' "${input//[$'\x00'-$'\x1f'$'\x7f']/}"
}

# === HELPER: Get short CWD (optimized - no external commands) ===
get_short_cwd() {
    local cwd
    cwd=$(sanitize_for_terminal "$PWD")
    cwd="${cwd/#$HOME/\~}"

    # Count slashes with pure bash (no tr/wc pipeline)
    local tmp="${cwd//[!\/]/}"
    local slash_count=${#tmp}

    if [[ "$slash_count" -gt 2 ]]; then
        # Get parent and base with parameter expansion (no basename/dirname)
        local parent="${cwd%/*}"
        parent="${parent##*/}"
        local base="${cwd##*/}"
        cwd="…/$parent/$base"
    fi
    echo "$cwd"
}

# === GRADUATED IDLE TIMER FUNCTIONS ===

# Calculate current stage from elapsed seconds using cumulative durations
# Sets RESULT_STAGE to stage number (0 to N) or N+1 if past all stages (time for reset)
# Uses global variable return to avoid subshell overhead
get_idle_stage() {
    local elapsed=$1
    local cumulative=0
    RESULT_STAGE=0

    for duration in "${IDLE_STAGE_DURATIONS[@]}"; do
        cumulative=$((cumulative + duration))
        if [[ $elapsed -lt $cumulative ]]; then
            return
        fi
        RESULT_STAGE=$((RESULT_STAGE + 1))
    done
    # Past all stages - RESULT_STAGE now equals final stage number (triggers reset)
}

# Kill any existing idle timer process (reads PID from consolidated state file)
kill_idle_timer() {
    read_session_state || return 0
    if [[ -n "$SESSION_TIMER_PID" ]] && kill -0 "$SESSION_TIMER_PID" 2>/dev/null; then
        kill "$SESSION_TIMER_PID" 2>/dev/null || true
    fi
}

# Background timer process for graduated idle color decay
# Runs as subprocess, checks every 60 seconds, updates color at stage boundaries
# Debug log: /tmp/claude-idle-timer.log (remove IDLE_DEBUG=1 to disable)
IDLE_DEBUG="${IDLE_DEBUG:-0}"  # Set to 1 to enable debug logging
IDLE_DEBUG_LOG="/tmp/claude-idle-timer.log"

idle_timer_worker() {
    local tty_device="$1"
    local start_seconds=$SECONDS  # Use builtin instead of $(date +%s)

    # Signal trap for clean shutdown - close fd3 on termination
    trap 'exec 3>&-; exit 0' TERM INT

    # Get actual subshell PID (Bash 3.2 compatible - $$ returns parent PID in subshells)
    local my_pid
    my_pid=$( sh -c 'echo $PPID' )

    # Open TTY as file descriptor 3 for explicit management
    exec 3>"$tty_device"

    # Cache SHORT_CWD once at start - PWD doesn't change during timer lifetime
    local SHORT_CWD
    SHORT_CWD=$(get_short_cwd)

    # CRITICAL: Timer writes its own PID to state file immediately
    # This is more reliable than relying on parent's $! capture
    write_session_state "idle" "$my_pid"

    [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] Timer started, tty=$tty_device, pid=$my_pid, cwd=$SHORT_CWD" >> "$IDLE_DEBUG_LOG"

    while true; do
        sleep "$IDLE_CHECK_INTERVAL"  # Configurable check interval

        # NO VOLUNTARY EXITS - timer only dies when killed by SIGTERM
        # This prevents the bell that occurs on voluntary exit
        # kill_idle_timer() will send SIGTERM when a new state starts

        # Skip processing if TTY invalid (terminal closed) - but don't exit
        [[ ! -w "$tty_device" ]] && continue

        local elapsed=$(( SECONDS - start_seconds ))  # Pure bash, no subprocess
        get_idle_stage $elapsed  # Sets RESULT_STAGE (avoids subshell)
        local stage=$RESULT_STAGE

        [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] elapsed=${elapsed}s, stage=$stage, max=${#IDLE_COLORS[@]}" >> "$IDLE_DEBUG_LOG"

        if [[ $stage -ge ${#IDLE_COLORS[@]} ]]; then
            # All stages complete - DO NOT EXIT VOLUNTARILY
            # Voluntary exit (exit 0) triggers a bell notification in Ghostty
            # Instead, enter "dormant mode" and wait to be killed by kill_idle_timer()
            # When killed (SIGTERM), no bell occurs - only voluntary exits trigger it
            [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] FINAL - all stages complete, entering dormant mode (waiting to be killed)" >> "$IDLE_DEBUG_LOG"

            # Sleep forever - only SIGTERM from kill_idle_timer() ends this
            while true; do
                sleep 86400
            done
            # NEVER exits voluntarily - will be killed by SIGTERM
        fi

        # Get color and emoji for this stage
        local stage_color="${IDLE_COLORS[$stage]}"
        local stage_emoji="${IDLE_EMOJIS[$stage]}"

        [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] STAGE $stage: color='$stage_color' emoji='$stage_emoji'" >> "$IDLE_DEBUG_LOG"

        # Apply background color (handle "reset" specially with OSC 111)
        # Write to fd 3 (our managed TTY descriptor)
        if [[ "$stage_color" == "reset" ]]; then
            [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] -> Sending OSC 111 (reset bg)" >> "$IDLE_DEBUG_LOG"
            printf "\033]111\033\\\\" >&3
        else
            [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] -> Sending OSC 11 with color" >> "$IDLE_DEBUG_LOG"
            printf "\033]11;%s\033\\\\" "$stage_color" >&3
        fi

        # Apply title with or without emoji (uses cached SHORT_CWD)
        if [[ -n "$stage_emoji" && "$ENABLE_IDLE_STAGE_INDICATORS" == "true" ]]; then
            [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] -> Sending OSC 0 with emoji" >> "$IDLE_DEBUG_LOG"
            printf "\033]0;%s %s\033\\\\" "$stage_emoji" "$SHORT_CWD" >&3
        else
            [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] -> Sending OSC 0 without emoji" >> "$IDLE_DEBUG_LOG"
            printf "\033]0;%s\033\\\\" "$SHORT_CWD" >&3
        fi

        [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] STAGE $stage complete" >> "$IDLE_DEBUG_LOG"
    done
}

# === MAIN LOGIC ===
STATE="${1:-}"

case "$STATE" in
    processing)
        # Check priority - don't override higher-priority states (e.g., permission)
        should_change_state "$STATE" || exit 0
        kill_idle_timer  # Cancel any graduated idle timer
        if [[ "$ENABLE_PROCESSING" == "true" ]]; then
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]11;%s\033\\\\" "$COLOR_PROCESSING" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s %s\033\\\\" "$EMOJI_PROCESSING" "$(get_short_cwd)" > "$TTY_DEVICE"
        else
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]111\033\\\\" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s\033\\\\" "$(get_short_cwd)" > "$TTY_DEVICE"
        fi
        send_bell_if_enabled "$STATE"
        record_state "$STATE"
        ;;
    permission)
        # Permission is high priority - always proceeds, records state
        kill_idle_timer  # Cancel any graduated idle timer
        if [[ "$ENABLE_PERMISSION" == "true" ]]; then
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]11;%s\033\\\\" "$COLOR_PERMISSION" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s %s\033\\\\" "$EMOJI_PERMISSION" "$(get_short_cwd)" > "$TTY_DEVICE"
        fi
        send_bell_if_enabled "$STATE"
        record_state "$STATE"
        # Permission fallback: do nothing (stay in current state)
        ;;
    complete)
        # Check priority - don't override higher-priority states
        should_change_state "$STATE" || exit 0
        kill_idle_timer  # Cancel any graduated idle timer
        if [[ "$ENABLE_COMPLETE" == "true" ]]; then
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]11;%s\033\\\\" "$COLOR_COMPLETE" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s %s\033\\\\" "$EMOJI_COMPLETE" "$(get_short_cwd)" > "$TTY_DEVICE"
        else
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]111\033\\\\" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s\033\\\\" "$(get_short_cwd)" > "$TTY_DEVICE"
        fi
        send_bell_if_enabled "$STATE"
        record_state "$STATE"
        ;;
    idle)
        # Idle is high priority - always proceeds
        kill_idle_timer  # Kill any existing timer first

        if [[ "$ENABLE_IDLE" == "true" ]]; then
            # Set initial idle color and emoji (stage 0) - uses ST (\033\\) to avoid audible bell
            # Use IDLE_EMOJIS[0] for consistency with timer stages (not generic EMOJI_IDLE)
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && \
                printf "\033]11;%s\033\\\\" "${IDLE_COLORS[0]}" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && \
                printf "\033]0;%s %s\033\\\\" "${IDLE_EMOJIS[0]}" "$(get_short_cwd)" > "$TTY_DEVICE"

            # Spawn background timer for graduated color fade
            # Timer will write its own PID to state file (more reliable than $! capture)
            ( idle_timer_worker "$TTY_DEVICE" ) &
            disown 2>/dev/null || true  # Prevent job control messages

            [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] IDLE HANDLER: spawned timer for $TTY_DEVICE" >> "$IDLE_DEBUG_LOG"
            send_bell_if_enabled "$STATE"
        else
            send_bell_if_enabled "$STATE"
            record_state "$STATE"
        fi
        ;;
    compacting)
        # Check priority - don't override higher-priority states
        should_change_state "$STATE" || exit 0
        kill_idle_timer  # Cancel any graduated idle timer
        if [[ "$ENABLE_COMPACTING" == "true" ]]; then
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]11;%s\033\\\\" "$COLOR_COMPACTING" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s %s\033\\\\" "$EMOJI_COMPACTING" "$(get_short_cwd)" > "$TTY_DEVICE"
        fi
        send_bell_if_enabled "$STATE"
        record_state "$STATE"
        ;;
    reset)
        # Reset always proceeds and clears state
        kill_idle_timer  # Cancel any graduated idle timer
        [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]111\033\\\\" > "$TTY_DEVICE"
        [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s\033\\\\" "$(get_short_cwd)" > "$TTY_DEVICE"
        send_bell_if_enabled "$STATE"
        record_state "$STATE"
        ;;
    *)
        echo "Usage: $0 {permission|idle|complete|processing|compacting|reset}" >&2
        exit 1
        ;;
esac

exit 0
