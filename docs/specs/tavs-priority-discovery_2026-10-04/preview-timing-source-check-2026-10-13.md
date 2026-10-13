# Preview preparation and lifetime source checks

Last Updated: 2026-10-13 (Europe/Vienna)
Version: 1.1
Current product checkpoint: `927a746`. Reports retain their original source-only scope.

These source-only reports describe the initial and corrected drafts. Parent tests reproduced
both timing defects. The final source queues expiry before the paint-age guard; the clock fixture
now serializes its counter and the canceled-worker test also drains main callbacks. Review reports
do not establish passing tests, configuration latency or physical Ghostty acceptance.

# M5 configured-color cost and preview timing

Source/docs-only investigation. No Ghostty invocation, tests, builds, app launch,
native catalogue or device actions. Actual query latency has not been measured here.

## Foundations and actual repeated work

- SPEC.md in docs/specs/tavs-priority-discovery_2026-10-04:38-39,120-121,465-468
  requires a two-second preview (250 ms tolerance), immediate UI cancellation,
  and bounded clear. Lines 200-218 require safe background-only composition,
  latest-intent restoration and explicit unavailable states. Configuration is a
  guide for plain shells, not a getter for running dynamic surface colors.
- terminal-renderer.swift:29-47 checks the supplied config paths on every query.
  At least one nonempty file triggers +validate-config, then +show-config, each
  with its OWN two-second bound. Thus successful preparation can approach four
  seconds, excluding file checks/process launch overhead. No configured file
  takes one explicit-default show-config call. Removing validation would weaken
  the documented failure contract: show-config can omit configuration diagnostics.
- ProcessRunner.swift:54-126 drains stdout/stderr, caps stdout at 1 MiB and rejects
  nonzero exit/timeout. Keep this path, without raw run() or output fallback.
- TAVSApp.swift:210-218 supplies four preflight paths: config and config.ghostty in
  XDG_CONFIG_HOME/ghostty and the macOS Application Support directory. These paths
  are NOT passed as CLI arguments. They only choose default versus configured
  loading; Ghostty itself resolves its dependency graph using inherited environment.
  GhosttyCatalog.executable(for:) at 57-63 verifies the selected app generation.
- FocusController.preview at 48-97 queries colors ONCE for the entire multirow
  selection. Superseded queued runs skip work via the leading isCurrent check.
  A query already running continues until return or its bounded subprocess timeout.
  Each later accepted preview runs a fresh query. There is no per-target query.
- FocusController.updateManual at 289-290 already caches colors in run.colors.
  Manual refreshes and an automatic run with continuing cues reuse them. New runs
  query again; automatic mode with no cues retires that run. No query repeats on
  every catalogue tick within one run. Preview and focus use the same serial queue.

## Confirmed timing defect

Run.startedAt is captured at selection (52), expiry is scheduled immediately (57),
isCurrent compares now < startedAt+2 (515-517), and TerminalPreviewRequest copies
that early timestamp (75). Configuration and target capture therefore consume
visible duration. For preparation delay D and paint delay W, remaining lease is
max(0, 2-D-W), not two seconds. D>=2 yields no paint, even after a valid query.
This is a source derivation, not a measured native slowdown.

VisualRecovery:240-261 persists request.startedAt as the preview heartbeat;
TerminalVisualStateStore:215-221 enforces heartbeat age<2 and 253-258 prevents
same-ID timestamp renewal. Moving ONLY the UI timer cannot fix the lease.

## Contrasting remedies

1. Persistent metadata cache: avoids later processes, but top-level file mtime/
   size alone does not establish unchanged resolved colors. Includes, optional
   files, theme files, theme lookup roots, symlink targets, environment, defaults
   from a changed executable and app generation can differ independently. This
   repository has no complete dependency discovery/invalidation interface.
   Appearance is an additional risk; parseConfiguration explicitly rejects
   light:/dark: dual themes. Never turn that rejection into a cached-color fallback.
