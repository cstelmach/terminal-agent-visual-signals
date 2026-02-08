# Testing

## Overview

Testing terminal visual signals involves verifying OSC escape sequences work correctly in your terminal emulator and that hooks fire at the right times.

## Manual Testing

### Test Individual States

```bash
# From repo root
./src/core/trigger.sh processing     # Orange background
./src/core/trigger.sh permission     # Red background
./src/core/trigger.sh complete       # Green background
./src/core/trigger.sh idle           # Purple background
./src/core/trigger.sh compacting     # Teal background
./src/core/trigger.sh subagent-start # Golden-Yellow background
./src/core/trigger.sh subagent-stop  # Returns to processing
./src/core/trigger.sh tool_error     # Orange-Red (auto-returns after 1.5s)
./src/core/trigger.sh reset          # Reset to default

# Test light mode
FORCE_MODE=light ./src/core/trigger.sh processing
FORCE_MODE=light ./src/core/trigger.sh reset
```

### Test Subagent Counter

```bash
# Simulate multiple subagents spawning
./src/core/trigger.sh subagent-start  # Counter: 1
./src/core/trigger.sh subagent-start  # Counter: 2 (title shows +2)
./src/core/trigger.sh subagent-stop   # Counter: 1 (title shows +1)
./src/core/trigger.sh subagent-stop   # Counter: 0 (returns to processing)

# Verify counter resets on complete
./src/core/trigger.sh subagent-start
./src/core/trigger.sh complete        # Counter resets to 0
./src/core/trigger.sh reset

# Verify counter resets on new prompt (abort recovery)
./src/core/trigger.sh subagent-start   # Counter: 1
./src/core/trigger.sh subagent-start   # Counter: 2
# Simulate abort: no subagent-stop, no complete
./src/core/trigger.sh processing new-prompt  # Counter reset to 0
# Counter file should be removed:
ls ~/.cache/tavs/subagent-count.* 2>/dev/null  # No matches

# Verify PostToolUse does NOT reset counter
./src/core/trigger.sh subagent-start           # Counter: 1
./src/core/trigger.sh processing               # PostToolUse (no flag)
cat ~/.cache/tavs/subagent-count.*             # Should still show 1
./src/core/trigger.sh subagent-stop
./src/core/trigger.sh reset
```

### Test Tool Error Auto-Return

```bash
# Tool error should flash orange-red then return to processing
./src/core/trigger.sh processing
./src/core/trigger.sh tool_error     # Flashes orange-red
sleep 2                               # Wait for auto-return
# Terminal should be back to processing (orange)
./src/core/trigger.sh reset
```

### Test Palette Theming

```bash
# Test with palette enabled (requires 256-color mode)
ENABLE_PALETTE_THEMING=true COLORTERM= ./src/core/trigger.sh processing
ls --color=auto  # Check if ls colors match theme
./src/core/trigger.sh reset

# Test auto mode (should skip in TrueColor)
ENABLE_PALETTE_THEMING=auto COLORTERM=truecolor ./src/core/trigger.sh processing
./src/core/trigger.sh reset

# Test auto mode (should apply when not TrueColor)
ENABLE_PALETTE_THEMING=auto COLORTERM= ./src/core/trigger.sh processing
ls --color=auto
./src/core/trigger.sh reset
```

### Test Session Icons

```bash
# Trigger reset to assign an icon (simulates SessionStart)
./src/core/trigger.sh reset

# Check icon was assigned
cat ~/.cache/tavs/session-icon.*  # Should show an animal emoji

# Check registry
cat ~/.cache/tavs/session-icon-registry  # tty_key=emoji pairs

# Verify icon appears in title
./src/core/trigger.sh processing  # Icon should show in tab title

# Clean up
./src/core/trigger.sh reset
```

### Test Compact Face Mode

