# OpenCode Integration

## Status: Full Support (TypeScript Plugin)

**Last Updated:** 2026-01-27

Visual terminal state indicators for [OpenCode](https://opencode.ai) sessions using OSC escape sequences.

## Installation

### Option 1: npm (Recommended)

```bash
npm install @terminal-visual-signals/opencode-plugin
```

Add to your `opencode.json` or `~/.opencode/config.json`:

```json
{
  "plugins": ["@terminal-visual-signals/opencode-plugin"]
}
```

### Option 2: Local Installation

```bash
# Clone the repository
git clone https://github.com/cstelmach/terminal-agent-visual-signals.git \
  ~/.opencode/plugins/terminal-visual-signals

# Build the plugin
cd ~/.opencode/plugins/terminal-visual-signals/src/agents/opencode
npm install
npm run build

# Add to config
echo '{"plugins": ["~/.opencode/plugins/terminal-visual-signals/src/agents/opencode"]}' > opencode.json
```

## Supported States

| State | Color | Emoji | Trigger |
|-------|-------|-------|---------|
| Processing | Orange | 🟠 | User prompt, Tool call |
| Complete | Green | 🟢 | Agent response done |
| Idle | Purple (graduated) | 🟣 | 30s after completion |
| Reset | Default | - | Session start/end |

### States NOT Available

| State | Reason |
|-------|--------|
| Permission (🔴) | OpenCode has no permission model |
| Compacting (🔄) | OpenCode may not have context compaction |

## Configuration

### Basic Configuration

```json
{
  "plugins": ["@terminal-visual-signals/opencode-plugin"]
}
```

### Advanced Configuration

Create a custom plugin instance in your project:

```typescript
import { createTerminalVisualSignalsPlugin } from '@terminal-visual-signals/opencode-plugin';

const plugin = createTerminalVisualSignalsPlugin({
  // Idle timeout in milliseconds (default: 30000)
  idleTimeout: 60000,

  // Enable debug logging
  debug: true,

  // Custom trigger script path (auto-detected if not set)
  triggerScript: '/path/to/trigger.sh'
});

export default plugin;
```

## How It Works

1. **Plugin hooks into OpenCode events:**
   - `onSessionStart` → Reset terminal
   - `onUserPrompt` → Processing signal
   - `onToolCall` → Processing signal
   - `onToolResult` → Maintain processing
   - `onAgentResponse` (done=true) → Complete signal
   - `onSessionEnd` → Reset terminal

2. **Signals are sent via the core trigger system:**
   - TypeScript calls bash trigger script
   - Trigger script sends OSC escape sequences
   - Terminal updates background color and title

3. **Idle timer:**
   - Starts 30 seconds after completion
   - Transitions through graduated idle stages
   - Canceled when new prompt submitted

## Terminal Compatibility

Works with terminals that support OSC escape sequences:

| Terminal | Support | Notes |
|----------|---------|-------|
| Ghostty | ✅ Full | Recommended |
| iTerm2 | ✅ Full | macOS |
| Kitty | ✅ Full | Cross-platform |
| WezTerm | ✅ Full | Cross-platform |
| Windows Terminal | ✅ Full | Windows |
| VS Code Terminal | ⚠️ Partial | Title only |
| GNOME Terminal | ⚠️ Partial | May need config |

## Troubleshooting

### Signals not appearing

1. **Check plugin is loaded:**
   ```bash
   # In OpenCode, check loaded plugins
   /plugins
   ```

2. **Enable debug mode:**
   ```json
   {
     "plugins": ["@terminal-visual-signals/opencode-plugin"],
     "terminal-visual-signals": {
       "debug": true
     }
   }
   ```

3. **Verify trigger script exists:**
   ```bash
   ls -la ~/.claude/hooks/terminal-agent-visual-signals/src/core/trigger.sh
   ```

4. **Test trigger script directly:**
   ```bash
   ~/.claude/hooks/terminal-agent-visual-signals/src/agents/opencode/trigger.sh processing
   ~/.claude/hooks/terminal-agent-visual-signals/src/agents/opencode/trigger.sh complete
   ~/.claude/hooks/terminal-agent-visual-signals/src/agents/opencode/trigger.sh reset
   ```

### Terminal not changing color

1. Verify your terminal supports OSC 11 (background color)
2. Try a known-compatible terminal like Ghostty or iTerm2
3. Check if your terminal theme overrides background colors

## Files

| File | Purpose |
|------|---------|
| `package.json` | npm package definition |
| `tsconfig.json` | TypeScript configuration |
| `src/index.ts` | Plugin entry point |
| `src/types.ts` | TypeScript type definitions |
| `src/signal-bridge.ts` | Bridge to core trigger system |
| `trigger.sh` | Bash wrapper to core trigger |
| `README.md` | This documentation |

## Development

```bash
# Install dependencies
npm install

# Build
npm run build

# Watch mode
npm run watch

# Clean
npm run clean
```

## Event Flow

```
User submits prompt
       │
       ▼
onUserPrompt() ──────► Processing (🟠)
       │
       ▼
onToolCall() ────────► Processing (🟠)
       │
       ▼
onToolResult() ──────► Processing (🟠)
       │
       ▼
onAgentResponse(done) ► Complete (🟢)
       │
       ▼
   [30 seconds]
       │
       ▼
Idle timer fires ────► Idle (🟣)
       │
       ▼
   [graduated stages]
```

## License

MIT