2. Per-operation reuse/coalescing: reuse across selected targets already exists;
   focus run reuse already exists; queued obsolete previews already skip queries.
   Sharing one in-flight result across later selections can reuse a configuration
   snapshot from before that selection. A new cache/coalescer has little justified
   benefit without measured repeated work and a defined freshness boundary.
3. Preview timing correction: fixes the demonstrated failure without retaining
   configured colors between operations. Recommended first slice.

## Smallest recommended implementation boundary

Keep selection identity/restriction revision immediately cancellable while colors
and targets prepare. After successful preparation, under the existing lock verify
that this is still current, then establish ONE immutable preview display-start
anchor immediately before bounded paint fanout. Use that same anchor in the
request/record, isCurrent and expiry scheduling. Preparing runs need identity
checks without the two-second display-age check. Keep manual focus's Run semantics
separate; do not make focus renewal depend on the preview clock.

Schedule expiry against anchor+2, using remaining delay if main-queue dispatch is
late. Do not schedule a fresh two seconds after fanout while retaining an earlier
record heartbeat. Clear/Escape/replacement/recovery must invalidate the run during
preparation and paint; stale preparation completions must not arm timers or paint.
Keep the original revision and exact-ID cleanup. Never renew an already saved
preview heartbeat under the same ID. Existing docs/API_REFERENCE.md:280 calls the
anchor the selection's original time; update that description explicitly to match
visible-duration acceptance rather than silently extending existing record leases.

This removes configuration delay from duration, not configuration cost. Healthy
paint fanout must still fit the SPEC's 250 ms duration tolerance; device calls have
100 ms bounds but aggregate scheduling is not proven here. If measurement finds
fanout skew exceeds tolerance, a paint-completion/start callback is the next narrow
step. Do not promise native timing from controller tests alone.

## Tests and unresolved facts

Add a deterministic VirtualClock test: colors advances time by >2 seconds, then
preview paints with a new heartbeat and remains active for two seconds from that
anchor. Add blocked query cancellation, replaced-selection no late timer/paint,
configuration failure without effect, and query-call counts (one per preview,
not per row). Retain focus-controller-tests:787-841 (one timer, latest intent,
old timer isolation, blocked-query cancellation), renderer-tests:74-117 (strict
parser/defaults/validation), visual-recovery-tests:978-992 (no lease renewal),
plus restriction-replacement and recovery cancellation regressions.

Pre-existing limitation: focus's run.colors can survive config changes during a
long run; this investigation does not establish that all existing focus colors
are fresh. Do not expand this lifetime cache into preview or claim it proves
config-change acceptance. CLI validation/loading also is not transactional.

Official external verification still needed before any dependency-based cache:
exact include/optional-config/theme lookup behavior, appearance selection/support,
config/config.ghostty precedence, launch overrides and CLI versus running-app
configuration behavior for the installed Ghostty version. Existing docs link
upstream show_config.zig and validate_config.zig but were not refreshed externally
under this source-only brief. No cache design may treat those details as verified.

# Preview timing diff source review

Reviewed only the uncommitted focus-controller.swift and focus-controller-tests.swift
changes, with connected timer/recovery source for context. No builds, tests, native
calls, apps or device actions. No runtime reproduction is claimed.

## Concrete new defect

[P2] Accepted-but-expired start can leave the preview UI active without a timer.

Situation: focus-controller.swift:65-70 reads startedAt, assigns it and targets to
an accepted run under the lock, then returns if isCurrent(run) is false. The sole
expiry timer is only queued at 71-78, AFTER that guard.

Behavior: if the worker is descheduled, waits on the lock, or the injected clock
advances enough between startedAt capture and the guard, current can still equal
run while now>=startedAt+2. The guard returns without timer scheduling, painting,
or any main-thread failure/clear callback. isPreviewActive remains true and
previewStatus stays Preparing preview until another explicit user action clears it.
The old implementation had already scheduled its expiry at selection, so this
specific accepted-but-expired no-timer path is introduced by the diff.

