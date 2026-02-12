#!/bin/bash
# ==============================================================================
# TAVS CLI — test command
# ==============================================================================
# Usage: tavs test [--quick|--terminal|--help]
#
# Visual signal testing. Cycles through states to verify terminal support.
# ==============================================================================

source "$CLI_DIR/cli-utils.sh"

cmd_test() {
    # Handle --help
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        cat <<'EOF'
tavs test — Test visual signals in current terminal

Usage:
  tavs test               Cycle through all 8 states (2s each)
  tavs test --quick       Quick check: processing → complete → reset
  tavs test --terminal    Show terminal capabilities

Examples:
  tavs test               Full visual test
  tavs test --quick       Quick 3-state check
  tavs test --terminal    Check terminal type and feature support
EOF
        return 0
    fi

    local trigger="$TAVS_ROOT/src/core/trigger.sh"
    if [[ ! -f "$trigger" ]]; then
        cli_error "Trigger script not found: $trigger"
        return 1
    fi

    # --terminal: show capabilities
    if [[ "${1:-}" == "--terminal" ]]; then
        local detection="$TAVS_ROOT/src/core/terminal-detection.sh"
        if [[ -f "$detection" ]]; then
            bash "$detection" test
        else
            cli_error "Terminal detection script not found"
            return 1
        fi
        return 0
    fi

    # --quick: fast 3-state check
    if [[ "${1:-}" == "--quick" ]]; then
        echo "Quick test: processing → complete → reset"
        echo ""
        echo -n "  Processing... "
        bash "$trigger" processing
        sleep 1.5
        echo "done"

        echo -n "  Complete...   "
        bash "$trigger" complete
        sleep 1.5
        echo "done"

        echo -n "  Reset...      "
        bash "$trigger" reset
        echo "done"

        echo ""
        cli_success "Quick test complete."
        return 0
    fi

    # Full test: cycle all states
    local states=("processing" "permission" "complete" "idle" "compacting" "subagent-start" "tool_error" "reset")
    local labels=("Processing (orange)" "Permission (red)" "Complete (green)" "Idle (purple)" "Compacting (teal)" "Subagent (golden)" "Tool Error (orange-red)" "Reset (default)")
    local delays=(2 2 2 2 2 2 2 0)

    echo "Full visual test — cycling through all ${#states[@]} states"
    echo ""

    local i
    for i in "${!states[@]}"; do
        printf "  %-30s " "${labels[$i]}"
        bash "$trigger" "${states[$i]}"
        echo "applied"
        if [[ "${delays[$i]}" -gt 0 ]]; then
            sleep "${delays[$i]}"
        fi
    done

    echo ""
    cli_success "Test complete. Terminal background should be back to default."
}
