#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Signals - Configure Step 1: Operating Mode
# ==============================================================================
# Interactive selection of operating mode (static, dynamic, preset).
# Part of the TAVS configuration wizard.
#
# Requires: configure-utilities.sh must be sourced before this file.
# Sets: SELECTED_MODE
# ==============================================================================

select_operating_mode() {
    print_section "Step 1: Operating Mode"

    echo "  How should terminal background colors be determined?"
    echo ""
    echo -e "  ${YELLOW}1)${NC} ${BOLD}Static${NC} ${DIM}(Recommended)${NC}"
    print_info "Use preconfigured colors from agent defaults or theme preset."
    print_info "Fastest, most predictable. Works everywhere."
    echo ""
    echo -e "  ${YELLOW}2)${NC} ${BOLD}Dynamic${NC}"
    print_info "Query your terminal's background color at session start."
    print_info "Calculate state colors by hue-shifting your base color."
    print_info "Colors adapt to your terminal aesthetic."
    echo ""
    echo -e "  ${YELLOW}3)${NC} ${BOLD}Theme Preset${NC}"
    print_info "Use a named color theme (Nord, Dracula, Solarized, etc.)."
    print_info "Consistent look with popular color schemes."
    echo ""

    local valid=false
    while [[ "$valid" == "false" ]]; do
        local choice
        choice=$(read_choice "Select mode [1-3]" "1")

        case "$choice" in
            1) SELECTED_MODE="static"; valid=true ;;
            2) SELECTED_MODE="dynamic"; valid=true ;;
            3) SELECTED_MODE="preset"; valid=true ;;
            *) echo -e "${RED}Invalid choice. Please enter 1, 2, or 3.${NC}" ;;
        esac
    done

    echo ""
    echo -e "  ${GREEN}Selected: ${BOLD}$SELECTED_MODE${NC}"
}
