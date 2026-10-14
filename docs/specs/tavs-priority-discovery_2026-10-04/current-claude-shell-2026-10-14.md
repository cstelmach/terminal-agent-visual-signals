## part07a: managed hook routing

> [!NOTE] EXPLICIT CLAUDE CLI REVIEW
> The caller selected real `claude -p`; Claude Hub retains disable, volume and concurrency controls.

> [!NOTE]
> Explicit native selection: real native Claude CLI under Hub controls, chosen by the caller. This is not an automatic fallback and is not evidence that the applied model or effort were observed.

# Claude Review Report

**Mode**: code-session
**Date**: 2026-10-14
**Focus**: all
**Intended report path**: `/tmp/claude-review-code-terminal-agent-visual-signals-main-20261014_000000.md`. This session had no tools, so no file was written. The full report follows inline for the parent to persist.

---

===DIMENSION_RATIONALE===
I used the five default code dimensions unchanged: correctness, security, maintainability, test coverage and performance. They fit this subscope, which is ordinary hook routing.

Scope reviewed:
- Adapters (Claude, Codex, Gemini, OpenCode).
- `trigger.sh` dispatch, `organizer-state.sh` intake, context and render bridge, and `helper-selection.sh`.
- The portable helper, renderer, policy and device writer.
- Idle worker, mute and lock gates, the suspension reader and standalone shellrc startup.
- Hooks JSON and the connected Bats and pytest suites.

Native catalogue, navigation, readability and Spaces acceptance cannot be established by any source review and remains unverified. Linux kernel and runtime tests also remain unverified. Linux behavior is judged here as source behavior against the existing README promise of macOS/Linux standalone signaling.
===END_DIMENSION_RATIONALE===

---

===EXECUTIVE_SUMMARY===
Overall grade: 5.9/10
Risk level: Medium

**Metadata.**
- Commit: 7ecfba2, clean checkout.
- Partition: 3, subscope 07a-managed-routing.
- Review was tool-free.

**Verdict: CONCERN.** All five dimensions score at least 5 and some score below 7.

**What holds up in source.**
- Backend selection is fixed once per intake and carried across `exec`.
- Failed native operations never switch to portable or raw output.
- Raw payloads, argv and stdin are dropped before core dispatch.
- Synthetic restores and idle renders revalidate inside the serialized writer.

**Where it falls short.**
- Every ordinary render now needs a helper. Neither available helper runs on Linux, so on Linux all agents and new shells produce zero visual output and print stderr warnings. This regresses a platform the README still lists.
- One connected Bats suite contradicts the current design and escapes test isolation.
- The legacy state directory keeps a non-UID-scoped, symlink-followable layout.
===END_EXECUTIVE_SUMMARY===

---

===ISSUES===

### Hypothesis falsification

**H1. A failed selected native operation silently switches to portable or raw output.**
Dismissed.
- `organizer-state.sh:53-56` exports the native choice even after a failed intake.
- `helper-selection.sh:21-39` imports that choice only with a matching intake hint and the same candidate.
- `_tavs_render_flush` (`organizer-state.sh:160-189`) has no raw `printf` path.
- `hook-observations.bats:434-476` covers this: native is probed twice and the portable helper is never called.

**H2. Raw hook payload, argv or stdin reaches core, process command lines or debug sinks.**
Dismissed.
- Adapters allowlist states and second arguments (`claude/trigger.sh:16-23`, `codex/trigger.sh:16-23`).
- Adapters `exec` core with `</dev/null` (`:33`, `:30`).
- `debug_log_invocation` writes only pid, a validated agent, state and a boolean (`trigger.sh:70-80`).
- Sentinel tests exist in `background-intent.bats:77-104` and `hook-observations.bats:210-261`.

**H3. Ordinary standalone signaling still works on Linux.**
Confirmed as defect. See R1.

**H4. The delayed tool-error restore can repaint over a newer Stop or SubagentStart.**
Dismissed.
- `trigger.sh:411-420` checks context first. The re-executed trigger is synthetic, so it skips counters, timers and records (`:205-230`, `:352-363`).
- `portable_renderer.py:189-213` revalidates context inside the lock.
- Barrier tests in `background-intent.bats:296-429` cover this race.

**H5. Gemini and OpenCode lose all output on the portable backend because `--organizer-context` rejects their provider.**
Unresolved. `portable_metadata.PROVIDERS` was not supplied. See the unresolved section below.

