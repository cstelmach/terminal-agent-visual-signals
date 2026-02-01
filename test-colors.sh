#!/usr/bin/env bash
# test-colors.sh - Visual test for color modes in Terminal Agent Visual Signals
#
# Usage:
#   ./test-colors.sh              # Run all tests interactively
#   ./test-colors.sh quick        # Quick comparison (no prompts)
#   ./test-colors.sh muted        # Test muted colors only
#   ./test-colors.sh regular      # Test regular colors only

# Note: Don't use set -e as some commands may return non-zero (e.g., TTY detection)
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the core modules
source "$SCRIPT_DIR/src/core/theme.sh"
source "$SCRIPT_DIR/src/core/terminal.sh"

# Colors for output
BOLD='\033[1m'
RESET_TEXT='\033[0m'
CYAN='\033[36m'

# Test delay (seconds to show each color)
DELAY="${DELAY:-2}"

print_header() {
    echo -e "\n${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${RESET_TEXT}"
    echo -e "${BOLD}${CYAN}  $1${RESET_TEXT}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${RESET_TEXT}\n"
}

print_info() {
    echo -e "${CYAN}→${RESET_TEXT} $1"
}

show_color() {
    local color="$1"
    local label="$2"
    local delay="${3:-$DELAY}"

    # Set background color
    send_osc_bg "$color"
    echo -e "  ${BOLD}$label${RESET_TEXT}"
    echo -e "  Color: $color"
    sleep "$delay"
}

wait_for_key() {
    if [[ "${QUICK:-}" != "true" ]]; then
        echo -e "\n${CYAN}Press Enter to continue...${RESET_TEXT}"
        read -r
    fi
}

test_regular_colors() {
    print_header "Regular Colors (Standard Mode)"
    print_info "These are the default colors used in non-TrueColor terminals"
    print_info "or when TRUECOLOR_MODE_OVERRIDE is 'off' or 'full'"
    echo

    load_agent_config claude

    echo "Dark Mode:"
    show_color "$DARK_BASE" "BASE"
    show_color "$DARK_PROCESSING" "PROCESSING"
    show_color "$DARK_PERMISSION" "PERMISSION"
    show_color "$DARK_COMPLETE" "COMPLETE"
    show_color "$DARK_IDLE" "IDLE"
    show_color "$DARK_COMPACTING" "COMPACTING"

    wait_for_key

    echo -e "\nLight Mode:"
    show_color "$LIGHT_BASE" "BASE"
    show_color "$LIGHT_PROCESSING" "PROCESSING"
    show_color "$LIGHT_PERMISSION" "PERMISSION"
    show_color "$LIGHT_COMPLETE" "COMPLETE"
    show_color "$LIGHT_IDLE" "IDLE"
    show_color "$LIGHT_COMPACTING" "COMPACTING"

    send_osc_bg "reset"
}

test_muted_colors() {
    print_header "Muted Colors (TrueColor Mode Override)"
    print_info "These colors have reduced contrast for TrueColor terminals"
    print_info "Used when TRUECOLOR_MODE_OVERRIDE='muted'"
    print_info "Dark muted is LIGHTER, Light muted is DARKER - they converge toward middle"
    echo

    load_agent_config claude

    echo "Muted Dark Mode (lighter than regular dark):"
    show_color "$MUTED_DARK_BASE" "MUTED BASE"
    show_color "$MUTED_DARK_PROCESSING" "MUTED PROCESSING"
    show_color "$MUTED_DARK_PERMISSION" "MUTED PERMISSION"
    show_color "$MUTED_DARK_COMPLETE" "MUTED COMPLETE"
    show_color "$MUTED_DARK_IDLE" "MUTED IDLE"
    show_color "$MUTED_DARK_COMPACTING" "MUTED COMPACTING"

    wait_for_key

    echo -e "\nMuted Light Mode (darker than regular light):"
    show_color "$MUTED_LIGHT_BASE" "MUTED BASE"
    show_color "$MUTED_LIGHT_PROCESSING" "MUTED PROCESSING"
    show_color "$MUTED_LIGHT_PERMISSION" "MUTED PERMISSION"
    show_color "$MUTED_LIGHT_COMPLETE" "MUTED COMPLETE"
    show_color "$MUTED_LIGHT_IDLE" "MUTED IDLE"
    show_color "$MUTED_LIGHT_COMPACTING" "MUTED COMPACTING"

    send_osc_bg "reset"
}

test_comparison() {
    print_header "Side-by-Side Comparison"
    print_info "Comparing regular vs muted colors"
    echo

    load_agent_config claude

    local states=("BASE" "PROCESSING" "PERMISSION" "COMPLETE" "IDLE" "COMPACTING")

    for state in "${states[@]}"; do
        echo -e "\n${BOLD}=== $state ===${RESET_TEXT}"

        local dark_var="DARK_$state"
        local light_var="LIGHT_$state"
        local muted_dark_var="MUTED_DARK_$state"
        local muted_light_var="MUTED_LIGHT_$state"

        echo "Regular Dark → Muted Dark → Muted Light → Regular Light"

        show_color "${!dark_var}" "Regular Dark" 1
        show_color "${!muted_dark_var}" "Muted Dark (lighter)" 1
        show_color "${!muted_light_var}" "Muted Light (darker)" 1
        show_color "${!light_var}" "Regular Light" 1
    done

    send_osc_bg "reset"
}

