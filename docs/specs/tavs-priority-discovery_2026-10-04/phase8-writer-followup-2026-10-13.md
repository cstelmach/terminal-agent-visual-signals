# TAVS Phase 8 writer follow-up

Last Updated: 2026-10-13
Version: 1
Baseline: `0b53c50` plus current dirty Phase 8 changes

## Conclusion

Fresh source does not reveal an additional definite writer or decoder defect in the reviewed
normal paths. The earlier preview revision-lifetime concern has been addressed during this
follow-up. Manual ownership is not implemented yet, so its run must adopt the same pin-retention
contract and must explicitly handle an expired ID. These are integration requirements, not
current shipped Manual-controller bugs.

This review read source and tests only. No test, build, native request, device write, UI action
or real-home inspection ran. The parent owns verification. Source changed during inspection;
the conclusions below incorporate the fresh preview clear and retention changes.

Paths are relative to:
`/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/`.

## Current lifecycle

### Start and renewal

`Sources/TAVSApp/visual-recovery.swift:235`, the `.focus` branch, checks `isCurrent`, controller,
pinned marker revision and active suspension state before policy lookup and checks again after
lookup. It obtains current ordinary intent and saves normalized colors and serialized revision
identity in a `.focus` effect. The new `focus.json` slot is independent of `preview.json` and the
legacy global/static `effect.json` slot.

`terminal-visual-state.swift:207`, `saveEffectUnlocked`, permits a same-ID active update only when
the existing focus lease remains active, its controller/colors/revision agree and heartbeat does
not move backward. Canceled IDs cannot reactivate. `refreshEffectUnlocked` rejects focus so the
old blind-heartbeat API cannot bypass these checks.

The six-second lease remains process-generation-bound. Ordinary writes change its cached result
but preserve heartbeat. After expiry, renewing that same ID throws rather than reviving it.
The future Manual controller must choose explicit Off or a fresh current run after an expired
lease, including after a delayed timer or sleep. It cannot reuse an expired ID indefinitely.

### Ordinary intent and alias agreement

`VisualRecovery.performWrite` at `visual-recovery.swift:124` preserves ordinary publication
before open and binding inside the writer lock. Common composition at lines 291-329 filters
leases by process lifetime, lease age and marker identity, then applies preview, focus and legacy
selective precedence after current global policy.

Focus composition calls `TerminalRenderer.focusBackground` using the latest
`ordinaryBackgroundUnlocked` on each managed paint where focus is visible. Style-only renders
also compose active focus. Registration and synthetic validation retain their nonpainting
returns. Under preview or global pause, ordinary intent continues to be retained and is read
fresh when focus becomes visible again.

Aliases agree on run ID, controller, revision and normalized colors. They do not have to agree
on their last rendered background. Recomputed background updates are written to each winning
focus alias without extending its heartbeat. Conflicting active recipes fail before output.
Physical target validation and one-write-per-physical-target fanout remain unchanged.

Explicit focus requests replace prior IDs across aliases before saving their current record.
Ordinary composition is the path that rejects competing current alias authority. Requests
masked by a global rule return before ordinary composition, so callers must not infer that every
cached alias recipe was checked merely from a masked request's result.

### Pause and preview

A focus request under a global rule saves its renewable recipe and returns no paint. Global
paint owns the legacy slot and does not replace `focus.json`. On release, the existing
`Broadcaster.broadcastPausedClear` routes
`.reconcile(resetLegacy: true, clearSelective: false)`, which resets legacy foreground/palette
state and derives current focus output. This is not achieved by `.currentRestriction` when
there is no rule, since that operation deliberately returns without paint.

Preview overrides focus while its two-second lease is active. Clear or expiry exposes focus
derived from current ordinary intent. A focus request during preview can return a successful
paint of the preview layer; during global pause it returns no paint even though focus metadata
was saved. The future UI must distinguish desired Manual state from visible dimming and generic
writer `restored`/`unaffected` statuses.

