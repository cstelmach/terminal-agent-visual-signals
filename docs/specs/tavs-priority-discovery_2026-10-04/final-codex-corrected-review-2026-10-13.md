# Codex Final Implementation Review

## Wrapper Metadata

- Wrapper status: SUCCESS
- Invocation: FILES, noninteractive, all nine phases, full organizer and reversible-focus scope
- Product target/base: 71e0f60 / e113fb8
- Raw skill report with appended evaluation: /private/tmp/codex-review-files-terminal-agent-visual-signals-tavs-final-corrected-20261013-20261013_024346.md
- Evidence directory: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-final-corrected-20261013-20261013_024346
- Provider thread: 01a132b7-2977-71c1-a93f-d428f0a3aef1
- Requested engine: Sol; configured model: gpt-5.6-sol (configuration, not server attestation)
- Requested level/floor: complex / xhigh; effective effort: xhigh
- Effort increases: 0; increase reason: none
- Original start: 1791852226.3248289 Unix seconds
- Whole-review allowance: 7200 seconds; provider elapsed: 606.611 seconds
- Continuations: none; new provider thread
- Confirmed severities: CRITICAL 0, IMPORTANT 2, MINOR 0
- Evaluated verdict/grade/risk: CONCERN / 7 out of 10 / Medium

## Concise Result

- Successful empty native catalogues fail to reconcile closed rows, priorities, Manual sets
  and Automatic cues. IMPORTANT finding R1 is confirmed against source and tests.
- The priority-pinning suite requires pending OSC files whose production writer was removed,
  uses an invalid reason fixture and drops the explicit helper. IMPORTANT R2 is confirmed.
- The provider supplied five scores and coverage for all nine phases and 83 exact product targets.
- This was source inspection only. No builds/tests, native/UI/device actions or source changes ran.
- Native salience, navigation, readability, recovery, relaunch and active-cue UI remain unverified.

## Preserved Raw Skill Report and Evaluation

# Codex Review Raw Report

## Metadata

- Status: SUCCESS
- Mode: file
- Profile: code-review
- Thread ID: 01a132b7-2977-71c1-a93f-d428f0a3aef1
- Codex exit status: 0
- Triage policy: include-all-confirmed
- Evidence directory: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-final-corrected-20261013-20261013_024346
- Raw JSONL: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-final-corrected-20261013-20261013_024346/events.jsonl
- Standard error: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-final-corrected-20261013-20261013_024346/stderr.log
- Final message: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-final-corrected-20261013-20261013_024346/final-message.md
- Command record: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-final-corrected-20261013-20261013_024346/command.json
- Requested model: sol
- Configured model: gpt-5.6-sol
- Review level: complex
- Effort floor: xhigh
- Effective effort: xhigh
- Effort increase reason: none
- Previous report: none
- Original start (Unix seconds): 1791852226.3248289
- Whole-review allowance (seconds): 7200.0
- Elapsed (seconds): 606.611
- Execution policy: {"allowance": 7200.0, "base_branch": null, "context": "tavs-final-corrected-20261013", "effort": "xhigh", "elapsed": 606.6106472015381, "explicit_budget": 7200, "floor": "xhigh", "level": "complex", "mode": "file", "model": "sol", "previous_report": null, "profile": "code-review", "reason": "", "resume_thread": null, "started_at": 1791852226.3248289, "status": "SUCCESS", "thread_id": "01a132b7-2977-71c1-a93f-d428f0a3aef1", "upgrades": 0, "workdir": "/Users/cs/local/code/apps/terminal-agent-visual-signals"}
- Model and effort describe requested configuration, not server attestation.

## Raw Codex Output

# Review Report

## Metadata

