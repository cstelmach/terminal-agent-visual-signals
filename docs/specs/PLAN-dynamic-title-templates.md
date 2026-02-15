# Implementation Plan: Dynamic Title Template System with Context Awareness

**Spec:** `docs/specs/SPEC-dynamic-title-templates.md`
**Created:** 2026-02-15
**Agent:** Fresh agent from /plan-from-spec

---

## Context

TAVS currently uses a single `TAVS_TITLE_FORMAT` template for ALL trigger states. The title
bar shows the same structure whether the agent is processing, waiting for permission, or idle.
The primary pain point: during permission requests (plan mode approval), users can't see how
full the context window is — information critical for deciding whether to continue or compact.

This plan implements per-state title templates with context window awareness, so the title
adapts to show relevant data per state (e.g., food emoji + percentage during permission).

---

## Prerequisites

- Git worktree for isolated development (`feature/dynamic-title-templates`)
- Access to `~/.cache/tavs/` directory (already created by `get_spinner_state_dir()`)
- All work in the worktree at `../tavs-dynamic-titles`

---

## Phase 0: Git Worktree Setup

### Implementation Steps
1. Create branch `feature/dynamic-title-templates` from `main`
2. Create worktree at `../tavs-dynamic-titles`
3. Verify all source files accessible

### Verification
- [ ] Branch exists
- [ ] Worktree functional at `../tavs-dynamic-titles`

### Definition of Done
- [ ] Working directory ready for isolated development

---

## Phase 1: Context Data System

**Scope:** Create the core context data resolution module with all token resolvers, add icon
arrays and per-state format defaults to `defaults.conf`, wire up module sourcing.

### Implementation Steps

1. **Create `src/core/context-data.sh`** (~250 lines) — the context data resolution module.

   Functions to implement:

   | Function | Purpose | Key Details |
   |----------|---------|-------------|
   | `load_context_data` | Main entry: read bridge or transcript fallback | Sets globals: `TAVS_CONTEXT_PCT`, `TAVS_CONTEXT_MODEL`, `TAVS_CONTEXT_COST`, `TAVS_CONTEXT_DURATION`, `TAVS_CONTEXT_LINES_ADD`, `TAVS_CONTEXT_LINES_REM` |
   | `read_bridge_state` | Safe key=value parsing from state file | Pattern from `title-state-persistence.sh:104-128` — `while IFS='=' read`, never source |
   | `_estimate_from_transcript` | File-size based token estimation | `file_size / 3.5 / ctx_window * 100` — stub in Phase 1, complete in Phase 4 |
   | `resolve_context_token` | Map token name to formatted value | `case` switch on 10 token types |
   | `_get_icon_from_array` | Lookup icon by percentage in bash array | `index = pct / step`, clamped to array bounds |
   | `_get_bar_horizontal` | Generate `▓▓░░░` style bar | Width param: 5 (BAR_H) or 10 (BAR_HL) |
   | `_get_bar_vertical` | Single block char `▁▂▃▄▅▆▇█` | `index = pct * 7 / 100` |
   | `_get_bar_vertical_max` | Block + max outline `▄▒` | Vertical char + `TAVS_CONTEXT_BAR_MAX` |
   | `_get_braille` | Braille fill char `⠀⠄⠤⠴⠶⠷⠿` | `index = pct * 6 / 100` |
   | `_get_number_emoji` | Digit as number emoji | `pct / 10`, 100% → `🔟` |
   | `_get_percentage` | Formatted `N%` string | Plain integer + `%` |
   | `_format_cost` | `$X.XX` format | From bridge `cost` field |
   | `_format_duration` | `NmNNs` format | From bridge `duration` field (ms) |
   | `_format_lines` | `+N` format | From bridge `lines_add` field |

   **Critical patterns to reuse:**
   - Safe key=value parsing: `title-state-persistence.sh:104-128` (never source state files)
   - Zsh compat: intermediate vars for brace defaults (`MEMORY.md` pattern)
   - Staleness: compare bridge `ts` field against `$(date +%s)` with `TAVS_CONTEXT_BRIDGE_MAX_AGE`
   - State file path: `~/.cache/tavs/context.{TTY_SAFE}` — use `get_spinner_state_dir()` from `spinner.sh` (already sourced before this module)

