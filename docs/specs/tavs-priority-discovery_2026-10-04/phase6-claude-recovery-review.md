> [!WARNING] DEGRADED REVIEW - LEGACY `claude -p` PATH
> This review did **not** run through `claude-hub`. That path failed:
> exceeded its 1800s deadline.
> `claude -p` is the path expected to be metered when Anthropic's paused
> subscription-metering policy returns, so this run borrows against exactly
> the risk `claude-hub` exists to hedge. Treat the findings as valid but the
> execution as degraded, and do not report this review as clean.
> Hub logs directory: /Users/cs/local/code/apps/claude-hub/logs (daily files use UTC).

# Claude Review Report

**Mode**: code-branch
**Date**: 2026-10-12
**Focus**: all default (correctness, security, maintainability, test_coverage, completeness), with emphasis on lifetime identity, shared serialization and the 100 ms caller deadline, recovery ordering, queued restrictive output, stale synthetic updates, reset/latest intent composition, failed-target retry and truthful partial reporting.

---

===DIMENSION_RATIONALE===
Using the five canonical code dimensions unchanged: correctness, security, maintainability, test_coverage, completeness. Performance is not mapped to completeness. Timing obligations are assessed under correctness and completeness: the 100 ms device caller deadline, open-before-lock ordering, and the one-second recovery paint. The artifact is a branch diff (baseline 43914a0 through committed HEAD 4bd7ce2) plus the supplied working-tree snapshot. That snapshot reroutes shell writers (trigger, idle worker, mute gate, shellrc, OSC helpers) through the new managed helper. Line references use the numbered file snapshots.
===END_DIMENSION_RATIONALE===

---

===EXECUTIVE_SUMMARY===
Overall grade: 6/10
Risk level: Medium

The core Phase 6 ordering contract is implemented soundly:
- The device is opened before the stable advisory lock is taken.
- Policy and suspension are recomputed inside the lock against the original 100 ms deadline.
- Recovery persists suspension before its serialized reset.
- Queued restrictive paints, caller snapshots and opaque pending replay are eliminated.

Two defects in that layer are material:
- **R1.** Ordinary-intent composition is stored per binding alias. When a plain alias and a native alias exist for the same TTY, fanout composes two conflicting backgrounds, so the post-pause background is nondeterministic. Debug replay deterministically resets instead of restoring the latest intent.
- **R2.** A cached binding whose recorded TTY owner has provably ended is reported as `failed` forever. After ordinary terminal close or TTY reuse, `tavs recover` and broadcaster results become permanently nonzero.

Lesser issues:
- **R3.** The idle worker treats any transient helper failure as supersession and terminates, which skips the max-runtime forced reset.
- **R4.** Hook intent publication is coupled to winning the device lock.
===END_EXECUTIVE_SUMMARY===

---

===ISSUES===

### CRITICAL
None.

### IMPORTANT

1. **[src/macos/TAVSApp/Sources/TAVSApp/terminal-visual-state.swift:238-265, :267-286, :401-411; visual-recovery.swift:159-176, :215-229]**: Ordinary background intent is bound per alias, but fanout writes every alias of the same TTY.
   - Trigger: the GUI starts with Ghostty Automation available, so `discoverAndRegisterActiveAgentTTYs` caches a native binding per surface. A hook then binds intent to the plain binding. A pause starts and ends.
   - Behavior: `apply(.reconcile)` writes both aliases. The native alias has no `bound-intent.json` and normally no current adoption record, so it composes `reset`. Final paint order is nondeterministic. `tavs` debug replay uses `cachedTarget`, which prefers the native alias, so replay always paints OSC 111.
   - Impact: violates G7 ("clearing restores current TAVS background intent") and the pause-release acceptance case.
   - Fix: compose ordinary intent per `(tty, device, ttyOwner)` lifetime, not per alias. Alternatively, dedupe fanout to one write per TTY lifetime.

