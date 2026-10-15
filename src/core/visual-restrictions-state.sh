#!/bin/bash

_tavs_visual_restrictions_trusted() {
    local metadata owner mode kind="${2:-leaf}"
    case "$OSTYPE" in
        darwin*) metadata=$(stat -f '%u:%Op' "$1" 2>/dev/null) || return 1 ;;
        linux*) metadata=$(stat -c '%u:%a' "$1" 2>/dev/null) || return 1 ;;
        *) return 1 ;;
    esac
    owner="${metadata%%:*}" mode="${metadata#*:}"
    [[ -n "$owner" && "$owner" != *[!0-9]* && -n "$mode" && "$mode" != *[!0-7]* ]] || return 1
    case "$kind" in
        leaf) [[ "$owner" == "$EUID" ]] || return 1 ;;
        alias|system) [[ "$owner" == 0 ]] || return 1 ;;
        ancestor) [[ "$owner" == 0 || "$owner" == "$EUID" ]] || return 1 ;;
        *) return 1 ;;
    esac
    [[ "$kind" == alias ]] && return 0
    (( (8#$mode & 8#22) == 0 )) && return 0
    if [[ "$kind" == ancestor && "$owner" == 0 ]] && (( (8#$mode & 8#1000) != 0 )); then
        case "$OSTYPE:$1" in
            darwin*:/private/tmp|darwin*:/private/var/tmp|linux*:/tmp|linux*:/var/tmp) return 0 ;;
        esac
    fi
    return 1
}

# Match native directory trust, and use the checked physical spelling after system aliases.
_tavs_visual_restrictions_path() {
    local file="$1" create="${2:-0}" LC_ALL=C remaining current="" part kind missing=0 target
    local doubles="//" single="/"
    [[ "$file" == /* && "$file" != */ && "$file" != *[[:cntrl:]]* && ${#file} -le 4096 ]] || return 1
    while [[ "$file" == *"$doubles"* ]]; do file="${file//$doubles/$single}"; done
    case "$file/" in *'/./'*|*'/../'*) return 1 ;; esac
    remaining="${file%/*}"
    remaining="${remaining#/}"
    [[ -n "$remaining" ]] || return 1
    while [[ -n "$remaining" ]]; do
        part="${remaining%%/*}"
        if [[ "$remaining" == */* ]]; then remaining="${remaining#*/}"; else remaining=""; fi
        current="${current}/${part}"
        [[ "$missing" == 0 ]] || continue
        if [[ ! -e "$current" && ! -L "$current" ]]; then
            if [[ "$create" == 1 ]]; then
                (umask 077; mkdir "$current") 2>/dev/null || [[ -d "$current" ]] || return 1
            else
                missing=1
                continue
            fi
        fi
        kind=ancestor
        [[ -n "$remaining" ]] || kind=leaf
        if [[ -L "$current" ]]; then
            [[ "$kind" == ancestor && "$OSTYPE" == darwin* ]] || return 1
            case "$current" in /tmp|/var) ;; *) return 1 ;; esac
            _tavs_visual_restrictions_trusted "$current" alias || return 1
            target=$(readlink "$current" 2>/dev/null) || return 1
            [[ "$target" == "/private$current" || "$target" == "private$current" ]] || return 1
            [[ -d /private && ! -L /private && -x /private ]] || return 1
            _tavs_visual_restrictions_trusted /private system || return 1
            current="/private$current"
        fi
        [[ -d "$current" && ! -L "$current" && -x "$current" ]] || return 1
        _tavs_visual_restrictions_trusted "$current" "$kind" || return 1
    done
    printf '%s/%s' "$current" "${file##*/}"
}

# Optional diagnostics must not mutate another file through a linked sink.
_tavs_debug_append() (
    local log="$1" links
    log=$(_tavs_visual_restrictions_path "$log" 1) || return 0
    if [[ -e "$log" || -L "$log" ]]; then
        [[ -f "$log" && ! -L "$log" ]] || return 0
        _tavs_visual_restrictions_trusted "$log" || return 0
        case "$OSTYPE" in
            darwin*) links=$(stat -f '%l' "$log" 2>/dev/null) || return 0 ;;
            linux*) links=$(stat -c '%h' "$log" 2>/dev/null) || return 0 ;;
            *) return 0 ;;
        esac
        [[ "$links" == 1 ]] || return 0
    fi
    umask 077
    printf '%s\n' "$2" 2>/dev/null >> "$log" || return 0
    return 0
)

_tavs_visual_restrictions_read() {
    local file="${1:-$HOME/.tavs/visual-restrictions.state}" data="" full=0 LC_ALL=C
    _TAVS_VISUAL_RESTRICTIONS_STATUS=unavailable
    file=$(_tavs_visual_restrictions_path "$file") || return 0
    if [[ ! -e "$file" && ! -L "$file" ]]; then
        _TAVS_VISUAL_RESTRICTIONS_STATUS=active
        return 0
    fi
    [[ -f "$file" && ! -L "$file" && -r "$file" ]] || return 0
    _tavs_visual_restrictions_trusted "$file" || return 0
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

_tavs_visual_restrictions_write() (
    local suspended="${1:-}" file="${2:-$HOME/.tavs/visual-restrictions.state}" dir tmp="" checked
    case "$suspended" in true|false) ;; *) return 1 ;; esac
    file=$(_tavs_visual_restrictions_path "$file" 1) || return 1
    if [[ -e "$file" || -L "$file" ]]; then
        [[ -f "$file" && ! -L "$file" ]] || return 1
        _tavs_visual_restrictions_trusted "$file" || return 1
    fi
    dir="${file%/*}"
    umask 077
    trap '[[ -z "$tmp" ]] || rm -f -- "$tmp"' EXIT
    trap 'exit 1' HUP INT TERM
    tmp=$(mktemp "$dir/.visual-restrictions.XXXXXX") || return 1
    printf 'SCHEMA_VERSION="1"\nSUSPENDED="%s"\n' "$suspended" > "$tmp" || return 1
    checked=$(_tavs_visual_restrictions_path "$file") || return 1
    [[ "$checked" == "$file" ]] || return 1
    if [[ -e "$file" || -L "$file" ]]; then
        [[ -f "$file" && ! -L "$file" ]] || return 1
        _tavs_visual_restrictions_trusted "$file" || return 1
    fi
    mv -f -- "$tmp" "$file" || return 1
    tmp=""
    return 0
)

# Legacy policy bodies are data, capped at the native readers' 8 KiB limit.
# Returns 0 for present, 1 for trusted absence, 2 for unavailable storage/content.
_tavs_policy_read_data() {
    local file="$1" data="" size full=0 LC_ALL=C
    _TAVS_POLICY_DATA="" _TAVS_POLICY_READ_STATUS=unavailable
    file=$(_tavs_visual_restrictions_path "$file") || return 2
    if [[ ! -e "$file" && ! -L "$file" ]]; then
        _TAVS_POLICY_READ_STATUS=absent
        return 1
    fi
    [[ -f "$file" && ! -L "$file" && -r "$file" ]] || return 2
    _tavs_visual_restrictions_trusted "$file" || return 2
    case "$OSTYPE" in
        darwin*) size=$(stat -f '%z' "$file" 2>/dev/null) || return 2 ;;
        linux*) size=$(stat -c '%s' "$file" 2>/dev/null) || return 2 ;;
        *) return 2 ;;
    esac
    [[ -n "$size" && "$size" != *[!0-9]* && ${#size} -le 4 ]] || return 2
    (( size <= 8192 )) || return 2
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        IFS= read -r -k 8193 -u 0 data < "$file" && full=1
        [[ "$data" != *$'\0'* ]] || return 2
    else
        IFS= read -r -d '' -n 8193 data < "$file" && full=1
    fi
    [[ "$full" == 0 && ${#data} -eq "$size" ]] || return 2
    _TAVS_POLICY_DATA="$data" _TAVS_POLICY_READ_STATUS=present
    return 0
}

# Normalize ASCII decimal values before arithmetic, without overflowing Int64.
_tavs_policy_decimal() {
    local value="${1:-}" prefix last
    [[ -n "$value" && "$value" != *[!0123456789]* ]] || return 1
    value="${value#"${value%%[!0]*}"}"
    [[ -n "$value" ]] || value=0
    [[ ${#value} -le 19 ]] || return 1
    if [[ ${#value} -eq 19 ]]; then
        prefix="${value%?}" last="${value#"${value%?}"}"
        (( 10#$prefix < 922337203685477580 ||
            (10#$prefix == 922337203685477580 && 10#$last <= 7) )) || return 1
    fi
    printf '%s' "$value"
}
