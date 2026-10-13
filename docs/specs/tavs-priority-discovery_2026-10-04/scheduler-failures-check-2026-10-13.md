# Scheduler partial failures: source investigation
Baseline: 525d42686b315e5ba78d9118bd70719538be878e (2026-10-13).
Read-only source inspection. No tests, app/device/native calls, or process changes ran.

## Verdict and contract
Claude M6 is confirmed: scheduler-driven managed failures have no production result consumer,
visible warning, or automatic retry. This does not mean failures are pruned or irrecoverable.
SPEC G6/G8 (SPEC.md:43-49) requires partial failures and uncertain targets to be visible.
SPEC.md:263-279 requires serialized current-policy writes, bounded independent fanout,
separate restored/vanished/unaffected/failed statuses, and retention of failed targets for retry.
The wording does not require a retry daemon or automatic retry of emergency recovery.
PROGRESS.md:885-898 explicitly leaves M6 next and warns that canceled metadata is not restoration.

## Current source evidence
- Broadcaster.swift:17-20 exposes lastResult under NSCondition, but Scheduler's protocol
  (Scheduler.swift:153-163) exposes no results. Source search finds no production lastResult reader.
- Broadcaster.swift:98-106 records startup reconciliation/registration then any queued operation.
  record():110-113 overwrites the prior result, so polling just the latest result can miss a
  startup cleanup failure that a following registration or unrelated operation replaced.
- Scheduler.swift:458-466 records lastPaintedPauseVisual immediately after enqueueing a write.
  finishEvaluation():425-434 skips unchanged paused/locked paint regardless of delivery result.
- Release is only the muted-to-unmuted edge (:420-423, :469-473). A failure does not cause a
  later active heartbeat to clear again. The 60-second heartbeat only reevaluates (:477-485).
- Broadcaster's serial queue coalesces operations (:57-79), retaining reconcile reset flags.
  Managed current policy is recomposed after queued native work; old caller colors/titles are ignored.
- VisualRecovery.apply(_:to:) (visual-recovery.swift:482-483) already provides targeted fanout
  without native discovery. fanout():542-579 validates exact bindings and reports each physical target.
- Generic write errors become .failed (:574); they do not establish vanished. validateTarget()
  (terminal-visual-state.swift:151-173) checks device and process generations before writing.
- Native query failure/timeout only sets catalogueAvailable=false (:433-479); valid cached targets
  can still be restored. The current tuple cannot distinguish permission denial from other outages.
- TAVSLog.broadcaster exists (TAVSLog.swift:15); Broadcaster never uses it. ProcessRunner.swift:225
  logs outer timeouts, but ordinary failed fanout has no production reporting path.
- MenuContent.swift:19 displays schedule status only. :41 displays SessionsModel recoveryStatus,
  which sessions-model.swift:185-197 updates only for explicit headless recovery results.

## Recommended bounded integration
1. Add one completion/result callback to BroadcasterProtocol, delivering onto the main queue.
   Publish each completed logical batch, including startup cleanup, rather than poll lastResult.
   Keep a small unresolved failure list inside Broadcaster using the existing result items and exact
   bindings. Registration success must not erase an unresolved paint/clear failure for that target.
2. Add one coalesced retry request to the existing Broadcaster queue. After heartbeat reevaluates
   and writes current policy, enqueue retry only when unresolved exact-bound targets remain.
   Use apply(_:to:) and freshly composed policy. Do not retain prior paint colors, lock deadlines,
   titles, ordinary renders, input, or opaque pending output. No extra timer or persistent registry.
3. Show an optional published delivery warning alongside the existing menu status, with failed
   target count and unavailable-discovery notice. Log safe count/reason summaries via existing Logger.
   Keep schedule/lock status intact: it describes the policy, not proof every terminal received it.
4. Remove retry entries only after actual .restored or confirmed .vanished, or explicitly classify
   an obsolete request as superseded. An .unaffected retry is not proof a failed reset was delivered.
   Stop/supersede queued retries through current writer-policy checks and current binding validation.

## Retry cases and the smallest safe boundary
- Transient device failure with active restrictions: retry only failed exact bindings on the next
  heartbeat. CurrentRestriction/current reconciliation reads the latest lock/pause under the lock.
  A reused TTY must yield vanished/unavailable, never a guessed replacement binding.
