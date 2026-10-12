#!/bin/bash

_tavs_visual_restrictions_read() {
    local file="${1:-$HOME/.tavs/visual-restrictions.state}" data="" full=0
    _TAVS_VISUAL_RESTRICTIONS_STATUS=unavailable
    [[ "$file" == /* ]] || return 0
    if [[ ! -e "$file" && ! -L "$file" ]]; then
        local parent="${file%/*}"
        [[ -n "$parent" ]] || parent=/
        while [[ ! -e "$parent" && ! -L "$parent" ]]; do
            parent="${parent%/*}"
            [[ -n "$parent" ]] || parent=/
        done
        if [[ -d "$parent" && -x "$parent" ]]; then
            _TAVS_VISUAL_RESTRICTIONS_STATUS=active
        fi
        return 0
    fi
    [[ -f "$file" && ! -L "$file" && -r "$file" ]] || return 0
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        IFS= read -r -k 128 -u 0 data < "$file" && full=1
    else
        IFS= read -r -d '' -n 128 data < "$file" && full=1
    fi
    [[ "$full" == 0 ]] || return 0
    case "$data" in
        $'SCHEMA_VERSION="1"\nSUSPENDED="true"\n') _TAVS_VISUAL_RESTRICTIONS_STATUS=suspended ;;
        $'SCHEMA_VERSION="1"\nSUSPENDED="false"\n') _TAVS_VISUAL_RESTRICTIONS_STATUS=active ;;
    esac
    return 0
}

_tavs_visual_restrictions_suspended() {
    _tavs_visual_restrictions_read
    # An unavailable marker cannot authorize restrictive painting.
    [[ "$_TAVS_VISUAL_RESTRICTIONS_STATUS" != active ]]
}

_tavs_visual_restrictions_write() {
    local suspended="${1:-}" file="${2:-$HOME/.tavs/visual-restrictions.state}" dir tmp
    case "$suspended" in true|false) ;; *) return 1 ;; esac
    [[ "$file" == /* ]] || return 1
    if [[ -e "$file" || -L "$file" ]]; then
        [[ -f "$file" && ! -L "$file" ]] || return 1
    fi
    dir="${file%/*}"
    [[ -n "$dir" ]] || dir=/
    [[ -d "$dir" ]] || (umask 077; mkdir -p "$dir") || return 1
    tmp=$(mktemp "$dir/.visual-restrictions.XXXXXX") || return 1
    if ! printf 'SCHEMA_VERSION="1"\nSUSPENDED="%s"\n' "$suspended" > "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    if ! mv -f "$tmp" "$file"; then
        rm -f "$tmp"
        return 1
    fi
    return 0
}
