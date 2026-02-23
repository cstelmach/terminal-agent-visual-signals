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

### Test Session Identity

```bash
# Test dual mode (default): session animal + directory flag
TAVS_SESSION_ID=test1234 ./src/core/trigger.sh reset              # Assign session icon
TAVS_SESSION_ID=test1234 TAVS_CWD=/tmp/proj ./src/core/trigger.sh processing new-prompt
# Title should show «flag|animal» format

# Check per-TTY cache (structured KV format)
cat ~/.cache/tavs/session-icon.*   # session_key=..., primary=animal, collision_active=...
cat /tmp/tavs-identity/dir-icon.*  # dir_path=..., main_icon=flag

# Test single mode (session animal only, no dir flag)
TAVS_IDENTITY_MODE=single TAVS_SESSION_ID=test ./src/core/trigger.sh reset
# Title should show animal only, no guillemets

# Test off mode (legacy random)
TAVS_IDENTITY_MODE=off ./src/core/trigger.sh reset
# Title should show random animal, v1 single-emoji format

# Clean up
./src/core/trigger.sh reset session-end
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

### Test Title Presets

```bash
# Test dashboard preset (text face + parenthesized info group)
TAVS_TITLE_PRESET=dashboard ./src/core/trigger.sh processing new-prompt
# Title should show: Ǝ[• •]E˙°(🟠|🧀|🇩🇪|🦊) 0% ~/proj  abc123de
./src/core/trigger.sh permission
# Same format with red status icon
./src/core/trigger.sh reset

# Test compact preset (emoji eyes + guillemet identity)
TAVS_TITLE_PRESET=compact ./src/core/trigger.sh processing new-prompt
# Title should show: Ǝ[🟧 🧀]E «🇩🇪|🦊» ~/proj
TAVS_TITLE_PRESET=compact ./src/core/trigger.sh permission
# Permission format: Ǝ[🟥 🧀]E «🇩🇪|🦊» 🧀0% ~/proj
./src/core/trigger.sh reset

# Switch between presets via CLI
./tavs set title-preset dashboard
./tavs set title-preset compact
```

### Test Reset Face Distinction

```bash
# Session-start reset: standard eyes (inviting)
./src/core/trigger.sh reset
# Should show: Ǝ[• •]E ⚪ (or variant)

# Session-end reset: em dash eyes (muted/closing)
./src/core/trigger.sh reset session-end
# Should show: Ǝ[— —]E ⚪

# Compact mode session-end: em dash (not emoji)
TAVS_FACE_MODE=compact ./src/core/trigger.sh reset session-end
# Should show: Ǝ[— —]E (em dash, not emoji eyes)
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

### Test Per-State Title Formats

```bash
# Test custom permission format with context tokens
TAVS_TITLE_FORMAT_PERMISSION="{FACE} {STATUS_ICON} {CONTEXT_FOOD}{CONTEXT_PCT} {BASE}" \
  ./src/core/trigger.sh permission
# Title should show food emoji + percentage (if bridge data available)
./src/core/trigger.sh reset

# Test fallback chain (no per-state format → falls back to TAVS_TITLE_FORMAT)
unset TAVS_TITLE_FORMAT_PERMISSION
./src/core/trigger.sh permission
# Should use the global TAVS_TITLE_FORMAT
./src/core/trigger.sh reset

# Test agent-specific override
CLAUDE_TITLE_FORMAT_PERMISSION="{FACE} {CONTEXT_FOOD}{CONTEXT_PCT} {MODEL}" \
  ./src/core/trigger.sh permission
./src/core/trigger.sh reset
```

### Test Context Tokens

```bash
# Test with mock bridge data (create state file manually)
STATE_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache}/tavs"
mkdir -p "$STATE_DIR"
TTY_SAFE=$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ' | sed 's|^|/dev/|; s|/|_|g')
cat > "$STATE_DIR/context.$TTY_SAFE" << EOF
pct=50
model=Opus
cost=1.23
duration=300000
lines_add=42
lines_rem=7
ts=$(date +%s)
EOF

# Now trigger with per-state format that uses context tokens
TAVS_TITLE_FORMAT_PERMISSION="{FACE} {CONTEXT_FOOD}{CONTEXT_PCT} {MODEL}" \
  ./src/core/trigger.sh permission
# Should show: Ǝ[° °]E 🧀50% Opus
./src/core/trigger.sh reset

# Clean up mock data
rm "$STATE_DIR/context.$TTY_SAFE"
```

### Test StatusLine Bridge