- Native permission denial: known cached targets still work. Show discovery unavailable separately
  from device-failure count. Do not retry native queries every heartbeat merely to seek permission,
  and never guess targets from titles, paths, or unknown/nil bindings. Unknown bindings stay visible
  and require a fresh deliberate discovery/recovery action or a legitimate later registration.
- Normal release with restrictions active: targeted reconcile is needed to restore latest intent
  and legacy foreground/palette. Full-catalogue reconcile is unsafe while one peer keeps failing:
  it resets healthy terminals' freshly rendered palette. Even the failed terminal can receive a
  fresh hook between attempts, so retry must check supersession rather than blindly force reset.
- Disabled recovery (.suspended/.unavailable): never retry historical restrictive paint. Existing
  reconcile cancels active obsolete effects before byte output (:337-360); a post-prepare device
  failure leaves inactive metadata, and the next call can return nil/.unaffected (:350-353).
  Blind emergencyReset would overwrite a legitimate fresh hook/preview; forcing resetLegacy does
  not resolve this safely. Smallest safe M6 scope: report unresolved cleanup and leave Restore
  Visibility as the explicit retry while disabled. Automatic default-reset retry needs a targeted
  guard checked under the existing writer lock against current revision and fresh publication;
  that is a separate concrete decision, not permission to invent a new retry framework.
- Stale queued retry: choose policy when the writer executes, not when Scheduler receives failure.
  A new schedule, grant, suspension, preview, focus or hook must take precedence over old output.
  Do not let an unrelated later successful batch erase outstanding failures for other targets.

## Existing tests and required regressions
BroadcasterTests.swift:368-394 proves failure retention and manual later retry beside healthy fanout;
it does not involve Scheduler. :318-366 covers fresh policy after blocked native work and coalescing.
:183-254 proves suspended recovery/late clear cannot overwrite fresh themes or full style renders.
SchedulerTests.swift:859-893/:949-971 enforces no unchanged repaint; :344-377 enforces no suspended
heartbeat output. MockBroadcaster.swift has call counters only, so no result integration is tested.
Add focused cases: failed pause retries next heartbeat; failed release targets only failing peers;
main-thread callback updates visible count; recovery/unknown marker blocks old paints; post-prepare
cleanup failure stays unresolved rather than unaffected-success; fresh full render beats a stale
retry; nil binding/native denial are explicit; startup failure survives registration; coalesced
retries preserve flags without native backlog; vanished ends retry and healthy targets get no bytes.

Logging alone improves diagnostics but does not satisfy G8's visible-state requirement. A single
menu warning/count is the smallest useful UI addition. No test execution or live acceptance claimed.
Memory orientation only: MEMORY.md:678-681 informed where to look; current source supersedes the
old pruning note. Historical rollout: 01a100cb-205c-7840-8268-c3d4ab1f7849.

## Follow-up: six-file diff source review
### Metadata
Reviewer: GPT-6; code/coaching/standard; 2026-10-13; uncommitted bounded reporting/retry diff.
### Rubric scores
| Dimension | Score | Evidence |
| --- | --- | --- |
| correctness | 6 | Retry path is safe; visible wording conflates retained historical failure with current incompleteness. |
| security | 8 | Exact physical bindings, current serialized policy, count-only logging; no new native access. |
| maintainability | 7 | One existing queue, callback and retained result state; no timer or persistent registry. |
| test_coverage | 8 | Source now covers exact targeting, unaffected retention, blocked/coalesced suspension and nil binding. |
| completeness | 7 | Scope intentionally leaves release/emergency retries to explicit Restore Visibility. |
### Verdict
CONCERN; high confidence in source assessment; tests and live behavior were not executed.
### Findings
R1 MEDIUM. Situation: Scheduler.swift:240 and Broadcaster.swift:133-138.
Behavior: failures remain after successful independent recovery or fresh hooks, which do not acknowledge them.
Impact: "Terminal updates incomplete" can report a historical failure as current visual incompleteness indefinitely.
Suggestion: use explicit historical wording, such as "Earlier terminal updates: N failed. Restore Visibility is available."
### Summary
Exact targeting, unaffected-result retention and main-queue publication checked; no actual production memory/race defect found.
A busy broadcaster ignores repeated retry requests; ordinary/release enqueue cancels pendingRetry; no native retry backlog forms.
Queued .currentRestriction reevaluates suspension inside the shared writer; nil policy returns unaffected and retains failures.
The two broader retry risks are avoided: healthy palette resets and automatic suspended defaults over fresh hooks.
