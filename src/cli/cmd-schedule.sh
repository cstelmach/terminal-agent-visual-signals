#!/bin/bash
# ==============================================================================
# TAVS CLI — schedule command
# ==============================================================================
# Usage: tavs schedule <subcommand> [options]
#
# Manage schedule rules in ~/.tavs/schedule.json.
# The TAVS.app reacts to CLI edits via filesystem watch.
# ==============================================================================

source "$CLI_DIR/cli-utils.sh"
source "$TAVS_ROOT/src/core/lock-state-lib.sh"
source "$TAVS_ROOT/src/core/challenge.sh"

SCHEDULE_FILE="$TAVS_USER_CONFIG_DIR/schedule.json"

# ==============================================================================
# HELPERS
# ==============================================================================

# Challenge gate for schedule-mutating subcommands (spec D7): while a hard
# lock is effective, resume/add/remove require passing the unlock challenge.
# Passing here permits THIS edit only; it does not create an unlock grant.
# `tavs schedule pause` (pausing MORE) is never gated.
_schedule_challenge_gate() {
    if ! _tavs_lock_effective; then
        return 0
    fi
    cli_info "A hard lock is active: this change requires the unlock challenge."
    if ! _tavs_challenge_verify; then
        cli_error "Challenge failed. Schedule unchanged."
        return 1
    fi
    return 0
}

_schedule_require_jq() {
    if ! command -v jq &>/dev/null; then
        cli_error "jq is required for schedule management. Install with: brew install jq"
        return 1
    fi
}

_schedule_load_or_empty() {
    if [[ -f "$SCHEDULE_FILE" ]]; then
        cat "$SCHEDULE_FILE"
    else
        echo ""
    fi
}

_schedule_load_or_create() {
    mkdir -p "$TAVS_USER_CONFIG_DIR"
    if [[ ! -f "$SCHEDULE_FILE" ]]; then
        local skeleton='{"version":1,"master_active":true,"allowed_windows":[],"quiet_periods":[]}'
        echo "$skeleton" | jq '.' > "$SCHEDULE_FILE"
    fi
    cat "$SCHEDULE_FILE"
}

_schedule_atomic_write() {
    local content="$1"
    local tmp
    tmp=$(mktemp "$TAVS_USER_CONFIG_DIR/schedule.json.XXXXXX")
    trap 'rm -f "$tmp"' RETURN
    echo "$content" > "$tmp"
    mv "$tmp" "$SCHEDULE_FILE"
    trap - RETURN
}

_schedule_generate_id() {
    local type="$1"
    shift
    local base=""

    case "$type" in
        window)
            local days="$1" start="$2" end="$3"
            base="window-${days}-${start}-${end}"
            ;;
        hourly)
            local sm="$1" em="$2"
            base="hourly-${sm}-${em}"
            ;;
        fixed_daily)
            local start="$1" end="$2"
            base="fixed-daily-${start}-${end}"
            ;;
    esac

    base="${base//,/-}"
    base="${base//:/-}"

    local json
    json=$(_schedule_load_or_empty)
    if [[ -z "$json" ]]; then
        echo "$base"
        return
    fi

    local existing
    existing=$(echo "$json" | jq -r '(.allowed_windows + .quiet_periods)[].id')

    local candidate="$base"
    local suffix=2
    while echo "$existing" | grep -qxF "$candidate"; do
        candidate="${base}-${suffix}"
        ((suffix++))
    done
    echo "$candidate"
}

# ==============================================================================
# VALIDATION (mirrors Swift ScheduleStore.validate exactly)
# ==============================================================================