- **Reviewer:** Codex, Sol
- **Review type:** code
- **Mode:** FILES
- **Review mode:** gatekeeping
- **Tier:** standard
- **Date:** 2026-10-13
- **Target:** `71e0f602de76e500f967852a6bf8534bb39a33cf`
- **Implementation base:** `e113fb8117260c5c0f13f3ae73c1b4552ef7776d`
- **Scope:** 83 restricted product files, 14,109 insertions and 1,677 deletions
- **Method:** complete pinned source inspection through `git show 71e0f60:<path>`
- **Execution:** no builds, tests, hooks, installs, native actions, or writes
- **Triage policy:** include all confirmed findings
- **Context limitation:** `AGENTS.md` and `CLAUDE.md` do not exist in the pinned commit. The supplied project instructions were used, but cannot be verified as commit artifacts.
- **Worktree isolation:** current HEAD is `12bacee`; no mutable worktree source was used as evidence.

## Executive Summary

===EXECUTIVE_SUMMARY===
Overall grade: 7/10
Risk level: Medium
Summary: A successful zero-surface native refresh is misclassified as catalogue failure, which retains closed working sets, cues, rows, and priority records instead of reconciling confirmed closure. The target also contains an integration suite that still requires the removed pending-OSC replay mechanism, so that suite cannot validate the final implementation as written.
===END_EXECUTIVE_SUMMARY===

## Rubric Scores

===SCORE_CARD===
| Dimension | Score | Evidence |
|---|---:|---|
| Correctness | 6/10 | Identity, recovery ordering, cue acknowledgement, and rendering composition are implemented, but confirmed empty catalogues take the failure path and violate closure semantics. |
| Security | 8/10 | Hook bodies are discarded, typed records reject unknown fields and controls, native requests use structured JSON, and device writes revalidate descriptors and policy. No exploitable security defect was confirmed. |
| Maintainability | 6/10 | Concerns are separated into catalogue, reducer, focus, renderer, and recovery modules, but lifecycle behavior is split across large state modules and obsolete replay assumptions remain in tests. |
| Test Coverage | 6/10 | Extensive deterministic identity, PTY, reducer, revision, and recovery tests exist. The empty-catalogue behavior is asserted incorrectly, one integration suite targets removed behavior, and physical UI cases remain unverified. |
| Performance | 7/10 | Native requests are bounded, device writes retain the 100 ms deadline, and recovery fanout is concurrent. No runtime measurements were permitted, and native timing acceptance remains empirical. |
| Overall | 7/10 | Nearest-integer mean of 6, 8, 6, 6, and 7 is 7. No CRITICAL cap applies. |
===END_SCORE_CARD===

## Verdict

**Verdict:** CONCERN
**Confidence:** high for the source findings; native and visual acceptance was not evaluated.

Derivation: every score is at least 5, with Correctness, Maintainability, and Test Coverage below 7.

## Findings

===ISSUES===
### CRITICAL

None

### IMPORTANT

1. **[R1] [src/macos/TAVSApp/Sources/TAVSApp/sessions-model.swift:217] Successful empty catalogues are treated as unavailable**
   - **Situation:** `SessionsModel.refresh()` receives `.success([])` from a completed native enumeration.
   - **Behavior:** Only nonempty successful results reach `acceptCatalogue()` at lines 208–216. An empty success enters the generic success case at lines 217–220, marks the catalogue unavailable, preserves the old rows and priorities, and calls `focus.catalogueUnavailable()` through lines 242–245. That focus path explicitly retains the captured set and automatic cues at `focus-controller.swift:219–225`. The normal confirmed-closure path at `focus-controller.swift:177–180`, which intersects the working set and ends Manual when empty, is never reached.
   - **Evidence:** `GhosttyCatalog.enumerate()` returns the decoded surface array after a successful request at `ghostty-catalog.swift:89–92`; an empty decoded array is not an identity or permission failure. `sessions-model-tests.swift:70–83` currently encodes preservation after `.success([])`, so the incorrect classification is deliberate in the tests.
   - **Impact:** Closing the last Ghostty surface while the Ghostty process remains available leaves stale rows and priority records, keeps Manual logically active instead of ending it, and retains Automatic cue history rather than resolving closed destinations. Non-Off polling also continues against a working set that is known to be empty.
   - **Suggestion:** Treat a successful empty array as a valid current catalogue, distinct from a failed native refresh.
   - **Fix:** Route every `.success(let rows)` through `acceptCatalogue(rows, coverage:)`, including `rows.isEmpty`. Publish a zero-surface status, reconcile selection and priorities, and let `FocusController.acceptCatalogue([])` end Manual and clear invalid cue destinations.
   - **Verification:** Add cases proving that `.success([])` clears rows and persisted priorities, ends Manual after its last member closes, clears invalid Automatic cues while leaving Automatic armed as specified, and still treats `.failure(...)` as stale/unavailable.

