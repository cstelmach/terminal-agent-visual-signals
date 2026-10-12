# Phase 3 pytest isolation audit

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0

## Scope and conclusion

Read-only audit of pytest configuration, its Python callers, and connected source
helpers in `/Users/cs/local/code/apps/terminal-agent-visual-signals`.
No tests, hooks, installers, native apps, process signals or commands operating
on real home/runtime state were executed. No project file changed.

The smallest central fix is one environment-merging helper in `tests/conftest.py`
that preserves the already-private runner paths even when a test passes a partial
environment. It should also mirror the private TAVS temporary root into the legacy
internal `_TAVS_TMP_DIR` for title-only source calls. The fix is insufficient to
authorize the full suite: a fixed external spinner path and detached completion
workers require targeted repairs first.

## Current environment propagation defects

All test paths below are absolute suffixes beneath:

`/Users/cs/local/code/apps/terminal-agent-visual-signals/tests/`

### conftest.py

- `bash_env:45` and `zsh_env:55` copy `os.environ`, so they retain private runner
  variables if those variables were supplied before starting pytest. Direct
  unwrapped pytest inherits real HOME and does not gain isolation from these
  fixtures.
- `clean_env:62` returns only PATH, HOME and SHELL. It drops TAVS_RUNTIME_DIR,
  TAVS_TMP_DIR, XDG_RUNTIME_DIR, fake TTY, cache paths and helper selection. Its
  HOME comes from the pytest process, so it is private only under the wrapper.
- `run_bash:84` and `run_zsh:116` copy the parent environment only when `env is
  None`. Any explicit dictionary is passed unchanged to subprocess.run. A test
  that supplies only a feature toggle or fake TTY therefore loses the private
  roots. This behavior reaches `run_in_both_shells` and `source_and_run` through
  those common helpers.
- The subprocess helpers capture stdout/stderr, so an ordinary command printing
  OSC bytes is not itself a real terminal write. However, source modules write
  through TTY_DEVICE independently, and can auto-resolve a live TTY when that
  variable is absent.
- `temp_tty_file:33` owns its NamedTemporaryFile, but tempfile's root comes from
  early process TMPDIR/default selection. Have the runner provide private TMPDIR
  before Python starts. Do not add a second temporary-root framework in pytest.

### Minimum conftest.py edits

Add a small `_subprocess_env(overrides=None)` used by run_bash/run_zsh and the
existing environment fixtures. Its behavior should be:

1. With no explicit environment, copy the runner environment.
2. With an explicit environment, copy that dictionary and fill only missing
   isolation/tool-selection keys from the runner. Do not merge every ambient
   variable back into an intentionally minimal dictionary: terminal-detection
   tests deliberately remove TERM_PROGRAM/COLORTERM and similar signals.
3. Preserve PATH (including existing command stubs), HOME, TAVS_RUNTIME_DIR,
   TAVS_TMP_DIR, XDG_RUNTIME_DIR, XDG_CACHE_HOME, TMPDIR, fake TTY_DEVICE/TTY_SAFE,
   and the actual built-helper selection key supplied by the wrapper. Explicit
   owned fixture overrides remain intentional, including empty XDG_RUNTIME_DIR
   for fallback tests.
4. When TAVS_TMP_DIR is supplied privately, set the missing legacy
   `_TAVS_TMP_DIR` to that same root. Do not inherit an unrelated ambient
   `_TAVS_TMP_DIR` that would redirect a title-only call elsewhere.
5. Keep clean_env clean of stylistic/feature overrides while retaining these
   isolation keys. Its docstring should distinguish path isolation from feature
   configuration.

The current Python files make no native built-helper calls. `SWIFT_BIN` is the
existing helper key in shell parity tests, not a Python contract. Preserve the
real helper key the new wrapper actually chooses; do not invent multiple future
helper aliases or add automatic installed-binary discovery to conftest.

