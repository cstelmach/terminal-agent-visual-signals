# Phase 4 Independent Codex Review

## Metadata

- Wrapper status: SUCCESS.
- Reviewer: delegated Codex CLI, requested sol, configured gpt-5.6-sol.
- Target: current uncommitted Phase 4 in terminal-agent-visual-signals on main.
- Mode: session. Depth: full/xhigh. Calibration tier: standard.
- Focus: native lifetime adoption/late deliveries; observations versus synthetic
  intent; JSON/privacy; known helper capability query; honest coverage; bounded
  off-main native intake; adapters/core/installer integration.
- Raw skill report: [codex-review-session-terminal-agent-visual-signals-tavs-phase4-20261012-20261012_124109.md](/private/tmp/codex-review-session-terminal-agent-visual-signals-tavs-phase4-20261012-20261012_124109.md).
- Evidence directory: /private/tmp/codex-review-artifacts-session-terminal-agent-visual-signals-tavs-phase4-20261012-20261012_124109.
- Thread: 01a12fb3-ba3e-7cc1-a6cb-9310720816aa.
- Requested/effective effort: xhigh/xhigh. Increases: none. Continuations: none.
- Delegated elapsed: 551.641 seconds. Total elapsed through evaluation: 752.350 seconds.
- Whole-review allowance: 7200 seconds. No explicit shorter cap.
- Counts: CRITICAL 0, IMPORTANT 3, MINOR 0. All three confirmed.
- Review was repository read-only. Only /tmp prompt/report/evidence paths were written.
- Prior memory was used only for historical phase orientation; current scope and
  findings were checked against freshly retrieved SPEC, PLAN and source.

## Summary

- Native version-path provider identification can reject the installed Claude layout.
- Decoded session/thread identifiers can carry terminal controls into title/state paths.
- Malformed latest observation/intent files prevent fresh real records from recovering coverage.
- No tests, builds, hooks, UI, installation, live process inventories or working terminal
  access were performed. Native rendering remains unverified.

## Rubric Scores

| Dimension | Score | Evidence |
|---|---:|---|
| Correctness | 6/10 | Verified provider path and malformed-record publication gaps. |
| Security | 6/10 | Decoded control bytes reach OSC and line-oriented state. |
| Maintainability | 8/10 | Separate typed store/intake and established integration points. |
| Test Coverage | 6/10 | Existing tests omit the three confirmed regression cases. |
| Performance | 7/10 | Visual reads are off-main and lock wait is bounded; no runtime timing probe. |

## Verdict

CONCERN. Risk: Medium. Overall grade: 7/10. Confidence: high for source paths;
provider proc_pidpath behavior is conditional on the actual native executable path,
which was not sampled from a live process.


## Evaluation Summary

- Raw findings: 3 IMPORTANT.
- Confirmed: 3. Upgraded: 0. Downgraded: 0. Dismissed: 0.
- Evaluated risk: Medium. Overall grade: 7/10. Verdict: CONCERN.
- Scores remain correctness 6, security 6, maintainability 8, test coverage 6,
  performance 7. Mean 6.6 rounds to 7. No CRITICAL cap applies.
- Selection policy: include-all-confirmed. No source changes or test runs were made.

## Evaluated Findings

### [R1] CONFIRMED: organizer-intake.swift:184: Provider verification rejects native version paths

- Raw finding: Exact executable basename matching rejects supported provider layouts.
- Situation: `src/macos/TAVSApp/Sources/TAVSApp/organizer-intake.swift:172-193` walks
  the producer ancestry after checking generation, device and foreground family.
- Behavior: Lines 184-185 grant verified provider status only when the executable's
  last component equals `claude` or `codex`. Falling through returns a foreground
  owner with `verified=false` at line 193.
- Evidence checked: Read the complete producer function. Read-only launcher resolution
  shows `/Users/cs/.local/bin/claude` targets
  `/Users/cs/.local/share/claude/versions/2.1.295`; `file` identifies this target as
  a native arm64 Mach-O executable. Its basename is `2.1.295`, which cannot pass
  the equality test. No live process was inspected or launched to sample proc_pidpath.
  Thus the precise demonstrated condition is proc_pidpath returning this installed
  native executable path. The Codex JS launcher was resolved too, but this is not
  evidence that the spawned native Codex binary has an unsupported basename.
- Impact: Correctly correlated native Claude installations can remain unverified.
  `terminal-visual-state.swift:167` displays that coverage and lines 233-234 reject
  attention eligibility. This is foundational Phase 4 provider verification; later
  automatic focus itself is outside this review.
- Severity: IMPORTANT (review-standards HIGH).
- Smallest fix: Recognize the supported resolved native provider executable path,
  retaining all existing generation/device/foreground-family checks. Do not simply
  accept arbitrary version-shaped basenames or trust a provider label by itself.