Smallest fix: every accepted run must enqueue its exact-ID remaining-delay expiry
(including zero delay) even when its paint predicate has already expired. Check
isCurrent again for painting AFTER queuing that expiry. Alternatively explicitly
retire this accepted-but-expired run on main with an exact-ID guard. Canceled
runs still must never arm a timer. Do not extend the timestamp or lease.

This branch is verified from source; its practical frequency is unmeasured.
A deterministic Clock fixture can advance between start capture and the next
now() call to exercise it without sleeping or relying on scheduler luck.

## Requirements retained by the rest of the diff

- Preparing runs have identity-only currency while previewStartedAt is nil.
  Once accepted, start time is assigned under the lock and read under that lock.
  No loop or refresh changes it afterward.
- Timer scheduling computes max(0, startedAt+2-now) and is queued before fanout.
  Thus main-queue or fanout delay after that enqueue cannot reset a fresh two
  seconds. The exact same startedAt reaches TerminalPreviewRequest and metadata.
- Timer registration and firing guard current===run. Cancel, replacement and
  recovery cannot arm a stale queued timer or let it clear a later selection.
- Cancellation while colors block makes acceptance false. It neither records
  targets/start time nor schedules a timer, and the writer retains its predicate.
- Configuration exceptions before start publication set inactive status on main
  only while the original run remains current. Explicit dual-theme/unavailable
  reasons survive. No config result is cached between previews.
- Manual/automatic Run construction drops a timestamp that had no focus consumer;
  revision, version, focus leases and catalogue heartbeat policy are untouched.

## Tests inspected and gaps

Added tests: slow preparation advances VirtualClock by three seconds and verifies
one query for two rows, heartbeat 1003, one two-second timer and exact reset;
replacement skips obsolete selection work; failed configuration has explicit
inactive status without timer or paint. Existing blocked-query cancellation,
old-timer isolation, current-intent expiry and recovery tests remain.

Add coverage for accepted start expiry before timer enqueue (defect above).
Also add delayed main-queue timer registration: advance clock after start but
before the queued scheduling callback, and assert a shortened or zero delay,
not a fresh two seconds. The existing slow-preparation test advances ONLY before
start, so it does not verify this new remaining-delay branch. A cancellation test
should assert scheduledTimers remains empty after draining the queued main blocks.
These are coverage gaps, not additional demonstrated production defects.

## Pre-existing limits

Wall-clock lease checks and monotonic dispatch timers can diverge after clock
adjustments. Physical paint duration still depends on bounded fanout/output and
main-queue responsiveness; this source review cannot establish native 250 ms
tolerance. Writer cancellation is checked before metadata/output work, with
per-TTY serialization and exact-ID clear handling the remaining write race.
Long-lived focus run.colors and nontransactional CLI config loading are unchanged.

## Final correction assessment

The parent reports CDAsJf reproduced the draft defect (no scheduled timer and
active UI). I inspected the subsequent source/test diff, without rerunning it.

The production correction closes that path: accepted runs enqueue exact-ID expiry
before isCurrent gates painting. Expired accepted starts therefore schedule zero
remaining delay and clear; canceled/replaced runs cannot register their timer.
The timestamp is still shared with the request and never renewed. No remaining
concrete production defect was found in this changed branch.

The added tests now target zero-delay expired-start cleanup, shortened registration
(1.25 seconds elapsed gives 0.75 remaining), and canceled preparation with no timer.

One concrete new test-fixture race remains: PreviewExpiryBoundaryClock.now()
mutates and checks reads without synchronization. The worker's isCurrent call and
the queued main timer-registration callback can invoke it concurrently. If one
increments reads to 2 and the other increments it to 3 before either checks
reads==2, both can skip the intended clock advance and the expired-start test can
paint or schedule delay=2. Serialize the increment, boundary advance and return
with a small lock in this helper to make that test deterministic. This is a
fixture defect, not a remaining preview production defect.