test_mode_switching() {
    print_header "Mode Switching Simulation"
    print_info "Simulating light/dark mode switching"
    echo

    load_agent_config claude

    echo "With REGULAR colors (high contrast - jarring switch):"
    for _ in {1..2}; do
        show_color "$DARK_PROCESSING" "Dark Processing" 1
        show_color "$LIGHT_PROCESSING" "Light Processing" 1
    done

    wait_for_key

    echo -e "\nWith MUTED colors (low contrast - smooth switch):"
    for _ in {1..2}; do
        show_color "$MUTED_DARK_PROCESSING" "Muted Dark Processing" 1
        show_color "$MUTED_LIGHT_PROCESSING" "Muted Light Processing" 1
    done

    send_osc_bg "reset"
}

test_truecolor_behavior() {
    print_header "TrueColor Mode Behavior Test"
    print_info "Testing how TRUECOLOR_MODE_OVERRIDE affects color selection"
    echo

    # Load config once, then override settings for testing
    load_agent_config claude

    # Simulate TrueColor environment
    COLORTERM="truecolor"
    ENABLE_LIGHT_DARK_SWITCHING="true"

    echo "Current environment:"
    echo "  COLORTERM=$COLORTERM"
    echo "  ENABLE_LIGHT_DARK_SWITCHING=$ENABLE_LIGHT_DARK_SWITCHING"
    echo

    echo "Test 1: TRUECOLOR_MODE_OVERRIDE='off' (default)"
    TRUECOLOR_MODE_OVERRIDE="off"
    _CACHED_SYSTEM_MODE=""
    _resolve_colors
    echo "  Result: IS_DARK_THEME=$IS_DARK_THEME"
    echo "  COLOR_PROCESSING=$COLOR_PROCESSING"
    show_color "$COLOR_PROCESSING" "Off Mode - Always Dark" 2

    echo -e "\nTest 2: TRUECOLOR_MODE_OVERRIDE='muted'"
    TRUECOLOR_MODE_OVERRIDE="muted"
    _CACHED_SYSTEM_MODE=""
    _resolve_colors
    echo "  Result: IS_DARK_THEME=$IS_DARK_THEME"
    echo "  COLOR_PROCESSING=$COLOR_PROCESSING (muted)"
    show_color "$COLOR_PROCESSING" "Muted Mode" 2

    echo -e "\nTest 3: TRUECOLOR_MODE_OVERRIDE='full'"
    TRUECOLOR_MODE_OVERRIDE="full"
    _CACHED_SYSTEM_MODE=""
    _resolve_colors
    echo "  Result: IS_DARK_THEME=$IS_DARK_THEME"
    echo "  COLOR_PROCESSING=$COLOR_PROCESSING"
    show_color "$COLOR_PROCESSING" "Full Mode - Regular Colors" 2

    send_osc_bg "reset"
}

run_all_tests() {
    print_header "Terminal Agent Visual Signals - Color Test Suite"
    echo "This test will cycle through different color configurations."
    echo "Watch your terminal background change."
    echo
    echo "Settings:"
    echo "  Delay per color: ${DELAY}s (set DELAY=N to change)"
    echo "  Quick mode: ${QUICK:-false} (run with 'quick' argument)"
    echo

    wait_for_key

    test_regular_colors
    wait_for_key

    test_muted_colors
    wait_for_key

    test_comparison
    wait_for_key

    test_mode_switching
    wait_for_key

    test_truecolor_behavior

    print_header "Test Complete"
    echo "All tests completed. Terminal background has been reset."
}

# Main
case "${1:-}" in
    quick)
        QUICK=true
        DELAY=1
        run_all_tests
        ;;
    muted)
        test_muted_colors
        ;;
    regular)
        test_regular_colors
        ;;
    compare)
        test_comparison
        ;;
    switch)
        test_mode_switching
        ;;
    truecolor)
        test_truecolor_behavior
        ;;
    -h|--help)
        echo "Usage: $0 [quick|muted|regular|compare|switch|truecolor]"
        echo
        echo "Options:"
        echo "  (none)     Run all tests interactively"
        echo "  quick      Run all tests quickly (1s delay, no prompts)"
        echo "  muted      Test muted colors only"
        echo "  regular    Test regular colors only"
        echo "  compare    Side-by-side comparison"
        echo "  switch     Mode switching simulation"
        echo "  truecolor  Test TRUECOLOR_MODE_OVERRIDE behavior"
        echo
        echo "Environment:"
        echo "  DELAY=N    Seconds to display each color (default: 2)"
        ;;
    *)
        run_all_tests
        ;;
esac