_schedule_validate_time() {
    local time="$1" id="$2" field="$3"
    if [[ ! "$time" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
        cli_error "$field \"$time\" in '$id' is invalid (must be HH:MM, two digits each)"
        return 1
    fi
    local hh="${time%%:*}" mm="${time##*:}"
    hh=$((10#$hh))
    mm=$((10#$mm))
    if (( hh < 0 || hh > 23 )); then
        cli_error "$field \"$time\" in '$id' has invalid hour (must be 00-23)"
        return 1
    fi
    if (( mm < 0 || mm > 59 )); then
        cli_error "$field \"$time\" in '$id' has invalid minute (must be 00-59)"
        return 1
    fi
    return 0
}

_schedule_validate() {
    local json="$1"
    local errors=0

    local master_active
    master_active=$(echo "$json" | jq -r '.master_active')

    local enabled_window_count
    enabled_window_count=$(echo "$json" | jq '[.allowed_windows[] | select(.enabled == true)] | length')

    if [[ "$master_active" == "true" ]] && (( enabled_window_count == 0 )); then
        cli_error "master_active is true but no enabled allowed_windows exist"
        ((errors++))
    fi

    local window_count
    window_count=$(echo "$json" | jq '.allowed_windows | length')
    local i
    for (( i = 0; i < window_count; i++ )); do
        local enabled
        enabled=$(echo "$json" | jq -r ".allowed_windows[$i].enabled")
        [[ "$enabled" != "true" ]] && continue

        local wid
        wid=$(echo "$json" | jq -r ".allowed_windows[$i].id")
        if [[ -z "$wid" || "$wid" == "null" ]]; then
            cli_error "allowed_windows[$i] has empty id"
            ((errors++))
            continue
        fi

        local days_count
        days_count=$(echo "$json" | jq ".allowed_windows[$i].days | length")
        if (( days_count == 0 )); then
            cli_error "window '$wid' has empty days list"
            ((errors++))
        fi

        local wstart wend
        wstart=$(echo "$json" | jq -r ".allowed_windows[$i].start")
        wend=$(echo "$json" | jq -r ".allowed_windows[$i].end")

        if ! _schedule_validate_time "$wstart" "$wid" "start"; then
            ((errors++))
        fi
        if ! _schedule_validate_time "$wend" "$wid" "end"; then
            ((errors++))
        fi
        if [[ "$wstart" == "$wend" ]]; then
            cli_error "window '$wid' has zero-length (start == end: $wstart)"
            ((errors++))
        fi
    done

    local quiet_count
    quiet_count=$(echo "$json" | jq '.quiet_periods | length')
    for (( i = 0; i < quiet_count; i++ )); do
        local enabled
        enabled=$(echo "$json" | jq -r ".quiet_periods[$i].enabled")
        [[ "$enabled" != "true" ]] && continue

        local qid
        qid=$(echo "$json" | jq -r ".quiet_periods[$i].id")
        if [[ -z "$qid" || "$qid" == "null" ]]; then
            cli_error "quiet_periods[$i] has empty id"
            ((errors++))
            continue
        fi

        local kind
        kind=$(echo "$json" | jq -r ".quiet_periods[$i].kind")

        case "$kind" in
            hourly)
                local sm em
                sm=$(echo "$json" | jq ".quiet_periods[$i].start_minute // empty")
                em=$(echo "$json" | jq ".quiet_periods[$i].end_minute // empty")
                if [[ -z "$sm" || -z "$em" ]]; then
                    cli_error "quiet period '$qid' requires both start_minute and end_minute"
                    ((errors++))
                    continue
                fi
                if [[ -n "$sm" ]] && (( sm < 0 || sm > 59 )); then
                    cli_error "quiet period '$qid' has invalid start_minute $sm (must be 0-59)"
                    ((errors++))
                fi
                if [[ -n "$em" ]] && (( em < 0 || em > 59 )); then
                    cli_error "quiet period '$qid' has invalid end_minute $em (must be 0-59)"
                    ((errors++))
                fi
                ;;
            fixed_daily)
                local qs qe
                qs=$(echo "$json" | jq -r ".quiet_periods[$i].start // empty")
                qe=$(echo "$json" | jq -r ".quiet_periods[$i].end // empty")
                if [[ -z "$qs" || -z "$qe" ]]; then
                    cli_error "quiet period '$qid' requires both start and end times (HH:MM)"
                    ((errors++))
                    continue
                fi
                if [[ -n "$qs" ]]; then
                    if ! _schedule_validate_time "$qs" "$qid" "start"; then
                        ((errors++))
                    fi
                fi
                if [[ -n "$qe" ]]; then
                    if ! _schedule_validate_time "$qe" "$qid" "end"; then
                        ((errors++))
                    fi
                fi
                if [[ -n "$qs" && -n "$qe" && "$qs" == "$qe" ]]; then
                    cli_error "quiet period '$qid' has zero-length (start == end: $qs)"
                    ((errors++))
                fi
                ;;
            *)
                cli_error "quiet period '$qid' has unknown kind '$kind' (must be hourly or fixed_daily)"
                ((errors++))
                ;;
        esac
    done

    return $errors
}

# ==============================================================================
# SUBCOMMANDS
# ==============================================================================

_schedule_show() {
    local json
    json=$(_schedule_load_or_empty)

    if [[ -z "$json" ]]; then
        cli_info "No schedule configured."
        cli_info "Create one with: tavs schedule add-window --days mon,tue,wed,thu,fri --start 08:00 --end 20:00"
        return 0
    fi

    local master_active
    master_active=$(echo "$json" | jq -r '.master_active')

    cli_section "Schedule Configuration"

    if [[ "$master_active" == "true" ]]; then
        echo -e "  Master: ${_CLR_GREEN}active${_CLR_RESET}"
    else
        echo -e "  Master: ${_CLR_RED}paused${_CLR_RESET}"
    fi
    echo ""

    local window_count
    window_count=$(echo "$json" | jq '.allowed_windows | length')
    if (( window_count > 0 )); then
        echo -e "  ${_CLR_BOLD}Allowed Windows${_CLR_RESET} ($window_count)"
        local i
        for (( i = 0; i < window_count; i++ )); do
            local wid enabled days start end
            wid=$(echo "$json" | jq -r ".allowed_windows[$i].id")
            enabled=$(echo "$json" | jq -r ".allowed_windows[$i].enabled")
            days=$(echo "$json" | jq -r ".allowed_windows[$i].days | join(\",\")")
            start=$(echo "$json" | jq -r ".allowed_windows[$i].start")
            end=$(echo "$json" | jq -r ".allowed_windows[$i].end")
            local status_icon
            if [[ "$enabled" == "true" ]]; then
                status_icon="${_CLR_GREEN}on ${_CLR_RESET}"
            else
                status_icon="${_CLR_DIM}off${_CLR_RESET}"
            fi
            printf "    %b  %-30s %s  %s-%s\n" "$status_icon" "$wid" "$days" "$start" "$end"
        done
    else
        echo -e "  ${_CLR_DIM}No allowed windows configured.${_CLR_RESET}"
    fi
    echo ""

    local quiet_count
    quiet_count=$(echo "$json" | jq '.quiet_periods | length')
    if (( quiet_count > 0 )); then
        echo -e "  ${_CLR_BOLD}Quiet Periods${_CLR_RESET} ($quiet_count)"
        local i
        for (( i = 0; i < quiet_count; i++ )); do
            local qid enabled kind
            qid=$(echo "$json" | jq -r ".quiet_periods[$i].id")
            enabled=$(echo "$json" | jq -r ".quiet_periods[$i].enabled")
            kind=$(echo "$json" | jq -r ".quiet_periods[$i].kind")
            local status_icon
            if [[ "$enabled" == "true" ]]; then
                status_icon="${_CLR_GREEN}on ${_CLR_RESET}"
            else
                status_icon="${_CLR_DIM}off${_CLR_RESET}"
            fi
            local detail=""
            if [[ "$kind" == "hourly" ]]; then
                local sm em
                sm=$(echo "$json" | jq -r ".quiet_periods[$i].start_minute")
                em=$(echo "$json" | jq -r ".quiet_periods[$i].end_minute")
                detail="hourly :${sm}-:${em}"
            elif [[ "$kind" == "fixed_daily" ]]; then
                local qs qe
                qs=$(echo "$json" | jq -r ".quiet_periods[$i].start")
                qe=$(echo "$json" | jq -r ".quiet_periods[$i].end")
                detail="daily  ${qs}-${qe}"
            fi
            printf "    %b  %-30s %s\n" "$status_icon" "$qid" "$detail"
        done
    else
        echo -e "  ${_CLR_DIM}No quiet periods configured.${_CLR_RESET}"
    fi

    # Show mute.state if present
    local mute_state_file="$TAVS_USER_CONFIG_DIR/mute.state"
    if [[ -f "$mute_state_file" ]]; then
        echo ""
        echo -e "  ${_CLR_BOLD}Current Mute State${_CLR_RESET}"
        local muted="" reason="" until_epoch=""
        while IFS='=' read -r key val; do
            val="${val#\"}"
            val="${val%\"}"
            case "$key" in
                MUTED) muted="$val" ;;
                REASON) reason="$val" ;;
                UNTIL_EPOCH) until_epoch="$val" ;;
            esac
        done < "$mute_state_file"

        if [[ "$muted" == "true" ]]; then
            local reason_text="$reason"
            [[ -z "$reason_text" ]] && reason_text="unknown"
            local until_text=""
            if [[ -n "$until_epoch" && "$until_epoch" != "0" ]]; then
                until_text=" until $(date -r "$until_epoch" '+%H:%M' 2>/dev/null || echo "epoch $until_epoch")"
            fi
            echo -e "    ${_CLR_RED}Muted${_CLR_RESET} — $reason_text$until_text"
        else
            echo -e "    ${_CLR_GREEN}Active${_CLR_RESET}"
        fi
    fi
}

