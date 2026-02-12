# TAVS Configuration Options Reference

Complete reference of all `tavs set` aliases. Each alias maps to one or more
config variables in `~/.tavs/user.conf`.

## Setting Aliases

### Core Settings

| Alias | Variable(s) | Valid Values | Default |
|-------|-------------|--------------|---------|
| `theme` | `THEME_PRESET` + `THEME_MODE` | catppuccin-frappe, catppuccin-latte, catppuccin-macchiato, catppuccin-mocha, nord, dracula, solarized-dark, solarized-light, tokyo-night | (none) |
| `mode` | `THEME_MODE` | static, dynamic, preset | static |
| `light-dark` | `ENABLE_LIGHT_DARK_SWITCHING` | true, false | false |
| `force-mode` | `FORCE_MODE` | auto, dark, light | auto |

**Note:** `theme` is a compound alias. Running `tavs set theme nord` sets
`THEME_MODE="preset"` and `THEME_PRESET="nord"` together.

### Visual Features

| Alias | Variable | Valid Values | Default |
|-------|----------|--------------|---------|
| `faces` | `ENABLE_ANTHROPOMORPHISING` | true, false | true |
| `face-mode` | `TAVS_FACE_MODE` | standard, compact | standard |
| `face-position` | `FACE_POSITION` | before, after | before |
| `compact-theme` | `TAVS_COMPACT_THEME` | semantic, circles, squares, mixed | semantic |
| `backgrounds` | `ENABLE_STYLISH_BACKGROUNDS` | true, false | false |
| `palette` | `ENABLE_PALETTE_THEMING` | false, auto, true | false |

### Title System

| Alias | Variable | Valid Values | Default |
|-------|----------|--------------|---------|
| `title-mode` | `TAVS_TITLE_MODE` | skip-processing, prefix-only, full, off | skip-processing |
| `title-fallback` | `TAVS_TITLE_FALLBACK` | path, session-path, path-session, session | path |
| `title-format` | `TAVS_TITLE_FORMAT` | free-form template | `{FACE} {STATUS_ICON} {AGENTS} {SESSION_ICON} {BASE}` |
| `session-icons` | `ENABLE_SESSION_ICONS` | true, false | true |
| `agents-format` | `TAVS_AGENTS_FORMAT` | free-form with `{N}` | `+{N}` |

### Spinner (when title-mode = full)

| Alias | Variable | Valid Values | Default |
|-------|----------|--------------|---------|
| `spinner` | `TAVS_SPINNER_STYLE` | braille, circle, block, eye-animate, none, random | random |
| `eye-mode` | `TAVS_SPINNER_EYE_MODE` | sync, opposite, stagger, clockwise, counter, mirror, mirror_inv, random | random |
| `session-identity` | `TAVS_SESSION_IDENTITY` | true, false | true |

### Advanced

| Alias | Variable | Valid Values | Default |
|-------|----------|--------------|---------|
| `mode-aware` | `ENABLE_MODE_AWARE_PROCESSING` | true, false | true |
| `truecolor-override` | `TRUECOLOR_MODE_OVERRIDE` | off, muted, full | off |
| `bell-permission` | `ENABLE_BELL_PERMISSION` | true, false | true |
| `bell-complete` | `ENABLE_BELL_COMPLETE` | true, false | false |
| `debug` | `DEBUG_ALL` | 0, 1 | 0 |

## Usage Examples

```bash
# Apply a theme preset
tavs set theme nord

# Enable compact face mode with squares
tavs set face-mode compact
tavs set compact-theme squares

# Full title mode with braille spinner
tavs set title-mode full
tavs set spinner braille
tavs set eye-mode opposite

# Custom title format (minimal, no face)
tavs set title-format "{STATUS_ICON} {SESSION_ICON} {BASE}"

# Enable palette theming (auto-detect TrueColor)
tavs set palette auto

# Interactive mode (picker when no value given)
tavs set theme      # Shows theme picker
tavs set spinner    # Shows spinner style picker
```

## Title Format Tokens

| Token | Description | Example |
|-------|-------------|---------|
| `{FACE}` | Agent face expression | `Ǝ[• •]E` |
| `{STATUS_ICON}` | State emoji | `🟠` |
| `{AGENTS}` | Subagent count (empty when 0) | `+2` |
| `{SESSION_ICON}` | Unique animal emoji per tab | `🦊` |
| `{BASE}` | Base title (user-set or fallback) | `~/projects` |

Empty tokens produce double spaces, collapsed by the title compositor.

## Spinner Eye Modes Explained

| Mode | Behavior |
|------|----------|
| `sync` | Both eyes show the same frame |
| `opposite` | Eyes half-cycle apart (left/right half-filled) |
| `stagger` | Left eye leads, right follows (2 frames behind) |
| `clockwise` | Both rotate clockwise (braille only) |
| `counter` | Both rotate counter-clockwise (braille only) |
| `mirror` | Left increases while right decreases |
| `mirror_inv` | Left decreases while right increases |
| `random` | Random selection per session |
