# Phase 6 headless managed entry

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 0.1 (recon and agreed design; implementation held)
Inspected baseline: `72dd557`; parent core API checkpoint: `f0cbc45`

## Owned scope

Only new `Sources/TAVSApp/managed-output-entry.swift`, new
`Tests/TAVSAppTests/managed-output-entry-tests.swift`, and the access modifier of
OrganizerIntake.decodedContext if needed. Parent owns app dispatch, coordinator
changes and broad renderer integration. No project edit or build has occurred.
Broadcaster worker owns the first build slot; entry work is held until release.

## Agreed entry and authority boundaries

ManagedOutputEntry.handle(args) precedes UI construction. It delegates to a
concrete run(args, environment, explicit factory, optional ancestry lookup)
returning code/output/error. Unrelated prefixes return unhandled; unknown managed
verbs fail with a fixed body-free error. No managed capability is advertised yet.

Root marker/runtime arguments are explicit absolute URLs. Validate optional
private ROOT containment before any write, protecting real home through resolved
paths. For visual-recover only, persist suspension once after safe root checks,
then validate target/fixture scope and construct recovery. apply does not mutate
marker, so wrap its catalogue/items tuple as a stateSaved recovery report. Scope
or factory failure therefore returns nonzero after safe persistence succeeds.

All isolated output requires nonempty explicit TEST_TARGETS, including fixture
runs. Existing IsolatedSessionsLaunch.fixture handling returns allowed=nil and
ignores supplied targets; the entry must preserve/validate that allowlist
separately. A fixture snapshot is lazy fixture data only and must never query
real Ghostty. Paths alone are not scope authority.

For register/current/reconcile, validate claimed PID as a bounded ancestor of
the current helper. Recheck generation and concrete target device; intermediate
detached helpers need not have a controlling device. Normal context producers
also require exact live generation/device plus ancestry. Synthetic calls may
skip ancestry only; coordinator publication must prove the current matching
observation. No process argv is read, no title targeting or arbitrary OSC parser
is introduced, and no unsafe target fallback broadens explicit scope.

## Coordinator APIs agreed with parent

VisualRecovery constructor receives controller: ProcessGeneration? and refuses
restrictive paint when its generation is unavailable. Register/recover remain
usable. target(tty, owner) returns exact continuing-owner binding; scoped runs
require exactly one validated cached allowed native binding or fresh allowed
native snapshot. write(.register) caches only and returns false.

Managed operation cases include register/current/reconcile, ordinary background,
emergency reset and forcedReset(intent,intakeAt,title). apply returns
(catalogueAvailable,items) without marker mutation. recover's existing report
remains available to other callers. Entry uses apply after its own ordered
persistence to avoid duplicate writes.

## Planned focused tests

- Unknown/query flags remain unhandled without any factory/UI activation;
  malformed known verbs and arguments produce fixed errors.
- Relative roots or unsafe private ROOT containment fail before persistence.
- Safe roots plus bad TARGETS/fixture/factory persist suspension then report
  failure without invoking native discovery or device output.
- Exact helper ancestry/device/generation authenticates register/current;
  unrelated, reused and mismatched callers cannot reach the factory/writer.
- Register caches a dedicated target without paint. Current/reconcile do not
  mutate the marker; live rule behavior is delegated to the coordinator.
- Ordinary live context is authenticated and outputs only typed normalized
  background through the actual owned-PTY writer.
- Synthetic orphan context works only with matching current observation;
  missing/stale/replaced observation exits 3 without paint.
- Forced reset retains synthetic validation and typed title bounds, without
  logging context/title data or parsing arbitrary OSC.
- Explicit scoped cached native binding works without real native discovery;
  owner-only cannot silently satisfy native scope, and foreign targets remain
  excluded even with fixtures.
- Recovery result uses correct success/partial failure codes and saved-state
  report fields. Fixture native snapshots never query the real catalogue.

Tests will use private runner roots, owned PTYs, injected process identities and
an explicit factory. No default factory will target working sessions during
unit acceptance. No real native/runtime read, install, Git/docs mutation or
process signal is authorized. Full source report and exact red/green logs will
replace this draft after the build slot/source are released.

## Final implementation checkpoint

Version: 1.0

Implementation is complete for the bounded entry slice. Changed exactly:

- `src/macos/TAVSApp/Sources/TAVSApp/managed-output-entry.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/managed-output-entry-tests.swift`
- `src/macos/TAVSApp/Sources/TAVSApp/organizer-intake.swift`: only decodedContext
  access changes from private to internal, reusing the existing decoder.

Parent separately owns TAVSAppMain dispatch and coordinator/cache/synthetic APIs.
The initial held-recon notes above record the sequencing before implementation.

### Implemented interface

