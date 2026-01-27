# Background Images for Stylish Mode

This directory contains sample background images for the stylish backgrounds feature.

## Supported Terminals

- **iTerm2** - Full support via OSC 1337
- **Kitty** - Requires `allow_remote_control=yes` in kitty.conf
- All other terminals fall back to solid colors silently

## Directory Structure

```
backgrounds/
├── dark/                    # Dark mode images
│   ├── processing.png       # Orange-tinted (agent working)
│   ├── permission.png       # Red-tinted (needs approval)
│   ├── complete.png         # Green-tinted (response finished)
│   ├── idle.png             # Purple-tinted (waiting for input)
│   ├── compacting.png       # Teal-tinted (context compression)
│   └── default.png          # Base background (fallback)
└── light/                   # Light mode images (same files)
    └── ...
```

## Image Guidelines

### Resolution
- **Recommended**: Match your display (1920x1080, 2560x1440, etc.)
- Images are scaled to fit the terminal window

### Format
- **PNG** recommended (supports transparency)
- JPG also supported

### Style
- **Muted, professional** - visible but not distracting
- **Low contrast** - text readability is priority
- **Color-coded** - subtle tint matching the state hue

### Color Reference (Dark Mode)

| State | Hue | Suggested Tint |
|-------|-----|----------------|
| Processing | 30° (Orange) | Warm amber overlay |
| Permission | 0° (Red) | Soft crimson overlay |
| Complete | 120° (Green) | Muted emerald overlay |
| Idle | 270° (Purple) | Subtle lavender overlay |
| Compacting | 180° (Teal) | Cool cyan overlay |

## Creating Images

### Option 1: Solid Colors with Texture
Create a dark base image with subtle noise/texture, then apply colored overlays.

### Option 2: Using ImageMagick

```bash
# Create a dark textured base (1920x1080)
convert -size 1920x1080 \
    plasma:gray20-gray30 \
    -blur 0x2 \
    dark/base.png

# Create state-specific images with color overlay
convert dark/base.png \
    -fill "#473D2F" -colorize 30% \
    dark/processing.png

convert dark/base.png \
    -fill "#4A2021" -colorize 30% \
    dark/permission.png

convert dark/base.png \
    -fill "#2D4A30" -colorize 30% \
    dark/complete.png

convert dark/base.png \
    -fill "#443147" -colorize 30% \
    dark/idle.png

convert dark/base.png \
    -fill "#2B4645" -colorize 30% \
    dark/compacting.png

cp dark/base.png dark/default.png
```

### Option 3: Using ffmpeg

```bash
# Generate noise pattern
ffmpeg -f lavfi -i "color=c=0x2E3440:s=1920x1080,noise=alls=10:allf=t" \
    -vframes 1 dark/base.png
```

### Option 4: Manual Creation
Use any image editor (GIMP, Photoshop, etc.) to create:
1. Dark base (~#2E3440)
2. Add subtle texture/noise
3. Create versions with state-colored tints

## Installation

Copy your images to the backgrounds directory:

```bash
# Default location
cp -r dark light ~/.terminal-visual-signals/backgrounds/

# Or specify custom location in config
STYLISH_BACKGROUNDS_DIR="/path/to/your/backgrounds"
```

## Testing

```bash
# Test with trigger script
ENABLE_STYLISH_BACKGROUNDS=true ./src/core/trigger.sh processing
sleep 2
./src/core/trigger.sh reset
```

## Kitty Setup

Add to `~/.config/kitty/kitty.conf`:

```
allow_remote_control yes
```

Then reload: `kitty @ set-background-image none` to test.
