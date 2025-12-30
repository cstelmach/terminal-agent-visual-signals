#!/bin/bash
# ==============================================================================
# Terminal OSC Escape Sequence Support Test
# ==============================================================================
# Tests whether your terminal supports the OSC sequences used by this project:
#   - OSC 0: Set window/tab title
#   - OSC 11: Set background color
#   - OSC 111: Reset background to default
#
# Usage: ./test-terminal.sh
# ==============================================================================

echo "Testing terminal OSC support..."
echo "Terminal: ${TERM_PROGRAM:-$TERM}"
echo ""

# Test OSC 0 (title)
printf "\033]0;TEST: OSC Title Support\007"
echo "✓ OSC 0 (title): Set title to 'TEST: OSC Title Support'"
echo "  → Check your tab/window title"
echo ""

# Test OSC 11 (background)
echo "Testing OSC 11 (background color)..."
printf "\033]11;#4A2021\007"
echo "  → Background should be RED now"
sleep 2

printf "\033]11;#473D2F\007"
echo "  → Background should be ORANGE now"
sleep 2

printf "\033]11;#3E3046\007"
echo "  → Background should be PURPLE now"
sleep 2

# Test OSC 111 (reset)
printf "\033]111\007"
echo "✓ OSC 111 (reset): Background restored to default"
echo ""

# Reset title
printf "\033]0;\007"

echo "================================"
echo "Results:"
echo "  - If title changed: OSC 0 ✓"
echo "  - If background changed colors: OSC 11 ✓"
echo "  - If background reset to default: OSC 111 ✓"
echo ""
echo "If all tests passed, your terminal supports visual signals!"
echo ""
echo "Tested terminals with full support:"
echo "  Ghostty, Kitty, WezTerm, iTerm2, VS Code, Cursor,"
echo "  GNOME Terminal, Windows Terminal (2025+), Foot"
