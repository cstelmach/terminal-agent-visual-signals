# Phase 6 alias composition and ended-lifetime correction

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0, completed bounded source/test correction.
Starting source baseline: `cd17388`, parent full Swift baseline 367 tests.
Parent later reoriented `d745e02` without touching the four owned files.

## First-principles boundary and verified findings

Physical identity is TTY path plus device plus continuing TTY-owner process generation.
Native identity is an additional scope/alias identity; it must not split one physical output
transaction or select an empty intent/effect namespace. One live native alias may share state
with a matching plain binding. Multiple live native IDs or conflicting verified owners remain
ambiguous and cannot authorize paint. Unknown metadata is not evidence of exit.

Read the actual evaluated reports:

- `/tmp/codex-tavs-phase6-recovery-review-20261012.md`, Codex R3 physical duplication.
- `/tmp/claude-tavs-phase6-recovery-review-20261012.md`, Claude R1 per-alias composition and R2
  proven-ended owner classification. Claude's report records degraded legacy transport; no
  execution/transport claim was upgraded here.

Verified current code and SPEC intent/ownership/recovery requirements before edits. Existing
source bound ordinary intent per alias, returned plain targets for unscoped hooks, composed only
one alias effect, and fanout treated native/owner-only aliases as distinct writes. Owner PID reuse
or affirmative process absence was reported unavailable. These findings were confirmed.

## Owned paths and scope

Only these four repository paths changed:

- `src/macos/TAVSApp/Sources/TAVSApp/terminal-visual-state.swift`
- `src/macos/TAVSApp/Sources/TAVSApp/visual-recovery.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/terminal-visual-state-tests.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/visual-recovery-tests.swift`

Backups were saved before mutation to `/tmp/tavs-phase6-alias-lifetimes-20261012/backup/`.
Parent approved the narrow equivalent-alias helper, same-physical plain cancellation for an exact
allowed native target, and the additional confirmed legacy-adoption owner-reuse correction.
No schemas, persisted control records, general adapters, history, retirement/deletion, unrelated
source, Git mutations, repository docs/META, native/Ghostty access, installs or real-runtime
operations were added. Device/metadata tests use explicit isolated roots and owned PTYs.
Dropped-intent entry, idle retry and coupled typed rendering remain separate parent slices.

## Implementation

TerminalTargetBinding.physicalTarget returns the existing binding type with nativeSurface nil.
It is a computed grouping key, not a new schema or persisted identifier.

TerminalVisualStateStore.equivalentBindingsUnlocked(for:deadline:) reads only the current TTY-owner
subtree under the caller's held stable writer lock and original deadline. It validates target
record schema/path/physical identity, rejects symlinks or unreadable metadata, skips positively
vanished aliases, and rejects multiple live native IDs. Unknown metadata remains an error.
There is no nested flock or fresh device budget.

ordinaryBackgroundUnlocked checks all validated equivalent aliases for a bound-intent copy
exactly equal to the latest per-TTY record. The latest matching bound copy survives agent exit;
an older different copy cannot override it, and an unmatched dead-producer latest record cannot
acquire authority. Changed owners/devices cannot read the old owner's subtree.

Unscoped target resolution and cachedTarget prefer one unique verified native alias, preserving
its selective lease for ordinary hooks. Exact allowed scope remains enforced; a matching plain
alias can contribute/cancel state only because its validated physical lifetime is identical.
Conflicting live native IDs or live owners fail rather than selecting an arbitrary alias.

Recovery collects current effects across validated aliases under one device lock, composes a
unique current selective lease, and cancels every matching alias effect during recovery/resume.
Current requested global policy still wins after explicit resume, with prior alias ownership
canceled first. Conflicting live selective effects fail honestly instead of choosing a color.
Existing canceled-global foreground/palette cleanup semantics remain intact.

Fanout groups by physicalTarget and emits one paint/report per physical lifetime. Cached healthy
output still runs before waiting for native discovery. A fresh native alias for an already handled
physical target is registered without duplicate paint/report. Conflicting current owners on one
TTY fail; unknown alias metadata blocks only its physical group while other healthy targets run.

validateTarget checks affirmative owner generation replacement/absence before unrelated missing
native/device metadata can mask the proof. A known different start generation or processMissing
true is vanished. Nil inspection alone, same-generation device uncertainty or generic I/O failure
remain unavailable/failed. Records are retained, including vanished records.