2. **Add icon arrays + config to `src/config/defaults.conf`** (~120 lines).

   Insert after the existing title settings section (after `TAVS_AGENTS_FORMAT` around line 135).
   Contents from Spec Sections 7.1-7.6 + Section 13:

   - `TAVS_CONTEXT_FOOD_21` — 21-entry food scale (5% steps)
   - `TAVS_CONTEXT_FOOD_11` — 11-entry food scale (10% steps)
   - `TAVS_CONTEXT_CIRCLES_11` — 11-entry color circles
   - `TAVS_CONTEXT_NUMBERS` — 11-entry number emoji
   - `TAVS_CONTEXT_BLOCKS` — 8-entry block chars (`▁▂▃▄▅▆▇█`)
   - `TAVS_CONTEXT_BRAILLE` — 7-entry braille chars
   - `TAVS_CONTEXT_BAR_FILL="▓"` / `TAVS_CONTEXT_BAR_EMPTY="░"` / `TAVS_CONTEXT_BAR_MAX="▒"`
   - `TAVS_CONTEXT_BRIDGE_MAX_AGE=30`
   - `TAVS_CONTEXT_WINDOW_SIZE=200000`
   - Per-state title format defaults:
     ```
     TAVS_TITLE_FORMAT_PROCESSING=""
     TAVS_TITLE_FORMAT_PERMISSION="{FACE} {STATUS_ICON} {CONTEXT_FOOD} {CONTEXT_PCT} {BASE}"
     TAVS_TITLE_FORMAT_COMPLETE=""
     TAVS_TITLE_FORMAT_IDLE=""
     TAVS_TITLE_FORMAT_COMPACTING="{FACE} {STATUS_ICON} {CONTEXT_PCT} {BASE}"
     TAVS_TITLE_FORMAT_SUBAGENT=""
     TAVS_TITLE_FORMAT_TOOL_ERROR=""
     TAVS_TITLE_FORMAT_RESET=""
     ```

3. **Source the new module in `src/core/trigger.sh`** — add after line 44 (after `session-icon.sh`):
   ```bash
   source "$CORE_DIR/context-data.sh"     # Context window data for title tokens
   ```

### Files to Create/Modify
- `src/core/context-data.sh` — **CREATE** (~250 lines)
- `src/config/defaults.conf` — **MODIFY** (add ~120 lines after line ~135)
- `src/core/trigger.sh` — **MODIFY** (add 1 source line after line 44)

### Verification
```bash
cd ../tavs-dynamic-titles  # or wherever worktree is
source src/config/defaults.conf
source src/core/context-data.sh
# Test all 21 food scale entries
for pct in 0 5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100; do
    echo "$pct%: $(resolve_context_token CONTEXT_FOOD $pct)"
done
# Verify: 0%→💧, 5%→🥬, 10%→🥦, ..., 50%→🧀, ..., 100%→🍫

# Test bar tokens
resolve_context_token CONTEXT_BAR_H 0    # → ░░░░░
resolve_context_token CONTEXT_BAR_H 50   # → ▓▓░░░
resolve_context_token CONTEXT_BAR_H 100  # → ▓▓▓▓▓
resolve_context_token CONTEXT_BAR_HL 50  # → ▓▓▓▓▓░░░░░

# Test other tokens
resolve_context_token CONTEXT_ICON 0     # → ⚪
resolve_context_token CONTEXT_ICON 50    # → 🟡
resolve_context_token CONTEXT_ICON 100   # → ⚫
resolve_context_token CONTEXT_NUMBER 90  # → 9️⃣
resolve_context_token CONTEXT_NUMBER 100 # → 🔟
resolve_context_token CONTEXT_PCT 85     # → 85%
```

### Definition of Done
- [ ] All 10 token types produce correct output for 0%, 50%, 100%
- [ ] All 21 food scale entries match Spec Section 7.1 exactly
- [ ] Bridge state file parsing works with safe key=value pattern
- [ ] Empty/missing data returns empty strings (no errors, no crashes)
- [ ] Icon arrays in defaults.conf match Spec Section 7 exactly
- [ ] Module sourced in trigger.sh without errors

---

## Phase 2: Per-State Title Format System

**Scope:** Modify title composition to use per-state format templates with 4-level fallback
chain, and register new variables in agent resolution.

