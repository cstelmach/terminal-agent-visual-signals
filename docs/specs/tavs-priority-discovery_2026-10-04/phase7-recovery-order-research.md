# Rejecting previews queued before independent recovery

Last Updated: 2026-10-12
Version: 1.0

## Recommendation

Use the existing suspension marker's atomic file replacement as the recovery revision.
Capture its file identity when the explicit selection event occurs. Compare that identity
inside the existing per-TTY managed writer before saving preview ownership. A new explicit
selection after recovery captures the replacement marker and can preview normally.

No state schema, generation counter, extra marker, hash, watcher, daemon, or `ProcessRunner`
protocol change is necessary. Put the small file-identity API in the existing
`visual-restrictions-state.swift` module.

## Fresh source evidence

- `VisualRestrictionsStateStore.write`, `visual-restrictions-state.swift:63-74`, always uses
  `Data.write(options: .atomic)`. It does not skip same-value writes.
- `_tavs_visual_restrictions_write`, `src/core/visual-restrictions-state.sh:39-58`, creates
  a same-directory temporary file and renames it over the marker. It likewise does not skip
  same-value writes.
- `src/cli/cmd-recover.sh:31-34` replaces the marker before helper resolution; `:53-54`
  invokes the separate recovery process. The Swift helper replaces it again via
  `VisualRecovery.recover`, `visual-recovery.swift:205-215`.
- `VisualRecovery.performWrite`, `visual-recovery.swift:112-147`, runs target verification,
  target caching, effect discovery, and current policy inside the managed callback.
- `ProcessRunner.swift:129-176` opens the device before acquiring the existing per-TTY
  lock and holds that lock across preparation and output.
- Recovery calls `cachedRecords()` only after persisting its marker, then resets the
  discovered targets (`visual-recovery.swift:205-226`).

The current in-progress preview design uses a separate `preview.json` record and fixed
two-second creation time. See `terminal-visual-state.swift:193-249,467-468`:
`matchingEffectUnlocked` rejects canceled/mismatched IDs, `refreshEffectUnlocked` cannot
renew a preview, and a same-ID save cannot alter its preview heartbeat. These protections
cover existing records but do not reject an initial queued start whose record does not
exist yet. The marker identity covers that missing case.

## Exact smallest APIs

Recommended signatures:

```swift
final class VisualRestrictionsRevision {
    // File identity and a pinned read-only descriptor, or an explicit missing-marker case.
}

func captureRevision() throws -> VisualRestrictionsRevision
func matches(_ revision: VisualRestrictionsRevision, deadline: UInt64) throws -> Bool
```

Capture once at the explicit selection boundary, before enqueueing configuration lookup,
native lookup or device work. All rows in that preview request share the captured revision.
Do not capture it inside the queued worker, since that would adopt a recovery that occurred
after selection and incorrectly authorize the old request.

For a present marker, reuse the existing reader's safeguards: regular bounded file,
`O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC`, and `lstat`/`fstat` identity agreement.
Retain the read-only descriptor until the request and its pending callbacks are released.
Compare `(st_dev, st_ino)` with the marker currently at the path. Pinning the old descriptor
prevents inode reuse while that request is pending. This needs one short-lived object with
`deinit { close(fd) }`, not a durable identity system.

For an absent marker, use an explicit missing revision only when the existing `missingStatus`
classification is valid. It matches only continued valid absence. Recovery creates the
marker, so the old missing revision stops matching. Unavailable, malformed, symlink,
nonregular or inaccessible marker state must not produce an authorized revision.

`matches` should honor the original managed deadline before and after metadata reads.
Replacement is a normal false result; genuine metadata/storage failure should remain an
explicit failure. No new deadline is acquired.

The matched revision does not replace the live in-memory preview ID/deadline check, target
lifetime checks, or current restriction policy. Those address different races.

## Required ordering and why it works

Inside the same managed callback:

```swift
try state.cacheTargetUnlocked(target, deadline: deadline)
guard requestIsCurrentAndNotExpired() else { return nil }
guard try restrictions.matches(requestRevision, deadline: deadline) else { return nil }
// Read current policy and latest ordinary intent, then save ownership before bytes.
```

Target caching must finish before the identity comparison. There are two relevant orders:

1. Recovery replaces the marker before the comparison. The old preview revision differs,
   so no preview ownership or output occurs, regardless of whether the final Boolean is
   suspended or active.
2. The comparison accepts the marker before recovery replaces it. The selected target is
   already cached. Recovery scans after replacement and can discover it. The preview holds
   the existing TTY lock through its save and output, so recovery resets that target after
   the preview write. Final paint belongs to recovery.

Checking marker identity before target caching would leave a gap: recovery could scan before
the newly accepted target becomes discoverable, and then the preview could paint a target
the reset never visits. The existing `performWrite` already caches at `:129`; retain that
ordering when adding initial preview support.

Repeat recover while already suspended changes identity. Recover followed by resume changes
identity even when the final status equals the captured active status. Repeating resume
while already active also replaces identity. A fresh explicit preview after the completed
operation captures its current identity and remains allowed, subject to any active global rule.

A selection during the CLI/helper gap may be rejected by the helper's second marker
replacement. That is appropriate while recovery is still running; a new explicit selection
after completion succeeds.

## Regression triggers

Use injected roots, mocked managed callbacks, and the existing isolated state store. No
physical device or native action is necessary for these ordering tests.

1. Capture a request with no marker and no preview record, pause its managed callback,
   independently recover, then release it. Assert no preview record or preview output.
2. Start suspended, capture a request, run independent recover again, then release. Assert
   rejection although both status reads are suspended.
3. Start active, capture a request, run recover and recover-resume, then release. Assert
   rejection although final status is active. Also test repeated resume from active.
4. Capture a new request after each completed operation. Assert normal preview creation
   when no global rule blocks it, including while suspended.
5. Capture a request, block its device open, complete recovery, then release open within
   the original test deadline. Assert the callback rejects the stale revision before save.
6. Pause an accepted callback after target caching and successful identity comparison,
   replace the marker and begin recovery's cached-target scan, then let preview output
   finish. Assert recovery discovers the target and final ordered bytes are its reset.
7. An old callback released after a newer explicit request must neither save its old
   record nor clear the new request's ID.
8. Symlink, nonregular, corrupt, unavailable and changed marker inputs fail explicitly;
   revision descriptors are released when canceled/completed requests leave scope.

Do not substitute status equality, marker contents equality, wall-clock timestamps, or a
GUI watcher for the file-identity comparison. They either miss same-value replacement or
depend on delayed event delivery. Exact-ID tombstones remain useful for already-created
preview records and are insufficient for an initial queued record.

## Isolated hypothesis check

Ran the actual shell writer against `/tmp/tavs-preview-order-h_m2hx0e/visual-restrictions.state`.
No real-home or installed-app path was used. Results:

- Replacing suspended with suspended changed `(st_dev, st_ino)`.
- Active to suspended to active changed identity although final contents matched active.
- An opened original descriptor retained its original identity across replacements.
- Final marker contents were the expected schema 1 active state.

The scratch directory remains available. No source edits, builds, device output, UI/native
commands, or real-home actions were performed. The Swift atomic writer was inspected, not
executed. The conclusion relies on recovery using the existing atomic writers; arbitrary
external in-place edits are outside that writer contract.