A short preflight that rejects a missing private runner environment is reasonable
if direct pytest is otherwise unsupported. Do not silently use real HOME or
`/tmp/tavs` as a fallback. Reuse the runner's established roots rather than adding
autouse fixtures that create another parallel isolation mechanism.

Also neutralize inherited shell startup sources at the runner/common helper:
BASH_ENV/ENV can cause noninteractive shell startup code to execute, and inherited
ZDOTDIR can point zsh outside private HOME. A private/cleared startup environment
or zsh's no-user-startup option prevents those paths. No personal startup file was
read here, and no claim is made that a harmful one is currently configured.

### Why fake TTY propagation is essential

`src/core/terminal-osc-sequences.sh:69` resolves a TTY when TTY_DEVICE is empty.
`resolve_tty():41` walks real parent processes and can return a writable device;
its fallback at line 62 opens `/dev/tty` for output. Private filesystem roots do
not prevent that device write. The wrapper's nonempty regular capture file must
remain present in every Python child that sources terminal interactions.

## Tests that still need a specific repair or exclusion

### 1. test_title_state_persistence.py

Confirmed wrong-root behavior:

- Tests export a private TITLE_STATE_DB before sourcing title-management, e.g.
  lines 114-121, 132-137, 247-264, 322-327 and 371-400.
- `src/core/title-management.sh:26` sources title-state-persistence directly.
- `src/core/title-state-persistence.sh:33` unconditionally assigns
  `TITLE_STATE_DB="${_TAVS_TMP_DIR:-/tmp/tavs}/title"`. It does not read
  TAVS_TMP_DIR and discards the pre-source TITLE_STATE_DB override.
- save_title_state writes that resulting path; clear_title_state at lines
  214-217 deletes it. TestClearTitleState can therefore delete a shared
  `/tmp/tavs/title.test_tty` even though the test owns a TemporaryDirectory.

Minimum repair: the helper's private `_TAVS_TMP_DIR` mirror prevents the shared
default escape. For true per-test ownership, set TITLE_STATE_DB AFTER sourcing
in those caller snippets, or initialize session-state with the intended temporary
root before sourcing title-management. Do not change production title persistence
merely to accommodate test ordering. Do not run this suite until the chosen route
has a meaningful assertion that the actual returned file path stays private.

Other title tests also directly source title-management and generate/read title
IDs. The same internal-root propagation is required to avoid reading shared
state, even when a particular test does not save/delete it.

### 2. test_spinner.py::TestGetSpinnerStateDir::test_falls_back_to_home_cache

At lines 45-48, it explicitly sets HOME to the fixed path `/tmp/testhome` and
clears XDG_RUNTIME_DIR. `source_spinner_and_run:23` merges the overrides into a
full inherited environment, so this explicit external HOME survives any central
missing-key propagation fix.

`src/core/spinner.sh:get_spinner_state_dir():16` chooses `${HOME}/.cache/tavs`
and immediately mkdir/chmod at lines 26-29. The test writes a fixed unowned path,
not merely prints what the path would be. Use the existing tmp_path fixture or
a TemporaryDirectory for this test's HOME; assert the resulting path is inside
that root. It needs only one local test edit, not a new fallback policy.

Other spinner write/reset tests use owned temporary XDG directories and explicit
TTY_SAFE values. They are substantially better isolated once the common helpers
retain runner roots. Do not block them merely because they exercise file writes.

### 3. test_trigger.py completion cases

Partial environments at lines 30-41, 113-115, 142-147, 179-185 and 201-207 drop
the private roots today. The central helper fix resolves that part, while retaining
each test's own fake TTY.

There is a second independent issue: completion cases spawn a detached idle worker
and then unlink the output file without terminating/waiting for that worker.
Examples:

- `TestTriggerStates.test_states_return_immediately` with state complete,
  through `_run_trigger` at lines 20-56.
- `TestTriggerStates.test_complete_state_non_blocking`, lines 81-87.
- `TestIdleWorkerSpawn.test_complete_spawns_background_worker`, lines 135-156.