### Implementation Steps

1. **Modify `compose_title()` in `src/core/title-management.sh`** — lines 322-335.

   **Replace lines 322-324** (single format) with 4-level fallback:
   ```bash
   # 4-level format fallback: agent+state → agent → global+state → global
   local _default_format='{FACE} {STATUS_ICON} {AGENTS} {SESSION_ICON} {BASE}'
   local state_upper
   state_upper=$(printf '%s' "$state" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

   # Level 1: Agent-specific + state-specific (e.g., CLAUDE_TITLE_FORMAT_PERMISSION)
   local _agent_state_var="TITLE_FORMAT_${state_upper}"
   local format=""
   eval "format=\${${_agent_state_var}:-}"

   # Level 2: Agent-specific all-states (e.g., CLAUDE_TITLE_FORMAT)
   [[ -z "$format" ]] && format="${TITLE_FORMAT:-}"

   # Level 3: Global state-specific (e.g., TAVS_TITLE_FORMAT_PERMISSION)
   if [[ -z "$format" ]]; then
       eval "format=\${TAVS_TITLE_FORMAT_${state_upper}:-}"
   fi

   # Level 4: Global default (backward compatible)
   [[ -z "$format" ]] && format="${TAVS_TITLE_FORMAT:-$_default_format}"

   local title="$format"
   ```

   **Note on `TITLE_FORMAT` and `TITLE_FORMAT_*`**: These bare variable names are set by
   `_resolve_agent_variables()` from `{AGENT}_TITLE_FORMAT` / `{AGENT}_TITLE_FORMAT_{STATE}`.
   For example, when `TAVS_AGENT=claude`, `_resolve_agent_variables()` will try
   `CLAUDE_TITLE_FORMAT_PERMISSION` → `UNKNOWN_TITLE_FORMAT_PERMISSION` → (DEFAULT_ check).

   **Add new token substitutions** after line 332 (after existing 5 tokens), before the
   space cleanup sed at line 335:
   ```bash
   # Context & metadata tokens — only resolve when format contains them
   if [[ "$title" == *"{CONTEXT_"* || "$title" == *"{MODEL}"* || \
         "$title" == *"{COST}"* || "$title" == *"{DURATION}"* || \
         "$title" == *"{LINES}"* || "$title" == *"{MODE}"* ]]; then
       load_context_data  # From context-data.sh
       # Context display tokens (10 types)
       title="${title//\{CONTEXT_PCT\}/$(resolve_context_token CONTEXT_PCT "$TAVS_CONTEXT_PCT")}"
       title="${title//\{CONTEXT_FOOD\}/$(resolve_context_token CONTEXT_FOOD "$TAVS_CONTEXT_PCT")}"
       title="${title//\{CONTEXT_FOOD_10\}/$(resolve_context_token CONTEXT_FOOD_10 "$TAVS_CONTEXT_PCT")}"
       title="${title//\{CONTEXT_BAR_H\}/$(resolve_context_token CONTEXT_BAR_H "$TAVS_CONTEXT_PCT")}"
       title="${title//\{CONTEXT_BAR_HL\}/$(resolve_context_token CONTEXT_BAR_HL "$TAVS_CONTEXT_PCT")}"
       title="${title//\{CONTEXT_BAR_V\}/$(resolve_context_token CONTEXT_BAR_V "$TAVS_CONTEXT_PCT")}"
       title="${title//\{CONTEXT_BAR_VM\}/$(resolve_context_token CONTEXT_BAR_VM "$TAVS_CONTEXT_PCT")}"
       title="${title//\{CONTEXT_BRAILLE\}/$(resolve_context_token CONTEXT_BRAILLE "$TAVS_CONTEXT_PCT")}"
       title="${title//\{CONTEXT_NUMBER\}/$(resolve_context_token CONTEXT_NUMBER "$TAVS_CONTEXT_PCT")}"
       title="${title//\{CONTEXT_ICON\}/$(resolve_context_token CONTEXT_ICON "$TAVS_CONTEXT_PCT")}"
       # Session metadata tokens
       title="${title//\{MODEL\}/$TAVS_CONTEXT_MODEL}"
       title="${title//\{COST\}/$(_format_cost "$TAVS_CONTEXT_COST")}"
       title="${title//\{DURATION\}/$(_format_duration "$TAVS_CONTEXT_DURATION")}"
       title="${title//\{LINES\}/$(_format_lines "$TAVS_CONTEXT_LINES_ADD")}"
       title="${title//\{MODE\}/$TAVS_PERMISSION_MODE}"
   fi
   ```