### CRITICAL
None substantiated.

### IMPORTANT

**R1. `src/core/portable_helper.py:72-79`, `src/core/helper-selection.sh:12-17,47-74`, `src/core/organizer-state.sh:160-168`, `src/shell/tavs-shellrc.sh:106-109`: all ordinary output stops on Linux.**
- **Trigger:** any hook or interactive shell on Linux, where `/Applications/TAVS.app` is absent.
- **Behavior:**
  1. The native candidate is not executable.
  2. The portable capability probe returns an error because `sys.platform != "darwin"`.
  3. `_TAVS_HELPER_BIN` therefore stays empty, and `_tavs_render_flush` sets `result=1`.
  4. Background, title, palette and bell output are all dropped, and every hook prints `tavs: current render unavailable`.
  5. Each new interactive shell prints `tavs: managed output helper unavailable or unsupported.`
- **Scope:** this covers Claude, Codex, Gemini, OpenCode and the idle worker. It is a source-grounded regression against `README.md:1086` ("macOS or Linux").
- **Note on documentation:** `README.md:1092` admits the repair is pending. That does not remove the regression for existing users.
- **Impact:** total loss of the product's core function on a documented platform, plus stderr noise at every shell start.
- **Smallest remedy (pick one):**
  - Add a bounded Linux branch to the portable helper using the same typed renderer.
  - Or change README requirements to macOS-only and make shellrc stay silent when no supported backend exists.
- **Criterion:** existing standalone compatibility; companion-optional output.
- **Discriminating test:** in a Linux container with an owned PTY and no native helper, run `trigger.sh processing` and assert `]11;` bytes on the PTY and empty stderr. Current source fails both assertions. A macOS run cannot discriminate this.

**R2. `tests/integration/lock-gate.bats:11-20,62-66,72-85,94-126`: the suite contradicts the current design and escapes isolation.**
- **Trigger:** running this suite, including through `tests/run-isolated.sh`.
- **Behavior:**
  - `run_trigger` uses `env -i`, which strips `TAVS_TEST_HELPER_BIN` and `TAVS_TEST_ROOT`.
  - Helper selection then probes the real `/Applications/TAVS.app/Contents/MacOS/TAVSApp` or the repo portable helper.
  - The test TTY is a regular file. The portable helper rejects it via `device_number`, and the native helper validates file descriptors.
  - Tests at `:76` and `:84` assert `pending_file_count -ge 1`, but pending output is no longer created anywhere (`mute-gate.sh:153-154`).
  - Tests at `:97,103,119,125` expect bytes in a regular file, which no managed helper writes.
  - The suite uses `mktemp -d` outside `TAVS_TEST_ROOT`.
- **Impact:**
  - The suite either fails deterministically or exercises the operator's installed app binary, breaching PLAN lines 59-66 ("explicitly built helper").
  - Lock fail-closed behavior through full dispatch has no valid current shell coverage.
- **Smallest remedy:** rewrite the suite like `liveness.bats`.
  - Require `TAVS_TEST_ROOT`.
  - Pass `TAVS_TEST_HELPER_BIN` through `env -i`.
  - Use a fake typed helper or an owned PTY.
  - Replace pending assertions with "no pending file" plus a `restricted` outcome.
- **Criterion:** PLAN phase 3 isolation; suspension and lock gate coverage.
- **Discriminating test:** with `TAVS_TEST_HELPER_BIN` pointing at a logging stub, the current suite never calls the stub, which proves the escape. After the fix, the stub log must show `--managed-render`.

**R3. `src/core/session-state.sh:16-28,96-101`, `src/core/title-state-persistence.sh:33,191-204`, `src/core/trigger.sh:91-92`: shared non-UID tmp root with symlink-followable writes.**
- **Trigger:** on a multi-user host, another local user pre-creates `/tmp/tavs` (world-writable, owned by them) before the victim's first hook.
- **Behavior:**
  - `mkdir -p` succeeds and `chmod 700` fails silently, because the victim does not own the directory.
  - The victim then writes `state.tmp.$$` with a predictable name, `mv`s it, and appends to `debug/title-trace.log` (`>>`) inside an attacker-controlled directory.
  - A pre-planted symlink therefore redirects victim writes or appends to any file the victim can write.
