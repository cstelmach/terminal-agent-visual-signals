> Source check of the uncommitted correction on baseline `bd89fe3`, before test strengthening.
> The source guards are committed in `47fdf9b`. Helper-result and timer-continuation assertions
> were strengthened afterward; see [final review corrections](final-review-corrections-2026-10-13.md).
> Original: /tmp/explorer-tavs-synthetic-restore-check-20261013.md.

# Review Report

## Metadata

- reviewer: GPT-6, focused host source assessment
- review_type: code
- review_mode: coaching
- tier: standard
- date: 2026-10-13
- target: current working diff in `src/core/trigger.sh` and
  `tests/integration/background-intent.bats`
- execution: read only. No tests, builds, helper invocations, devices, native apps or source edits.

Related functions were inspected directly to establish call behavior. Only this requested report
was written. The review covers the requested timer/state/counter race, not all terminal styling
or native application behavior.

## Rubric Scores

| Dimension | Score | Evidence |
|-----------|-------|----------|
| correctness | 8 | All timer/state/counter writes on the two reachable restore branches are guarded. |
| security | 8 | Output still uses managed validation; no new direct-output path or trust boundary. |
| maintainability | 8 | Small branch guards; existing helper and context contracts are reused. |
| test_coverage | 6 | Real helper barrier reaches the dangerous interval; outcome and full-exit evidence are incomplete. |
| completeness | 8 | Requested side-effect paths are covered in source; ordinary hook branches are preserved. |

## Verdict

**verdict**: CONCERN
**confidence**: high for the inspected source logic; runtime behavior is unverified.

No source defect was found in the requested fix. The concern is test evidence, not a remaining
timer/state/counter mutation in the changed branches.

## Forced falsification

1. A Stop after successful context precheck could still let the delayed processing branch kill its
   timer or erase its timer PID. Rejected by the new guards at `trigger.sh:216` and `:230`.
2. A SubagentStart after precheck could cause the delayed subagent branch to increment the new
   count. Rejected by `trigger.sh:352-355`; its state write is also guarded at `:363`.
3. The synthetic child might replace the context by going through Claude intake again. Rejected:
   `trigger.sh:416-418` invokes the core script directly with the inherited context, and
   `organizer-state.sh:55` skips synthetic observation publication.
4. The barrier might report success before a formerly dangerous state/counter write. Rejected for
   this specific diff: those writes precede the final flush, while `returned` is written after the
   real managed-render helper returns. It is nevertheless not proof that the whole trigger exited.
5. Markers might be satisfied by a transient helper failure instead of successful current rendering
   or deliberate stale rejection. Confirmed as an evidence limitation below.

## Findings

### [R1] MEDIUM: barrier markers do not distinguish the helper result

- **Situation:** `background-intent.bats:301-318` stores `result`, but writes `returned` and
  `stage-ready` without checking it. The script waits for those markers at `:353-357` and
  `:367-371`.
- **Behavior:** `returned` can be created after render failure code 1, after stale code 3, or after
  success. The first current completion-worker render can also create `stage-ready` on a failed
  attempt. The latest-intent check at `:386` establishes retained delivery identity, not successful
  paint, because current `VisualRecovery` can publish before device open (`:155-165`).
- **Impact:** The tests meaningfully catch the old timer/state/counter mutations, but a pass does
  not prove the delayed render was rejected specifically as stale or that the completion worker's
  render succeeded. A failed completion stage can also retry and legitimately rewrite the state
  DB (`idle-worker-background.sh:140-147,180-182`), creating a false failure in the byte comparison.
- **Suggestion:** Have the proxy record the returned status alongside each marker. Assert result 3
  for the superseded restore and result 0 for the current stage. This is a small test-only oracle;
  it needs no extra runtime control mechanism. Keep the existing state, count and intent checks.

### [R2] LOW: helper-return and PID existence do not prove complete child termination/liveness

- **Situation:** `background-intent.bats:313` writes `returned` before proxy exit at `:318`.
  Assertions then begin at `:372`, and `:379` uses `kill -0` to check the timer. `_owned_pty`
  at `:28-32` waits for the foreground test shell, not the disowned restore grandchild.
- **Behavior:** The synthetic trigger is still finishing its command substitution and flush when
  the marker appears. A successful `kill -0` establishes that the PID exists at that instant;
  it cannot alone rule out pending termination or a process temporarily remaining as a zombie.
- **Impact:** The test does not prove whole-trigger exit or continued timer work. This does not
  allow the old `record_state`/counter defects to slip past the marker: those effects were before
  the helper call. With titles disabled, the current post-helper restore path has no relevant
  state/counter/timer writes, so the incomplete wait is a coverage limit rather than a demonstrated
  source race.
- **Suggestion:** If complete process/liveness proof is required, add a test-only exit marker on
  the synthetic core invocation and wait for it before final assertions. For timer continuation,
  wait for one later successful owned stage with that same recorded timer PID. Do not substitute
  a longer arbitrary sleep. The primary regression test can otherwise retain its narrower claim.

