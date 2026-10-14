# Standalone shell delivery and restore oracle checks

Last Updated: 2026-10-14 (Europe/Vienna)
Version: 1.0

## Parent disposition

`76e79a5` connects standalone startup and complete adjacent helper delivery; `7ca84a8` corrects
only the live-timer test oracle. Source checker R1 was verified with red vkGHoL before two
one-line bare-path corrections; initial and recheck reports remain unchanged below. Function
source localization independently failed su1pmO before Bash export removal and zsh global
attribute handling. Linked helper-copy ordering failed 8nuANC before guarded delivery ran first.
Final dBGZmz passes 135 shell tests, OSByNL passes 173 portable tests in 13.552 seconds and
pZyeFE passes 561 Swift tests in 14.882 seconds. Changed shell syntax and staged checks pass.

The initial combined G2glOv had one byte-comparison failure. A passing focused retry was
insufficient evidence. Controlled RInZM7 reproduced the same mismatch with a legitimate timer
transition before restore release; stale restore returned 3 and changed none of the measured
new state, PID, counter, observation or delivery. The corrected case still checks forward state,
priority/time, exact live timer, code 3 and exact observation/counter/delivery. Non-timer byte
comparisons remain. Historical removed artifacts still prevent definitive earlier attribution.

Reports' model names are subagent self-reports, not parent-observed runtime identities. Scope
approval covers these source corrections, not Linux or physical native acceptance. Docker's
stopped daemon was rechecked without startup; the environment-choice question remains pending.
No real installation/settings/schedule, app/VM/container or existing-session action occurred.

## Initial delivery check

# Shell Helper Delivery Source Check

## Metadata

- Reviewer: GPT-6.1 Sol, independent source-check subagent.
- Review type: code.
- Review mode: coaching.
- Tier: standard.
- Date: 2026-10-14.
- Target: current uncommitted changes in `src/shell/tavs-shellrc.sh`,
  `src/core/helper-selection.sh`, `src/cli/cmd-install-shell-integration.sh`,
  `src/cli/cmd-sync.sh`, and their connected tests.
- Method: current diff, callers, helper imports, focused isolated tests, and direct isolated probes.
- No source edits, real-home installation, native app control, or workspace `.build` binary use.
- Required helper: `/tmp/tavs-focus-leases-84v8mqbc/build/arm64-apple-macosx/release/TAVSApp`.

## Rubric Scores

| Dimension | Score | Evidence |
|-----------|-------|----------|
| correctness | 6 | Installed and qualified source paths pass; bare-basename source lookup fails. |
| security | 8 | Dedicated scopes preserved or rejected; generic probe errors; no raw output branch. |
| maintainability | 7 | One explicit dependency copy list serves install and sync. |
| test_coverage | 8 | 37 focused cases pass, plus inherited function-cache and missing-resource probes. |
| completeness | 7 | Requested delivery boundaries verified; basename path edge remains. |

## Verdict

**verdict**: CONCERN

**confidence**: high for the reviewed slice. The concern is limited to the reproducible source-path
edge below, not companion app, Linux, or broader product acceptance.

## Findings

### [R1] MEDIUM: Bare-basename sourcing loses the adjacent selector directory

- **Situation**: `src/shell/tavs-shellrc.sh:64-69`, `_tavs_shellrc_managed_helper`.
- **Behavior**: After `cd src/shell`, `source tavs-shellrc.sh` succeeds, but invoking the helper
  loader returns 1 in both `/bin/bash` 3.2.57 and `/bin/zsh` 5.9. The recorded defining filename is
  `tavs-shellrc.sh`; `${location%/*}` leaves that string intact, so the selector lookup becomes
  `tavs-shellrc.sh/../core/helper-selection.sh`. The equivalent path edge also applies to an
  installed file sourced as bare `shellrc` while already in its directory.
- **Impact**: This valid shell source form reports the managed helper unavailable despite adjacent
  resources being present. The generated installation fence uses an absolute path and is unaffected.