- **Context:** this is pre-existing. SPEC line 168 requires `/tmp/tavs-$UID` conventions, which `mute-gate.sh:20-23` follows.
- **Impact:** local file clobber or append; leaks session state and titles to another user.
- **Smallest remedy:**
  - Default `TAVS_TMP_DIR` to `/tmp/tavs-$UID/state`.
  - Verify the directory is owned by the effective user with mode 0700 before use, and refuse otherwise.
  - Use `mktemp` for the state temp file.
- **Criterion:** security; shared-state conventions.
- **Discriminating test:** as a second fixture user (or with `TAVS_TMP_DIR` set to a directory not owned by the caller containing a symlink `state.tmp.<pid>`), assert the hook refuses to write. Current source follows the symlink.

### MINOR

**R4. `src/core/terminal-osc-sequences.sh:15-22`: bell settings ignore user config.**
- `BELL_ON_*` is hardcoded after `theme-config-loader.sh` loads `user.conf` (`trigger.sh:47,49`), so any user `BELL_ON_COMPLETE=false` is overwritten.
- `defaults.conf:665-670` `ENABLE_BELL_*` is never consulted, and `ENABLE_BELL_COMPLETE="false"` still produces a completion BEL.
- **Remedy:** derive `BELL_ON_*` from `ENABLE_BELL_*` with `${VAR:-default}`.
- **Discriminating test:** set `ENABLE_BELL_COMPLETE=false`, run `complete`, and assert render field 22 equals `0`.

**R5. Per-hook and per-shell helper cost.**
- Sources: `hook-observations.bats:257-258` asserts 5 helper processes per hook. `tavs-shellrc.sh:106-120` runs about 4 synchronously during interactive shell startup.
- The portable path also forks inside `write_managed` (`portable_device_writer.py:117`).
- No measurement exists. Shell-start latency is a user-visible risk for every new terminal.
- **Remedy:** cache the capability probe result per helper path and mtime in the runtime directory, or combine register and current into one call.
- **Test:** time shellrc sourcing against a stub helper that sleeps 50 ms per call.

**R6. `tests/test_idle_worker.py:85,89`: undeclared ripgrep dependency.**
- The test depends on `rg`. If `rg` is missing, it returns 127, failing the first assertion and making the `== 1` check meaningless.
- **Remedy:** use `grep -E`.

**R7. `tests/test_trigger.py:63-71,89-97`: weak face assertions.**
- The "include face" test asserts only the exit code.
- The face-disabled test passes trivially because no helper writes to the regular tempfile TTY.
- **Remedy:** assert render field 19 via a stub helper.

### Unresolved hypotheses (not findings)

**U1. Gemini/OpenCode provider on the portable backend** (`portable_helper.py:81-83`).
- The portable helper raises when the provider is not in `PROVIDERS`.
- The Gemini adapter exports `TAVS_AGENT=gemini` with no intake (`gemini/trigger.sh:12-15`). Core then requests `--organizer-context gemini` (`organizer-state.sh:67-68,86-87`).
- If `PROVIDERS` contains only claude and codex (README:1087 suggests this), `_tavs_managed_context` fails and Gemini produces zero output without the companion.
- **Discriminating test:** with a missing native helper, run `gemini/trigger.sh processing` on an owned PTY and assert `]11;` bytes.

**U2. Restriction enforcement on the portable render path** (`portable_renderer.py:189-213`).
- `--managed-render` checks `policy.restricted` only when `ordinary_only` is set. The global lock/mute replacement presumably lives in `Store.ordinary_ownership`, which was not supplied.
- Existing restriction tests (`background-intent.bats:600-643`) use the native helper.
- **Discriminating test:** with the portable helper, an active lock, and an owned PTY, assert lock bytes and no ordinary color.

**U3. macOS without Command Line Tools.**
- `/usr/bin/python3` is an install-prompt shim. The `-x portable_helper.py` probe (`helper-selection.sh:64-66`) could trigger a GUI install prompt on every hook and shell.
- This needs live confirmation.

===END_ISSUES===

---

===SCORE_CARD===

### Rubric Scores

| Dimension | Score | Key Finding |
|-----------|-------|-------------|
| Correctness | 6/10 | Selection, intake and synthetic validation are sound; Linux ordinary output is fully lost (R1); provider coverage is uncertain (U1) |
| Security | 6/10 | Payload privacy, allowlists and data-only parsing are strong; the non-UID tmp root follows symlinks (R3) |
| Maintainability | 6/10 | Small typed bridge; dense cross-file control flow and shellrc/core reader duplication make the invariants hard to audit |
| Test Coverage | 5/10 | Rich owned-PTY race tests; `lock-gate.bats` is stale and escapes isolation (R2); no Linux or portable-provider coverage; weak pytest assertions |
| Performance | 6/10 | Bounded 100 ms writer is retained; about 5 helper spawns per hook and synchronous shell-start probes are unmeasured (R5) |
| **Overall** | **5.9/10** | Weighted 25/25/20/15/15 |