ManagedOutputEntry.handle(args) calls concrete run with explicit environment,
factory and ancestry lookup seams, prints the result and exits before UI. The
factory receives absolute marker/runtime URLs and environment, builds the small
state/policy/recovery dependencies, and never creates Scheduler/login/SwiftUI.

Supported operations are visual-recover recover/resume; managed-register;
managed-current; managed-reconcile; managed-background; managed-forced-reset;
and managed-check-context. The validation-only synthetic operation performs no
paint/intent publication. Reconcile authenticates actual caller ancestry without
requiring its controlling device to equal the other requested TTY, then uses
exact cachedTarget, never discovery, PID matching or title guessing.

Ordinary context calls require a live exact producer generation/device plus
helper ancestry. Synthetic calls skip ancestry only and require the coordinator's
current matching observation. Invalid arguments/errors are body-free. Stale
record/context outcomes exit 3; other failures and partial restoration exit 1;
success/unaffected exits 0.

Root/path safety is checked before writes. Safe visual-recover persists once
before target/fixture/factory validation and uses apply to avoid duplicate
persistence. Its report accurately retains stateSaved after a later helper/scope
failure. Marker definition does not change for ordinary/register/current/
reconcile/check operations.

All isolated output requires explicit nonempty TARGETS even when a fixture is
present. The separate allowlist is retained through the concrete fixture factory;
its native snapshot closure reads only a bounded regular fixture and filters
native IDs. It cannot fall through to real Ghostty. Cached allowed native binding
can satisfy scope, while owner-only cannot silently broaden it. Relative/control
paths, unsafe private ROOT containment and unsafe typed titles are rejected.

The safe known query --validate-config --managed-output-capabilities was added
only after parent confirmed all shell route sources existed. It returns exactly
`tavs-managed-output-schema=1` without parsing isolated environment or invoking
factory/native discovery. Extra arguments fail and unrelated flags remain
unhandled for existing dispatch.

### Test-first and failure evidence

Initial missing-entry red compile (terminal):
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.gWja28/command.log`

Parent/store coordinated missing-API compile red: cachedTarget, checkSynthetic
and validateSyntheticUnlocked were absent intentionally. No runtime failure
count claimed for this compilation result. Log:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.kuyDvs/command.log`

Capability functional red: one test, four failed assertions before query support.
Log: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.KGqbJE/command.log`

First combined runtime check: 89 tests, 17 failures. Sixteen were the fixture's
URL object equality: Foundation marked an existing directory URL with a trailing
slash while the original URL had none. Assertions now compare the exact paths.
The remaining parent's core fixture published observedAt 1001 with VirtualClock
still 1000; its correct future-timestamp rejection was verified and parent
advanced clock before publication. No production guard was weakened. Log:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.mhaH36/command.log`

Final focused: **89/89**, Entry16 + Store52 + Recovery21, zero failures/warnings.
Log: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.dN0urz/command.log`

Final full Swift: **363/363**, zero failures/warnings, exit 0, 4.085 seconds XCTest.
Log: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.kILG2B/command.log`

Explicit source helper build: success, 0.14 seconds.
Log: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.UM5Ylu/command.log`

Actual executable safe query with all invalid TAVS_SESSIONS_TEST_* values:
exit 0, exact `tavs-managed-output-schema=1`, proving pre-UI handling. Log:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.HCqj66/command.log`

Build/test commands used tests/run-isolated.sh, the explicit baseline helper and
`/tmp/tavs-phase6-routing-20261012T165000/build` scratch. Focused filter was
ManagedOutputEntryTests|VisualRecoveryTests|TerminalVisualStateTests.
No unknown new verb was sent to an old binary.

The source-built helper is:
`/tmp/tavs-phase6-routing-20261012T165000/build/arm64-apple-macosx/debug/TAVSApp`

Scratch/source release and helper path were sent to parent and shell worker.
No further builds are running from this worker. Shell worker owns actual scoped
PTY route integration next; default entry operations were not run against working
Ghostty, home, registry, agents or sessions.

### Capture and limitations

[O] Recon verified the fixture launch's dropped allowlist before any entry edit.
The entry retains a separately validated explicit target set.
[O] Source/build dependencies were held and intentionally missing APIs were
captured together before root/store implementation and combined green.
[O] URL representation and future-timestamp fixture errors were traced in source;
only fixtures changed, preserving device/scope/freshness checks.
[O] Query support remained absent until connected shell routes were ready, then
unit red and an actual isolated executable query established the handshake.
[R] Persistence-before-scope/factory, with apply instead of a second recover
write, was the smallest way to preserve independent safety and accurate reporting.
Exact served model was not observed; GPT-6 family is self-reported only. Parent
owns project meta capture, durable docs/state and commits.

This checkpoint does not establish live Ghostty rendering or the full Phase 6
acceptance/review milestone. Shell route integration and native acceptance remain
outstanding. No Git mutation, real runtime/native inspection, user-data change,
process signal, install, sync or additional project edit was made by this worker.