Minor coverage limit: the blocked-color cancellation test fulfills its drain
expectation directly on the worker queue. A worker-to-main completion would also
establish that any queued main timer-registration block has drained before its
new scheduledTimers assertion. The production exact-ID guard itself is present.

Pre-existing limits listed above still apply. No native timing acceptance or
passing test claim is inferred from this source-only correction assessment.

## Replacement cleanup source reports

The following reports retain draft findings and their later correction. Parent regressions reproduced
same-target busy admission, unrelated serial-batch delay and loss of a timed-out predecessor.
The final source keeps bounded failure reporting separate from transitive dependency completion.
These checks do not causally attribute the older `RoXBKk` failure or establish physical Ghostty timing.

# Replacement preview versus its prior cleanup

Read-only source investigation at b35f0ff. No builds, tests, Ghostty/native calls,
apps or devices. RoXBKk has not been reproduced or causally attributed here.

## Foundations

SPEC in docs/specs/tavs-priority-discovery_2026-10-04/SPEC.md:120-121 says a
selection change restarts a two-second preview and clears deselected rows;
Clear/Escape/close cancel immediately. Lines 271-272 and 465-470 retain the 100 ms
writer deadline, healthy-target independence, bounded partial failures, immediate
UI cancellation and one-second healthy clear/recovery acceptance. Recovery must
remain available independently. Per-target busy failures are not permission to
stretch writer bounds or guess that a timed-out write did nothing.

## Confirmed possible race, not attribution of RoXBKk

FocusController.preview:48 calls clearPreview immediately. clearPreview:105-126
invalidates the old ID/UI and asynchronously runs exact-ID cleanup on clearQueue.
The new preview prepares/paints on a separate serial start queue (57-88).
There is no ordering edge between same-target cleanup and replacement paint.

SystemProcessRunner:159-170 calls beforeOpen, then takes static process-wide
admission for the physical target and opens the device. Its defer releases
admission only when the worker returns. completeDeviceWrite:217-229 publishes a
successful result only after operation completion; caller timeout does NOT release
a worker still stuck inside open/preparation. admitDevice:240-251 rejects an
occupied same-path/same-physical/non-emergency slot immediately with EBUSY.
Plain/native aliases share that physical key; emergency has an independent lane.

Therefore this healthy interleaving is possible:
1. Old exact-ID cleanup cancels old metadata, acquires ordinary admission and
   begins a finite open/write operation on target A.
2. New preview resolves colors quickly and attempts target A before that worker
   returns. It receives EBUSY, even though A itself is healthy.
3. VisualRecovery.fanout:540-579 catches the error as a failed item. The controller
   reports it, without another preview attempt for that selection.
4. Old cleanup returns, restores current background, and releases admission.
   The replacement remains unpainted until another explicit selection action.

The reverse ordering can make old cleanup fail EBUSY and enter pendingClear.
Exact-ID checks prevent that cleanup from canceling a newer record, but do not
avoid admission/open: VisualRecovery:181-210 runs metadata cancellation before
admission even when no old record matches; output preparation checks IDs at 262.
An obsolete no-op clear can consequently still contend with a current preview.

The old-timer test at focus-controller-tests:921-934 replaces the selection and
awaits paint before firing the OLD timer. Its timer ID guard is correct, but the
replacement itself can race its own cleanup before that timer is exercised.
This explains a possible test failure mechanism, not the retained run's cause.

## Contrasting remedies and recommended boundary

Recommended: order only a preview's own outstanding exact-ID cleanup and its
replacement on the SAME physical target, in the controller/fanout orchestration
layer before starting the new 100 ms writer call. Register the cleanup dependency
when it is scheduled, not later when pendingClear is published on main. Consume
it per physical target so another selected healthy target can paint independently.
Keep lifecycle state local and in memory; ordinary Git/tests suffice.