_schedule_pause() {
    _schedule_require_jq || return 1
    local json
    json=$(_schedule_load_or_create)
    local updated
    updated=$(echo "$json" | jq '.master_active = false')
    _schedule_atomic_write "$updated"
    cli_success "Schedule paused (master_active = false)"
}

_schedule_resume() {
    _schedule_challenge_gate || return 1
    _schedule_require_jq || return 1
    local json
    json=$(_schedule_load_or_create)
    local updated
    updated=$(echo "$json" | jq '.master_active = true')

    if ! _schedule_validate "$updated"; then
        local allow_empty
        allow_empty=$(echo "$updated" | jq '.master_active = false')
        if ! _schedule_validate "$allow_empty"; then
            return 1
        fi
        cli_warn "Schedule resumed but has validation warnings (no enabled windows)."
        cli_info "Add a window: tavs schedule add-window --days mon,fri --start 08:00 --end 20:00"
    fi

    _schedule_atomic_write "$updated"
    cli_success "Schedule resumed (master_active = true)"
}

_schedule_add_window() {
    _schedule_challenge_gate || return 1
    _schedule_require_jq || return 1

    local days="" start="" end="" id=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --days) days="$2"; shift 2 ;;
            --start) start="$2"; shift 2 ;;
            --end) end="$2"; shift 2 ;;
            --id) id="$2"; shift 2 ;;
            *)
                cli_error "Unknown option: $1"
                cli_info "Usage: tavs schedule add-window --days mon,tue,wed --start 08:00 --end 20:00 [--id name]"
                return 1
                ;;
        esac
    done

    if [[ -z "$days" || -z "$start" || -z "$end" ]]; then
        cli_error "Required: --days, --start, --end"
        cli_info "Usage: tavs schedule add-window --days mon,tue,wed --start 08:00 --end 20:00 [--id name]"
        return 1
    fi

    # Validate days
    local valid_days="mon tue wed thu fri sat sun"
    local days_json="["
    local first=true
    IFS=',' read -ra day_arr <<< "$days"
    for d in "${day_arr[@]}"; do
        d=$(echo "$d" | tr '[:upper:]' '[:lower:]')
        if ! echo "$valid_days" | grep -qw "$d"; then
            cli_error "Invalid day: $d (valid: mon,tue,wed,thu,fri,sat,sun)"
            return 1
        fi
        if [[ "$first" == "true" ]]; then
            days_json+="\"$d\""
            first=false
        else
            days_json+=",\"$d\""
        fi
    done
    days_json+="]"

    [[ -z "$id" ]] && id=$(_schedule_generate_id window "$days" "$start" "$end")

    local json
    json=$(_schedule_load_or_create)

    local new_window
    new_window=$(jq -n --arg id "$id" --argjson days "$days_json" --arg start "$start" --arg end "$end" \
        '{id: $id, enabled: true, days: $days, start: $start, end: $end}')

    local updated
    updated=$(echo "$json" | jq --argjson w "$new_window" '.allowed_windows += [$w]')

    if ! _schedule_validate "$updated"; then
        cli_error "Validation failed — window not added."
        return 1
    fi

    _schedule_atomic_write "$updated"
    cli_success "Added window '$id': $days $start-$end"
}