**Verdict:** CONCERN. All dimensions are at least 5 and some are below 7.

===END_SCORE_CARD===

---

===RECOMMENDATIONS===

### Summary

1. **Priority 1: resolve R1.** Either restore a bounded Linux ordinary backend through the same typed renderer, or explicitly narrow the README platform promise and silence shellrc when no supported backend exists. Add the Linux owned-PTY discriminating test.
2. **Priority 2: rewrite `tests/integration/lock-gate.bats` (R2).** Use private roots and an explicit stub or built helper, with assertions that match the no-pending-replay design.
3. **Priority 3: close R3.** Move `TAVS_TMP_DIR` under the UID runtime root with ownership and mode verification and `mktemp` temp files. Then settle U1 and U2 with portable-backend tests for Gemini and for lock restriction.

===END_RECOMMENDATIONS===

---

===REVIEW_META===
Execution path: claude-cli-explicit
Completion: full
Review mode: code-session
Model requested: opus
Model observed: unknown
Effort requested: unspecified
Effort observed: unknown
NOTE: real native Claude CLI under Hub controls, chosen by caller; it is not an automatic fallback or evidence that applied model/effort were observed.
Input scope: Partition 3 (ordinary hook routing), subscope 07-hook-routing / 07a-managed-routing, at commit 7ecfba2. All supplied files were reviewed:
- SPEC.md, PLAN.md, Package.swift, README.md.
- src/core: trigger, terminal-osc-sequences, helper-selection, organizer-state, idle-worker-background, session-state, mute-gate, visual-restrictions-state, lock-state-lib, theme-config-loader, terminal-detection, colors, dynamic-color-calculation, palette-mode-helpers, title-management, title-state-persistence, spinner, context-data, portable_helper, portable_renderer, portable_policy, portable_device_writer.
- Agent adapters and hooks JSON for Claude, Codex, Gemini and OpenCode, plus the statusline bridge.
- The OpenCode TypeScript plugin.
- Tests: background-intent, hook-observations, managed-background, emit-osc, idle-worker-mute, visual-restrictions-parity, liveness and lock-gate Bats; test_idle_worker, test_trigger, test_shell_compatibility, conftest; run-isolated.sh.
- tavs-shellrc.sh and defaults.conf.
Focus: all default
Limitations:
- Tool-free single turn. No source execution, builds, tests, git inspection or report file write; the report is inline only.
- Connected modules that were not supplied could not be inspected: portable_metadata, portable_context, portable_intent, portable_ownership, portable_records, portable_record_io, portable_render, portable_process_identity, backgrounds.sh, subagent-counter.sh, identity modules and the native Swift helper. U1 and U2 remain unresolved for this reason.
- Native catalogue, navigation, readability, Spaces, permission and visible-rendering acceptance is unverified.
- Linux kernel and runtime behavior is unverified. R1 is derived from source.
- Historical first-paint/EPERM and fresh-render timeout causes are not inferred from passing retries.
- Completion: full refers to this supplied subscope only, not to whole-goal acceptance.
===END_REVIEW_META===


## part07b: shell colors and titles

> [!NOTE] EXPLICIT CLAUDE CLI REVIEW
> The caller selected real `claude -p`; Claude Hub retains disable, volume and concurrency controls.

**Report path:** not written. This session has no tools, so the full report is reproduced inline below. The intended path was `/tmp/claude-review-code-terminal-agent-visual-signals-main-<timestamp>.md`.

- Verdict: **CONCERN**, 5.9/10, Risk Medium. Explicit native route `claude-cli-explicit`, selected by the caller.
- R1 (IMPORTANT): with no selectable helper, every ordinary color and title is dropped. This covers Linux and macOS without the companion or Python. The source promises macOS/Linux output.
- R2 (IMPORTANT): the idle worker and forced reset write titles even when title mode is `off`, the title is locked, or the user set a base title.
- R5 (IMPORTANT): counter tests can never fail because mismatches become `skip`. They also mutate shared `/tmp/tavs` state.
- 3 minor findings and 2 unresolved hypotheses.

---

