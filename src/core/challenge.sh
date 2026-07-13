#!/bin/bash
# ==============================================================================
# TAVS — Unlock challenge (spec D2, section 2.4)
# ==============================================================================
# Two challenge types, configurable via ~/.tavs/challenge.conf:
#   password — salted SHA-256; spec: hash = hex(SHA256(UTF8(salt_hex + password)))
#              (dual implementation with ChallengeVerifier.swift, pinned by
#              tests/integration/challenge-parity.bats)
#   puzzle   — retype a shown sentence with each word's FIRST letter moved to
#              the word's END ("the quick" -> "het uickq"). Generated and
#              verified ephemerally; needs no cross-side parity.
#   both     — password first, then puzzle.
# No challenge.conf at all means: puzzle (works out of the box, no setup).
#
# Every prompt reads from stdin (tests can pipe answers). 3 attempts per
# challenge, then failure. All functions are set -e safe.
# ==============================================================================

_TAVS_CHALLENGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Populates _CH_TYPE, _CH_SALT, _CH_HASH, _CH_SENTENCES. Invalid or
# inconsistent config degrades to the puzzle (never locks the user out, D3).
_tavs_challenge_load_config() {
    _CH_TYPE="" _CH_SALT="" _CH_HASH="" _CH_SENTENCES=""
    local f="$HOME/.tavs/challenge.conf" k v
    if [[ -r "$f" ]]; then
        while IFS='=' read -r k v; do
            v="${v%\"}"; v="${v#\"}"
            case "$k" in
                CHALLENGE_TYPE)        _CH_TYPE="$v" ;;
                PASSWORD_SALT_HEX)     _CH_SALT="$v" ;;
                PASSWORD_HASH_HEX)     _CH_HASH="$v" ;;
                PUZZLE_SENTENCES_FILE) _CH_SENTENCES="$v" ;;
            esac
        done < "$f"
    fi
    case "$_CH_TYPE" in
        password|puzzle|both) ;;
        *) _CH_TYPE="puzzle" ;;
    esac
    if [[ "$_CH_TYPE" != "puzzle" && ( -z "$_CH_SALT" || -z "$_CH_HASH" ) ]]; then
        _CH_TYPE="puzzle"
    fi
    return 0
}

# Spec 2.4: lowercase-hex SHA256(UTF8(salt_hex_string + password)).
# The salt is concatenated as the LITERAL hex string, not decoded bytes.
_tavs_challenge_hash() {
    printf '%s%s' "$1" "$2" | shasum -a 256 | cut -d' ' -f1
}

# "the quick brown fox" -> "het uickq rownb oxf" (single-letter words map to
# themselves). Input is lowercase words + single spaces (pool constraint).
_tavs_puzzle_transform() {
    local out="" w
    for w in $1; do
        out+="${w:1}${w:0:1} "
    done
    printf '%s' "${out% }"
}

_tavs_puzzle_pick_sentence() {
    local file="${_CH_SENTENCES:-$_TAVS_CHALLENGE_DIR/challenge-sentences.txt}"
    [[ -r "$file" ]] || return 1
    local -a lines=()
    local line
    while IFS= read -r line; do
        [[ -n "$line" ]] && lines+=("$line")
    done < "$file"
    (( ${#lines[@]} > 0 )) || return 1
    printf '%s' "${lines[$(( RANDOM % ${#lines[@]} ))]}"
}

_tavs_challenge_password_once() {
    local pw
    printf 'Password: ' >&2
    IFS= read -rs pw || return 1
    printf '\n' >&2
    [[ "$(_tavs_challenge_hash "$_CH_SALT" "$pw")" == "$_CH_HASH" ]]
}

_tavs_challenge_puzzle_once() {
    local sentence transformed answer
    sentence=$(_tavs_puzzle_pick_sentence) || return 1
    transformed=$(_tavs_puzzle_transform "$sentence")
    {
        printf 'Retype this sentence, moving each word'"'"'s FIRST letter to its END:\n'
        printf '    %s\n' "$sentence"
        printf '> '
    } >&2
    IFS= read -r answer || return 1
    # Trim trailing whitespace only; the comparison is otherwise exact.
    answer="${answer%"${answer##*[![:space:]]}"}"
    [[ "$answer" == "$transformed" ]]
}

# Runs one challenge kind with 3 attempts. $1 = password|puzzle
_tavs_challenge_run_kind() {
    local kind="$1" attempt
    for attempt in 1 2 3; do
        if [[ "$kind" == "password" ]]; then
            _tavs_challenge_password_once && return 0
        else
            _tavs_challenge_puzzle_once && return 0
        fi
        printf 'Wrong (%d/3).\n' "$attempt" >&2
    done
    return 1
}

# Main entry: verifies per configured CHALLENGE_TYPE. Returns 0 on success.
_tavs_challenge_verify() {
    _tavs_challenge_load_config
    case "$_CH_TYPE" in
        password)
            _tavs_challenge_run_kind password
            ;;
        both)
            _tavs_challenge_run_kind password && _tavs_challenge_run_kind puzzle
            ;;
        *)
            _tavs_challenge_run_kind puzzle
            ;;
    esac
}
