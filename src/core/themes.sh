#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Signals — Face Themes (Anthropomorphising)
# ==============================================================================
# Defines ASCII face expressions for each state, organized by theme.
# Uses Bash 3.2-compatible case statements for macOS compatibility.
# ==============================================================================

# Available themes for configuration script
AVAILABLE_THEMES=("minimal" "bear" "cat" "lenny" "shrug" "plain")

# === FACE ACCESSOR FUNCTION ===
# Usage: get_face <theme> <state>
# Returns: ASCII face for the given theme and state, or empty string if not found
get_face() {
    local theme="$1"
    local state="$2"

    case "${theme}:${state}" in
        # =======================================================================
        # THEME: minimal — Simple, unobtrusive kaomoji
        # =======================================================================
        minimal:processing)  echo "(°-°)" ;;
        minimal:permission)  echo "(°□°)" ;;
        minimal:complete)    echo "(^‿^)" ;;
        minimal:compacting)  echo "(°◡°)" ;;
        minimal:reset)       echo "(-_-)" ;;
        minimal:idle_0)      echo "(•‿•)" ;;      # Alert
        minimal:idle_1)      echo "(‿‿)" ;;       # Content
        minimal:idle_2)      echo "(︶‿︶)" ;;     # Relaxed
        minimal:idle_3)      echo "(¬‿¬)" ;;      # Drowsy
        minimal:idle_4)      echo "(-.-)zzZ" ;;   # Sleepy
        minimal:idle_5)      echo "(︶.︶)ᶻᶻ" ;;  # Deep Sleep

        # =======================================================================
        # THEME: bear — Cute bear faces ʕ•ᴥ•ʔ
        # =======================================================================
        bear:processing)     echo "ʕ•ᴥ•ʔ" ;;
        bear:permission)     echo "ʕ๏ᴥ๏ʔ" ;;
        bear:complete)       echo "ʕ♥ᴥ♥ʔ" ;;
        bear:compacting)     echo "ʕ•̀ᴥ•́ʔ" ;;
        bear:reset)          echo "ʕ-ᴥ-ʔ" ;;
        bear:idle_0)         echo "ʕ•ᴥ•ʔ" ;;     # Alert
        bear:idle_1)         echo "ʕ‾ᴥ‾ʔ" ;;     # Content
        bear:idle_2)         echo "ʕ︶ᴥ︶ʔ" ;;    # Relaxed
        bear:idle_3)         echo "ʕ¬ᴥ¬ʔ" ;;     # Drowsy
        bear:idle_4)         echo "ʕ-ᴥ-ʔzZ" ;;   # Sleepy
        bear:idle_5)         echo "ʕ︶ᴥ︶ʔᶻᶻ" ;; # Deep Sleep

        # =======================================================================
        # THEME: cat — Playful cat faces ฅ^•ﻌ•^ฅ
        # =======================================================================
        cat:processing)      echo "ฅ^•ﻌ•^ฅ" ;;
        cat:permission)      echo "ฅ^◉ﻌ◉^ฅ" ;;
        cat:complete)        echo "ฅ^♥ﻌ♥^ฅ" ;;
        cat:compacting)      echo "ฅ^•̀ﻌ•́^ฅ" ;;
        cat:reset)           echo "ฅ^-ﻌ-^ฅ" ;;
        cat:idle_0)          echo "ฅ^•ﻌ•^ฅ" ;;    # Alert
        cat:idle_1)          echo "ฅ^‾ﻌ‾^ฅ" ;;    # Content
        cat:idle_2)          echo "ฅ^︶ﻌ︶^ฅ" ;;   # Relaxed
        cat:idle_3)          echo "ฅ^¬ﻌ¬^ฅ" ;;    # Drowsy
        cat:idle_4)          echo "ฅ^-ﻌ-^ฅzZ" ;;  # Sleepy
        cat:idle_5)          echo "ฅ^︶ﻌ︶^ฅᶻᶻ" ;;# Deep Sleep

        # =======================================================================
        # THEME: lenny — Expressive lenny faces ( ͡° ͜ʖ ͡°)
        # =======================================================================
        lenny:processing)    echo "( ͡° ͜ʖ ͡°)" ;;
        lenny:permission)    echo "( ͡⊙ ͜ʖ ͡⊙)" ;;
        lenny:complete)      echo "( ͡♥ ͜ʖ ͡♥)" ;;
        lenny:compacting)    echo "( ͡~ ͜ʖ ͡°)" ;;
        lenny:reset)         echo "( ͡_ ͜ʖ ͡_)" ;;
        lenny:idle_0)        echo "( ͡° ͜ʖ ͡°)" ;;  # Alert
        lenny:idle_1)        echo "( ͡‾ ͜ʖ ͡‾)" ;;  # Content
        lenny:idle_2)        echo "( ͡︶ ͜ʖ ͡︶)" ;; # Relaxed
        lenny:idle_3)        echo "( ͡¬ ͜ʖ ͡¬)" ;;  # Drowsy
        lenny:idle_4)        echo "( ͡- ͜ʖ ͡-)zZ" ;;# Sleepy
        lenny:idle_5)        echo "( ͡︶ ͜ʖ ͡︶)ᶻᶻ" ;;# Deep Sleep

        # =======================================================================
        # THEME: shrug — Shrug-style faces ¯\_(ツ)_/¯
        # =======================================================================
        shrug:processing)    echo "¯\\_(°‿°)_/¯" ;;
        shrug:permission)    echo "¯\\_(°□°)_/¯" ;;
        shrug:complete)      echo "¯\\_(^‿^)_/¯" ;;
        shrug:compacting)    echo "¯\\_(°◡°)_/¯" ;;
        shrug:reset)         echo "¯\\_(-_-)_/¯" ;;
        shrug:idle_0)        echo "¯\\_(•‿•)_/¯" ;;    # Alert
        shrug:idle_1)        echo "¯\\_(‾‿‾)_/¯" ;;    # Content
        shrug:idle_2)        echo "¯\\_(︶‿︶)_/¯" ;;   # Relaxed
        shrug:idle_3)        echo "¯\\_(¬‿¬)_/¯" ;;    # Drowsy
        shrug:idle_4)        echo "¯\\_(-.-)_/¯zZ" ;;  # Sleepy
        shrug:idle_5)        echo "¯\\_(︶.︶)_/¯ᶻᶻ" ;;# Deep Sleep

        # =======================================================================
        # THEME: plain — ASCII-only fallback for terminal compatibility
        # =======================================================================
        plain:processing)    echo ":-|" ;;
        plain:permission)    echo ":-O" ;;
        plain:complete)      echo ":-)" ;;
        plain:compacting)    echo ":-/" ;;
        plain:reset)         echo ":-|" ;;
        plain:idle_0)        echo ":-)" ;;      # Alert
        plain:idle_1)        echo ":-|" ;;      # Content
        plain:idle_2)        echo ":-)" ;;      # Relaxed
        plain:idle_3)        echo ":-/" ;;      # Drowsy
        plain:idle_4)        echo ":-(" ;;      # Sleepy
        plain:idle_5)        echo ":-(zzZ" ;;   # Deep Sleep

        # Default: return empty string for unknown combinations
        *) echo "" ;;
    esac
}