> [!NOTE] Explicit native Claude CLI under Hub controls, chosen by the caller. This is not an automatic fallback. It is not evidence that the requested model or effort was applied.

# Claude Review Report

**Mode**: code-session
**Date**: 2026-10-14
**Focus**: all

---

===DIMENSION_RATIONALE===
## Metadata
- Target: commit 7ecfba2, partition 3, subscope 07b-shell-colors-titles (within 07-hook-routing).
- The supplied inventory was reviewed in full: SPEC, PLAN, Package.swift, README, and all core shell modules listed. That covers the trigger, render queue, helper selection, organizer state, idle worker, titles, faces, identity, context, colors, detection and policy modules. It also covers portable_helper/renderer/policy/device_writer, defaults.conf, the Claude trigger and statusline bridge, and the listed bats, pytest and shell tests.

## Dimensions
Using defaults, which are appropriate for this artifact:
- Correctness
- Security
- Maintainability
- Test Coverage
- Performance

Compatibility of ordinary standalone signaling is assessed under Correctness, per the caller's priorities.
===END_DIMENSION_RATIONALE===

---

===EXECUTIVE_SUMMARY===
Overall grade: 5.9/10
Risk level: Medium

## Summary
Ordinary hooks send background, palette, title and bell through one typed batch. That batch goes to a single selected helper:
- `_tavs_render_queue`/`_tavs_render_flush` in `src/core/organizer-state.sh:129-189`
- helper selection in `src/core/helper-selection.sh:47-74`

Several properties checked out:
- Synthetic renders drop bells (organizer-state.sh:130).
- The last-set title is persisted only after a `rendered` outcome (organizer-state.sh:176-180).
- Debug sinks carry only state and agent metadata (trigger.sh:70-93).

The defects found:
- **R1, no-backend compatibility.** When no backend can be selected, the hook emits nothing, titles included. The portable backend is darwin-only, so Linux ordinary signaling regresses to zero output.
- **R2, idle titles bypass title settings.** The idle worker and the forced reset build and send titles outside `should_send_title`/`set_tavs_title`. They ignore `TAVS_TITLE_MODE=off`, title locks and user base titles.
- **R5, non-failing tests.** The counter tests cannot fail, and two bats suites escape the private-root isolation the PLAN requires.

Native, visible, Spaces, readability and permission behavior is unverified, as are Linux kernel and runtime tests. Passing tests here are not evidence of physical acceptance.
===END_EXECUTIVE_SUMMARY===

---

===ISSUES===

## Hypothesis falsification

**H1: Ordinary signaling survives when no managed helper is available. Falsified; this is a defect (R1).**
- `_tavs_helper_select` sets `_TAVS_HELPER_BIN` only when one of two checks passes (helper-selection.sh:52-71):
  - the native capability strings match, or
  - the portable capability check passes.
- The portable path refuses any non-darwin platform (portable_helper.py:72-79).
- `_tavs_render_flush` then sets `result=1`, prints `tavs: current render unavailable` to stderr, and writes no bytes (organizer-state.sh:164-168, 185-188).

**H2: Idle-stage titles honor title mode, lock and user base. Falsified; this is a defect (R2).**
- idle-worker-background.sh:164-177 checks only `ENABLE_TITLE_PREFIX`.
- It composes from `$SHORT_CWD` and queues the title directly.
- It never calls `should_send_title` (trigger.sh:126-153) or `set_tavs_title` (title-management.sh:469-490).

**H3: Synthetic restores (tool_error delay, idle stages) replay bells or historical titles. Dismissed.**
- `_tavs_render_queue` returns early for `bell` when `TAVS_ORGANIZER_SYNTHETIC=1` (organizer-state.sh:130).
- Synthetic `processing` skips `record_state` and `kill_idle_timer` (trigger.sh:216, 230).
- The title-save flag is honored only on a `rendered` outcome (organizer-state.sh:176-180).
- `replay` reconciles typed intent and never touches cached OSC (trigger.sh:183-196).

**H4: A shell writer in this subscope bypasses the managed path for backgrounds during suspension or restriction. Dismissed for backgrounds.**
- `send_osc_bg`, palette, title, image (iTerm2) and bell all enter `_tavs_render_queue` (terminal-osc-sequences.sh:84-121, 201; backgrounds.sh:73-79).
- Kitty image changes are subprocesses gated on `_TAVS_SUPPRESS_OUTPUT` (backgrounds.sh:99, 134). They are not OSC background writes.
- Residual: the iTerm2 title query writes and reads the TTY directly (title-iterm2.sh:54, 62). That is a query, not a restrictive paint. It is listed below as unresolved.

