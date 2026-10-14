# Codex Review Raw Report

## Metadata

- Status: SUCCESS
- Mode: file
- Profile: code-review
- Thread ID: 01a139e4-228b-7f60-9397-82e2ddefa8be
- Codex exit status: 0
- Triage policy: include-all-confirmed
- Evidence directory: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-ordinary-shell-delivery-20261014_121013
- Raw JSONL: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-ordinary-shell-delivery-20261014_121013/events.jsonl
- Standard error: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-ordinary-shell-delivery-20261014_121013/stderr.log
- Final message: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-ordinary-shell-delivery-20261014_121013/final-message.md
- Command record: /private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-ordinary-shell-delivery-20261014_121013/command.json
- Requested model: sol
- Configured model: gpt-5.6-sol
- Review level: full
- Effort floor: xhigh
- Effective effort: xhigh
- Effort increase reason: none
- Previous report: /private/tmp/codex-review-files-terminal-agent-visual-signals-tavs-visual-state-recovery-20261014_115422.md
- Original start (Unix seconds): 1791970687.162588
- Whole-review allowance (seconds): 7200.0
- Elapsed (seconds): 2899.409
- Execution policy: {"allowance": 7200.0, "base_branch": null, "context": "tavs-ordinary-shell-delivery", "effort": "xhigh", "elapsed": 2899.409405231476, "explicit_budget": null, "floor": "xhigh", "level": "full", "mode": "file", "model": "sol", "previous_report": "/private/tmp/codex-review-files-terminal-agent-visual-signals-tavs-visual-state-recovery-20261014_115422.md", "profile": "code-review", "reason": "", "resume_thread": null, "started_at": 1791970687.162588, "status": "SUCCESS", "thread_id": "01a139e4-228b-7f60-9397-82e2ddefa8be", "upgrades": 0, "workdir": "/Users/cs/local/code/apps/terminal-agent-visual-signals"}
- Model and effort describe requested configuration, not server attestation.

## Raw Codex Output

===EXECUTIVE_SUMMARY===
Overall grade: 4/10
Risk level: High
Summary: All 66 named files were inspected at clean commit `7ecfba2`; no target file was omitted. The portable backend disables all advertised Linux ordinary signaling, which is a release-blocking compatibility failure. Four additional defects affect runtime-directory trust, concurrent state persistence, installer result reporting, and test isolation.

Potential-mechanism falsification: Backend switching and raw-output fallback were falsified by the fixed helper selection path. Linux compatibility, secure pre-existing runtime roots, atomic shared-state updates, and installer failure propagation were disproved by the cited paths.

Scope coverage: No tests, builds, applications, AppleEvents, containers, real-home queries, or terminal sessions were run, as required. Native Ghostty rendering, navigation, Spaces behavior, readability, and Linux runtime acceptance remain unverified limitations, not inferred defects. Prior memory was used only for orientation; every current claim below was reverified against the checkout.
===END_EXECUTIVE_SUMMARY===

===ISSUES===
### CRITICAL

1. **[src/core/portable_helper.py:77](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/core/portable_helper.py:77)** Linux ordinary signaling has no usable backend
   - Evidence: When the native capability pair is unavailable, [helper-selection.sh:63](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/core/helper-selection.sh:63) probes the portable helper. The helper rejects every non-Darwin request at lines 77–79, so selection fails. Even removing that guard is insufficient: Linux inspection adds `linuxScope` at [portable_process_identity.py:113](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/core/portable_process_identity.py:113), while [portable_records.py:45](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/core/portable_records.py:45) rejects that extra generation field and line 61 excludes Linux `/dev/pts/N` targets. The hook then suppresses the render failure at [trigger.sh:430](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/core/trigger.sh:430) and exits successfully without OSC output.
   - Impact: On the advertised Linux platform, a system without the macOS native companion cannot emit processing, permission, completion, idle, or reset signals. This removes the product's core behavior while reporting hook success.
   - Fix: Define and validate a versioned Linux generation record, admit `/dev/pts/N` targets, connect Linux process and TTY ownership through the portable renderer, and advertise the portable capability only after that complete path works.
   - Verification: On a real Linux host with no native helper, invoke the Claude and Codex adapters through an owned PTY and assert exact OSC bytes, current typed intent, bounded completion, and rejection after PID or PTY reuse.

### IMPORTANT