2. **[src/macos/TAVSApp/Sources/TAVSApp/terminal-visual-state.swift:156-157, :301-355; visual-recovery.swift:238-240]**: Bindings whose recorded owner generation has ended are never classified as vanished and are never retired.
   - Trigger: close a registered terminal, then open a new one that reuses the same `/dev/ttysNNN`.
   - Behavior: the device number matches, the owner lookup returns nil or a different generation, the result is `.unavailable` and the item is reported `failed` on every run.
   - Impact: `tavs recover` exits nonzero indefinitely after routine churn. This contradicts "Confirmed closed targets do not produce false failure" and makes the retry list unbounded.
   - Fix: classify the binding as `.vanished` when the recorded owner PID is ESRCH or carries a different start generation, and the device is now owned by a different verified owner or by none. Retire such records.

3. **[src/core/idle-worker-background.sh:154-158; src/core/organizer-state.sh:111-113, :135]**: The idle worker exits on any nonzero helper status, not only on staleness.
   - Trigger: a broadcaster fanout or another hook holds the per-TTY writer lock while the PTY is backpressured during an idle tick. The helper times out and exits with code 1.
   - Behavior: `_TAVS_MANAGED_STALE=1` is set, then `return 0`. No later stages run and no max-runtime forced reset is sent.
   - Impact: the idle gradient freezes, and the SPEC-required forced-reset path is skipped on a transient, retryable failure.
   - Fix: stop only on exit code 3. On other failures, skip the tick and retry.

### MINOR

1. **[src/macos/TAVSApp/Sources/TAVSApp/visual-recovery.swift:99-103; ProcessRunner.swift:122, :147-157]**: Hook intent publication happens only inside the device-lock callback. An open hang, or a lock held to its deadline by a backpressured writer, drops the newer ordinary intent. A later reconcile then paints an older color.

===END_ISSUES===

---

===SCORE_CARD===

| Dimension | Score | Key Finding |
|-----------|-------|-------------|
| correctness | 5/10 | Ordering and deadline sound; alias composition (R1) and dead-binding classification (R2) wrong on common paths |
| security | 8/10 | Strict parsing, O_NOFOLLOW, control-character and size bounds, scope roots validated; no injection path found |
| maintainability | 6/10 | Dense multi-branch `write` closure; alias semantics implicit in path layout |
| test_coverage | 6/10 | Strong PTY ordering and late-open tests; no test with plain plus native alias of one TTY, no TTY-reuse recovery report test |
| completeness | 6/10 | All writers routed; retire/vanish semantics and transient retry for idle worker incomplete |
| **Overall** | **6/10** | |

===END_SCORE_CARD===

---

===RECOMMENDATIONS===

1. **[Priority 1]**: Make ordinary background composition alias-independent per TTY lifetime (R1). Add a test covering a cached native alias plus a hook-bound plain alias across pause release and debug replay.
2. **[Priority 2]**: Classify a proven owner-generation end as `vanished` and retire it (R2). Add a reused-TTY recovery report test asserting exit zero.
3. **[Priority 3]**: Distinguish stale (exit 3) from transient failure in the idle worker so retries and the forced reset survive contention (R3).

## Action required (added by the review transport, not by the reviewer)

- [ ] TODO: investigate the `claude-hub` failure that forced the legacy
      `claude -p` path: exceeded its 1800s deadline.
      Inspect this invocation's stderr and selected scalar Hub diagnostics first.
      Use a real-model canary only within an authorized bounded probe scope.
      Runbook: ~/local/code/apps/claude-hub/docs/OPERATING.md

===END_RECOMMENDATIONS===

---

===PR_READINESS===
Status: NEEDS WORK
Blockers: R1 (nondeterministic post-pause composition), R2 (permanently nonzero recovery after TTY reuse)
Scope: appropriate
Commit quality: well-organized
===END_PR_READINESS===

---

===SUGGESTED_PR_DESCRIPTION===
Fix before PR:
- Compose ordinary intent per TTY lifetime so plain and native aliases cannot paint divergent backgrounds; cover pause release and debug replay.
- Report a proven owner-generation end as vanished and retire the binding; cover TTY reuse in the recovery report and exit code.
- Retry idle-worker ticks on non-stale helper failure, preserving the max-runtime forced reset.
- Optionally decouple hook intent publication from device-lock success.
===END_SUGGESTED_PR_DESCRIPTION===

