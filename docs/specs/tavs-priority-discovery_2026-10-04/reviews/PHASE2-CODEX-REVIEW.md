Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0

This report predates the test-root alias correction found during staged launch acceptance.
That correction and its red/green regression are recorded in [PROGRESS](../PROGRESS.md).
The original review and evaluated scores below are retained without a new approval claim.

# Codex Review Raw Report

## Metadata

- Status: SUCCESS
- Mode: file
- Profile: code-review
- Thread ID: 01a12f16-131d-74c1-a8bb-4dca78464c1c
- Codex exit status: 0
- Triage policy: include-all-confirmed
- Evidence directory: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-phase2-sessions-20261012_094857
- Raw JSONL: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-phase2-sessions-20261012_094857/events.jsonl
- Standard error: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-phase2-sessions-20261012_094857/stderr.log
- Final message: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-phase2-sessions-20261012_094857/final-message.md
- Command record: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-phase2-sessions-20261012_094857/command.json
- Requested model: sol
- Configured model: gpt-5.6-sol
- Review level: partial
- Effort floor: high
- Effective effort: high
- Effort increase reason: none
- Previous report: none
- Original start (Unix seconds): 1791791337.583099
- Whole-review allowance (seconds): 3600.0
- Elapsed (seconds): 260.243
- Execution policy: {"allowance": 3600.0, "base_branch": null, "context": "tavs-phase2-sessions", "effort": "high", "elapsed": 260.2430651187897, "explicit_budget": null, "floor": "high", "level": "partial", "mode": "file", "model": "sol", "previous_report": null, "profile": "code-review", "reason": "", "resume_thread": null, "started_at": 1791791337.583099, "status": "SUCCESS", "thread_id": "01a12f16-131d-74c1-a8bb-4dca78464c1c", "upgrades": 0, "workdir": "/Users/cs/local/code/apps/terminal-agent-visual-signals"}
- Model and effort describe requested configuration, not server attestation.

## Raw Codex Output

===EXECUTIVE_SUMMARY===
Overall grade: 7/10
Risk level: Medium
Summary: One IMPORTANT correctness defect survives review: a successful empty catalogue preserves closed surfaces and their priorities instead of reconciling them. Selection isolation, navigation validation, timer ownership, launch rejection, and native allowlisting were technically supported by the reviewed source. Live native UI acceptance was not executed under the read-only boundary.
===END_EXECUTIVE_SUMMARY===

===ISSUES===
### CRITICAL
None

### IMPORTANT
1. **[src/macos/TAVSApp/Sources/TAVSApp/sessions-model.swift:106]** Successful empty refresh is misclassified as catalogue failure
   - Evidence: `GhosttyCatalog` returns `.success([])` after successful enumeration and application-generation revalidation. `SessionsModel.refresh()` handles only nonempty success at lines 98-105; empty success enters the generic branch at lines 106-108, leaving `surfaces`, `selection`, and persisted priorities unchanged. The test at `sessions-model-tests.swift:69-79` explicitly codifies this behavior.
   - Impact: Closing the final Ghostty surface leaves a stale row and priority record, violating confirmed-closure reconciliation and the requirement that priorities survive only for the current native surface lifetime.
   - Fix: Handle every `.success(let rows)` as an authoritative snapshot, including an empty array. Replace `surfaces`, intersect selection, update refresh status, and atomically save priorities filtered against the resulting ID set.
   - Verification: Replace the empty-success expectation with a test asserting zero rows, empty selection, Normal priority for the closed ID, and a reloaded priority file without that ID. Keep failed-refresh assertions separate and verify they preserve the last-known rows and file bytes.

### MINOR
None
===END_ISSUES===