2. **Modify `_resolve_agent_variables()` in `src/core/theme-config-loader.sh`** — line 114.

   Add to the `vars` array after `SPINNER_FACE_FRAME`:
   ```bash
       SPINNER_FACE_FRAME
       # Per-state title format overrides
       TITLE_FORMAT
       TITLE_FORMAT_PROCESSING TITLE_FORMAT_PERMISSION TITLE_FORMAT_COMPLETE
       TITLE_FORMAT_IDLE TITLE_FORMAT_COMPACTING TITLE_FORMAT_SUBAGENT
       TITLE_FORMAT_TOOL_ERROR TITLE_FORMAT_RESET
   ```

   **Note on DEFAULT_ fallback (line 129):** The condition matches `*_PERMISSION`,
   `*_PROCESSING`, etc. — so `TITLE_FORMAT_PERMISSION` will accidentally trigger the
   DEFAULT_ check. This is **harmless**: no `DEFAULT_TITLE_FORMAT_*` variables are defined
   anywhere, so the eval produces empty string. The real fallback (Levels 3-4) is in
   `compose_title()`. `TITLE_FORMAT` (without suffix) won't match any pattern, which is
   correct — its fallback is `TAVS_TITLE_FORMAT` in compose_title().

### Files to Modify
- `src/core/title-management.sh` — `compose_title()` at lines 322-335 (~40 lines changed/added)
- `src/core/theme-config-loader.sh` — `_resolve_agent_variables()` vars array at line 114 (~9 lines added)

### Verification
```bash
# Test per-state format selection (with mock context data)
TAVS_CONTEXT_PCT=50 \
TAVS_TITLE_FORMAT_PERMISSION="{FACE} {CONTEXT_PCT}" \
  ./src/core/trigger.sh permission
# → Title should contain "50%"

# Test fallback to global when no per-state format
unset TAVS_TITLE_FORMAT_PERMISSION
./src/core/trigger.sh permission
# → Uses TAVS_TITLE_FORMAT (standard title)

# Test agent-specific override
CLAUDE_TITLE_FORMAT_PERMISSION="{FACE} {CONTEXT_FOOD} {MODEL}" \
  ./src/core/trigger.sh permission
# → Should show food emoji

# Test backward compatibility
./src/core/trigger.sh processing
# → Unchanged from current behavior (no per-state format for processing)
```

### Definition of Done
- [ ] 4-level fallback chain works: agent+state → agent → state → global
- [ ] Backward compatible: no per-state format set → uses `TAVS_TITLE_FORMAT`
- [ ] New tokens resolved only when present in format string (performance guard)
- [ ] Empty tokens collapse cleanly (existing sed cleanup handles it)
- [ ] Existing title behavior unchanged for states without per-state formats

---

## Phase 3: StatusLine Bridge

**Scope:** Create the silent bridge script, extract transcript_path from hook JSON.

### Implementation Steps

