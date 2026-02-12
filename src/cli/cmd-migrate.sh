#!/bin/bash
# ==============================================================================
# TAVS CLI — migrate command
# ==============================================================================
# Usage: tavs migrate [--help]
#
# Migrates old (pre-v3) user.conf to the new v3 organized format.
# Preserves all active settings. Creates a timestamped backup.
# ==============================================================================

source "$CLI_DIR/cli-utils.sh"

_V3_MARKER="User Configuration (v3)"

cmd_migrate() {
    # Handle --help
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        cat <<'EOF'
tavs migrate — Migrate configuration to v3 format

Usage:
  tavs migrate            Migrate old config to v3 format

What it does:
  1. Detects if your config is already v3 format
  2. Extracts all active (uncommented) settings from old config
  3. Creates a new v3 config from the organized template
  4. Applies your settings to the new config
  5. Backs up old config as ~/.tavs/user.conf.v2.bak

Safe to run multiple times — already-migrated configs are skipped.
All variable names are unchanged between v2 and v3.
EOF
        return 0
    fi

    # Check if user.conf exists
    if [[ ! -f "$TAVS_USER_CONFIG" ]]; then
        cli_info "No user configuration found. Nothing to migrate."
        cli_info "Create one with: tavs set <key> <value>"
        return 0
    fi

    # Check if already v3
    if grep -q "$_V3_MARKER" "$TAVS_USER_CONFIG" 2>/dev/null; then
        cli_info "Configuration is already v3 format. No migration needed."
        return 0
    fi

    echo "Migrating user configuration to v3 format..."
    echo ""

    # Step 1: Extract active settings from old config
    local settings=()
    local setting_count=0
    while IFS= read -r line; do
        # Skip comments, empty lines, shebang
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" == "#!/"* ]] && continue

        # Must contain = to be a setting
        [[ "$line" == *"="* ]] || continue

        settings+=("$line")
        setting_count=$((setting_count + 1))
    done < "$TAVS_USER_CONFIG"

    if [[ $setting_count -eq 0 ]]; then
        cli_info "No active settings found in old config."
        cli_info "Creating fresh v3 config from template."
    else
        echo "  Found $setting_count active setting(s)."
    fi

    # Step 2: Backup old config
    local backup="${TAVS_USER_CONFIG}.v2.bak"
    if [[ -f "$backup" ]]; then
        backup="${backup}.$(date +%Y%m%d-%H%M%S)"
    fi
    cp "$TAVS_USER_CONFIG" "$backup"
    echo "  Backup: $backup"

    # Step 3: Create new config from v3 template
    local template="$TAVS_ROOT/src/config/user.conf.template"
    if [[ -f "$template" ]]; then
        cp "$template" "$TAVS_USER_CONFIG"
    else
        cli_warn "Template not found, creating minimal v3 config."
        cat > "$TAVS_USER_CONFIG" << 'HEADER'
#!/bin/bash
# ==============================================================================
# TAVS - User Configuration (v3)
# ==============================================================================
# Quick config: tavs set <key> <value>
# Full wizard:  tavs wizard
# See current:  tavs status
# ==============================================================================

HEADER
    fi

    # Step 4: Apply each old setting to the new config
    local applied=0
    for setting in "${settings[@]}"; do
        # Parse var=value
        local var="${setting%%=*}"
        local value="${setting#*=}"

        # Strip leading/trailing whitespace from var
        var="${var#"${var%%[![:space:]]*}"}"
        var="${var%"${var##*[![:space:]]}"}"

        if [[ -n "$var" ]]; then
            # Check if the variable exists (commented) in the new template
            if grep -q "^#[[:space:]]*${var}=" "$TAVS_USER_CONFIG" 2>/dev/null; then
                # Uncomment and set the value — use temp file for portability
                local tmp
                tmp=$(mktemp)
                local found=false
                while IFS= read -r line; do
                    if [[ "$found" == "false" ]] && [[ "$line" =~ ^#[[:space:]]*${var}= ]]; then
                        echo "${var}=${value}"
                        found=true
                    else
                        echo "$line"
                    fi
                done < "$TAVS_USER_CONFIG" > "$tmp"
                mv "$tmp" "$TAVS_USER_CONFIG"
            else
                # Append to end of file
                echo "${var}=${value}" >> "$TAVS_USER_CONFIG"
            fi
            applied=$((applied + 1))
        fi
    done

    echo "  Applied $applied setting(s) to v3 config."
    echo ""
    cli_success "Migration complete."
    cli_info "Run 'tavs status' to verify your settings."
    cli_info "Run 'tavs config show' to see the new config."
}
