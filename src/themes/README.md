# Theme Presets

This directory contains shareable theme presets for Terminal Agent Visual Signals.

## Using Presets

### Method 1: Configuration File

Edit your config to use a preset:

```bash
# In ~/.terminal-visual-signals/user.conf
THEME_MODE="preset"
THEME_PRESET="nord"
```

### Method 2: Command Line

Apply a preset at runtime:

```bash
source src/core/theme-config-loader.sh
apply_theme "dracula"
```

### Method 3: Configuration Wizard

Run the configuration wizard and select a preset:

```bash
./configure.sh
```

## Available Presets

| Preset | Description | Best For |
|--------|-------------|----------|
| `nord` | Arctic, bluish color palette | Dark terminals with cool tones |
| `dracula` | Dark theme with vibrant colors | High contrast preference |
| `solarized-dark` | Precise LAB color values | Long coding sessions |
| `solarized-light` | Light variant of Solarized | Bright environments |
| `tokyo-night` | Inspired by Tokyo city lights | Modern aesthetic |

## Creating Your Own Preset

### File Format

Create a `.conf` file in this directory with bash variable assignments:

```bash
#!/bin/bash
# my-theme.conf - Your Custom Theme
# Author: Your Name
# Description: A brief description of your theme
# License: MIT (or your preferred license)

# =============================================================================
# COLORS (Required)
# =============================================================================
# Use hex colors: #RRGGBB

# Dark mode colors (required)
DARK_BASE="#2E3440"           # Background base color
DARK_PROCESSING="#XXXXXX"     # Orange-ish: agent working
DARK_PERMISSION="#XXXXXX"     # Red-ish: needs approval
DARK_COMPLETE="#XXXXXX"       # Green-ish: task finished
DARK_IDLE="#XXXXXX"           # Purple-ish: waiting
DARK_COMPACTING="#XXXXXX"     # Teal-ish: compressing context

# Light mode colors (optional - auto-generated if omitted)
LIGHT_BASE="#ECEFF4"
LIGHT_PROCESSING="#XXXXXX"
LIGHT_PERMISSION="#XXXXXX"
LIGHT_COMPLETE="#XXXXXX"
LIGHT_IDLE="#XXXXXX"
LIGHT_COMPACTING="#XXXXXX"

# =============================================================================
# FACES (Optional)
# =============================================================================
# Override face theme for this preset
# Available: minimal, bear, cat, lenny, shrug, plain, claudA-F
# FACE_THEME="minimal"

# =============================================================================
# EMOJIS (Optional)
# =============================================================================
# Override state emojis
# EMOJI_PROCESSING="🟠"
# EMOJI_PERMISSION="🔴"
# EMOJI_COMPLETE="🟢"
# EMOJI_IDLE="🟣"
# EMOJI_COMPACTING="🔄"
```

### Color Guidelines

For visual signal recognition, follow these hue guidelines:

| State | Target Hue | Color Family |
|-------|------------|--------------|
| Processing | ~30° | Orange, Amber, Gold |
| Permission | ~0° | Red, Crimson, Rose |
| Complete | ~120° | Green, Mint, Lime |
| Idle | ~270° | Purple, Violet, Lavender |
| Compacting | ~180° | Teal, Cyan, Turquoise |

Keep saturation and lightness appropriate for terminal backgrounds:
- **Dark themes**: Lower lightness (20-35%), moderate saturation (30-50%)
- **Light themes**: Higher lightness (85-95%), lower saturation (15-30%)

### Testing Your Theme

```bash
# Load your theme
source src/core/theme-config-loader.sh
apply_theme "my-theme"

# Test each state
./src/core/trigger.sh processing
sleep 2
./src/core/trigger.sh permission
sleep 2
./src/core/trigger.sh complete
sleep 2
./src/core/trigger.sh idle
sleep 2
./src/core/trigger.sh compacting
sleep 2
./src/core/trigger.sh reset
```

## Contributing Presets

To share your preset with the community:

1. Create your `.conf` file following the format above
2. Test thoroughly in multiple terminals
3. Submit a pull request to the project repository

Include in your PR:
- Screenshot showing all states
- Terminal emulator(s) tested
- Any special requirements or recommendations
