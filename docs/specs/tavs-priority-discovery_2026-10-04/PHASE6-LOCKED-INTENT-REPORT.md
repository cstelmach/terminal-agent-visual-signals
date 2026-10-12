# Phase 6 locked intent integration

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0
Initial baseline: `43914a0`.

## Scope

Assigned repository paths only:

- `src/macos/TAVSApp/Sources/TAVSApp/terminal-visual-state.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/terminal-visual-state-tests.swift`

Current state: the bounded source/test slice is implemented and focused green. Repository
edits and builds waited for parent policy/Scheduler focused/full green and explicit slot release.
Only the two assigned paths were edited. No Git, native/UI, real runtime, shell-suite or unrelated
action was performed. Parent-owned policy/Scheduler/coordinator changes were preserved.

## Implemented bounded change

Moved the existing intent-validation/order/comparison/write body into publishIntentUnlocked.
The public locking method prevalidates as before, then calls it with UInt64.max, documented as
preserving legacy non-device publication timing. Every managed prepare caller must supply the
writer's real original deadline. No new budget, timer, lock or generic publication layer exists.

Added bindOrdinaryIntentUnlocked. After a live producer and exact continuing target are verified,
it normalizes the candidate color exactly as publication does and requires complete equality
with the current per-TTY intent. It saves that same OrdinaryBackgroundIntent schema as the single
current bound-intent.json beside the target binding's current target/effect records. Existing
bound data must parse correctly; fresh binding does not silently overwrite a corrupt record.

Restoration still reads latest per-TTY intent first. An equal validated target-local copy can
outlive the producer while the exact target and continuing owner remain valid. Unmatched new
intent cannot borrow an old dead producer's authority. Existing exact native adoption remains
supported. The local copy requires exact sibling target.json metadata as well as matching TTY/
device fields. Corrupt bound intent throws; discovery reports that file unreadable without
deriving target authority from its filename. Valid bound data creates no extra snapshot binding.

readLatest now accepts the optional original deadline and checks it after IO/validation and
after its malformed-regular-file recovery stat. The unlocked publisher passes that deadline
through all reads/write, preserves synthetic/older-intake/older-render rejection, and does not
swallow a deadline error as a merely missing observation. Existing observation/intent/effect
schemas, public publication signatures and old tests are preserved.

## Tests added before implementation

- Publish and bind while the caller holds the stable writer lock, proving no nested flock.
- Expired original deadline preserves the latest per-TTY and target-bound records.
- Synthetic old deliveries and delayed older intake cannot replace newer meaningful intent.
- Plain-shell parent binding retains exact latest intent after its child producer exits.
- Distinct native/owner bindings cannot acquire another binding's retained color.
- Dead-producer new/latest mismatches stay unbound; corrupt target-bound JSON remains reported.

All tests use explicit private roots, injected generations/devices and an owned lock file.
No user process/session, device paint, native request, UI, Git or unrelated edit is authorized.

## Exact verification evidence

The scoped command was run through the isolated runner:

```bash
TAVS_TEST_HELPER_BIN=/tmp/tavs-phase6-coordinator-20261012T152000/baseline-helper \
  tests/run-isolated.sh swift test --package-path src/macos/TAVSApp \
  --scratch-path /tmp/tavs-phase6-coordinator-20261012T152000/build \
  --filter TerminalVisualStateTests
```

- Tests-first API red: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.OtjDsw/command.log`.
  Exit 1, because publishIntentUnlocked and bindOrdinaryIntentUnlocked did not exist.
- Focused green: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.9IAQZj/command.log`.
  **48 tests, zero failures**, 0.275 seconds. No compiler warnings/errors were reported.
- git diff --check passed for the two owned files.
- Diff: 228 insertions, 39 deletions, including 127 new test lines. Most removed production
  lines are the publication body moved into its reusable unlocked entry.

Seven new tests establish held-lock nonreentrancy/stable inode, unchanged observation bytes,
original-deadline preservation of latest/local copies, synthetic and intake chronology, plain
child-producer exit into a continuing owner, exact latest mismatch refusal, distinct owner/
native binding isolation, corrupt metadata reporting and filename-only non-authorization.

No behavioral source change followed the focused green. The shared scratch was released to
parent. This focused run completed before the parent's missing coordinator class entered build
discovery; that later missing-API red is intentional and separate from the store result.

## Capture notes and remaining work

Observed workflow: current SPEC/PLAN/PROGRESS/GOAL and connected publication/read helpers were
reread; repository edits were held while another worker's suites used the shared slot; public
timing semantics were explicitly agreed; tests preceded APIs; publication reused existing code
instead of adding another serializer; restoration uses exact latest-plus-binding evidence rather
than old producer liveness or a bare TTY filename. Fold these facts into the parent's required
meta-thinking capture with truthful attribution.

No full Swift suite was started in this slice because parent requested it wait for coordinator
implementation. Parent owns policy/coordinator/file registration, full integration/regressions,
reviews and live acceptance. This is one required Phase 6 slice, not Phase 6 completion.
