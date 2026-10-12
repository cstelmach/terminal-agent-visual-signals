# Phase 5: persistent suspension readers

Last Updated: 2026-10-12
Version: 1.0
Source baseline: 120c79d
Scope: source inspection only. No edits, builds, hooks, installs or live state reads.

## Smallest consistent design

Add one strict two-field state format at `$HOME/.tavs/visual-restrictions.state`:

```text
SCHEMA_VERSION="1"
SUSPENDED="true"
```

Resume writes the same schema with `SUSPENDED="false"`. Do not remove the marker to resume and
do not add PID, heartbeat, expiry, reason, schedule, challenge or runtime-directory fields.
This user choice must survive new processes, runtime cleanup, TAVS restart and reboot.

Use a core shell helper and a matching Swift reader/writer. A tiny builtins-only parser embedded
in the standalone shellrc is necessary because that installed file has no core-module bundle.
Share exact fixtures to keep semantics aligned; do not introduce a second format or a parser
fallback. The shellrc copy is an existing install boundary, not a new general-purpose framework.

Recommended read classifications:

| Input | Classification | Restrictive visuals allowed |
|---|---|---|
| File absent | active | Yes |
| Schema 1, suspended false | active | Yes |
| Schema 1, suspended true | suspended | No |
| Existing unreadable/malformed/unknown-schema marker | unavailable | No |

The unavailable policy is a recommendation, not an already locked product decision. It avoids
silently reapplying restrictions after a damaged recovery marker while reporting that the state
could not be validated. Do not claim this is a valid suspension. Ordinary hooks may still paint
their normal intent. A later explicit writer can replace the invalid marker with valid state.

## Strict data contract

- Accept exactly one `SCHEMA_VERSION="1"` and one `SUSPENDED="true"` or `SUSPENDED="false"`.
  Pick one canonical write order. The reader can accept either order if duplicate detection is
  present. It must reject unknown fields, missing fields, duplicate fields and trailing content.
- Parse literal lines as data using `IFS= read -r`; never source, eval, interpolate or execute a
  value. Do not trim arbitrary quotes or default a missing schema to 1.
- Decide newline details once in fixtures. LF with an optional final LF is simple; reject BOM,
  CRLF, comments, blank lines, shell syntax and alternate boolean spellings unless explicitly
  supported by both readers.
- Require a readable regular file, reject symlinks/special files, and report existing invalid
  inputs separately from absence. Avoid opening FIFOs or device files in a shell startup reader.
- Every read resets its classification rather than retaining a previous global result.
- Write only typed boolean state with same-directory `mktemp`, restrictive mode and atomic
  `mv`. Check write/rename errors and preserve the previous file on failure. Swift writes the
  identical text atomically to its injected persistent URL.
- Keep invalid-state diagnostics generic. No raw marker text or private paths are needed.

## Reader and caller map

### trigger.sh stage 0

`src/core/trigger.sh:42-84` independently reads soft mute and runtime hard lock and sets
`_TAVS_SUPPRESS_OUTPUT`. Suspension must be checked before both, and disabled restrictions must
leave `_TAVS_SUPPRESS_OUTPUT=0`. Dispatch bookkeeping and typed observations still run.

The current comment says stage 0 runs before any source. The smallest nonduplicated core path
is to source the pure builtins-only state helper before this gate using a builtin script-directory
expression, then call its reader. That requires updating the comment honestly: it remains before
the theme/terminal modules and requires no new subprocess. Handle a basename-only BASH_SOURCE
with `.` rather than forming `trigger.sh/visual-restrictions-state.sh`.

If the literal before-any-source hot-path boundary must be retained, embed the exact tiny parser
there too and test it against the same corpus. This is a distinct implementation tradeoff; do not
pretend a loose stage-0 approximation is equivalent to the strict shared reader.

### mute-gate.sh stage 1 and idle workers

- `_tavs_validate_mute_liveness` begins with an early return when suppression is not 1. Put the
  fresh suspension read before that return. When disabled, reset suppression and all stage-0
  lock/mute temporaries; do not let an earlier lock result survive suspension.
- `_tavs_check_mute_state` resets suppression and checks hard lock first. Put suspension above
  that hard-lock branch. It must return the existing unmuted result and leave suppression 0.
- `_tavs_mute_gate_init` must still resolve the private runtime, register the active TTY and
  preserve normal bookkeeping. Disabled restrictions should not open a pending mute buffer.
