# Scheduler projection-write verification

Last Updated: 2026-10-14 (Europe/Vienna)
Version: 1.0
Source baseline: `77bda67`.

## Parent verification and disposition

Codex R2 is confirmed and corrected: required persistence now gates transition/paint caches and
heartbeat terminal retries. Both lock/mute attempts still run; timers and actual disk observations
remain active on failure. Existing status text exposes storage failure while preserving requested
or suspended state. No transaction framework, new timer or rollback of user definitions was added.

Direct lock/grant callers now report persistence failure. A grant's discardable Bool reports its
actual durable acceptance, independently of a subsequent mute failure. A genuinely absent lock
remains a no-file no-op. Unknown/nonregular/oversized records cannot certify no-op success and are
preserved; readable semantically unchanged records can remain usable in read-only directories.
These checks do not establish general root trust, reader-race safety or bounded LockStateReader I/O.

| Check | Result | Isolated log ID |
|---|---|---|
| Seven initial regressions | 13 expected assertions failed | tlK6dw |
| Initial lifecycle correction | 42/42 passed | RYaS5C |
| Direct-call and lock checks | 64 tests, one fixture failure | haEKMW |
| Repaired fixture and owned-PTY integration | 65/65 passed | mupO0o |
| Full Swift suite | 609/609, 16.301 seconds | D6toCz |
| Serial release build | Passed in 29.58 seconds | hj0ZJJ |

haEKMW's read-only fixture omitted the resolved foreground color, so its initial lock was not
semantically equal and legitimately required a write. The fixture now supplies both colors;
production availability checks were not weakened. Thirteen final new cases include actual
Scheduler/Broadcaster/VisualRecovery/SystemProcessRunner output after repairing an owned state
endpoint, with no duplicate heartbeat paint. Native enumeration is an empty fixture, and process
identities are simulated. Bytes do not prove visible Ghostty acceptance or kernel-held recovery.

The source explorer's optional scores/verdict below are read-only judgments, not the required
final Codex/Claude/AGY reviews or runtime certification. Parent checks confirm the inspected cache,
timer, status and grant behavior. SPEC/PLAN and the 100 ms device writer remain unchanged. Linux,
headless feedback, historical timing attribution, broader storage trust and native acceptance stay
open. No live installation, settings/schedule change, session shutdown or native operation occurred.

## Read-only exploration and source check

The full report below is preserved unchanged.

# TAVS projection-write retry exploration

Last Updated: 2026-10-14
Version: 1

## Scope and outcome

Read-only source exploration of Scheduler, connected callers, file watching,
timers, projection writers, and existing tests. No repository changes, tests,
native app operations, settings access, or container operations were performed.

The minimum complete fix is to return write success as Bool, keep scheduling and
runtime observation alive on failures, and gate transition bookkeeping plus
broadcasts on successful required projections. The heartbeat retry caller must
also consume that outcome. No two-file transaction or rollback framework is
needed.

All paths below are under:
`/Users/cs/local/code/apps/terminal-agent-visual-signals/`.

## Confirmed failure paths

- `src/macos/TAVSApp/Sources/TAVSApp/Scheduler.swift:410-429` assigns
  `previousMuted` before writing either file. Both writer helpers catch failures
  and return Void. A failed transition therefore consumes its own retry signal.
- `Scheduler.swift:403-407` clears pause paint bookkeeping for suspension before
  either write. These are also success caches and should move after the write
  gate.
- `Scheduler.swift:436-445` calls `paintMuted`, which updates
  `lastPaintedPauseVisual` and `lastPaintedWasLock` at lines 476-477 even when a
  projection failed. Repairing storage may then produce no new paint request.
- `Broadcaster.swift:27-35` ignores the passed visual/title snapshots and queues
  `.currentRestriction`. Managed work reads the persisted projections through
  `VisualRestrictionPolicy.current`. This makes write-before-broadcast a real
  behavior requirement.
- `Scheduler.swift:494-498` calls `retryFailedRestrictions` after every heartbeat
  evaluation, independent of write success. That retry can also consume stale
  persisted rules. Merely returning early from `finishEvaluation` does not close
  this caller path.

## Minimum propagation and ordering

1. Make `writeLockStateIfChanged` and `writeMuteState` return Bool. A completed
   atomic write returns true; a failed required write returns false. Keep the
   low-level `LockStateWriter.write` and `MuteStateWriter.write` throwing APIs.
   They already report failure correctly.
