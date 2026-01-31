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
    "terminal-visual-signals@terminal-visual-signals": true
  }
}
```

### Hooks Not Installed

Hooks may not be in settings file.

**Check Claude Code:**
```bash
grep -A5 "terminal-visual-signals" ~/.claude/settings.json
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
CACHE_DIR="$HOME/.claude/plugins/cache/terminal-visual-signals/terminal-visual-signals/*/src"
cp src/core/agent-theme.sh "$CACHE_DIR/core/"
cp src/agents/claude/data/faces.conf "$CACHE_DIR/agents/claude/data/"
```

**Solution 2: Check for user overrides**
```bash
# Check if user override exists
ls ~/.terminal-visual-signals/agents/claude/faces.conf
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
# In ~/.terminal-visual-signals/user.conf
ENABLE_PALETTE_THEMING="auto"  # or "true"
```

**Test if working:**
```bash
ENABLE_PALETTE_THEMING=true COLORTERM= ./src/core/trigger.sh processing
ls --color=auto  # Colors should match theme
./src/core/trigger.sh reset
```

See [Palette Theming Reference](../reference/palette-theming.md) for details.

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

Logs saved to: `~/.claude/hooks/terminal-agent-visual-signals/debug/`

## Still Stuck?

1. Check the [Architecture](../reference/architecture.md) to understand how it works
2. Read agent-specific README files in `src/agents/*/`
3. Open an issue: https://github.com/cstelmach/terminal-agent-visual-signals/issues