**H5: Title tokens can carry terminal control bytes. Unresolved (see U1).**
- `{SESSION_ID}`, `{MODE}` and `{MODEL}` are substituted without `sanitize_for_terminal` (title-management.sh:406, 432, 436).
- Whether the bytes reach the TTY depends on `Render.encode` in portable_render.py and on the native renderer. Neither was supplied.

## Findings

### CRITICAL
None substantiated.

### IMPORTANT

**R1. No-backend path drops all ordinary colors and titles (Linux; macOS without companion or Python 3)**

- **Source lines:**
  - `src/core/helper-selection.sh:47-74` (selection)
  - `src/core/organizer-state.sh:160-189` (flush)
  - `src/core/portable_helper.py:72-79` (darwin-only capability)
  - `src/core/title-management.sh:526` (titles also routed into this batch)
- **Trigger:** any hook where neither helper qualifies. Examples:
  - Linux: `sys.platform != "darwin"` fails the portable check.
  - macOS without `/Applications/TAVS.app` and without a working `python3`.
- **Behavior:**
  - `_tavs_managed_helper` fails, `result=1`, and stderr shows "current render unavailable".
  - No OSC 11, OSC 0, palette or bell bytes are written. Titles are lost too, although they are not restrictive output.
- **Impact:**
  - README:1084-1086 states the requirements are "macOS or Linux".
  - SPEC:163-164 requires preserving "direct ordinary signaling when no controller owns an effect".
  - README:1092 concedes the gap, but that does not remove the compatibility regression.
- **Smallest remedy:**
  - Add a Linux portable ordinary backend. Process identity can come from `/proc/<pid>/stat` start time.
  - Until then, surface "no ordinary backend" in `tavs status` instead of only per-hook stderr.
  - Do not add a raw-printf fallback after a *selected* operation fails (PLAN:45).
- **Criterion:** SPEC:163-164 and README:1086 compatibility.
- **Discriminating test:**
  - Setup: owned PTY with `TAVS_TEST_HELPER_BIN=/nonexistent`, plus a portable check forced to fail (or run on Linux).
  - Action: run `trigger.sh processing`.
  - Assertion: background and title bytes are present, or `tavs status` reports the missing backend explicitly.
  - Current source writes zero bytes, so this test discriminates.

**R2. Idle worker and forced reset write titles despite `TAVS_TITLE_MODE=off`, title lock, or user base title**

- **Source lines:**
  - `src/core/idle-worker-background.sh:164-177` and `:129`
  - `src/core/organizer-state.sh:92-97`
  - `src/core/portable_renderer.py:80-88`, which sets title flag `fields[18]="1"` unconditionally
- **Trigger:** set `TAVS_TITLE_MODE="off"` (or `lock_tavs_title`, or `TAVS_RESPECT_USER_TITLE=full` with a user base), then fire `complete`.
- **Behavior:**
  - At the first tick the worker composes `compose_title complete "$SHORT_CWD"` and queues OSC 0.
  - Later stages and the max-runtime forced reset also send a title.
  - Both replace the prefix-only user base with the path.
- **Impact:**
  - README:330 says `off` makes no title changes. This breaks that promise.
  - It also defeats explicit locks and prefix-only base preservation.
- **Smallest remedy:**
  - Gate the worker's title on `should_send_title "$title_state"`.
  - Also gate it on `load_title_state; [[ $TITLE_LOCKED != true ]]`.
  - Use `get_base_title` instead of `$SHORT_CWD`.
  - Pass an explicit no-title form to `--managed-forced-reset` when the gate fails.
- **Criterion:** existing title-mode contract (README:323-330; defaults.conf:93-101).
- **Discriminating test:**
  - Setup: owned PTY with `TAVS_TITLE_MODE=off`, `IDLE_CHECK_INTERVAL=1`, `STAGE_DURATIONS=(1 1 1 1 1 1 1)`, `MAX_TIMER_RUNTIME=3`.
  - Assertion: no `\e]0;` bytes appear after `complete`.
  - Current code emits them.

**R5. Counter tests are non-failing, and two bats suites escape private roots**

- **Source lines:**
  - `tests/integration/counter-integrity.bats:25, 56-59, 78, 89, 105, 119`
  - `tests/integration/identity-teardown.bats:25, 53-59, 81`