===SCORE_CARD===
| Dimension | Score | Evidence |
|---|---:|---|
| Correctness | 6/10 | Core sorting, navigation, write ordering, and isolation paths are supported, but `sessions-model.swift:106-108` violates the required all-surfaces-closed lifecycle. |
| Security | 9/10 | Native IDs are JSON data, exact full-generation allowlisting is checked at `ghostty-catalog.swift:84-88`, and navigation revalidates TTY and generation. No supported attack path was found. |
| Maintainability | 8/10 | The model, view, catalogue, and isolated launch responsibilities remain small and separated. The empty-success special case introduces the principal semantic inconsistency. |
| Test Coverage | 6/10 | Priority, sorting, save failure, timer, mapping, launch-root, and allowlist paths have targeted tests, but `sessions-model-tests.swift:69-79` asserts the incorrect closure behavior. |
| Performance | 8/10 | Refresh uses a separate two-second timer, bounded off-main native requests, and one serialized follow-up request. No concrete resource or concurrency defect survived review. |
| Overall | 7/10 | Rounded mean of 7.4; no CRITICAL cap applies. |
===END_SCORE_CARD===

===RECOMMENDATIONS===
1. Treat an empty successful catalogue as an authoritative zero-surface snapshot and reconcile persisted priorities.
2. Split the current empty-and-failed refresh test so empty success clears state while genuine failure preserves it.
3. After correction, complete the pending dedicated-surface UI acceptance for window behavior, multiselection, and exact native Go To.
===END_RECOMMENDATIONS===

Not checked: live Ghostty navigation, window presentation, and visual acceptance remain unexecuted. Risk: static review cannot establish actual macOS focus behavior.

## Evaluated Review

- Wrapper status: SUCCESS. This is authentic execution plus evaluated source review.
- Review type: code; file/partial; standard tier; noninteractive.
- Source baseline: `338c1c2`; current uncommitted Phase 2 changes, including untracked targets.
- Findings: 1 raw, 0 CONFIRMED, 0 UPGRADED, 0 DOWNGRADED, 1 DISMISSED.
- Evaluated actionable severity counts: CRITICAL 0, IMPORTANT 0, MINOR 0.
- Evaluated risk: Low. Evaluated grade: 8/10. Standards verdict: APPROVE.
- Verdict scope: the specified static code review only, not completion of live GUI acceptance.
- Selection policy: include-all-confirmed. No corrections remain in the action plan.
- No branch readiness verdict is assigned for file mode.

### Exact Targets and Focus

1. `src/macos/TAVSApp/Sources/TAVSApp/sessions-model.swift`
2. `src/macos/TAVSApp/Sources/TAVSApp/sessions-view.swift`
3. `src/macos/TAVSApp/Sources/TAVSApp/TAVSApp.swift`
4. `src/macos/TAVSApp/Sources/TAVSApp/MenuContent.swift`
5. `src/macos/TAVSApp/Sources/TAVSApp/ghostty-catalog.swift`
6. `src/macos/TAVSApp/Tests/TAVSAppTests/sessions-model-tests.swift`
7. `src/macos/TAVSApp/Tests/TAVSAppTests/ghostty-catalog-tests.swift`

Only requested concerns were reviewed: priority persistence/reconciliation and atomic
save correctness; separate selection/navigation; timer/main-thread lifecycle; and
isolated test entry, storage and native-target scope. No independent exploration
report or other reviewer report was read. This does not re-review all Phase 1 code.

### [R1] [DISMISSED] Empty success does not establish confirmed closure

- Situation: `sessions-model.swift:98-108`; current regression at
  `sessions-model-tests.swift:69-83`; native return path at
  `ghostty-catalog.swift:64-69,103-116,190-209,217-243`.
- Raw finding: Every `.success([])` was treated as an authoritative empty roster;
  retaining previous rows and priorities was classified IMPORTANT, with a proposed
  correction to clear and persist the zero-surface snapshot.
- Behavior verified: The existing model does retain old rows, selection and High
  priority/file bytes, including across restart. It marks the catalogue unavailable
  and blocks navigation and priority changes while doing so.
- Raw impact claim: The final closed native surface supposedly leaves stale state
  instead of reconciling a confirmed closure.
- Technical falsification: The native result lacks affirmative access or completeness
  evidence. App-generation equality proves which app answered, not that an empty
  collection describes all surviving surfaces. Native collection reads and the
  resulting JSON do not provide a separate scripting-enabled/authoritative-empty
  marker. Thus the raw finding's premise is not established by this adapter contract.
