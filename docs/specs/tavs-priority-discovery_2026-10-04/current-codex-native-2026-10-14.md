# Codex Review Raw Report

## Metadata

- Status: SUCCESS
- Mode: file
- Profile: code-review
- Thread ID: 01a139c6-bb39-7a73-8f47-516517ceb218
- Codex exit status: 0
- Triage policy: include-all-confirmed
- Evidence directory: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-native-sessions-focus-20261014_113807
- Raw JSONL: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-native-sessions-focus-20261014_113807/events.jsonl
- Standard error: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-native-sessions-focus-20261014_113807/stderr.log
- Final message: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-native-sessions-focus-20261014_113807/final-message.md
- Command record: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-native-sessions-focus-20261014_113807/command.json
- Requested model: sol
- Configured model: gpt-5.6-sol
- Review level: full
- Effort floor: xhigh
- Effective effort: xhigh
- Effort increase reason: none
- Previous report: none
- Original start (Unix seconds): 1791970687.162588
- Whole-review allowance (seconds): 7200.0
- Elapsed (seconds): 960.196
- Execution policy: {"allowance": 7200.0, "base_branch": null, "context": "tavs-native-sessions-focus", "effort": "xhigh", "elapsed": 960.1958241462708, "explicit_budget": null, "floor": "xhigh", "level": "full", "mode": "file", "model": "sol", "previous_report": null, "profile": "code-review", "reason": "", "resume_thread": null, "started_at": 1791970687.162588, "status": "SUCCESS", "thread_id": "01a139c6-bb39-7a73-8f47-516517ceb218", "upgrades": 0, "workdir": "/Users/cs/local/code/apps/terminal-agent-visual-signals"}
- Model and effort describe requested configuration, not server attestation.

## Raw Codex Output

The enforced read-only sandbox rejected the requested `/tmp` report write. The complete report follows; the worktree remains clean.

===EXECUTIVE_SUMMARY===
Overall grade: 7/10
Risk level: Medium
Summary: Two IMPORTANT defects are supported by the source: preview and focus effects do not freshly revalidate the native Ghostty surface-to-TTY mapping before output, and the installer can remove the installed app, ignore a failed replacement copy, and still report success. All 20 named paths were inspected with no omissions, together with connected process runner, terminal state, recovery, renderer, broadcaster, and scheduler paths. Five failure mechanisms were examined: stale native targeting and failed installation replacement were confirmed; duplicate Go To acknowledgement, automatic cue rearming from polling, and stale lease renewal were falsified by the ID/TTY checks, occurrence bookkeeping, revision checks, and six-second lifetime checks.

Limitations: This was read-only inspection at commit `7ecfba229a5341adbcf02abc8a5658580e2807d9`. No builds, tests, apps, AppleEvents, real-home queries, terminal operations, or installations were run. Native rendering, navigation, readability, and Spaces behavior remain unverified acceptance limits. Linux runtime gaps and historical first-paint, EPERM, and fresh-render timeout causes were not established and are not reported as defects.
===END_EXECUTIVE_SUMMARY===

===ISSUES===
### CRITICAL
None

### IMPORTANT
1. **[src/macos/TAVSApp/Sources/TAVSApp/focus-controller.swift:67]** Effects paint from cached native rows without immediate native revalidation
   - Evidence: `SessionsModel` passes its last accepted catalogue rows into previews at `sessions-model.swift:14` and focus at `sessions-model.swift:157` and `sessions-model.swift:237`. Preview converts those rows directly with `captureTarget` at line 67; focus does likewise at `focus-controller.swift:323` and `focus-controller.swift:332`. The connected `TerminalVisualStateStore.captureTarget` at `terminal-visual-state.swift:129` verifies TTY device and process state, but `validateTarget` at `terminal-visual-state.swift:161` verifies only the Ghostty application generation unless a fresh native row is supplied. These effect paths never obtain or supply that row.
   - Impact: A close or reuse race can authorize preview or dimming output under a stale native surface identity. A reused TTY and current process lifetime could consequently be painted as though it were the closed surface.
   - Fix: Before preparing each preview or focus batch, obtain one fresh serialized catalogue snapshot and retain only rows whose application generation, terminal ID, and TTY exactly match the requested rows. Reject missing, changed, ambiguous, or timed-out mappings without painting.
   - Verification: Accept surface A on `/dev/ttys001`, keep local device and process checks valid, then make a fake fresh catalogue omit A or map it to another TTY. Assert zero writes, no active effect record, and an unavailable status. A control with only tab or window movement and unchanged ID/TTY must still paint.

