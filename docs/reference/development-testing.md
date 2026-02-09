# Development Testing Workflow

## Overview

When developing TAVS, changes need to be deployed to the plugin cache before they take effect in Claude Code. This document provides the workflow for testing changes live.

## Quick Reference

### Update Plugin Cache (One-Liner)

```bash
# Copy all core files from repo to plugin cache
CACHE="$HOME/.claude/plugins/cache/terminal-agent-visual-signals/tavs/2.0.0"
cp src/core/*.sh "$CACHE/src/core/" && cp src/config/*.conf "$CACHE/src/config/" 2>/dev/null; echo "Cache updated"
```

### Test Immediately

```bash
# Trigger a visual state to see your changes
./src/core/trigger.sh processing   # See processing state
./src/core/trigger.sh complete     # See complete state
./src/core/trigger.sh reset        # Reset to default
```

## Full Development Workflow

### 1. Make Changes in Repository

Edit files in `/Users/cs/.claude/hooks/terminal-agent-visual-signals/`:

| Change Type | Files to Edit |
|-------------|---------------|
| Colors | `src/config/defaults.conf`, `src/core/theme-config-loader.sh` |
| Faces | `src/config/defaults.conf` (search `FACES_`), `src/core/face-selection.sh` |
| Behavior | `src/core/trigger.sh`, `src/core/theme-config-loader.sh` |
| Titles | `src/core/title-management.sh`, `src/core/spinner.sh` |
| Session icons | `src/core/session-icon.sh` |
| Idle timer | `src/core/idle-worker-background.sh` |
| Backgrounds | `src/core/backgrounds.sh` |
| Terminal OSC | `src/core/terminal-osc-sequences.sh` |
| Subagents | `src/core/subagent-counter.sh` |

### 2. Test Locally First

```bash
# Test from repo directory (doesn't require cache update)
./src/core/trigger.sh processing
sleep 2
./src/core/trigger.sh reset

# Test specific theme loading
bash -c 'source src/core/theme-config-loader.sh && load_agent_config claude && echo "COLOR_PROCESSING=$COLOR_PROCESSING"'
```

### 3. Update Plugin Cache

The plugin cache is where Claude Code actually loads the code from:

```bash
CACHE_BASE="$HOME/.claude/plugins/cache/terminal-agent-visual-signals/tavs/2.0.0"
REPO_BASE="/Users/cs/.claude/hooks/terminal-agent-visual-signals"

# All core files (recommended — ensures consistency)
cp "$REPO_BASE/src/core/"*.sh "$CACHE_BASE/src/core/"

# Config files
mkdir -p "$CACHE_BASE/src/config"
cp "$REPO_BASE/src/config/defaults.conf" "$CACHE_BASE/src/config/"

# Agent adapters (if modified)
cp "$REPO_BASE/src/agents/claude/trigger.sh" "$CACHE_BASE/src/agents/claude/"
```

### 4. Test in Claude Code

After updating the cache, the next prompt you submit will use the new code.

**Quick test:** Just submit any prompt and observe the visual signals.

### 5. User Config Location

User settings are in `~/.tavs/user.conf`. Changes here take effect immediately (no cache update needed).

## File Locations Summary

| Purpose | Location |
|---------|----------|
| Source repo | `/Users/cs/.claude/hooks/terminal-agent-visual-signals/` |
| Plugin cache | `~/.claude/plugins/cache/terminal-agent-visual-signals/tavs/2.0.0/` |
| User config | `~/.tavs/user.conf` |
| Debug logs | `~/.claude/hooks/terminal-agent-visual-signals/debug/` |

## Common Tasks

### Change a Color

1. Edit `src/config/defaults.conf` (find `DARK_PROCESSING` or similar)
2. Copy to cache: `cp src/config/defaults.conf ~/.claude/plugins/cache/terminal-agent-visual-signals/tavs/2.0.0/src/config/`
3. Submit a prompt to see the change

### Change Behavior Logic

1. Edit `src/core/theme-config-loader.sh` or `src/core/trigger.sh`
2. Copy to cache: `cp src/core/*.sh ~/.claude/plugins/cache/terminal-agent-visual-signals/tavs/2.0.0/src/core/`
3. Submit a prompt to see the change

### Debug Issues

```bash
# Enable debug logging
export DEBUG_ALL=1
./src/core/trigger.sh processing

# Check logs
ls -la ~/.claude/hooks/terminal-agent-visual-signals/debug/
```

## Troubleshooting

### Changes Not Appearing

1. **Verify cache was updated:**
   ```bash
   ls -la ~/.claude/plugins/cache/terminal-agent-visual-signals/tavs/2.0.0/src/core/trigger.sh
   # Should show recent timestamp
   ```

2. **Check for syntax errors:**
   ```bash
   bash -n src/core/trigger.sh  # Syntax check only
   ```

3. **Source and test manually:**
   ```bash
   bash -c 'source src/core/theme-config-loader.sh && echo "Loaded OK"'
   ```

### Wrong Colors Showing

1. Check user config override: `cat ~/.tavs/user.conf`
2. Check which agent is being used: `echo $TAVS_AGENT`
3. Verify color variables: `bash -c 'source src/core/theme-config-loader.sh && load_agent_config claude && echo "COLOR_PROCESSING=$COLOR_PROCESSING"'`

## Related

- [Architecture](architecture.md) - How the system works
- [Testing](testing.md) - Full testing procedures
- [Troubleshooting](../troubleshooting/overview.md) - Common issues
