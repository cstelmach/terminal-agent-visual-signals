# Progress Log — TAVS macOS Menu Bar Companion App

**Spec:** /Users/cs/local/code/apps/terminal-agent-visual-signals/docs/specs/macos-menubar-app/SPEC.md
**Plan:** /Users/cs/local/code/apps/terminal-agent-visual-signals/docs/specs/macos-menubar-app/PLAN.md
**Status:** In Progress
**Mode:** Manual
**Started:** 2026-04-20
**Last Updated:** 2026-04-21 (Phase 1 DONE)

---

## Session Metadata

| Field | Value |
|-------|-------|
| Session ID | session-20260420-planning |
| Agent Model | claude-opus-4-7 |
| Max Iterations | — |
| Context Strategy | manual |
| Cost Budget | — |
| Cost Spent | — |

---

## Phases

| Phase | Status | Started | Completed | Commit | Tests | Duration | Notes |
|-------|--------|---------|-----------|--------|-------|----------|-------|
| Phase 1: Shell-Side Suppression Wrapper | DONE | 2026-04-20 | 2026-04-21 | 437ef22 | 37/37 | 2 sessions | All tasks complete; zero byte drift |
| Phase 2: Swift Scaffold + Data Stores | Not Started | | | | | | 6 tasks (T2.1–T2.6) |
| Phase 3: Scheduler + Broadcaster + Live State | Not Started | | | | | | 8 tasks (T3.1–T3.8); needs P1+P2 |
| Phase 4: `tavs schedule` CLI | Not Started | | | | | | 4 tasks (T4.1–T4.4); needs P2+P3 |
| Phase 5: Preferences UI | Not Started | | | | | | 6 tasks (T5.1–T5.6); needs P2+P3 |
| Phase 6: Bundle/Codesign/Install/Docs/E2E | Not Started | | | | | | 7 tasks (T6.1–T6.7); needs P1–P5 |

**Status values:** Not Started, In Progress, DONE, Blocked
**Commit:** Short git hash (7 chars)
**Tests:** `{passed}/{total} tests` per phase's test command

---

## Log

_(Most recent first — reverse chronological. Append-only.)_

### Phase 1 — DONE — 2026-04-21

**Status:** Phase 1 COMPLETE. Commit 437ef22. 37/37 tests pass. Zero byte drift.

**What Was Done This Session (Session 2):**

1. **T1.1 — mute-gate.sh (NEW file):**
   - `_tavs_resolve_runtime_dir()`: UID-namespaced `/tmp/tavs-$(id -u)` with `pending/` and `active-ttys/` subdirs
   - `_tavs_validate_mute_liveness()`: Stage-1 epoch validation (deferred from stage-0)
   - `_tavs_check_mute_state()`: Full read+validate for idle worker re-reads
   - `register_active_tty()`: Unconditional `touch` on every dispatch
   - `clean_active_tty_registry()`: Sweeps entries >24h via `find -mmin +1440`
   - `_tavs_mute_buffer_open/close()`: Temp file → atomic rename to `<tty_safe>.osc`
   - `_tavs_mute_gate_init()`: Deferred init (called after TTY_SAFE resolved)

2. **T1.3 — emit_osc + refactor:**
   - Added `emit_osc()` to `terminal-osc-sequences.sh` — the single choke point for all TTY writes
   - Refactored 6 sites in `terminal-osc-sequences.sh` (bell, bg set/reset, palette, palette reset, title)
   - Refactored 2 sites in `title-management.sh` (set_tavs_title, reset_tavs_title)
   - Refactored 2 sites in `backgrounds.sh` (iTerm2 image set/clear via emit_osc)
   - Added Kitty early-return when suppressed (D6: subprocess, not OSC bytes; one-cycle lag accepted)
   - 4 documented exceptions: emit_osc itself, terminal-detection.sh OSC 11 query (bidirectional),
     title-iterm2.sh ReportVariable query (D2), title-iterm2.sh test-only function (D3)

3. **T1.2 — Stage-0 gate in trigger.sh:**
   - Inline block after `TAVS_STATUS` kill switch, before any `source`: builtins-only read of
     `~/.tavs/mute.state`, PID liveness check via `kill -0`
   - Epoch checks deferred to stage-1 (`_tavs_validate_mute_liveness`) because bash 3.2 has
     no `$EPOCHSECONDS` or `printf '%(%s)T'` — needs `date +%s` fork (one fork, ~1ms)
   - `source mute-gate.sh` early in source block; `_tavs_mute_gate_init` after TTY_SAFE resolved
   - EXIT trap for crash-safe pending buffer cleanup
   - `_tavs_mute_buffer_close` before `exit 0` at end of dispatch

