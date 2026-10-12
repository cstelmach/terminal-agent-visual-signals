# Codex Review Raw Report

## Metadata

- Status: SUCCESS
- Mode: session
- Profile: code-review
- Thread ID: 01a12fb3-ba3e-7cc1-a6cb-9310720816aa
- Codex exit status: 0
- Triage policy: include-all-confirmed
- Evidence directory: /private/tmp/codex-review-artifacts-session-terminal-agent-visual-signals-tavs-phase4-20261012-20261012_124109
- Raw JSONL: /private/tmp/codex-review-artifacts-session-terminal-agent-visual-signals-tavs-phase4-20261012-20261012_124109/events.jsonl
- Standard error: /private/tmp/codex-review-artifacts-session-terminal-agent-visual-signals-tavs-phase4-20261012-20261012_124109/stderr.log
- Final message: /private/tmp/codex-review-artifacts-session-terminal-agent-visual-signals-tavs-phase4-20261012-20261012_124109/final-message.md
- Command record: /private/tmp/codex-review-artifacts-session-terminal-agent-visual-signals-tavs-phase4-20261012-20261012_124109/command.json
- Requested model: sol
- Configured model: gpt-5.6-sol
- Review level: full
- Effort floor: xhigh
- Effective effort: xhigh
- Effort increase reason: none
- Previous report: none
- Original start (Unix seconds): 1791801669.686872
- Whole-review allowance (seconds): 7200.0
- Elapsed (seconds): 551.641
- Execution policy: {"allowance": 7200.0, "base_branch": null, "context": "tavs-phase4-20261012", "effort": "xhigh", "elapsed": 551.6406421661377, "explicit_budget": null, "floor": "xhigh", "level": "full", "mode": "session", "model": "sol", "previous_report": null, "profile": "code-review", "reason": "", "resume_thread": null, "started_at": 1791801669.686872, "status": "SUCCESS", "thread_id": "01a12fb3-ba3e-7cc1-a6cb-9310720816aa", "upgrades": 0, "workdir": "/Users/cs/local/code/apps/terminal-agent-visual-signals"}
- Model and effort describe requested configuration, not server attestation.

## Raw Codex Output

===EXECUTIVE_SUMMARY===
Overall grade: 7/10
Risk level: Medium
Summary: Three confirmed defects affect provider verification, terminal-safe metadata handling, and recovery from malformed records. The review was read-only; no additional tests were started, and the existing scratch area contained no final full-suite result.
===END_EXECUTIVE_SUMMARY===

===ISSUES===
### CRITICAL
None

### IMPORTANT
1. **[P1] [/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/organizer-intake.swift:184] Verify providers without relying on executable basenames**
   - Evidence: Provider verification succeeds only when `proc_pidpath` has a final component exactly equal to `claude` or `codex`. Versioned executables and renamed shims therefore become `verifiedAgent=false` even when their generation, TTY device, and foreground process group all match. This conflicts with the required generation-based correlation in [SPEC.md:138-142](docs/specs/tavs-priority-discovery_2026-10-04/SPEC.md#L138-L142).
   - Impact: Affected installations permanently show unverified observations, and those observations cannot become attention-eligible.
   - Fix: Add provider-specific executable verification that accepts supported versioned or shim layouts without weakening the generation, device, and foreground-family checks.
   - Verification: Inject the executable-path resolver and test exact names, versioned Claude paths, supported Codex wrappers, and unrelated foreground processes.

2. **[P2] [/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/organizer-intake.swift:39] Reject control characters in exported session identifiers**
   - Evidence: The decoder rejects only NUL, then exports decoded `session_id` or `thread-id` as `TAVS_SESSION_ID`. `compose_title` inserts its first eight characters into OSC 0 without sanitizing them, so a payload such as `"\u0007\u001b[2J"` terminates the title sequence and emits a terminal control command. The metadata boundary requires bounded allowlisted extraction in [SPEC.md:127-132](docs/specs/tavs-priority-discovery_2026-10-04/SPEC.md#L127-L132).
   - Impact: Malformed provider metadata can inject terminal control bytes and corrupt line-oriented identity state.
   - Fix: Apply an identifier-specific ASCII allowlist to Claude session IDs and Codex thread IDs before exporting them.
   - Verification: Add decoder and owned-PTY tests using BEL, ESC, newline, and carriage-return identifiers and assert that no injected control bytes reach the TTY or state files.

3. **[P2] [/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/terminal-visual-state.swift:78] Allow fresh records to recover malformed latest files**
   - Evidence: `publishObservation` and `publishIntent` validate the existing record before writing. If the existing JSON is malformed, has unknown keys, or has an invalid schema, validation throws and every later valid publication fails without replacing it. Malformed-record behavior is explicitly in scope at [SPEC.md:502-504](docs/specs/tavs-priority-discovery_2026-10-04/SPEC.md#L502-L504).
   - Impact: One damaged runtime file wedges observation or intent coverage for that TTY until manual deletion or runtime cleanup.
   - Fix: Under the per-TTY lock, let a fresh non-synthetic publication replace an invalid current record while keeping synthetic updates fail-closed.
   - Verification: Corrupt each latest file, publish a newer valid hook record, and assert coverage recovers; separately assert that a synthetic update still cannot repair or overwrite corruption.

### MINOR
None
===END_ISSUES===

===FALSIFICATION===
1. Control-character injection through decoded session IDs: confirmed through the decode, export, title substitution, and OSC write path.
2. Provider verification failure for alternate executable basenames: confirmed for that explicit installation condition.
3. Permanent failure after malformed latest records: confirmed because the thrown validation error precedes every replacement write.
4. Synthetic updates creating observations: false alarm. `_tavs_organizer_begin` returns immediately for synthetic work, and intent publication checks the retained delivery.
5. Muted writes losing intent: false alarm. `send_osc_bg` publishes intent before routing bytes through the mute-aware writer.
===END_FALSIFICATION===

===SCORE_CARD===
| Dimension | Score | Evidence |
|---|---:|---|
| Correctness | 6/10 | Provider verification can reject valid installations, and malformed records cannot self-recover. |
| Security | 6/10 | Decoded session identifiers can carry terminal control characters into OSC output. |
| Maintainability | 8/10 | The new store and intake modules are focused, but executable identity policy is embedded in a brittle basename comparison. |
| Test Coverage | 6/10 | Coverage includes concurrency, stale delivery, privacy sentinels, and PTYs, but omits alternate provider paths, identifier controls, and malformed-record recovery. |
| Performance | 7/10 | Record reads are off-main and locks are bounded, though each hook launches several helper processes and row coverage serializes per-TTY reads. |
| Overall | 7/10 | Rounded mean is 7/10 with no critical cap. |

Verdict: CONCERN  
Patch correctness: Incorrect  
Evidence confidence: 0.92
===END_SCORE_CARD===

===RECOMMENDATIONS===
1. Replace basename-only provider verification and add injected-path tests.
2. Validate session and thread identifiers before exporting them to shell/title code.
3. Permit fresh non-synthetic records to replace malformed current records under the existing lock.
===END_RECOMMENDATIONS===


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
