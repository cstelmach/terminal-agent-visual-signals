# TAVS persistent focus failure and cleanup bounds

Last Updated: 2026-10-13
Version: 1
Requested baseline: `71e0f60`
Inspected HEAD: `12bacee`, its documentation-only child

## Finding

The persistent-failure lead is confirmed from source, without consulting peer reports.
Failed outside writes prevent the aggregate heartbeat from advancing. A fresh Run is created
after six seconds; failed cleanup requeues every retired Run, with no retirement bound.
Cleanup attempts therefore grow with the history of runs, and the shared serial clear queue can
delay an unrelated healthy preview clear.

The inspected focus controller/tests have no code difference from `71e0f60`. No source edits,
tests, builds, native calls, devices, hooks, fingerprints or real-home operations were performed.
Only this requested report was created. The parent owns implementation and verification.

All paths below are relative to:
`/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/`.

## Exact source path

`Sources/TAVSApp/focus-controller.swift`:

- line 23: one serial `clearQueue` serves preview and focus cleanup;
- line 28: `pendingFocusClear` retains Run objects;
- lines 203-205: a heartbeat older than six seconds creates another Run and appends the old one;
- line 273: the current Run remembers every captured outside target before writes are attempted;
- lines 293-295: lastHeartbeat advances only if every outside surface maps and no result fails;
- lines 304-305: each completed current update drains all pending runs into cleanup;
- lines 340-354: cleanup creates one queue job per Run and requeues the whole Run if any target
  reports failed, including when other targets are already cleared or superseded;
- lines 376-378: a new Run initializes lastHeartbeat to its start time, so continuous failure
  still causes the next rollover eight seconds later under two-second ticks.

`clearPreview` at lines 94-115 queues its exact-ID operations on that same clearQueue. There is
no priority/preemption between queued focus retirement and preview clearing.

## Finite sequence and counts

Take selected working shell A, healthy outside H and outside F. Initial R0 paints successfully
at t=0. At t=2 and thereafter, F's focus writes and focus cleanup keep failing, including a
failure before the pre-open metadata callback. H remains mapped and healthy. Each update and
cleanup wave completes before the next two-second tick in this finite example.

H can renew its current lease, but F's failure prevents the Run-wide lastHeartbeat from
advancing. At the strict `> 6` boundary:

| Tick | Current Run | Retired Runs retried in that wave | Retained after failure |
|---|---|---|---|
| 0, 2, 4, 6 | R0 | none | none |
| 8 | R1 | R0 | R0 |
| 10, 12, 14 | R1 | R0 each time | R0 |
| 16 | R2 | R0, R1 | R0, R1 |
| 18, 20, 22 | R2 | R0, R1 each time | R0, R1 |
| 24 | R3 | R0, R1, R2 | R0, R1, R2 |

By t=24 there are four Run objects held across current/pending ownership and 15 retired-run
cleanup jobs have been attempted: `1+1+1+1+2+2+2+2+3 = 15`. Each Run still carries H and F even
though H's newer successful lease has superseded the retired IDs on H.

For the same fully drained tick pattern through t=8n, there are n retained retired Runs and
`2n²-n` cumulative retired-run cleanup jobs. This formula describes that explicit sequence,
not a claim that arbitrarily large real-time waves can always drain within two seconds.
When they cannot drain, work remains in flight/queued; there is still no source retirement bound.

These rollovers reuse `old.revision`, so they share one pinned revision object. The sequence
grows Run objects, target arrays, retry work and color caches, not one new descriptor per rollover.
Separate explicit starts/recovery transitions can capture other revisions, but are not needed
for this failure demonstration.

## Preview delay

`VisualRecovery.apply` fans targets out independently, but clearQueue executes whole Run batches
serially. One blocked F can occupy roughly the existing 100 ms caller budget in each batch.
Three focus jobs ahead of a healthy A preview clear can therefore add roughly 300 ms before A's
clear starts; ten can add roughly one second. A uses a different TTY, so this queue delay is
independent of legitimate per-TTY serialization.

The API sets isPreviewActive false immediately, while the physical preview can remain visible
until its queued cleanup reaches the device. This can violate the intended immediately
cancellable preview and two-second timing even though each individual device call is bounded.

## Why blindly coalescing by target is unsafe

`visual-recovery.swift:181` cancels clear metadata before opening, under the existing per-TTY
lock. Matching includes effect kind, exact Run ID, controller generation and revision identity.
The later callback suppresses repaint after marker replacement and cannot clear a newer ID.

