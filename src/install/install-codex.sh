#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals - Codex CLI Installer
# ==============================================================================
# Standalone installer for Codex CLI visual signals.
#
# ⚠️  LIMITED SUPPORT: Codex CLI only supports ONE event (agent-turn-complete)
#     Only the "complete" signal (green) will work.
#     Processing, permission, idle, and compacting signals are NOT supported.
#
# See: https://github.com/openai/codex/discussions/2150 (60+ votes for full hooks)
# ==============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Paths
REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
CODEX_CONFIG_DIR="$HOME/.codex"
CONFIG_FILE="$CODEX_CONFIG_DIR/config.toml"
TRIGGER_SCRIPT="$REPO_ROOT/src/agents/codex/trigger.sh"

echo -e "${BLUE}=== TAVS - Terminal Agent Visual Signals - Codex CLI Installer ===${NC}"
echo -e "Repository: $REPO_ROOT"
echo ""

# Show limitations warning
echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  ⚠️  LIMITED SUPPORT                                           ║${NC}"
echo -e "${YELLOW}║                                                                ║${NC}"
echo -e "${YELLOW}║  Codex CLI only supports ONE hook event: agent-turn-complete  ║${NC}"
echo -e "${YELLOW}║                                                                ║${NC}"
echo -e "${YELLOW}║  What WILL work:                                               ║${NC}"
echo -e "${YELLOW}║    ✅ Complete signal (green) - when agent finishes            ║${NC}"
echo -e "${YELLOW}║                                                                ║${NC}"
echo -e "${YELLOW}║  What will NOT work:                                           ║${NC}"
echo -e "${YELLOW}║    ❌ Processing signal (orange)                               ║${NC}"
echo -e "${YELLOW}║    ❌ Permission signal (red)                                  ║${NC}"
echo -e "${YELLOW}║    ❌ Idle signal (purple)                                     ║${NC}"
echo -e "${YELLOW}║    ❌ Compacting signal (teal)                                 ║${NC}"
echo -e "${YELLOW}║    ❌ Reset signal                                             ║${NC}"
echo -e "${YELLOW}║                                                                ║${NC}"
echo -e "${YELLOW}║  Vote for full hooks: github.com/openai/codex/discussions/2150║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
if [[ ! -d "$CODEX_CONFIG_DIR" ]]; then
    echo -e "${RED}Error: Codex CLI config directory not found: $CODEX_CONFIG_DIR${NC}"
    echo "Please install and configure Codex CLI first."
    exit 1
fi

if [[ ! -f "$TRIGGER_SCRIPT" ]]; then
    echo -e "${RED}Error: Trigger script not found: $TRIGGER_SCRIPT${NC}"
    exit 1
fi

# Check if config.toml exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${YELLOW}Config file not found. Will create: $CONFIG_FILE${NC}"
    EXISTING_CONFIG=""
else
    EXISTING_CONFIG=$(cat "$CONFIG_FILE")
fi

# Check if notify is already configured
NOTIFY_LINE="notify = [\"bash\", \"-lc\", \"$TRIGGER_SCRIPT complete\"]"

if echo "$EXISTING_CONFIG" | grep -q "tavs.*trigger.sh"; then
    echo -e "${GREEN}✓ Visual signals already configured in $CONFIG_FILE${NC}"
    echo ""
    echo "Current notify configuration:"
    grep -n "notify" "$CONFIG_FILE" 2>/dev/null || echo "  (not found)"
    echo ""
    read -p "Overwrite existing configuration? [y/N] " response
    if [[ ! "$response" =~ ^[yY] ]]; then
        echo "Installation cancelled."
        exit 0
    fi
fi

# Show what will be added
echo -e "${CYAN}Configuration to add to $CONFIG_FILE:${NC}"
echo ""
echo -e "${GREEN}$NOTIFY_LINE${NC}"
echo ""

# Confirm
read -p "Apply this configuration? [y/N] " response

if [[ "$response" =~ ^[yY] ]]; then
    # Backup existing config
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
        echo "Backup created: $CONFIG_FILE.bak"
    fi

    # Remove existing notify line if present
    if [[ -f "$CONFIG_FILE" ]]; then
        # Create temp file without notify lines
        grep -v "^notify" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" || true
        mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    fi

    # Append notify configuration
    echo "" >> "$CONFIG_FILE"
    echo "# TAVS - Terminal Agent Visual Signals (complete signal only)" >> "$CONFIG_FILE"
    echo "$NOTIFY_LINE" >> "$CONFIG_FILE"

    echo ""
    echo -e "${GREEN}✓ Codex CLI visual signals installed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Start a new Codex CLI session"
    echo "  2. Run a command and wait for completion"
    echo "  3. Terminal should turn green (🟢) when agent finishes"
    echo ""
    echo -e "${YELLOW}Remember: Only the complete signal works with Codex CLI.${NC}"
else
    echo "Installation cancelled."
fi
