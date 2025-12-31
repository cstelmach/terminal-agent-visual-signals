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
# Usage: claude-code-visual-signal.sh {permission|idle|complete|processing|reset}
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

COLOR_PROCESSING="#473D2F"
COLOR_PERMISSION="#4A2021"
COLOR_COMPLETE="#3E3046" #"#2B4636"
COLOR_IDLE="#3E3046"

EMOJI_PROCESSING="🟠"
EMOJI_PERMISSION="🔴"
EMOJI_COMPLETE="🟢"
EMOJI_IDLE="🟣"

# === GRADUATED IDLE TIMER CONFIGURATION ===
IDLE_LOCK_DIR="/tmp/claude-idle-timer.lock"
IDLE_COLORS=("#3E3046" "#362A3D" "#2E2534" "#26202B" "#1E1B22")  # Stage 0-4

# Duration in seconds to stay at each stage before transitioning to next
# Stage 0→1, 1→2, 2→3, 3→4, 4→reset (5 values = 5 transitions)
IDLE_STAGE_DURATIONS=(180 180 180 180 180)  # 3 min each = 15 min total

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
# Returns stage number (0 to N) or N+1 if past all stages (time for reset)
get_idle_stage() {
    local elapsed=$1
    local cumulative=0
    local stage=0

    for duration in "${IDLE_STAGE_DURATIONS[@]}"; do
        cumulative=$((cumulative + duration))
        if [[ $elapsed -lt $cumulative ]]; then
            echo $stage
            return
        fi
        stage=$((stage + 1))
    done

    # Past all stages - return final stage number (triggers reset)
    echo $stage
}

# Kill any existing idle timer process
kill_idle_timer() {
    if [[ -d "$IDLE_LOCK_DIR" && -f "$IDLE_LOCK_DIR/pid" ]]; then
        local old_pid
        old_pid=$(cat "$IDLE_LOCK_DIR/pid" 2>/dev/null)
        if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
            kill "$old_pid" 2>/dev/null || true
        fi
        rm -rf "$IDLE_LOCK_DIR" 2>/dev/null || true
    fi
}

# Background timer process for graduated idle color decay
# Runs as subprocess, checks every 60 seconds, updates color at stage boundaries
idle_timer_worker() {
    local tty_device="$1"
    local start_time
    start_time=$(date +%s)

    while true; do
        sleep 60  # Check every minute

        # Exit if lock directory removed (cancelled by activity)
        [[ ! -d "$IDLE_LOCK_DIR" ]] && exit 0

        # Exit if TTY no longer valid (terminal closed)
        [[ ! -w "$tty_device" ]] && { rm -rf "$IDLE_LOCK_DIR" 2>/dev/null; exit 0; }

        local elapsed=$(( $(date +%s) - start_time ))
        local stage
        stage=$(get_idle_stage $elapsed)

        if [[ $stage -ge ${#IDLE_COLORS[@]} ]]; then
            # Final stage: reset to default, remove emoji
            printf "\033]111\033\\\\" > "$tty_device"
            printf "\033]0;%s\033\\\\" "$(get_short_cwd)" > "$tty_device"
            rm -rf "$IDLE_LOCK_DIR" 2>/dev/null
            exit 0
        fi

        # Apply stage color (only if changed from previous)
        printf "\033]11;%s\033\\\\" "${IDLE_COLORS[$stage]}" > "$tty_device"
    done
}

# === MAIN LOGIC ===
STATE="${1:-}"

case "$STATE" in
    processing)
        kill_idle_timer  # Cancel any graduated idle timer
        if [[ "$ENABLE_PROCESSING" == "true" ]]; then
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]11;%s\007" "$COLOR_PROCESSING" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s %s\007" "$EMOJI_PROCESSING" "$(get_short_cwd)" > "$TTY_DEVICE"
        else
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]111\007" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s\007" "$(get_short_cwd)" > "$TTY_DEVICE"
        fi
        ;;
    permission)
        kill_idle_timer  # Cancel any graduated idle timer
        if [[ "$ENABLE_PERMISSION" == "true" ]]; then
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]11;%s\007" "$COLOR_PERMISSION" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s %s\007" "$EMOJI_PERMISSION" "$(get_short_cwd)" > "$TTY_DEVICE"
        fi
        # Permission fallback: do nothing (stay in current state)
        ;;
    complete)
        kill_idle_timer  # Cancel any graduated idle timer
        if [[ "$ENABLE_COMPLETE" == "true" ]]; then
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]11;%s\007" "$COLOR_COMPLETE" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s %s\007" "$EMOJI_COMPLETE" "$(get_short_cwd)" > "$TTY_DEVICE"
        else
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]111\007" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s\007" "$(get_short_cwd)" > "$TTY_DEVICE"
        fi
        ;;
    idle)
        kill_idle_timer  # Kill any existing timer first

        if [[ "$ENABLE_IDLE" == "true" ]]; then
            # Set initial idle color (stage 0) - uses ST (\033\\) to avoid audible bell
            [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && \
                printf "\033]11;%s\033\\\\" "${IDLE_COLORS[0]}" > "$TTY_DEVICE"
            [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && \
                printf "\033]0;%s %s\033\\\\" "$EMOJI_IDLE" "$(get_short_cwd)" > "$TTY_DEVICE"

            # Spawn background timer for graduated color fade
            mkdir -p "$IDLE_LOCK_DIR" 2>/dev/null
            ( idle_timer_worker "$TTY_DEVICE" ) &
            echo $! > "$IDLE_LOCK_DIR/pid"
            disown  # Prevent job control messages
        fi
        ;;
    reset)
        kill_idle_timer  # Cancel any graduated idle timer
        [[ "$ENABLE_BACKGROUND_CHANGE" == "true" ]] && printf "\033]111\007" > "$TTY_DEVICE"
        [[ "$ENABLE_TITLE_PREFIX" == "true" ]] && printf "\033]0;%s\007" "$(get_short_cwd)" > "$TTY_DEVICE"
        ;;
    *)
        echo "Usage: $0 {permission|idle|complete|processing|reset}" >&2
        exit 1
        ;;
esac

exit 0
