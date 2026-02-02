#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Signals - Configure Step 5: Stylish Backgrounds
# ==============================================================================
# Interactive configuration of background images for visual states.
# Part of the TAVS configuration wizard.
#
# Requires: configure-utilities.sh must be sourced before this file.
# Sets: SELECTED_STYLISH_ENABLED, SELECTED_STYLISH_DIR
# ==============================================================================

select_stylish_backgrounds() {
    print_section "Step 5: Stylish Backgrounds (Images)"

    echo "  Enable background images for visual states?"
    echo ""
    print_info "This feature replaces solid background colors with images."
    print_info "Each state can have its own image (processing.png, complete.png, etc.)"
    echo ""
    echo -e "  ${BOLD}Supported terminals:${NC} iTerm2, Kitty"
    echo -e "  ${BOLD}Unsupported terminals:${NC} Will automatically fall back to solid colors"
    echo ""
    print_info "This is a global setting. When enabled, supported terminals show"
    print_info "images while unsupported terminals gracefully use color-only mode."
    echo ""

    # Detect terminal
    local terminal_type="unknown"
    if [[ -n "$ITERM_SESSION_ID" ]]; then
        terminal_type="iterm2"
    elif [[ -n "$KITTY_PID" ]] || [[ -n "$KITTY_WINDOW_ID" ]]; then
        terminal_type="kitty"
    elif [[ "$TERM_PROGRAM" == "Apple_Terminal" ]]; then
        terminal_type="terminal.app"
    elif [[ -n "$TERM_PROGRAM" ]]; then
        terminal_type="${TERM_PROGRAM,,}"
    fi

    # Show compatibility info for current terminal
    echo -e "  ${DIM}Current terminal:${NC}"
    case "$terminal_type" in
        iterm2)
            echo -e "  ${GREEN}✓${NC} ${BOLD}iTerm2${NC} - Background images will work"
            ;;
        kitty)
            echo -e "  ${GREEN}✓${NC} ${BOLD}Kitty${NC} - Background images will work (requires allow_remote_control=yes)"
            ;;
        terminal.app)
            echo -e "  ${YELLOW}○${NC} ${BOLD}Apple Terminal${NC} - Will use solid colors (images not supported)"
            ;;
        *)
            echo -e "  ${YELLOW}○${NC} ${BOLD}$terminal_type${NC} - Will use solid colors (images not supported)"
            ;;
    esac
    echo ""

    if confirm "Enable stylish background images?"; then
        SELECTED_STYLISH_ENABLED="true"

        echo ""
        echo "  Where should background images be stored?"
        echo ""
        print_info "Default: ~/.terminal-visual-signals/backgrounds/"
        print_info "Create processing.png, complete.png, etc. in this directory."
        print_info "Or organize by mode: dark/processing.png, light/processing.png"
        echo ""

        local default_dir="$HOME/.terminal-visual-signals/backgrounds"
        local custom_dir
        custom_dir=$(read_choice "Directory path" "$default_dir")
        SELECTED_STYLISH_DIR="${custom_dir:-$default_dir}"

        # Check if directory exists
        if [[ ! -d "$SELECTED_STYLISH_DIR" ]]; then
            echo ""
            if confirm "Directory doesn't exist. Create it now?"; then
                mkdir -p "$SELECTED_STYLISH_DIR"
                mkdir -p "$SELECTED_STYLISH_DIR/dark"
                mkdir -p "$SELECTED_STYLISH_DIR/light"
                echo -e "  ${GREEN}Created:${NC} $SELECTED_STYLISH_DIR"
                echo -e "  ${DIM}Add your images to the dark/ and light/ subdirectories${NC}"
            fi
        fi

        echo ""
        echo -e "  ${GREEN}Stylish backgrounds: ${BOLD}Enabled${NC}"
        echo -e "  ${GREEN}Directory: ${BOLD}$SELECTED_STYLISH_DIR${NC}"
        print_info "Images in iTerm2/Kitty, solid colors elsewhere"
    else
        SELECTED_STYLISH_ENABLED="false"
        echo ""
        echo -e "  ${GREEN}Stylish backgrounds: ${BOLD}Disabled${NC}"
        print_info "Using solid colors in all terminals"
    fi
}
