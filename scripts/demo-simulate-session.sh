#!/bin/bash
# ==============================================================================
# TAVS Demo — Realistic Session Simulator
# ==============================================================================
# Simulates a realistic AI coding session with natural workflow patterns.
# Run 5-10 instances in separate terminal tabs for a multi-agent showcase.
#
# Usage:
#   ./scripts/demo-simulate-session.sh                    # Random persona, 2 minutes
#   ./scripts/demo-simulate-session.sh --persona coding   # Specific workflow
#   ./scripts/demo-simulate-session.sh --duration 180     # 3-minute session
#   ./scripts/demo-simulate-session.sh --backgrounds      # Enable background images
#   ./scripts/demo-simulate-session.sh --label "Auth API" # Custom title label
#
# Personas:
#   coding    — Long processing bursts, occasional permissions, some subagents
#   review    — Quick cycles, frequent permission requests
#   research  — Processing with many parallel subagent spawns
#   refactor  — Steady processing → complete cycles
#   debug     — Processing → tool errors → retries → eventual success
#
# Multi-session recording:
#   Open 5-10 terminal tabs, run in each with different personas:
#
#   Tab 1:  ./scripts/demo-simulate-session.sh --persona coding --label "Auth API"
#   Tab 2:  ./scripts/demo-simulate-session.sh --persona research --label "Docs"
#   Tab 3:  ./scripts/demo-simulate-session.sh --persona review --label "PR #42"
#   Tab 4:  ./scripts/demo-simulate-session.sh --persona debug --label "Fix crash"
#   Tab 5:  ./scripts/demo-simulate-session.sh --persona coding --label "Tests"
#   Tab 6:  ./scripts/demo-simulate-session.sh --persona refactor --label "Cleanup"
#
#   Then screen-record the whole display (Cmd+Shift+5 or OBS).
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
TRIGGER="$REPO_DIR/src/core/trigger.sh"

# ==============================================================================
# CONFIGURATION
# ==============================================================================

DURATION=120
PERSONA=""
LABEL=""
ENABLE_BG="false"
VERBOSE="false"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --persona)    PERSONA="$2"; shift 2 ;;
        --duration)   DURATION="$2"; shift 2 ;;
        --label)      LABEL="$2"; shift 2 ;;
        --backgrounds) ENABLE_BG="true"; shift ;;
        --verbose|-v) VERBOSE="true"; shift ;;
        --help|-h)
            sed -n '2,/^# ====/{/^# ====/d;s/^# //;p}' "$0"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Validate numeric input
if ! [[ "$DURATION" =~ ^[0-9]+$ ]]; then
    echo "Error: --duration must be a positive integer." >&2
    exit 1
fi

# ==============================================================================
# PERSONA DEFINITIONS
# ==============================================================================
# Each persona defines probability weights for state transitions.
# Format: STATE:WEIGHT (higher = more likely to transition to that state)
#
# Workflow phases within each persona:
#   1. Start: always begins with processing (user submitted a prompt)
#   2. Work: cycles through states based on persona weights
#   3. Complete: ends with complete → idle → reset
# ==============================================================================

# Returns a weighted random choice from a space-separated "item:weight" list
# Uses $RANDOM (bash built-in) for portability
weighted_random() {
    local items="$1"
    local total=0
    local item weight

    # Calculate total weight
    for entry in $items; do
        weight="${entry##*:}"
        total=$((total + weight))
    done

    # Guard against zero total weight
    if [[ $total -eq 0 ]]; then
        echo "${items%% *}"
        return
    fi

    # Pick random point
    local roll=$(( RANDOM % total ))
    local cumulative=0

    for entry in $items; do
        item="${entry%%:*}"
        weight="${entry##*:}"
        cumulative=$((cumulative + weight))
        if [[ $roll -lt $cumulative ]]; then
            echo "$item"
            return
        fi
    done

    # Fallback
    echo "${items%% *}"
}

# Random sleep with jitter: base_seconds +/- jitter
sleep_jitter() {
    local base="$1"
    local jitter="${2:-0}"

    if [[ $jitter -gt 0 ]]; then
        local offset=$(( (RANDOM % (jitter * 2 + 1)) - jitter ))
        local total=$(( base + offset ))
        [[ $total -lt 1 ]] && total=1
        sleep "$total"
    else
        sleep "$base"
    fi
}

# Random float-ish sleep using tenth-second increments
sleep_tenths() {
    local min_tenths="$1"  # e.g., 5 = 0.5s
    local max_tenths="$2"  # e.g., 30 = 3.0s

    local range=$(( max_tenths - min_tenths ))
    local pick=$(( min_tenths + (RANDOM % (range + 1)) ))
    local secs=$(( pick / 10 ))
    local frac=$(( pick % 10 ))

    sleep "${secs}.${frac}"
}