```bash
# Bridge should produce zero stdout
output=$(echo '{"context_window":{"used_percentage":72},"model":{"display_name":"Opus"},"cost":{"total_cost_usd":1.23,"total_duration_ms":300000,"total_lines_added":42,"total_lines_removed":7}}' \
  | ./src/agents/claude/statusline-bridge.sh)
[[ -z "$output" ]] && echo "PASS: bridge is silent" || echo "FAIL: produced output"

# Verify state file was written
cat ~/.cache/tavs/context.* 2>/dev/null
# Should show: pct=72, model=Opus, cost=1.23, ts=...

# Test with missing fields (graceful handling)
echo '{"context_window":{}}' | ./src/agents/claude/statusline-bridge.sh
# Should write state file with empty values, not crash
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
2. Enable plugin: `/plugin` → select tavs
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
- [ ] Compact mode suppresses separate {STATUS_ICON} and {AGENTS} tokens
- [ ] Compact mode subagent count appears as right eye (+N)
- [ ] Tool error shows orange-red flash
- [ ] Tool error auto-returns to processing after 1.5s
- [ ] Session icon assigned deterministically on reset (same session_id → same animal)
- [ ] Dir icon assigned on first new-prompt (same cwd → same flag, dual mode only)
- [ ] Session icon appears in tab title via `{SESSION_ICON}` token
- [ ] Dual mode shows `«flag|animal»` guillemet format
- [ ] Concurrent sessions get unique icons (round-robin, 2-icon collision overflow)
- [ ] `TAVS_IDENTITY_MODE=off` preserves exact legacy random behavior
- [ ] Per-state format applies for permission (food emoji + percentage)
- [ ] Per-state format applies for compacting (percentage only)
- [ ] Per-state format falls back to TAVS_TITLE_FORMAT when not set
- [ ] StatusLine bridge produces zero stdout
- [ ] Bridge writes state file to `~/.cache/tavs/context.{TTY_SAFE}`
- [ ] Context tokens default to 0% when no data available (not empty)
- [ ] Transcript fallback estimates percentage from JSONL tokens
- [ ] Title preset "dashboard" applies text face + parenthesized info group
- [ ] Title preset "compact" applies emoji eyes + guillemet identity
- [ ] Preset switch via `./tavs set title-preset` updates user.conf correctly
- [ ] Session-start reset shows standard face eyes (e.g., `Ǝ[• •]E`)
- [ ] Session-end reset shows em dash face eyes (`Ǝ[— —]E`)
- [ ] Reset state shows ⚪ status icon
- [ ] Dir icon visible across all states (not just processing new-prompt)

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

### Session Identity

Verify deterministic identity and uniqueness:
- Reset assigns a deterministic animal emoji per session_id (same session → same animal)
- First new-prompt assigns a deterministic flag per working directory (dual mode)
- Icon persists across `/clear` (tied to session_id, not TTY device)
- Opening a second terminal tab gets a different animal (round-robin)
- Closing a tab frees the icon for reuse (active-sessions cleanup)
- Dual mode shows `«flag|animal»` in tab title; single mode shows animal only
- Two sessions with same animal show 2-icon pair (collision overflow)
- Git worktrees show `main_flag→worktree_flag` format

### Session Reset

End and start new session:
- Background should reset to default
- No lingering state from previous session
- Subagent counter should be reset to 0
- Session icon should be assigned (if `TAVS_IDENTITY_MODE` != `off`)
- SessionEnd (`reset session-end`) releases both session and dir icons

## Terminal Compatibility

| Terminal | OSC 4 (palette) | OSC 11 (bg) | OSC 1337 (images) | Title Detection |
|----------|-----------------|-------------|-------------------|-----------------|
| Ghostty | ✅ | ✅ | ❌ | State file* |
| iTerm2 | ✅ | ✅ | ✅ | OSC 1337 query |
| Kitty | ✅ | ✅ | ❌** | State file |
| WezTerm | ✅ | ✅ | ❌*** | State file |
| Terminal.app | ❌ | ❌ | ❌ | State file |
| VS Code | ❌ | ❌ | ❌ | State file |

\* Ghostty requires `shell-integration-features = no-title` (see below).
\** Kitty uses its own image protocol, not OSC 1337.
\*** WezTerm has partial OSC 1337 support, but TAVS only uses OSC 1337 backgrounds on iTerm2.

**Note:** OSC 4 palette theming only affects applications using ANSI palette indices.
Claude Code uses TrueColor (24-bit RGB) by default, which bypasses the palette.

### Ghostty Shell Integration (Required for Titles)

Ghostty's shell integration automatically manages tab titles, which conflicts with TAVS.
**For TAVS title features to work**, disable Ghostty's title management:

```ini
# macOS: ~/Library/Application Support/com.mitchellh.ghostty/config
# Linux: ~/.config/ghostty/config

shell-integration-features = no-title
```

This disables ONLY title management while keeping cursor shape integration, sudo
wrapping, and other modern shell features.

**Without this setting:** Ghostty will overwrite TAVS titles after every command.

### iTerm2

- May need "Apps can change title" enabled in preferences
- Background images require enabling "Background Image" in profile → Window

### VS Code Terminal

- No background color support (OSC 11)
- Title works (OSC 0)
- Test with title-only mode

## Automated Test Suites

The `tests/` directory contains automated test suites (bash scripts, no framework):

| Suite | Tests | What It Covers |
|-------|-------|----------------|
| `tests/test-context-data.sh` | 107 | Context token resolvers, icon lookups, bar generation, edge cases |
| `tests/test-title-formats.sh` | 50 | Per-state format selection, 4-level fallback chain, token substitution |
| `tests/test-bridge.sh` | 47 | StatusLine bridge silence, atomic writes, JSON extraction |
| `tests/test-transcript-fallback.sh` | 45 | Transcript estimation, JSONL parsing, per-agent window sizes |
| `tests/test-integration.sh` | 94 | End-to-end: trigger → title output with context data |

```bash
# Run all test suites
for t in tests/test-*.sh; do bash "$t"; done

# Run a specific suite
bash tests/test-context-data.sh

# Run with verbose output
DEBUG=1 bash tests/test-context-data.sh
```

## Related

- [Dynamic Titles](dynamic-titles.md) - Per-state title formats and context tokens
- [Architecture](architecture.md) - How the system works
- [Troubleshooting](../troubleshooting/overview.md) - When tests fail
