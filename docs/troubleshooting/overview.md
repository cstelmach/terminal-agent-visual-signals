# Troubleshooting Overview

Quick reference for common issues with Terminal Agent Visual Signals.

## Issue Index

| Problem | Symptoms | Solution |
|---------|----------|----------|
| No visual changes | Terminal stays default color | [Check terminal compatibility](#terminal-not-supported) |
| Plugin shows disabled | CLI says disabled but settings say true | [Local settings override](#local-settings-override) |
| Hooks not firing | No color change on prompt submit | [Verify hook installation](#hooks-not-installed) |
| Wrong colors | Colors different than expected | [Theme configuration](#wrong-theme) |
| Wrong faces showing | Old faces or wrong agent faces | [Agent theme issues](#agent-theme-issues) |
| Idle timer not working | No purple stages after completion | [Check idle-worker](#idle-timer-issues) |
| Palette theming not working | `ls` colors unchanged | [Palette theming issues](#palette-theming-issues) |
| OpenCode plugin fails | TypeScript/npm errors | [Build issues](#opencode-build-issues) |
| Spinner not animating | Static face during processing | [Spinner issues](#spinner-issues) |
| Spinner wrong style | Block instead of braille, etc. | [Spinner configuration](#spinner-configuration) |
| Title not changing | Tab title stays default | [Title management issues](#title-management-issues) |
| Title mode not working | Full mode not showing spinner | [Title mode setup](#title-mode-setup) |
| Ghostty title override | Ghostty resets title after commands | [Ghostty configuration](#ghostty-configuration) |
| Ghostty locked title | Title stops working after manual rename | [Ghostty manual tab naming](#ghostty-manual-tab-naming-known-limitation) |
| Empty variables in zsh | Config values empty in Claude Code | [Shell compatibility](#shell-compatibility-issues) |
| Subagent state not showing | No golden-yellow during Task tool | [Subagent state issues](#subagent-state-issues) |
| Tool error not flashing | No orange-red on tool failure | [Tool error issues](#tool-error-issues) |
| Subagent count wrong | Title shows wrong +N number | [Subagent counter issues](#subagent-counter-issues) |

## Quick Fixes

### Terminal Not Supported

Your terminal may not support OSC escape sequences.

**Test:**
```bash
./test-terminal.sh
```

**Solution:** Use a supported terminal:
- Ghostty (recommended)
- iTerm2 (macOS)
- Kitty
- WezTerm
- Windows Terminal

### Local Settings Override

Claude Code uses local settings that override global.

**Check:** Look for `.claude/settings.local.json` in project directory.

**Solution:** Enable plugin in local settings:
```json
{
  "enabledPlugins": {
    "tavs@tavs": true
  }
}
```

### Hooks Not Installed

Hooks may not be in settings file.

**Check Claude Code:**
```bash
grep -A5 "tavs" ~/.claude/settings.json
```

**Check Gemini CLI:**
```bash
grep -A5 "trigger.sh" ~/.gemini/settings.json
```

**Solution:** Run appropriate installer or enable plugin.

### Wrong Theme

Colors may be configured for a different palette.

**Check:** `src/core/theme.sh` for color definitions.

**Solution:** Modify theme colors or use a different terminal that renders colors correctly.

### Agent Theme Issues

Wrong faces appearing (e.g., round brackets instead of square for Claude).

**Common causes:**
1. **Plugin cache outdated** - Cached plugin version has old faces
2. **User override exists** - Custom faces.conf overriding source
3. **Old idle timer running** - Background process started before update

**Solution 1: Update plugin cache**
```bash
# Copy updated files to plugin cache
CACHE_DIR="$HOME/.claude/plugins/cache/tavs/tavs/*/src"
cp src/core/agent-theme.sh "$CACHE_DIR/core/"
cp src/agents/claude/data/faces.conf "$CACHE_DIR/agents/claude/data/"
```

**Solution 2: Check for user overrides**
```bash
# Check if user override exists
ls ~/.tavs/agents/claude/faces.conf
# If exists but outdated, remove or update it
```

**Solution 3: Kill stale background processes**
```bash
pkill -f "idle-worker"
./src/core/trigger.sh reset
```

**Verify faces are correct:**
```bash
/bin/bash -c '
    export TAVS_AGENT=claude
    source src/core/agent-theme.sh
    echo "Processing: $(get_random_face processing)"
'
# Should show: Ǝ[• •]E (square brackets for Claude)
```

### Idle Timer Issues

Timer may not be starting or may be killed prematurely.

**Check:**
```bash
ps aux | grep idle-worker
```

**Solution:**
1. Verify `ENABLE_IDLE=true` in theme.sh
2. Check for processes killing the timer
3. Increase idle timeout if needed

### Palette Theming Issues

Palette theming enabled but `ls`, `git` colors unchanged.

**Common causes:**
1. **TrueColor mode active** - Claude Code uses TrueColor by default
2. **Palette theming disabled** - Not enabled in config
3. **Terminal doesn't support OSC 4** - Use supported terminal

**Check TrueColor status:**
```bash
echo $COLORTERM  # "truecolor" means palette won't work
bash src/core/detect.sh test  # Shows "Palette Theming" status
```

**Solution 1: Launch in 256-color mode**
```bash
TERM=xterm-256color COLORTERM= claude
```

**Solution 2: Add alias**
```bash
# In ~/.zshrc or ~/.bashrc
alias claude='TERM=xterm-256color COLORTERM= claude'
```

**Solution 3: Enable palette theming**
```bash
# In ~/.tavs/user.conf
ENABLE_PALETTE_THEMING="auto"  # or "true"
```

**Test if working:**
```bash
ENABLE_PALETTE_THEMING=true COLORTERM= ./src/core/trigger.sh processing
ls --color=auto  # Colors should match theme
./src/core/trigger.sh reset
```

See [Palette Theming Reference](../reference/palette-theming.md) for details.

### Spinner Issues

Spinner not animating during processing - shows static face instead of animated eyes.

**Common causes:**
1. **Title mode not "full"** - Spinner only works in full mode
2. **Claude Code controlling titles** - Need to disable Claude's title management
3. **Spinner not integrated** - Using old title path without spinner

**Check title mode:**
```bash
grep "TAVS_TITLE_MODE" ~/.tavs/user.conf
# Should show: TAVS_TITLE_MODE="full"
```

**Solution:** Enable full title mode (see [Title Mode Setup](#title-mode-setup) below).

### Spinner Configuration

Spinner showing wrong style (e.g., blocks instead of braille).

**Check current settings:**
```bash
grep "TAVS_SPINNER" ~/.tavs/user.conf
```

**Available styles:** `braille`, `circle`, `block`, `eye-animate`, `none`, `random`

**Available eye modes:** `sync`, `opposite`, `stagger`, `clockwise`, `counter`, `mirror`

**Solution 1: Set spinner style**
```bash
# Add to ~/.tavs/user.conf
TAVS_SPINNER_STYLE="braille"
TAVS_SPINNER_EYE_MODE="sync"
```

**Solution 2: Clear cached spinner state**
```bash
# Spinner caches style per-session - clear to pick up new settings
rm -f ~/.cache/tavs/session-spinner.* ~/.cache/tavs/spinner-idx.*
```

**Verify spinner works:**
```bash
cd /path/to/tavs
zsh -c '
source src/core/theme.sh
source src/core/spinner.sh
source src/core/title.sh
export TAVS_TITLE_MODE="full"
for i in 1 2 3 4 5; do
    compose_title "processing" "Test"
done
'
# Should show animated braille: ⠋ ⠙ ⠹ ⠸ ⠼ etc.
```

### Title Management Issues

Terminal tab title not changing when TAVS triggers states.

**Common causes:**
1. **TTY not detected** - Hook runs without terminal access
2. **Title mode is "off"** - Disabled in config
3. **Terminal doesn't support OSC title** - Use supported terminal

**Check TTY detection:**
```bash
# From within Claude Code, TTY should be detected
echo $TTY
```

**Check title mode:**
```bash
grep "TAVS_TITLE_MODE" ~/.tavs/user.conf
# Valid values: full, prefix-only, skip-processing, off
```

**Solution:** See [Title Mode Setup](#title-mode-setup).

### Title Mode Setup

Setting up full title mode with animated spinner.

**Requirements for full mode:**
1. TAVS title mode set to "full"
2. Claude Code title management disabled
3. Terminal shell integration configured (Ghostty)

**Step 1: Enable full mode in TAVS**
```bash
# Add to ~/.tavs/user.conf
TAVS_TITLE_MODE="full"
```

**Step 2: Disable Claude Code title management**
```bash
# Add to ~/.claude/settings.json under "env":
{
  "env": {
    "CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1"
  }
}
```
Or use jq:
```bash
jq '.env["CLAUDE_CODE_DISABLE_TERMINAL_TITLE"] = "1"' ~/.claude/settings.json > tmp.json && mv tmp.json ~/.claude/settings.json
```

**Step 3: Configure terminal** (see [Ghostty Configuration](#ghostty-configuration) for Ghostty)

**Step 4: Restart Claude Code** for settings to take effect.

### Ghostty Configuration

Ghostty's shell integration manages tab titles by default, which conflicts with TAVS.

**Symptom:** Title changes briefly then reverts after each command.

**Solution: Disable Ghostty's title management**

Add to Ghostty config (`~/Library/Application Support/com.mitchellh.ghostty/config` on macOS):
```ini
# TAVS: Disable Ghostty's automatic title management
shell-integration-features = no-title
```

**Reload config:** Press `Cmd+Shift+,` or restart Ghostty.

This disables ONLY title management while keeping other shell integration features (cursor shape, sudo wrapping, etc.).

### Ghostty Manual Tab Naming (Known Limitation)

**Symptom:** After manually renaming a tab in Ghostty, TAVS spinner/title stops working.

**Cause:** When you manually name a tab in Ghostty (via Cmd+I or right-click → Rename), Ghostty **locks** that title and ignores all OSC escape sequences. This is intentional Ghostty behavior to protect your customization.

**This is NOT a TAVS bug** - Ghostty is designed this way.

**Solutions:**

1. **Clear the custom name:**
   - Press `Cmd+I` (or right-click tab → Rename)
   - Delete the custom name and save
   - Ghostty will now accept OSC title changes again

2. **Close and reopen the tab:**
   - New tabs don't have locked titles

3. **Use a different terminal:**
   - iTerm2 supports user title detection and can work around this
   - Other terminals may have different behaviors

**Note:** Unlike iTerm2 where TAVS can detect user-set titles via OSC 1337, Ghostty doesn't provide a way to query or detect locked titles. Once locked, TAVS cannot override it.

### Shell Compatibility Issues

Variables empty or wrong values when running in Claude Code (zsh) vs direct bash testing.

**Symptom:** Config values like `TAVS_TITLE_FORMAT` are empty in Claude Code but work in bash.

**Root cause:** Claude Code's Bash tool runs commands in zsh, not bash. Two issues can occur:
1. **BASH_SOURCE empty in zsh** - Path resolution fails
2. **Brace expansion in defaults** - `${VAR:-{...}}` interpreted differently

**Check if affected:**
```bash
# Run in both shells and compare
bash -c 'source src/core/theme.sh && echo "TAVS_TITLE_FORMAT=$TAVS_TITLE_FORMAT"'
zsh -c 'source src/core/theme.sh && echo "TAVS_TITLE_FORMAT=$TAVS_TITLE_FORMAT"'
# Both should show the same non-empty value
```

**Solution:** Update to latest code (commit 3aab004+) which includes zsh compatibility fixes:
- Uses `${(%):-%x}` fallback for path resolution in zsh
- Uses intermediate variables to avoid brace expansion issues

**If issue persists after updating:**
```bash
# Update plugin cache with fixed code
CACHE="$HOME/.claude/plugins/cache/tavs/tavs/1.2.0"
cp src/core/*.sh "$CACHE/src/core/"
```

### Subagent State Issues

Subagent golden-yellow background not appearing when Task tool spawns subagents.

**Common causes:**
1. **ENABLE_SUBAGENT disabled** - Feature toggle is off
2. **Plugin cache outdated** - Cached version doesn't have subagent support
3. **Claude Code version** - SubagentStart/SubagentStop hooks require recent Claude Code

**Check feature toggle:**
```bash
grep "ENABLE_SUBAGENT" ~/.tavs/user.conf
# Should be: ENABLE_SUBAGENT="true" (default)
```

**Solution 1: Update plugin cache**
```bash
CACHE="$HOME/.claude/plugins/cache/tavs/tavs/1.2.0"
cp src/core/*.sh "$CACHE/src/core/" && cp src/config/*.conf "$CACHE/src/config/"
```

**Solution 2: Test manually**
```bash
./src/core/trigger.sh subagent-start  # Should show golden-yellow
./src/core/trigger.sh reset
```

### Tool Error Issues

Tool error orange-red flash not appearing when tools fail.

**Common causes:**
1. **ENABLE_TOOL_ERROR disabled** - Feature toggle is off
2. **Plugin cache outdated** - Cached version doesn't have PostToolUseFailure hook
3. **Auto-return too fast** - The 1.5s flash may be missed

**Check feature toggle:**
```bash
grep "ENABLE_TOOL_ERROR" ~/.tavs/user.conf
# Should be: ENABLE_TOOL_ERROR="true" (default)
```

**Test manually:**
```bash
./src/core/trigger.sh tool_error  # Should flash orange-red, returns after 1.5s
```

### Subagent Counter Issues

Title shows wrong subagent count or count doesn't reset.

**Common causes:**
1. **Stale counter file** - Previous session left counter file in `~/.cache/tavs/`
2. **TTY mismatch** - Counter uses TTY-based file isolation
3. **Aborted prompt** - Counter resets on each new prompt via `new-prompt` flag, but old `/tmp/` files from pre-v1.2.0 may persist

**Solution: Clear stale counter files**
```bash
# Current location (v1.2.0+)
rm -f ~/.cache/tavs/subagent-count.*

# Legacy location (pre-v1.2.0)
rm -f /tmp/tavs-subagent-count-*

./src/core/trigger.sh reset
```

**Note:** Since v1.2.0, the counter automatically resets on each new prompt
(`UserPromptSubmit` passes `new-prompt` flag). Stale counts from aborted
operations (Ctrl+C, ESC) are cleared when the next prompt starts.

**Verify counter works:**
```bash
./src/core/trigger.sh subagent-start  # +1
./src/core/trigger.sh subagent-start  # +2 (title should show +2)
./src/core/trigger.sh subagent-stop   # +1
./src/core/trigger.sh subagent-stop   # 0 (returns to processing)
./src/core/trigger.sh reset
```

### OpenCode Build Issues

TypeScript compilation failing.

**Check:**
```bash
cd src/agents/opencode
npm run build
```

**Solution:**
1. Install dependencies: `npm install`
2. Check Node.js version (requires >=18)
3. Check for TypeScript errors in output

## Debug Mode

Enable detailed logging:

```bash
export DEBUG_ALL=1
./src/core/trigger.sh processing
```

Logs saved to: `~/.claude/hooks/tavs/debug/`

## Still Stuck?

1. Check the [Architecture](../reference/architecture.md) to understand how it works
2. Read agent-specific README files in `src/agents/*/`
3. Open an issue: https://github.com/cstelmach/tavs/issues