_schedule_add_quiet() {
    _schedule_challenge_gate || return 1
    _schedule_require_jq || return 1

    local kind="" start_minute="" end_minute="" start="" end="" id=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --kind) kind="$2"; shift 2 ;;
            --start-minute) start_minute="$2"; shift 2 ;;
            --end-minute) end_minute="$2"; shift 2 ;;
            --start) start="$2"; shift 2 ;;
            --end) end="$2"; shift 2 ;;
            --id) id="$2"; shift 2 ;;
            *)
                cli_error "Unknown option: $1"
                cli_info "Usage: tavs schedule add-quiet --kind hourly --start-minute 50 --end-minute 59 [--id name]"
                cli_info "       tavs schedule add-quiet --kind fixed_daily --start 12:00 --end 13:00 [--id name]"
                return 1
                ;;
        esac
    done

    if [[ -z "$kind" ]]; then
        cli_error "Required: --kind (hourly or fixed_daily)"
        return 1
    fi

    local new_quiet=""
    case "$kind" in
        hourly)
            if [[ -z "$start_minute" || -z "$end_minute" ]]; then
                cli_error "Hourly quiet periods require --start-minute and --end-minute"
                return 1
            fi
            [[ -z "$id" ]] && id=$(_schedule_generate_id hourly "$start_minute" "$end_minute")
            new_quiet=$(jq -n --arg id "$id" --argjson sm "$start_minute" --argjson em "$end_minute" \
                '{id: $id, enabled: true, kind: "hourly", start_minute: $sm, end_minute: $em}')
            ;;
        fixed_daily)
            if [[ -z "$start" || -z "$end" ]]; then
                cli_error "Fixed daily quiet periods require --start and --end"
                return 1
            fi
            [[ -z "$id" ]] && id=$(_schedule_generate_id fixed_daily "$start" "$end")
            new_quiet=$(jq -n --arg id "$id" --arg start "$start" --arg end "$end" \
                '{id: $id, enabled: true, kind: "fixed_daily", start: $start, end: $end}')
            ;;
        *)
            cli_error "Invalid kind: $kind (must be hourly or fixed_daily)"
            return 1
            ;;
    esac

    local json
    json=$(_schedule_load_or_create)

    local updated
    updated=$(echo "$json" | jq --argjson q "$new_quiet" '.quiet_periods += [$q]')

    if ! _schedule_validate "$updated"; then
        cli_error "Validation failed — quiet period not added."
        return 1
    fi

    _schedule_atomic_write "$updated"
    if [[ "$kind" == "hourly" ]]; then
        cli_success "Added quiet period '$id': hourly :${start_minute}-:${end_minute}"
    else
        cli_success "Added quiet period '$id': daily ${start}-${end}"
    fi
}