- **Trigger:** running either suite.
- **Behavior:**
  - Every counter assertion ends in `|| skip`, so a wrong count passes.
  - counter-integrity uses `env -i` without `TAVS_TMP_DIR`. That sends the following into the shared `/tmp/tavs` (session-state.sh:17; identity-registry.sh:62):
    - `STATE_DB`
    - title state
    - the `processing new-prompt` identity registry and round-robin counter
  - Both suites drop `TAVS_TEST_HELPER_BIN`. The helper therefore resolves to `/Applications/TAVS.app` (helper-selection.sh:16).
  - Both use fixed `/tmp/test-*` TTY files.
- **Impact:**
  - The counter-integrity contract is unverified.
  - The suites mutate live shared state, contrary to PLAN:59-66 and phase 3.
- **Smallest remedy:**
  - Require `TAVS_TEST_ROOT`, as `priority-pinning.bats:10-11` does.
  - Derive every path from it and pass `TAVS_TMP_DIR`, `XDG_*` and the helper binary.
  - Replace `|| skip` with real assertions on a known counter path.
- **Criterion:** PLAN phase 3 isolation and meaningful assertions.
- **Discriminating test:** deliberately break `reset_subagent_count` (no-op it). The repaired suite must fail; the current suite skips.

### MINOR

**R3. Title state escaping is not reversed on load, so quotes and backslashes grow on each render**

- **Source lines:**
  - `src/core/title-state-persistence.sh:112-125, 160-168`
  - re-saved on every delivered title by `title-management.sh:571-574`
- **Trigger:** `set_user_title 'a"b'`, followed by any hooks.
- **Behavior:**
  - The load returns `a\"b`; it strips only the outer quotes.
  - The next save writes `a\\\"b`. Growth is unbounded, and the escaped text appears in the title.
- **Remedy:** unescape `\\` and `\"` in `_read_title_state_value`.
- **Test:** save `My "Project"`, then load and save twice, then assert equality. This test discriminates. The existing `test_quotes_in_value_are_escaped` has no assertion.

**R4. Per-agent `COMPACT_CONTEXT_EYE` applies to the face but not to title token suppression**

- **Source lines:**
  - `src/core/face-selection.sh:195` reads `COMPACT_CONTEXT_EYE` with a global fallback.
  - `src/core/title-management.sh:315-317` reads only `TAVS_COMPACT_CONTEXT_EYE`.
- **Trigger:** `CLAUDE_COMPACT_CONTEXT_EYE=true` while the default preset forces the global value to `mirror` (theme-config-loader.sh:99).
- **Behavior:**
  - The right eye shows the food icon, and the title shows `{CONTEXT_FOOD}` again.
  - The inverse configuration hides the context entirely.
  - Because the preset clobbers the global value after user.conf loads, the per-agent override is the only working override path.
- **Remedy:** use `${COMPACT_CONTEXT_EYE:-${TAVS_COMPACT_CONTEXT_EYE:-mirror}}` in compose_title.
- **Test:** with that configuration, assert the food emoji appears exactly once.

**R6. Bash-4 expansions in a Bash-3.2 code path**

- **Source lines:**
  - `src/core/terminal-detection.sh:37` uses `${TERM_PROGRAM,,}`.
  - `src/core/terminal-detection.sh:368` uses `${r^^}`.
- **Trigger:** `/bin/bash` 3.2 with an unmatched `TERM_PROGRAM` (e.g. `tmux`), reached via `supports_background_images` when stylish backgrounds are enabled.
- **Behavior:** "bad substitution". The subshell returns empty and image support silently degrades.
- **Criterion:** SPEC:474, Bash 3.2.
- **Remedy:** `tr '[:upper:]' '[:lower:]'` / `tr '[:lower:]' '[:upper:]'`.

**R7. README per-state title defaults disagree with defaults.conf**

- **Source lines:**
  - README:451-459 documents per-state permission, idle and compacting formats.
  - defaults.conf:152 and 165-172 set every per-state format empty and enable the `compact_project_sorted` preset.
- **Remedy:** update the README.

## Unresolved hypotheses (not findings)

- **U1: control bytes in titles.**
  - Unsanitized `{SESSION_ID}`, `{MODE}` and `{MODEL}` (title-management.sh:406, 432, 436) could carry control bytes into OSC 0.
  - Whether they do depends on `Render.encode` and the native renderer, which were not supplied.
  - Test: put a sentinel `\x1b` in the bridge `model=` field, then assert no raw ESC appears inside the OSC 0 payload.