```bash
# Test compact mode with semantic theme (emoji eyes in face frame)
TAVS_FACE_MODE=compact TAVS_COMPACT_THEME=semantic ./src/core/trigger.sh processing
# Should show: Ǝ[🟠 🟠]E or similar emoji-eye face

TAVS_FACE_MODE=compact ./src/core/trigger.sh permission   # Ǝ[🔴 🔴]E
TAVS_FACE_MODE=compact ./src/core/trigger.sh complete      # Ǝ[✅ ✅]E
TAVS_FACE_MODE=compact ./src/core/trigger.sh tool_error    # Ǝ[❌ ❌]E
TAVS_FACE_MODE=compact ./src/core/trigger.sh reset

# Test all 4 themes
TAVS_FACE_MODE=compact TAVS_COMPACT_THEME=circles ./src/core/trigger.sh processing  # Ǝ[🟠 🟠]E
TAVS_FACE_MODE=compact TAVS_COMPACT_THEME=squares ./src/core/trigger.sh processing  # Ǝ[🟧 🟧]E
TAVS_FACE_MODE=compact TAVS_COMPACT_THEME=mixed ./src/core/trigger.sh processing    # Ǝ[🟧 🟠]E

# Test subagent count as right eye in compact mode
TAVS_FACE_MODE=compact ./src/core/trigger.sh subagent-start  # Ǝ[🔶 +1]E
TAVS_FACE_MODE=compact ./src/core/trigger.sh subagent-start  # Ǝ[🔶 +2]E
TAVS_FACE_MODE=compact ./src/core/trigger.sh subagent-stop   # Ǝ[🔶 +1]E
TAVS_FACE_MODE=compact ./src/core/trigger.sh subagent-stop
./src/core/trigger.sh reset

# Test other agent frames in compact mode
TAVS_FACE_MODE=compact TAVS_AGENT=gemini ./src/core/trigger.sh processing   # ʕ🟠ᴥ🟠ʔ
TAVS_FACE_MODE=compact TAVS_AGENT=codex ./src/core/trigger.sh processing    # ฅ^🟠ﻌ🟠^ฅ

# Standard mode still works
TAVS_FACE_MODE=standard ./src/core/trigger.sh processing     # Ǝ[• •]E 🟠
./src/core/trigger.sh reset
```

### Test Terminal Title Mode

```bash
# Test with TAVS title mode (requires disabling Claude Code's title)
TAVS_TITLE_MODE=full ./src/core/trigger.sh processing
sleep 3  # Watch spinner animation
./src/core/trigger.sh reset

# Test skip-processing mode (default)
TAVS_TITLE_MODE=skip-processing ./src/core/trigger.sh processing
./src/core/trigger.sh reset
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
- [ ] Palette theming applies to ls/git (when enabled)
- [ ] Title mode respects TAVS_TITLE_MODE setting
- [ ] Spinner animation works (when TAVS_TITLE_MODE=full)
- [ ] Subagent state shows golden-yellow background
- [ ] Subagent counter increments/decrements correctly
- [ ] Subagent title shows "+N" count via {AGENTS} token
- [ ] Subagent counter resets on complete
- [ ] Subagent counter resets on new prompt (abort recovery)
- [ ] PostToolUse does not reset subagent counter mid-prompt
- [ ] Compact face mode shows emoji eyes in agent frame
- [ ] Compact mode suppresses separate {EMOJI} and {AGENTS} tokens
- [ ] Compact mode subagent count appears as right eye (+N)
- [ ] Tool error shows orange-red flash
- [ ] Tool error auto-returns to processing after 1.5s
- [ ] Session icon assigned on reset (animal emoji in `~/.cache/tavs/`)
- [ ] Session icon appears in tab title via `{ICON}` token
- [ ] Concurrent sessions get unique icons (registry dedup)

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

### Subagent Lifecycle

Trigger a prompt that spawns Task tool subagents:
- Background should turn golden-yellow
- Title should show subagent face (e.g., `Ǝ[⇆ ⇆]E`) and `+N` count
- As subagents complete, count decrements
- When all complete, returns to processing (orange)

### Tool Error Flash

Trigger a tool that fails:
- Background should flash orange-red briefly
- Title should show error face (e.g., `Ǝ[✕ ✕]E`) and ❌ emoji
- After 1.5s, should auto-return to processing or subagent state

### Session Icons

Verify icon persistence and uniqueness:
- Reset assigns a unique animal emoji per terminal tab
- Icon persists across `/clear` (tied to TTY device)
- Opening a second terminal tab gets a different icon
- Closing a tab frees the icon for reuse (stale cleanup)
- Icon shows in tab title between `{AGENTS}` and `{BASE}` tokens

### Session Reset

End and start new session:
- Background should reset to default
- No lingering state from previous session
- Subagent counter should be reset to 0
- Session icon should be assigned (if `ENABLE_SESSION_ICONS=true`)

## Terminal-Specific Tests

### Ghostty (Recommended)

- OSC 4 (palette): ✅
- OSC 11 (background): ✅
- OSC 0 (title): ✅
- Bell notifications: ✅

### iTerm2

- OSC 4: ✅
- OSC 11: ✅
- OSC 0: ✅
- OSC 1337 (images): ✅
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