A failure before that metadata callback can leave an older Run's actual record authoritative.
A newer attempted Run may never have created a record on F. Keeping only the newest attempted
ID per target would then lose the ID needed to cancel the actual older record. Discarding its
revision pin is also unsafe before cancellation/supersession is known.

A failure after metadata cancellation is different: ownership can already be inactive while
physical restoration remains pending. Do not treat every `.failed` item as proof that metadata
remains active, or treat metadata cancellation as proof that physical restoration succeeded.
Current VisualRecoveryItem exposes only the aggregate outcome, so the controller cannot infer
that distinction safely from failure alone.

Changing cleanup to a blind current-target clear would also risk canceling a newer active focus
run. Dropping old IDs solely because of age or a newer logical Run is not sufficient proof of
supersession. The exact-ID/revision protocol must remain intact.

## Smallest universally safe bound

The conservative small fix is to stop creating another ownership generation while the previous
exact-ID retirement is unresolved, and coalesce its retry work to one outstanding cleanup wave.
Keep the logical captured working set or Automatic armed/cue state; report focus unavailable
while cleanup blocks replacement. After cleanup succeeds, create the fresh ID required for an
expired lease and recompose current intent. This bounds ownership history without discarding
unknown older authority or adding a service.

Use a separate serial focus-clear queue from preview clear. The existing shared per-TTY writer
lock still orders conflicting device writes and each preserves its original deadline. Separate
queues remove historical focus retry work ahead of an unrelated healthy preview.

This conservative choice can temporarily stop fresh dimming on healthy targets while one old
retirement remains unresolved. That is its concrete product tradeoff, rather than an invisible
change to cleanup ownership. It should preserve desired mode/selection and show the limitation.

If continued partial healthy focus is required, the connected alternative needs a narrow
existing-lock proof of each target's old ownership cancellation, absence or supersession, then
prunes only proven obsolete exact-ID work. Keep the original owner/revision for unknown targets
and physical restoration that remains necessary. Merely retaining an unbounded set of old IDs
inside a per-target dictionary does not solve the bound. Unknown metadata failure still requires
controlling the issue of further ownership generations or an explicit write-stage result.

No new cleanup registry, scheduler, watcher or state control plane is recommended.

## Regression strategy using existing seams

Extend FocusControllerTests and the existing MockProcessRunner handler. Do not use real process
signals or an actual wedged terminal. The fixture already supplies private roots, virtual clock,
owned PTYs, injected identities and a queued controller.

1. Start R0 successfully on H/F, then make F fail before its beforeOpen callback. At two-second
   virtual-clock steps through 24 seconds, count clear calls using the existing
   managedBeforeOpenHandler: focus starts have no beforeOpen publication; exact clears do.
   Wait for main-thread requeue completion between waves. The current code produces 15 retired
   F cleanup attempts and continues growing. The corrected path must have a bounded number of
   owner generations and at most one queued/in-flight retry wave.
2. Make one focus cleanup wave wait behind an injected semaphore; enqueue and clear a healthy
   preview on working A. A's preview cleanup must reach its handler without waiting for all
   focus retirement jobs. Assert actual clear completion, not only isPreviewActive false.
3. Fail cleanup before metadata cancellation and verify the real older ID and pinned revision
   remain retryable despite a newer failed attempt. Recover the seam, then assert exact metadata
   tombstoning and latest ordinary-background restoration.
4. Fail after successful pre-open cancellation and verify physical retry is retained as needed,
   while no canceled ID can rearm. Keep the existing tombstone/save guards.
5. Publish a newer successful exact ID and assert an older cleanup cannot cancel it. Include
   plain/native aliases, marker replacement and recovery/resume pin retention.
6. Keep existing expiry-new-ID and unavailable mapping tests, including
   `testCatalogueFailureRetainsLogicalSetAndExpiredOwnershipGetsANewID` and
   `testUnmappedOutsideSurfaceCannotKeepAnExpiredPaintIDFresh`, so bounding retirement does not
   silently revive expired IDs or lose the captured logical working set.

Existing controller tests cover a single expiry and cleanup after recovery, but do not exercise
this repeated persistent write-plus-cleanup failure sequence. The relevant writer regressions
already prove exact clear and cancellation-before-device-failure behavior and should be reused.
