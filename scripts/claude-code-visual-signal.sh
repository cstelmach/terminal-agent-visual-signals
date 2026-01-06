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
# Performance: Uses bash builtins where possible ($EPOCHSECONDS, $SECONDS,
#              parameter expansion). Spawns ~8-10 external processes per state
#              change (pgrep, subshells for functions, background timer).
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
COLOR_IDLE="#443147"
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
    # Use $EPOCHSECONDS builtin instead of $(date +%s) - zero subprocess
    local now=$EPOCHSECONDS

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
    # Use $EPOCHSECONDS builtin instead of $(date +%s) - zero subprocess
    local elapsed=$(( EPOCHSECONDS - SESSION_TIME ))
    [[ $elapsed -lt $STATE_GRACE_PERIOD ]] && return 1
    return 0
}

# Record current state (wrapper for write_session_state)
record_state() {
    write_session_state "$1" ""
}

# === SKIP SIGNAL MECHANISM ===
# Used for inter-process communication between idle handler and unified timer
# When idle_prompt fires during stage 0 (complete), it signals timer to skip to stage 1

# Write skip signal for timer to detect
write_skip_signal() {
    local skip_file="${STATE_DB}.skip.${TTY_SAFE}"
    echo "1" > "$skip_file"
    [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] write_skip_signal: created $skip_file" >> "$IDLE_DEBUG_LOG"
}

# Check and clear skip signal (called by timer)
# Returns 0 if signal was present, 1 otherwise
check_and_clear_skip_signal() {
    local skip_file="${STATE_DB}.skip.${TTY_SAFE}"
    if [[ -f "$skip_file" ]]; then
        rm -f "$skip_file"
        [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] check_and_clear_skip_signal: found and cleared $skip_file" >> "$IDLE_DEBUG_LOG"
        return 0  # Signal was present
    fi
    return 1  # No signal
}

# === UNIFIED TIMER CONFIGURATION ===
# Complete and idle are now managed by a single timer triggered on Stop hook
# Stage 0 = Complete (green), Stage 1+ = Idle progression (purple fade)

# Toggle for showing stage progression with distinct colors/emojis
ENABLE_STAGE_INDICATORS=true  # Set to false to use subtle color fade only

# Unified stage colors - Stage 0 is complete (green), then idle progression
# Final stage uses "reset" marker to trigger OSC 111 (reset to terminal default)
UNIFIED_STAGE_COLORS=("$COLOR_COMPLETE" "$COLOR_IDLE" "#423148" "#3f3248" "#3a3348" "#373348" "reset")

# Unified stage emojis - Stage 0 is complete (green), then idle emojis
# Final stage has empty emoji (back to normal title)
UNIFIED_STAGE_EMOJIS=("$EMOJI_COMPLETE" "$EMOJI_IDLE" "🟣" "🟣" "🟣" "🟣" "")

# Duration in seconds for each stage
# Default: Stage 0 (complete) = 60s, then idle stages = 120s each
UNIFIED_STAGE_DURATIONS=(60 60 60 60 60 60 60)

# Bell configuration per stage (only complete stage gets bell by default)
UNIFIED_STAGE_BELLS=(true false false false false false false)

# How often the timer checks for stage transitions (in seconds)
# Should be <= shortest stage duration to ensure smooth transitions
# Testing: 2-5s | Production: 30s
UNIFIED_CHECK_INTERVAL=20

# === SAFETY: Maximum timer runtime ===
# Timer will self-terminate after this many seconds to prevent zombie processes
# Should be longer than total stage duration (60 + 6*120 = 780s)
# Default: 900s (15 minutes) - gives buffer beyond stage completion
MAX_TIMER_RUNTIME=450

# Legacy aliases for backward compatibility (if needed by other code)
IDLE_COLORS=("${UNIFIED_STAGE_COLORS[@]:1}")  # Skip stage 0 (complete)
IDLE_EMOJIS=("${UNIFIED_STAGE_EMOJIS[@]:1}")
IDLE_STAGE_DURATIONS=("${UNIFIED_STAGE_DURATIONS[@]:1}")
IDLE_CHECK_INTERVAL=$UNIFIED_CHECK_INTERVAL

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
get_unified_stage() {
    local elapsed=$1
    local cumulative=0
    RESULT_STAGE=0

    for duration in "${UNIFIED_STAGE_DURATIONS[@]}"; do
        cumulative=$((cumulative + duration))
        if [[ $elapsed -lt $cumulative ]]; then
            return
        fi
        RESULT_STAGE=$((RESULT_STAGE + 1))
    done
    # Past all stages - RESULT_STAGE now equals final stage number (triggers reset)
}

# Alias for backward compatibility
get_idle_stage() { get_unified_stage "$@"; }