1. **Create `src/agents/claude/statusline-bridge.sh`** (~60 lines) — silent data siphon.

   **Critical: TTY resolution.** The bridge runs in StatusLine context (stdin is piped JSON).
   It CANNOT source `terminal-osc-sequences.sh` (too much baggage — sources themes.sh, etc.).
   Must **inline** the TTY resolution pattern from `terminal-osc-sequences.sh:41-58`:
   ```bash
   _resolve_tty() {
       local tty_dev
       tty_dev=$(ps -o tty= -p $PPID 2>/dev/null)
       tty_dev="${tty_dev// /}"
       if [[ -n "$tty_dev" && "$tty_dev" != "??" && "$tty_dev" != "-" ]]; then
           [[ "$tty_dev" != /dev/* ]] && tty_dev="/dev/$tty_dev"
           [[ -w "$tty_dev" ]] && echo "$tty_dev" && return 0
       fi
       if { echo -n "" > /dev/tty; } 2>/dev/null; then
           echo "/dev/tty"
           return 0
       fi
       return 1
   }
   ```

   **Also inline** state directory logic from `spinner.sh:16-24`:
   ```bash
   _get_state_dir() {
       if [[ -n "${XDG_RUNTIME_DIR:-}" && -d "$XDG_RUNTIME_DIR" ]]; then
           echo "$XDG_RUNTIME_DIR/tavs"
       else
           echo "${HOME}/.cache/tavs"
       fi
   }
   ```

   **Extraction approach** (no jq, matching `claude/trigger.sh:27-28` pattern):
   ```bash
   _extract() {
       sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\",$]*\).*/\1/p" | head -1
   }
   ```

   Fields to extract from StatusLine JSON:
   - `used_percentage` → `pct`
   - `display_name` → `model`
   - `total_cost_usd` → `cost`
   - `total_duration_ms` → `duration`
   - `total_lines_added` → `lines_add`
   - `total_lines_removed` → `lines_rem`

   **Atomic write** using mktemp+mv to `{state_dir}/context.{TTY_SAFE}`:
   ```bash
   tmp_file=$(mktemp "${state_file}.tmp.XXXXXX" 2>/dev/null) || exit 0
   cat > "$tmp_file" << EOF
   # TAVS Context Bridge - $(date -u +%Y-%m-%dT%H:%M:%S+00:00)
   pct=${pct:-}
   model=${model:-}
   cost=${cost:-}
   duration=${duration:-}
   lines_add=${lines_add:-}
   lines_rem=${lines_rem:-}
   ts=$(date +%s)
   EOF
   mv "$tmp_file" "$state_file" 2>/dev/null
   ```

   **Zero stdout** — the entire script writes nothing to stdout. This is critical for
   coexistence with the user's existing statusline output.

2. **Modify `src/agents/claude/trigger.sh`** — add transcript_path extraction.

   Insert inside the existing `if [[ -n "$_tavs_stdin" ]]` block (between lines 29 and 30),
   after the permission_mode extraction:
   ```bash
       # Extract transcript_path for context fallback estimation
       _transcript=$(printf '%s' "$_tavs_stdin" | \
           sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
       [[ -n "$_transcript" ]] && export TAVS_TRANSCRIPT_PATH="$_transcript"
   ```

### Files to Create/Modify
- `src/agents/claude/statusline-bridge.sh` — **CREATE** (~60 lines, chmod +x)
- `src/agents/claude/trigger.sh` — **MODIFY** (add ~4 lines inside existing if block)

### Verification
```bash
# Test bridge silence
output=$(echo '{"context_window":{"used_percentage":72},"model":{"display_name":"Opus"},"cost":{"total_cost_usd":1.23,"total_duration_ms":300000,"total_lines_added":42,"total_lines_removed":7}}' \
  | ./src/agents/claude/statusline-bridge.sh)
[[ -z "$output" ]] && echo "PASS: silent" || echo "FAIL: produced output"

# Verify state file was written
cat ~/.cache/tavs/context.* 2>/dev/null
# Should show: pct=72, model=Opus, cost=1.23, ts=...

# Test bridge with missing fields (graceful handling)
echo '{"context_window":{}}' | ./src/agents/claude/statusline-bridge.sh
# Should write state file with empty values, not crash
```

### Definition of Done
- [ ] Bridge produces zero bytes of stdout
- [ ] State file written atomically (mktemp+mv) to `~/.cache/tavs/context.{TTY_SAFE}`
- [ ] State file uses safe key=value format (no executable content)
- [ ] TTY_SAFE derived correctly using inlined `resolve_tty()` pattern
- [ ] Handles missing/malformed JSON gracefully (empty values, no crash)
- [ ] transcript_path extracted and exported in `claude/trigger.sh`
- [ ] Bridge is executable (`chmod +x`)

---

## Phase 4: Transcript Fallback

**Scope:** Complete the transcript file-size estimation (stubbed in Phase 1).

### Implementation Steps

