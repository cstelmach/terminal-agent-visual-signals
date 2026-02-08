#!/bin/bash
# ==============================================================================
# Generate Agent Background Image Placeholders
# ==============================================================================
# Creates simple solid-color PNG placeholders for each agent's data/backgrounds/
# directory. These are small (~2KB) images that can be replaced with custom art.
#
# Usage:
#   ./generate-agent-backgrounds.sh [--force]
#
# Options:
#   --force  Overwrite existing images
#
# Requires: ImageMagick (convert command)
# ==============================================================================

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/../.."
AGENTS_DIR="$PROJECT_ROOT/src/agents"

# Image dimensions (small for repo size)
WIDTH=64
HEIGHT=64

STATES=("processing" "permission" "complete" "idle" "compacting" "reset")
MODES=("dark" "light")
AGENTS=("claude" "gemini" "opencode" "codex")

FORCE=false
if [[ "${1:-}" == "--force" ]]; then
    FORCE=true
fi

# Get color for agent/state/mode
get_color() {
    local agent="$1"
    local state="$2"
    local mode="$3"

    # Dark mode colors
    if [[ "$mode" == "dark" ]]; then
        case "$agent" in
            claude)
                case "$state" in
                    processing) echo "#473D2F" ;;
                    permission) echo "#4A2021" ;;
                    complete)   echo "#2D4A3D" ;;
                    idle)       echo "#443147" ;;
                    compacting) echo "#2B4645" ;;
                    reset)      echo "#2E3440" ;;
                esac
                ;;
            gemini)
                case "$state" in
                    processing) echo "#3D4147" ;;
                    permission) echo "#4A2021" ;;
                    complete)   echo "#2D4A3D" ;;
                    idle)       echo "#2F3D4A" ;;
                    compacting) echo "#2B4645" ;;
                    reset)      echo "#2E3440" ;;
                esac
                ;;
            opencode)
                case "$state" in
                    processing) echo "#404040" ;;
                    permission) echo "#4A2021" ;;
                    complete)   echo "#2D4A3D" ;;
                    idle)       echo "#383838" ;;
                    compacting) echo "#2B4645" ;;
                    reset)      echo "#2E3440" ;;
                esac
                ;;
            codex)
                case "$state" in
                    processing) echo "#3D3347" ;;
                    permission) echo "#4A2021" ;;
                    complete)   echo "#2D4A3D" ;;
                    idle)       echo "#443147" ;;
                    compacting) echo "#2B4645" ;;
                    reset)      echo "#2E3440" ;;
                esac
                ;;
        esac
    else
        # Light mode colors
        case "$agent" in
            claude)
                case "$state" in
                    processing) echo "#F5E0D0" ;;
                    permission) echo "#F5D0D0" ;;
                    complete)   echo "#D0F0E0" ;;
                    idle)       echo "#E8E0F0" ;;
                    compacting) echo "#D8F0F0" ;;
                    reset)      echo "#ECEFF4" ;;
                esac
                ;;
            gemini)
                case "$state" in
                    processing) echo "#D0E0F5" ;;
                    permission) echo "#F5D0D0" ;;
                    complete)   echo "#D0F0E0" ;;
                    idle)       echo "#D0E8F5" ;;
                    compacting) echo "#D8F0F0" ;;
                    reset)      echo "#ECEFF4" ;;
                esac
                ;;
            opencode)
                case "$state" in
                    processing) echo "#E0E0E0" ;;
                    permission) echo "#F5D0D0" ;;
                    complete)   echo "#D0F0E0" ;;
                    idle)       echo "#E8E8E8" ;;
                    compacting) echo "#D8F0F0" ;;
                    reset)      echo "#ECEFF4" ;;
                esac
                ;;
            codex)
                case "$state" in
                    processing) echo "#E0D0F5" ;;
                    permission) echo "#F5D0D0" ;;
                    complete)   echo "#D0F0E0" ;;
                    idle)       echo "#E8E0F0" ;;
                    compacting) echo "#D8F0F0" ;;
                    reset)      echo "#ECEFF4" ;;
                esac
                ;;
        esac
    fi
}

# Check for ImageMagick
if ! command -v convert &>/dev/null; then
    echo "Error: ImageMagick (convert command) is required but not found."
    echo "Install with: brew install imagemagick (macOS) or apt install imagemagick (Linux)"
    exit 1
fi

echo "Generating agent background placeholders..."
echo "Image size: ${WIDTH}x${HEIGHT}"
echo ""

for agent in "${AGENTS[@]}"; do
    echo "Agent: $agent"

    for mode in "${MODES[@]}"; do
        dir="$AGENTS_DIR/$agent/data/backgrounds/$mode"
        mkdir -p "$dir"

        for state in "${STATES[@]}"; do
            output="$dir/${state}.png"

            # Skip if exists and not forcing
            if [[ -f "$output" ]] && [[ "$FORCE" != "true" ]]; then
                echo "  [$mode] $state.png - exists (skipped)"
                continue
            fi

            # Get color for this agent/state/mode
            color=$(get_color "$agent" "$state" "$mode")
            color="${color:-#2E3440}"

            # Generate solid color PNG
            convert -size "${WIDTH}x${HEIGHT}" "xc:${color}" "$output"

            # Get file size
            size=$(ls -lh "$output" | awk '{print $5}')
            echo "  [$mode] $state.png - created ($color, $size)"
        done
    done
    echo ""
done

echo "Done! Generated placeholder images for all agents."
echo ""
echo "To customize:"
echo "  1. Replace images in src/agents/{agent}/data/backgrounds/{dark,light}/"
echo "  2. Or add custom images to ~/.tavs/agents/{agent}/backgrounds/"