1. **[src/core/mute-gate.sh:25](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/core/mute-gate.sh:25)** The predictable runtime root accepts attacker-owned directories and symlinks
   - Evidence: `_tavs_resolve_runtime_dir` checks only whether `/tmp/tavs-$UID` is a directory, following symlinks, and validates neither owner nor mode before using `lock.state`, `pending`, and `active-ttys`. The standalone path repeats this behavior at [tavs-shellrc.sh:99](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/shell/tavs-shellrc.sh:99). The Python writer likewise creates or accepts the lock parent and checks only that it is a directory at [portable_device_writer.py:38](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/core/portable_device_writer.py:38).
   - Impact: After reboot or before first use, another local user can pre-create the predictable runtime path as a symlink or writable directory. TAVS then reads attacker-controlled lock state and writes terminal identifiers and organizer records there, enabling visual-signal suppression, state tampering, and metadata disclosure.
   - Fix: Reject symlinked runtime components and require the runtime root to be owned by the effective user with mode `0700`. Open and retain a verified directory descriptor for subsequent operations. Prefer a platform-provided per-user runtime directory where available.
   - Verification: Pre-create the default root as a symlink, foreign-owned directory, and mode-0777 directory. Every shell and Python entry point must refuse it without reading state, registering a TTY, or writing terminal bytes.

2. **[src/install/install-gemini.sh:184](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/install/install-gemini.sh:184)** Installer failures are followed by a false success result
   - Evidence: The apply subprocess status is ignored, and line 186 unconditionally prints that Gemini signals were installed. The unified installer has the same defect: [install.sh:161](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/install/install.sh:161) ignores preview failure status, while [install.sh:186](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/install/install.sh:186) reports success after an unchecked apply call. Later successful `echo` commands make the scripts exit zero.
   - Impact: Invalid JSON, missing Python, permission errors, or failed atomic replacement can leave configuration unchanged while `tavs install gemini` reports success and returns success.
   - Fix: Wrap both preview and apply calls in explicit status checks, return nonzero immediately on failure, and print success only after the apply subprocess exits zero.
   - Verification: Put a stub `python3` returning status 43 first in `PATH`. Both installers must return nonzero, preserve the settings file, and omit every success message.

3. **[src/core/session-state.sh:96](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/core/session-state.sh:96)** Concurrent hooks lose other terminals' state
   - Evidence: `write_session_state` reads the shared database, removes one TTY row, appends its replacement, and renames a per-process temporary file at lines 96–101 without serialization. Two processes can read the same original file and then overwrite each other's complete result. `write_session_colors` repeats the same pattern at lines 174–179.
   - Impact: Concurrent sessions can lose another terminal's state, timer PID, or stored colors. A later hook may fail to stop the displaced idle worker, bypass state-priority protection, or retain an unnecessary background process until its next transition or timeout.
   - Fix: Store state per TTY, or serialize each shared read-modify-replace transaction with a bounded lock. Preserve ordering for competing updates to the same TTY.
   - Verification: Pause two writers after both have read the original database, then release them concurrently. The completed state must contain both TTY updates and their timer PIDs.

4. **[tests/integration/lock-gate.bats:63](/Users/cs/local/code/apps/terminal-agent-visual-signals/tests/integration/lock-gate.bats:63)** The lock-gate test escapes the isolation wrapper and asserts removed behavior
   - Evidence: `env -i` forwards only `HOME`, `PATH`, `TTY_DEVICE`, and `TAVS_RUNTIME_DIR`. It drops `TAVS_TEST_ROOT`, `TAVS_TEST_HELPER_BIN`, `TAVS_TMP_DIR`, and XDG roots. Consequently, [session-state.sh:17](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/core/session-state.sh:17) falls back to shared `/tmp/tavs`, and helper selection may probe the installed application. The test also expects opaque pending files at [lock-gate.bats:76](/Users/cs/local/code/apps/terminal-agent-visual-signals/tests/integration/lock-gate.bats:76), although current compatibility functions only discard pending buffers at [mute-gate.sh:152](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/core/mute-gate.sh:152).
   - Impact: Running this test can overwrite live shared session state, depend on the workstation's installed helper, and fail for reasons unrelated to the lock predicate. It therefore provides neither safe isolation nor reliable regression coverage.
   - Fix: Forward every private root and the explicitly built helper, use an owned PTY, and replace pending-file assertions with current typed managed-output assertions.
   - Verification: Run the repaired test only through `tests/run-isolated.sh`; assert every created path remains under `TAVS_TEST_ROOT`, the real application is never invoked, and no opaque pending file is created.

### MINOR
None
===END_ISSUES===