## Confirmed legacy-adoption owner leak and narrow remedy

After initial full green, source review found that the existing native-adoption fallback could
restore a dead producer's old intent to a newly captured changed-owner generation if native ID
and rdev matched. A new typed regression reproduced #123ABC crossing that boundary.
Parent confirmed this belongs to the same lifecycle correction.

Successful live native intent adoption now snapshots the existing bound-intent record only when
the producer's verified continuing owner matches the captured native target. Metadata publication
runs under the existing consumer lock; .max preserves the pre-existing non-device publication
body timing and is never passed by a managed device caller. Unchanged bound copies are not
rewritten. Unbound legacy fallback now requires a live producer with the exact continuing owner.
The original owner restores after producer exit through its bound copy; a changed owner cannot
inherit it despite matching native ID/rdev. The adoption/intent/effect schemas remain unchanged.

## Tests and preserved evidence

All Swift commands used tests/run-isolated.sh with explicit helper:
`/tmp/tavs-phase6-routing-20261012T165000/build/arm64-apple-macosx/debug/TAVSApp`.
Scratch: `/tmp/tavs-phase6-routing-20261012T165000/build`.
Focused filter: `TerminalVisualStateTests|VisualRecoveryTests`.
Full command: `swift test --package-path src/macos/TAVSApp --scratch-path` plus that scratch URL.

The isolated logs below retain complete build/test output:

- Expected missing helper API red, exit 1: `tavs-isolated.YD3naJ/command.log`.
- Behavioral red after the first store slice, exit 1: `tavs-isolated.uGHgQR/command.log`.
  82 tests, 16 failures including one unexpected prior nil assertion now correctly throwing
  unavailable for a conflicting replacement native ID. Other failures show duplicate reset/rule
  bytes and report items, ignored native lease, and scoped live-native ambiguity.
- Initial focused green, 82/82, exit 0: `tavs-isolated.8jnxpb/command.log`.
- Owner-end masking regression red, 1 test/3 failures, exit 1:
  `tavs-isolated.cZWlEL/command.log`.
- Expanded focused green, 85/85, exit 0: `tavs-isolated.uFEJoy/command.log`.
- Intermediate full green, 378/378, exit 0: `tavs-isolated.8NIcnF/command.log`.
- Legacy adoption changed-owner regression red, 1 test/1 failure, exit 1:
  `tavs-isolated.V6GOoW/command.log`.
- Final focused green, 86/86, exit 0: `tavs-isolated.pBMxVx/command.log`.
- Final full green, 379/379, exit 0: `tavs-isolated.uc68Lh/command.log`.

All log prefixes are
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/`.
Final focused counts: TerminalVisualState56 and VisualRecovery30. Full count is baseline367
plus 12 new tests; no tests were removed/skipped. Counts are XCTest results, not Swift Testing's
separate zero-test footer. Owned-path git diff --check passed.

Regression scenarios include differing alias-bound intents after producer exit without adoption,
held stable lock/expired original deadline, alias metadata uncertainty, native lease overlay,
recovery/resume cancellation across aliases, one physical write/report, fresh native registration
without repaint, scoped live-native ambiguity, conflicting live owners, affirmative owner exit/
reuse versus unknown metadata, and legacy-adoption same-ID/rdev changed-owner rejection.
Existing original 100ms managed writer, healthy-before-native, latest intake/synthetic, metadata
bounds, no historical title/BEL replay and generic failure retention tests remain green.

## Handoff

New public members: TerminalTargetBinding.physicalTarget and
TerminalVisualStateStore.equivalentBindingsUnlocked(for:deadline:).
Existing write, target, cachedTarget, apply, recover, record publication and schemas retain their
signatures. Key modified functions also include ordinaryBackgroundUnlocked, validateTarget,
coverage(for:), effectsUnlocked, cancelEffects, preferredTarget and fanout.

Four source/test files are stable and the shared build slot was released immediately after
final full379 green. No further worker source edits/builds will run. Parent owns docs, commits,
independent review, remaining typed rendering/entry/idle work and live acceptance. This report
completes the bounded alias/lifetime correction, not Phase 6 or the master goal.

Observed workflow for parent capture: tested the binding distinction rather than deduplication
alone; preserved compile and behavioral red; confirmed positive owner-end proof independently
of unavailable metadata; treated a full green as insufficient when source exposed a legacy
adoption path, reproduced it, obtained scope confirmation and fixed it without new schemas.
