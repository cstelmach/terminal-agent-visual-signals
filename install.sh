#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Themes - Unified Installer
# ==============================================================================
# Safe, interactive installer for Claude, Gemini, and Codex.
# Features:
# - Dry-run preview (default)
# - Atomic file replacement
# - Automatic backup (*.json.bak)
# - Smart hook merging (prepends new hooks, avoids duplicates)
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
CLAUDE_CONFIG_DIR="$HOME/.claude"
GEMINI_CONFIG_DIR="$HOME/.gemini"
CODEX_CONFIG_DIR="$HOME/.codex"

echo -e "${BLUE}=== Terminal Agent Visual Themes Installer ===${NC}"
echo -e "Repository: $REPO_ROOT"
echo ""

# Python script to handle JSON safely
# Note: delimiter is quoted 'END_PYTHON' to prevent bash expansion
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
        print(f"File not found: {target_file}. Creating new object.")
        settings = {}

    # 2. Load New Hooks Template
    with open(new_hooks_file, 'r') as f:
        content = f.read().replace(placeholder, repo_path)
        new_data = json.loads(content)
        new_hooks_map = new_data.get('hooks', {})

    # 3. Merge Logic (Prepend & Deduplicate)
    if 'hooks' not in settings:
        settings['hooks'] = {}
    
    existing_hooks_section = settings['hooks']
    changes_log = []

    for event, new_hooks_list in new_hooks_map.items():
        if event not in existing_hooks_section:
            existing_hooks_section[event] = []
        
        # Iterate reversed so we can insert at 0 and maintain order
        for new_hook in reversed(new_hooks_list):
            new_cmd = new_hook.get('command', '')
            is_duplicate = False
            
            # Simple duplicate check based on command string
            for existing in existing_hooks_section[event]:
                if existing.get('command') == new_cmd:
                    is_duplicate = True
                    break
            
            if not is_duplicate:
                existing_hooks_section[event].insert(0, new_hook)
                changes_log.append(f"  [+] {event}: Added hook '{new_cmd.split('/')[-1]}'")
            else:
                pass # Duplicate

    # 4. Handle Modes
    if mode == 'preview':
        if not changes_log:
            print("No new hooks to add (all duplicates or already present).")
        else:
            print("Proposed Changes:")
            for log in changes_log:
                print(log)
            print("\nResulting 'hooks' section preview:")
            print(json.dumps(settings['hooks'], indent=2))
            
    elif mode == 'apply':
        if not changes_log:
            print("No changes needed.")
            sys.exit(0)

        # Atomic Write
        # 1. Backup
        backup_path = target_file + ".bak"
        shutil.copy2(target_file, backup_path)
        print(f"Backup created: {backup_path}")

        # 2. Write to temp
        fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(target_file), text=True)
        with os.fdopen(fd, 'w') as tmp:
            json.dump(settings, tmp, indent=2)
            tmp.write('\n') # trailing newline
        
        # 3. Rename (Atomic)
        os.replace(tmp_path, target_file)
        print(f"Successfully updated {target_file}")

except Exception as e:
    print(f"Python Error: {e}", file=sys.stderr)
    sys.exit(1)
END_PYTHON
)

# Helper function to run the python script
run_json_merge() {
    local target="$1"
    local source="$2"
    local var="$3"
    local mode="$4"
    
    python3 -c "$PYTHON_SCRIPT" "$target" "$source" "$var" "$REPO_ROOT" "$mode"
}

# Generic install function
process_agent() {
    local agent_name="$1"
    local config_dir="$2"
    local hook_source="$3"
    local var_name="$4"
    local settings_file="$config_dir/settings.json"

    echo -e "${YELLOW}--- Checking $agent_name Configuration ---${NC}"
    
    if [[ ! -d "$config_dir" ]]; then
        echo "Config directory not found: $config_dir (Skipping)"
        return
    fi
    
    if [[ ! -f "$settings_file" ]]; then
        echo "Settings file not found: $settings_file (Skipping)"
        return
    fi

    echo "Found settings: $settings_file"
    echo -e "${CYAN}Analyzing changes...${NC}"
    
    # 1. PREVIEW
    output=$(run_json_merge "$settings_file" "$hook_source" "$var_name" "preview")
    
    # Check if python script failed (check for Python Error string in stderr, 
    # but we are capturing stdout. Let's rely on the output text.)
    if [[ "$output" == *"Python Error:"* ]]; then
        echo -e "${RED}$output${NC}"
        return
    fi

    if [[ "$output" == *"No new hooks to add"* ]]; then
        echo -e "${GREEN}✓ All hooks already installed.${NC}"
        return
    fi

    # Show preview output
    echo "$output"
    echo ""
    
    # 2. CONFIRM
    echo -e "${YELLOW}WARNING: This will rewrite $settings_file.${NC}"
    echo "A backup will be created at $settings_file.bak"
    read -p "Apply these changes to $agent_name? [y/N] " response
    
    if [[ "$response" =~ ^[yY] ]]; then
        # 3. APPLY
        run_json_merge "$settings_file" "$hook_source" "$var_name" "apply"
        echo -e "${GREEN}✓ $agent_name updated.${NC}"
    else
        echo "Skipped $agent_name."
    fi
    echo ""
}

# === MAIN ===

process_agent "Claude" \
    "$CLAUDE_CONFIG_DIR" \
    "$REPO_ROOT/src/agents/claude/hooks.json" \
    "\${CLAUDE_PLUGIN_ROOT}"

process_agent "Gemini" \
    "$GEMINI_CONFIG_DIR" \
    "$REPO_ROOT/src/agents/gemini/hooks.json" \
    "\${GEMINI_EXTENSION_ROOT}"

process_agent "Codex" \
    "$CODEX_CONFIG_DIR" \
    "$REPO_ROOT/src/agents/codex/hooks.json" \
    "\${CODEX_EXTENSION_ROOT}"

echo -e "${BLUE}Done.${NC}"