===SCORE_CARD===
| Dimension | Score | Evidence |
|---|---:|---|
| Correctness | 4/10 | Linux core signaling is unavailable; installers misreport failure; shared state loses concurrent updates. |
| Security | 5/10 | Typed records and bounded writers reject many unsafe inputs, but the default shared runtime root lacks ownership, mode, and symlink validation. |
| Maintainability | 6/10 | Modules are separated, but duplicated policy readers, duplicated installers, and legacy shared databases permit divergent behavior. |
| Test Coverage | 5/10 | Extensive macOS and parser coverage exists, but Linux is explicitly rejected, installer failures and shared-state concurrency are uncovered, and lock-gate integration is unsafe and stale. |
| Performance | 6/10 | Device operations retain bounded deadlines, but shared-state races can retain idle workers and the portable path launches several helper processes per hook. |
| Overall | 4/10 | Rounded mean is 5/10; the confirmed CRITICAL finding caps the result at 4/10. |
===END_SCORE_CARD===

===RECOMMENDATIONS===
1. Restore end-to-end Linux ordinary signaling before release, including Linux generation records and `/dev/pts` ownership.
2. Secure the shared runtime root against pre-creation and symlink attacks across shell and Python paths.
3. Before merge, serialize session-state updates, propagate installer failures, and repair the lock-gate isolation harness.
===END_RECOMMENDATIONS===

## Wrapper evaluation of partition 3

Reviewed source: commit `7ecfba2`. No tests, builds, installers, applications, native queries,
containers, real-home reads or terminal operations were run. All verification below is source-only.

### [CONFIRMED] portable_helper.py:77: Existing Linux ordinary output has no selected backend

- Raw finding: The portable helper rejects Linux and ordinary signaling suppresses its final
  render failure, eliminating the advertised platform's core OSC behavior.
- Evidence checked: `portable_helper.py:67-79`; `helper-selection.sh:47-74`;
  `portable_process_identity.py:88-117`; `portable_records.py:44-69`;
  `organizer-state.sh:21-60`, `63-88`, `160-174`; `terminal-osc-sequences.sh:83-90`;
  `trigger.sh:200-230`, `430-431`; `README.md:1085-1087`.
- Evaluation: Linux cannot return the portable capability marker, so normal selection has
  neither a native nor portable backend. Ordinary colors/title/palette are queued for typed
  rendering and that rendering has no backend; the final trigger converts failure to success.
  The Linux identity parser alone cannot restore output: its generation shape and `/dev/pts/N`
  targets are rejected by the current record schema. The README still promises Linux and Python
  metadata when the macOS companion is absent. This is an existing ordinary-signal compatibility
  regression, separate from the intended macOS/Ghostty-only organizer and native acceptance gaps.
- Severity: CRITICAL (core behavior is removed for an advertised platform).
- Fix: Complete a versioned Linux ordinary generation/TTY proof and rendering path while retaining
  failure isolation, typed serialization, recovery policy checks and the 100 ms deadline. Advertise
  its capability only when that path works; do not substitute raw OSC fallback after a failed
  selected operation or call the broken compatibility boundary merely unsupported organizer scope.
- Verification: Linux kernel, owned foreground PTYs, no native app, Claude/Codex adapter inputs,
  actual OSC bytes, retained intent, bounded failure and process/PTY reuse rejection. Parser mocks
  or changing `sys.platform` cannot establish kernel TTY/process behavior.

### [CONFIRMED] mute-gate.sh:25: Runtime-root trust is unchecked

- Raw finding: Shell and Python paths accept a pre-created symlinked or foreign/writable runtime
  root without owner/mode validation.
- Evidence checked: `mute-gate.sh:20-30`, `143-146`; `tavs-shellrc.sh:98-104`;
  `portable_helper.py:38-49`; `portable_device_writer.py:35-49`;
  `portable_record_io.py:17-58`, `88-107`;
  `portable_ownership.py:47-74`; `portable_policy.py:20-37`.
- Evaluation: Shell `-d` follows root symlinks and registry writes occur before helper trust
  checks. Production portable `_roots` does not validate ownership/mode; its private-root check
  is conditional on test-root environment. Record directory handles reject a final symlink and
  compare inode identity, but check neither root ownership nor permissions, and ancestor symlinks
  are not ruled out. Lock-file owner/mode checks protect that final node only. Another local user
  can pre-create the predictable root with writable contents, supply readable fake lock state or
  inspect TTY registry names; fresh suspension still prevents those locks while suspended.
  The checked mechanism establishes tampering and registry metadata exposure, not terminal input
  injection or a claim that every victim-owned mode-0600 record body is readable by the attacker.
- Severity: IMPORTANT.
- Fix: Reject linked/untrusted runtime roots and require the effective-user-owned private mode
  before shell reads/registration or Python output. Reuse held directory handles where current
  record code already has them. A targeted root check is required; a new governance system is not.
- Verification: Owned symlink and mode-0777 fixtures must be rejected before file reads/writes;
  a mocked or separately controlled ownership case discriminates foreign ownership. Include a
  legitimate existing mode-0700 root and ensure refusal never chmods/overwrites foreign paths.