2. **[R2] [tests/integration/priority-pinning.bats:3] The priority-pinning suite tests a removed replay mechanism**
   - **Situation:** The final target replaces opaque pending OSC replay with typed current-state composition.
   - **Behavior:** The test declares pending-cache replay as its contract at lines 3–18 and requires `.osc` files at lines 89, 114–115, and 131. Production explicitly makes `_tavs_mute_buffer_open` and `_tavs_mute_buffer_close` no-ops at `src/core/mute-gate.sh:152–154`. The test also writes `REASON="test"` at line 41, while production accepts only the enumerated reasons at `src/core/mute-gate.sh:108`, and its `env -i` dispatch at lines 64–69 omits `TAVS_TEST_HELPER_BIN`.
   - **Evidence:** No pinned production writer creates a pending OSC file. `visual-recovery.swift:545–561` only removes legacy pending files during reconciliation. Therefore the three behavior tests have no source path capable of satisfying their file assertions.
   - **Impact:** If this file is included, its behavior cases fail against the final target. If it is omitted, aggregate shell-test totals do not cover the named priority suite. The file also encourages reintroduction of historical OSC replay, which the specification explicitly forbids.
   - **Suggestion:** Replace the historical replay contract with current typed-intent and managed-composition assertions.
   - **Fix:** Use owned PTYs and the source-built helper to verify independent per-TTY intent records, newest-delivery behavior, global-rule precedence, and the absence of pending OSC files.
   - **Verification:** Run the rewritten file through `tests/run-isolated.sh` with an explicit source-built `TAVS_TEST_HELPER_BIN`, then include it in the audited complete shell-suite invocation.

### MINOR

None
===END_ISSUES===

## Phase Coverage

| Phase | Inspected source and tests | Requirement assessment | Acceptance gap |
|---:|---|---|---|
| 1 | Process identity, bounded runner, Ghostty catalogue, plist, catalogue and process tests | Source implements PID-generation identity, opaque native IDs, structured JXA input, bounded enumeration, and confirmed Go To | Native navigation across tabs, windows, Spaces, and permission states remains unverified |
| 2 | Sessions model/view, application wiring, menu controls, priority tests | **Concern:** R1 prevents confirmed zero-surface reconciliation | Resizable window, selection behavior, relaunch UI, and exact physical navigation remain unverified |
| 3 | Isolated runner, pytest fixtures, shell isolation tests | Private roots are propagated, but R2 leaves a stale integration contract | No test commands were executed in this review |
| 4 | Organizer intake, hook adapters, typed visual state, background routing, Codex installer, hook tests | Source uses body-free typed records, verified producer generations, and completion-only Codex boundaries | Installed provider delivery was not observed |
| 5 | Persistent suspension readers/writers, policy, scheduler, CLI status/lock, shellrc parity tests | Source consistently disables restrictions on suspended or unavailable state while retaining saved rules | Relaunch behavior was not exercised |
| 6 | Managed entry, writer ordering, recovery, broadcaster, CLI recovery, PTY-oriented tests | Source persists suspension before recovery, rechecks policy under the output lock, retains the 100 ms deadline, and reports partial failures | Actual hung-device, hung-GUI, and native recovery behavior remains unverified |
| 7 | Renderer, preview controller, menu recovery, scheduler release, sync packaging, preview tests | Source uses background-only effects, current intent recomposition, revision invalidation, and no historical replay | Two-second visible salience, focus preservation, and readability remain unverified |
| 8 | Manual focus controller, sessions UI, renderer and manual-focus tests | Captured set and browsing state are separated; **R1** breaks last-target closure when the successful catalogue is empty | Native dimming, readability, closed-window behavior, sleep/wake, and relaunch remain unverified |
| 9 | Attention reducer, automatic focus, sessions navigation acknowledgement, hook-observation tests | Baseline, permission coalescing, completion IDs, captured acknowledgement, priority changes, and source validation are present; **R1** retains cues on a successful zero-surface result | Active-cue UI and native automatic salience remain unverified |

