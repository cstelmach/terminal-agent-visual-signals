# Codex Review Raw Report

## Metadata

- Status: SUCCESS
- Mode: file
- Profile: code-review
- Thread ID: 01a139d5-9b0e-7af3-91fa-6f4dacb33797
- Codex exit status: 0
- Triage policy: include-all-confirmed
- Evidence directory: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-visual-state-recovery-20261014_115422
- Raw JSONL: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-visual-state-recovery-20261014_115422/events.jsonl
- Standard error: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-visual-state-recovery-20261014_115422/stderr.log
- Final message: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-visual-state-recovery-20261014_115422/final-message.md
- Command record: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-visual-state-recovery-20261014_115422/command.json
- Requested model: sol
- Configured model: gpt-5.6-sol
- Review level: full
- Effort floor: xhigh
- Effective effort: xhigh
- Effort increase reason: none
- Previous report: /private/tmp/codex-review-files-terminal-agent-visual-signals-tavs-native-sessions-focus-20261014_113807.md
- Original start (Unix seconds): 1791970687.162588
- Whole-review allowance (seconds): 7200.0
- Elapsed (seconds): 1900.550
- Execution policy: {"allowance": 7200.0, "base_branch": null, "context": "tavs-visual-state-recovery", "effort": "xhigh", "elapsed": 1900.5502970218658, "explicit_budget": null, "floor": "xhigh", "level": "full", "mode": "file", "model": "sol", "previous_report": "/private/tmp/codex-review-files-terminal-agent-visual-signals-tavs-native-sessions-focus-20261014_113807.md", "profile": "code-review", "reason": "", "resume_thread": null, "started_at": 1791970687.162588, "status": "SUCCESS", "thread_id": "01a139d5-9b0e-7af3-91fa-6f4dacb33797", "upgrades": 0, "workdir": "/Users/cs/local/code/apps/terminal-agent-visual-signals"}
- Model and effort describe requested configuration, not server attestation.

## Raw Codex Output

The report could not be written to `/tmp`: the read-only sandbox rejected the write. Full review result:

===EXECUTIVE_SUMMARY===
Overall grade: 7/10
Risk level: Medium
Summary: Three IMPORTANT correctness defects remain in scheduler state projection and schedule validation. The recovery writer otherwise rechecks suspension and target identity under the per-TTY lock, while bounded fanout isolates unhealthy targets. This was a read-only review of commit 7ecfba2; no tests or native acceptance checks were run.
===END_EXECUTIVE_SUMMARY===

===ISSUES===
### CRITICAL
None

### IMPORTANT

1. **[src/macos/TAVSApp/Sources/TAVSApp/Scheduler.swift:334] A decodable invalid schedule can crash the menu app**
   - Evidence: `loadAndEvaluate()` assigns `ScheduleStore.load` directly without calling `ScheduleStore.validate`, then evaluates it at line 352. Arbitrary decoded time strings reach force-indexing and force-unwrapping at lines 145-147. File changes invoke this path through lines 517-523.
   - Impact: Valid JSON containing `"start":"bad"` crashes the running app during evaluation and can repeat after relaunch.
   - Fix: Validate a temporary configuration before assigning it. Replace force-unwrapping time parsing with throwing or optional parsing.
   - Verification: Trigger the file watcher with a decodable invalid schedule and verify the app reports rejection without crashing or projecting mute state.

2. **[src/macos/TAVSApp/Sources/TAVSApp/Scheduler.swift:408] Failed state projection is committed in memory and is not repainted after storage recovers**
   - Evidence: `previousMuted` is updated before state writes at lines 411-426. Both write helpers swallow errors at lines 567-627. Painting still proceeds, and `lastPaintedPauseVisual` is recorded at lines 467-475. Without a policy file, `visual-recovery.swift:315-316` returns unaffected. A later evaluation sees no transition or visual change, so it does not repaint.
   - Impact: A transient filesystem or permission failure can leave the UI reporting a pause or lock while terminals remain unrestricted. Repairing storage does not automatically apply the missed visual.
   - Fix: Make state writers return success or throw. Do not commit transition and painted state until the required policy files are saved; expose a retryable error.
   - Verification: Make `muteStateURL` unwritable for the first muted evaluation, repair it, then reevaluate. The second evaluation must save state and invoke the broadcaster.

