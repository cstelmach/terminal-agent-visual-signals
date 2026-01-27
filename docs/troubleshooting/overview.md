# Troubleshooting Overview

Quick reference for common issues with Terminal Agent Visual Signals.

## Issue Index

| Problem | Symptoms | Solution |
|---------|----------|----------|
| No visual changes | Terminal stays default color | [Check terminal compatibility](#terminal-not-supported) |
| Plugin shows disabled | CLI says disabled but settings say true | [Local settings override](#local-settings-override) |
| Hooks not firing | No color change on prompt submit | [Verify hook installation](#hooks-not-installed) |
| Wrong colors | Colors different than expected | [Theme configuration](#wrong-theme) |
| Idle timer not working | No purple stages after completion | [Check idle-worker](#idle-timer-issues) |
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
