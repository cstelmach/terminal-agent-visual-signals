# Phase 3 progress appendix

> Parent: [PROGRESS.md](PROGRESS.md)
> Scope: completed Phase 3 isolation logs
> Consolidated: 2026-10-12

### Phase 3 COMPLETE: 2026-10-12 11:14 CEST

Added a small command runner with private child HOME/runtime/tmp/XDG/cache, a regular capture
file, an explicit TAVS_TEST_HELPER_BIN and retained full logs/status. Direct invocation uses
Bash -p so inherited BASH_ENV cannot execute before the clean child environment exists.
Python helpers preserve only missing isolation keys in partial dictionaries, keeping intentional
terminal-indicator removals. Private TAVS_TMP_DIR is mirrored to legacy _TAVS_TMP_DIR for
standalone title sources. Missing runner context raises before those helpers launch a shell.

Repaired idle-worker-mute's runtime/state/cache paths and stop-before-delete cleanup; all worker
scripts/captures are fixture-owned, and already-reaped PIDs are cleared. The mute default-path
test stubs id/mkdir and never touches the live UID directory. Priority-pinning has private
capture/state paths, no silent trigger-error swallowing or environment-dependent skips, and
exact OSC 11 processing/permission assertions. Its final processing dispatch waits through the
existing 400 ms protection; no production state-priority behavior changed.

Red evidence: missing runner produced three failures; old idle fixture failed private-path
assertion; an inherited Bash startup file ran before the -p fix. The first integrated run
also caught a mkdir-call assertion depending on an existing default directory and a priority
assertion inside the permission grace period. Both fixture assumptions were corrected with
controlled identity and timing. The first Python probe used an interpreter without pytest;
the corrected probe uses the installed pytest command, adding no dependency. Failure logs
remain under `/tmp/tavs-phase3-20261012T105131/` and retained runner directories.

Final verification: 33/33 affected Bats tests; 230/230 audited Python tests in 9.80 seconds;
237/237 Swift tests in 1.980 seconds, with fresh scratch build completing in 15.58 seconds.
Runner Bash syntax and Python compilation passed. Each changed Bats file was separately
preprocessed by Bats and checked with bash -n. ShellCheck passed with existing dynamic-source
SC1091 and Bats subshell-model SC2030/2031 notices excluded; new quoting findings were fixed.

The audited Python run covered colors, idle helper functions, config, themes, shell compatibility
and terminal detection. It did not invoke trigger completion workers or the full Python/Bats
suites. Before broader runs, repair spinner's fixed HOME, set title DB overrides after source
for per-test ownership, and stop owned completion workers before removing their fake TTY.
Details: [isolation audit](PHASE3-PYTEST-ISOLATION-AUDIT.md), saved from the read-only explorer.
The new wrapper is not an arbitrary-command sandbox; explicit path overrides still need audit.

No production source, personal state, live schedule, terminal paint, native app operation,
installer/sync or unrelated process changed. Root hard-lock state, PLAN and SPEC body are fixed.
Phase 2's required native acceptance remains Blocked. Next: Phase 4, typed observations and
latest ordinary background intent, using the runner and the fresh built helper in this scratch.

### Phase 3 started: 2026-10-12 10:57 CEST

The operator explicitly resumed the goal. Native status is active; source is clean at 90883bf.
Execute-spec E1 skips a Blocked phase to the next Not Started phase. Although PLAN's top-level
graph is sequential, test isolation consumes no native UI acceptance result. Proceeding with
this independent foundation corrects the earlier overbroad stop. Phase 2 remains unverified;
neither phase status nor future release acceptance is weakened. PLAN and SPEC body stay fixed.

Backups/scratch: `/tmp/tavs-phase3-20261012T105131/`. Read-only Python isolation exploration is
running; the parent audits the three shell fixtures. Confirmed source leaks are the live UID
runtime in idle-worker-mute, the unset-runtime default test, partial Python environments and
fixed priority-pinning TTY files. Tests first use controlled paths/stubs, never real defaults.
Broader suites will run only after their overrides and process cleanup are audited.

> Return to [PROGRESS.md](PROGRESS.md).