3. **[src/macos/TAVSApp/Sources/TAVSApp/ScheduleStore.swift:118] Enabled quiet periods with missing bounds pass validation and silently do nothing**
   - Evidence: Lines 120-139 validate optional bounds only when present and never require both. The evaluator returns false when either bound is absent at `Scheduler.swift:112` and `Scheduler.swift:119`. `TAVSApp.swift:61-62` therefore reports incomplete rules as valid.
   - Impact: An enabled quiet period can pass public validation but never mute or hard-lock.
   - Fix: Require both bounds for the selected quiet-period kind and return a specific validation error when either is missing.
   - Verification: Test hourly rules missing either minute and fixed-daily rules missing either time. All must fail validation.

### MINOR
None
===END_ISSUES===

===SCORE_CARD===
| Dimension | Score | Evidence |
|---|---:|---|
| Correctness | 5/10 | Invalid schedules can crash, failed state writes can permanently miss paint, and incomplete quiet rules validate. |
| Security | 8/10 | Typed payloads, bounded records, `O_NOFOLLOW`, process-generation checks, and fixed OSC construction were verified. |
| Maintainability | 7/10 | Concerns are separated, although scheduler state commits and output effects are loosely coordinated. |
| Test Coverage | 6/10 | Extensive race, PTY, ownership, and privacy coverage exists, but none of the three confirmed paths is discriminated. |
| Performance | 8/10 | Device writes retain the 100 ms deadline, subprocesses are bounded, and fanout is concurrent. |
| Overall | 7/10 | Rounded mean is 7; no CRITICAL cap applies. |
===END_SCORE_CARD===

===RECOMMENDATIONS===
1. Make scheduler policy-file writes observable and retryable before committing transition state.
2. Validate every loaded schedule before evaluation and remove force-unwrapped parsing.
3. Require complete bounds for every enabled quiet-period rule.

Scope coverage: All 32 named files were inspected, with relevant connected callers and contracts. No named file was omitted. Tests, builds, applications, native requests, real-home state, and physical Ghostty acceptance were not run.

Falsified mechanisms: queued restrictive writes recheck suspension under serialization; reused TTYs are generation-bound; unhealthy devices do not block healthy fanout; preview and focus clearing do not replay historical titles or BEL bytes. Native navigation, readability, Spaces behavior, Linux runtime behavior, first-paint behavior, EPERM observations, and fresh-render timeout causes remain unverified.
===END_RECOMMENDATIONS===

## Wrapper evaluation of partition 2

Reviewed source: commit `7ecfba2`. Source-only verification; no runtime reproduction,
source edits, builds, tests, native requests or real-home operations.

### [UPGRADED] Scheduler.swift:334: Decodable invalid time reaches a trapping parser

- Raw finding: The scheduler loads decoded schedules without semantic validation and can
  crash on a malformed time string.
- Evidence checked: `ScheduleStore.swift:70-75`, `84-96`, `99-109`, `144-155`;
  `Scheduler.swift:14-31`, `78-81`, `145-147`, `330-354`, `517-523`;
  `TAVSApp.swift:57-65`; connected Preferences validates drafts, but the file watcher/load
  path does not pass through that validation.
- Evaluation: With master active and an enabled allowed window whose start is `bad`, JSON
  decoding succeeds. The scheduler calls the evaluator, which calls the forced time parser.
  `Int(parts[0])!` is nil and traps; strings with missing fields also reach forced indexing.
  This does not require malformed JSON or an unavailable native/device dependency. A hand edit,
  corruption or external writer of a decodable schedule can crash startup or the live watcher.
- Evaluated severity: CRITICAL, upgraded from IMPORTANT because the canonical severity
  definition includes crashes in realistic paths and this path terminates the companion app.