## Grouped Exact Target Coverage

All 83 changed product targets from the restricted diff were inspected.

- **Adapters and entry points:** `tavs`, `src/agents/claude/hooks.json`,
  `src/agents/claude/trigger.sh`, `src/agents/codex/trigger.sh`,
  `src/install/install-codex.sh`, `src/shell/tavs-shellrc.sh`.
- **CLI:** `cmd-help.sh`, `cmd-lock.sh`, `cmd-recover.sh`, `cmd-status.sh`,
  `cmd-sync.sh`.
- **Shell core:** `backgrounds.sh`, `dir-icon.sh`, `idle-worker-background.sh`,
  `lock-state-lib.sh`, `mute-gate.sh`, `organizer-state.sh`,
  `terminal-osc-sequences.sh`, `title-management.sh`, `trigger.sh`,
  `visual-restrictions-state.sh`.
- **macOS production:** `Info.plist`, `Broadcaster.swift`, `MenuContent.swift`,
  `MuteState.swift`, `PauseVisual.swift`, `ProcessRunner.swift`, `Scheduler.swift`,
  `TAVSApp.swift`, `attention-state.swift`, `focus-controller.swift`,
  `ghostty-catalog.swift`, `managed-output-entry.swift`, `organizer-intake.swift`,
  `process-identity.swift`, `sessions-model.swift`, `sessions-view.swift`,
  `terminal-render.swift`, `terminal-renderer.swift`, `terminal-visual-state.swift`,
  `visual-recovery.swift`, `visual-restriction-policy.swift`,
  `visual-restrictions-state.swift`.
- **Swift tests:** broadcaster, mute, scheduler, attention, focus, catalogue,
  managed-output, organizer-intake, process-identity, process-runner, sessions,
  terminal-render, renderer, visual-state, recovery, policy, restriction-state,
  and both mock files listed in the request.
- **Shell and Python tests:** `tests/conftest.py`, the shared restriction fixture,
  all eight listed integration Bats files, `tests/run-isolated.sh`,
  both listed pytest files, and all seven listed unit Bats files.
- **Adjacent context:** pinned SPEC, PLAN, API reference, `Package.swift`,
  `hooks/hooks.json`, and `.gitignore`.

## Forced Falsification

| Potential problem | Result | Source basis |
|---|---|---|
| PID, TTY, or application reuse can transfer identity or priority | Technically falsified for nonempty catalogues | `ProcessGeneration`, device checks, native IDs, exact priority keys, and reuse tests bind state to the current lifetime |
| A queued restrictive write can repaint after recovery | Technically falsified | Marker revision capture, before-open publication, in-lock policy checks, and deadline checks reject replaced recovery revisions |
| Go To can acknowledge cues that arrive during navigation | Technically falsified | `SessionsModel.goTo()` snapshots cue identities before dispatch and acknowledges only that set after verified success |
| Synthetic idle or delayed restoration can create or resolve cues | Technically falsified | The reducer accepts only supported permission/completion events; synthetic renders preserve the original delivery and do not publish meaningful observations |
| A successful zero-surface refresh is handled as confirmed closure | **Confirmed defect R1** | `sessions-model.swift:217–220` routes it to stale/unavailable handling |
| The priority-pinning suite validates current typed composition | **Confirmed defect R2** | The suite still requires pending replay files whose production writers were removed |

