#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Signals - Configuration Script
# ==============================================================================
# Interactive configuration for anthropomorphising (ASCII faces) feature.
# Run this script to enable and configure face themes.
# ==============================================================================

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
THEME_FILE="$SCRIPT_DIR/src/core/theme.sh"

# Source themes for preview
source "$SCRIPT_DIR/src/core/themes.sh"

# === COLORS ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# === HELPER FUNCTIONS ===

print_header() {
    echo ""
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║       Terminal Agent Visual Signals - Configuration        ║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━ $1 ━━━${NC}"
    echo ""
}

show_theme_preview() {
    local theme="$1"
    local indent="${2:-  }"

    echo -e "${indent}${BOLD}$theme${NC}"
    echo -e "${indent}  Processing: $(get_face "$theme" processing)"
    echo -e "${indent}  Permission: $(get_face "$theme" permission)"
    echo -e "${indent}  Complete:   $(get_face "$theme" complete)"
    echo -e "${indent}  Sleepy:     $(get_face "$theme" idle_4)"
    echo -e "${indent}  Deep Sleep: $(get_face "$theme" idle_5)"
}

show_all_themes() {
    print_section "Available Themes"
    local i=1
    for theme in "${AVAILABLE_THEMES[@]}"; do
        echo -e "  ${YELLOW}$i)${NC}"
        show_theme_preview "$theme" "     "
        echo ""
        ((i++))
    done
}

select_theme() {
    show_all_themes

    local valid=false
    while [[ "$valid" == "false" ]]; do
        echo -ne "${GREEN}Select theme [1-${#AVAILABLE_THEMES[@]}]: ${NC}"
        read -r choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#AVAILABLE_THEMES[@]} ]]; then
            SELECTED_THEME="${AVAILABLE_THEMES[$((choice - 1))]}"
            valid=true
        else
            echo -e "${RED}Invalid choice. Please enter a number between 1 and ${#AVAILABLE_THEMES[@]}.${NC}"
        fi
    done

    echo ""
    echo -e "${GREEN}Selected theme: ${BOLD}$SELECTED_THEME${NC}"
}

select_position() {
    print_section "Face Position"

    echo "  Where should faces appear relative to the emoji?"
    echo ""
    echo -e "  ${YELLOW}1)${NC} After emoji:  🟠 $(get_face minimal processing) ~/path"
    echo -e "  ${YELLOW}2)${NC} Before emoji: $(get_face minimal processing) 🟠 ~/path"
    echo ""

    local valid=false
    while [[ "$valid" == "false" ]]; do
        echo -ne "${GREEN}Select position [1-2]: ${NC}"
        read -r choice

        case "$choice" in
            1) SELECTED_POSITION="after"; valid=true ;;
            2) SELECTED_POSITION="before"; valid=true ;;
            *) echo -e "${RED}Invalid choice. Please enter 1 or 2.${NC}" ;;
        esac
    done

    echo ""
    echo -e "${GREEN}Selected position: ${BOLD}$SELECTED_POSITION${NC}"
}

update_config() {
    local var="$1"
    local value="$2"

    # Create backup
    cp "$THEME_FILE" "${THEME_FILE}.bak"

    # Check if variable exists in file
    if grep -q "^${var}=" "$THEME_FILE"; then
        # Update existing variable (macOS compatible sed)
        sed -i.tmp "s/^${var}=.*/${var}=\"${value}\"/" "$THEME_FILE"
        rm -f "${THEME_FILE}.tmp"
    else
        # This shouldn't happen if theme.sh is properly set up
        echo -e "${YELLOW}Warning: Variable $var not found in config. Please add manually.${NC}"
    fi
}

show_current_config() {
    print_section "Current Configuration"

    # Source theme.sh to get current values
    source "$THEME_FILE"

    echo -e "  ENABLE_ANTHROPOMORPHISING: ${BOLD}$ENABLE_ANTHROPOMORPHISING${NC}"
    echo -e "  FACE_THEME:                ${BOLD}$FACE_THEME${NC}"
    echo -e "  FACE_POSITION:             ${BOLD}$FACE_POSITION${NC}"
    echo ""

    if [[ "$ENABLE_ANTHROPOMORPHISING" == "true" ]]; then
        echo -e "  Current face preview:"
        show_theme_preview "$FACE_THEME" "    "
    fi
}

show_final_preview() {
    print_section "Configuration Preview"

    echo "  Your terminal titles will look like:"
    echo ""

    local face_proc=$(get_face "$SELECTED_THEME" processing)
    local face_perm=$(get_face "$SELECTED_THEME" permission)
    local face_comp=$(get_face "$SELECTED_THEME" complete)
    local face_idle=$(get_face "$SELECTED_THEME" idle_4)

    if [[ "$SELECTED_POSITION" == "before" ]]; then
        echo -e "  Processing:  $face_proc 🟠 ~/project"
        echo -e "  Permission:  $face_perm 🔴 ~/project"
        echo -e "  Complete:    $face_comp 🟢 ~/project"
        echo -e "  Idle:        $face_idle 🟣 ~/project"
    else
        echo -e "  Processing:  🟠 $face_proc ~/project"
        echo -e "  Permission:  🔴 $face_perm ~/project"
        echo -e "  Complete:    🟢 $face_comp ~/project"
        echo -e "  Idle:        🟣 $face_idle ~/project"
    fi
    echo ""
}

# === MAIN FLOW ===

main() {
    print_header
    show_current_config

    print_section "Enable Anthropomorphising"
    echo "  Add expressive ASCII faces to your terminal titles?"
    echo ""
    echo -ne "${GREEN}Enable faces? [y/N]: ${NC}"
    read -r enable_choice

    if [[ "$enable_choice" =~ ^[Yy] ]]; then
        # Enable and configure
        select_theme
        select_position

        show_final_preview

        echo -ne "${GREEN}Apply these settings? [Y/n]: ${NC}"
        read -r confirm

        if [[ ! "$confirm" =~ ^[Nn] ]]; then
            update_config "ENABLE_ANTHROPOMORPHISING" "true"
            update_config "FACE_THEME" "$SELECTED_THEME"
            update_config "FACE_POSITION" "$SELECTED_POSITION"

            echo ""
            echo -e "${GREEN}${BOLD}Configuration saved!${NC}"
            echo ""
            echo "  Changes applied to: $THEME_FILE"
            echo "  Backup created:     ${THEME_FILE}.bak"
            echo ""
            echo -e "${YELLOW}Restart your Claude Code session to see the changes.${NC}"
        else
            echo ""
            echo -e "${YELLOW}Configuration cancelled. No changes made.${NC}"
        fi
    else
        # Disable
        echo ""
        echo -ne "${GREEN}Disable anthropomorphising? [y/N]: ${NC}"
        read -r disable_choice

        if [[ "$disable_choice" =~ ^[Yy] ]]; then
            update_config "ENABLE_ANTHROPOMORPHISING" "false"

            echo ""
            echo -e "${GREEN}${BOLD}Anthropomorphising disabled.${NC}"
            echo ""
            echo "  Changes applied to: $THEME_FILE"
            echo "  Backup created:     ${THEME_FILE}.bak"
        else
            echo ""
            echo -e "${YELLOW}No changes made.${NC}"
        fi
    fi

    echo ""
}

main "$@"
