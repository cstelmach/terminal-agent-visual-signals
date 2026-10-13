# Preview preparation and lifetime source checks

Last Updated: 2026-10-13 (Europe/Vienna)
Version: 1.0
Product checkpoint: `a710d9f`. Reports are source-only draft assessments.

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