### [CONFIRMED] install-gemini.sh:184: Failed apply can report success

- Raw finding: Preview/apply subprocess errors are not propagated by Gemini/unified installers.
- Evidence checked: `install-gemini.sh:1-28`, `163-193`; `install.sh:1-22`, `160-191`;
  `cmd-install.sh:60-68`; `tavs:15`, `119-121`.
- Evaluation: The standalone scripts do not enable errexit and rely on selected output-string
  matches instead of actual exit status. Apply failure is followed by successful echo commands.
  `tavs` launches a new Bash script through `cmd-install.sh:68`, so its own errexit does not protect
  these child commands. Unlike the macOS bundle replacement subclaim in partition 1, false success
  is supported for this child-script path. A preview error lacking the expected text can also
  continue into confirmation/apply.
- Severity: IMPORTANT.
- Fix: Check preview and apply statuses explicitly, stop nonzero on failure and print success
  only after successful apply; preserve existing backup/atomic settings replacement behavior.
- Verification: An owned settings path and stub Python process fails with status 43 without the
  string `Python Error:`. Exercise preview and confirmed apply separately; no success message or
  settings alteration may occur on failure. No real account settings need to be touched.

### [CONFIRMED] session-state.sh:96: Atomic replacement does not serialize shared updates

- Raw finding: Concurrent whole-file read/modify/rename writers can lose another TTY's state.
- Evidence checked: `session-state.sh:28-32`, `75-101`, `105-127`, `157-179`, `221-228`;
  `trigger.sh:214-230`. State/color writes and color removal lack transaction serialization.
- Evaluation: Distinct process temporary names prevent partial-file exposure but not lost
  updates: two writers can each read old state, append different TTY rows and replace the file;
  the last rename drops the first update. Existing priority/timer readers consume these rows,
  so missing rows can bypass priority protection or lose a worker PID. This is ordinary state,
  separate from the correctly separated per-TTY organizer intent records.
- Severity: IMPORTANT.
- Fix: Use one bounded shared transaction lock or per-TTY storage across every mutation,
  including clear operations. Preserve existing read formats if choosing the smaller lock fix.
- Verification: Barrier two different-TTY writers after both read the same starting database;
  ensure both results/timer PIDs survive, then cover competing same-TTY updates and color clear
  versus another terminal's color write. A merely high-volume non-barrier test can pass by luck.

### [CONFIRMED] lock-gate.bats:63: env-i drops private roots and expects obsolete pending output

- Raw finding: The integration fixture escapes the wrapper's isolation and asserts opaque
  pending behavior removed from current implementation.
- Evidence checked: `tests/run-isolated.sh:9-23`; `lock-gate.bats:11-23`, `62-84`, `94-125`,
  `128-133`; `session-state.sh:16-31`; `trigger.sh:42-67`, `214-230`;
  `helper-selection.sh:12-17`; `mute-gate.sh:152-154`.
- Evaluation: Nested `env -i` discards `TAVS_TMP_DIR`, test root, temporary/XDG roots and the
  explicit helper. The trigger sources session state at startup and ordinary processing records
  to the fallback shared `/tmp/tavs/state`, even if managed output fails for its regular fake TTY.
  Its whole-file replacement can interact with real state. Helper selection can probe the real
  installed app. Assertions demand pending files that are no longer produced, and release cases
  demand output to a regular file the typed writer correctly refuses. The fixture is unsafe and
  no longer discriminates current managed lock policy.
- Severity: IMPORTANT.
- Fix: Forward all wrapper roots and the source-built helper; retain test directories below
  `TAVS_TEST_ROOT`; use an owned PTY/producer or a focused typed helper fixture; replace historical
  buffer assertions with actual current policy/intent/output semantics and honest exit results.
- Verification: Run only after repair through `tests/run-isolated.sh`, establish that every
  created state path stays private, and assert no installed-app candidate is invoked. Do not run
  the existing fixture to reproduce the known isolation leak against workstation defaults.

## Evaluated partition 3 summary

- Raw findings: 5. Confirmed: 5. Upgraded/downgraded/dismissed: 0.
- Evaluated severity: CRITICAL 1, IMPORTANT 4, MINOR 0.
- Dimension scores retained: Correctness 4, Security 5, Maintainability 6, Test Coverage 5,
  Performance 6. Rounded mean 5; CRITICAL cap yields 4/10.
- Risk: High. Calibration verdict: VETO (correctness below 5).
- Noninteractive selection: include all five confirmed corrections with the narrower trust
  impact and exact fixture/child-installer paths described above.
- All 66 named files were covered by the delegated review. Runtime and native acceptance,
  plus historical first-paint/EPERM/fresh-render timeout causes, remain unverified.
