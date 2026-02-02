#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Signals - Configure Step 6: Terminal Title Mode
# ==============================================================================
# Interactive configuration of terminal title mode and spinner settings.
# Part of the TAVS configuration wizard.
#
# This is the most complex step, handling:
#   - Title mode selection (skip-processing, prefix-only, full, off)
#   - Prefix-only mode fallback configuration
#   - Full mode spinner and Claude Code integration
#
# Requires: configure-utilities.sh must be sourced before this file.
# Sets: SELECTED_TITLE_MODE, SELECTED_TITLE_FALLBACK, SELECTED_SPINNER_STYLE,
#       SELECTED_SPINNER_EYE_MODE, SELECTED_SESSION_IDENTITY
# ==============================================================================

select_title_mode() {
    print_section "Step 6: Terminal Title Mode (Claude Code Integration)"

    # Check for Ghostty and show configuration guidance
    if [[ "$TERM_PROGRAM" == "ghostty" ]] || [[ -n "$GHOSTTY_RESOURCES_DIR" ]]; then
        echo -e "  ${YELLOW}⚠️  Ghostty Terminal Detected${NC}"
        echo ""
        print_info "Ghostty's shell integration automatically manages tab titles."
        print_info "For TAVS title features to work properly, you need to disable this."
        echo ""
        echo -e "  ${BOLD}Add this line to your Ghostty config:${NC}"
        echo ""
        echo -e "    ${CYAN}shell-integration-features = no-title${NC}"
        echo ""
        print_info "Config file locations:"
        print_info "  macOS: ~/Library/Application Support/com.mitchellh.ghostty/config"
        print_info "  Linux: ~/.config/ghostty/config"
        echo ""
        print_info "This disables ONLY title management while keeping other modern"
        print_info "features like cursor shapes and sudo wrapping."
        echo ""
        echo -e "  ${YELLOW}⚠️  Important Limitation:${NC} If you manually name a tab in Ghostty"
        echo -e "      (Cmd+I), Ghostty locks that title and TAVS cannot override it."
        echo -e "      Clear the custom name to restore TAVS title functionality."
        echo ""

        if confirm "Have you updated your Ghostty config (or want to proceed anyway)?"; then
            echo ""
        else
            echo ""
            echo -e "  ${YELLOW}Note: Title features may not work correctly without this setting.${NC}"
            echo -e "  ${DIM}You can continue and update Ghostty config later.${NC}"
            echo ""
        fi
    fi

    echo "  How should TAVS handle terminal tab titles?"
    echo ""
    print_info "Claude Code sets its own animated spinner title during processing."
    print_info "This setting controls whether TAVS also sets titles, which may conflict."
    echo ""
    echo -e "  ${YELLOW}1)${NC} ${BOLD}Skip Processing${NC} ${DIM}(Recommended)${NC}"
    print_info "Let Claude Code handle processing titles with its spinner."
    print_info "TAVS shows titles for other states (complete, permission, etc.)."
    print_info "Safe default - no title conflicts."
    echo ""
    echo -e "  ${YELLOW}2)${NC} ${BOLD}Prefix Only${NC}"
    print_info "TAVS adds face+emoji prefix while preserving your tab names."
    print_info "Example: 'My Project' becomes 'Ǝ[• •]E 🟠 My Project'"
    print_info "Best for users who manually name their tabs."
    echo ""
    echo -e "  ${YELLOW}3)${NC} ${BOLD}Full${NC}"
    print_info "TAVS owns all terminal titles, including processing."
    print_info "Shows animated spinner eyes in face: Ǝ[⠋ ⠙]E"
    print_info "Requires disabling Claude Code's terminal title (will be configured)."
    echo ""
    echo -e "  ${YELLOW}4)${NC} ${BOLD}Off${NC}"
    print_info "TAVS never sets terminal titles."
    print_info "Only background colors and images are used."
    echo ""

    local valid=false
    while [[ "$valid" == "false" ]]; do
        local choice
        choice=$(read_choice "Select title mode [1-4]" "1")

        case "$choice" in
            1) SELECTED_TITLE_MODE="skip-processing"; valid=true ;;
            2) SELECTED_TITLE_MODE="prefix-only"; valid=true ;;
            3) SELECTED_TITLE_MODE="full"; valid=true ;;
            4) SELECTED_TITLE_MODE="off"; valid=true ;;
            *) echo -e "${RED}Invalid choice. Please enter 1, 2, 3, or 4.${NC}" ;;
        esac
    done

    echo ""
    echo -e "  ${GREEN}Selected: ${BOLD}$SELECTED_TITLE_MODE${NC}"

    # If full mode, configure spinner and disable Claude's title
    if [[ "$SELECTED_TITLE_MODE" == "full" ]]; then
        configure_full_title_mode
    fi

    # If prefix-only mode, configure title fallback
    if [[ "$SELECTED_TITLE_MODE" == "prefix-only" ]]; then
        configure_prefix_only_mode
    fi
}