## Source trace and requested behavior

### The dangerous interval is protected

`trigger.sh:411-420` sleeps, checks the frozen managed context, reads the current subagent count,
then executes either core `subagent` or core `processing` with
`TAVS_ORGANIZER_SYNTHETIC=1`. A newer hook can occur after line 413 succeeds. The fix does not
depend on that precheck remaining current for protecting nonvisual side effects.

- Processing skips new-prompt count reset and identity work at `:205`, skips
  `kill_idle_timer` at `:216`, and skips `record_state` at `:230`.
- Subagent skips both `increment_subagent_count` and `kill_idle_timer` at `:352-355`,
  and skips `record_state` at `:363`.
- Neither branch starts `unified_timer_worker` or calls `cleanup_stale_timers`.
- `should_change_state` only reads the state DB and calculates priority/time
  (`session-state.sh:105-121`). It does not replace a timer or write state.
- The invoked visual helpers queue a managed batch. Their inspected paths do not call the timer,
  counter or state-writing functions. The module-source/init path registers the TTY and may do
  normal support bookkeeping; it does not write `STATE_DB` or alter the subagent count.

The precheck parent's `has_active_subagents` is a read. If it observes the newer count 1, choosing
the subagent branch no longer counts that restoration as another spawn. A real SubagentStop
retains its existing decrement behavior; the delayed restore cannot execute that branch.

### Current restoration still reaches the existing managed helper

The new guards suppress state side effects, not rendering. Processing/subagent still queue the
configured background, palette, title and image, and call the final `_tavs_render_flush` at
`trigger.sh:430`. Synthetic bell queueing is suppressed by the existing
`organizer-state.sh:134` rule.

`_tavs_render_flush` at `organizer-state.sh:175-177` invokes the existing `--managed-render`
helper with synthetic flag 1 and the inherited context. The native entry builds the synthetic
render at `managed-output-entry.swift:94-117` and calls `recovery.render` at `:130-133`.
The state path validates synthetic publication before open, and the opened-device callback
revalidates the render context at `visual-recovery.swift:208-213`. A newer observation therefore
rejects the stale output even when the earlier context precheck succeeded. No raw output or
alternate rendering fallback was added.

For a still-current tool-error delivery, the same context remains valid. After the 1.5 second delay,
the 400 ms state priority grace has expired (`session-state.sh:32,116-120`), allowing the configured
processing/subagent restoration to render. Its session DB intentionally remains the meaningful
tool-error hook's record until another meaningful hook or timer changes it; this is paint-only
restoration. Source supports the path, but the existing positive test at
`background-intent.bats:213-225` only checks observation retention and a later intent timestamp.
Add an expected processing/subagent background and successful helper outcome/PTY output check
if the acceptance claim includes actual successful paint.

### Meaningful hooks keep their previous behavior

For normal hooks, `TAVS_ORGANIZER_SYNTHETIC` is absent or 0. Every new condition therefore takes
the previous side-effect branch: new prompts reset the subagent count and revalidate identity;
processing kills the prior timer and records processing; SubagentStart increments once, kills
the prior timer and records subagent. The complete, permission, idle, compacting, reset and
SubagentStop branches are not changed by this diff. The timer's synthetic export occurs in its
background subshell, so it does not set the parent's environment for later real hooks.

### The test barrier is meaningful and bounded

The proxy first calls the real helper and creates `validated` only on successful
`--managed-check-context` while `RESTORE_BARRIER=1` (`:303-304`). That environment is attached to
the old tool-error invocation alone. The newer hook is issued while the old precheck is held at
the barrier. The old restore is released only after the newer session state is sampled, and the
completion case also waits for a timer-managed-render attempt. The synthetic argument check
`${6:-} == 1` is correct for the shell helper argument layout.

The marker polling loops all end with explicit existence assertions. Barrier timeout or absence
of a managed render fails the test instead of silently passing. The 3 second proxy release window
can be a loaded-host false failure, but it is not an unbounded or fail-open wait. The newer states
have the same or lower priority than the delayed processing/subagent branch, so priority suppression
does not conceal the mutation being tested.

Without the guards, the completion case's restored processing branch would kill the newer timer
and replace its DB row; the subagent case would increment 1 to 2 and replace its DB timestamp.
Those operations occur before the helper-return marker, making the byte/count checks meaningful
regression assertions even when the native helper correctly rejects the old render.

## Summary

The changed source prevents the delayed restore from killing or replacing a newer completion
timer, writing its session DB, or incrementing a newer subagent count after precheck success.
It preserves ordinary hook behavior and the existing managed rendering route. The barrier test
covers the relevant interval, with the outcome and process-completion limits described above.

Skipped tests, builds, helper/native execution and device/UI checks. Runtime timing, successful
paint and continued timer execution remain unverified by this read-only assessment.
