> Retained source check of the first uncommitted correction draft on baseline `5760baf`.
> Both reported edges were verified and corrected in `02708b8`; executed results are in
> [final review corrections](final-review-corrections-2026-10-13.md).
> The original report remains at /tmp/explorer-tavs-unknown-cue-correction-check-20261013.md.

# Unknown-cue correction source check

Last Updated: 2026-10-13
Scope: current seven-file uncommitted source/test diff, read-only inspection. No tests, builds,
devices, native apps or peer reports were accessed. Line references reflect the inspected diff.

## Assessment

The correction addresses the main nil-clearing, Boolean invalidation, false-heartbeat and
zero-fanout failures. Unknown cues remain in memory; unknown-only sources cannot authorize a
new focus write; positive invalidation removes captured source identities independently of
outside targets. `didRenew` is correctly placed after actual metadata publication and preserves
the existing writer deadline. Two remaining source-derived edges can delay removal of cues
that are already positively invalidated. They do not permit uncertain paint.

## Verified changes

- `attention-state.swift:37-41`: nil, unverified or unsupported coverage now skips updates rather
  than clearing cues. The occurrence book is retained, so restoring the same delivery does not
  invent a trigger. Fresh native closure, downgrade, verified actor replacement and processing
  keep their established clearing behavior.
- `terminal-visual-state.swift:171-187`: source checking distinguishes `.valid`, `.vanished` and
  `.unavailable`, and may prove producer exit even without a captured destination. Foreground
  changes do not invalidate a previously adopted producer with the same generation/device.
- `focus-controller.swift:253-269`: the worker validates cue sources before the outside-target
  and emphasized-binding guards. All-High/zero-outside runs therefore still resolve positively
  invalidated sources. No outside target means no device fanout and no heartbeat advancement.
- `automaticSourcesCurrent` collects only `.vanished` snapshots for removal. An unknown-only
  collection returns false. A valid source can still authorize focus alongside an unknown cue,
  which is consistent with retaining all High surfaces while any eligible cue remains.
- Final device callbacks revalidate source lifetimes against the passed deadline. Run/version
  checks before and after the validation prevent stale worker completion from authorizing paint.
- `visual-recovery.swift:269-271`: `didRenew(target)` runs only after successful
  `saveEffectUnlocked`. A global rule may then suppress bytes, but actual focus metadata renewal
  is still reported. Predicate rejection reports no renewal.
- `focus-controller.swift:291-301`: heartbeat requires nonempty, fully mapped targets, exact
  successful-renewal target membership and no failed items. The renewal set is protected by the
  controller lock and run/version checks. Late callbacks cannot renew a replacement run.

The new callback creates no second writer budget. It runs inside `prepare`; `ProcessRunner`
checks its original deadline after `prepare` and before bytes (`ProcessRunner.swift:187-191`).
`completeDeviceWrite` still returns failure at the same 100 ms deadline (lines 200-209). If a
metadata save succeeds but later bytes or the caller deadline fail, the returned failed item
prevents controller heartbeat advancement. This conservatively preserves the original deadline.

## Remaining edges to verify and correct

### 1. Unknown producer inspection masks known destination invalidation

`validateAttentionSource:178` returns `.unavailable` immediately when producer lookup is nil and
`processMissing` is false. It therefore never sees independently positive invalidation from:

- An actual changed or known-missing device number.
- A captured target whose continuing-owner generation changed or exited.
- A captured target whose native application generation changed or exited.

Similarly, unknown device metadata at line 181 prevents inspection of positively vanished target
ownership. This is more conservative than required: it retains an old cue despite trustworthy
proof that its destination lifetime ended. Existing `validateTarget` deliberately permits known
owner invalidation to win over unavailable native/device metadata.

Smallest remedy: collect source and captured-target evidence without returning unavailable on
the first unknown domain. Return `.vanished` if any inspected domain positively disproves the
captured source/destination lifetime. Return `.valid` only when every required domain is valid;
otherwise return `.unavailable`. Preserve pre/post deadline checks and do not inspect guessed
native mappings. A missing optional target alone remains unavailable.

Regression: producer lookup nil without ESRCH plus a changed device must return `.vanished`;
repeat with known owner generation reuse and device metadata nil. For all-High rows, unknown
producer metadata plus known destination invalidation should remove only the old cue. Preserve
the producer-nil/device-nil unknown-only cases.

### 2. A later deadline exception drops prior positive invalidations

`automaticSourcesCurrent:342-352` may collect A as `.vanished`, then throw while inspecting B.
Its catch returns before scheduling A's removal. Dictionary iteration order can change whether
that positive evidence is discarded. Repeated unavailable or slow B inspection can retain A
indefinitely even though its exit was successfully proven each pass.

Smallest remedy: when an inspection fails, reject paint but still schedule any exact vanished
snapshots already established before the failure. Do not remove B. This needs no retry logic or
new state. Inspection which itself crosses its deadline still cannot be used as positive proof.

Regression: A is confirmed exited before B's injected metadata lookup exceeds the passed
inspection deadline. Assert A is removed, B remains, no bytes are written and no heartbeat is
claimed. A directly scoped helper test can avoid depending on dictionary order; otherwise inject
an ordering-independent failure that occurs after at least one confirmed result is collected.

## Race and snapshot considerations

I found no new unsafe-paint path from the inspected renewal callback. `values.first` remains safe
under the reducer's established invariant that a surface's current cue set belongs to one actor;
actor replacement clears the old set. Source removal passes the exact captured occurrence set,
so a later delivery is not removed merely because navigation or validation began earlier.

`invalidSourcesVersion` permits only one queued removal batch per run/version. A source that
vanishes later in concurrent fanout can be omitted from that first batch, but the first removal
changes the version and queues the accepted catalogue again while a worker is active. That
provides a subsequent check; it is not presently an independently confirmed permanent-loss bug.
Keep this coalescing behavior when correcting the exception path. Do not replace captured
snapshots with current whole-row cue removal.

## Verification gaps in the current diff

The new tests directly cover completion-gap retention, permission-gap coalescing, unknown source
rejection/restoration, all-High confirmed exit versus unknown retention, producer reuse and known
versus unknown missing-device cases. They are source-visible coverage, not executed evidence in
this report.

The following meaningful cases are still missing from the current test diff:

1. Unknown-source rejection spanning more than six seconds, followed by a fresh active effect ID
   rather than expired-ID reuse. The existing gap test restores within four seconds.
2. Actual `didRenew` callback behavior under an active global mask, including controller
   heartbeat after more than six seconds. Existing global-pause tests verify composition but
   do not exercise the new renewal callback.
3. Rejected predicates and deadline failures must not invoke `didRenew`; successful metadata
   saves must invoke it even when output is masked.
4. Mixed valid / confirmed-invalid / unknown source cues with outside fanout, proving only the
   invalid captured set resolves and the valid cue continues authorizing effects.
5. The two positive-invalidation masking/exception cases above.

The existing final-source race test now encounters the extra preflight inspection. Its injected
third producer lookup may still reach final device validation, but verify the actual trace before
using it as proof of the same historical race location. No runtime execution was performed here.