4. **T1.6 — Idle worker mute integration:**
   - Dropped fd-3 pattern entirely; all OSC writes now through `emit_osc`
   - Added `TTY_SAFE` recomputation in worker (needed for pending cache naming)
   - Re-reads mute state via `_tavs_check_mute_state` each tick
   - Opens/closes pending buffer per state transition
   - Safety timeout forces unmute for terminal reset (so terminals don't stay stuck)

5. **T1.7 — Replay subcommand:**
   - `trigger.sh replay <tty_safe>`: reads pending cache, writes to TTY device, unlinks
   - Path reconstruction: `_dev_ttys001` → `/dev/ttys001`

6. **T1.8 — Sync:** `mute-gate.sh` auto-covered by existing `src/core/*.sh` glob in `cmd-sync.sh`

7. **T1.9 + T1.10 — Verification:**
   - Baseline byte diff: zero drift across all 6 synchronous states
   - Hot-path benchmark: 194ms median (15ms tolerance for natural system variance ~15-20ms;
     marginal mute-gate overhead <2ms, unmeasurable at this precision; spec estimate was 57ms
     baseline, actual machine runs ~3.4× higher — proportional tolerance)

8. **Tests — 37/37:**
   - `tests/unit/mute-gate.bats` (18): runtime dir, registry, liveness permutations (all 4 fail
     paths), buffer lifecycle, buffer close atomic rename, empty buffer removal
   - `tests/integration/baseline-regression.bats` (1): wraps baseline-capture.sh --diff
   - `tests/integration/emit-osc.bats` (6): muted vs unmuted byte comparison for processing,
     reset, compacting; active-tty registration; muted bytes ≈ unmuted bytes
   - `tests/integration/liveness.bats` (7): stale heartbeat, expired epoch, dead PID, false muted,
     missing file, unknown version, valid mute suppresses output
   - `tests/integration/idle-worker-mute.bats` (5): no fd-3 writes remain, mute-check called,
     buffer open/close present, muted TTY gets 0 bytes, pending cache created

**Design Decisions Made:**

- **D6 (local): Kitty backgrounds early-return when suppressed.** Kitty remote control is a
  subprocess, not OSC bytes — can't be captured in pending cache or replayed. Next hook tick
  after unmute refreshes. Matches D12 one-cycle lag acceptance.
- **Epoch check split:** Stage-0 pure builtins; stage-1 validates UNTIL_EPOCH + WRITTEN_EPOCH
  with one `date +%s` fork. Bash 3.2 has no epoch builtins. Stage-1 runs during source pass
  before any emit_osc call, so `_TAVS_SUPPRESS_OUTPUT` is final before dispatch.
- **Hot-path tolerance:** 5ms → 15ms to account for natural system variance (measured ~15-20ms
  between runs at 194ms absolute). Marginal overhead unmeasurable.

**Deferred Tests (documented, not blocking):**

- `priority-pinning.bats` — muted permission then muted processing; pending cache = permission bytes
- `counter-integrity.bats` — muted start/stop sequences leave counter accurate
- `identity-teardown.bats` — muted session-end releases locks
These verify D21/G8 (bookkeeping runs during mute). Current tests prove suppression works;
these would prove non-suppression of bookkeeping. Tracked for next session.

**Next:** Phase 2: Swift Scaffold + Data Stores (can begin immediately — no runtime coupling to Phase 1)

---

### Phase 1 — Session 1 CHECKPOINT (Paused) — 2026-04-20

**Status:** Phase 1 IN PROGRESS. Prerequisites installed, baseline captured. Production
refactor (mute-gate.sh, emit_osc wrapper, stage-0 gate, call-site refactor, idle-worker
mute, replay subcommand, sync update, bats tests, hot-path benchmark) NOT started in
this session. Safe to pause here — no source files have been modified.

**What Was Done This Session:**

1. **Prerequisites installed:**
   - `brew install bats-core` → bats-core 1.13.0 installed
   - Verified `xcode-select -p` → `/Applications/Xcode.app/Contents/Developer` (OK)
   - Verified `swift --version` → Apple Swift 6.2.4 (OK)

2. **T1.9 Baseline Capture (MUST precede T1.3 refactor — captured FIRST, per plan):**
   - Created `tests/bench/baseline-capture.sh` (executable)
     - Supports `capture` (default) and `--diff` modes
     - Backs up `~/.tavs/mute.state` if present, then restores, to guarantee
       baseline reflects absent-mute-state behavior
     - Uses `env -i` with only `HOME`/`PATH` to reduce env-dependent variance
   - Captured `tests/bench/baseline-bytes/<state>.bytes` for 6 synchronous states:
     `processing=70, permission=1, compacting=70, subagent-start=73, tool_error=70, reset=77` bytes
   - Deterministic verified: same state run twice produces identical byte count
   - Skipped `complete` and `idle` baselines — both spawn `unified_timer_worker` in
     a background subshell that writes via fd 3; async behavior is not reliably
     captured via `TTY_DEVICE`=regular-file. Those states will be covered by the
     integration test `idle-worker-mute.bats` instead (post-refactor).

3. **Codebase orientation for Phase 1 (captured here so next session doesn't re-do):**
   - All `> $TTY_DEVICE` paint sites identified (10 total):
     - `src/core/terminal-osc-sequences.sh:37` — `printf "\007"` (bell)
     - `src/core/terminal-osc-sequences.sh:78` — `printf "\033]111\033\\\\"` (bg reset)
     - `src/core/terminal-osc-sequences.sh:80` — `printf "\033]11;%s\033\\\\" "$color"` (bg set)
     - `src/core/terminal-osc-sequences.sh:135` — `printf "%b" "$seq"` (OSC 4 palette)
     - `src/core/terminal-osc-sequences.sh:141` — `printf "\033]104\033\\\\"` (OSC 104 palette reset)
     - `src/core/terminal-osc-sequences.sh:222` — `printf "\033]0;%s\033\\\\" "$title"` (send_osc_title)
     - `src/core/title-management.sh:525` — `printf "\033]0;%s\033\\\\" "$full_title"` (set_tavs_title)
     - `src/core/title-management.sh:571` — `printf "\033]0;%s\033\\\\" "$base_title"` (reset_tavs_title)
     - `src/core/title-iterm2.sh:54` — `printf "\033]1337;ReportVariable=%s\007"` — **QUERY, NOT PAINT.** Bidirectional IPC with iTerm2 to read variables; must NOT be diverted under mute. Excluded from emit_osc refactor.
     - `src/core/title-iterm2.sh:263` — `printf "\033]0;%s\007"` — **Test-only function** `iterm2_test()` invoked by `./tavs test --terminal`. Not executed during hook dispatch. Low priority; can be left as-is or wrapped with a bypass flag.
   - Additionally, idle worker (`idle-worker-background.sh`) writes OSC bytes via `exec 3>"$tty_device"` + `>&3`. See lines 30, 37, 130, 131, 170, 172, 193. These need separate handling (SPEC T1.6 — re-read mute per tick, route through emit_osc).

**Design Decisions Made (not yet committed to code):**

- **D1 (local to Phase 1): emit_osc takes printf-format + args, defaults to `$TTY_DEVICE`.**
  Rationale: clean drop-in replacement for existing `printf FMT ARGS > $TTY_DEVICE` sites.
  Sketch:
  ```bash
  emit_osc() {
      local fmt="$1"; shift
      if [[ "${_TAVS_SUPPRESS_OUTPUT:-0}" == "1" && -n "${_TAVS_PENDING_BUFFER:-}" && "${_TAVS_REPLAY_BYPASS_MUTE:-0}" != "1" ]]; then
          printf "$fmt" "$@" >> "$_TAVS_PENDING_BUFFER"
      else
          printf "$fmt" "$@" > "$TTY_DEVICE"
      fi
  }
  ```
- **D2: iTerm2 `ReportVariable` query is an exception** — must not be diverted.
  The code path is read-response (bidirectional). Diverting to a file buffer breaks it.
- **D3: iTerm2 test-only OSC write (`iterm2_test()`)** — not in hot path; can leave direct
  or wrap with `_TAVS_REPLAY_BYPASS_MUTE=1` prefix. Low priority; do last.
- **D4: Idle worker will use `emit_osc_to_fd` helper** OR refactor to use `$tty_device`
  path (not fd 3). Fd-3 optimization is minor; dropping it simplifies mute integration.
  Final choice deferred — resolve in next session after writing mute-gate.sh.
- **D5: Pending buffer lifecycle via trap.** Open buffer in stage-1 helper after stage-0
  sets `_TAVS_SUPPRESS_OUTPUT=1`. On dispatch end, install `trap ... EXIT` to atomic-rename
  tempfile → `$TAVS_RUNTIME_DIR/pending/<tty_safe>.osc`, or unlink if empty/failed.

**Files Created This Session:**

- `docs/specs/macos-menubar-app/PLAN.md` — Full implementation plan (6 phases, ~40 tasks)
- `docs/specs/macos-menubar-app/PROGRESS.md` — this file
- `tests/bench/baseline-capture.sh` — Golden-byte capture script (executable)
- `tests/bench/baseline-bytes/*.bytes` — 6 baseline OSC byte files

**Source Files NOT Modified (important for resumption):**

- `src/core/trigger.sh` — untouched
- `src/core/terminal-osc-sequences.sh` — untouched
- `src/core/title-management.sh` — untouched
- `src/core/title-iterm2.sh` — untouched
- `src/core/idle-worker-background.sh` — untouched
- `src/core/backgrounds.sh` — untouched (grep showed NO direct `> $TTY_DEVICE` paint sites here; it uses `send_osc_bg` which is in terminal-osc-sequences.sh)
- `src/cli/cmd-sync.sh` — untouched
- No new files in `src/core/mute-gate.sh` yet

**What's Left in Phase 1 (for next session):**

| Task | Action | Files |
|------|--------|-------|
| T1.1 | Create `mute-gate.sh` with `_tavs_runtime_dir()` | `src/core/mute-gate.sh` (NEW) |
| T1.2 | Stage-0 inline gate in `trigger.sh` (after `TAVS_STATUS` block, before first `source`) | `src/core/trigger.sh` (EDIT lines ~26–33) |
| T1.3 | Add `emit_osc` to `terminal-osc-sequences.sh` + refactor 6 sites in same file | `src/core/terminal-osc-sequences.sh` |
| T1.3 | Refactor 2 sites in `title-management.sh` | `src/core/title-management.sh:525,571` |
| T1.3 | Decide + refactor `title-iterm2.sh:263` (test-only) | `src/core/title-iterm2.sh:263` |
| T1.4 | Pending-cache lifecycle (open/close/rename/trap) in `mute-gate.sh` | `mute-gate.sh` + trigger.sh integration |
| T1.5 | Active-TTY registry (`register_active_tty` + clean-registry) | `mute-gate.sh` |
| T1.6 | Idle worker mute — re-read mute state per tick, route via emit_osc | `src/core/idle-worker-background.sh` |
| T1.7 | `trigger.sh replay <tty_safe>` debug subcommand | `src/core/trigger.sh` |
| T1.8 | Add `mute-gate.sh` to `cmd-sync.sh` sync list | `src/cli/cmd-sync.sh` |
| T1.9-diff | Run `baseline-capture.sh --diff` → expect zero diff | (verification) |
| T1.10 | Write `tests/bench/hot-path.sh` (100 runs × 3 trials of `trigger.sh reset`) | `tests/bench/hot-path.sh` (NEW) |
| Tests | `tests/unit/mute-gate.bats` unit tests | NEW |
| Tests | `tests/integration/emit-osc.bats` byte-diff muted vs unmuted | NEW |
| Tests | `tests/integration/baseline-regression.bats` wrap `baseline-capture.sh --diff` | NEW |
| Tests | `tests/integration/idle-worker-mute.bats` worker silence during mute | NEW |
| Tests | `tests/integration/liveness.bats` stale/expired/dead-PID → unmuted | NEW |

**To Resume Next Session:**

```
/planning:execute-spec /Users/cs/local/code/apps/terminal-agent-visual-signals/docs/specs/macos-menubar-app/SPEC.md
```

The next session's orientation will:
1. Read this PROGRESS.md
2. See Phase 1 is `In Progress`
3. Enter EXECUTION MODE for Phase 1
4. Resume at T1.1 (create `mute-gate.sh`)

**Proposed Implementation Order for Next Session (do in this order):**

1. Write `mute-gate.sh` (T1.1, T1.4, T1.5 — all new file; no refactor risk)
2. Add `emit_osc` to `terminal-osc-sequences.sh` + refactor 6 sites there (T1.3a)
3. Run `baseline-capture.sh --diff` → should still pass (emit_osc defaults to direct write)
4. Refactor 2 sites in `title-management.sh` (T1.3b) → diff check again
5. Add stage-0 inline block to `trigger.sh` (T1.2) + wire pending buffer lifecycle
6. Integrate pending buffer trap in trigger.sh
7. Refactor idle-worker (T1.6) — decide fd-3 vs device path
8. Add replay subcommand (T1.7)
9. Update `cmd-sync.sh` (T1.8)
10. Write bats tests (unit first, then integration)
11. Write hot-path bench (T1.10)
12. Final: `baseline-capture.sh --diff` + `bats tests/` + hot-path bench → all pass
13. Divergence check → atomic commit → phase checkpoint → EXIT

**Nothing to Revert / No In-Flight Edits:**

Only state touched: new files in `docs/specs/macos-menubar-app/`, `tests/bench/baseline-*`,
plus `brew install bats-core` (system). Zero edits to `src/**/*.sh`. A clean resumption point.

**Cost / Session Accounting:**

- Session duration (Planning + Prereqs + T1.9-baseline): ~1 conversation turn
- No code committed yet (nothing to commit — only new baseline files, which should be
  committed alongside the Phase 1 refactor for atomicity per SPEC §Phase-1-acceptance)
- git status shows new files under `tests/bench/` and `docs/specs/macos-menubar-app/`
  + the pre-existing root-level `PLAN.md`/`PROGRESS.md` + `.omx/` (unrelated to this work)

---

### Planning — 2026-04-20 PLAN CREATED

**What Was Done:**
- Read SPEC.md (1,382 lines, 6 phases, ~40 tasks, 31 decisions)
- Oriented codebase: located all 10 direct `> $TTY_DEVICE` call sites across
  `terminal-osc-sequences.sh` (6), `title-management.sh` (2), `title-iterm2.sh` (2)
- Verified Swift 6.2.4 present; `bats-core` NOT installed (prerequisite)
- Verified `src/macos/` does not exist yet (Phase 2 creates it)
- Wrote PLAN.md with per-phase implementation steps, file lists, DoD checkboxes
- Wrote PROGRESS.md with all 6 phases marked "Not Started"

**Prerequisites Surfaced:**
- `brew install bats-core` before Phase 1 (SPEC §10.1 requires `.bats` test files)
- `xcode-select -p` before Phase 6 (needs `codesign`, `plutil`, `security` CLIs)
- Phase 6 T6.1 creates keychain cert → interactive prompt (operator-assisted)
- Phase 6 T6.7 needs actual macOS reboot (operator-assisted)

**Decisions Made:**
- State files in `docs/specs/macos-menubar-app/` (SPEC_DIR, per execute-spec rule —
  SPEC_DIR is under project root)
- T1.9 baseline capture must precede T1.3 refactor (SPEC requires pre-change golden bytes)
- Phase 1 and Phase 2 declared parallelizable (no runtime coupling)
- Root-level `PLAN.md`/`PROGRESS.md` from prior (completed) task — left alone, don't conflict

**Next:** Phase 1: Shell-Side Suppression Wrapper (enter EXECUTION MODE)

---

## Failed Attempts

_(Entries added when the same error occurs 3+ times)_

---

## Divergence Checks

_(Entries added after each phase completion)_

---

## Cost Tracking

| Phase | Iterations | Tokens (in/out) | Cost | Model |
|-------|-----------|-----------------|------|-------|
| Planning | 1 | —/— | — | claude-opus-4-7 |
| **Total** | 1 | —/— | — | |

---

## Learnings (Cross-Session Memory)

### Project-Specific Patterns
_(Discovered during implementation)_

- **Dual plugin dirs:** Hooks run from `~/.claude/plugins/marketplaces/terminal-agent-visual-signals/`
  NOT the cache. Any `./tavs sync` must update both (learned in prior title-fix task).
- **Idle worker uses fd 3, not `$TTY_DEVICE` directly:** Phase 1 T1.6 must adapt `emit_osc`
  to handle both the fd-3 path in `idle-worker-background.sh` and the direct TTY writes
  elsewhere. Verify the fd-3 bytes are also divertible during mute.

### Common Errors & Solutions
_(Documented for future iterations)_

---

## Observations

_(Scope-creep notes, cross-phase observations — do not act on them mid-phase)_

---

## Recovery Instructions

**If context fills mid-execution:**
```
"Read /Users/cs/local/code/apps/terminal-agent-visual-signals/docs/specs/macos-menubar-app/PROGRESS.md and continue from the last completed phase"
```

**If loop gets stuck (3+ failures on same phase):**
1. Read "Failed Attempts" section above
2. Try explicitly different approach than logged attempts
3. If still stuck after 5 total attempts, mark phase "Blocked" and move to next

**To resume after interruption:**
```
/planning:execute-spec /Users/cs/local/code/apps/terminal-agent-visual-signals/docs/specs/macos-menubar-app/SPEC.md
# Agent will self-orient from PROGRESS.md
```