2. **[src/cli/cmd-install-macos-app.sh:376]** Failed bundle replacement is ignored after removing the existing app
   - Evidence: `_install_bundle` removes `/Applications/TAVS.app` at line 373, executes unchecked `cp -R` at line 376, and prints `Installed` at line 377. The caller later prints `TAVS.app installed successfully!` at line 69 regardless of that copy result.
   - Impact: Permission failure, insufficient disk space, interruption, or partial copying can destroy the working installation, leave no valid replacement, and still return a success message.
   - Fix: Copy the signed bundle to a unique sibling staging path, check the copy and bundle validation, and replace the destination only after staging succeeds. Return nonzero on every replacement or launch failure and preserve or restore the prior bundle.
   - Verification: Inject temporary source and destination paths and force the copy operation to fail. Assert a nonzero result, no success message, and byte-identical preservation of the prior destination. Add a successful staged-replacement case.

### MINOR
3. **[src/macos/TAVSApp/Sources/TAVSApp/sessions-view.swift:50]** Automatic-focus help text omits completion triggers
   - Evidence: The view says Automatic uses observed permission episodes. The reducer also creates completion cues at `attention-state.swift:68`, including Claude `Stop` deliveries at `attention-state.swift:84` and Codex turn completions at `attention-state.swift:85`.
   - Impact: Users can see automatic dimming after a completed response even though the mode explanation only names permissions.
   - Fix: State that Automatic reacts to new verified High-priority permission and response-completion observations, while retaining the Go To acknowledgement explanation.
   - Verification: Present one Claude `Stop` and one Codex `agent-turn-complete` observation and verify the displayed explanation describes both triggers.
===END_ISSUES===

===SCORE_CARD===
| Dimension | Score | Evidence |
|---|---:|---|
| Correctness | 6/10 | Exact Go To, priority lifetime, manual capture, acknowledgement, and lease expiry are implemented, but effect output lacks fresh native revalidation and installation can falsely succeed after losing the installed app. |
| Security | 8/10 | Native requests carry JSON as data, TTY paths and process generations are validated, allowlists are enforced, and no supported injection, secret exposure, or authorization bypass was found. |
| Maintainability | 7/10 | Catalogue, model, reducer, and rendering ownership are separated, but the 626-line focus controller coordinates several synchronized state machines. |
| Test Coverage | 7/10 | Tests cover identity, priorities, occurrences, acknowledgement snapshots, preview races, lease expiry, and cleanup failures. They do not discriminate stale native mapping immediately before an effect, and the installer lacks a failure-preservation test. Tests were inspected but not run. |
| Performance | 7/10 | Catalogue work is serialized and coalesced, device writes use bounded fanout, and focus preparation is coalesced. No confirmed material performance defect was found. |
| Overall | 7/10 | The rounded mean of 6, 8, 7, 7, and 7 is 7. No CRITICAL cap applies. |
===END_SCORE_CARD===

===RECOMMENDATIONS===
1. Add fresh batched Ghostty ID-to-TTY revalidation before preview and focus preparation.
2. Make app installation a checked staged replacement that preserves the prior bundle on failure.
3. Correct the Automatic Focus explanation and add targeted regression coverage for both confirmed defects.
===END_RECOMMENDATIONS===

## Wrapper evaluation of partition 1

Reviewed source: commit `7ecfba2`. No source changes, builds, tests, native requests,
installations or real-home operations were performed.

### [CONFIRMED] focus-controller.swift:67: Effects lack fresh native mapping validation

- Raw finding: Preview/focus captures targets from accepted catalogue rows without a new
  native identity-to-TTY check before preparing output.
- Evidence checked: `sessions-model.swift:11-14`, `155-164` and `228-237`;
  `focus-controller.swift:59-94`, `315-352` and `374-395`;
  `terminal-visual-state.swift:129-136`, `151-173` and `485-497`;
  `visual-recovery.swift:592-597`; `TAVSApp.swift:200-219`.
