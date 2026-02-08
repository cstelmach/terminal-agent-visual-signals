#!/bin/bash
# ==============================================================================
# Generate Sample Background Images
# ==============================================================================
# Creates sample background images for stylish mode using ImageMagick.
#
# Usage: ./generate-samples.sh [output_dir]
#
# Requirements: ImageMagick (convert command)
# ==============================================================================

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUTPUT_DIR="${1:-$SCRIPT_DIR}"

# Check for ImageMagick
if ! command -v convert &>/dev/null; then
    echo "Error: ImageMagick is required but not installed."
    echo ""
    echo "Install with:"
    echo "  macOS:  brew install imagemagick"
    echo "  Ubuntu: sudo apt install imagemagick"
    echo "  Fedora: sudo dnf install ImageMagick"
    exit 1
fi

echo "Generating sample background images..."
echo "Output directory: $OUTPUT_DIR"

# Create directories
mkdir -p "$OUTPUT_DIR/dark" "$OUTPUT_DIR/light"

# Image dimensions
WIDTH=1920
HEIGHT=1080

# === DARK MODE IMAGES ===

echo "Creating dark mode images..."

# Base dark color (Nord Polar Night)
DARK_BASE="#2E3440"

# Create base texture (subtle plasma noise)
echo "  - Creating base texture..."
convert -size ${WIDTH}x${HEIGHT} \
    "plasma:${DARK_BASE}-#3B4252" \
    -blur 0x3 \
    -modulate 100,50,100 \
    "$OUTPUT_DIR/dark/base.png"

# Processing (Orange tint)
echo "  - processing.png (orange)"
convert "$OUTPUT_DIR/dark/base.png" \
    -fill "#D08770" -colorize 15% \
    "$OUTPUT_DIR/dark/processing.png"

# Permission (Red tint)
echo "  - permission.png (red)"
convert "$OUTPUT_DIR/dark/base.png" \
    -fill "#BF616A" -colorize 20% \
    "$OUTPUT_DIR/dark/permission.png"

# Complete (Green tint)
echo "  - complete.png (green)"
convert "$OUTPUT_DIR/dark/base.png" \
    -fill "#A3BE8C" -colorize 12% \
    "$OUTPUT_DIR/dark/complete.png"

# Idle (Purple tint)
echo "  - idle.png (purple)"
convert "$OUTPUT_DIR/dark/base.png" \
    -fill "#B48EAD" -colorize 15% \
    "$OUTPUT_DIR/dark/idle.png"

# Compacting (Teal tint)
echo "  - compacting.png (teal)"
convert "$OUTPUT_DIR/dark/base.png" \
    -fill "#88C0D0" -colorize 12% \
    "$OUTPUT_DIR/dark/compacting.png"

# Default (base)
echo "  - default.png"
cp "$OUTPUT_DIR/dark/base.png" "$OUTPUT_DIR/dark/default.png"

# Clean up base
rm "$OUTPUT_DIR/dark/base.png"

# === LIGHT MODE IMAGES ===

echo "Creating light mode images..."

# Base light color (Nord Snow Storm)
LIGHT_BASE="#ECEFF4"

# Create base texture (subtle plasma noise)
echo "  - Creating base texture..."
convert -size ${WIDTH}x${HEIGHT} \
    "plasma:${LIGHT_BASE}-#E5E9F0" \
    -blur 0x3 \
    -modulate 100,30,100 \
    "$OUTPUT_DIR/light/base.png"

# Processing (Orange tint)
echo "  - processing.png (orange)"
convert "$OUTPUT_DIR/light/base.png" \
    -fill "#D08770" -colorize 20% \
    "$OUTPUT_DIR/light/processing.png"

# Permission (Red tint)
echo "  - permission.png (red)"
convert "$OUTPUT_DIR/light/base.png" \
    -fill "#BF616A" -colorize 25% \
    "$OUTPUT_DIR/light/permission.png"

# Complete (Green tint)
echo "  - complete.png (green)"
convert "$OUTPUT_DIR/light/base.png" \
    -fill "#A3BE8C" -colorize 18% \
    "$OUTPUT_DIR/light/complete.png"

# Idle (Purple tint)
echo "  - idle.png (purple)"
convert "$OUTPUT_DIR/light/base.png" \
    -fill "#B48EAD" -colorize 20% \
    "$OUTPUT_DIR/light/idle.png"

# Compacting (Teal tint)
echo "  - compacting.png (teal)"
convert "$OUTPUT_DIR/light/base.png" \
    -fill "#88C0D0" -colorize 18% \
    "$OUTPUT_DIR/light/compacting.png"

# Default (base)
echo "  - default.png"
cp "$OUTPUT_DIR/light/base.png" "$OUTPUT_DIR/light/default.png"

# Clean up base
rm "$OUTPUT_DIR/light/base.png"

echo ""
echo "Done! Generated images:"
echo ""
ls -la "$OUTPUT_DIR/dark/" "$OUTPUT_DIR/light/" 2>/dev/null || true

echo ""
echo "To use these images:"
echo "  1. Copy to ~/.tavs/backgrounds/"
echo "  2. Enable in configuration: ENABLE_STYLISH_BACKGROUNDS=\"true\""
echo "  3. Run ./configure.sh to set up via wizard"
