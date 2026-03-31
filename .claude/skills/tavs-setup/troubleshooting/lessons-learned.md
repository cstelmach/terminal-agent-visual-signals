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

## Configuration Change Issues

### Raw variable not taking effect
**Problem:** Set a custom color variable (e.g., `CLAUDE_DARK_PROCESSING`) in
`user.conf`, but the color doesn't change.
**Solution:** When `THEME_MODE="preset"`, the preset's colors override custom
colors in `user.conf`. Either switch to `THEME_MODE="static"` to use your custom
colors directly, or use per-agent overrides which have higher priority than theme
defaults (e.g., `CLAUDE_DARK_PROCESSING` overrides `DEFAULT_DARK_PROCESSING`).

### Backup directory doesn't exist
**Problem:** First backup attempt fails with a directory error.
**Solution:** The backup workflow should auto-create `~/.tavs/backups/` with
`mkdir -p`. If it fails, check directory permissions on `~/.tavs/` — the user
must have write access.

### Profile apply has unexpected results
**Problem:** After applying a profile, settings not in the profile seem different.
**Solution:** Profiles are additive — they only change the settings they contain.
They don't remove other settings. If a clean slate is needed, reset to defaults
first (`./tavs config reset`), then apply the profile.

### Array syntax errors in user.conf
**Problem:** Edited face arrays in `user.conf` but get shell errors.
**Solution:** Bash arrays require specific syntax: `('item1' 'item2')`. Common
mistakes: using JSON syntax `["item1", "item2"]`, adding spaces around `=`, or
forgetting quotes around face strings containing special characters.

### Commented vs uncommented variables confused
**Problem:** Uncommented a variable but it still uses the default value.
**Solution:** Ensure both the `#` AND any leading space are removed. Watch for
double-commented lines like `## Section Header` — those are section dividers,
not settings. A setting line looks like `# VARIABLE="value"` (single `#`).