A small per-physical completion dependency, or per-physical task ordering, is
sufficient. Preserve full alias grouping/ambiguity checks before individual
requests. Do not turn clearQueue.sync, a whole-run completion wait or all-target
barrier into the dependency: they delay unrelated targets. A clear batch must
signal each physical completion independently, not only after its slowest peer.
Cancellation must invalidate queued replacement work immediately, and recovery
must not join this preview dependency. Do not consume preparation/cleanup waiting
as a renewal of an already published preview timestamp.

Successful cleanup return implies its admission has been released. Bounded cleanup
failure does not prove release if its worker remains stuck; keep that target an
explicit partial failure and independent emergency recovery available. Do not
poll admission, extend its deadline or retry a timed-out device write blindly.

Skipping same-target clear can avoid the race, but needs ownership transfer and
cleanup when color resolution, validation or paint fails. Otherwise old visible
paint can survive canceled/failed preparation. It is a wider change than ordering.
A general EBUSY retry changes global writer semantics, can amplify stuck workers,
and hides the distinction between owned cleanup and unrelated contention.

## Source-grounded deterministic test idea

Paint A, then instrument the REAL SystemProcessRunner's next open for A so the
old cleanup signals admission-held and waits on a controlled gate. Have replacement
colors wait for that signal before returning. The new request now necessarily
meets occupied admission: record its failed result/EBUSY before releasing cleanup
within the original deadline. Use this as the red mechanism test, not a timing
assumption about RoXBKk. After correction, prove replacement waits only for its
own finite cleanup and paints once after release. Include healthy B in the new
selection and prove B paints while A cleanup is held; cancel replacement while
waiting and prove no late paint. Keep writer 100 ms/admission/emergency regressions.
Existing process-runner-tests:462-524 cover physical alias admission and retained
admission after timeout; 527-562 covers independent emergency/reset admission.
Focus-controller-tests:505-536 requires preview clear independence from unrelated
focus cleanup. None presently gates prior preview cleanup against replacement.

# Replacement cleanup dependency diff review

Source-only review of the uncommitted FocusController/VisualRecovery changes and
owned-PTY replacement test. No builds/tests/native/app/device actions. The parent
reports KMqaUW red and KGHoBu green; those were not rerun or independently verified.

## Concrete introduced defect

[P2] Per-physical waiting inherits cross-run serial cleanup queue blockage.

FocusController still submits one whole-run recovery.apply batch to serial
clearQueue. Per-physical didComplete releases a healthy target independently
INSIDE that batch, but a second run's batch cannot start until the first finishes.
The new awaitPriorClear makes a healthy replacement depend on that queue backlog.

Concrete interleaving:
1. Preview A is cleared; A's cleanup batch is pending/blocked on clearQueue.
2. Preview B starts and paints because previewClears has no B dependency yet.
3. B is replaced. Its own B group is registered, but B cleanup is queued behind A.
4. Replacement B waits inside its original 100 ms beforeOpen deadline for that
   group. A can consume the budget, although B is healthy and B cleanup has not
   begun. B fails before device admission and has no automatic repaint attempt.
Multiple old batches can accumulate the same delay. This is not fixed by calling
B's completion before A's completion within a DIFFERENT multi-target batch.

The serial cleanup backlog itself predates this diff; turning it into a bounded
replacement-start dependency/failure is the new consequence. The source permits
this interleaving; no runtime reproduction was performed during this review.

Smallest fix boundary: allow cleanup tasks for distinct physical targets from
successive runs to start independently, while preserving ordering of multiple
clears on the same physical target. Keep existing fanout alias/conflicting-owner
validation and the original 100 ms wait/write budget. Do not replace the queue
with blind concurrent same-target clears, a global barrier or general busy retry.

## Checked behavior without a defect found

- Synchronous registration enters exactly one group per distinct physical target
  per cleanup run. Duplicate plain/native aliases do not over-enter the group.
