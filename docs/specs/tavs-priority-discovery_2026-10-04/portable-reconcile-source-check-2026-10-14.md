# Portable reconcile source checks

Last Updated: 2026-10-14 (Europe/Vienna)
Version: 1.0

Source: `0be5c93`. Source exploration is separate from executed acceptance.

## Parent verification

The native queued-suspension regression at `visual-recovery-tests.swift:933` requires reconcile
to read suspension after device open. Reconcile therefore has no frozen pre-open render revision.
The native branches at `visual-recovery.swift:343-417` distinguish one-time default cleanup from
matching-preview expiry restoration and active ordinary composition. The pending helper at
lines 614-634 removes the derived slot without replay. These source anchors were read directly.

Portable reconcile preserves unavailable outcomes for live native control and unreadable marker
state. Unlike native pre-output cancellation, it cancels exact obsolete snapshots after complete
output to retain retry responsibility. This deliberate difference remains explicit in API docs.
No concrete introduced defect was found by the bounded source check.

Initial eK63u8: 13 missing-method errors among 25 renderer cases. K3iBon: 25/25 passed after
implementation. Added three boundary cases for current global-rule refusal, recovery during
composition and unrelated pending slots. Final o2JN0F: 101/101 portable tests in 2.718 seconds.
oVGcci: 561/561 Swift tests in 10.384 seconds. Changed Python syntax and staged checks passed.
Tests used private roots and owned macOS PTYs, not physical Ghostty UI. Helper verbs, production
routing, Linux scope and native acceptance remain open.

## Source exploration report

# Portable ordinary reconcile contract

Source exploration only. Current portable renderer has render/forced_reset, not
reconcile. No tests, edits to project, UI/provider/device or goal calls performed.

## Entry and transaction

Use `Renderer.reconcile(tty, reset_legacy=True, clear_selective=False)` as a typed
current-state operation. No producer context, new intent, title, saved OSC replay
or synthetic alert is involved. Validate both flags as actual bools. Native CLI
uses cachedTarget for reconcile, not a newly invented target; its PID argument is
validated ancestry but does not supply the cached target's ownership authority
(managed-output-entry.swift:68,72,127-129).

Reuse cached_target for existing current owner/device and unambiguous native alias
selection. Use write_managed's original 100 ms deadline and per-TTY output lock.
Select the target before open; re-read effects, current policy and marker AFTER
open, under that lock. Native reconcile has no frozen pre-open render revision:
testReconciliationQueuedBeforeSuspensionReadsTheMarkerAfterDeviceOpen requires
the new suspension state to govern. Final device/target/policy checks still matter.

When current policy has no global rule, invalidate exactly
`runtime/pending/<tty with / replaced by _>.osc` before background selection,
even when the eventual result is no paint. Missing directory/file is a no-op;
directory must be a real directory and leaf a regular file. Links/storage/timeout
errors fail. Never read/replay its body. Native invalidation is AFTER open under
writer lock (visual-recovery.swift:343-345,614-634); active global policy takes an
earlier branch and does not invalidate there. Retain typed intents/observations,
adoptions, unrelated pending files, titles and theme definitions.

## Exact native no-rule behavior

`effects` means all three slots across equivalent current aliases, not arbitrary
other-owner records. `clear_selective=True` cancels ALL active effects first,
including global and preview/focus; old snapshots still drive the suspended
branch below. Native cancellation precedes physical bytes. The portable render
after-success cancellation is an intentional difference, not an exact substitute
for this explicit native clear operation.

| Current state | Native reconcile action |
| --- | --- |
| Active marker | Legacy prefix iff any active global, reset_legacy=True, OR any global record even canceled. Then compose current selective lease or latest ordinary intent/default reset. |
| Suspended/unavailable marker, no active records | Return false, no bytes, regardless of reset_legacy. Pending invalidation still occurs. |
| Disabled marker, active records without eligible suspended preview | Cancel active records. Emit full reset iff obsolete active global exists; otherwise background default reset. Do NOT replay retained ordinary color. |
| Suspended marker, active preview with nonnil matching revision | Preserve that preview for subsequent lease classification; cancel other active records. Prefix only for obsolete active global, ignoring reset_legacy. |
| Matching suspended preview expired/dead controller | Subsequent lease classification cancels it and restores latest ordinary intent/default reset. Following reconcile returns false. |
| clear_selective=True with matching suspended preview | Early cancellation plus refreshed effect read removes preview; restore latest ordinary intent/default reset. |

Unavailable marker never qualifies a preview even if its inode matches. Native
can perform default cleanup on that path; current portable Policy throws on
unavailable state. For the approved ordinary backend, preserve explicit unavailable
failure instead of claiming the native emergency/unavailable cleanup capability.

Selective priority is preview, then focus, then selectiveBackground. Live means
active/current controller, age <2 s preview or <=6 s other, and matching revision
when present. Chosen equivalent leases must agree in effectID/controller/revision/
focusColors and background except focus, else staleEffect. Native focus recomputes
dimming from current ordinary color and saved focusColors. Native preserves live
nonselected underlying leases while canceling obsolete records. Global records
are residual cleanup evidence, never selective control; current global policy is
recomputed separately and wins over all leases.

