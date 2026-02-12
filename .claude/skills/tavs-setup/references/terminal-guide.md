# Terminal-Specific Guide

How TAVS detects terminals and what to recommend for each.

## Detection Methods

| Terminal | Detection | Env Variable |
|----------|-----------|-------------|
| Ghostty | `$TERM_PROGRAM=ghostty` or `$GHOSTTY_RESOURCES_DIR` set | `GHOSTTY_RESOURCES_DIR` |
| iTerm2 | `$TERM_PROGRAM=iTerm.app` or `$ITERM_SESSION_ID` set | `ITERM_SESSION_ID` |
| Kitty | `$TERM_PROGRAM=kitty` or `$KITTY_PID` set | `KITTY_PID` |
| WezTerm | `$TERM_PROGRAM=WezTerm` | `TERM_PROGRAM` |
| VS Code | `$TERM_PROGRAM=vscode` or `$VSCODE_GIT_ASKPASS_NODE` set | `TERM_PROGRAM` |
| GNOME Terminal | `$VTE_VERSION` set | `VTE_VERSION` |
| Terminal.app | `$TERM_PROGRAM=Apple_Terminal` | `TERM_PROGRAM` |

## Capability Matrix

| Terminal | OSC 11 (bg color) | OSC 4 (palette) | OSC 1337 (images) | Titles |
|----------|-------------------|-----------------|-------------------|--------|
| Ghostty | Yes | Yes | No | Yes* |
| iTerm2 | Yes | Yes | Yes | Yes |
| Kitty | Yes | Yes | No** | Yes |
| WezTerm | Yes | Yes | Partial | Yes |
| VS Code | Yes | Yes | No | Limited |
| GNOME Terminal | Yes | Yes | No | Yes |
| Terminal.app | **No** | **No** | No | Yes |

\* Ghostty requires config change for titles (see below).
\** Kitty uses its own image protocol.

## Terminal-Specific Recommendations

### Ghostty

**Required for titles:** Add to Ghostty config:

```ini
# macOS: ~/Library/Application Support/com.mitchellh.ghostty/config
# Linux: ~/.config/ghostty/config
shell-integration-features = no-title
```

Without this, Ghostty overwrites TAVS titles after every command. This only
disables title management — cursor shape, sudo wrapping, and other shell
features continue working.

**Recommended setup:**
```bash
tavs set theme nord           # or any theme
tavs set title-mode prefix-only
tavs set faces true
```

### iTerm2

**Best TAVS support** — all features including background images work.

**For background images:** Enable in iTerm2 Preferences > Profiles > Window >
Background Image (can leave path empty). Without this, OSC 1337 background
commands are silently ignored.

**Recommended setup:**
```bash
tavs set theme catppuccin-mocha
tavs set title-mode prefix-only
tavs set backgrounds true       # Optional: background images
```

### Kitty

**Good support** — background images use Kitty's native protocol.

**For background images:** Add `allow_remote_control=yes` to `~/.config/kitty/kitty.conf`.

**Recommended setup:**
```bash
tavs set theme dracula
tavs set title-mode prefix-only
tavs set backgrounds true       # Optional
```

### WezTerm

**Good support** — no special config needed.

**Recommended setup:**
```bash
tavs set theme tokyo-night
tavs set title-mode prefix-only
```

### VS Code Terminal

**Limited title support** — VS Code manages its own terminal titles.
Background colors work normally.

**Recommended setup:**
```bash
tavs set theme nord
tavs set title-mode off         # VS Code handles titles
```

### Terminal.app (macOS)

**Minimal support** — no OSC 11 or OSC 4. Background color changes and
palette theming will NOT work.

**Recommended setup:**
```bash
tavs set title-mode prefix-only  # Titles still work
tavs set faces true              # Faces in titles still work
# Note: Background colors won't change. Consider switching to
# Ghostty, iTerm2, or another modern terminal for full TAVS support.
```

## Dark/Light Mode Detection

TAVS detects system dark/light mode:
- **macOS:** `defaults read -g AppleInterfaceStyle` (returns "Dark" or errors)
- **Linux GNOME:** `gsettings get org.gnome.desktop.interface color-scheme`
- **Linux KDE:** `kreadconfig5 --group General --key ColorScheme`

Enable with `tavs set light-dark true`. Default is false (always dark).

## TrueColor Considerations

Most modern terminals use TrueColor (`COLORTERM=truecolor`). This means:
- Background color changes (OSC 11) work normally
- ANSI palette theming (OSC 4) is bypassed — apps use direct RGB values
- Claude Code uses TrueColor by default

To enable palette theming with Claude Code:
```bash
TERM=xterm-256color COLORTERM= claude
# Or alias:
alias claude='TERM=xterm-256color COLORTERM= claude'
```

## SSH Sessions

Over SSH, TAVS disables by default:
- Dynamic mode terminal queries (may timeout)
- Background images (not forwarded)
- OSC queries (unreliable over slow connections)

Static colors and title changes still work over SSH.
