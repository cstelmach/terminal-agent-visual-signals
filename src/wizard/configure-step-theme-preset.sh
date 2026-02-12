#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — Configure Step 2: Theme Preset
# ==============================================================================
# Interactive selection of theme preset (when SELECTED_MODE=preset).
# Part of the TAVS configuration wizard.
#
# Requires: configure-utilities.sh must be sourced before this file.
# Requires: TAVS_ROOT variable must be set by main configure.sh
# Sets: SELECTED_PRESET, may change SELECTED_MODE to static if no presets found
# ==============================================================================

select_theme_preset() {
    if [[ "$SELECTED_MODE" != "preset" ]]; then
        echo ""
        echo -e "  ${DIM}Step 2: Theme Preset - Skipped (not using preset mode)${NC}"
        return
    fi

    print_section "Step 2: Theme Preset"

    echo "  Select a color theme:"
    echo ""

    # Get available themes
    local themes=()
    if [[ -d "$TAVS_ROOT/src/themes" ]]; then
        while IFS= read -r theme; do
            themes+=("$theme")
        done < <(find "$TAVS_ROOT/src/themes" -name "*.conf" -exec basename {} .conf \; | sort)
    fi

    if [[ ${#themes[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No theme presets found. Using static mode instead.${NC}"
        SELECTED_MODE="static"
        return
    fi

    local i=1
    for theme in "${themes[@]}"; do
        # Get description from theme file if available
        local desc
        desc=$(grep -m1 "^# Description:" "$TAVS_ROOT/src/themes/${theme}.conf" 2>/dev/null | sed 's/# Description: //' || echo "")
        echo -e "  ${YELLOW}$i)${NC} ${BOLD}$theme${NC}"
        [[ -n "$desc" ]] && print_info "$desc"
        ((i++))
    done
    echo ""

    local valid=false
    while [[ "$valid" == "false" ]]; do
        local choice
        choice=$(read_choice "Select theme [1-${#themes[@]}]" "1")

        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#themes[@]} ]]; then
            SELECTED_PRESET="${themes[$((choice - 1))]}"
            valid=true
        else
            echo -e "${RED}Invalid choice.${NC}"
        fi
    done

    echo ""
    echo -e "  ${GREEN}Selected theme: ${BOLD}$SELECTED_PRESET${NC}"
}
