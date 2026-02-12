# TAVS Setup — Lessons Learned

Common issues encountered during configuration and their solutions.

## Terminal Issues

### Terminal.app: No background color changes
**Problem:** macOS Terminal.app doesn't support OSC 11 or OSC 4. Background
colors and palette theming won't work.
**Solution:** Switch to Ghostty, iTerm2, Kitty, or WezTerm. TAVS title features
still work in Terminal.app.

### Ghostty: Titles get overwritten after every command
**Problem:** Ghostty's shell integration manages titles, overwriting TAVS titles.
**Solution:** Add `shell-integration-features = no-title` to Ghostty config:
- macOS: `~/Library/Application Support/com.mitchellh.ghostty/config`
- Linux: `~/.config/ghostty/config`

### iTerm2: Background images not showing
**Problem:** OSC 1337 background commands silently ignored.
**Solution:** Enable in iTerm2 > Preferences > Profiles > Window > Background Image.
The checkbox must be enabled even if no default image is set.

## Theme & Color Issues

### Palette theming has no visible effect
**Problem:** Claude Code uses TrueColor by default (`COLORTERM=truecolor`),
which bypasses the 16-color ANSI palette entirely.
**Solution:** Launch Claude Code in 256-color mode:
```bash
TERM=xterm-256color COLORTERM= claude
```
Or add an alias to your shell profile.

### `tavs set theme` changes two variables
**Problem:** User expected `tavs set theme nord` to only set the theme name,
but existing color settings seem overridden.
**Explanation:** `theme` is a compound alias. It sets both `THEME_PRESET="nord"`
and `THEME_MODE="preset"`. This is intentional — the preset mode tells TAVS
to use the named theme's color definitions.

## Title Issues

### Claude Code's spinner conflicts with TAVS titles
**Problem:** Both TAVS and Claude Code try to set processing titles.
**Solution:** Use the default title-mode (`skip-processing`) which lets Claude
handle processing titles. Or for full TAVS control:
1. Set `TAVS_TITLE_MODE="full"`
2. Add `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` to `~/.claude/settings.json` env

### Session icons not appearing
**Problem:** `{SESSION_ICON}` token produces nothing in titles.
**Solution:** Check that `ENABLE_SESSION_ICONS="true"` (it is by default).
If still missing, ensure the `{SESSION_ICON}` token is in your title format.

## Configuration Issues

### Changes not taking effect in Claude Code
**Problem:** Edited `~/.tavs/user.conf` but signals haven't changed.
**Explanation:** User config changes take effect on the next hook trigger.
Submit a new prompt to see the change. If using the plugin, make sure
the plugin cache is synced: `./tavs sync`

### Unknown setting name error
**Problem:** `tavs set` rejects a setting name.
**Solution:** Use the friendly alias names (e.g., `faces` not
`ENABLE_ANTHROPOMORPHISING`). Run `tavs set` with no arguments to see
all available aliases.