# Kill any existing idle timer process (reads PID from consolidated state file)
kill_idle_timer() {
    read_session_state || return 0
    if [[ -n "$SESSION_TIMER_PID" ]] && kill -0 "$SESSION_TIMER_PID" 2>/dev/null; then
        kill "$SESSION_TIMER_PID" 2>/dev/null || true
        [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] kill_idle_timer: killed PID $SESSION_TIMER_PID" >> "$IDLE_DEBUG_LOG"
    fi
}

# SAFETY: Kill any stale timer processes for this TTY (catches orphaned processes)
# Uses pgrep instead of ps|grep|awk pipeline (1 process vs 5)
cleanup_stale_timers() {
    local stale_pids
    # pgrep -f matches against full command line; escape special chars in TTY path
    stale_pids=$(pgrep -f "unified_timer_worker.*${TTY_DEVICE}" 2>/dev/null) || true

    if [[ -n "$stale_pids" ]]; then
        for pid in $stale_pids; do
            kill "$pid" 2>/dev/null || true
            [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] cleanup_stale_timers: killed stale PID $pid" >> "$IDLE_DEBUG_LOG"
        done
    fi
}

# Unified background timer process for complete → idle → reset progression
# Stage 0 = complete (green), Stage 1+ = idle progression (purple fade)
# Runs as subprocess, checks every N seconds, updates color at stage boundaries
# Debug log: /tmp/claude-idle-timer.log (set IDLE_DEBUG=1 to enable)
IDLE_DEBUG="${IDLE_DEBUG:-0}"  # Set to 1 to enable debug logging
IDLE_DEBUG_LOG="/tmp/claude-idle-timer.log"