2. Capture `wasMuted = previousMuted`, but do not assign `previousMuted` yet.
   Compute the desired projections exactly as today, including requested mute,
   hard cause, and grant preservation.
3. Attempt the required projection writes, then gate transition broadcasts,
   paint-cache changes, and a successful published status on their outcome.
   Evaluating both writes into local Bool values avoids accidental `&&`
   short-circuiting when independent mute persistence is useful during recovery.
4. After both required projections are available, assign `previousMuted`, clear
   disabled paint bookkeeping, and perform the existing transition/repaint logic.
   Keep clear-before-replay and write-before-clear ordering.
5. Return evaluation success through `finishEvaluation` and `loadAndEvaluate`,
   using `@discardableResult` if existing non-heartbeat callers should ignore it.
   Gate heartbeat terminal retries on evaluation success and an active
   restrictions marker.

Returning false must not mean scheduling is abandoned. `loadAndEvaluate:331`
cancels every timer before evaluating. Put heartbeat, transition, lock expiry,
and grant expiry scheduling before the failure return, or in a shared deferred
tail after the merged lock has been computed. Preserve the 60-second repeating
timer and exact epoch wakes. A single heartbeat retries storage; no additional
retry mechanism is necessary.

`lastReadLockState` is an observation cache, not a transition-success cache. It
should still reflect an actual read of disk after an attempt, including partial
success. Do not assign the desired merged value to it. A successful lock write
followed by a mute failure otherwise causes the runtime watcher to keep seeing
the app's own lock change. The preserved heartbeat supplies retry after observing
that partial success.

## Suspension must remain independently effective

Read `visualRestrictionsState` before the projection gate, as today. Both
`.suspended` and `.unavailable` disable new restrictive visuals and heartbeat
retries. `VisualRestrictionPolicy.swift:27-31` independently obeys that marker
before reading rule projections; a projection failure must not replace or undo
the marker.

If the failure path leaves prior published state intact, ensure it does not leave
an effective UI hard lock while the authoritative marker disables restrictions.
At minimum preserve `visualRestrictionsStatus`, publish the disabled status, and
set `isHardLocked` false for disabled restrictions. Keep `previousMuted` and paint
bookkeeping available for eventual write-success reconciliation. Show storage
failure through the existing status surface, without reporting a completed
Active/Locked/Unlocked transition.

After storage repair while suspension persists, writes should save
`MUTED="false"`, retain `REQUESTED_MUTED` and `MUTE_LEVEL`, then clear prior paint
once. Explicit re-enable must repaint the current requested pause or lock.
Neither rules nor suspension should be modified by this fix.

## Direct lock and grant callers

There is no `requestUnlock` symbol in this checkout. The direct writer caller is
`Scheduler.grantUnlock(untilEpoch:)` at lines 316-325. Its only Swift caller is
`MenuContent.swift:54`, after the challenge and grant-end picker.

Recommended Bool semantics for `grantUnlock`: true means the grant was actually
saved; false means state was absent/unreadable or the grant write failed. Return
on write failure instead of re-evaluating and overwriting the failure status with
an apparently ordinary lock status. Existing timers remain armed because this
caller has not entered `loadAndEvaluate` yet. On successful grant persistence,
evaluate immediately, then report success of the durable grant even if a later
mute projection fails. That failure remains a pending projection problem, not a
failed grant save. Never return false as though no grant exists after persisting
one successfully.

`lockNow:310-311` is the other helper caller. Consume its Bool too. A failed manual
lock write must not appear to accept the lock request or overwrite a useful
failure status by immediately evaluating unrelated current state.

Existing tests seed grants directly; none invokes `grantUnlock`. New direct-call
coverage is needed for success, write failure, and a saved grant followed by a
failed mute projection. Confirm the grant end, original lock end, hard-only
unmute behavior, and grant expiry wake.

## No-op branches and unavailable storage

`Scheduler.swift:570-575` has two early-success candidates:

- Nil existing state plus no lock/no grant intentionally creates no lock file.
  Keep that behavior for a genuinely absent usable path. However,
  `LockStateReader.read` collapses absence, unreadability, malformed content, and
  other read failures to nil. A directory at `lock.state`, an invalid URL, or an
  unusable parent is not confirmed benign absence. Turning the current return
  into unconditional `true` would certify those cases without an attempted
  write.