# ==============================================================================
# WORKFLOW PATTERNS
# ==============================================================================

# Persona: coding — typical feature development
# Long processing, occasional permission for file writes, some subagents
persona_coding() {
    local elapsed=0
    local subagents=0

    while [[ $elapsed -lt $DURATION ]]; do
        # Processing phase (2-8 seconds — agent thinking/writing)
        trigger processing
        sleep_tenths 20 80

        # What happens next?
        local next
        next=$(weighted_random "continue_processing:40 permission:20 subagent_start:15 complete:15 tool_error:5 compacting:5")

        case "$next" in
            continue_processing)
                # More processing (editing files, running code)
                sleep_tenths 15 50
                ;;
            permission)
                trigger permission
                sleep_tenths 10 30  # User reads and approves
                trigger processing  # Back to work
                sleep_tenths 10 40
                ;;
            subagent_start)
                trigger subagent-start
                subagents=$((subagents + 1))
                sleep_tenths 20 60

                # Subagent finishes
                if [[ $subagents -gt 0 ]]; then
                    trigger subagent-stop
                    subagents=$((subagents - 1))
                fi
                sleep_tenths 5 15
                ;;
            complete)
                trigger complete
                sleep_tenths 20 50
                # Short idle before next prompt
                trigger idle
                sleep_tenths 15 40
                # New prompt
                trigger processing new-prompt
                ;;
            tool_error)
                trigger tool_error
                sleep_tenths 15 20  # Auto-returns to processing
                ;;
            compacting)
                trigger compacting
                sleep_tenths 10 25
                trigger processing
                ;;
        esac

        elapsed=$SECONDS
    done
}

# Persona: review — code review with many permission requests
persona_review() {
    local elapsed=0

    while [[ $elapsed -lt $DURATION ]]; do
        # Quick processing
        trigger processing
        sleep_tenths 10 30

        local next
        next=$(weighted_random "permission:45 continue_processing:25 complete:20 compacting:10")

        case "$next" in
            permission)
                trigger permission
                sleep_tenths 8 25  # Quick approve/deny
                trigger processing
                sleep_tenths 5 20
                ;;
            continue_processing)
                sleep_tenths 10 35
                ;;
            complete)
                trigger complete
                sleep_tenths 15 40
                trigger idle
                sleep_tenths 20 50
                trigger processing new-prompt
                ;;
            compacting)
                trigger compacting
                sleep_tenths 8 15
                trigger processing
                ;;
        esac

        elapsed=$SECONDS
    done
}

# Persona: research — heavy subagent usage (explore agents, web research)
persona_research() {
    local elapsed=0
    local subagents=0

    while [[ $elapsed -lt $DURATION ]]; do
        trigger processing
        sleep_tenths 10 25

        local next
        next=$(weighted_random "subagent_start:40 continue_processing:20 permission:10 complete:15 subagent_burst:15")

        case "$next" in
            subagent_start)
                trigger subagent-start
                subagents=$((subagents + 1))
                sleep_tenths 15 50

                # Sometimes subagent returns quickly
                if [[ $(( RANDOM % 3 )) -eq 0 ]] && [[ $subagents -gt 0 ]]; then
                    trigger subagent-stop
                    subagents=$((subagents - 1))
                fi
                ;;
            subagent_burst)
                # Spawn 2-3 subagents rapidly (parallel explore)
                local burst=$(( 2 + RANDOM % 2 ))
                local i
                for (( i=0; i<burst; i++ )); do
                    trigger subagent-start
                    subagents=$((subagents + 1))
                    sleep_tenths 2 5
                done
                sleep_tenths 30 70

                # They return one by one
                while [[ $subagents -gt 0 ]]; do
                    trigger subagent-stop
                    subagents=$((subagents - 1))
                    sleep_tenths 3 12
                done
                ;;
            continue_processing)
                sleep_tenths 15 40
                ;;
            permission)
                trigger permission
                sleep_tenths 10 20
                trigger processing
                ;;
            complete)
                # Drain remaining subagents
                while [[ $subagents -gt 0 ]]; do
                    trigger subagent-stop
                    subagents=$((subagents - 1))
                    sleep_tenths 2 5
                done
                trigger complete
                sleep_tenths 20 45
                trigger idle
                sleep_tenths 25 60
                trigger processing new-prompt
                ;;
        esac

        elapsed=$SECONDS
    done
}

