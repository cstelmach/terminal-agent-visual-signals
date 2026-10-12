# Phase 6 synthetic context validation

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.1, source handoff with parent integration evidence.

## Assigned scope

- `src/macos/TAVSApp/Sources/TAVSApp/terminal-visual-state.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/terminal-visual-state-tests.swift`

Parent owns the connected recovery operation and cached-target routing; entry worker owns
headless dispatch and the shared build. This worker edited only the two owned paths and ran
no builds. Source is stable and ready for entry worker's integrated focused/full green.

## Current source contract and minimal change

publishIntentUnlocked already validates the typed intent and optional intake time, reads a bounded
latest observation using the original deadline, compares exact TTY/device/producer/delivery,
and checks the producer's live generation/device. It then compares/replaces latest intent.

Added validateSyntheticUnlocked(intent,intakeAt,deadline) using the same validation/validProducer
helpers without intent reads, mutation, byte composition, schema changes or lock acquisition.
Check original deadline before validation, after bounded read, and after producer/device lookup.
Missing/mismatched/newer and unsupported observations must not authorize synthetic paint.
Invalid typed intent/intake retains invalidRecord; deadline/storage classification remains honest.
Parent confirmed unsupported persisted observation mapping to staleDelivery. Existing public
publication, coverage, adoption, schemas, intent/effect and deadline behavior is unchanged.

## Tests-first implementation

- Exact live delivery under already-held stable lock validates and preserves observation/intent
  bytes and record paths. No reentrant lock acquisition or fresh timeout budget.
- Frozen delivery/producer/device/TTY mismatch and later observation time reject stale context.
- Missing/unsupported latest observation rejects with no new intent/observation files.
- Expired original deadline rejects before any mutation. Invalid typed intent/intake rejects.

Use current explicit fixture roots, injected process/device metadata and VirtualClock. No native
or real devices/processes are required.

Four tests were added before source. Entry worker's coordinated combined compile-red captured
the absent store method at multiple call sites alongside the intentionally absent recovery APIs:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.kuyDvs/command.log`.
Exit 1 confirmed by this worker's bounded log inspection. Source was implemented after red.
Own-path git diff --check passed. No independent build was started while entry owns scratch.

## Implementation boundary

The method performs no lock acquisition, cache call, publication, write, deletion, byte composition
or intent/effect read. Typed intent/intake validation precedes a bounded observation read. Exact
TTY/device/producer/delivery and observation-time comparison precede validProducer. Original
deadline guards follow the observation read and metadata lookup, including a false producer
lookup. Input errors remain invalidRecord; unsupported or stale/missing context is staleDelivery;
storageUnavailable and deadlineExceeded propagate without payload diagnostics.

Parent integrates checkSynthetic before cacheTargetUnlocked so an invalid render cannot create
target state. A caller may create/acquire its existing stable writer lock before validation.

## Final handoff and verification limit

Parent reviewed the source's validation-only scope and original-deadline logic. Parent explicitly
requested ending this bounded worker slice with integrated green pending, to release the agent
slot; the entry worker owns the next focused/full verification. This worker reports no green
test count for this API and will not start additional builds or source edits. Parent will append
later integration evidence and archive this report.

Changed function: TerminalVisualStateStore.validateSyntheticUnlocked. Four new test methods begin
with testSyntheticContext. Current diff is 31 source lines and 83 test lines across exactly the two
owned files. No Git mutations, documentation edits, native/UI activity, real-runtime state or
unrelated source changes were made.

Observed workflow for parent capture: held source/build coordination avoided missing-API tests
contaminating another worker's green. Tests preceded the shared compile-red; the required narrow
error mapping was confirmed before implementation. Deadline checking after producer lookup
preserves the original writer budget even when metadata becomes unavailable. Integrated behavior
remains explicitly unverified in this source-only handoff.

## Parent integration result

After correcting two unrelated fixture assumptions, the connected focused suite passes 89/89:
16 entry, 52 store and 21 recovery tests, with zero failures or warnings. Log:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.dN0urz/command.log`.
This adds integrated evidence without replacing the original source-only account above.
