#!/bin/bash
# ==============================================================================
# TAVS Demo — Multi-Session Showcase Launcher
# ==============================================================================
# Opens multiple terminal sessions running different workflow personas.
# Designed for screen recording to showcase TAVS in a multi-agent environment.
#
# Usage:
#   ./scripts/demo-multi-session.sh                # 6 sessions, 90 seconds
#   ./scripts/demo-multi-session.sh --sessions 8   # 8 sessions
#   ./scripts/demo-multi-session.sh --duration 120 # 2 minutes
#   ./scripts/demo-multi-session.sh --backgrounds  # Enable background images
#   ./scripts/demo-multi-session.sh --terminal     # Auto-detect and use terminal API
#
# Supports:
#   - iTerm2: Opens split panes via AppleScript
#   - Ghostty: Opens new tabs
#   - Other: Prints commands to run manually
#
# Recording tips:
#   1. Arrange terminal windows/tabs before starting
#   2. Start screen recording (Cmd+Shift+5, OBS, or asciinema)
#   3. Run this script
#   4. Wait for the duration to complete
#   5. Stop recording
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SESSION_SCRIPT="$SCRIPT_DIR/demo-simulate-session.sh"

# ==============================================================================
# CONFIGURATION
# ==============================================================================

NUM_SESSIONS=6
DURATION=90
BACKGROUNDS=""
USE_TERMINAL_API="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sessions)    NUM_SESSIONS="$2"; shift 2 ;;
        --duration)    DURATION="$2"; shift 2 ;;
        --backgrounds) BACKGROUNDS="--backgrounds"; shift ;;
        --terminal)    USE_TERMINAL_API="true"; shift ;;
        --help|-h)
            sed -n '2,/^# ====/{/^# ====/d;s/^# //;p}' "$0"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ==============================================================================
# SESSION DEFINITIONS
# ==============================================================================
# Each session has a persona and a label that appears as the tab title.
# Personas cycle to give visual variety.

SESSIONS=(
    "coding:Auth Service"
    "research:API Docs"
    "review:PR #42"
    "debug:Fix Crash"
    "coding:Unit Tests"
    "refactor:Cleanup"
    "research:Migration"
    "coding:Dashboard"
    "debug:Edge Cases"
    "review:Security Audit"
)

# ==============================================================================
# TERMINAL DETECTION
# ==============================================================================

BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

detect_terminal() {
    if [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]] || [[ -n "${ITERM_SESSION_ID:-}" ]]; then
        echo "iterm2"
    elif [[ -n "${GHOSTTY_RESOURCES_DIR:-}" ]] || [[ "${TERM_PROGRAM:-}" == "ghostty" ]]; then
        echo "ghostty"
    elif [[ "${TERM_PROGRAM:-}" == "WezTerm" ]]; then
        echo "wezterm"
    elif [[ "${TERM_PROGRAM:-}" == "tmux" ]] || [[ -n "${TMUX:-}" ]]; then
        echo "tmux"
    else
        echo "unknown"
    fi
}

# ==============================================================================
# LAUNCHER: iTerm2 (AppleScript)
# ==============================================================================

launch_iterm2() {
    echo -e "  ${DIM}Launching ${NUM_SESSIONS} sessions in iTerm2 split panes...${RESET}"

    # Build session commands
    local commands=()
    local i
    for (( i=0; i<NUM_SESSIONS; i++ )); do
        local entry="${SESSIONS[$i]}"
        local persona="${entry%%:*}"
        local label="${entry#*:}"
        commands+=("cd '$REPO_DIR' && '$SESSION_SCRIPT' --persona '$persona' --label '$label' --duration $DURATION $BACKGROUNDS")
    done

    # Create AppleScript to open split panes
    local script="
tell application \"iTerm\"
    tell current window
        tell current session
            write text \"${commands[0]}\"
        end tell"

    # Add remaining sessions as split panes
    for (( i=1; i<NUM_SESSIONS; i++ )); do
        if (( i % 2 == 1 )); then
            script+="
        tell current session
            set newSession to (split vertically with default profile)
            tell newSession
                write text \"${commands[$i]}\"
            end tell
        end tell"
        else
            script+="
        tell current session
            set newSession to (split horizontally with default profile)
            tell newSession
                write text \"${commands[$i]}\"
            end tell
        end tell"
        fi
    done

    script+="
    end tell
end tell"

    osascript -e "$script" 2>/dev/null
}