## Portable reuse and specific gaps

- Reuse cached_target/_current, status(fd), bounded records.read/write,
  ordinary_background_unlocked, output_lock and write_managed. Reuse held-parent
  `parent_directory(runtime, pending_path, deadline)` without create for a narrow
  no-follow regular-file unlink. No raw payload parser is needed.
- ordinary_ownership works for no-rule, ordinary admission after explicit clears,
  but currently refuses every live selective record. With clear_selective=False,
  report unavailable/EBUSY for surviving live control, preserving records and no
  paint; do not claim native composition or refresh controller/heartbeat. With
  explicit clear=True, a bounded exact-snapshot cancellation path is needed;
  do not call the unchanged admission guard first and render the flag ineffective.
- Policy.restricted only proves a rule exists; it cannot generate restriction
  colors/foreground/image or native controller records. Current rule means
  unavailable/no ordinary paint. Reject before canceling live controlled records
  on that portable failure path; this is safer than native's clear-before-rule
  partial metadata mutation and must be stated as unavailable behavior.
- Active-marker canceled-global evidence and reset_legacy=True require prefix
  even when ordinary_ownership returns no obsolete active global. Current renderer
  derives prefix only from obsolete active globals, so it cannot be reused as-is.
- Cancellation/no-paint outcomes need explicit handling: writer skips after_write
  when prepare returns None. Pending invalidation belongs in prepare; explicit
  metadata cancellation must not be silently lost in that early return.

Normal bytes are optional OSC104 BEL + OSC110 BEL, then one OSC11 color ST or
OSC111 ST. Disabled full reset is exactly OSC104 BEL + OSC110 BEL + OSC111 BEL.
No OSC0/title/image/standalone audible bell is emitted. BEL terminators remain.

Useful existing regression models: visual-recovery-tests.swift:833-973 (preview,
suspension, unavailable marker, residual global and one-shot cleanup), 600
(retained failed-open intent), 1040-1063 (pending body/title/BEL sentinel), 1198
(expired selective); Broadcast/default replay uses clear=False, startup/resume
uses clear=True. These are source references, not newly executed acceptance.

## Implemented source check

# Portable reconcile source check

Read-only review of the current portable_renderer.py, portable_ownership.py and
test_portable_renderer.py diff. Related writer/policy helpers were read to verify
the boundaries. No tests, provider/UI/device operations, project edits or goals.

## Conclusion

No concrete introduced defect found within the approved ordinary reconcile scope.
The unavailable outcomes and post-complete-output cancellation are deliberate
differences from native managed composition/pre-output cancellation.

## Verified branches

- portable_renderer.py:40-53 chooses an existing cached target before open, then
  captures current suspension and checks target/descriptor after open under the
  writer lock. There is no stale pre-open render revision for reconcile.
- Lines 49-53 refuse current global policy before pending invalidation or effect
  cancellation, and ownership repeats the policy check. Live selective control
  with clear_selective=False is explicitly EBUSY, preserving its records and
  avoiding a false controlled-composition claim.
- Lines 54-68 distinguish matching-revision active preview evidence from ordinary
  suspended residue. No active residue gives None/no paint. Residual global gives
  the exact full BEL reset; other unmatched residue gives background-only default
  reset without retained theme replay. Expired matching preview reaches latest
  ordinary intent/default reset, then cancellation makes the next call no paint.
- portable_ownership.py:283-297 makes explicit clear admit all active effect
  snapshots without controller lookup, while still requiring current target,
  policy and revision. Suspended preview without revision is obsolete. Matching
  live preview remains blocked unless explicitly cleared; expired/dead preview
  is eligible cleanup. Unknown fresh controller remains unavailable.
- Active-marker prefix selection (renderer:63-64) honors reset_legacy and canceled
  global records, not just obsolete active globals. Suspended prefix ignores the
  flag and depends on actual obsolete active global residue.
- Pending invalidation (79-94) uses held parent descriptors, rejects links and
  nonregular leaf, tolerates absence, never reads the body, and checks the original
  deadline. It occurs before a suspended no-paint result and before live selective
  EBUSY, matching the intended pending cleanup boundary.
- Lines 69-77 and 96-107 preserve final target/revision checks and full snapshot
  equality for cancellation. The existing writer runs completion only after all
  bytes are accepted, under the same lock and original 100 ms budget. Failed or
  partial output keeps active cleanup records. No-paint skips completion only
  when obsolete is empty, so no cancellation is lost through that branch.
- Bytes contain only the specified legacy prefix and current/default background.
  There is no title, image, pending body replay or standalone audible alert.

The inspected additions cover active restoration, canceled global prefix,
suspended repeat-no-paint, one-shot defaults, revisionless/live/expired previews,
explicit clear, after-open suspension, linked pending refusal and failed-write
retry. These tests were not executed here.

## Limits retained

Unavailable marker throws through existing Policy capture rather than claiming
native unavailable-marker emergency cleanup. Live native rule/lease composition
is refused. Complete output followed by metadata/deadline failure remains a
reported partial transaction; successful pixels are not successful cancellation.
No new runtime acceptance, capability, routing or full H1 claim is made.