- Verification: Add a small injectable executable-path lookup and test the installed
  native Claude version layout, exact `claude`/`codex` names, the supported Codex
  native target, and an unrelated foreground executable. No need for live hooks.

### [R2] CONFIRMED: organizer-intake.swift:39: Decoded IDs can inject terminal controls

- Raw finding: session_id and thread-id permit BEL, ESC, newline and carriage return.
- Situation: `organizer-intake.swift:37-42` rejects NUL only. Lines 48 and 54 export
  the decoded identifier as TAVS_SESSION_ID; output is NUL-framed at lines 91-95/138-139.
- Behavior: NUL framing safely transports other controls, rather than stripping them.
  `src/core/organizer-state.sh:32-44` stores/exports the value.
  `src/core/title-management.sh:405-408` inserts its first eight characters in
  the default SESSION_ID token; line 526 writes the composed value inside OSC 0
  without sanitizing the finished title. A decoded `\u0007\u001b[2J` identifier
  therefore terminates OSC and sends an erase-display CSI command.
- Evidence checked: Read decoder, shell intake, both adapters, title composition and
  output. `src/core/session-icon.sh:60-62` also uses the first eight characters as a
  line-oriented identity key, written at lines 271-274 and by identity-registry.sh.
  `organizer-intake-tests.swift:6-12` explicitly accepts quote/backslash identifiers,
  but has no control-character identifier check. The pre-change Claude adapter
  used sed on JSON source text; escaped JSON controls were not decoded into bytes.
  This new decoding path therefore adds a concrete reachable byte transformation.
- Impact: Malformed provider metadata can corrupt terminal display and line-based
  identity state. This is a boundary validation defect, not a claim that prompt or
  tool content can modify a provider-generated ID on its own.
- Severity: IMPORTANT (review-standards HIGH).
- Smallest fix: Validate only identifier fields with an ASCII identifier allowlist
  before export. Preserve legitimate escaped filesystem metadata separately.
- Verification: Decoder tests for BEL, ESC, LF, CR and identity separators, for both
  providers; owned-output test proving rejected IDs cannot emit injected controls
  or introduce identity-state lines. Any shell test must use tests/run-isolated.sh
  with an explicit source-built helper.

### [R3] CONFIRMED: terminal-visual-state.swift:78: Damaged latest files wedge publication

- Raw finding: Invalid current records prevent a newer valid publication.
- Situation: `terminal-visual-state.swift:74-84` reads/validates the current observation
  before replacement. `:121-131` does the same for the current intent.
- Behavior: `read` throws on malformed JSON or unknown keys, and validate throws on
  invalid schema/content. Neither current-record path catches these failures, so
  every valid subsequent publication stops before the atomic write.
- Evidence checked: Complete publishObservation/publishIntent and read/write functions.
  `terminal-visual-state-tests.swift:300-321` checks that damaged records are hidden;
  it never follows corruption with a new observation write.
  `:323-331` proves independent ordinary intent can survive corrupt observation,
  but does not cover replacing the corrupt observation or a corrupt current intent.
- Impact: A single damaged latest record makes that TTY's corresponding coverage
  unavailable until manual cleanup; fresh real hook deliveries do not restore it.
- Severity: IMPORTANT (review-standards HIGH).
- Smallest fix: Under the existing per-TTY lock, allow a freshly validated real
  publication to replace a malformed regular latest record. Keep synthetic updates,
  filesystem errors, unsafe paths and corrupt adoption bindings fail-closed.
  The recommendation does not authorize re-adopting old records from damaged bindings.
- Verification: Corrupt each regular latest JSON file, publish a newer real record,
  and assert restored coverage. Assert synthetic publication still refuses corruption.
  Preserve symlink/directory rejection and late-delivery/lifetime regression cases.

## Action Plan

1. Repair provider executable verification and add native-layout fixtures.
2. Reject unsafe identifiers at JSON intake and add decoder/output regressions.
3. Permit fresh real publications to recover damaged latest JSON and add recovery tests.

## Deferred and Dismissed

No raw finding was dismissed or downgraded. The delegated falsification section
correctly treats synthetic observations and muted intent loss as false alarms:
organizer-state.sh:55 returns before observation for synthetic work, and
terminal-osc-sequences.sh:103 publishes intent before emit_osc.
Phases 5-9, full native rendering, real hooks, installation and live terminal
behavior were outside this pass. No broad test suite was launched by this reviewer.


## Future Review Advice

Keep standard calibration for this slice. A future review limited to these three
repairs can use partial/high with the same integration paths and regression tests;
this invocation completed the requested full review without reducing its depth.