- Evaluation: The model passes cached rows. Fresh colors do not refresh native mapping.
  Capture validates the currently inspected foreground process and device, then associates
  that result with the supplied native ID. Later descriptor/device/owner-generation checks
  protect the captured physical binding, but do not establish that Ghostty still associates
  that native ID with it. The GUI has a native snapshot closure, but it is not used by these
  paint preparation paths. The explicit SPEC immediate native revalidation contract is unmet.
  Common closures with an exited producer are protected; the raw race claim needs a surviving
  process or reuse before capture, rather than assuming every closure authorizes a new TTY.
- Severity: IMPORTANT.
- Fix: Revalidate the requested native IDs and exact TTY mappings through one serialized,
  bounded snapshot at paint preparation, before creating targets/effects; retain the in-lock
  process/device checks and reject missing/ambiguous/unavailable mappings.
- Verification: A fake native snapshot changes or removes the requested native ID while the
  local process/device checks remain valid. Assert no new effect/write; keep a moved-tab
  unchanged-ID/TTY control. This test distinguishes native authority from physical liveness.

### [CONFIRMED] cmd-install-macos-app.sh:373: Replacement can remove the working app before copy fails

- Raw finding: The installer removes the old bundle before an unchecked replacement copy and
  may report success after copy failure.
- Evidence checked: `cmd-install-macos-app.sh:55-76`, `355-382`, `384-400`;
  `tavs:15` and `106-113`.
- Evaluation: The destructive ordering is confirmed: destination removal precedes the copy,
  with no staging/backup/restore branch. A failed copy can therefore lose the prior installation.
  The separate false-success subclaim is technically falsified for the normal `tavs` entry:
  `set -euo pipefail` is active and the installer function is a direct simple command in the
  dispatcher. A nonzero copy exits that normal CLI path before its later success print.
  No evidence was established that the ordinary CLI suppresses errexit around this call.
- Severity: IMPORTANT for loss of the prior working bundle; no false-success claim retained.
- Fix: Stage and validate a sibling replacement before retiring the destination; preserve the
  prior bundle on staging/replacement failure. Explicit return checks make the function safe
  under sourced/conditional callers as well, but that is not the demonstrated normal CLI bug.
- Verification: Inject owned source/destination paths and a failing staging-copy command;
  assert nonzero and preservation of the old destination. Also discriminate replacement failure
  from staging failure and verify successful replacement without touching `/Applications`.

### [CONFIRMED] sessions-view.swift:50: Automatic help omits completion triggers

- Raw finding: Automatic help names only permission episodes although completion cues exist.
- Evidence checked: `sessions-view.swift:49-51`; `attention-state.swift:58-86`.
- Evaluation: Claude Stop and Codex agent-turn-complete create completion keys, while the text
  says Automatic uses observed permission episodes. This is a concrete product explanation
  mismatch with D13; navigation acknowledgement text remains accurate.
- Severity: MINOR.
- Fix: Name new verified High-priority permission and response-completion observations and
  keep the distinction between response completion and task success.
- Verification: Inspect the rendered explanation for both trigger types in dedicated UI
  acceptance. A string-mirroring unit test would add little discrimination.

## Evaluated partition 1 summary

- Raw findings: 3. Confirmed: 3 with installer false-success subclaim falsified above.
- Evaluated severity counts: CRITICAL 0, IMPORTANT 2, MINOR 1.
- Independent dimension scores retained: Correctness 6, Security 8, Maintainability 7,
  Test Coverage 7, Performance 7. Rounded mean 7; no CRITICAL cap.
- Risk: Medium. Calibration verdict: CONCERN (all scores at least 5; correctness below 7).
- Noninteractive selection: include all confirmed corrections, with the narrowed installer
  mechanism. No host-only finding was added.
- Full requested review remains in progress across partitions 2 and 3. This partition does
  not establish native visual acceptance, Linux compatibility, or historical timeout causes.

Timing clarification for finding 1: obtain the fresh serialized native mapping after potentially slow configured-color preparation and immediately before target capture/fanout. Native request work stays outside the unchanged 100 ms device budget; existing in-lock process/device validation remains necessary. A snapshot before slow preparation alone leaves the stated race window.