unified_timer_worker() {
    local tty_device="$1"
    local start_seconds=$SECONDS  # Use builtin instead of $(date +%s)
    local current_stage=0
    local last_applied_stage=-1  # Track which stage we last applied visuals for

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
    # Stage 0 is "complete" state, so record as complete
    write_session_state "complete" "$my_pid"

    [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] Unified timer started, tty=$tty_device, pid=$my_pid, cwd=$SHORT_CWD" >> "$IDLE_DEBUG_LOG"

    while true; do
        sleep "$UNIFIED_CHECK_INTERVAL"  # Configurable check interval

        # NO VOLUNTARY EXITS - timer only dies when killed by SIGTERM
        # This prevents the bell that occurs on voluntary exit
        # kill_idle_timer() will send SIGTERM when a new state starts

        # Skip processing if TTY invalid (terminal closed) - but don't exit
        [[ ! -w "$tty_device" ]] && continue

        # Check for skip signal (from idle_prompt hook)
        # If we're at stage 0 (complete) and skip signal received, jump to stage 1
        if check_and_clear_skip_signal && [[ $current_stage -eq 0 ]]; then
            [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] Skip signal received at stage 0, jumping to stage 1" >> "$IDLE_DEBUG_LOG"
            # Adjust start_seconds so elapsed time puts us at stage 1
            start_seconds=$((SECONDS - UNIFIED_STAGE_DURATIONS[0]))
        fi

        local elapsed=$(( SECONDS - start_seconds ))  # Pure bash, no subprocess
        get_unified_stage $elapsed  # Sets RESULT_STAGE (avoids subshell)
        current_stage=$RESULT_STAGE

        [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] elapsed=${elapsed}s, stage=$current_stage, max=${#UNIFIED_STAGE_COLORS[@]}" >> "$IDLE_DEBUG_LOG"

        # SAFETY: Check max runtime - self-terminate to prevent zombie processes
        if [[ $elapsed -ge $MAX_TIMER_RUNTIME ]]; then
            [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] SAFETY: Max runtime ($MAX_TIMER_RUNTIME s) reached, resetting and self-terminating" >> "$IDLE_DEBUG_LOG"

            # Try to reset visuals before terminating (non-blocking, best-effort)
            # Uses timeout to ensure we don't get stuck - termination happens regardless
            {
                # Reset background to default (OSC 111)
                printf "\033]111\033\\\\" >&3 2>/dev/null || true
                # Reset title to just the cwd (no emoji)
                printf "\033]0;%s\033\\\\" "$SHORT_CWD" >&3 2>/dev/null || true
            } &
            local reset_pid=$!
            # Wait max 1 second for reset, then kill it and proceed
            sleep 1
            kill $reset_pid 2>/dev/null || true

            # Clean exit via trap - no bell because we use SIGTERM to ourselves
            kill -TERM $my_pid 2>/dev/null
            exit 0  # Fallback if kill fails
        fi

        if [[ $current_stage -ge ${#UNIFIED_STAGE_COLORS[@]} ]]; then
            # All stages complete - enter time-limited dormant mode
            # Will be killed by kill_idle_timer() or self-terminate at MAX_TIMER_RUNTIME
            [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] FINAL - all stages complete, entering dormant mode (max ${MAX_TIMER_RUNTIME}s)" >> "$IDLE_DEBUG_LOG"

            # Update state to reset before going dormant
            write_session_state "reset" "$my_pid"

            # Dormant mode - but will self-terminate at MAX_TIMER_RUNTIME
            # The main loop continues checking elapsed time
            continue
        fi

        # Only apply visuals if stage changed (optimization)
        if [[ $current_stage -ne $last_applied_stage ]]; then
            last_applied_stage=$current_stage

            # Update state file: stage 0 = complete, stage 1+ = idle
            if [[ $current_stage -eq 0 ]]; then
                write_session_state "complete" "$my_pid"
            else
                write_session_state "idle" "$my_pid"
            fi

            # Get color and emoji for this stage
            local stage_color="${UNIFIED_STAGE_COLORS[$current_stage]}"
            local stage_emoji="${UNIFIED_STAGE_EMOJIS[$current_stage]}"

            [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] STAGE $current_stage: color='$stage_color' emoji='$stage_emoji'" >> "$IDLE_DEBUG_LOG"

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
            if [[ -n "$stage_emoji" && "$ENABLE_STAGE_INDICATORS" == "true" ]]; then
                [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] -> Sending OSC 0 with emoji" >> "$IDLE_DEBUG_LOG"
                printf "\033]0;%s %s\033\\\\" "$stage_emoji" "$SHORT_CWD" >&3
            else
                [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] -> Sending OSC 0 without emoji" >> "$IDLE_DEBUG_LOG"
                printf "\033]0;%s\033\\\\" "$SHORT_CWD" >&3
            fi

            [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] STAGE $current_stage transition complete" >> "$IDLE_DEBUG_LOG"
        fi
    done
}

# Legacy alias for backward compatibility
idle_timer_worker() { unified_timer_worker "$@"; }

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
        kill_idle_timer  # Cancel any existing timer first
        cleanup_stale_timers  # SAFETY: Kill any orphaned timers for this TTY

        # Set immediate complete visuals (stage 0 of unified timer)
        if [[ "$ENABLE_COMPLETE" == "true" ]]; then
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]11;%s\033\\\\" "$COLOR_COMPLETE" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s %s\033\\\\" "$EMOJI_COMPLETE" "$(get_short_cwd)" > "$TTY_DEVICE"
        else
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]111\033\\\\" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s\033\\\\" "$(get_short_cwd)" > "$TTY_DEVICE"
        fi

        send_bell_if_enabled "$STATE"

        # Start unified timer immediately (handles complete → idle → reset progression)
        # Timer will write its own PID to state file and manage all stage transitions
        ( unified_timer_worker "$TTY_DEVICE" ) &
        disown 2>/dev/null || true  # Prevent job control messages

        [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] COMPLETE HANDLER: spawned unified timer for $TTY_DEVICE" >> "$IDLE_DEBUG_LOG"
        # Note: State recording handled by timer worker (starts as "complete")
        ;;
    idle)
        # Idle notification from Claude Code - used as skip-forward hint
        # If unified timer is at stage 0 (complete), signal it to skip to stage 1 (idle)
        # If already at stage 1+, do nothing (timer is managing progression)

        if [[ "$ENABLE_IDLE" == "true" ]]; then
            # Check if a timer is running (state should be "complete" at stage 0)
            read_session_state || true

            if [[ -n "$SESSION_TIMER_PID" ]] && kill -0 "$SESSION_TIMER_PID" 2>/dev/null; then
                # Timer is running - send skip signal to jump from stage 0 to stage 1
                write_skip_signal
                [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] IDLE HANDLER: sent skip signal (timer pid=$SESSION_TIMER_PID)" >> "$IDLE_DEBUG_LOG"
            else
                # No timer running - this shouldn't normally happen, but handle gracefully
                # Start the unified timer from stage 0 (complete)
                [[ "$IDLE_DEBUG" == "1" ]] && echo "[$(date)] IDLE HANDLER: no timer found, starting unified timer" >> "$IDLE_DEBUG_LOG"

                # Set idle visuals immediately (skipping stage 0)
                [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && \
                    printf "\033]11;%s\033\\\\" "${UNIFIED_STAGE_COLORS[1]}" > "$TTY_DEVICE"
                [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && \
                    printf "\033]0;%s %s\033\\\\" "${UNIFIED_STAGE_EMOJIS[1]}" "$(get_short_cwd)" > "$TTY_DEVICE"

                # Start timer at stage 1 by adjusting start time
                # (Timer will detect it's past stage 0 and continue from there)
                ( unified_timer_worker "$TTY_DEVICE" ) &
                disown 2>/dev/null || true
            fi
            # No bell for idle - let the timer/skip handle it
        fi
        # Note: No state recording here - timer manages state
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
