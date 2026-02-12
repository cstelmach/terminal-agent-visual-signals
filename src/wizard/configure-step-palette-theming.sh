#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — Configure Step 7: Palette Theming
# ==============================================================================
# Interactive configuration of OSC 4 palette theming.
# Part of the TAVS configuration wizard.
#
# Requires: configure-utilities.sh must be sourced before this file.
# Sets: SELECTED_PALETTE_MODE, SELECTED_CREATE_ALIAS
# ==============================================================================

select_palette_theming() {
    print_section "Step 7: Palette Theming (OSC 4)"

    echo "  Modify the terminal's 16-color ANSI palette for cohesive theming?"
    echo ""
    print_info "This affects shell prompts, ls colors, git status, and other CLI tools."
    print_info "Colors from your selected theme will be applied to the entire terminal."
    echo ""
    echo -e "  ${YELLOW}Important:${NC} Only works when applications use 256-color mode."
    echo -e "  Claude Code uses ${BOLD}TrueColor${NC} by default, which bypasses the palette."
    echo ""
    echo -e "  ${YELLOW}1)${NC} ${BOLD}Disabled${NC} ${DIM}(Recommended)${NC}"
    print_info "Background colors only. Safest, works everywhere."
    echo ""
    echo -e "  ${YELLOW}2)${NC} ${BOLD}Auto${NC}"
    print_info "Enable when NOT in TrueColor mode."
    print_info "Automatically detects COLORTERM environment."
    echo ""
    echo -e "  ${YELLOW}3)${NC} ${BOLD}Enabled${NC}"
    print_info "Always apply palette (affects shell tools even in TrueColor)."
    print_info "Shell prompts, ls, git will use themed colors."
    echo ""

    local valid=false
    while [[ "$valid" == "false" ]]; do
        local choice
        choice=$(read_choice "Select palette theming mode [1-3]" "1")

        case "$choice" in
            1) SELECTED_PALETTE_MODE="false"; valid=true ;;
            2) SELECTED_PALETTE_MODE="auto"; valid=true ;;
            3) SELECTED_PALETTE_MODE="true"; valid=true ;;
            *) echo -e "${RED}Invalid choice. Please enter 1, 2, or 3.${NC}" ;;
        esac
    done

    echo ""
    case "$SELECTED_PALETTE_MODE" in
        false) echo -e "  ${GREEN}Palette theming: ${BOLD}Disabled${NC}" ;;
        auto)  echo -e "  ${GREEN}Palette theming: ${BOLD}Auto (256-color only)${NC}" ;;
        true)  echo -e "  ${GREEN}Palette theming: ${BOLD}Always enabled${NC}" ;;
    esac

    # Offer to create Claude alias if palette theming is enabled
    if [[ "$SELECTED_PALETTE_MODE" != "false" ]]; then
        echo ""
        echo -e "  ${BOLD}To enable palette theming for Claude Code:${NC}"
        echo ""
        echo -e "  Launch with: ${CYAN}TERM=xterm-256color COLORTERM= claude${NC}"
        echo ""
        print_info "Or add an alias to your shell profile."
        echo ""

        if confirm "Create this alias in your shell profile?"; then
            SELECTED_CREATE_ALIAS="true"

            # Detect shell config
            local shell_rc=""
            if [[ -f "$HOME/.zshrc" ]]; then
                shell_rc="$HOME/.zshrc"
            elif [[ -f "$HOME/.bashrc" ]]; then
                shell_rc="$HOME/.bashrc"
            fi

            if [[ -n "$shell_rc" ]]; then
                echo ""
                echo -e "  ${GREEN}Will add alias to:${NC} $shell_rc"
            else
                echo ""
                echo -e "  ${YELLOW}No .zshrc or .bashrc found. You may need to add the alias manually.${NC}"
                SELECTED_CREATE_ALIAS="false"
            fi
        else
            SELECTED_CREATE_ALIAS="false"
        fi
    fi
}