- **Suggestion**: Normalize a filename with no slash to the current directory before forming the
  adjacent resource path, and add one Bash 3.2/zsh regression case for bare-basename sourcing.
  No new module or packaging mechanism is needed.
- **Reproduction log**:
  `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.2cD38w/command.log`.

## Checked Boundaries

1. **Source and installed paths.** `src/shell/tavs-shellrc.sh` and `./tavs-shellrc.sh` resolve the
   source selector in both system shells. Installed `~/.tavs/shellrc` resolves the adjacent
   `shell-helper/helper-selection.sh` independently of checkout and copied plugin roots.
2. **Function-source cache lifetime and privacy.** The Bash `export -n` path and zsh
   `typeset -g +x` path retain global checked/bin/backend values after returning from a source-loader
   function. The new test checks a fresh selection. A separate isolated probe also checks an
   imported native cache with the accepted intake hint: values survive and no `_TAVS_HELPER_` cache
   variable reaches a child environment.
3. **Complete helper closure.** Recursive AST inspection finds 13 local Python files reachable
   from `portable_helper.py`. Every file appears in `_tavs_copy_ordinary_helper_files`, together
   with `helper-selection.sh`. Install, installed-shell sync, and plugin-target sync use this same
   function. Copied resources work after both plugin roots are moved offline in the owned fixture.
4. **Copy failure.** Required-copy and installed-resource delivery failures propagate nonzero and
   suppress success output. Install publishes the shellrc after helper copying, and the existing
   shellrc/fences are preserved by the covered helper-directory failure.
5. **Unavailable and missing resources.** An isolated installed fixture with either its selector
   or `portable_policy.py` moved aside reports `managed output helper unavailable or unsupported`.
   Neither shell exposes Python traceback content or emits raw OSC output during this check.
6. **Failure keeps the selection.** Checked/bin/backend are cached once. Registration failure
   does not re-probe or switch backend, and current-policy dispatch still uses the selected helper.
   The focused source tests verify both native and portable operation-failure paths.
7. **Dedicated native scope.** Native capability probes strip only the three dedicated test-scope
   keys. Native operations retain them. Portable selection and operations retain those keys so
   the helper can reject their presence, including empty values. Scope introduced after portable
   selection also reaches the selected operation and is rejected.
8. **Persistence and readers.** The persistent writer and public recovery command have no diff.
   Exact source comparison confirms shellrc read/suspended function definitions still match the
   core definitions. Malformed marker, persistent suspension, fresh-runtime suspension, and
   explicit resume-reader cases pass. Owned-PTY startup leaves the marker unchanged when present
   and does not create it when absent. Sync preserves user configuration, schedule, and saved lock.
9. **No raw output fallback.** The shellrc's only painting requests are typed managed-helper
   operations. It suppresses helper stdout and emits generic errors on failure. There is no new
   shell OSC writer or backend switch after an operation failure.
10. **Native-only public recovery.** `cmd_recover` saves state, probes the explicit native candidate,
    and invokes `--visual-recover` directly with dedicated scope retained. It does not use ordinary
    helper selection. A missing companion remains nonzero after state persistence. Portable helper
    capability and unsupported-recovery tests confirm it claims no native control/recovery API.

## Falsification Record

| Potential problem | Result |
|-------------------|--------|
| Sourcing selector inside a function localizes or exports its cache | Disproved by both fresh-cache test and imported-cache probe. |
| Installed shell depends on checkout or plugin cache | Disproved by offline-root cases and owned-PTY startup. |
| Operation failure selects a different backend or emits shell OSC | Disproved by failure cases and source trace. |
| Missing selector/module exposes probe output instead of unavailability | Disproved by isolated missing-resource probe. |
| Bare-basename source path resolves adjacent resources | Confirmed failure, R1. |

## Verification

All test executions ran through `tests/run-isolated.sh` with the required source-built helper.

