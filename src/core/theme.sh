#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Themes - Theme Definitions
# ==============================================================================
# Defines colors, emojis, and configuration toggles.
# Used by all agents (Claude, Gemini, Codex).
# ==============================================================================

# === TOGGLES ===
ENABLE_BACKGROUND_CHANGE=true
ENABLE_TITLE_PREFIX=true

# Per-state Toggles
ENABLE_PROCESSING=true
ENABLE_PERMISSION=true
ENABLE_COMPLETE=true
ENABLE_IDLE=true
ENABLE_COMPACTING=true

# === ANTHROPOMORPHISING (ASCII FACES) ===
# Add expressive ASCII faces to terminal titles
#
# ENABLE_ANTHROPOMORPHISING: Master toggle for ASCII face display
#   - false (default): No faces shown
#   - true: Faces appear in title per FACE_POSITION
#
# FACE_THEME: Which face style to use
#   - minimal: Simple kaomoji (default)
#   - bear: ʕ•ᴥ•ʔ family
#   - cat: ฅ^•ﻌ•^ฅ family
#   - lenny: ( ͡° ͜ʖ ͡°) family
#   - shrug: ¯\_(ツ)_/¯ family
#   - plain: ASCII-only (:-) for compatibility
#
# FACE_POSITION: Where face appears relative to emoji
#   - before: (°-°) 🟠 ~/path (default)
#   - after: 🟠 (°-°) ~/path
#
ENABLE_ANTHROPOMORPHISING="${ENABLE_ANTHROPOMORPHISING:-false}"
FACE_THEME="${FACE_THEME:-minimal}"
FACE_POSITION="${FACE_POSITION:-before}"

# === THEME: Catppuccin Frappe (Default) ===
# Muted tints that blend subtly with the background.

COLOR_PROCESSING="#473D2F"   # Muted orange
COLOR_PERMISSION="#4A2021"   # Muted red
COLOR_COMPLETE="#473046"     # Muted purple-green mix
COLOR_IDLE="#443147"         # Muted purple
COLOR_COMPACTING="#2B4645"   # Muted teal

EMOJI_PROCESSING="🟠"
EMOJI_PERMISSION="🔴"
EMOJI_COMPLETE="🟢"
EMOJI_IDLE="🟣"
EMOJI_COMPACTING="🔄"

# === IDLE TIMER THEME ===
# Progression colors for the idle fade effect
# Stage 0 (Complete) -> Idle Stages -> Reset

ENABLE_STAGE_INDICATORS=true

# Colors: Complete -> Idle 1..4 -> Reset
UNIFIED_STAGE_COLORS=(
    "$COLOR_COMPLETE"
    "$COLOR_IDLE"
    "#423148"
    "#3f3248"
    "#3a3348"
    "#373348"
    "reset"
)

# Emojis: Complete -> Idle 1..4 -> Reset (Empty)
UNIFIED_STAGE_EMOJIS=(
    "$EMOJI_COMPLETE"
    "$EMOJI_IDLE"
    "🟣"
    "🟣"
    "🟣"
    "🟣"
    ""
)

# Durations (seconds): Complete -> Idle 1..4
UNIFIED_STAGE_DURATIONS=(60 30 30 30 30 30 30)

# Check Interval (seconds)
UNIFIED_CHECK_INTERVAL=15