---

# Review Report

## Metadata
- **reviewer**: Claude (requested opus; served model unobserved)
- **review_type**: code
- **review_mode**: gatekeeping
- **tier**: standard
- **date**: 2026-10-12
- **target**: TAVS Phase 6, 43914a0..4bd7ce2, plus the supplied working snapshot of Swift writer/recovery/state/policy/entry and the shell bridge files

## Rubric Scores

| Dimension | Score (1-10) | Evidence |
|-----------|-------------|----------|
| correctness | 5 | ProcessRunner.swift:121-165 ordering is correct. terminal-visual-state.swift:238-265 and fanout at visual-recovery.swift:159-176 yield divergent per-alias composition. validateTarget:156-157 misclassifies dead owners. |
| security | 8 | Bounded reads with inode checks (visual-restriction-policy.swift:100-137), O_NOFOLLOW lock and records, title control-character rejection (visual-recovery.swift:93), root containment (managed-output-entry.swift:150-159). |
| maintainability | 6 | The `write` closure (visual-recovery.swift:68-137) mixes publication, binding, policy, effect and byte composition. Alias identity is encoded only in directory layout. |
| test_coverage | 6 | Paused-before-open, paused-before-policy, busy lock, late policy and backpressure fanout are tested. No test for alias duality, TTY reuse reporting, or idle-worker transient failure. |
| completeness | 6 | Every listed writer is routed through the managed path. Retire/vanish and transient retry semantics are incomplete. |

## Forced falsification (before verdict)

1. **Coalescing drops a `currentRestriction` queued behind a `reconcile`** (Broadcaster.swift:66-69).
   - Dismissed. `write` evaluates `policy.current` for every non-emergency operation and paints the rule if one exists (visual-recovery.swift:104-117).
2. **A writer paused before open, or before its policy check, repaints after recovery.**
   - Dismissed. Open precedes the lock with a deadline check (ProcessRunner.swift:122, :197-212).
   - Suspension is read twice inside policy (visual-restriction-policy.swift:29, :48) under the lock.
   - Emergency reset re-reads suspension under the lock (visual-recovery.swift:81).
3. **Ordinary composition differs by alias.**
   - Confirmed as R1.
4. **Dead bindings produce permanent false failures.**
   - Confirmed as R2.
5. **A stale synthetic tool-error or idle update repaints after a newer hook.**
   - Dismissed for background output. `validateSyntheticUnlocked` and synthetic publication require a matching latest observation inside the lock (terminal-visual-state.swift:495-522, :552-555).
   - Palette and title follow only after successful validation (trigger.sh:109-111; idle-worker-background.sh:154-159).
   - The residual window for raw title output is ordinary styling, not restrictive output.

## Verdict

**verdict**: CONCERN
**confidence**: medium (source examined directly; no execution, and macOS PTY node and reuse behavior is inferred)

## Findings

### [R1] - HIGH
- **Situation**: Per-alias storage of bound intent, and fanout over all aliases:
  - `targetURL` in terminal-visual-state.swift:401-411
  - `bindOrdinaryIntentUnlocked` at :267-286
  - `ordinaryBackgroundUnlocked` at :238-265
  - `apply` fanout at visual-recovery.swift:159-176
  - `cachedTarget` at visual-recovery.swift:215-229
- **Behavior**:
  - Hook writes bind intent to the plain binding (`target(tty:owner:)` returns `nativeSurface: nil`).
  - GUI startup registration caches a native binding for the same TTY and owner.
  - On reconcile, the native alias has no bound intent. Its fallback requires an adoption record that exists only after `coverage(for:)` runs in an open Sessions window, so it returns nil and composes `reset`.
  - Both aliases are written concurrently. The per-TTY lock serializes them in arbitrary order.
  - `--managed-reconcile` prefers the native alias (:226), so debug replay always sends OSC 111.
- **Impact**: After pause release, the terminal can end at the default background instead of the latest ordinary intent. This violates G7 and SPEC 221-223. The order varies run to run, so the failure is intermittent.
- **Suggestion**: Bind ordinary intent at lifetime granularity `(tty, device, ttyOwner)`, readable by every alias of that lifetime, or emit one composed write per TTY lifetime in `apply`. Add a test with both aliases cached.