| Run | Result | Preserved log |
|-----|--------|---------------|
| `bats tests/unit/helper-selection.bats` | 10 passed | `tavs-isolated.vIYm8X/command.log` |
| Focused install/startup/suspension/unavailable shellrc cases | 10 passed | `tavs-isolated.db9B5C/command.log` |
| Focused delivery/capability/recovery/sync cases | 12 passed | `tavs-isolated.6PPH0d/command.log` |
| Owned-PTY hook/startup plus portable capability/scope/recovery cases | 5 passed | `tavs-isolated.pnGMyB/command.log` |
| Function-source imported cache privacy and system-shell versions | Passed | `tavs-isolated.t2wwIM/command.log` |
| Missing installed selector and Python dependency | Passed | `tavs-isolated.7TkABi/command.log` |

Log base: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/`.

## Summary

The changed delivery mechanism covers the adjacent helper closure and maintains selected-backend,
scope, persistence, and native-recovery boundaries. One narrow valid source invocation fails because
the loader does not handle a defining filename without a directory component.

Live companion/UI installation acceptance, native terminal-app behavior, and full Linux/backend
acceptance were not tested. The portable helper deliberately refuses Linux in its current contract;
that boundary is not a regression in this shell-delivery slice.

Historical memory was used only to retain the live-operation boundary, not as evidence of current
runtime or source state: `MEMORY.md:664-665`, rollout ID `01a100cb-205c-7840-8268-c3d4ab1f7849`.

## Delivery correction recheck

# Shell Helper Delivery Source Recheck

## Metadata

- Reviewer: GPT-6.1 Sol, independent source-check subagent.
- Review type: code.
- Review mode: coaching.
- Tier: standard.
- Date: 2026-10-14.
- Target: current shell-helper delivery slice after the basename correction.
- Original report: `/tmp/explorer-tavs-shell-helper-delivery-source-check-20261014.md`.
- Required helper: `/tmp/tavs-focus-leases-84v8mqbc/build/arm64-apple-macosx/release/TAVSApp`.
- No source edits, real-home installation, native app operations, or workspace `.build` use.

## Rubric Scores

| Dimension | Score | Evidence |
|-----------|-------|----------|
| correctness | 8 | The reported source-path failure now passes independently in both system shells. |
| security | 8 | Linked-file refusal, scope boundaries, private cache, and no raw output retained. |
| maintainability | 7 | Two one-line path normalizations; shared delivery function retained. |
| test_coverage | 8 | 37 initial focused cases, six correction-focused cases, eight direct source-form probes. |
| completeness | 7 | Requested source/delivery boundaries complete within this slice's stated scope. |

## Verdict

**verdict**: APPROVE

**confidence**: high for the inspected shell-delivery slice.

## Findings

No remaining actionable finding in the reviewed slice.

### Resolved R1 from the original report

The initial isolated probe confirmed `source tavs-shellrc.sh` failed helper selection in Bash 3.2.57
and zsh 5.9 after changing into `src/shell`. Qualified `./tavs-shellrc.sh` and repository-relative
source paths worked. The original probe is retained at:

`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.2cD38w/command.log`.

The latest source adds `./` when the defining filename has no slash in both places:

- `src/core/helper-selection.sh:8`, before resolving `_TAVS_HELPER_DIR`.
- `src/shell/tavs-shellrc.sh:67`, before selecting the source or installed resource layout.

This directly fixes the failed directory derivation without changing backend selection or resource
layout. New tests cover the shared module's adjacent portable helper and the source shellrc's helper
loader in both shells. Independent direct probes additionally cover the installed bare `shellrc`
form with the native companion deliberately missing.

## Recheck Verification

Every test/probe below used `tests/run-isolated.sh` with the specified source-built helper.

- Six focused Bats cases passed: module bare filename, function-scoped selector lifetime, complete
  installed adjacency, linked destination refusal, registration failure without raw output, and
  source shellrc bare filename.
- Eight independent source-form probes passed: repository-relative source shellrc, `./` source
  shellrc, bare source shellrc, and bare installed `shellrc`, each in `/bin/bash` and `/bin/zsh`.
  These probes selected the real portable helper while the native candidate was explicitly missing.
- The original 37 focused cases passed before this path-only correction. They cover cache privacy,
  exact capabilities, dedicated scope, offline copied roots, persistence, native-only public
  recovery, generic unavailable reporting, and owned-PTY installed startup.

Recheck logs:

- `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.sMwMPQ/command.log`
- `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.fxdeEK/command.log`

The original report records the full source/import trace, unchanged persistence/readers,
private/global function-source cache probe, missing-resource probe, and earlier test logs.

## Summary

The one source-path defect found independently is corrected and verified. Complete shared helper
delivery, global private caches, stable backend selection, dedicated scope, persistent readers,
generic unavailability, absence of raw output fallback, and native-only public recovery remain
supported by the reviewed source and focused evidence.

Live companion/UI installation, terminal-app native behavior, and full Linux/backend acceptance
were not tested. Those boundaries remain separate from this source-delivery slice. Parent-reported
broader Swift/portable counts were not rerun or represented as independent verification here.

## Controlled restore oracle diagnosis

# Restore state oracle diagnosis

Last Updated: 2026-10-14
Version: 1

Confirmed: the completion case has a byte-comparison race with its live idle worker.
The matching failure was reproduced under a controlled owned schedule. The worker changed the
state before restoration was released; the stale restore did not cause that state change.
No repository files were edited. No real-home or native app operations were performed.

## Evidence and limits

The historical combined run is at:

```text
/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.G2glOv/command.log
```

It failed at `background-intent.bats:379` with `differ: char 14, line 1`.
Its case artifacts are gone, so its historical before/after state cannot be independently read.
The mechanism and exact mismatch location were reproduced below; the historical attribution is
supported by that reproduction and current source, rather than recovered historical snapshots.

The installed Bats is 1.14.0 and supports `--no-tempdir-cleanup`.
The unmodified, single-test retry passed with retained fixtures:

```bash
TAVS_TEST_HELPER_BIN=/tmp/tavs-focus-leases-84v8mqbc/build/arm64-apple-macosx/release/TAVSApp \
  tests/run-isolated.sh bats --no-tempdir-cleanup \
  --filter 'a restore validated before Stop preserves the newer state and timer' \
  tests/integration/background-intent.bats