- The idle worker calls `_tavs_check_mute_state` each tick. Reuse that fresh check rather than
  remembering suspension only at process launch. It can therefore react after recovery without
  restarting the worker.
- New worker and buffer tests need to distinguish a new read from inherited suppression flags.

The currently loaded old worker code may still bypass new semantics. Updating/restarting owned
workers is a later authorized deployment task, not proof supplied by source tests.

### standalone tavs-shellrc.sh

The installed `~/.tavs/shellrc` is one copied file. `cmd-install-shell-integration.sh` copies only
`src/shell/tavs-shellrc.sh`; `cmd-sync.sh:65-67` likewise copies only that file. A source statement
pointing to `../core/visual-restrictions-state.sh` would break the installed layout. Requiring a
new installed helper expands installer/sync scope and still fails until deployed.

Embed the exact parser in the shellrc. Run it after interactive/kill-switch checks and TTY
registration, before lock/mute reads or any palette/background/title paint. Suspended/unavailable
returns silently while retaining active-TTY registration. This means a newly opened terminal
still participates in future recovery and explicitly resumed rules.

It must remain compatible with Bash 3.2 and zsh. Avoid Bash-only parameter case conversion,
associative arrays and read options with different zsh semantics. A plain literal-line loop and
ordinary `case`/`[[ ]]` are enough. Do not make shell startup depend on jq, Python, Swift, native
Automation permission or the CLI being on PATH.

### lock-state-lib.sh

`_tavs_lock_read` remains raw configured state. `_tavs_lock_write` still saves finite definitions
and grants. `_tavs_lock_effective` gains a fresh suspension check before evaluating its existing
predicate. A disabled restriction is not visually effective even when a saved lock is unexpired.

Connected callers:

- `cmd-lock.sh:_lock_status` reports configured state plus effective state. It needs a suspension
  line even if no `lock.state` exists, because suspension is independently persistent.
- `cmd-lock.sh:_lock_unlock` uses the effective predicate before the challenge. While suspended,
  no challenge or new grant is needed; the saved lock stays unchanged. Make its message explicit
  rather than misleadingly saying there was no saved lock.
- `cmd-schedule.sh:_schedule_challenge_gate` uses the same predicate. Suspension therefore makes
  edits ungated without inventing another challenge path or silently modifying saved rules.
- `challenge.sh` can remain the verifier. Recovery suspension does not call it. Existing direct
  challenge tests continue to test configured challenge behavior.

### CLI status and new locks

`cmd-status.sh` currently displays configuration, without live restriction state. Add one short
unfiltered status line sourced from the common reader. `cmd-lock.sh:_lock_now` still writes the
requested definition but must not promise immediate paint while suspended/unavailable.

Minimal wording:

```text
Visual restrictions: suspended; saved rules apply after explicit resumption.
Lock saved until HH:MM; visual restrictions are suspended.
Effective: not locked (visual restrictions suspended).
Visual restriction state unavailable; restrictive visuals disabled.
```

Do not say the schedule is deleted, paused permanently or resumed. `cmd-schedule.sh`'s status
block presently prints Muted directly from mute.state. If touched, add the same suspension line
or label the displayed mute as configured/projection state, so it does not contradict recovery.
Keep new state strings free of em dashes.

### Scheduler projection

Compute schedule/lock definitions and merge expiry normally, then apply suspension only to the
effective visual mute/lock projection and published status. Do not overwrite `schedule.json`,
grant definitions or a saved finite lock merely to recover visibility. New CLI/GUI locks may be
saved while suspension keeps them inert.

Keep evaluation timers/watchers alive; explicit resumption must see the then-current schedule.
Resume does not resurrect Manual/Automatic focus. In Phase 5 those modes are not implemented;
leave their Off launch semantics intact.

## Pending output and Phase 6 boundary

`Scheduler.finishEvaluation` currently calls `clearPausedVisualAndReplayPending` when mute goes
true to false. That method calls both `broadcastPausedClear` and `Broadcaster.broadcast`.
`broadcast` writes cached raw OSC files, including historical title and alert bytes.
Suspension must not be modeled as this ordinary unmute transition.

At a minimum, Phase 5 must avoid replay on entry to suspension/unavailable state and prevent
restrictive repaint during subsequent evaluations. It may leave physical clearing to Phase 6,
but must report that independent recovery is not implemented yet. The ordinary legacy unmute
behavior for unaffected paths can remain until Phase 6 replaces it with typed intent composition.

There is no `clearPending()` implementation in current source; only an old Scheduler comment
mentions it. Do not call a nonexistent helper or mistake that comment for available behavior.