- Fix: Validate a temporary loaded schedule before adoption/evaluation and expose rejection.
  Remove trapping parser behavior or establish validated types at all evaluator entry points.
  Keep a prior valid configuration if that is the established failure behavior; do not silently
  infer a new user recovery policy from this review.
- Verification: An owned file-watcher test supplies an enabled bad start and then a valid
  replacement. Assert no trap, visible rejection, no invalid evaluation, and valid subsequent
  reload. Direct validation tests alone do not exercise the missing scheduler call.

### [CONFIRMED] Scheduler.swift:408: Failed policy persistence suppresses later repaint retry

- Raw finding: Transition/paint state is committed despite projection-write failure, allowing
  repaired storage to produce a valid rule later without applying its missed visual.
- Evidence checked: `Scheduler.swift:408-443`, `467-475`, `492-496`, `567-627`;
  `visual-recovery.swift:315-316`; `visual-restriction-policy.swift:44-45`, `53-70`,
  `100-108`; `Broadcaster.swift:49-55`, `124-136`.
- Evaluation: Both state writers return void and absorb errors. `previousMuted` and
  last-painted flags therefore advance even if the saved soft policy remains missing or
  readable/unmuted. The broadcaster then reads no current restriction and returns unaffected.
  Such a target is not placed in the failed-target retry set. After storage repair, evaluation
  writes the rule but sees no mute transition or changed visual, so it does not repaint; the
  heartbeat's retry method has no failed target to retry. Ordinary future hooks or another
  visual change can eventually paint, so this is not a claim of permanent impossibility.
  A policy-read permission error is a different branch and may be retried as a device failure;
  it does not falsify the missing/readable-old-policy trigger above.
- Severity: IMPORTANT.
- Fix: Return/throw projection outcomes and leave missed transition/paint work retryable until
  required policy persistence succeeds. Show a projection error and retain a timer-based retry.
- Verification: Fail the initial soft-pause write while policy reads still see missing or
  readable-unmuted state; allow the subsequent write and reevaluate with identical colors.
  Assert the later broadcast occurs and the state is not silently marked applied beforehand.
  A test where policy reads themselves throw would not distinguish this lost-retry branch.

### [CONFIRMED] ScheduleStore.swift:118: Missing enabled quiet-period bounds are accepted

- Raw finding: The public validator accepts enabled hourly/fixed-daily rules without both
  required bounds, and the evaluator silently ignores them.
- Evidence checked: `ScheduleStore.swift:24-33`, `84-96`, `113-141`;
  `Scheduler.swift:110-127`; `TAVSApp.swift:57-65`;
  `ScheduleStoreTests.swift:233-303` (invalid values are tested, omissions are not).
- Evaluation: Each optional field is validated only if present. There is no both-bounds
  requirement for an enabled rule. The evaluator requires both and returns false otherwise,
  including rules publicly reported as valid by the headless validation entry.
- Severity: IMPORTANT.
- Fix: Require start/end minute for enabled hourly rules and start/end time for enabled
  fixed-daily rules; return a specific missing-bound validation error. Disabled drafts need
  not be made invalid merely because their fields are incomplete.
- Verification: For each kind, test missing start, missing end and both missing with a valid
  allowed window, plus valid boundaries and disabled-incomplete controls.

## Evaluated partition 2 summary

- Raw findings: 3. Upgraded: 1. Confirmed: 2. Dismissed: 0.
- Evaluated severity counts: CRITICAL 1, IMPORTANT 2, MINOR 0.
- Independent scores: Correctness 4 (the verified runtime load trap is below adequate),
  Security 8, Maintainability 7, Test Coverage 6, Performance 8.
- Rounded mean: 7. CRITICAL cap makes evaluated overall grade 4/10.
- Raw outcome: Medium risk, 7/10. Evaluated outcome: High risk, 4/10.
- Calibration verdict: VETO because correctness is below 5; confidence high for source paths,
  with runtime reproduction still pending.
- Noninteractive selection: include all three corrections, with the precise lost-retry trigger.
- All 32 named paths were inspected by the delegated review. No scope omission was reported.
  The full requested review remains incomplete until partition 3 returns and is evaluated.