```

Its log is `tavs-isolated.2oWHZ8/command.log`, beneath the same macOS temporary parent.
That passing retry alone was not used to justify relaxing the assertion.

The controlled reproduction uses the current fixture's proxy and restore script, extracted into
the new isolated root by `/tmp/tavs-restore-oracle-repro-20261014.py`. Its only scheduling change
was a 2.5-second pause after the existing state snapshot and before creating `release`. It also
copied the state before release and immediately after the stale helper returned, so the writer's
effect could be distinguished from restoration. The script asserts the expected original fixture
failure and checks all the required invariants independently before returning success.

```bash
TAVS_TEST_HELPER_BIN=/tmp/tavs-focus-leases-84v8mqbc/build/arm64-apple-macosx/release/TAVSApp \
  tests/run-isolated.sh python3 /tmp/tavs-restore-oracle-repro-20261014.py
```

Evidence root:

```text
/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.RInZM7
```

The retained `controlled-case/race-complete/diagnostic-summary.json` records:

| Measurement | Result |
|---|---|
| State snapshot | `_dev_ttys035 complete 20 1791963513713 61871` |
| State before release | `_dev_ttys035 idle 15 1791963515072 61871` |
| State after stale return | Exactly equal to state before release |
| Original fixture status | 1, at original `cmp`, char 14, line 1 |
| Stale restore helper result | 3 |
| Worker stage-ready result | 0 |
| Subagent counter | Exactly 0 before and after |
| Stop observation | Byte-identical before and after |
| Intent delivery | Exactly matches the preserved Stop observation's delivery ID |
| Intent background | `#44CC55` |
| Timer | PID 61871 before and after; alive immediately after stale return |

