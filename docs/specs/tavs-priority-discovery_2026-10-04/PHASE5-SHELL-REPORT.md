# Phase 5 shell and CLI suspension readers

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0
Baseline: `120c79d`

## Completed scope

Only these eight owned project paths changed:

- `src/core/trigger.sh`: source the pure reader with builtin, basename-safe path
  resolution and fresh-check persistent suspension before stage-0 mute and lock.
- `src/core/mute-gate.sh`: source the shared helper; fresh-check before stage-1's
  early return, clear suppression and stage-0 temporaries while disabled, and
  fresh-check before each idle-worker full mute evaluation.
- `src/core/lock-state-lib.sh`: source the shared helper; effective-lock predicate
  reads suspension first. Raw lock read/write and saved definitions are unchanged.
- `src/shell/tavs-shellrc.sh`: exact standalone copies of the common read/predicate
  functions; register TTY first, then skip restrictive paints while suspended or
  unavailable. Invalid state reports only a generic availability message.
- `src/cli/cmd-status.sh`: unfiltered persistent visual-status line, including
  explicit resumption and unavailable-state guidance.
- `src/cli/cmd-lock.sh`: status distinguishes saved versus effective state;
  newly requested locks are saved but report inert while disabled; unlock skips
  challenge and preserves the saved lock when restriction state disables it.
- `tests/unit/shellrc.bats`: private ZDOTDIR and five suspension/unavailable
  acceptance cases using real interactive Bash/zsh and copied standalone shellrc.
- `tests/unit/cmd-lock.bats`: deterministic read-only pgrep stub and nine new
  predicate, status, new-lock, challenge-bypass and preservation acceptance cases.

No parser/writer was introduced outside the parent's shared module. The
standalone boundary uses exact copies because only one shellrc is installed.
No schedule/grant definition migration, recovery command, pending-cache replay,
drain, invalidation or device ordering was added.

Key touched functions: `_tavs_validate_mute_liveness`, `_tavs_check_mute_state`,
`_tavs_lock_effective`, `_tavs_shellrc_main`, `cmd_status`, `_lock_now`,
`_lock_status`, `_lock_unlock`; standalone `_tavs_visual_restrictions_read` and
`_tavs_visual_restrictions_suspended` mirror the parent's shared functions.

## Test isolation audit

Both suites create TEST_DIR under the runner's private TMPDIR, then private
HOME/runtime and rc paths. Shellrc emits to captured stdout and uses synthetic
`/dev/ttys901`/`902` registry identifiers; it never opens those device paths.
Zsh's ZDOTDIR is explicitly the per-test private HOME. Bash uses `--norc`.
All lock/challenge/schedule fixtures and cleanup targets are owned by TEST_DIR.
Neither suite contains an inner `env -i` or launches completion workers.

The parent separately authorized the three existing fixture-only installer
cases. They were audited and included: copied shellrc and rc fences remain
within TEST_HOME, and removal deletes only the fixture's copied shellrc/fence.
No real installation, app/native target, personal config or unrelated process
was operated on. No Swift build or new helper verb was invoked by this worker.

## Red/green evidence

Red command:

`TAVS_TEST_HELPER_BIN=/tmp/tavs-phase5-20261012T132300/baseline-helper tests/run-isolated.sh bats --filter 'suspension:|unavailable:|status: persistent' tests/unit/cmd-lock.bats tests/unit/shellrc.bats`

Result: all 14 new cases failed against prior readers and output behavior.
Log: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.u2hA6p/command.log`

Green command:

`TAVS_TEST_HELPER_BIN=/tmp/tavs-phase5-20261012T132300/baseline-helper tests/run-isolated.sh bats tests/unit/cmd-lock.bats tests/unit/shellrc.bats`

Result: **43/43 passed**, exit 0 (14 new, 29 existing).
Log: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.uiEccd/command.log`

After strengthening the malformed-marker test's negative predicate assertion,
its focused rerun passed, exit 0. Log:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.9IEKZo/command.log`

Every changed shell file passed its individual `/bin/bash -n`; shellrc also
passed `/bin/zsh -n`. Both standalone reader functions were compared verbatim
against the shared module and match exactly. Owned diff whitespace checks pass.
Credential-pattern scan found no match; `.env` remains ignored.

ShellCheck warning scan found only two pre-existing SC2174 notices at existing
`mkdir -m 0700 -p` lines in mute-gate and lock-state-lib. No touched-line warning
was introduced; no unrelated mkdir behavior was changed.

## Capture notes and remaining verification

[O] Initial tests reproduced old effective rules and restrictive shell-start
paint despite a valid suspension marker. Implementation preserved byte-for-byte
lock/grant/schedule definitions while disabling effective predicates.
[O] Negative predicate checks followed by more assertions use explicit failing
branches, avoiding Bash's special errexit behavior for `!` commands.
[O] The malformed executable-text fixture targets only its owned TEST_DIR; an
assertion verifies that the file was not created and text was not echoed.
[R] Exact parser copying plus ordinary source comparison was the smallest
solution at the existing standalone installation boundary. No extra deployed
helper or configuration layer was needed.

Exact served model was not observed; GPT-6 family is self-reported only.
Parent owns mandatory project META-THINKING-CAPTURE and progress/documentation.

Core stage-0/stage-1/shared fixture parity, full Swift regression and GUI checks
remain with the parent. These reader tests do not prove serialized physical
recovery or prevent queued restrictive writes; Phase 6 must establish that.
No Git mutation or commit was made. The eight paths are ready for integration.
