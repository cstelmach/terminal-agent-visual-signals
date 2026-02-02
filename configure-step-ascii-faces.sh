#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Signals - Configure Step 4: ASCII Faces
# ==============================================================================
# Interactive configuration of anthropomorphising (ASCII faces in titles).
# Part of the TAVS configuration wizard.
#
# Requires: configure-utilities.sh must be sourced before this file.
# Requires: themes.sh must be sourced for AVAILABLE_THEMES and get_face()
# Sets: SELECTED_FACE_ENABLED, SELECTED_FACE_THEME, SELECTED_FACE_POSITION
# ==============================================================================

select_faces() {
    print_section "Step 4: ASCII Faces (Anthropomorphising)"

    echo "  Add expressive ASCII faces to terminal titles?"
    echo ""
    print_info "Examples: (°-°) ʕ•ᴥ•ʔ ฅ^•ﻌ•^ฅ ( ͡° ͜ʖ ͡°)"
    echo ""

    if confirm "Enable ASCII faces?"; then
        SELECTED_FACE_ENABLED="true"

        # Show face themes
        echo ""
        echo "  Select face theme:"
        echo ""

        local i=1
        for theme in "${AVAILABLE_THEMES[@]}"; do
            echo -e "  ${YELLOW}$i)${NC} ${BOLD}$theme${NC}"
            echo -e "     Processing: $(get_face "$theme" processing)  Complete: $(get_face "$theme" complete)  Idle: $(get_face "$theme" idle_4)"
            ((i++))
        done
        echo ""

        local valid=false
        while [[ "$valid" == "false" ]]; do
            local choice
            choice=$(read_choice "Select theme [1-${#AVAILABLE_THEMES[@]}]" "1")

            if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#AVAILABLE_THEMES[@]} ]]; then
                SELECTED_FACE_THEME="${AVAILABLE_THEMES[$((choice - 1))]}"
                valid=true
            else
                echo -e "${RED}Invalid choice.${NC}"
            fi
        done

        # Position
        echo ""
        echo "  Face position:"
        echo -e "  ${YELLOW}1)${NC} Before emoji: $(get_face "$SELECTED_FACE_THEME" processing) 🟠 ~/path"
        echo -e "  ${YELLOW}2)${NC} After emoji:  🟠 $(get_face "$SELECTED_FACE_THEME" processing) ~/path"
        echo ""

        local pos_choice
        pos_choice=$(read_choice "Select position [1-2]" "1")
        [[ "$pos_choice" == "2" ]] && SELECTED_FACE_POSITION="after" || SELECTED_FACE_POSITION="before"

        echo ""
        echo -e "  ${GREEN}Face theme: ${BOLD}$SELECTED_FACE_THEME${NC}, Position: ${BOLD}$SELECTED_FACE_POSITION${NC}"
    else
        SELECTED_FACE_ENABLED="false"
        echo ""
        echo -e "  ${GREEN}ASCII faces: ${BOLD}Disabled${NC}"
    fi
}