1. **Complete `_estimate_from_transcript()` in `src/core/context-data.sh`**:
   ```bash
   _estimate_from_transcript() {
       local transcript_path="${1:-$TAVS_TRANSCRIPT_PATH}"
       [[ -z "$transcript_path" || ! -f "$transcript_path" ]] && return 1

       local file_size
       # macOS stat vs Linux stat
       file_size=$(stat -f%z "$transcript_path" 2>/dev/null \
           || stat -c%s "$transcript_path" 2>/dev/null)
       [[ -z "$file_size" || "$file_size" -eq 0 ]] && return 1

       # ~3.5 chars/token (Anthropic heuristic)
       local _default_ctx=200000
       local ctx_size="${TAVS_CONTEXT_WINDOW_SIZE:-$_default_ctx}"
       local estimated_tokens=$((file_size * 10 / 35))  # integer: file_size / 3.5
       local pct=$((estimated_tokens * 100 / ctx_size))
       [[ $pct -gt 100 ]] && pct=100

       TAVS_CONTEXT_PCT="$pct"
       return 0
   }
   ```

2. **Wire into `load_context_data`** fallback chain:
   ```
   1. Bridge state file fresh? → use it
   2. No bridge? transcript exists? → _estimate_from_transcript
   3. Neither? → all context vars stay empty → tokens collapse silently
   ```

### Files to Modify
- `src/core/context-data.sh` — complete `_estimate_from_transcript()` (~40 lines)

### Verification
```bash
# Create fake transcript of known size
dd if=/dev/zero bs=1 count=350000 of=/tmp/fake_transcript.jsonl 2>/dev/null
TAVS_TRANSCRIPT_PATH=/tmp/fake_transcript.jsonl
source src/config/defaults.conf
source src/core/context-data.sh
_estimate_from_transcript
echo "Estimated: $TAVS_CONTEXT_PCT%"
# 350000 / 3.5 = 100000 tokens → 100000 / 200000 * 100 = 50%
rm /tmp/fake_transcript.jsonl

# Test missing file
TAVS_TRANSCRIPT_PATH=/nonexistent
_estimate_from_transcript; echo "exit: $?"
# Should return 1, no error output

# Test empty file
touch /tmp/empty_transcript.jsonl
TAVS_TRANSCRIPT_PATH=/tmp/empty_transcript.jsonl
_estimate_from_transcript; echo "exit: $?"
# Should return 1
rm /tmp/empty_transcript.jsonl
```

### Definition of Done
- [ ] Returns estimated percentage from file size
- [ ] Handles missing/empty file gracefully (returns 1, no error output)
- [ ] Works on macOS (`stat -f%z`) and Linux (`stat -c%s`)
- [ ] Clamps result to 0-100
- [ ] Only sets `TAVS_CONTEXT_PCT` (no model/cost/duration from transcript)

---

## Phase 5: Configuration & Documentation

**Scope:** Update user config template and project documentation.

### Implementation Steps

1. **Update `src/config/user.conf.template`** (~60 lines added).

   Add after the title format section (around line 137, after `TAVS_AGENTS_FORMAT`):

   - **Per-state title formats** section (commented examples):
     ```
     # TAVS_TITLE_FORMAT_PROCESSING="{FACE} {STATUS_ICON} {CONTEXT_FOOD} {CONTEXT_PCT} ..."
     # TAVS_TITLE_FORMAT_PERMISSION="{FACE} {STATUS_ICON} {CONTEXT_FOOD} {CONTEXT_PCT} {BASE}"
     # TAVS_TITLE_FORMAT_COMPLETE="{FACE} {STATUS_ICON} {COST} {SESSION_ICON} {BASE}"
     # TAVS_TITLE_FORMAT_COMPACTING="{FACE} {STATUS_ICON} {CONTEXT_PCT} {BASE}"
     ```

   - **Per-agent title formats** section (commented examples):
     ```
     # CLAUDE_TITLE_FORMAT_PERMISSION="{FACE} {STATUS_ICON} {CONTEXT_FOOD} {CONTEXT_PCT} {MODEL} {BASE}"
     # GEMINI_TITLE_FORMAT="{FACE} {STATUS_ICON} {BASE}"
     ```

   - **Context icon customization** section (commented copy-paste arrays)

   - **StatusLine bridge setup** section (step-by-step guide)

2. **Update `CLAUDE.md`**:
   - Add new tokens to the "Title Format Tokens" table
   - Add per-state format documentation section
   - Add StatusLine bridge setup guide
   - Add context icon customization section

### Files to Modify
- `src/config/user.conf.template` — add ~60 lines of new sections
- `CLAUDE.md` — update title format section, add bridge setup