## Limitations

- This was a source-only review. No builds, tests, linters, hooks, helper processes, or product scripts ran.
- Native Ghostty navigation, visible salience, readability, focus preservation, relaunch, and recovery were not empirically verified.
- Historical test totals were not treated as current evidence.
- The pinned commit lacks `AGENTS.md` and `CLAUDE.md`; their supplied contents could not be verified at the target.
- No production deployment can be inferred from source or test declarations.

## Recommendations

===RECOMMENDATIONS===
1. Correct successful empty-catalogue handling and add closure regressions for priorities, Manual, and Automatic.
2. Replace `priority-pinning.bats` with typed per-TTY intent and no-replay tests, then include it in the complete isolated shell suite.
3. After both corrections, rerun the deterministic suites and complete dedicated native acceptance for zero-surface closure, active-cue UI, navigation, salience, readability, relaunch, and recovery.
===END_RECOMMENDATIONS===

## Summary

The target needs correction before final acceptance because confirmed closure is not reconciled when native enumeration succeeds with zero surfaces. The recovery, rendering, identity, and automatic-cue paths otherwise have direct source coverage, but the obsolete pending-replay suite and outstanding native acceptance prevent an approval verdict.


# Evaluated Findings and Action Plan

## Evaluation Summary

- Wrapper status: SUCCESS
- Reviewed product target: 71e0f60, compared with e113fb8
- Raw findings: 2
- Confirmed: 2
- Upgraded: 0
- Downgraded: 0
- Dismissed: 0
- Evaluated severities: CRITICAL 0; IMPORTANT 2; MINOR 0
- Review-standards mapping: HIGH 2; no CRITICAL, MEDIUM or LOW findings
- Risk: Medium
- Overall grade: 7/10
- Derived verdict: CONCERN
- Selection policy: include-all-confirmed
- Verification method: pinned source, callers and test assertions only; no runtime reproduction

Scores were supplied independently by the provider before its verdict and retained after source
verification: Correctness 6, Security 8, Maintainability 6, Test Coverage 6, Performance 7.
Their sum is 33; 33 / 5 is 6.6, which rounds to 7. No CRITICAL cap applies. Every score is at
least 5 and three are below 7, so the review-standards verdict is CONCERN. Two IMPORTANT findings
without a CRITICAL finding mechanically yield Medium risk. FILES mode has no PR readiness claim.

## [CONFIRMED] R1: Successful empty catalogue bypasses confirmed closure

- Raw finding: SessionsModel treats `.success([])` as unavailable and retains closed surfaces.
- Evidence checked: pinned sessions-model.swift:200-249; focus-controller.swift:172-232;
  ghostty-catalog.swift:89-102,130-178,193-274; sessions-model-tests.swift:70-99;
  attention-state.swift:32-35; SPEC.md:113-114,418,447-451.
- Situation: Ghostty remains a valid application instance after its last native surface closes;
  enumeration succeeds with an empty surface array.
- Behavior: JXA snapshot legitimately returns an empty array when its window loop has zero
  iterations. The decoder accepts this array and returns success. Permission, unavailable native
  access, malformed response and stale application have separate error paths. SessionsModel's
  nonempty success guard instead routes the empty result through markCoverageStale(), which
  retains rows, priorities, the Manual working set and Automatic cues. Its normal accepted
  catalogue path would prune priorities and selection, end an empty Manual set, and pass empty
  coverage to the occurrence reducer while leaving Automatic armed.
- Impact: Known closed destinations remain displayed and logically active; persisted priorities
  are not reconciled and non-Off polling continues. This is a lifecycle/UI defect, not demonstrated
  unsafe navigation or inheritance of a closed surface's priority by a new opaque native ID.