- fanout computes distinct physical groups and invokes didComplete once after
  every success/failure/vanished/unaffected result. A preferred alias remains in
  that same physical group; errors use an original alias with the same key.
- Group enter/leave/map removal are protected by the controller lock. A group is
  removed only when its count is zero and the map still points to that instance.
  Weak-self disappearance balances every entered group. There is no error branch
  that skips normal fanout completion notification.
- awaitPriorClear copies the group under lock, waits outside that lock, and
  checks exact current-run identity/age both before and after waiting. It executes
  before admission through beforeOpen and shares the writer's original deadline.
  A timed-out worker that retains admission is still an explicit failure.
- Cancellation invalidates queued work immediately; waiting work can take up to
  the existing deadline to observe cancellation but cannot start output afterward.
  Recovery does not use the preview callback and retains its emergency admission.
- A direct TerminalPreviewRequest with nil awaitPriorClear retains its former
  beforeOpen behavior. No configuration cache or admission/retry change was added.
- The new PTY regression makes old cleanup hold real admission for finite 40 ms,
  forces replacement color resolution to follow that admission, and checks zero
  EBUSY/new active effect ID. It covers the single-target original mechanism.

## Concrete tests to add

1. Hold A-only clear before its writer completes; paint B while A is held; replace
   B and prove its own cleanup/start finish without waiting for A. Gate events
   rather than assuming request order. Preserve partial-failure reporting for A.
2. One old multiselection A+B: hold A cleanup and prove B replacement can paint
   after B's per-target callback while A remains held. This verifies callbacks
   release independently, instead of only at overall batch completion.
3. Cancel/recover while a replacement waits for its group; release cleanup and
   assert no late paint, timer or new effect. Confirm independent emergency reset.
4. Exercise didComplete once per physical target for healthy, vanished, unavailable,
   conflicting-owner and ambiguous-native groups. Include plain/native aliases and
   repeated cleanup registrations to catch enter/leave accounting regressions.

Pre-existing limits: a timed-out write can retain admission until its worker
returns; per-target callbacks signify bounded call completion, not worker release
in that timeout case. Main-thread status and whole-batch reporting still wait for
fanout return. Physical preview duration and healthy-target latency need runtime
acceptance. No causal claim about the retained old-timer failure is added here.

## Final corrected-diff assessment

Inspected the subsequent concurrent-batch/predecessor-chain correction and tests.
The parent reports ZTqHdl reproduced cross-run blockage; I did not rerun that log
or claim the new tests pass. No remaining concrete introduced defect was found
in the inspected source.

The clear queue now permits distinct-run batches to execute concurrently. Each
physical registration takes its current predecessor under the controller lock,
creates/enters a NEW group, and replaces the map entry. Edges point only to an
older group, so there is no self-wait or cycle. A completion leaves precisely
its captured group; it removes the map entry only if still newest. Completing
an older clear cannot erase a newer outstanding dependency. Alias grouping still
matches each registration with one physical callback.

Predecessor waits run before clear metadata cancellation, locks and admission,
using the original writer deadline. Preview waits use that same deadline before
admission, outside controller locks, with current-run checks around the wait.
No deadline is renewed. Every caught fanout outcome reaches didComplete; this
includes failed, vanished, unaffected and restored paths. Direct requests with
nil callbacks retain their prior path. Emergency operations do not traverse
these waits and keep their independent admission lane.

The source tests now cover an unrelated replacement while another whole batch
is held, cancel during an owned cleanup wait, and healthy/unavailable per-physical
callbacks before a stalled peer. The corrected native-binding record lookup
matches state.currentEffectUnlocked's exact-target location. Plain/native alias
callback count is checked once per physical group. No fixture defect was found
in this correction. Explicit callback regressions for vanished/conflicting-owner/
ambiguous-native statuses would broaden coverage but are not required to repair
an identified defect: their unconditional callback path is shared in source.

