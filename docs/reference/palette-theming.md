# Palette Theming

## Overview

TAVS can optionally modify the terminal's 16-color ANSI palette (OSC 4) for cohesive light/dark mode theming. This affects shell prompts, `ls` colors, `git status`, and any application using ANSI palette indices.

**Key point:** This is separate from background colors (OSC 11). Palette theming changes how text colors appear, while background theming changes the terminal background.

## How It Works

### OSC 4 vs TrueColor

| Color Mode | How Colors Work | Palette Affected? |
|------------|-----------------|-------------------|
| 16/256-color | Uses palette indices (0-15 ANSI, 16-255 extended) | Yes |
| TrueColor (24-bit) | Direct RGB values `\033[38;2;R;G;Bm` | No |

**Claude Code uses TrueColor by default** (`COLORTERM=truecolor`), which bypasses the palette entirely. To see palette theming effects in Claude Code, you must launch it in 256-color mode.

### Enabling Palette Theming

Add to `~/.tavs/user.conf`:

```bash
ENABLE_PALETTE_THEMING="auto"  # or "true"
```

**Options:**
- `"false"` (default) - No palette changes, background colors only
- `"auto"` - Apply palette only when NOT in TrueColor mode
- `"true"` - Always apply palette (affects shell tools like `ls`, `git`)

### For Claude Code Users

To enable palette theming for Claude Code:

```bash
# Launch with 256-color mode
TERM=xterm-256color COLORTERM= claude

# Or add alias to your shell profile (.zshrc/.bashrc)
alias claude='TERM=xterm-256color COLORTERM= claude'
```

The `configure.sh` wizard (Step 7) can create this alias for you.

## Theme Presets

All built-in theme presets include matching 16-color palettes:

| Theme | Dark Palette | Light Palette |
|-------|--------------|---------------|
| Catppuccin Frappé | Frappé colors | Latte colors |
| Catppuccin Latte | Frappé fallback | Latte colors |
| Catppuccin Macchiato | Macchiato colors | Latte colors |
| Catppuccin Mocha | Mocha colors (darkest) | Latte colors |
| Nord | Polar Night | Snow Storm |
| Dracula | Dracula dark | Light variant |
| Solarized Dark | Solarized base03 | Solarized base3 |
| Solarized Light | Solarized base03 fallback | Solarized base3 |
| Tokyo Night | Storm colors | Day colors |

Select via `configure.sh` or set `THEME_PRESET` in user.conf.

## ANSI Color Indices

The 16-color palette uses indices 0-15:

| Index | Name | Typical Use |
|-------|------|-------------|
| 0 | Black | Background |
| 1 | Red | Errors |
| 2 | Green | Success, git additions |
| 3 | Yellow | Warnings |
| 4 | Blue | Directories |
| 5 | Magenta | Special files |
| 6 | Cyan | Symlinks |
| 7 | White | Primary text |
| 8-15 | Bright variants | Bold/bright versions |

## Configuration Variables

### Global Defaults (defaults.conf)

```bash
# Enable palette theming
ENABLE_PALETTE_THEMING="false"

# Dark mode palette
PALETTE_DARK_0="#303446"     # Black (Base)
PALETTE_DARK_1="#e78284"     # Red
# ... through PALETTE_DARK_15

# Light mode palette
PALETTE_LIGHT_0="#eff1f5"    # Black (Base)
PALETTE_LIGHT_1="#d20f39"    # Red
# ... through PALETTE_LIGHT_15
```

### Per-Theme Overrides

Theme presets in `src/themes/*.conf` can define their own palettes:

```bash
# Example: src/themes/nord.conf
PALETTE_DARK_0="#2e3440"     # Nord Polar Night
PALETTE_DARK_1="#bf616a"     # Nord Red
# ...
```

## Technical Details

### Application Order

When a state change occurs:

1. **Palette applied FIRST** (if enabled) - prevents contrast flicker
2. **Background color applied** - OSC 11
3. **Title updated** - OSC 0

### Mode Detection

```bash
# In detect.sh
is_truecolor_mode() {
    [[ "$COLORTERM" == "truecolor" ]] || [[ "$COLORTERM" == "24bit" ]]
}

should_enable_palette_theming() {
    [[ "$ENABLE_PALETTE_THEMING" == "false" ]] && return 1
    [[ "$ENABLE_PALETTE_THEMING" == "true" ]] && return 0
    # auto mode: enable if NOT truecolor
    ! is_truecolor_mode
}
```

### Palette Mode Selection

The palette mode (dark/light) follows the same logic as background colors:

1. Respect explicit `FORCE_MODE` ("dark" or "light")
2. Use `IS_DARK_THEME` from theme.sh (if available)
3. Use system detection if `ENABLE_LIGHT_DARK_SWITCHING="true"`
4. Fall back to dark mode

### OSC Sequences

```bash
# Set palette color (OSC 4)
# Format: ESC ] 4 ; index ; rgb:RR/GG/BB ST
printf "\033]4;1;rgb:e7/82/84\033\\"

# Reset palette to defaults (OSC 104)
printf "\033]104\033\\"
```

## Terminal Support

| Terminal | OSC 4 Support | Notes |
|----------|---------------|-------|
| Ghostty | ✅ | Full support |
| iTerm2 | ✅ | Full support |
| Kitty | ✅ | Full support |
| WezTerm | ✅ | Full support |
| Terminal.app | ❌ | No OSC support |
| VS Code Terminal | ❌ | No OSC 4 support |

## Troubleshooting

### Colors Not Changing

1. **Check if TrueColor is active:**
   ```bash
   echo $COLORTERM  # "truecolor" means palette won't work
   ```

2. **Verify palette theming is enabled:**
   ```bash
   bash src/core/terminal-detection.sh test  # Shows "Palette Theming" status
   ```

3. **Force enable for testing:**
   ```bash
   ENABLE_PALETTE_THEMING=true COLORTERM= ./src/core/trigger.sh processing
   ls --color=auto  # Should show themed colors
   ```

### Palette Persists After Reset

The `reset` state calls `send_osc_palette_reset()` (OSC 104) to restore terminal defaults. If colors persist:

1. Restart your terminal
2. Check for other tools modifying palette
3. Verify reset is being called: `DEBUG_ALL=1 ./src/core/trigger.sh reset`

### Contrast Issues

If text becomes unreadable:

1. Check that dark/light mode matches your terminal background
2. Try explicit mode: `FORCE_MODE=dark ./src/core/trigger.sh processing`
3. Disable palette theming: `ENABLE_PALETTE_THEMING="false"`

## Related

- [Architecture](architecture.md) - How palette theming fits in the system
- [Agent Themes](agent-themes.md) - Per-agent color customization
- [Testing](testing.md) - How to test palette theming
