# Fresh native validation before surface effects

Last Updated: 2026-10-14
Scope: read-only source recon. No builds, tests, apps, native requests or runtime changes.

## Confirmed gap

SPEC:89-96 requires serialized bounded native requests and immediate ID/TTY revalidation before
effects. `FocusController.preview` captures caller rows after colors at lines 66-67.
`updateManual` captures source/outside rows at lines 323-332 before colors. Both targeted
`VisualRecovery.apply` overloads go directly to fanout. `validateTarget` checks application
generation, owner generation and device; its optional fresh-native argument is not supplied in
these paths. A still-live PTY owner therefore cannot prove the old native surface owns that TTY.

## Smallest complete injection

Require a `nativeSnapshot: () throws -> [GhosttySurface]` initializer closure in FocusController.
Pass the existing local `snapshot` closure in `SessionsModel.create` at TAVSApp:201-215. It
already uses the same scoped GhosttyCatalog or isolated fixture snapshot as VisualRecovery.
Do not default to caller rows or an empty result: either would conceal a missing integration.

Use one snapshot per effect preparation after colors, before target capture and fanout. Recheck
the current run/version immediately before and after it. For each submitted surface, accept
only one fresh row with the same full native ID (including application generation), same
non-nil TTY, no mapping issue, and unique TTY among the complete fresh catalogue. Use that fresh
row for foreground PID/owner capture. Do not compare title, directory, window, tab, ordering or
selected state: a moved surviving pane remains the same target. Reject duplicate IDs and TTYs
even in injected fixtures instead of relying solely on GhosttyCatalog.decode.

Retain the original submitted catalogue as the requested set for this update. Validate its
members against the fresh catalogue; do not silently adopt newly enumerated IDs or mutate the
captured working set on the worker. New surfaces enter the next ordinary Sessions refresh.
An exact ID with a different TTY is unavailable for this request; the next accepted catalogue
can explicitly capture its current lifetime. A missing selected pane must never cause the
controller to dim every remaining pane.

Manual/Automatic: move outside target capture, attempted/wanted bookkeeping and lease
retirement after fresh validation. At least one fresh verified emphasized binding is required.
Automatic cue-source targets must also come from fresh validated rows, then keep the existing
per-writer `automaticSourcesCurrent` checks. Preserve the existing no-outside branch's producer
validation and cue resolution; it needs no color/native work because it paints no effect.

## Bounds and cancellation

GhosttyCatalog.snapshot:74-82 enqueues on the shared serial native queue but waits indefinitely.
Each osascript request is bounded to two seconds at request:137, but queue residence is not.
Before using snapshot as an effect prerequisite, give its caller a two-second bound including
queue wait, skip an expired queued snapshot, and pass remaining time into request's bounded
subprocess. Use the existing process timeout error. Do not dispatch another queue inside the
100 ms device preparation closure or extend that deadline. Native work must finish first.

Keep preview timer/start time after both colors and fresh validation. For focus, keep heartbeat
after preparation and all existing run/version, catalogue-age, revision and source checks.
Cancelled color or native preparation must not publish targets, leases or timers. Native failure
must stop new/renewed effects while retaining logical set/cues and existing retryable ownership;
do not turn an enumeration error into confirmed closure or discard old repaint obligations.

## Callers and test risks

Four FocusController constructions exist: production TAVSApp:215, common FocusControllerTests
helper:68, its direct expiry-boundary test:1179, and SessionsModelTests helper:111. All must inject
explicit snapshots. Focus tests currently give VisualRecovery `{ [] }`; do not reuse that empty
closure for new effect validation. Give the common helper a mutable fixture catalogue independent
of submitted rows, populated from owned `surface()` fixtures with a per-test override. This lets
blocked-color tests change native evidence without delivering a Sessions poll. Update fixtures
for intentional PID/mapping changes; immutable title/tab/TTY fields require reconstructed rows.

Focused red cases: closed ID with owner still alive, same ID changed TTY, changed app generation,
duplicate ID/TTY, and permission/timeout failure during blocked colors. Positive controls:
surviving moved tab, identical titles/directories, fresh foreground process, and one invalid row
alongside a healthy target. Exercise preview, manual and automatic source/outside targets,
cancel/recovery while snapshot blocks, and zero new effect metadata/bytes on rejection. Retain
the existing two-second preview and six-second focus freshness tests. Source-level test coverage
and owned PTY bytes do not establish physical Ghostty acceptance.

Memory consultation: MEMORY.md:664-665 was used only to retain the no-live-operation boundary;
no memory-derived runtime status is claimed.

# Native revalidation implementation check

Last Updated: 2026-10-14
Scope: current primary-checkout diff in six Swift source/test files. Read-only source analysis;
no builds, tests, native operations, apps or real-home writes.

## One concrete ordering defect