The worker at `idle-worker-background.sh:109` sleeps, then checks
`[[ ! -w "$tty_device" ]] && continue` at line 112 BEFORE its max-runtime check
at line 129. Once the test unlinks the fake file, this early continue can bypass
the max-runtime exit indefinitely. Merely setting a short MAX_TIMER_RUNTIME is
not sufficient when the output file is removed first.

Minimum repair: keep the owned fake file alive while the worker is active; capture
the launched worker PID from the test's private state and terminate/wait only that
owned worker before unlink/fixture cleanup, or structure the test so the worker
reaches a short bounded exit while its file remains present. Do not use global
pkill/pgrep cleanup for the test runner.

The production trigger's complete path calls cleanup_stale_timers, which uses
`pgrep -f` and sends signals; kill_idle_timer reads a PID from STATE_DB. Private
state and a unique fake path are therefore prerequisites to running these cases.
This audit did not signal or enumerate any real process.

Until worker ownership cleanup is established, do not run the whole trigger
suite merely because environment propagation has been repaired. Pure syntax,
grep and non-worker cases can be reviewed/run separately through the wrapper.

## Other audited Python callers

- `test_title_composition.py:42` supplies only TTY_DEVICE/TAVS_AGENT to run_bash.
  This is fixed by central isolation-key propagation. Its deep-path case at
  lines 244-253 changes HOME to a synthetic string after sourcing, then only
  formats a path. No connected post-change write was found there, so it is not
  equivalent to the spinner fixed-HOME mkdir defect.
- `test_terminal_detection.py` generally copies os.environ; its minimal
  dictionaries at lines 108-114, 215-221 and 239-246 require missing-key
  propagation without restoring intentionally removed terminal indicators.
  TestDetectSystemDarkMode invokes `defaults read -g AppleInterfaceStyle` through
  source code. That is a read of actual system appearance, not a settings write;
  use a stub for deterministic private-only testing if required. Do not classify
  it as a destructive action.
- `test_idle_worker.py` checks worker functions with type/grep and calls only
  the pure stage calculator. The inspected tests do not invoke
  unified_timer_worker, kill_idle_timer or cleanup_stale_timers. They still
  source state/terminal modules, which require private roots/fake TTY. Do not
  infer that every test mentioning kill actually sends a signal.
- `test_configure.py` mostly uses syntax/grep checks. Two interaction cases at
  lines 72-85 launch the real wizard with `n` input. The wizard loads HOME-based
  configuration and has write-capable later steps. Private HOME and captured
  stdout are required; these are not installer/production-home test commands.
  The audit did not run the wizard or assume piped n proves every branch inert.
- `test_config.py`, `test_themes.py`, `test_title.py` and
  `test_shell_compatibility.py` source configuration/title helpers and use
  common run_bash/run_zsh calls. Private HOME prevents sourcing personal user.conf;
  private internal title root and fake TTY handle the connected state/device
  concerns. The inspected tests do not contain direct installer/native-app calls.
- `test_colors.py` uses pure color functions and a source self-test through
  captured subprocess output. No personal state/device write path was found in
  the inspected color module/callers. It is a suitable first narrow Python slice
  after common fixture propagation is proven.

## Minimal verification recommendation

Do not prove isolation by executing live hooks. First add/run a harmless child
environment assertion through the existing common helpers with a partial dict,
and the existing clean_env fixture: check private HOME/runtime/tmp/XDG/capture
and helper paths survived, and intentional terminal-indicator removals stayed
removed. Test that title-only sourcing sees private `_TAVS_TMP_DIR`, using an
owned path/temporary stub so no shared default file is read or deleted.

Then use the existing tests/run-isolated.sh runner for only the audited slices.
Leave spinner's fixed fallback case, title wrong-root cases and completion worker
cases excluded until their targeted repairs/ownership assertions pass. A full
pytest invocation would otherwise overstate the scope of the central fix.

No execution result or green-suite claim is made in this report.
