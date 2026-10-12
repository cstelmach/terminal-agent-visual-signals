# Phase 1 implementation log

> Parent: PROGRESS.md
> Scope: Phase 1 completed implementation and verification log
> Consolidated: 2026-10-12

### Phase 1: Native catalogue and exact navigation COMPLETE, 2026-10-12 09:09 CEST

Added typed Ghostty surface/native process identities, bounded native/config subprocesses,
serialized refresh/coalescing and exact PID/ID/TTY Go To with focus confirmation. Readonly
metadata uses public proc_pidinfo and rejects missing/exiting generations. Request values are
JSON arguments, not interpolated source. Missing/ambiguous TTY rows remain explicit and
unactionable. Added Automation purpose text; UI remains the next phase.

Verification: 21 new tests; baseline 203/203 and final 224/224 full Swift tests passed in
2.104 seconds. The red run failed on missing implementation. Release build, compile-only
native script and plist validation passed. Foundation-only probes verified scalar/void-call
and truthy Objective-C nil behavior without Ghostty events. Existing 100 ms writer is unchanged.
Logs/build: `/tmp/tavs-phase1-20261012T075910/`.

Independent Codex review: SUCCESS, CONCERN 7/10 on the original target. Both confirmed findings
were source-verified and resolved: adapter-level permission/nil coverage and vanished-target
classification. The latter reproduced two assertion failures before its correction. Final
regressions passed; no new provider approval is claimed. Durable findings/dispositions:
[Phase 1 review](reviews/PHASE1-CODEX-REVIEW.md).

Decisions: PID-bound ScriptingBridge, exact objectWithID lookup, opaque generation/terminal key,
separate typed metadata and existing runner/mocks. A 1 MiB stdout cap reports oversized data
explicitly; raise only if a measured native catalogue requires it. No dependency or live setting
change, input, terminal paint, shell suite or personal-session interruption occurred.

Observation for Phase 2: disabled scripting can yield empty native collections. Do not infer
confirmed closure or discard retained priorities merely from an empty/unavailable refresh.
Real native/TCC/Spaces behavior remains unverified Phase 2 work, not a completed SPEC acceptance.

Next: Phase 2: Sessions window and retained surface priorities. Goal remains active.

### Phase 1 verification in progress: 2026-10-12 08:30 CEST

Baseline passed 203/203 Swift tests. New tests first failed on missing implementation
(`red-swift.log`). After implementing the native catalogue/process primitives, an XCTest
callback compile error was corrected without weakening assertions. The latest full run passed
222/222 tests in 2.280 seconds (`green-swift-3.log`); the release build passed in 7.58 seconds.
Logs and the owned scratch build are under `/tmp/tavs-phase1-20261012T075910/`.

Compile-only osacompile validated the native script and plutil validated Info.plist. A separate
Foundation-only JXA probe confirmed scalar unwrapping and zero-argument Objective-C invocation.
It sent no Ghostty AppleEvents. Process metadata uses public proc_pidinfo generation/device/group
fields; native requests use a PID-bound ScriptingBridge proxy and exact objectWithID lookup.
TTY ambiguity and current focus are checked before navigation; post-request generation and
focus confirmation determine success. Real Ghostty/TCC/Space behavior remains Phase 2 work.

Independent canonical Codex file/partial review is running in agent review_phase1_codex;
its CLI session is 42628 and intended report is `/tmp/codex-review-tavs-phase1-20261012.md`.
No review verdict exists yet. Phase 1 remains In Progress pending source-verified findings.
Do not rerun passing suites without a new edit/failure; inspect the live review handle first.

### Phase 1 started: 2026-10-12 07:59 CEST

The native Codex goal is active. Re-read SPEC/PLAN/PROGRESS/GOAL and selected Phase 1.
Worktree starts clean at a23acdc. Backed up touched existing files under
`/tmp/tavs-phase1-20261012T075910/backup/`. The phase covers bounded subprocesses, verified
process generations, native catalogue parsing and exact navigation; it performs no live
AppleEvents, terminal painting, installs or shell regression runs. Tests precede implementation.
Goal continuations authorize the next phase after this phase's verified checkpoint.

Continue with the [current progress log](PROGRESS.md).
