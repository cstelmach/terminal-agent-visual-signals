#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals - Gemini CLI Installer
# ==============================================================================
# Standalone installer for Gemini CLI visual signals.
# Features:
# - Dry-run preview (default)
# - Atomic file replacement
# - Automatic backup (*.json.bak)
# - Smart hook merging (prepends new hooks, avoids duplicates)
# - Enables hooks in Gemini settings
# ==============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Paths
REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
GEMINI_CONFIG_DIR="$HOME/.gemini"
SETTINGS_FILE="$GEMINI_CONFIG_DIR/settings.json"
HOOKS_SOURCE="$REPO_ROOT/src/agents/gemini/hooks.json"

echo -e "${BLUE}=== TAVS - Terminal Agent Visual Signals - Gemini CLI Installer ===${NC}"
echo -e "Repository: $REPO_ROOT"
echo ""

# Check prerequisites
if [[ ! -d "$GEMINI_CONFIG_DIR" ]]; then
    echo -e "${RED}Error: Gemini CLI config directory not found: $GEMINI_CONFIG_DIR${NC}"
    echo "Please install and configure Gemini CLI first."
    exit 1
fi

if [[ ! -f "$HOOKS_SOURCE" ]]; then
    echo -e "${RED}Error: Hooks source not found: $HOOKS_SOURCE${NC}"
    exit 1
fi

# Python script to handle JSON safely
PYTHON_SCRIPT=$(cat <<'END_PYTHON'
import sys, json, os, shutil, tempfile

target_file = sys.argv[1]
new_hooks_file = sys.argv[2]
placeholder = sys.argv[3]
repo_path = sys.argv[4]
mode = sys.argv[5]

try:
    # 1. Load Existing Settings
    if os.path.exists(target_file):
        with open(target_file, 'r') as f:
            try:
                settings = json.load(f)
            except json.JSONDecodeError:
                print(f"Error: {target_file} is not valid JSON.", file=sys.stderr)
                sys.exit(1)
    else:
        print(f"Creating new settings file: {target_file}")
        settings = {}

    # 2. Load New Hooks Template
    with open(new_hooks_file, 'r') as f:
        content = f.read().replace(placeholder, repo_path)
        new_data = json.loads(content)
        new_hooks_map = new_data.get('hooks', {})

    # 3. Ensure hooks are enabled
    if 'tools' not in settings:
        settings['tools'] = {}
    settings['tools']['enableHooks'] = True

    # 4. Merge Logic (Prepend & Deduplicate)
    if 'hooks' not in settings:
        settings['hooks'] = {}

    existing_hooks_section = settings['hooks']
    changes_log = []

    for event, new_hooks_list in new_hooks_map.items():
        if event not in existing_hooks_section:
            existing_hooks_section[event] = []

        # Iterate reversed so we can insert at 0 and maintain order
        for new_hook in reversed(new_hooks_list):
            # Get command from nested structure
            inner_hooks = new_hook.get('hooks', [])
            if inner_hooks:
                new_cmd = inner_hooks[0].get('command', '')
            else:
                new_cmd = new_hook.get('command', '')

            is_duplicate = False

            # Check for duplicates
            for existing in existing_hooks_section[event]:
                existing_inner = existing.get('hooks', [])
                if existing_inner:
                    existing_cmd = existing_inner[0].get('command', '')
                else:
                    existing_cmd = existing.get('command', '')
                if existing_cmd == new_cmd:
                    is_duplicate = True
                    break

            if not is_duplicate:
                existing_hooks_section[event].insert(0, new_hook)
                cmd_short = new_cmd.split('/')[-1] if new_cmd else 'unknown'
                changes_log.append(f"  [+] {event}: Added hook '{cmd_short}'")

    # 5. Handle Modes
    if mode == 'preview':
        print("Proposed Changes:")
        print("  [+] tools.enableHooks = true")
        if not changes_log:
            print("  (No new hooks to add - all already present)")
        else:
            for log in changes_log:
                print(log)
        print("\nResulting 'hooks' section preview:")
        print(json.dumps(settings['hooks'], indent=2)[:2000])
        if len(json.dumps(settings['hooks'])) > 2000:
            print("... (truncated)")

    elif mode == 'apply':
        # Atomic Write
        # 1. Backup if exists
        if os.path.exists(target_file):
            backup_path = target_file + ".bak"
            shutil.copy2(target_file, backup_path)
            print(f"Backup created: {backup_path}")

        # 2. Write to temp
        os.makedirs(os.path.dirname(target_file), exist_ok=True)
        fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(target_file), text=True)
        with os.fdopen(fd, 'w') as tmp:
            json.dump(settings, tmp, indent=2)
            tmp.write('\n')

        # 3. Rename (Atomic)
        os.replace(tmp_path, target_file)
        print(f"Successfully updated {target_file}")

except Exception as e:
    print(f"Python Error: {e}", file=sys.stderr)
    import traceback
    traceback.print_exc()
    sys.exit(1)
END_PYTHON
)

# Run installation
echo -e "${YELLOW}--- Gemini CLI Configuration ---${NC}"
echo "Settings file: $SETTINGS_FILE"
echo -e "${CYAN}Analyzing changes...${NC}"
echo ""

# 1. PREVIEW
output=$(python3 -c "$PYTHON_SCRIPT" "$SETTINGS_FILE" "$HOOKS_SOURCE" '${GEMINI_EXTENSION_ROOT}' "$REPO_ROOT" "preview" 2>&1)

if [[ "$output" == *"Python Error:"* ]] || [[ "$output" == *"Error:"* ]]; then
    echo -e "${RED}$output${NC}"
    exit 1
fi

echo "$output"
echo ""

# 2. CONFIRM
echo -e "${YELLOW}WARNING: This will modify $SETTINGS_FILE${NC}"
if [[ -f "$SETTINGS_FILE" ]]; then
    echo "A backup will be created at $SETTINGS_FILE.bak"
fi
echo ""
read -p "Apply these changes? [y/N] " response

if [[ "$response" =~ ^[yY] ]]; then
    # 3. APPLY
    python3 -c "$PYTHON_SCRIPT" "$SETTINGS_FILE" "$HOOKS_SOURCE" '${GEMINI_EXTENSION_ROOT}' "$REPO_ROOT" "apply"
    echo ""
    echo -e "${GREEN}✓ Gemini CLI visual signals installed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Start a new Gemini CLI session"
    echo "  2. Verify terminal color changes on prompt submit"
else
    echo "Installation cancelled."
fi