configure_prefix_only_mode() {
    echo ""
    print_info "Prefix-only mode selected. Configuring title fallback..."
    echo ""
    echo "  When you haven't manually named a tab, TAVS needs a fallback title."
    echo ""
    echo -e "  ${YELLOW}1)${NC} ${BOLD}Path Only${NC} ${DIM}(Default)${NC}"
    print_info "Shows current directory: ~/projects/my-app"
    echo ""
    echo -e "  ${YELLOW}2)${NC} ${BOLD}Session ID + Path${NC}"
    print_info "Shows unique session ID + path: 134eed79 ~/projects"
    print_info "Helps identify multiple Claude sessions."
    echo ""
    echo -e "  ${YELLOW}3)${NC} ${BOLD}Path + Session ID${NC}"
    print_info "Shows path + session ID: ~/projects 134eed79"
    echo ""
    echo -e "  ${YELLOW}4)${NC} ${BOLD}Session ID Only${NC}"
    print_info "Shows just the session ID: 134eed79"
    print_info "Minimal, relies on colors for state."
    echo ""

    local valid=false
    while [[ "$valid" == "false" ]]; do
        local choice
        choice=$(read_choice "Select fallback mode [1-4]" "1")

        case "$choice" in
            1) SELECTED_TITLE_FALLBACK="path"; valid=true ;;
            2) SELECTED_TITLE_FALLBACK="session-path"; valid=true ;;
            3) SELECTED_TITLE_FALLBACK="path-session"; valid=true ;;
            4) SELECTED_TITLE_FALLBACK="session"; valid=true ;;
            *) echo -e "${RED}Invalid choice. Please enter a number from 1 to 4.${NC}" ;;
        esac
    done

    echo ""
    echo -e "  ${GREEN}Title fallback: ${BOLD}$SELECTED_TITLE_FALLBACK${NC}"
}