- Evaluation: CONFIRMED. The existing preservation test establishes the behavior but does not
  falsify the defect. Native exceptions already have explicit failure results; treating an
  otherwise valid empty success as unavailable lacks source evidence.
- Severity: IMPORTANT, mapped to HIGH under review-standards.
- Fix/Suggestion: Accept all successful arrays, including empty ones, and reserve stale state
  for actual native failures. Reuse the existing acceptCatalogue path rather than adding a new
  lifecycle mechanism.
- Verification: Correct the empty-success model regression and add closure coverage for stored
  priority/selection, the last Manual member, and Automatic cues with the mode still armed.
  Keep failed-native refresh retention as a separate regression. No tests ran in this review.

## [CONFIRMED] R2: Priority-pinning tests require removed pending OSC replay

- Raw finding: tests/integration/priority-pinning.bats tests obsolete pending-file behavior.
- Evidence checked: pinned priority-pinning.bats:3-18,25-46,61-69,78-141;
  mute-gate.sh:102-108,152-154; visual-recovery.swift:545-561; a pinned production search of
  pending OSC references under src/, tavs and hooks/.
- Situation: The suite dispatches current trigger.sh while expecting historical opaque OSC
  cache files and replay semantics.
- Behavior: The three behavior cases require `.osc` files at lines 89,114-115,131, yet the former
  pending-buffer entry points now only unset their buffer and no production source creates those
  files. Recovery's legacy pending path only unlinks old files. The fixture's REASON=test is also
  rejected by the current allowed-reason reader, and env -i drops TAVS_TEST_HELPER_BIN before
  calling the trigger. These problems are independent of the fixture's fourth isolation check.
- Impact: The suite cannot validate the target's current behavior and its behavior assertions
  cannot succeed as written. A selected passing test total does not prove this suite passed.
  Its documented replay contract conflicts with the specified no-historical-replay behavior.
- Evaluation: CONFIRMED by source inspection. The absence of a current pending writer and the
  explicit file assertions establish the contradiction without executing the suite.
- Severity: IMPORTANT, mapped to HIGH under review-standards.
- Fix/Suggestion: Retarget the suite to current per-TTY typed intent and managed composition,
  using the existing owned-PTY/source-built-helper patterns. Pass the explicit helper through
  the child environment, use valid policy fixtures, and assert that historical pending OSC
  files are not produced. Do not restore replay merely to satisfy these tests.
- Verification: Run the updated suite through the existing isolated runner with an explicit
  source-built helper, then include it in the audited shell-suite selection. No tests ran here.

## Curated Action Plan

1. Route a successful zero-surface catalogue through ordinary reconciliation and add the Manual,
   Automatic and priority/selection closure regressions.
2. Replace the priority-pinning suite's removed replay expectations with current typed-intent,
   per-TTY isolation, precedence and no-replay assertions using existing test fixtures.
3. Have the implementation owner run the affected isolated checks. Native salience, navigation,
   recovery, relaunch and active-cue UI still require their separate empirical acceptance.

## Dismissed and Deferred

No raw findings were dismissed or deferred by this noninteractive wrapper. The provider's
falsified hypotheses remain in the unmodified raw output; they are not independent claims of
physical acceptance or absolute defect absence. Historical test totals were not independently
recomputed. No source, build, test, native/UI/device or real-home runtime mutation occurred.

## Scope and Execution Notes

The provider supplied all nine PLAN phase rows and grouped coverage of all 83 product targets.
Its recorded commands show pinned Git/source inspection and no product execution, source edits,
peer-report reads or fingerprints. The canonical command used file-mode profile exec in a fresh
thread, not the built-in review subcommand. AGENTS.md and CLAUDE.md were absent from the target
commit; supplied project instructions remained context rather than verified tracked artifacts.
The wrapper likewise verified findings against git show 71e0f60:path, so later documentation
commits did not change the product source reviewed. No continuation or lighter review is
recommended for this cross-phase concurrency and recovery scope.