### [R2] - HIGH
- **Situation**: `validateTarget` at terminal-visual-state.swift:156-157, `fanout` at visual-recovery.swift:238-240, and `cachedRecords` (no retirement path).
- **Behavior**:
  - When the device node still exists with the same number but the recorded `ttyOwner` is gone or carries a different start generation, the binding is `.unavailable` and is reported `failed`.
  - macOS commonly reuses the lowest free `/dev/ttysNNN`, so closing one tab and opening another reproduces this.
  - Bindings are never retired.
- **Impact**:
  - `VisualRecoveryReport.hasFailures` stays true, so `tavs recover` exits 1 after routine churn.
  - This contradicts SPEC 274-279 ("confirmed vanished targets are not failures") and SPEC 186. A different generation owning the device is validated process evidence, not uncertainty.
  - Broadcaster results also carry permanent false failures.
- **Suggestion**:
  - Return `.vanished` when the recorded owner PID is ESRCH or holds a different start generation, and the device is now held by another verified owner or by none.
  - Retire those binding directories.
  - Keep `.unavailable` only for lookup errors.

### [R3] - MEDIUM
- **Situation**: idle-worker-background.sh:154-158; organizer-state.sh:111-113 and :135.
- **Behavior**:
  - Any nonzero helper status in synthetic mode sets `_TAVS_MANAGED_STALE=1`. Examples: exit 1 from `deviceWriteTimedOut` on a busy lock, a policy read failure, or a missing helper.
  - The worker then `return 0`s. The max-runtime branch (:127-132) is never reached.
- **Impact**: A transient failure, which SPEC 271-272 treats as a retryable partial failure, permanently ends the idle gradient and skips the forced reset that SPEC 67-68 keeps on the managed path.
- **Suggestion**: Treat only exit 3 as supersession. For other statuses, skip the current tick and continue, so later ticks and the forced reset still run.

### [R4] - LOW
- **Situation**: visual-recovery.swift:99-103 (publication inside `prepare`); ProcessRunner.swift:122 and :147-157.
- **Behavior**: An ordinary hook's intent is published only after the device opens and the writer lock is acquired within 100 ms. A backpressured holder that keeps the lock to its own deadline, or a wedged open, drops the new intent.
- **Impact**: SPEC 154-155 requires the latest intent to be retained independently of presentation. A later reconcile paints a superseded color.
- **Suggestion**: On device-path failure, publish the intent through the existing bounded `withLock` record path, without painting.

## Dismissed hypotheses
- Late open holding serialization. Covered by ProcessRunner tests at 188-226.
- Opaque pending replay. Removed: mute-gate.sh:153-154 and trigger.sh:187-200; `invalidatePending` is serialized.
- `??` versus `==` precedence in `softRestriction` (visual-restriction-policy.swift:55). Nil-coalescing binds tighter, so the logic is correct.
- A partial OSC write at the deadline could leave an unterminated sequence. The next managed write begins with ESC and terminates it; not material.
- Scheduler ordering. `writeMuteState` now precedes the release reconcile (Scheduler.swift:429-435), so the release reads the new projection.

## Summary
The serialized writer, open-before-lock ordering, in-lock fresh policy and persist-first recovery satisfy the Phase 6 ordering contract. Lifetime composition across binding aliases (R1) and classification of ended owner generations (R2) produce wrong final backgrounds and permanently untruthful failure reporting, and require fixes before acceptance. R3 and R4 are smaller retry and retention gaps.

Skipped checks: no tests, builds, PTY, native, AppleEvents or UI execution, and no install or sync. The caller-reported 363 Swift and 230 Python test results are unverified.

Material risks: macOS PTY node retention and reuse behavior (R2) and Ghostty alias registration (R1) are inferred from source, not observed.

## Host source verification (Codex, separate from the Claude review)

