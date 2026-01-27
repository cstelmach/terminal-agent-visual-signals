# Testing

## Overview

Testing terminal visual signals involves verifying OSC escape sequences work correctly in your terminal emulator and that hooks fire at the right times.

## Manual Testing

### Test Individual States

```bash
# From repo root
./src/core/trigger.sh processing   # Orange background
./src/core/trigger.sh permission   # Red background
./src/core/trigger.sh complete     # Green background
./src/core/trigger.sh idle         # Purple background
./src/core/trigger.sh compacting   # Teal background
./src/core/trigger.sh reset        # Reset to default
```

### Test Agent Triggers

```bash
# Claude Code adapter
./src/agents/claude/trigger.sh processing

# Gemini CLI adapter
./src/agents/gemini/trigger.sh processing

# Codex CLI adapter
./src/agents/codex/trigger.sh complete

# OpenCode adapter
./src/agents/opencode/trigger.sh processing
```

### Test Terminal Compatibility

```bash
./test-terminal.sh
```

This script tests:
- OSC 11 (background color change)
- OSC 0 (title change)
- Bell notification

## Testing Hooks

### Claude Code

1. Remove visual signals from settings (if manually added)
2. Enable plugin: `/plugin` → select terminal-visual-signals
3. Restart Claude Code
4. Submit a prompt → verify orange background
5. Wait for response → verify green background
6. Wait 30+ seconds → verify purple idle stages

### Gemini CLI

1. Run `./install-gemini.sh`
2. Start new Gemini session
3. Submit prompt → verify processing signal
4. Get response → verify complete signal

### Codex CLI

1. Run `./install-codex.sh`
2. Start new Codex session
3. Get response → verify complete signal (only supported state)

### OpenCode

1. Build plugin: `cd src/agents/opencode && npm run build`
2. Install: `npm link` or add to config
3. Start OpenCode session → verify reset
4. Submit prompt → verify processing
5. Get response → verify complete

## Debug Mode

Enable debug logging:

```bash
export DEBUG_ALL=1
./src/core/trigger.sh processing
# Check ~/.claude/hooks/terminal-agent-visual-signals/debug/ for logs
```

## Verification Checklist

- [ ] Background color changes visibly
- [ ] Tab title updates with emoji/face
- [ ] Idle timer starts after completion
- [ ] Idle stages graduate correctly
- [ ] New prompt cancels idle timer
- [ ] Reset clears all visual state

## Common Test Scenarios

### Rapid Tool Execution

Submit a prompt that triggers multiple tools:
- Background should stay orange throughout
- No flicker between tools
- Green only after final response

### Permission Interruption

Trigger a permission request:
- Background should turn red
- Should stay red until approved/denied
- Returns to processing after

### Idle Timer

Wait after completion:
- 30s: First idle stage (light purple)
- 60s: Second idle stage
- Continue through all 6 stages
- New prompt resets to processing

### Session Reset

End and start new session:
- Background should reset to default
- No lingering state from previous session

## Terminal-Specific Tests

### Ghostty (Recommended)

- Full OSC 11 support ✅
- Full OSC 0 support ✅
- Bell notifications ✅

### iTerm2

- OSC 11: ✅
- OSC 0: ✅
- May need "Apps can change title" enabled

### VS Code Terminal

- OSC 11: ❌ (no background support)
- OSC 0: ✅ (title works)
- Test with title-only mode

### Windows Terminal

- OSC 11: ✅
- OSC 0: ✅
- Works well on Windows

## Related

- [Architecture](architecture.md) - How the system works
- [Troubleshooting](../troubleshooting/overview.md) - When tests fail