Other risks to hand to Phase 6:

- `_tavs_mute_buffer_close` can publish a buffer opened before suspension after recovery has
  invalidated pending bytes. A policy check performed only at buffer open does not order this.
- Trigger's `replay` debug subcommand directly cats a pending cache to a TTY and removes it.
  It is not a recovery renderer and should not authorize stale replay while suspended.
- Idle safety reset forcibly sets suppression 0 and writes reset/title bytes. The generation
  and fresh serialized policy requirement must eventually cover this writer too.
- Persisting suspension and later repainting alone does not stop a queued restrictive write.
  Phase 6 must fresh-check state under shared serialization inside the bounded device writer.
- Old pending data must not survive to replay after a later resume/unmute. Clear/invalidate only
  obsolete opaque output while preserving typed observation/ordinary-intent records. Do not
  strip BEL indiscriminately because BEL is also an OSC terminator.

These are runtime requirements, not reasons to introduce a control plane or extra daemon.

## Connected test isolation audit

No tests were run in this exploration. All proposed runs must use `tests/run-isolated.sh` and an
explicit source-built `TAVS_TEST_HELPER_BIN`; no live scheduling E2E or installer/sync invocation.

| Test | Existing safety | Remaining issue before broader invocation |
|---|---|---|
| unit/shellrc.bats | Private HOME/runtime, fake TTY, stdout paint | Verify Bash and zsh through private ZDOTDIR; copied-shellrc test must run without source modules |
| unit/cmd-lock.bats | Private HOME/runtime and owned cleanup | pgrep is read-only; no real app is modified; stub if output must be deterministic |
| unit/challenge.bats | Private HOME/runtime, stdin prompts, private pool | Keep no-challenge suspension case separate from existing challenge validity tests |
| unit/mute-gate.bats | Private HOME/runtime, /dev/null, stubbed default mkdir/id | DEBUG_MUTE/DEBUG_ALL sink is fixed /tmp/tavs-mute-trace.log; runner clears flags, so do not enable without private sink repair |
| integration/lock-gate.bats | Private HOME/runtime, regular fake TTY, processing only | env -i drops TMPDIR/XDG/state/helper overrides; forward them before complete-hook or organizer-helper testing |
| integration/idle-worker-mute.bats | Private worker/state/runtime/XDG; owned worker killed/waited | Preserve stop-before-delete ownership and do not reuse dead PID; new state marker goes in the worker's private HOME |
| integration/emit-osc.bats | Private HOME/runtime and fake captures | env -i cases lose runner helper/state overrides; audit before extending full trigger behavior |

The runner's outer HOME and the per-suite HOME are both private, but an inner `env -i` can still
drop TMPDIR and select a non-runner legacy state path. Isolation is not established merely by
the outer wrapper. Propagate the small relevant allowlist through those children explicitly.

## Focused acceptance tests to add

1. Shared text-fixture classifications for shell, Swift, stage 0 and standalone shellrc: absent,
   true, false, unknown schema, missing/duplicate/unknown fields, wrong quotes, executable syntax,
   CRLF/BOM/trailing content and unreadable/nonregular markers.
2. Valid suspension overrides overlapping soft mute and finite hard lock, including stage-0
   true flags already set before stage-1. Ordinary hook bookkeeping/intent still proceeds.
3. A worker starts restricted, then reads a newly persisted suspension on the next tick and
   releases suppression. Do not claim physical ordering from this check alone.
4. Copy only shellrc to a fixture's `.tavs/shellrc`, hide repo-relative dependencies, and source
   it in both interactive Bash and zsh. It registers fake TTY and emits no restrictive OSC.
5. A new process and a recreated empty runtime still honor the persistent marker.
6. Saved schedule/lock/grant bytes remain identical across suspension reads and recovery policy
   evaluation. A newly requested lock is saved but reports inert while suspended.
7. `_lock_unlock` and schedule mutation guard do not call a challenge while suspended. Use a
   verifier stub that fails if called; verify configured lock survives without a new grant.
8. Scheduler ticks/relaunch never call restrictive broadcaster methods or pending replay while
   suspended/unavailable. Explicit false re-enables the current rule, not prior selective mode.
9. Invalid marker is reported as unavailable in CLI/GUI; no raw marker content is echoed or run.

## Limitations

This report does not validate live rendering or independent recovery. Phase 5 is the shared
reader/projection foundation; Phase 6 must establish serialized device ordering and repaint.
No personal home/runtime state, native app, installer or live process was modified.
