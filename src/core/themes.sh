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
        minimal:processing)  echo "(°-°)" ;;     # working
        minimal:permission)  echo "(°□°)" ;;     # waiting for permission
        minimal:complete)    echo "(^‿^)" ;;     # happy
        minimal:compacting)  echo "(@_@)" ;;     # confused
        minimal:reset)       echo "(-_-)" ;;     # content
        minimal:idle_0)      echo "(•‿•)" ;;      # Alert
        minimal:idle_1)      echo "(‿‿)" ;;       # Content
        minimal:idle_2)      echo "(︶‿︶)" ;;     # Relaxed
        minimal:idle_3)      echo "(¬‿¬)" ;;      # Drowsy
        minimal:idle_4)      echo "(-.-)zzZ" ;;   # Sleepy
        minimal:idle_5)      echo "(︶.︶)ᶻᶻ" ;;  # Deep Sleep

        # =======================================================================
        # THEME: bear — Cute bear faces ʕ•ᴥ•ʔ
        # =======================================================================
        bear:processing)     echo "ʕ•ᴥ•ʔ" ;;     # working
        bear:permission)     echo "ʕ๏ᴥ๏ʔ" ;;     # waiting for permission
        bear:complete)       echo "ʕ♥ᴥ♥ʔ" ;;     # happy
        bear:compacting)     echo "ʕ•_•ʔ" ;;     # confused
        bear:reset)          echo "ʕ-ᴥ-ʔ" ;;     # content
        bear:idle_0)         echo "ʕ•ᴥ•ʔ" ;;     # Alert
        bear:idle_1)         echo "ʕ‾ᴥ‾ʔ" ;;     # Content
        bear:idle_2)         echo "ʕ︶ᴥ︶ʔ" ;;    # Relaxed
        bear:idle_3)         echo "ʕ¬ᴥ¬ʔ" ;;     # Drowsy
        bear:idle_4)         echo "ʕ-ᴥ-ʔzZ" ;;   # Sleepy
        bear:idle_5)         echo "ʕ︶ᴥ︶ʔᶻᶻ" ;; # Deep Sleep

        # =======================================================================
        # THEME: cat — Playful cat faces ฅ^•ﻌ•^ฅ
        # =======================================================================
        cat:processing)      echo "ฅ^•ﻌ•^ฅ" ;;     # working
        cat:permission)      echo "ฅ^◉ﻌ◉^ฅ" ;;     # waiting for permission
        cat:complete)        echo "ฅ^♥ﻌ♥^ฅ" ;;     # happy
        cat:compacting)      echo "ฅ^•_•^ฅ" ;;     # confused
        cat:reset)           echo "ฅ^-ﻌ-^ฅ" ;;     # content
        cat:idle_0)          echo "ฅ^•ﻌ•^ฅ" ;;    # Alert
        cat:idle_1)          echo "ฅ^‾ﻌ‾^ฅ" ;;    # Content
        cat:idle_2)          echo "ฅ^︶ﻌ︶^ฅ" ;;   # Relaxed
        cat:idle_3)          echo "ฅ^¬ﻌ¬^ฅ" ;;    # Drowsy
        cat:idle_4)          echo "ฅ^-ﻌ-^ฅzZ" ;;  # Sleepy
        cat:idle_5)          echo "ฅ^︶ﻌ︶^ฅᶻᶻ" ;;# Deep Sleep

        # =======================================================================
        # THEME: lenny — Expressive lenny faces ( ͡° ͜ʖ ͡°)
        # =======================================================================
        lenny:processing)    echo "( ͡° ͜ʖ ͡°)" ;;  # working
        lenny:permission)    echo "( ͡⊙ ͜ʖ ͡⊙)" ;;     # waiting for permission
        lenny:complete)      echo "( ͡♥ ͜ʖ ͡♥)" ;;     # happy
        lenny:compacting)    echo "( ͡ʘ ͜ʖ ͡ʘ)" ;;     # confused
        lenny:reset)         echo "( ͡_ ͜ʖ ͡_)" ;;     # content
        lenny:idle_0)        echo "( ͡° ͜ʖ ͡°)" ;;  # Alert
        lenny:idle_1)        echo "( ͡‾ ͜ʖ ͡‾)" ;;  # Content
        lenny:idle_2)        echo "( ͡︶ ͜ʖ ͡︶)" ;; # Relaxed
        lenny:idle_3)        echo "( ͡¬ ͜ʖ ͡¬)" ;;  # Drowsy
        lenny:idle_4)        echo "( ͡- ͜ʖ ͡-)zZ" ;;# Sleepy
        lenny:idle_5)        echo "( ͡︶ ͜ʖ ͡︶)ᶻᶻ" ;;# Deep Sleep

        # =======================================================================
        # THEME: shrug — Shrug-style faces ¯\_(ツ)_/¯
        # =======================================================================
        shrug:processing)    echo "¯\\_(°‿°)_/¯" ;;     # working
        shrug:permission)    echo "¯\\_(°□°)_/¯" ;;     # waiting for permission
        shrug:complete)      echo "¯\\_(^‿^)_/¯" ;;     # happy
        shrug:compacting)    echo "¯\\_(@_@)_/¯" ;;     # confused
        shrug:reset)         echo "¯\\_(-_-)_/¯" ;;     # content
        shrug:idle_0)        echo "¯\\_(•‿•)_/¯" ;;    # Alert
        shrug:idle_1)        echo "¯\\_(‾‿‾)_/¯" ;;    # Content
        shrug:idle_2)        echo "¯\\_(︶‿︶)_/¯" ;;   # Relaxed
        shrug:idle_3)        echo "¯\\_(¬‿¬)_/¯" ;;    # Drowsy
        shrug:idle_4)        echo "¯\\_(-.-)_/¯zZ" ;;  # Sleepy
        shrug:idle_5)        echo "¯\\_(︶.︶)_/¯ᶻᶻ" ;;# Deep Sleep

        # =======================================================================
        # THEME: plain — ASCII-only fallback for terminal compatibility
        # =======================================================================
        plain:processing)    echo ":-|" ;;     # working
        plain:permission)    echo ":-O" ;;     # waiting for permission
        plain:complete)      echo ":-)" ;;     # happy
        plain:compacting)    echo ":-|" ;;     # confused
        plain:reset)         echo ":-|" ;;     # content
        plain:idle_0)        echo ":-)" ;;      # Alert
        plain:idle_1)        echo ":-|" ;;      # Content
        plain:idle_2)        echo ":-)" ;;      # Relaxed
        plain:idle_3)        echo ":-/" ;;      # Drowsy
        plain:idle_4)        echo ":-(" ;;      # Sleepy
        plain:idle_5)        echo ":-(zzZ" ;;   # Deep Sleep


        # =======================================================================
        # THEME: claudA — pincer style Ǝ(...)E  (NO mouth)
        # =======================================================================
        claudA:processing)    echo "Ǝ(• •)E" ;;
        claudA:permission)    echo "Ǝ(° °)E" ;;
        claudA:complete)      echo "Ǝ(✦ ✦)E" ;;
        claudA:compacting)    echo "Ǝ(@ @)E" ;;
        claudA:reset)         echo "Ǝ(• •)E" ;;
        claudA:idle_0)        echo "Ǝ(◕ ◕)E" ;;
        claudA:idle_1)        echo "Ǝ(• •)E" ;;
        claudA:idle_2)        echo "Ǝ(ᴗ ᴗ)E" ;;
        claudA:idle_3)        echo "Ǝ(¬ ¬)E" ;;
        claudA:idle_4)        echo "Ǝ(- -)E zZ" ;;
        claudA:idle_5)        echo "Ǝ(= =)E ᶻᶻ" ;;

        # =======================================================================
        # THEME: claudB — pincer style Ǝ(...)E  (NO mouth)
        # =======================================================================
        claudB:processing)    echo "Ǝ(• ◕)E" ;;
        claudB:permission)    echo "Ǝ(○ ○)E" ;;
        claudB:complete)      echo "Ǝ(★ ★)E" ;;
        claudB:compacting)    echo "Ǝ(◎ ◎)E" ;;
        claudB:reset)         echo "Ǝ(• •)E" ;;
        claudB:idle_0)        echo "Ǝ(◉ ◉)E" ;;
        claudB:idle_1)        echo "Ǝ(• •)E" ;;
        claudB:idle_2)        echo "Ǝ(ᵕ ᵕ)E" ;;
        claudB:idle_3)        echo "Ǝ(￢ ￢)E" ;;
        claudB:idle_4)        echo "Ǝ(－ －)E zZ" ;;
        claudB:idle_5)        echo "Ǝ(＿ ＿)E ᶻᶻ" ;;

        # =======================================================================
        # THEME: claudC — pincer style Ǝ(...)E  (NO mouth)
        # =======================================================================
        claudC:processing)    echo "Ǝ(■ ■)E" ;;
        claudC:permission)    echo "Ǝ(□ □)E" ;;
        claudC:complete)      echo "Ǝ(✧ ✧)E" ;;
        claudC:compacting)    echo "Ǝ(▣ ▣)E" ;;
        claudC:reset)         echo "Ǝ(■ ■)E" ;;
        claudC:idle_0)        echo "Ǝ(▢ ▢)E" ;;
        claudC:idle_1)        echo "Ǝ(■ ■)E" ;;
        claudC:idle_2)        echo "Ǝ(▱ ▱)E" ;;
        claudC:idle_3)        echo "Ǝ(▨ ▨)E" ;;
        claudC:idle_4)        echo "Ǝ(─ ─)E zZ" ;;
        claudC:idle_5)        echo "Ǝ(═ ═)E ᶻᶻ" ;;

        # =======================================================================
        # THEME: claudD — pincer style Ǝ(...)E  (NO mouth)
        # =======================================================================
        claudD:processing)    echo "Ǝ(◔ ◔)E" ;;
        claudD:permission)    echo "Ǝ(ʘ ʘ)E" ;;
        claudD:complete)      echo "Ǝ(❀ ❀)E" ;;
        claudD:compacting)    echo "Ǝ(× ×)E" ;;
        claudD:reset)         echo "Ǝ(◔ ◔)E" ;;
        claudD:idle_0)        echo "Ǝ(◍ ◍)E" ;;
        claudD:idle_1)        echo "Ǝ(• •)E" ;;
        claudD:idle_2)        echo "Ǝ(ᵔ ᵔ)E" ;;
        claudD:idle_3)        echo "Ǝ(ಠ ಠ)E" ;;
        claudD:idle_4)        echo "Ǝ(∪ ∪)E zZ" ;;
        claudD:idle_5)        echo "Ǝ(∩ ∩)E ᶻᶻ" ;;

        # =======================================================================
        # THEME: claudE — pincer style Ǝ(...)E  (NO mouth)
        # =======================================================================
        claudE:processing)    echo "Ǝ(｡ ｡)E" ;;
        claudE:permission)    echo "Ǝ(՞ ՞)E" ;;
        claudE:complete)      echo "Ǝ(✿ ✿)E" ;;
        claudE:compacting)    echo "Ǝ(＠ ＠)E" ;;
        claudE:reset)         echo "Ǝ(｡ ｡)E" ;;
        claudE:idle_0)        echo "Ǝ(◠ ◠)E" ;;
        claudE:idle_1)        echo "Ǝ(｡ ｡)E" ;;
        claudE:idle_2)        echo "Ǝ(ᵕ ᵕ)E" ;;
        claudE:idle_3)        echo "Ǝ(⌣ ⌣)E" ;;
        claudE:idle_4)        echo "Ǝ(ᴗ ᴗ)E zZ" ;;
        claudE:idle_5)        echo "Ǝ(︶ ︶)E ᶻᶻ" ;;

        # =======================================================================
        # THEME: claudF — pincer style Ǝ(...)E  (NO mouth)
        # =======================================================================
        claudF:processing)    echo "Ǝ(. .)E" ;;
        claudF:permission)    echo "Ǝ(o o)E" ;;
        claudF:complete)      echo "Ǝ(* *)E" ;;
        claudF:compacting)    echo "Ǝ(@ @)E" ;;
        claudF:reset)         echo "Ǝ(. .)E" ;;
        claudF:idle_0)        echo "Ǝ(O O)E" ;;
        claudF:idle_1)        echo "Ǝ(. .)E" ;;
        claudF:idle_2)        echo "Ǝ(^ ^)E" ;;
        claudF:idle_3)        echo "Ǝ(- -)E" ;;
        claudF:idle_4)        echo "Ǝ(- -)E zZ" ;;
        claudF:idle_5)        echo "Ǝ(_ _)E ᶻᶻ" ;;

        # Default: return empty string for unknown combinations
        *) echo "" ;;
    esac
}