- **U2: iTerm2 title detection can block and steal input.**
  - `iterm2_get_var` reads replies from `TTY_DEVICE` with a 1 s timeout, twice per title (title-iterm2.sh:54, 62).
  - This can add about 2 s of hook latency, and it may consume user keystrokes. Both are runtime-dependent.
  - It predates this work and is iTerm2-only.
- **Dismissed:** arithmetic evaluation of bridge fields (context-data.sh:75, 297; `_format_duration`). The fields come from same-user 0700 directories and from provider JSON numeric extraction, so no privilege boundary is crossed.
===END_ISSUES===

---

===SCORE_CARD===

## Rubric Scores

| Dimension | Score | Key Finding |
|-----------|-------|-------------|
| Correctness | 5/10 | R1: no-backend path emits nothing. R2: idle titles ignore mode, lock and base. R3, R4 also apply. |
| Security | 7/10 | No concrete vulnerability. Title-token sanitization is unresolved (U1). |
| Maintainability | 6/10 | Duplicated policy predicates, dead `cleanup_stale_timers` pgrep pattern (idle-worker-background.sh:58), doc drift (R7). |
| Test Coverage | 5/10 | `|| skip` assertions and isolation escapes (R5). Assertion-free pytest cases (R3). |
| Performance | 6/10 | Several helper process launches per hook (capability probes, intake, observe, render), plus iTerm2 blocking queries (U2). |
| **Overall** | **5.9/10** | Weighted 25/25/20/15/15. |

## Verdict
**CONCERN.** Every dimension is at least 5 and some are below 7.
===END_SCORE_CARD===

---

===RECOMMENDATIONS===

1. **[Priority 1]** Restore ordinary signaling when no helper is selectable (R1).
   - Add a Linux portable ordinary backend.
   - Make backend absence visible in `tavs status`.
   - Keep the rule of no raw writes after a selected operation fails.
2. **[Priority 2]** Gate idle-worker and forced-reset titles on `should_send_title`, the title lock and `get_base_title` (R2). Add an owned-PTY title-mode-off test.
3. **[Priority 3]** Repair counter-integrity and identity-teardown isolation and assertions (R5). Then fix title-state unescaping (R3) and the compact context-eye resolution (R4).

===END_RECOMMENDATIONS===

---

===REVIEW_META===
Execution path: claude-cli-explicit
Completion: full
Review mode: code-session
Model requested: opus
Model observed: unknown
Effort requested: unspecified
Effort observed: unknown
NOTE: Real native Claude CLI under Hub controls, chosen by the caller. It is not an automatic fallback and not evidence that the applied model or effort was observed.
Input scope: Partition 3, subscope 07-hook-routing / 07b-shell-colors-titles at commit 7ecfba2. All supplied files were reviewed in full:
- Documents: SPEC.md, PLAN.md, README.md
- Swift package: Package.swift
- src/core: trigger, terminal-osc-sequences, organizer-state, helper-selection, idle-worker-background, session-state, mute-gate, visual-restrictions-state, lock-state-lib, theme-config-loader, terminal-detection, colors, dynamic-color-calculation, palette-mode-helpers, title-management, title-state-persistence, title-iterm2, spinner, context-data, backgrounds, challenge, dir-icon, face-selection, identity-registry, session-icon, subagent-counter, themes
- Portable helper: portable_helper/renderer/policy/device_writer.py
- Configuration: defaults.conf
- Claude agent: trigger.sh, statusline-bridge.sh
- Tests: conftest.py, run-isolated.sh, the 6 listed bats files, test_title_state_persistence.py, and the 4 listed shell test scripts
"Full" refers to this subscope only, not whole-goal acceptance.
Focus: all default
Limitations:
- Tool-free single turn. Nothing was built, run or executed, and the report could not be written to /tmp, so it is delivered inline.
- Referenced modules not supplied (portable_render, portable_records, portable_intent, portable_ownership, portable_metadata, portable_context, portable_process_identity, native Swift renderer) limit U1 and parts of R1/R2 to source inference.
- Native catalogue, navigation, visibility, Spaces, readability and permission acceptance is unverified.
- Linux kernel and runtime tests are unverified.
- Historical first-paint/EPERM and fresh-render timeout causes remain unestablished; no inference was drawn from green runs.
===END_REVIEW_META===