The wrapper returned exit 0 and `CLAUDE_REVIEW_EXECUTION_PATH=claude-p-fallback`.
The banner reports that Hub exceeded its 1800-second deadline. The requested model was
Opus; neither served model nor applied effort was observed. No additional review call was
made. The supplied snapshot and source references match the requested Phase 6 paths.

Source was checked after the report returned, with repository HEAD `cd17388` at the check.
No tests, builds, native/AppleEvents/UI operations, installs, settings changes or TAVS target
signals were performed. Only the mandated review transport's own process lifecycle ran.
No repository or Git changes were made by this reviewer.

- **R1: source-confirmed.** Normal managed hooks receive a plain binding in
  `visual-recovery.swift:189-191`; `targetURL` separates native and plain aliases, while
  `bound-intent.json` is saved under that alias. `ordinaryBackgroundUnlocked` requires a
  matching adoption for an unbound native alias. `SessionsModel` adopts only on refresh,
  normally while its window is open. Fanout retains both aliases, and debug reconcile
  prefers a native alias. The claimed wrong background therefore follows when no matching
  adoption exists. The report's "always" wording is conditional on that trigger; a valid
  current adoption can avoid it. Deduplicating fanout alone must not arbitrarily choose an
  alias that still lacks the latest lifetime-bound intent.
- **R2: source-confirmed for explicit generation mismatch or proven owner absence.** The
  owner branch returns unavailable for all of these cases, unlike the existing application
  generation branch. Cached records are retained and re-enumerated, so the report stays
  failed while a reused device node still matches. Physical macOS reuse frequency was not
  checked. Retiring records is an optional cleanup; correct vanished classification is the
  necessary reporting remedy. Unknown lookup errors must remain failed/unverified.
- **R3: source-confirmed.** The helper entry distinguishes stale exit 3 from general failure
  exit 1. Shell wrappers set `_TAVS_MANAGED_STALE` for both, and the idle worker returns on
  any failure. Its applied-stage marker is advanced before that attempted write. A retry
  remedy must also retain or restore the prior applied-stage marker so the same stage can
  retry, and avoid raw palette/title output after a failed managed check.
- **R4: publication loss is source-confirmed; the suggested remedy is not implemented or
  runtime-verified.** Publication occurs only after open and lock acquisition call prepare.
  Failure before prepare cannot save this delivery's intent; observation publication does
  not save a background. Any remedy must preserve serialization, lifetime/stale-delivery
  validation and the original device deadline. An unchecked second publication path is not
  established as safe by this review.

The independent report did not identify the separate producer-versus-shell-owner guard
that the parent corrected in `2ee25f7`. That correction was source-checked but is not
presented as a Claude finding. The four reported code paths remain applicable to the
source examined after the correction. Later concurrent changes are not reviewed here.

Skipped checks: no test execution or native acceptance; shell owned-PTY acceptance remains
with the parent. Risk: the review is degraded and its runtime claims require targeted checks.

===REVIEW_META===
Execution path: claude-p-fallback (DEGRADED)
Completion: full
Review mode: code-branch
Model requested: opus
Model observed: unknown
Effort requested: unset
Effort observed: unknown
Input scope: committed diff 43914a0..4bd7ce2 plus supplied working snapshot (Swift writer/recovery/state/policy/entry, Broadcaster, Scheduler, shell trigger/idle worker/mute gate/OSC/organizer bridge/shellrc, CLI recover) and associated tests; SPEC/PLAN Phase 6 dated requirements
Focus: all default; emphasis on lifetime identity, serialization and 100 ms deadline, recovery ordering, queued restrictive output, stale synthetic updates, reset/latest intent composition, failed-target retry and partial reporting
Limitations: degraded claude-p-fallback after Hub exceeded its 1800-second deadline; tool-free, pre-gathered single-turn review; dated 2026-10-07 PTY semantic-fidelity limitation applies (format validity is not semantic fidelity); no tests, native/AppleEvents/UI, device output, install/sync/settings or TAVS target signals executed; Computer Use Ghostty denied; native visual acceptance and later focus/preview phases out of scope; shell fixtures may still be evolving; reported test counts unverified; completion means the response is complete, not that native acceptance was achieved
===END_REVIEW_META===