# Persona: refactor — steady processing with clean cycles
persona_refactor() {
    local elapsed=0

    while [[ $elapsed -lt $DURATION ]]; do
        # Long focused processing
        trigger processing
        sleep_tenths 30 80

        local next
        next=$(weighted_random "complete:35 permission:25 continue_processing:25 compacting:10 tool_error:5")

        case "$next" in
            complete)
                trigger complete
                sleep_tenths 15 30
                # Quick turnaround
                trigger processing new-prompt
                ;;
            permission)
                trigger permission
                sleep_tenths 5 15  # Fast approval (expected changes)
                trigger processing
                sleep_tenths 20 50
                ;;
            continue_processing)
                sleep_tenths 20 60
                ;;
            compacting)
                trigger compacting
                sleep_tenths 8 20
                trigger processing
                ;;
            tool_error)
                trigger tool_error
                sleep_tenths 15 20
                ;;
        esac

        elapsed=$SECONDS
    done
}

# Persona: debug — investigation with errors and retries
persona_debug() {
    local elapsed=0
    local error_streak=0

    while [[ $elapsed -lt $DURATION ]]; do
        trigger processing
        sleep_tenths 15 40

        local next

        # Higher error chance during streaks (simulates repeated failing attempts)
        if [[ $error_streak -gt 0 ]]; then
            next=$(weighted_random "tool_error:35 processing:30 permission:15 complete:15 subagent:5")
        else
            next=$(weighted_random "tool_error:20 processing:25 permission:20 complete:20 subagent:10 compacting:5")
        fi

        case "$next" in
            tool_error)
                trigger tool_error
                error_streak=$((error_streak + 1))
                sleep_tenths 15 20  # Auto-returns
                # Retry
                trigger processing
                sleep_tenths 10 30
                ;;
            processing)
                sleep_tenths 15 45
                # Sometimes error streak breaks
                error_streak=0
                ;;
            permission)
                trigger permission
                sleep_tenths 8 20
                trigger processing
                error_streak=0
                ;;
            complete)
                trigger complete
                error_streak=0
                sleep_tenths 20 40
                trigger idle
                sleep_tenths 20 50
                trigger processing new-prompt
                ;;
            subagent)
                trigger subagent-start
                sleep_tenths 20 50
                trigger subagent-stop
                error_streak=0
                ;;
            compacting)
                trigger compacting
                sleep_tenths 8 20
                trigger processing
                ;;
        esac

        elapsed=$SECONDS
    done
}

# ==============================================================================
# TRIGGER WRAPPER
# ==============================================================================

trigger() {
    if [[ "$VERBOSE" == "true" ]]; then
        local ts
        ts=$(date +%H:%M:%S)
        printf "\033[2m  [%s] %s\033[0m\n" "$ts" "$*"
    fi

    if [[ "$ENABLE_BG" == "true" ]]; then
        ENABLE_STYLISH_BACKGROUNDS="true" "$TRIGGER" "$@"
    else
        "$TRIGGER" "$@"
    fi
}

# ==============================================================================
# MAIN
# ==============================================================================

# Pick persona
PERSONAS="coding review research refactor debug"

if [[ -z "$PERSONA" ]]; then
    # Random persona
    set -- $PERSONAS
    shift $(( RANDOM % $# ))
    PERSONA="$1"
fi

# Validate persona
case "$PERSONA" in
    coding|review|research|refactor|debug) ;;
    *)
        echo "Unknown persona: $PERSONA"
        echo "Available: $PERSONAS"
        exit 1
        ;;
esac

# Add random startup delay (0-3 seconds) so parallel sessions desync
sleep_tenths 0 30

# Set window title if label provided
if [[ -n "$LABEL" ]]; then
    printf '\033]0;%s\033\\' "$LABEL"
fi

# Show what's running
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

echo ""
echo -e "  ${BOLD}TAVS Session Simulator${RESET}"
echo -e "  ${DIM}Persona:  ${PERSONA}${RESET}"
echo -e "  ${DIM}Duration: ${DURATION}s${RESET}"
[[ -n "$LABEL" ]] && echo -e "  ${DIM}Label:    ${LABEL}${RESET}"
[[ "$ENABLE_BG" == "true" ]] && echo -e "  ${DIM}Backgrounds: enabled${RESET}"
echo -e "  ${DIM}Press Ctrl+C to stop${RESET}"
echo ""

# Cleanup on exit
cleanup() {
    "$TRIGGER" reset 2>/dev/null
    echo ""
    echo -e "  ${DIM}Session ended — reset to default${RESET}"
}
trap cleanup EXIT INT TERM

# Record start time
SECONDS=0

# Run the persona
"persona_${PERSONA}"

# Final cleanup
trigger complete
sleep 2
trigger reset