### Clear before device open

`visual-recovery.swift:160` now handles both `.clearFocus` and `.clearPreview` through the existing
`beforeOpen` metadata hook. It takes the existing per-TTY lock, validates the target, cancels
matching kind/ID/controller/revision records across aliases and releases that lock before
opening the device. Legacy previews without a recorded revision receive the narrow existing
compatibility treatment. This is sequential locking, not a nested same-lock acquisition.

A failed open can therefore leave paint visible but cannot leave a successfully canceled
metadata lease available to the next ordinary writer. The failure is returned honestly.
After open, a changed marker suppresses repaint. A matching canceled record may still authorize
current-background recomposition while a different, newer ID cannot be cleared by the old
request. An active global rule suppresses the focus-clear repaint rather than replacing its
visual with ordinary background.

## Recovery and pin ownership

`VisualRecovery.recover` at line 347 writes suspension/resume first, then reconciles devices.
Persisted focus and new preview records carry the old marker device/inode. Even if a device
cannot be cleared, later ordinary composition rejects a mismatching marker identity. The new
failed-recovery/resume regression exercises this metadata boundary.

The device/inode identity is sound across repeated marker replacement only while the old inode
is pinned, or after its lease cannot be used. `captureRevision` holds that file descriptor for
this purpose. Initially, the preview owner's `cancelForRecovery` dropped all run references,
which did not meet that lifetime requirement after partial cancellation. Fresh
`focus-controller.swift:104` now moves the old Run to `pendingClear` and preserves existing
pending runs. That concern is resolved for the reviewed preview owner.

`clearPreview` at line 80 retains a run through queued cleanup and keeps failures pending.
The new `testRecoveryRetainsPreviewRevisionUntilMetadataCleanupAfterReplacement` at
`Tests/TAVSAppTests/focus-controller-tests.swift:148` checks repeated same-state replacements,
then metadata cancellation without repaint. The parent reports that test passed; this reviewer
did not execute it.

The future Manual run must likewise retain its pinned revision through current ownership and
failed/pending metadata cancellation. Serialized device/inode alone does not pin an inode.
Reuse the existing run/pending-cleanup ownership rather than add a token file or service.

## Decoder and validation check

`TerminalRenderer.Colors` strictly decodes only background/foreground and normalizes both.
`TerminalEffectRecord` allows the new keys but enforces that focus requires colors and revision;
nonfocus kinds cannot carry focus colors. Revision is permitted only for focus or preview.
Invalid identity values such as nonzero device with zero inode are rejected by the effect store
and decoded identity. Independent slot readers reject a focus record in a different slot.

Legacy global/static records and legacy two-second previews remain decodable. They are not
silently converted into dynamic focus. Cached recovery enumerates `focus.json` and validates
its expected target path. No concrete decoder/slot disagreement was found.

## Bounded remaining verification

The new source tests cover latest intent without renewal, normal renewal/exact clear, pause and
preview release, failed recovery/resume, metadata cancellation before device failure, masked
focus, changed marker/current run, old-ID clear, style-only rendering and alias recipe agreement.
Those are source tests read here, not a claim of independently verified passing behavior.

Before the future Manual controller is accepted, retain these focused cases:

- A Manual run releases current ownership during failed recovery/resume but keeps its pin until
  metadata cleanup or lease expiry, as the preview owner now does.
- Renewal during a global pause lasts beyond six seconds, then pause release derives the latest
  ordinary intent. A paused run whose renewal actually expired follows an explicit fresh-ID/Off
  path rather than retrying a tombstoned ID.
- Clear across native/plain aliases still tombstones every matching record when device open
  fails, and a newer run between metadata clear and open is never erased or repainted over.
- Decoder tests reject unknown revision keys and misplaced focus records, and ordinary helpers
  continue to reject mismatched revisions after partial cancellation and repeated same-boolean
  marker replacement.

No new process machinery is recommended. Dedicated native acceptance remains outside this
read-only follow-up.