configure_full_title_mode() {
    echo ""
    print_info "Full title mode selected. Configuring spinner settings..."
    echo ""

    # Configure CLAUDE_CODE_DISABLE_TERMINAL_TITLE in settings.json
    local SETTINGS_FILE="$HOME/.claude/settings.json"
    if [[ -f "$SETTINGS_FILE" ]]; then
        # Check if already set
        if grep -q 'CLAUDE_CODE_DISABLE_TERMINAL_TITLE' "$SETTINGS_FILE"; then
            echo -e "  ${GREEN}✓${NC} CLAUDE_CODE_DISABLE_TERMINAL_TITLE already configured"
        else
            echo -e "  ${YELLOW}!${NC} Need to configure CLAUDE_CODE_DISABLE_TERMINAL_TITLE"
            if confirm "  Add to ~/.claude/settings.json?"; then
                if command -v jq &>/dev/null; then
                    local backup_file="${SETTINGS_FILE}.bak"
                    local tmp_file="${SETTINGS_FILE}.tmp"

                    # Create backup before modifying
                    if ! cp "$SETTINGS_FILE" "$backup_file" 2>/dev/null; then
                        echo -e "  ${RED}✗${NC} Failed to create backup; aborting update."
                    else
                        local jq_success=false

                        # Check if env key exists and apply appropriate jq transformation
                        if jq -e '.env' "$SETTINGS_FILE" &>/dev/null; then
                            jq '.env["CLAUDE_CODE_DISABLE_TERMINAL_TITLE"] = "1"' "$SETTINGS_FILE" > "$tmp_file" 2>/dev/null && jq_success=true
                        else
                            jq '. + {"env": {"CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1"}}' "$SETTINGS_FILE" > "$tmp_file" 2>/dev/null && jq_success=true
                        fi

                        if [[ "$jq_success" == "true" ]] && jq -e '.' "$tmp_file" >/dev/null 2>&1; then
                            # Validate JSON is valid before replacing
                            if mv "$tmp_file" "$SETTINGS_FILE" 2>/dev/null; then
                                rm -f "$backup_file" 2>/dev/null
                                echo -e "  ${GREEN}✓${NC} Added to settings.json"
                                echo -e "  ${YELLOW}!${NC} Restart Claude Code for this to take effect"
                            else
                                echo -e "  ${RED}✗${NC} Failed to update settings.json; restoring backup."
                                mv "$backup_file" "$SETTINGS_FILE" 2>/dev/null || true
                                rm -f "$tmp_file" 2>/dev/null
                            fi
                        else
                            echo -e "  ${RED}✗${NC} jq failed to produce valid JSON; restoring backup."
                            mv "$backup_file" "$SETTINGS_FILE" 2>/dev/null || true
                            rm -f "$tmp_file" 2>/dev/null
                        fi
                    fi
                else
                    echo -e "  ${RED}✗${NC} jq not found. Please manually add to ~/.claude/settings.json:"
                    echo -e '     "env": { "CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1" }'
                fi
            else
                echo -e "  ${DIM}Skipped. Remember to add manually for full mode to work.${NC}"
            fi
        fi
    else
        echo -e "  ${YELLOW}!${NC} ~/.claude/settings.json not found"
        print_info "Create it with: {\"env\": {\"CLAUDE_CODE_DISABLE_TERMINAL_TITLE\": \"1\"}}"
    fi

    # Spinner Style
    echo ""
    echo "  Select spinner style for processing state:"
    echo ""
    echo -e "  ${YELLOW}1)${NC} ${BOLD}braille${NC} - Rotating dots ⠋ ⠙ ⠹ ⠸ (Claude-style)"
    echo -e "  ${YELLOW}2)${NC} ${BOLD}circle${NC} - Filling circles ○ ◔ ◑ ◕ ●"
    echo -e "  ${YELLOW}3)${NC} ${BOLD}block${NC} - Pulsing bars ▁ ▂ ▃ ▄ ▅ ▆ ▇ █"
    echo -e "  ${YELLOW}4)${NC} ${BOLD}eye-animate${NC} - Random eye characters • ◦ · ° ○ ●"
    echo -e "  ${YELLOW}5)${NC} ${BOLD}none${NC} - Use existing face variants (no spinner)"
    echo -e "  ${YELLOW}6)${NC} ${BOLD}random${NC} - Random selection per session ${DIM}(Recommended)${NC}"
    echo ""

    local valid=false
    while [[ "$valid" == "false" ]]; do
        local choice
        choice=$(read_choice "Select spinner style [1-6]" "6")

        case "$choice" in
            1) SELECTED_SPINNER_STYLE="braille"; valid=true ;;
            2) SELECTED_SPINNER_STYLE="circle"; valid=true ;;
            3) SELECTED_SPINNER_STYLE="block"; valid=true ;;
            4) SELECTED_SPINNER_STYLE="eye-animate"; valid=true ;;
            5) SELECTED_SPINNER_STYLE="none"; valid=true ;;
            6) SELECTED_SPINNER_STYLE="random"; valid=true ;;
            *) echo -e "${RED}Invalid choice.${NC}" ;;
        esac
    done

    echo ""
    echo -e "  ${GREEN}Spinner style: ${BOLD}$SELECTED_SPINNER_STYLE${NC}"

    # Eye Synchronization Mode (only if face enabled and not "none" style)
    if [[ "$SELECTED_FACE_ENABLED" == "true" && "$SELECTED_SPINNER_STYLE" != "none" ]]; then
        echo ""
        echo "  How should the two 'eyes' in the face animate?"
        echo ""
        echo -e "  ${YELLOW}1)${NC} ${BOLD}sync${NC} - Both eyes same frame: Ǝ[⠋ ⠋]E"
        echo -e "  ${YELLOW}2)${NC} ${BOLD}opposite${NC} - Eyes half-cycle apart: Ǝ[◐ ◑]E"
        echo -e "  ${YELLOW}3)${NC} ${BOLD}stagger${NC} - Left leads, right follows: Ǝ[⠹ ⠙]E"
        echo -e "  ${YELLOW}4)${NC} ${BOLD}mirror${NC} - Eyes move in opposite directions"
        echo -e "  ${YELLOW}5)${NC} ${BOLD}random${NC} - Random selection per session ${DIM}(Recommended)${NC}"
        echo ""

        local valid=false
        while [[ "$valid" == "false" ]]; do
            local choice
            choice=$(read_choice "Select eye mode [1-5]" "5")

            case "$choice" in
                1) SELECTED_SPINNER_EYE_MODE="sync"; valid=true ;;
                2) SELECTED_SPINNER_EYE_MODE="opposite"; valid=true ;;
                3) SELECTED_SPINNER_EYE_MODE="stagger"; valid=true ;;
                4) SELECTED_SPINNER_EYE_MODE="mirror"; valid=true ;;
                5) SELECTED_SPINNER_EYE_MODE="random"; valid=true ;;
                *) echo -e "${RED}Invalid choice.${NC}" ;;
            esac
        done

        echo ""
        echo -e "  ${GREEN}Eye mode: ${BOLD}$SELECTED_SPINNER_EYE_MODE${NC}"
    fi

    # Session Identity
    echo ""
    echo "  Should each Claude Code session have a unique visual identity?"
    print_info "When enabled, spinner style and eye mode are randomly selected once"
    print_info "at session start and maintained throughout for consistent appearance."
    echo ""

    if confirm "Enable session identity?"; then
        SELECTED_SESSION_IDENTITY="true"
    else
        SELECTED_SESSION_IDENTITY="false"
    fi

    echo ""
    echo -e "  ${GREEN}Session identity: ${BOLD}$SELECTED_SESSION_IDENTITY${NC}"

    # Note about spinner cache
    echo ""
    print_info "Note: To apply new spinner settings to existing sessions,"
    print_info "clear the cache: rm -f ~/.cache/tavs/session-spinner.* ~/.cache/tavs/spinner-idx.*"
}
