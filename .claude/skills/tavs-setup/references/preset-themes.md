# TAVS Preset Themes

All 9 available theme presets. Apply with `tavs set theme <name>`.

## Theme List

### Catppuccin Variants

**Catppuccin Frappe** — `catppuccin-frappe`
Mid-tone pastel dark theme. The default TAVS palette is based on Frappe.
Good balance of contrast and comfort.
- Dark base: `#303446` (Frappe Base)
- Light base: `#eff1f5` (Latte Base)
- Best for: Users who want the default look with a named theme

**Catppuccin Latte** — `catppuccin-latte`
Warm pastel light theme. Catppuccin's official light variant.
- Dark base: `#303446` (falls back to Frappe)
- Light base: `#eff1f5` (Latte Base)
- Best for: Light mode users, bright environments

**Catppuccin Macchiato** — `catppuccin-macchiato`
Slightly warmer than Frappe, between Frappe and Mocha.
- Dark base: `#24273A` (Macchiato Base)
- Best for: Users who find Frappe too cool, Mocha too warm

**Catppuccin Mocha** — `catppuccin-mocha`
Warmest Catppuccin variant. Rich, deep tones.
- Dark base: `#1E1E2E` (Mocha Base)
- Best for: OLED screens, deep dark preference, very popular

### Nordic

**Nord** — `nord`
Arctic, bluish color palette from nordtheme.com. Clean and uncluttered.
Uses Nord Aurora colors (muted) for state signals.
- Dark base: `#2E3440` (Polar Night)
- Light base: `#ECEFF4` (Snow Storm)
- Best for: Cool-toned terminals, minimal aesthetic, long coding sessions

### Gothic

**Dracula** — `dracula`
Dark theme with vibrant, high-contrast colors. Bold and distinctive.
- Dark base: `#282A36` (Dracula Background)
- Light base: `#F8F8F2` (Dracula Foreground area)
- Best for: High contrast preference, dark terminal enthusiasts

### Precision

**Solarized Dark** — `solarized-dark`
Ethan Schoonover's precision-engineered color palette. LAB-based color
values for balanced contrast across all states.
- Dark base: `#002B36` (Solarized Base03)
- Best for: Long coding sessions, eye strain reduction

**Solarized Light** — `solarized-light`
Light variant of Solarized with the same LAB precision.
- Light base: `#FDF6E3` (Solarized Base3)
- Best for: Bright environments, users who prefer light themes

### Modern

**Tokyo Night** — `tokyo-night`
Inspired by Tokyo city lights at night. Modern aesthetic with
carefully selected blue-purple undertones.
- Dark base: `#1A1B26` (Tokyo Night Background)
- Best for: Modern aesthetic, blue-purple preference

## Pairing Recommendations

| Terminal Theme | TAVS Theme | Why |
|---------------|------------|-----|
| Ghostty default | Nord | Cool tones match Ghostty's clean aesthetic |
| iTerm2 default | Catppuccin Mocha | Warm tones complement iTerm2's defaults |
| Dracula (terminal) | Dracula | Perfect match with terminal theme |
| Solarized (terminal) | Solarized Dark/Light | Cohesive palette throughout |
| Catppuccin (terminal) | Matching Catppuccin variant | Use same flavor as terminal |
| Any dark terminal | Tokyo Night | Safe, modern default |

## Applying Themes

```bash
# Apply theme (sets THEME_MODE="preset" + THEME_PRESET)
tavs set theme nord

# Preview current theme
tavs status --colors

# Test visual signals with theme
tavs test --quick

# List available themes
tavs theme
```

Each theme includes dark/light mode colors. When `ENABLE_LIGHT_DARK_SWITCHING`
is true, TAVS selects the appropriate color set based on system appearance.