- A readable, regular, semantically equal existing state requires no heartbeat
  rewrite. Return true even if its parent is read-only: the required projection
  already exists. Do not equate write permission with projection correctness.

The equality branch has a connected reader mismatch: ordinary
`String(contentsOf:)` in `LockStateReader` follows symlinks and has no 8192-byte
limit, while `VisualRestrictionPolicy.readRule:100-114` rejects nonregular paths,
symlinks, and oversized files. A readable symlink-backed lock can therefore
compare equal while managed policy reports storage unavailable. Its existing
policy regression at `visual-restriction-policy-tests.swift:210-236` explicitly
checks symlinks, FIFOs, oversized files, unreadable files, and directories.

A small local check before accepting a no-op can distinguish confirmed absence
from unavailable paths and ensure an equal file is usable by the managed reader.
Otherwise attempt the canonical atomic write and return its actual result.
Avoid changing D3 malformed-lock semantics: malformed data means no active lock,
but it does not establish storage availability. No new persistence layer is
needed.

## Tests to preserve and focused regressions

Existing behavior coverage:

- `SchedulerLockTests:94-128`, `:198-218`: suspension preserves manual lock/grant
  definitions and their exact expiry timers.
- `SchedulerLockTests:239-253`: unmuted projection is written before clear/replay.
- `SchedulerLockTests:273-283`: soft pauses intentionally create no lock file.
- `SchedulerLockTests:307-344`: grants suspend hard-caused mute only and survive
  schedule merging.
- `LockStateTests:134-146`: merge preserves active grants and drops expired ones.
- `SchedulerTests:401-435`, `:459-550`: suspension/unavailable markers disable
  visuals, preserve requested rules, clear once, and permit explicit repaint.
- `SchedulerTests:437-457`: heartbeat retries terminal failures only while
  restrictions are enabled.
- `SchedulerTests:552-621`: startup, watcher, heartbeat, and timer lifecycle.
- `SchedulerTests:938`, `:1028`, `:1203`: stable paints and persisted startup mute.

Focused additions:

1. Fail mute persistence on entering a pause; assert no premature paint, timers
   remain armed, then repair storage and fire heartbeat to obtain one paint.
2. Fail mute persistence on leaving a pause; assert no clear/replay, then repair
   and assert written unmuted state before one clear and replay.
3. Fail lock persistence for a hard transition; assert no mute/paint success cache
   consumes the transition and repair produces one locked paint.
4. Change pause visuals during a failed persistence attempt; successful later
   persistence must repaint the new visual exactly once.
5. Activate suspension during a projection failure; assert marker preservation,
   disabled restrictions/retries, heartbeat and expiry timers, then repair and
   explicitly resume.
6. Exercise failed/successful direct grant save and benign/unsafe lock no-op paths.

Use a directory at a state-file endpoint or a file blocking an intermediate
directory to produce deterministic failures. Separate schedule, projection, and
explicit restriction-marker URLs so the injected projection error does not
accidentally turn the marker unavailable and hide the actual failure under test.
Mocks already expose broadcast ordering and timer handlers; no new mock writer
framework is necessary.

## Limits and session observation

These conclusions are grounded in current source. No runtime reproduction,
Swift test execution, native acceptance, or permission probing was performed.
Nothing here changes the 100ms device writer deadline or D01-D18 decisions.

[O] Exploration followed callers from Scheduler through Broadcaster and fresh
policy reads, then checked existing behavioral tests. This exposed the heartbeat
retry bypass and the mismatch between lock no-op inference and managed policy
path validation. The main session's meta-thinking capture can cover this
delegated exploration; this read-only agent did not mutate that repository file.

The memory quick pass was limited to `MEMORY.md:746-749`, which supplied the scope
reminder to preserve terminal sessions and recheck live operations. No historical
runtime state was relied on.

## Follow-up source-check of the implemented diff

### Metadata

- reviewer: Codex delegated source-check
- review_type: code
- review_mode: coaching
- tier: standard
- date: 2026-10-14
- target: Current Scheduler.swift, SchedulerTests.swift, and BroadcasterTests.swift
  working diff. Connected MenuContent caller checked again.

### Potential problems examined before scoring