Thus the failing comparison detects `complete` changing to `idle`, at the first character of
the state field. The timestamp also advances, as required by `write_session_state`.

## Source attribution

All paths below are relative to `/Users/cs/local/code/apps/terminal-agent-visual-signals`.

- `tests/integration/background-intent.bats:311-316`: `stage-ready` is written after any successful
  worker synthetic render. It does not stop the worker or guarantee its state remains unchanged.
- `tests/integration/background-intent.bats:329`: stage durations are `(2 60 60 60 60 60 60)`.
- `tests/integration/background-intent.bats:365-379`: state is copied, the restore is released,
  its result is awaited, and the whole state file is compared byte-for-byte.
- `src/core/idle-worker-background.sh:101`: the worker records its initial state with its PID.
- `src/core/idle-worker-background.sh:121-146`: elapsed whole seconds select the stage. Stage 0
  writes `complete`; later stages write `idle`, preserving the same worker PID.
- `src/core/session-state.sh:86-105`: each state write recomputes priority and current timestamp.
- `src/core/trigger.sh:215-230`: synthetic processing restoration skips killing the timer and
  recording processing state. The parallel synthetic subagent path has the same gates at
  `src/core/trigger.sh:352-363`.
- `src/core/organizer-state.sh:63-67`: synthetic restoration does not publish an observation.
- `src/core/organizer-state.sh:172-179`: synthetic render passes its inherited delivery context
  and synthetic flag to the helper. The controlled helper returned the required stale result 3.

No source defect in restoration was found within this narrow scope. Broader worker races and
real native behavior were not audited.

## Smallest recommended assertion change

Keep the exact state-file comparison for the `subagent-start` and `current` cases, which have no
live completion timer. For `complete`, compare state meaning instead: the state may advance from
`complete` to `idle`; its priority must match the state, its timestamp must not go backward, and
its timer PID must remain exactly the newer completion timer. Keep every existing result,
counter, observation, live-PID, graduated-color, and delivery-ID assertion.

Replace only the unconditional `cmp` at line 379 with this branch:

```bash
if [[ "$3" == complete ]]; then
    read -r before_tty before_state before_priority before_time before_timer \
        < "$RESTORE_CASE_DIR/state-before"
    read_session_state
    [[ "$SESSION_STATE" == complete || "$SESSION_STATE" == idle ]]
    [[ "$before_state" != idle || "$SESSION_STATE" == idle ]]
    test "$SESSION_PRIORITY" = "$(get_state_priority "$SESSION_STATE")"
    test "$SESSION_TIME" -ge "$before_time"
    test "$before_timer" = "$timer"
    test "$SESSION_TIMER_PID" = "$timer"
else
    cmp "$STATE_DB" "$RESTORE_CASE_DIR/state-before"
fi
```

This excludes processing/subagent/reset overwrite, priority corruption, timestamp regression,
timer replacement, and idle-to-complete reversal while allowing the demonstrated worker update.
The existing `kill -0`, exact counter, exact observation bytes, result 3, successful stage paint,
and observation-to-intent delivery ID checks still apply. The recommendation has not been
implemented in the repository or run as a modified Bats test.

## Capture contribution for the parent session

[O] A single-test retry passed, but the diagnosis continued. A copied isolated fixture delayed
restore release across the existing idle boundary and captured state before release. That state
already differed from the original snapshot and was identical after stale result 3, separating
the live timer's evolution from stale restoration. Exact counter, observation, delivery, and PID
checks held. [R] Choosing a semantic assertion only for the live-timer case is the smallest fix
because byte equality still expresses the contract of the non-timer cases. The requested
read-only repository scope takes precedence over writing a child capture into the shared project
file; this contribution is available for the parent's final capture. Model variant unverified.