`focus-controller.swift:370-380` checks whether a fresh emphasized binding can be captured
before calling `automaticSourcesCurrent` with fresh source targets. Consider one High surface
A with one cue and Normal B. Initial cached-source validation succeeds. During blocked color
preparation, A's producer exits and processMissing positively confirms exit. Fresh capture for
A then fails. The emphasized-binding guard throws before the source validator reaches its
producer-first `.vanished` classification at terminal-visual-state:182-187. No effect is newly
painted, but the cue and any existing dimming remain until another external catalogue poll
runs the earlier source check. The previous writer path could detect and clear that exit during
this update.

Small fix: construct `freshSources` and perform automatic source validation before the fresh
emphasized-binding guard. Keep target/attempted/lease mutation after both validations. Add the
single-High variant of `testExitedCueProducerCannotAuthorizePaintThroughAnotherHighShell`.
That existing test uses High A and B, so B supplies a surviving emphasized binding and hides
this ordering case. Verify cleared cue, armed Automatic mode, no new outside effect, and
cleanup of a previously painted outside target without requiring another catalogue poll.

## Verified implementation properties

- Production passes the same scoped snapshot closure already used for recovery. All four
  FocusController construction sites are updated, including the direct expiry test and
  SessionsModelTests' intentionally unmapped helper.
- Snapshot follows colors and current-run checks. Fresh matching requires full native ID,
  exact non-nil TTY, no old/new mapping issue, and one row in both grouped ID and TTY maps.
  Fresh foreground PID is retained; moved tab/window/title/selection fields do not reject a
  surviving surface. Only submitted IDs can be acted upon.
- Preview assigns targets/start time and schedules expiration after native preparation.
  Cancellation during the query returns before target publication, timers or painting.
- Manual/Automatic snapshot exceptions occur before attempted/wanted changes or lease
  retirement. Existing same-run lease records and logical set/cues are retained for explicit
  cleanup and retry. A failed native request is not classified as disappearance.
- After successful validation, current run/version is checked again under lock before lease
  mutations. Per-writer lease/catalogue-age/revision/source checks remain. Native work stays
  outside VisualRecovery's device preparation and the 100 ms device deadline.
- GhosttyCatalog.snapshot now bounds caller queue wait to two seconds, skips expired queued
  work, uses the remaining budget for runBounded, and rejects late results. The semaphore
  success orders result access; a timed-out caller does not read incomplete result storage.
- No-outside updates retain the earlier producer checks and return without colors or native
  enumeration. That preserves the existing all-High cue resolution case without output.

## Concrete test limits

New tests cover closed preview, changed manual TTY, automatic native-query failure, moved pane
with new foreground PID, duplicate ID/TTY, recovery during blocked native preparation, and a
query exception after an existing lease. Fixtures provide explicit snapshots independent of
submitted rows. The producer-exit test's removed cleanup expectation is appropriate because
failed validation now happens before any lease creation; it still requires no effects/bytes.

Partial valid targets remain paintable. The pre-existing all-outside `renewed` predicate still
reports blanket unavailable when one outside row cannot map despite successful healthy
painting. This is the previously recorded partial-status finding, not a new validation defect.
No mixed-valid/invalid new validation test or changed-application test was present in the diff
read here. Existing full-ID comparison rejects the latter by inspection; visible native and
timing acceptance still require live evidence.

## Parent disposition and verification

The single-High ordering finding reproduced in zJbwDf and was corrected before c747c42. Both
initial and continuing-dimming exit cases pass. Mixed healthy/stale native rows are now covered.
Native mapping REDv2qZfv:three cases/seven failures; snapshot RED8WfNva:three failures. s10QY9
found obsolete exact-time and nonexistent-cleanup expectations; corrected KVZZnL passed94 cases.
ro9dB0's old status waiter was changed to observe actual cue clearing. Full w82n5q passes585 tests
in20.127s; release3bZq5y passes28.26s. Twelve new regressions cover exact/ambiguous mappings,
moved/fresh foreground, blocked cancellation, failure retention, healthy partial targets,
missing source, producer exit and bounded snapshot queue expiry. Native preparation precedes
unchanged100ms writes; failed lookup keeps old recoverable leases and logical sets/cues.

vpyTDw retains a first-paint timeout in masked focus. Original outcome recorder and explicit
cleanup wait now match prior diagnostic fixtures. Cause is unestablished; passing retry is not
attribution. Physical native acceptance remains unverified. The partial-mapping status finding
is still open. No live Ghostty/app/install/settings/VM/terminal-session action occurred.

Scope: two source concerns (effect preparation and snapshot bound), mandatory production/test
constructor callers, three test files, existing API/bug/roadmap. A single coupled feature was
kept together because revalidation must be bounded before it becomes an effect prerequisite.
No generic adapter, replacement watcher, cached-row fallback or deadline widening was added.
