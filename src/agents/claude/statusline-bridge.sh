#!/bin/bash
# ==============================================================================
# TAVS StatusLine Bridge — Silent Data Siphon
# ==============================================================================
# Reads Claude Code StatusLine JSON from stdin, extracts context window and
# session metadata, writes to TAVS state file. Produces NO output on stdout.
#
# User integrates by adding to their statusline script:
#   #!/bin/bash
#   input=$(cat)
#   echo "$input" | /path/to/statusline-bridge.sh
#   # ... user's statusline code continues with $input ...
#
# Test overrides (for testing without real TTY):
#   _TAVS_BRIDGE_STATE_DIR  — override state directory
#   _TAVS_BRIDGE_TTY_SAFE   — override TTY_SAFE identifier
# ==============================================================================
set -euo pipefail

# === READ STDIN ===
# StatusLine mechanism pipes JSON on stdin; cat reads full payload
_input=""
if [[ ! -t 0 ]]; then
    _input=$(cat 2>/dev/null) || true
fi
[[ -z "$_input" ]] && exit 0

# === TTY RESOLUTION ===
# Inlined from terminal-osc-sequences.sh:41-58 — cannot source that file
# (it pulls in themes.sh and other heavy dependencies)
_tty_safe="${_TAVS_BRIDGE_TTY_SAFE:-}"
if [[ -z "$_tty_safe" ]]; then
    _tty_dev=""
    _tty_dev=$(ps -o tty= -p $PPID 2>/dev/null) || true
    _tty_dev="${_tty_dev// /}"
    if [[ -n "$_tty_dev" && "$_tty_dev" != "??" && "$_tty_dev" != "-" ]]; then
        [[ "$_tty_dev" != /dev/* ]] && _tty_dev="/dev/$_tty_dev"
    else
        # Fallback to /dev/tty
        if { echo -n "" > /dev/tty; } 2>/dev/null; then
            _tty_dev="/dev/tty"
        else
            exit 0  # Can't determine TTY — exit silently
        fi
    fi
    _tty_safe="${_tty_dev//\//_}"
fi

# === STATE DIRECTORY ===
# Inlined from spinner.sh:16-24 — same reason as above
_state_dir="${_TAVS_BRIDGE_STATE_DIR:-}"
if [[ -z "$_state_dir" ]]; then
    if [[ -n "${XDG_RUNTIME_DIR:-}" && -d "${XDG_RUNTIME_DIR:-}" ]]; then
        _state_dir="$XDG_RUNTIME_DIR/tavs"
    else
        _state_dir="${HOME}/.cache/tavs"
    fi
fi
# Create directory if missing (secure permissions)
if [[ ! -d "$_state_dir" ]]; then
    mkdir -p "$_state_dir" 2>/dev/null || exit 0
    chmod 700 "$_state_dir" 2>/dev/null || true
fi

# === JSON FIELD EXTRACTION ===
# sed-based extraction — no jq dependency (matching trigger.sh pattern)
# Handles: "key": value, "key": "value", "key":value (with/without quotes)
_extract() {
    printf '%s' "$_input" | \
        sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\",}]*\).*/\1/p" | head -1
}

_pct=$(_extract 'used_percentage')
_model=$(_extract 'display_name')
_cost=$(_extract 'total_cost_usd')
_duration=$(_extract 'total_duration_ms')
_lines_add=$(_extract 'total_lines_added')
_lines_rem=$(_extract 'total_lines_removed')

# Filter out literal "null" (used_percentage is null before first API call)
[[ "$_pct" == "null" ]] && _pct=""
[[ "$_model" == "null" ]] && _model=""
[[ "$_cost" == "null" ]] && _cost=""
[[ "$_duration" == "null" ]] && _duration=""
[[ "$_lines_add" == "null" ]] && _lines_add=""
[[ "$_lines_rem" == "null" ]] && _lines_rem=""

# === ATOMIC WRITE ===
# mktemp + mv pattern (from session-state.sh, title-state-persistence.sh)
_state_file="${_state_dir}/context.${_tty_safe}"
_tmp_file=$(mktemp "${_state_file}.tmp.XXXXXX" 2>/dev/null) || exit 0

cat > "$_tmp_file" << EOF
# TAVS Context Bridge - $(date -u +%Y-%m-%dT%H:%M:%S+00:00)
pct=${_pct:-}
model=${_model:-}
cost=${_cost:-}
duration=${_duration:-}
lines_add=${_lines_add:-}
lines_rem=${_lines_rem:-}
ts=$(date +%s)
EOF

mv "$_tmp_file" "$_state_file" 2>/dev/null || { rm -f "$_tmp_file" 2>/dev/null; exit 0; }

# === NO OUTPUT ===
# Critical: this script must produce ZERO bytes on stdout.
# The user's statusline script continues after piping to this bridge.