Limit retained: completion signals that the bounded call returned, including
failure, not that a timed-out native worker released admission. A predecessor
wait can fail rather than make progress; failed cleanup remains reported and
retry state retained. This is not a promise of successful target restoration.
Physical timing, hung-worker release and independent recovery acceptance still
require the parent's runtime checks. Source inspection alone establishes no
native latency or device acceptance claim.

## Additional transitive-timeout counterexample

The parent's additional counterexample identifies an ordering gap missed in the
preceding final assessment. This supersedes its no-remaining-defect conclusion.

[P2] A failed successor can discard its still-running predecessor dependency.

C1 is outstanding before device admission (for example in pre-writer validation
or a controlled ProcessRunner fixture). C2 records C1 as predecessor, but its
beforeOpen wait reaches its 100 ms deadline. fanout reports C2 failed and invokes
didComplete. That callback immediately leaves C2's group and, if newest, removes
its map entry, although C1 has not finished. C3 already registered against C2 sees
a completed predecessor; a later preview can likewise see no map dependency.
Both can proceed before C1 reaches or returns from device I/O.

Exact-ID metadata cancellation protects C3's newer record from C1. It does NOT
order admission: C1's later finite write attempt and C3 can still collide with
EBUSY. Thus the stale-record safety property survives, but the intended own-clear
ordering property does not. This is a source counterexample, not a reproduction
or attribution of a native failure. If C1 is already a timed-out worker inside
SystemProcessRunner, its retained admission still rejects C3; that separate
pre-existing protection must not be mistaken for transitive dependency ordering.

Smallest correction: report C2's bounded failure immediately, but leave/finalize
its dependency group only after BOTH C2's result and its captured predecessor
completion. In didComplete, dispatch the existing leave/map-removal closure with
predecessor.notify(on: the existing concurrent clearQueue); no predecessor can
finalize immediately. That retains the transitive edge without blocking callbacks,
renewing the writer deadline, retrying writes or creating another framework.
Older completions must still remove the map only if they remain newest.

Deterministic regression: hold C1 before native writer entry; register C2 and let
its bounded wait fail; register C3/new preview and verify it cannot reach device
open while C1 remains held. Release C1, then verify group/map retirement and
no late paint from requests whose own deadlines expired. A fresh explicit preview
should be allowed once the chain drains. Include an independent B to retain
healthy-target progress. This tests ordering beyond the exact-ID record checks.

## Final notify-branch correction assessment

Inspected the final notify branch and transitive regression only. The parent
reports KelinG reproduced the transitive gap and a54Lpn passed 142 focused checks;
I performed no runtime verification of those results.

The correction closes the identified gap. didComplete creates one finish closure
for its own entered group. With a predecessor, that closure is scheduled only by
predecessor.notify on the existing concurrent clearQueue; without one, it runs
immediately. Own result/failure reporting still returns without waiting for that
notification. Thus C2's group means C2 returned AND its predecessor chain drained,
including when C2's original writer wait failed. C3 cannot mistake C2's failure
return for C1 completion.

Each callback path registers finish once, so each entered group has one leave.
New group edges still reference older groups only; notify adds no reverse edge,
self-wait or cycle. Map removal remains locked and conditional on newest identity.
An older notification cannot remove a newer registration. No writer deadline,
admission rule, retry behavior or emergency recovery path changes in this branch.

The transitive test holds the old clear, observes bounded failure for replacement
and successor clear, then verifies a fresh selection still cannot paint or replace
the old effect while that ancestor is held. After release it checks the old reset
and a subsequent explicit preview's fresh effect ID and cleanup. Native binding
lookup matches the exact-target storage path. No remaining concrete introduced
production or fixture defect was found in this narrow inspection.

Limits remain explicit: dependency completion tracks bounded call results, not a
native worker's post-timeout admission release. Notifications preserve ordering
without extending an individual writer budget; a fresh request can still report
partial failure if the chain does not drain within that budget. This source check
does not establish native timing, device acceptance or an independent test pass.