- Fresh external evidence: Official upstream Ghostty accessors `scriptWindows` and
  `terminals` return empty collections when scripting is disabled; the enabling check
  uses `config.macosAppleScript`. This supports a successful-empty ambiguity, not a
  claim about the installed build's exact revision. See the
  [official Ghostty source](https://github.com/ghostty-org/ghostty/blob/main/macos/Sources/Features/AppleScript/AppDelegate%2BAppleScript.swift)
  and its [raw source](https://raw.githubusercontent.com/ghostty-org/ghostty/main/macos/Sources/Features/AppleScript/AppDelegate%2BAppleScript.swift),
  independently retrieved during evaluation on 2026-10-12.
- Controlled reproduction: The current production JXA script produces the identical
  `{"surfaces":[],"focused":false}` response for a successful zero-window collection.
  The pure fake gives it no information to distinguish zero-window causes. This
  reproduction has no ObjC bridge and sends no AppleEvents.
- Requirement checked afresh: PLAN Phase 2 requires reconciling confirmed closed
  bindings while failed/unavailable coverage preserves last-known state. SPEC lines
  111-114 require valid surface lifetime, not deleting priorities on uncertain access.
  A nonempty validated roster already reconciles missing bindings in the current
  model; unavailable emptiness receives explicit status and disabled controls.
- Evaluation: DISMISSED. This is a technical inference error, not dismissal based
  on implementation intent or the parent's preferred outcome. Automatically clearing
  priorities on this ambiguous result can discard valid retained state.
- Fix disposition: Do not apply the raw clear-on-empty proposal. No replacement
  architecture, capability protocol or new control mechanism is requested here.
- Residual limit: The reviewer did not prove installed Ghostty build/source
  correspondence or exercise disabled scripting live. Actual all-surfaces-closed
  display and capability behavior remain part of dedicated native acceptance.

### Recomputed Scores and Outcomes

| Dimension | Raw | Evaluated | Evaluation evidence |
|---|---:|---:|---|
| Correctness | 6/10 | 7/10 | Removed the unsupported empty-success penalty; persistence, closure-on-valid-roster, save ordering and guarded navigation are supported. Live lifecycle behavior remains unverified. |
| Security | 9/10 | 9/10 | Exact generation/ID allowlist and JSON data isolation are present; no supported escape or native navigation path outside the allowed target set was found. |
| Maintainability | 8/10 | 8/10 | Model, view, catalogue and isolated launch remain bounded and separately readable. |
| Test Coverage | 6/10 | 7/10 | The empty-result test protects an ambiguous-access case; restart, sorting, movement, closure, failed save, timers, invalid roots and allowlisting have meaningful source tests. Live/app-entry acceptance was not executed here. |
| Performance | 8/10 | 8/10 | Independent timer, main-queue callbacks and serialized off-main catalogue requests are supported by current production paths. |

Raw mean: `(6 + 9 + 8 + 6 + 8) / 5 = 7.4`, rounded grade 7/10.
Evaluated mean: `(7 + 9 + 8 + 7 + 8) / 5 = 7.8`, rounded grade 8/10.
No CRITICAL cap applies. Risk changes from Medium to Low after R1 dismissal.
All evaluated dimensions are at least 7, so standards verdict is APPROVE.
Scores are source-review judgments, not proof of live GUI or native focus behavior.

### Source Checks

- `SessionsModel.save` encodes first, writes with `.atomic`, then publishes the new
  priority dictionary. Failed writes leave the old dictionary; malformed storage is
  preserved and edits blocked rather than overwritten.
- Priority keys contain the full application generation plus native terminal ID.
  Sorting compares priority rank and original native offset. Tab moves retain ID,
  while new application generation or terminal IDs default to Normal.
- A nonempty successful snapshot intersects selection and prunes stored priorities
  to its known IDs. Failed/uncertain catalogue coverage retains state and disables
  `setPriority` and `goTo`; this is visible in the view controls.
- Selection is only a Set binding. Row selection, Clear Selection and priority
  changes do not call navigation. Only the per-row Go To button invokes `goTo`.
- Sessions owns a distinct TimerScheduler, schedules on `.main` at two seconds,
  guards duplicate `opened` calls and cancels that owner in `closed`. The concrete
  catalogue completion paths dispatch to `.main`; fixture completion runs inline
  with the UI caller. No concrete off-main production publication was established.
- Any one Sessions test environment flag enters validation before normal TAVS app
  construction. Missing/invalid root/fixture/targets throws and exits instead of
  falling through to production. Valid isolated mode instantiates its own app and
  delegate, with no Scheduler, Settings scene or login-registration delegate.
- Isolated storage is rooted in a resolved temporary subdirectory. Fixture mode
  uses local JSON and simulated navigation with an explicit UI label.
- Dedicated native mode passes complete `GhosttySurfaceID` values as an allowlist.
  Foreign IDs are rejected before native work. Script request IDs are restricted to
  the current generation and output rows filtered again by the complete ID set.
- Source tests cover 11 Sessions cases and 12 catalogue cases. This count is an
  inventory, not proof of execution. The parent-reported 233/236 runs were not
  independently re-executed by this reviewer.

### Isolated Evaluation Evidence

Files in the runner evidence directory:

- `empty-catalog-check.swift`: unchanged SessionsModel source plus local protocol/
  surface stubs, fixture URLs and assert checks. Native methods are fatal-error
  stubs and were never called; timers are no-op stubs.
- `empty-catalog-check.log`: confirmed retained row=1, selection=1, priority=High,
  unchanged stored bytes, blocked navigation, and retained old priority on restart.
  The log's word "closed" refers to the hypothetical raw finding's fixture scenario;
  it is not evidence of an observed native closure.
- `empty-adapter-check.js` and its log: unmodified production script, zero-count
  collection fake, identical empty result for the two asserted collection causes.

Both assert checks passed. They ran from /tmp with injected fixture storage. Swift
module cache was also explicitly under this evidence directory. They did not run
project tests, start app UI, read personal application state or send native events.

### Action Plan and Deferred Acceptance

No confirmed code correction is selected. Preserve the conservative empty/unavailable
behavior. Continue already-planned dedicated-surface UI acceptance when the computer
and tool access permit it. CUA denial and locked-Mac reports are host/tool limitations,
not product findings and not evidence that GUI acceptance passed.

No project edits, stage operations or commits were performed. No second review,
continuation, retry, engine substitution or host-only replacement was used. A future
review confined to a small model regression can use quick mode; partial/high was
appropriate for these seven interacting source/test files.

### Authentic Execution Outcome

- Canonical `run_codex_review.py` completed successfully with exit 0.
- Resolved prefix: `codex -p code-review -m gpt-5.6-sol -s read-only -a never`,
  high reasoning effort, `review_model=gpt-5.6-sol`, `exec --json`.
- Requested engine: Sol. Requested/effective effort: high. Increases: none.
  Model configuration is launch evidence, not server attestation.
- Thread: `01a12f16-131d-74c1-a8bb-4dca78464c1c`, uniquely captured from thread.started.
- JSONL: 80 valid events, one turn.completed, zero turn.failed/error events.
- Artifact bytes: prompt 9729, command 10296, events 227628, stderr 394, final 3594.
- Elapsed: 260.243 s. Original start: 1791791337.583099 Unix seconds.
  Whole-review allowance: 3600 s. No shorter outer watchdog was imposed.
- Stderr contained the existing nonfatal humanizer plugin metadata warning. It did
  not invalidate the completed delegated result and was not repaired in this review.

### Limits

No project Swift suite, build, actual application entry, GUI, Ghostty native
navigation, Automation permission, disabled-scripting case, personal settings or
session bodies were executed/read by this reviewer. Live acceptance and installed
Ghostty correspondence remain unverified. Repository meta-thinking capture was not
invoked because canonical reviewer instructions forbid repository writes.
