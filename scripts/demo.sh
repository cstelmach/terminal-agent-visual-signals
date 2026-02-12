#!/bin/bash
# ==============================================================================
# TAVS Demo Recording Script
# ==============================================================================
# Cycles through all visual states with timed pauses, designed for screen
# recording tools (asciinema, native screen capture, OBS, etc.).
#
# Usage:
#   ./scripts/demo.sh              Full showcase (~45 seconds)
#   ./scripts/demo.sh --quick      Quick cycle (~15 seconds)
#   ./scripts/demo.sh --states     States only, no intro text
#
# See also:
#   ./scripts/demo-session.sh      Realistic single-session simulator
#   ./scripts/demo-showcase.sh     Multi-session launcher (5-10 tabs)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
TRIGGER="$REPO_DIR/src/core/trigger.sh"

# Colors for demo text
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# Timing
PAUSE_SHORT=2
PAUSE_LONG=3
PAUSE_INTRO=1

quick_mode=false
states_only=false

case "${1:-}" in
    --quick)  quick_mode=true; PAUSE_SHORT=1; PAUSE_LONG=1; PAUSE_INTRO=0 ;;
    --states) states_only=true; PAUSE_SHORT=2; PAUSE_LONG=2; PAUSE_INTRO=0 ;;
esac

# Helper: show a demo step
demo_step() {
    local state="$1"
    local label="$2"
    local icon="$3"
    local pause="${4:-$PAUSE_LONG}"

    if [[ "$states_only" == "false" ]]; then
        echo ""
        echo -e "  ${BOLD}${icon}  ${label}${RESET}"
        echo -e "  ${DIM}→ ./src/core/trigger.sh ${state}${RESET}"
    fi

    "$TRIGGER" "$state"
    sleep "$pause"
}

# ==============================================================================
# INTRO
# ==============================================================================

if [[ "$states_only" == "false" ]]; then
    "$TRIGGER" reset
    echo ""
    echo -e "${BOLD}  TAVS — Terminal Agent Visual Signals${RESET}"
    echo -e "${DIM}  Visual feedback for AI coding sessions${RESET}"
    echo ""
    sleep "$PAUSE_INTRO"
fi

# ==============================================================================
# STATE CYCLE
# ==============================================================================

demo_step "processing" "Processing — Agent is working" "🟠"
demo_step "permission" "Permission — Needs your approval" "🔴"
demo_step "processing" "Approved — Back to processing" "🟠" "$PAUSE_SHORT"
demo_step "compacting" "Compacting — Context compression" "🔄"
demo_step "subagent-start" "Subagent — Spawned a task agent" "🔀"

if [[ "$quick_mode" == "false" ]]; then
    demo_step "subagent-start" "Subagent — Second agent spawned" "🔀" "$PAUSE_SHORT"
    demo_step "subagent-stop" "Subagent returned (1 remaining)" "🔀" "$PAUSE_SHORT"
    demo_step "subagent-stop" "All subagents complete" "🟠" "$PAUSE_SHORT"
    demo_step "tool_error" "Tool Error — Execution failed" "❌" "$PAUSE_SHORT"
fi

demo_step "complete" "Complete — Response finished" "🟢"

# Idle fade
if [[ "$quick_mode" == "false" ]]; then
    if [[ "$states_only" == "false" ]]; then
        echo ""
        echo -e "  ${BOLD}🟣  Idle — Graduated purple fade${RESET}"
        echo -e "  ${DIM}→ ./src/core/trigger.sh idle${RESET}"
    fi
    "$TRIGGER" idle
    sleep 4
fi

# ==============================================================================
# RESET
# ==============================================================================

"$TRIGGER" reset

if [[ "$states_only" == "false" ]]; then
    echo ""
    echo -e "  ${BOLD}↺  Reset — Back to default${RESET}"
    echo ""
    echo -e "  ${DIM}Install: claude plugin marketplace add cstelmach/terminal-agent-visual-signals${RESET}"
    echo -e "  ${DIM}         claude plugin install tavs@terminal-agent-visual-signals${RESET}"
    echo ""
fi