1. Failure might cancel timers permanently. Disproved in the current diff:
   `finishEvaluation:466-473` always schedules heartbeat, schedule transition,
   original lock expiry, and grant expiry after attempting both writes. The
   success condition only wraps transition/cache/broadcast work.
2. Heartbeat might still retry a terminal restriction from stale files.
   Disproved: `projectionSaved` is reassigned from both write outcomes on every
   finishEvaluation, including the no-config path, and heartbeat retry at
   `Scheduler.swift:505` requires it plus an enabled restrictions marker.
3. Suspension could lose its independent disabling semantics when projections
   fail. Disproved for the scoped behavior: the marker is read before projection
   work; published muted/reason/hard-lock state uses the disabled override even
   on write failure; status retains the suspended/unavailable message behind the
   storage-failure prefix. Paint bookkeeping only changes after storage success.
4. Unlock could claim success without a durable grant, or reject a grant that was
   saved before a subsequent mute failure. Disproved: `grantUnlock:322-335`
   returns false before failed persistence and true after the common writer
   succeeds. The following evaluation does not change that acceptance result.
5. A valid unchanged lock in a read-only directory could be rejected needlessly.
   Disproved by source: the regular, sized, parsed path check precedes semantic
   equality, which returns true before any directory/write operation. The
   repaired read-only fixture now copies both resolved background and foreground
   into the saved lock, so it exercises actual semantic equality.

### Rubric Scores

| Dimension | Score | Evidence |
|-----------|-------|----------|
| correctness | 8 | Both write results gate transition/paint caches and heartbeat retries; timer and readback tail remains unconditional. |
| security | 7 | Local no-op rejects known unsafe/unknown records without replacing them; broader root, trust, and reader-race concerns remain outside this fix. |
| maintainability | 8 | Two Bool returns and one private success flag retain the existing scheduling and broadcasting structure. |
| test_coverage | 7 | Focused failure/repair, grant, suspension, visual-change, unsafe-path, and owned-PTY integration assertions are present; this reviewer did not run them. |
| completeness | 8 | Direct lock/grant callers, heartbeat retry caller, normal transition callers, and persistence failure status are covered in source. |

### Verdict

**verdict**: APPROVE

**confidence**: medium

This is an approval of the scoped source change, not runtime test certification
or release/native acceptance.

### Findings

No actionable regression found in the current R2 source diff.

`MenuContent.swift:54` continues to ignore the discardable grant result, but its
displayed `scheduler.statusText` exposes the persistence failure. The new Bool
does not require a new UI confirmation flow. Failed direct lock/grant requests
return before re-evaluation, keeping their failure status and existing timers.

Unknown/nonregular lock records are deliberately preserved and make projection
success false. This differs from benign absent-lock no-op and is explicitly
tested. It does not establish general LockStateReader/managed-reader agreement.
Shared runtime root/trust and reader races remain separate.

### Regression coverage and limits

The new Scheduler tests exercise pause entry failure, release failure, hard lock
failure, unavailable no-lock destinations, suspension while writes fail, direct
manual lock failure, unknown records, changed pause colors, absent grant state,
failed grant writes with unchanged lock ends/timers, accepted persisted grants
despite mute failure, grant expiry, and a symlink-backed lock. Existing lock tests
continue to cover hard-only grant semantics and exact suspension expiry timers.

`BroadcasterTests.swift:429-456` now connects Scheduler, the real Broadcaster,
fresh VisualRestrictionPolicy reads, VisualRecovery, and SystemProcessRunner to
an owned PTY. It asserts no bytes during failed persistence, the exact requested
pause OSC sequence after storage repair, and no duplicate bytes on the next
heartbeat. The test's nativeSnapshot closure is empty and its process identities
are test fixtures. It is meaningful hermetic integration coverage; it does not
prove recovery of a kernel-held terminal write, a native catalogue, or a real
running terminal application's visible state.

This reviewer performed source inspection only. No tests, file permission
changes, PTY operations, native actions, settings operations, or repository edits
were performed. Only this requested /tmp report was appended.

### Summary

The current implementation closes the confirmed write-failure/cache-advance bug
and the connected heartbeat retry bypass while preserving timer recovery and
durable grant semantics. The new PTY integration test provides a direct output
assertion after storage repair, with the runtime and native limitations above.