### Definition of Done
- [ ] user.conf.template includes all new settings as commented examples
- [ ] Bridge setup documented with concrete shell script examples
- [ ] Icon customization documented with copy-paste ready arrays
- [ ] CLAUDE.md updated with new tokens, per-state formats, bridge setup
- [ ] All new tokens listed with descriptions and examples

---

## Phase 6: Deploy & Integration Test

**Scope:** Copy to plugin cache and test live with Claude Code.

### Implementation Steps

1. **Deploy to plugin cache:**
   ```bash
   CACHE="$HOME/.claude/plugins/cache/terminal-agent-visual-signals/tavs/2.0.0"
   cp src/core/*.sh "$CACHE/src/core/"
   mkdir -p "$CACHE/src/config" && cp src/config/*.conf "$CACHE/src/config/"
   cp src/agents/claude/*.sh "$CACHE/src/agents/claude/"
   ```

2. **Configure bridge** in user's statusline script (or create one)

3. **Live test sequence:**
   - SessionStart → reset title (no context tokens, standard format)
   - UserPromptSubmit → processing title (standard format — no per-state override)
   - PermissionRequest → **food emoji + percentage visible** (per-state format!)
   - Stop → complete title (standard format)
   - Notification idle → idle title
   - PreCompact → compacting title with context % (per-state format)
   - Remove bridge from statusline config → verify graceful fallback
   - Remove transcript → verify tokens collapse silently (no broken titles)
   - Test per-agent overrides: set `CLAUDE_TITLE_FORMAT_PERMISSION` in user.conf

### Definition of Done
- [ ] All 8 trigger states produce correct titles in live Claude Code session
- [ ] Context percentage updates in real-time via bridge
- [ ] Fallback works when bridge not configured (transcript estimate)
- [ ] Graceful degradation when neither bridge nor transcript exists
- [ ] Per-agent overrides work
- [ ] No regressions in existing title behavior (processing, complete, idle)
- [ ] Empty tokens collapse — no double spaces or broken formatting

---

## Risk Areas

| Risk | Impact | Mitigation |
|------|--------|------------|
| Bridge TTY_SAFE differs from hook TTY_SAFE | Bridge writes to wrong state file path → context data invisible to hooks | **Inline same `resolve_tty()` pattern** from `terminal-osc-sequences.sh:41-58` using `$PPID`; verify with live test |
| DEFAULT_ fallback matches TITLE_FORMAT_PERMISSION | Could pick up unintended `DEFAULT_TITLE_FORMAT_PERMISSION` | **Harmless** — no such variable defined. Document in code comments. |
| `eval` for dynamic var resolution | Code injection if state names untrusted | **Safe** — state names are hardcoded constants (processing, permission, etc.) |
| StatusLine not configured by user | No bridge data → no context % | **Graceful** — transcript fallback → empty tokens → clean collapse |
| Zsh brace expansion | `${VAR:-{FACE}...}` breaks in zsh | **Use intermediate vars** consistently (documented in MEMORY.md) |
| StatusLine debounce (300ms) | Bridge data may lag slightly | **Acceptable** — 300ms is imperceptible for title display |
| Bridge state file left stale | Old data displayed after session ends | **Staleness check** — `TAVS_CONTEXT_BRIDGE_MAX_AGE=30` rejects data older than 30s |

---

## Sequencing & Dependencies

```
Phase 0 (worktree)
    │
    └──→ Phase 1 (context-data.sh + defaults.conf + trigger.sh source)
              │
              ├──→ Phase 2 (per-state formats in title-management.sh + theme-config-loader.sh)
              ├──→ Phase 3 (statusline-bridge.sh + claude/trigger.sh transcript_path)
              └──→ Phase 4 (transcript fallback in context-data.sh)
                        │
                        └──→ Phase 5 (config template + CLAUDE.md docs)
                                  │
                                  └──→ Phase 6 (deploy to plugin cache + live integration test)
```

- **Phase 0** must complete first (working directory)
- **Phase 1** must complete before Phases 2-4 (all depend on context-data.sh and defaults.conf)
- **Phases 2, 3, 4** are partially parallelizable (touch different files), but Phase 2 uses Phase 1 functions
- **Phase 5** must wait for all functionality (needs to document what exists)
- **Phase 6** is the final integration test (needs everything deployed)