_schedule_remove() {
    _schedule_challenge_gate || return 1
    _schedule_require_jq || return 1

    local target_id="$1"
    if [[ -z "$target_id" ]]; then
        cli_error "Usage: tavs schedule remove <id>"
        cli_info "Use 'tavs schedule list' to see available ids."
        return 1
    fi

    if [[ ! -f "$SCHEDULE_FILE" ]]; then
        cli_error "No schedule file found at $SCHEDULE_FILE"
        return 1
    fi

    local json
    json=$(cat "$SCHEDULE_FILE")

    local found
    found=$(echo "$json" | jq --arg id "$target_id" \
        '[(.allowed_windows + .quiet_periods)[] | select(.id == $id)] | length')

    if (( found == 0 )); then
        cli_error "No rule found with id '$target_id'"
        cli_info "Available ids:"
        echo "$json" | jq -r '(.allowed_windows + .quiet_periods)[].id' | sed 's/^/  /'
        return 1
    fi

    local updated
    updated=$(echo "$json" | jq --arg id "$target_id" \
        '.allowed_windows = [.allowed_windows[] | select(.id != $id)] |
         .quiet_periods = [.quiet_periods[] | select(.id != $id)]')

    _schedule_atomic_write "$updated"
    cli_success "Removed rule '$target_id'"
}

_schedule_validate_cmd() {
    _schedule_require_jq || return 1

    if [[ ! -f "$SCHEDULE_FILE" ]]; then
        cli_error "No schedule file found at $SCHEDULE_FILE"
        return 1
    fi

    local json
    if ! json=$(jq '.' "$SCHEDULE_FILE" 2>&1); then
        cli_error "Invalid JSON: $json"
        return 1
    fi

    if _schedule_validate "$json"; then
        cli_success "Schedule is valid."
        return 0
    else
        return 1
    fi
}

_schedule_list() {
    local json
    json=$(_schedule_load_or_empty)

    if [[ -z "$json" ]]; then
        cli_info "No schedule configured."
        return 0
    fi

    local window_count quiet_count
    window_count=$(echo "$json" | jq '.allowed_windows | length')
    quiet_count=$(echo "$json" | jq '.quiet_periods | length')

    if (( window_count + quiet_count == 0 )); then
        cli_info "No rules configured."
        return 0
    fi

    printf "%-35s %-8s %s\n" "ID" "STATE" "TYPE"
    printf "%-35s %-8s %s\n" "---" "-----" "----"

    local i
    for (( i = 0; i < window_count; i++ )); do
        local wid enabled
        wid=$(echo "$json" | jq -r ".allowed_windows[$i].id")
        enabled=$(echo "$json" | jq -r ".allowed_windows[$i].enabled")
        local state="enabled"
        [[ "$enabled" != "true" ]] && state="disabled"
        printf "%-35s %-8s %s\n" "$wid" "$state" "window"
    done

    for (( i = 0; i < quiet_count; i++ )); do
        local qid enabled kind
        qid=$(echo "$json" | jq -r ".quiet_periods[$i].id")
        enabled=$(echo "$json" | jq -r ".quiet_periods[$i].enabled")
        kind=$(echo "$json" | jq -r ".quiet_periods[$i].kind")
        local state="enabled"
        [[ "$enabled" != "true" ]] && state="disabled"
        printf "%-35s %-8s %s\n" "$qid" "$state" "quiet/$kind"
    done
}

# ==============================================================================
# DISPATCHER
# ==============================================================================

cmd_schedule() {
    local subcmd="${1:-}"

    if [[ "$subcmd" == "--help" || "$subcmd" == "-h" ]]; then
        cat <<'EOF'
tavs schedule — Manage muting schedule

Usage:
  tavs schedule show                Show current schedule + mute state
  tavs schedule list                List rule ids and state
  tavs schedule pause               Pause scheduling (master_active = false)
  tavs schedule resume              Resume scheduling (master_active = true)
  tavs schedule add-window          Add an allowed time window
  tavs schedule add-quiet           Add a quiet period
  tavs schedule remove <id>         Remove a rule by id
  tavs schedule validate            Validate schedule.json

While a hard lock is active (tavs lock status), resume/add-window/add-quiet/
remove require the unlock challenge; pause is never gated.

Add Window Options:
  --days <mon,tue,...>    Comma-separated days (required)
  --start <HH:MM>        Start time (required)
  --end <HH:MM>          End time (required)
  --id <name>            Custom id (optional, auto-generated if omitted)

Add Quiet Options:
  --kind <hourly|fixed_daily>  Period kind (required)
  --start-minute <0-59>        Start minute (hourly, required)
  --end-minute <0-59>          End minute (hourly, required)
  --start <HH:MM>              Start time (fixed_daily, required)
  --end <HH:MM>                End time (fixed_daily, required)
  --id <name>                  Custom id (optional, auto-generated if omitted)

Examples:
  tavs schedule add-window --days mon,tue,wed,thu,fri --start 08:00 --end 20:00
  tavs schedule add-quiet --kind hourly --start-minute 50 --end-minute 59
  tavs schedule add-quiet --kind fixed_daily --start 12:00 --end 13:00
  tavs schedule pause
  tavs schedule list
  tavs schedule remove weekday-core-hours
EOF
        return 0
    fi

    case "$subcmd" in
        show)
            shift
            _schedule_show "$@"
            ;;
        list)
            shift
            _schedule_list "$@"
            ;;
        pause)
            shift
            _schedule_pause "$@"
            ;;
        resume)
            shift
            _schedule_resume "$@"
            ;;
        add-window)
            shift
            _schedule_add_window "$@"
            ;;
        add-quiet)
            shift
            _schedule_add_quiet "$@"
            ;;
        remove)
            shift
            _schedule_remove "$@"
            ;;
        validate)
            shift
            _schedule_validate_cmd "$@"
            ;;
        "")
            cli_bold "tavs schedule — Manage muting schedule"
            echo ""
            echo "  show           Show current schedule + mute state"
            echo "  list           List rule ids and state"
            echo "  pause          Pause scheduling"
            echo "  resume         Resume scheduling"
            echo "  add-window     Add an allowed time window"
            echo "  add-quiet      Add a quiet period"
            echo "  remove <id>    Remove a rule by id"
            echo "  validate       Validate schedule.json"
            echo ""
            cli_info "Usage: tavs schedule <subcommand> [options]"
            cli_info "Run 'tavs schedule --help' for detailed options."
            ;;
        *)
            cli_error "Unknown subcommand: $subcmd"
            cli_info "Try: tavs schedule --help"
            return 1
            ;;
    esac
}
