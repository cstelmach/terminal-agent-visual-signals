#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — Configure Step 3: Light/Dark Mode
# ==============================================================================
# Interactive configuration of light/dark mode switching.
# Part of the TAVS configuration wizard.
#
# Requires: configure-utilities.sh must be sourced before this file.
# Sets: SELECTED_LIGHT_DARK_SWITCHING, SELECTED_FORCE_MODE
# ==============================================================================

select_auto_dark_mode() {
    print_section "Step 3: Light/Dark Mode"

    echo "  Should the system automatically detect light/dark mode?"
    echo ""
    print_info "When enabled, colors adapt when your system theme changes."
    print_info "Checked at: session start, permission requests, completions."
    echo ""
    echo -e "  ${YELLOW}1)${NC} ${BOLD}Disabled${NC} ${DIM}(Recommended)${NC}"
    print_info "Use dark colors always. Fastest, most predictable."
    echo ""
    echo -e "  ${YELLOW}2)${NC} ${BOLD}Enabled${NC}"
    print_info "Detect system preference and switch between light/dark colors."
    echo ""
    echo -e "  ${YELLOW}3)${NC} ${BOLD}Force Light${NC}"
    print_info "Always use light mode colors."
    echo ""
    echo -e "  ${YELLOW}4)${NC} ${BOLD}Force Dark${NC}"
    print_info "Always use dark mode colors."
    echo ""

    local valid=false
    while [[ "$valid" == "false" ]]; do
        local choice
        choice=$(read_choice "Select option [1-4]" "1")

        case "$choice" in
            1) SELECTED_LIGHT_DARK_SWITCHING="false"; SELECTED_FORCE_MODE="auto"; valid=true ;;
            2) SELECTED_LIGHT_DARK_SWITCHING="true"; SELECTED_FORCE_MODE="auto"; valid=true ;;
            3) SELECTED_LIGHT_DARK_SWITCHING="false"; SELECTED_FORCE_MODE="light"; valid=true ;;
            4) SELECTED_LIGHT_DARK_SWITCHING="false"; SELECTED_FORCE_MODE="dark"; valid=true ;;
            *) echo -e "${RED}Invalid choice.${NC}" ;;
        esac
    done

    echo ""
    if [[ "$SELECTED_LIGHT_DARK_SWITCHING" == "true" ]]; then
        echo -e "  ${GREEN}Light/dark switching: ${BOLD}Enabled${NC}"
    elif [[ "$SELECTED_FORCE_MODE" != "auto" ]]; then
        echo -e "  ${GREEN}Forced mode: ${BOLD}$SELECTED_FORCE_MODE${NC}"
    else
        echo -e "  ${GREEN}Light/dark switching: ${BOLD}Disabled${NC}"
    fi
}