# ==============================================================================
# LAUNCHER: tmux
# ==============================================================================

launch_tmux() {
    local session_name="tavs-demo"

    echo -e "  ${DIM}Launching ${NUM_SESSIONS} sessions in tmux...${RESET}"

    # Kill existing session if present
    tmux kill-session -t "$session_name" 2>/dev/null || true

    # Create session with first command
    local entry="${SESSIONS[0]}"
    local persona="${entry%%:*}"
    local label="${entry#*:}"
    tmux new-session -d -s "$session_name" \
        "cd '$REPO_DIR' && '$SESSION_SCRIPT' --persona '$persona' --label '$label' --duration $DURATION $BACKGROUNDS; read"

    # Add remaining panes
    local i
    for (( i=1; i<NUM_SESSIONS; i++ )); do
        entry="${SESSIONS[$i]}"
        persona="${entry%%:*}"
        label="${entry#*:}"
        tmux split-window -t "$session_name" \
            "cd '$REPO_DIR' && '$SESSION_SCRIPT' --persona '$persona' --label '$label' --duration $DURATION $BACKGROUNDS; read"
        tmux select-layout -t "$session_name" tiled
    done

    # Attach
    tmux attach -t "$session_name"
}

# ==============================================================================
# LAUNCHER: Manual (any terminal)
# ==============================================================================

launch_manual() {
    echo -e "  ${BOLD}Open ${NUM_SESSIONS} terminal tabs and run one command per tab:${RESET}"
    echo ""

    local i
    for (( i=0; i<NUM_SESSIONS; i++ )); do
        local entry="${SESSIONS[$i]}"
        local persona="${entry%%:*}"
        local label="${entry#*:}"
        printf "  ${DIM}Tab %d:${RESET}  ./scripts/demo-simulate-session.sh --persona %-10s --label %-16s --duration %s %s\n" \
            "$((i + 1))" "$persona" "\"$label\"" "$DURATION" "$BACKGROUNDS"
    done

    echo ""
    echo -e "  ${DIM}Tip: Start screen recording before running the commands.${RESET}"
    echo -e "  ${DIM}Each session starts with a random delay (0-3s) to desync.${RESET}"
}

# ==============================================================================
# MAIN
# ==============================================================================

# Cap sessions to available definitions
if [[ $NUM_SESSIONS -gt ${#SESSIONS[@]} ]]; then
    NUM_SESSIONS=${#SESSIONS[@]}
fi

echo ""
echo -e "  ${BOLD}TAVS Multi-Session Showcase${RESET}"
echo -e "  ${DIM}Sessions: ${NUM_SESSIONS} | Duration: ${DURATION}s${RESET}"
[[ -n "$BACKGROUNDS" ]] && echo -e "  ${DIM}Background images: enabled${RESET}"
echo ""

TERMINAL=$(detect_terminal)

if [[ "$USE_TERMINAL_API" == "true" ]]; then
    case "$TERMINAL" in
        iterm2) launch_iterm2 ;;
        tmux)   launch_tmux ;;
        *)      launch_manual ;;
    esac
else
    # Check if we're in a supported terminal and suggest --terminal
    case "$TERMINAL" in
        iterm2)
            echo -e "  ${DIM}Detected iTerm2. Use --terminal flag to auto-open split panes.${RESET}"
            echo ""
            ;;
        tmux)
            echo -e "  ${DIM}Detected tmux. Use --terminal flag to auto-create panes.${RESET}"
            echo ""
            ;;
    esac
    launch_manual
fi
