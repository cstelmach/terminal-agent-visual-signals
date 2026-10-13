# TAVS focused cancellation evidence
Last Updated: 2026-10-13
Version: 1
Source: `4d1d194` plus implemented uncommitted callback diff

## Verdict and scope
The narrow implementation matches the proposed contract. didCancel is point-in-time
exact-ownership evidence, not physical restoration or resolution of retained-focus bounds.
The parent reports 526/526 Swift tests passed. This reviewer only read source/tests;
no implementation, tests, builds, devices, native calls or peer-report reads ran here.

## Source contract verified
- [visual-recovery.swift:30](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/visual-recovery.swift:30)
  adds the default noop callback without changing existing callers' behavior.
- [visual-recovery.swift:183](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/visual-recovery.swift:183)
  validates the target, enumerates all validated physical aliases and reads their effects under
  the existing pre-open TTY lock. Unknown/corrupt alias metadata throws before acknowledgement.
  Matching remains kind + exact ID + controller generation + requested revision identity.
- cancelEffects completes every matching active cancellation before the callback. The explicit
  original-deadline guard precedes didCancel(target); no extra I/O budget or admission is added.
  Already canceled/absent/superseded old ownership also qualifies after the full validated read.
- [visual-recovery.swift:284](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/visual-recovery.swift:284)
  retains old repaint guards: current matching record and marker revision are required;
  a current global rule still suppresses clear repaint. Output/result behavior is unchanged.

## Important edge cases
1. Partial alias cancellation is not whole-target resolution. If one write persists and another
   throws, cancelEffects does not return and didCancel cannot fire. Retry must retain old
   identity/revision and finish the remaining alias, ignoring already inactive copies safely.
2. Store write can rename then throw its post-rename deadline check. A throw before the callback
   gives no acknowledgement even if cancellation actually persisted. This conservative absence
   requires another locked check; it must not be interpreted as proof of active or absent state.
3. If the callback already fired and a later withLock deadline check or device operation fails,
   the acknowledgement remains valid metadata evidence. Do not reset it merely because the
   aggregate operation reports failed. Physical repaint can remain outstanding independently.
4. Marker replacement must not suppress old metadata cancellation. The old record revision is
   matched, then cancellation is acknowledged; the later marker check still blocks stale paint.
   This allows safe cancellation after recovery without claiming its failed repaint succeeded.
5. A newer active ID is not canceled. Acknowledging the old ID's absence/supersession says nothing
   about newer ownership or physical paint. The strengthened old-ID test verifies this boundary.
6. The callback does not prohibit future publication of an absent ID. Retire/invalidate the old
   lease's isCurrent predicate before requesting clear. Otherwise a queued old focus request
   with isCurrent still true can save after this stage, especially when no tombstone existed.
7. Callbacks execute on writer/fanout workers under the lock. Keep them short, thread-safe and
   nonblocking; do not call coverage, another writer or wait for the main queue from didCancel.

## Test evidence and remaining targeted coverage
Six new and two strengthened tests read here cover pre-stage failure, global no-paint,
changed-marker no-paint, corrupt-alias uncertainty, an already expired deadline, one physical
acknowledgement across plain/native aliases, acknowledgement before device failure and an old
ID superseded by a newer one. These test outcomes were reported by the parent, not rerun here.

Remaining focused regressions for retirement integration are:
- force one alias cancellation to persist before the next alias fails, then retry and verify
  zero first-stage acknowledgement and one acknowledgement after full resolution;
- distinguish an actual post-rename deadline error from an expired-before-write test;
- keep metadata-resolved and physical-pending state after failed/no-paint output;
- cancel an absent old candidate after making its queued predicate false, then prove releasing
  the queued request cannot republish or cancel the newer lease.
Do not assume Set alias iteration order when injecting the partial failure. Use owned fixtures
and a deterministic failure seam. Callback count alone does not establish repaint completion.

No production contract objection was found in this implemented slice. Controller per-target
retirement, healthy continuous renewal and retained-obligation bounds remain separate open work.
