# TAVS Configuration Change Workflow

Step-by-step procedure for making targeted TAVS configuration changes.
Use this workflow when the user wants to modify specific settings — not for
initial setup (use the Setup Wizard for that).

## 1. Overview

This workflow handles:
- Single setting changes ("change my theme to dracula")
- Batch updates ("switch to compact face mode with squares theme")
- Theme switches (compound alias that sets two variables)
- Raw variable edits (per-agent colors, faces, title formats)

**Not for:** First-time setup or full reconfiguration — use the Setup Wizard instead.

## 2. Safety Protocol: Backup

Before ANY config change, create a backup:

```bash
# Create backup directory if needed
mkdir -p ~/.tavs/backups

# Back up current config (skip if user.conf doesn't exist yet)
if [[ -f ~/.tavs/user.conf ]]; then
    cp ~/.tavs/user.conf ~/.tavs/backups/user.conf.$(date +%Y%m%d_%H%M%S)
fi
```

Inform the user: "Backed up your current config to `~/.tavs/backups/user.conf.TIMESTAMP`"

**Skip backup** if `~/.tavs/user.conf` doesn't exist (fresh install — nothing to back up).

## 3. Setting Type Resolution

Determine the correct mechanism for each requested change:

**Step 1:** Check if the setting name matches one of the 28 CLI aliases.
See `references/config-options.md` for the complete alias table.

- Match found → use `./tavs set <alias> <value>` (validated, handles compound aliases)
- No match → proceed to Step 2

**Step 2:** Check if it's a known raw variable pattern (see `references/raw-variables.md`):
- Per-agent colors: `{AGENT}_{MODE}_{STATE}` (e.g., `CLAUDE_DARK_PROCESSING`)
- Per-agent faces: `{AGENT}_FACES_{STATE}` (e.g., `CLAUDE_FACES_PROCESSING`)
- Per-state titles: `TAVS_TITLE_FORMAT_{STATE}` or `{AGENT}_TITLE_FORMAT_{STATE}`
- Feature toggles: `ENABLE_*` variables
- Any other valid shell identifier in `user.conf.template`

- Match found → use Edit tool on `~/.tavs/user.conf`
- No match → inform user the setting doesn't exist, suggest closest match

**Compound aliases:** The `theme` alias is compound — `./tavs set theme nord` sets
both `THEME_PRESET="nord"` and `THEME_MODE="preset"`. The `title-preset` alias is
also compound. Always use the CLI for these.

## 4. Raw Variable Editing Procedure

When using the Edit tool instead of the CLI:

1. **Read** `~/.tavs/user.conf` first
2. **Locate** the variable:
   - If commented out (prefixed with `#`): uncomment and update the value
   - If already active: update the value in place
   - If not present: add it to the appropriate section (match section headers from
     `user.conf.template`: Essential Settings, Visual Features, Title System, etc.)
3. **Validate** the value:
   - Variable name: valid shell identifier (`[A-Za-z_][A-Za-z0-9_]*`)
   - Color values: 7-char hex format (`#RRGGBB`)
   - Boolean values: `"true"` or `"false"` (quoted)
   - Arrays: bash syntax `('item1' 'item2')` — NOT JSON `["item1", "item2"]`
   - Strings: double-quoted (`"value"`)
4. **Ensure** no spaces around `=` in assignments: `VARIABLE="value"`
5. **Preserve** section headers (`# ╔═══...`) — these are structural, not settings

**Important:** Lines starting with `##` are section dividers. Lines with single `#`
followed by a variable name are commented-out settings. Don't confuse the two.

## 5. Preview & Confirmation

Before applying any changes, show a summary:

**Single change:**
> Setting `theme`: (none) -> `nord`

**Multiple changes:**
> | Setting | Current | New |
> |---------|---------|-----|
> | `THEME_PRESET` | (none) | `nord` |
> | `THEME_MODE` | `static` | `preset` |
> | `TAVS_FACE_MODE` | `standard` | `compact` |

**For CLI commands**, show the exact commands:
```
tavs set theme nord
tavs set face-mode compact
```

Use AskUserQuestion with options:
- **Apply** — Execute the changes
- **Edit** — Let me adjust before applying
- **Cancel** — Abort without changes

## 6. Apply

Execute changes in order:

**For CLI aliases:**
```bash
./tavs set theme nord
./tavs set face-mode compact
```

**For raw variables:** Use the Edit tool to modify `~/.tavs/user.conf` directly.

**Mixed changes:** Run CLI commands first (they validate), then apply raw variable
edits. This ensures validated settings are written correctly before adding advanced
overrides.

## 7. Verify

After applying:

1. Run `./tavs status` to show the new configuration state
2. Optionally run `./tavs test --quick` to visually demo the change (ask first)
3. Inform user: "Changes take effect on the next hook trigger (your next prompt)"

If the user enabled a title mode or changed something requiring additional setup
(e.g., full title mode needs `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1`), remind them.

## 8. Rollback

If something went wrong:

```bash
# List available backups (most recent last)
ls -1t ~/.tavs/backups/

# Restore the most recent backup
cp ~/.tavs/backups/user.conf.LATEST ~/.tavs/user.conf
```

Replace `user.conf.LATEST` with the actual timestamped filename. If multiple backups
exist, show the list and let the user pick which to restore.

After rollback, run `./tavs status` to confirm the restored state.

## 9. Common Recipes

**Switch theme preset:**
```bash
./tavs set theme dracula
```
This is a compound alias — sets both `THEME_PRESET` and `THEME_MODE`.

**Change face mode (standard <-> compact):**
```bash
./tavs set face-mode compact
./tavs set compact-theme squares
```

**Update title format template:**
```bash
./tavs set title-format "{FACE} {STATUS_ICON} {SESSION_ICON} {BASE}"
```

**Set per-agent color override** (raw variable, use Edit):
```
CLAUDE_DARK_PROCESSING="#4A3D2F"
```

**Enable/disable a feature toggle:**
```bash
./tavs set mode-aware false
./tavs set bell-complete true
```

**Change identity system:**
```bash
./tavs set identity-mode single
./tavs set dir-icon-type plants
```
