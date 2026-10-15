# Recovery and managed output API

Last Updated: 2026-10-15 (Europe/Vienna)
Version: 1.83

## Private managed-output failure diagnostics

Code1 managed failures retain empty stdout and the `Managed output unavailable.` prefix,
adding fixed `stage` and `failure` tokens. Stages identify the caller's request, roots, identity,
context, input, setup, target or write boundary; native suspension persistence also uses policy.
Native timeout labels now add the last entered writer boundary: queued, operation, storage,
publication, admission, open, lock, prepare, write or cleanup. A completion-owned mutex protects
that fixed enum; the caller uses one nonblocking try-read and reports unavailable attribution
if busy. Late workers cannot advance it past the original deadline. It identifies a boundary,
not elapsed time or a syscall cause. Completed timeout errors are enriched after the semaphore;
unfinished results are never read. Native labels match typed errors; portable labels match fixed
exception families. Numeric device/OS codes are restricted to 1...4095; native POSIX codes are typed.
Unknown categories remain explicit other/os/device-io failures. No exception descriptions,
class names, paths, titles, payloads, tokens or userInfo are printed.

Semaphore success also requires current monotonic time before the original 100 ms deadline.
Late completed values, including no-paint false, and failures report caller timeout before
Result access. Timely results/errors retain their behavior; timeout does not prove no paint.
The internal completionTime clock seam affects this caller check only, never the worker budget.

Portable callers recheck after readiness, bounded read and decoding, including parse failure.
Expired packets report ETIMEDOUT with bytes_written=None. Timely child errors retain known
write counts and stale categories; timely malformed packets remain EIO. Child cleanup is unchanged.

The internal deviceWriteTimedOut case gains a defaulted optional stage. Existing one-argument
construction and bare matching remain valid; nil keeps the generic device-deadline label.
Code3 stale diagnostics, successful scalar tokens, organizer errors and capabilities remain.
A native exception after suspension persistence retains its structured partial report and adds
these tokens to the fixed reason; no successful restore or target disappearance is inferred.
No deadline, identity check, write ordering, retry or publication behavior changes. Tests retain
helper stages/results through Bats' existing flags; worker intent must also have rendered status
and its expected physical PTY color. A passing control does not explain a prior failed run.

## Shared lock-state transactions

LockStateWriter.update(at:transform:) holds the stable `lock.state.lock` across a checked
fresh read, merge, semantic comparison and atomic replacement. The regular mutex must be
owned by the effective UID and have mode 0600. Its descriptor is always released; the file
remains across rule replacements. No-file shortcuts leave lock.state absent, but create the
mutex. Timestamp-only no-ops return the actual stored record. Transform failure or contention
cannot replace state. One cooperative 100 ms deadline covers the transaction, separately from
the existing 100 ms device caller deadline.

Scheduler manual engagement, grant and schedule projection use this transaction. Its watcher
baseline is the accepted transaction snapshot, including nil for unused absence. A newer CLI
update remains detectable rather than being absorbed by a later snapshot reread.

The headless qualifier `--validate-config --lock-state-capabilities` emits
`tavs-lock-state-schema=1`. `--lock-state-update /absolute/lock.state now END BG FG`,
`grant END`, and `replace LOCKED REASON END GRANT BG FG` return the accepted lock end.
Now/grant ends must be finite digit-only Int64 values after the current time. Replace validates
its fields; colors use PauseVisual's canonical hex normalizer. Malformed requests exit nonzero
before UI or login startup. These verbs perform rule I/O without terminal enumeration or paint.

Darwin CLI mutations require a matching native helper. Explicit test helpers override the
installed path, including unavailable values. The CLI probes the qualifier and never retries
an operation through an unlocked writer. Grants acquire after the challenge and preserve the
current record's end/colors. Non-Darwin mutations use `portable_lock_state.py` with the same
`now END BG FG`, `grant END`, and `replace LOCKED REASON END GRANT BG FG` operations after an
absolute state path. `update(path, operation, values, now, deadline)` holds the stable mutex
across trusted read, merge and private replacement; it returns the accepted lock end. Its CLI
uses one 100 ms transaction budget, excluding Python startup/imports. Missing Python, unsafe
storage, malformed required state and contention fail without an unchecked retry. Successful
replacement commits the result even if descriptor cleanup reports an error. Sync copies this
adjacent dependency. Older writers that ignore the mutex do not participate. Plain-file deadlines
cannot preempt blocked syscalls; ACL/TOCTOU limits remain.

## Checked native mute projection I/O

MuteStateReader.readMutedFlagChecked returns nil for trusted absence and throws for unavailable
storage or unusable flag data. It preserves the legacy flag interpretation, with parent/leaf
trust, no-follow regular-file/inode checks, 8192-byte input and one supplied cooperative deadline.
Successful flag parsing checks the original deadline. Passive readMutedFlag retains optional
semantics; Scheduler uses the checked method for pending startup seeding.

MuteStateWriter validates metadata before creation/replacement and deliberately permits trusted
malformed generated content to be canonically repaired. New output is capped at 8192 and staged
0600 through its descriptor before atomic rename. Unsafe links, special objects, ownership and
writable metadata are not repaired. The existing delete API checks the same objects before unlink;
it has no production caller. Safe absence remains a no-op. No live cleanup flow was added.

Scheduler retries pending startup reads before overwrite and consumes them only when projection
is saved. Lock-save failure skips mute writing. A safely repaired unknown startup value triggers
one explicit reconciliation for an unmuted current projection, without inferring its old Boolean.
Suspended/unavailable restriction UI, grants and retry timers remain. Device100ms is unchanged;
file checks do not interrupt blocked syscalls. Native lock merges use the shared transaction above.

## Checked native lock-state I/O

LockStateReader.readChecked returns nil only for trusted absence. Parent/leaf trust, regular-file
type, no-follow open, inode/device matching, 8192-byte input, UTF-8 and parse acceptance are required.
Its optional supplied monotonic deadline covers retry/size checks; the default is 100 ms. Blocking
syscalls are not preempted. The legacy read wrapper keeps optional semantics for passive callers;
all Scheduler decisions and watches use the throwing method. Pure parsing remains unchanged.

Failed reads stop evaluation before merging or writing projections. Existing paint bookkeeping
and trusted state snapshots remain; heartbeat/transition and known expiry timers rearm. Disabled
restrictions still publish false/none with their status. Watch callbacks retry failed projections
after unchanged-state repair, and heartbeat retries skipped watch startup. Existing save-failure
and grant-acceptance behavior remains. No watcher success Boolean or new state framework is added.

LockStateWriter validates current storage, bounds output and writes an exclusive private temporary
through its descriptor. fchmod applies 0600 before rename, including under restrictive umasks.
The same cooperative deadline covers preparation/writes. Successful rename commits complete
private bytes; no fallible permission operation follows. Existing unsafe/unparseable destinations
are preserved. No-file/unchanged shortcuts inspect current data; readonly unchanged state is valid.

The terminal device deadline remains 100 ms. Native and Darwin CLI mutations now serialize
read/merge/replace. Portable/non-Darwin storage and non-cooperating writers remain outside it.

## Persistent marker trust

Native marker APIs and core/standalone shell reads require trusted directory ancestry and
effective-UID-owned, non-group/other-writable parent/file leaves. Native uses RuntimeDirectoryTrust;
shell guards follow its exact system-alias policy before I/O. Unsafe metadata is unavailable and
preserved. Trusted malformed content stays repairable; trusted absence stays active. New directories
use 0700, markers use 0600, and the atomic canonical format is unchanged.

Native revisions retain their descriptor against inode reuse and use the original deadline;
expiry remains deadlineExceeded. Shell reads keep a 128-byte C-locale bound and their status contract.
Shell writes scope cleanup/umask and recheck before rename; metadata checks do not preempt syscalls.
Schema, resumption and device100ms stay unchanged. Portable marker/policy trust remains separate.

`_tavs_policy_read_data(path)` uses the same shell ancestry/leaf guard for legacy lock/mute data.
It publishes `_TAVS_POLICY_DATA` only for a complete, NUL-free snapshot of at most 8192 bytes.
Returns/statuses are 0/present, 1/absent and 2/unavailable; lock reads preserve `_LS_READ_STATUS`.
CLI status/unlock and schedule edits distinguish unavailable storage from absence. Suspension
still bypasses challenges and preserves definitions. Shell pathname checks remain separate from
opening; the byte cap provides neither descriptor binding nor a hard wall-clock deadline.

`_tavs_policy_decimal(value)` returns canonical ASCII decimal in 0...Int64.max, or status1
without output. It strips zero prefixes and range-checks before full-value arithmetic. Legacy
lock/mute predicates and CLI durations, merges, grants and status use it. Duration products/sums
are checked before calculation. An unavailable clock reports unavailable policy to schedule
gates after the recovery check; suspended/unavailable markers still bypass challenges.

## Native runtime directory trust

RuntimeDirectoryTrust.check validates a file URL's directory chain at use. Existing leaves must
belong to the effective UID and have no group/other write bits. Ancestors must belong to root or
the effective UID and be non-writable by group/other, with a narrow root-owned sticky exception
for /private/tmp and /private/var/tmp. Only the verified root-owned /tmp and /var system symlinks
are accepted as ancestors. A runtime leaf or user/organizer symlink remains unavailable.

Missing read directories retain absence behavior. Creation uses 0700 for each missing component
after checking its parent; unsafe existing paths are rejected rather than changed. Typed-store
and policy reads also validate file UID/write bits; unsafe typed leaves are storage failures,
not repairable invalid data. Existing inode, no-follow and size checks remain.

Store, rule, registry, pending and managed-writer boundaries reuse this guard. Writer checks run
inside its existing worker and original 100 ms deadline, before callbacks/open and again after
open. Lock-parent creation now precedes device admission/open. Lock-file UID checks supplement
its existing exact 0600 predicate. No target/emergency identity or render schema changes occur.

Portable and shell paths remain outside these native guards. The guard checks POSIX metadata,
not ACLs or all path replacement races.

## Record read retries

TerminalVisualStateStore checks the original monotonic deadline before every syscall and retry.
EINTR and partial reads cannot issue another syscall after expiry. Budget and schema stay fixed.
The buffer uses checked file size plus one; reads still enforce the cumulative 8,192-byte limit.
Actual EOF is required, including growth after open. readDescriptor defaults to Darwin.read.
Existing directory/leaf trust, regular-file, device/inode, decode and deadline checks remain.

## Ordinary provider observation compatibility

Native and portable schema-1 observation readers accept the existing context provider set:
claude, codex, gemini, opencode and unknown. This lets ordinary synthetic idle/error updates retain
and validate their original delivery, live producer and device. Synthetic updates do not replace
observations, and superseded contexts still fail. Unknown provider strings remain invalid.

Automatic attention eligibility remains limited to Claude/Codex supported events; a verified flag
or Claude-like event cannot grant it to another provider. The existing cue reducer independently
retains that same boundary. Other-provider coverage states that automatic focus is unavailable.
No executable verification, hook, integration or schema-version expansion was added.

The portable reader reuses the existing metadata PROVIDERS constant. Copied helper bundles already
include that module. Native reading of portable observations uses the same accepted domain.
Updated native helper code is required for this native-path repair; no deployed app was changed.

## Enabled quiet-period bounds

Swift and shell validators require both selected-kind bounds for every enabled quiet period:
hourly start/end minutes or fixed-daily start/end times. Swift reports missingQuietBounds with
rule ID and kind; Preferences identifies the values to enter or permits disabling the row.
Disabled incomplete rows remain valid. Hourly 0/0 and wrapping 55/5, plus daily overnight ranges,
retain their existing semantics. Inactive-kind fields cannot substitute for the selected pair.

The scheduler and headless --validate-config use the shared Swift check without rewriting invalid
files. Shell schedule validation agrees. Resume retains its documented empty-window bootstrap
warning, but rejects other invalid rows before saving. The parity suite requires the explicit
source-built helper and private test root instead of rebuilding in the checkout.

## Scheduler projection-write outcomes

Scheduler attempts both lock/mute projections before advancing transition or paint caches.
Only successful required writes permit broadcasting or heartbeat terminal retries. Failure uses
existing status text to report unavailable storage while retaining requested/suspended UI state.
Heartbeat, transition, grant/lock expiry timers and actual disk readback remain active for repair.
No extra retry timer or two-file transaction is introduced; partial persistence is not rolled back.

A benign missing lock remains a no-file no-op. No-op equality requires a parsed regular lock file
within the managed reader's size limit. Nonregular, unknown or unavailable records fail explicitly
and are preserved. This local check does not replace root trust or eliminate reader races.

`grantUnlock(untilEpoch:)` now returns a discardable Bool: true means the grant was persisted,
even if the following mute projection fails. False preserves the existing lock and reports failure.
`lockNow` likewise stops on a failed lock write. Existing callers continue to display status text.
Thirteen regressions include real Scheduler/Broadcaster/owned-PTY output after storage repair.

## GUI recovery confirmation

`FocusController.cancelForRecovery()` returns a completion closure for that canceled focus-lease
cohort. SessionsModel invokes it on the main queue before displaying a successful recovery report.
Only saved-state reports with bound restored/vanished outcomes for the exact physical target
settle a lease. Conflicting statuses, failures, unaffected results and missing targets retain it.
A late report cannot remove a replacement lease; existing clear workers own their completion groups.
Confirmation emits no terminal output. Fresh ordinary colors and newer effects are preserved.
Independent headless recovery has no GUI report callback; its obsolete-lease bookkeeping remains
an open source issue. Marker replacement or inactive metadata is not physical recovery proof.

## Fresh native effect preparation

FocusController requires an explicit nativeSnapshot closure. Production shares the same scoped
catalogue closure as recovery; tests supply independent native fixtures. After configured colors,
one fresh catalogue validates submitted full surface IDs and exact non-nil TTYs. Duplicate IDs,
shared TTYs, mapping issues and changed associations are unavailable. Fresh foreground PID is used
for physical binding capture. Window/tab/title changes preserve a surviving surface's identity.

Native preparation precedes the existing 100 ms device transaction. Snapshot caller queue wait
and subprocess work share a two-second deadline; expired queued snapshots issue no request.
Preview lifetime and focus heartbeat begin after preparation. Current run/version, physical
generation/device, revision and automatic-source guards still apply inside output serialization.
Native query failure stops new renewal while preserving logical sets/cues and recoverable leases.
Known producer exit is resolved before requiring a fresh emphasized binding. Extra native IDs
enter through ordinary catalogue refresh, not through the effect revalidation callback.

## Continuing focus color refresh

Every nonempty Manual/Automatic focus update resolves configured colors once on the existing
preparation queue, before target fanout or device deadlines. `Run.lastFocusColors` records only
the last accepted recipe for comparison. It is never returned as a cached lookup answer.
Unchanged pairs retain healthy lease IDs. Changed pairs retire that run's leases and use the
existing exact ownership cancellation/replacement path; immutable same-ID recipe checks remain.

A current lookup failure retires old focus leases and includes them in existing cleanup. Mode,
captured set and attention cues remain intact. Cleanup failures retain ownership/repaint work;
later valid updates can replace the old recipe. Obsolete lookup results cannot change the newer
run/version. Foreground, palette and titles are untouched by these background operations.
Global masking retains the new recipe and restores only its current rule's background.

Lookups remain bounded separately from the original 100 ms device transaction. While preparation
is active, identical rendering inputs refresh catalogue coverage without superseding that work.
Title/directory/grouping changes are display-only. Changed native IDs, TTYs, foreground PIDs,
mapping availability, emphasized IDs or attention cues still invalidate the captured version.
Only one active preparation and one latest pending update are retained. Accepted preparation
starts its heartbeat at completion, and each paint still requires catalogue coverage within six
seconds. Four two-second identical polls, changed bindings/cues and expired coverage have
controller regressions. Configuration is a guide, not a getter for arbitrary running colors.
Owned-PTY dark/light, masked cue, unavailable lookup and cancellation tests verify source behavior;
visible reload/readability and native timing acceptance remain open.

## Standalone shell helper delivery

Install and sync use one explicit copy list for the selector and all 13 portable modules.
The standalone shellrc lives at `~/.tavs/shellrc`; adjacent dependencies live under
`~/.tavs/shell-helper/`. The entry point is copied after its dependencies. Required copy failures
return nonzero and do not publish a new shellrc or add fences. Updates may leave earlier helper
copies applied; this is ordinary source copying, not an atomic multi-file installation.
Linked or directory helper leaves are refused instead of writing through them. Removal retains
helper resources for a later reinstall while removing the existing shellrc and rc fences.

Interactive startup resolves the TTY and loads the selector before any registration I/O.
Source `tavs-shellrc.sh` uses the neighboring core; installed `shellrc` uses adjacent resources.
Both support bare, relative and absolute source paths. Backend selection remains private and
global. Only the helper publishes a verified `target.json`; failed registration skips current
policy, retains its backend and reports unavailability. Shell code creates no legacy TTY hints.

Native preference requires both schemas; portable startup permits ordinary registration/no-rule
checks on macOS. Native controlled rules remain unavailable in the portable backend. Suspension
still omits current-policy requests; the persistent reader and native-only recovery are unchanged.
Owned Bash/zsh PTYs prove native/portable startup caching, no bytes/hints and retained suspension.
Visible Ghostty effects and Linux runtime support remain unverified.

## Shared ordinary helper selection and core routing

`src/core/helper-selection.sh` serves Bash 3.2 and zsh. Ordinary hooks select the native candidate
only when both exact organizer and managed-output schemas are supported. Otherwise they select
the adjacent executable Python 3 ordinary helper after its distinct capability check. Selection
precedes stdin consumption and remains fixed for that hook. Failed operations return their original
status; they cannot change backend, reparse payloads or emit raw terminal output.

Completed adapter intake exports the chosen path/backend with the existing context/intake hint.
Success uses intake `1` with context; failure uses intake `0` without context, carrying selection
without metadata authority. Core accepts only the matching candidate, then removes those export
attributes before child work. Missing or mismatched intake hints force a new capability check.
Portable paths resolve the module directory physically so adapter and core source aliases agree.
Native capability and organizer calls omit native test scope; managed calls retain it. Every
portable probe and operation retains scope so unsupported dedicated scope remains a refusal.

The core bridge routes context/intake, observation, render, context validation, forced reset and
reconciliation through that choice. Sync distinguishes portable ordinary support from native
organizer/focus/recovery. Recovery remains native-only and persists suspension before its probe.
Standalone installed-shell resources are delivered; Linux runtime support remains pending.
Owned macOS PTY tests verify real hook intake/render bytes, not visible Ghostty colors or native navigation.

## Portable ordinary capability and copied delivery

The exact query `--validate-config --portable-ordinary-capabilities` returns
`tavs-portable-ordinary-schema=1` on macOS/Linux with current platform process inspection and
no native Sessions test scope. This versions the command protocol; native records stay schema 1,
Linux records use schema 2. Missing identity, extra operands and native recovery remain unavailable.
The query consumes no stdin and creates no state; it grants no native focus/recovery capability.

Source sync copies all 13 existing portable helper modules together and makes the entry executable.
The copied helper probes without importing files from the source checkout. Fake installation
tests compare each copied file and preserve preferences, schedules and lock state. Copied core
intake now selects the portable backend without the original checkout. Installed-shell resource
delivery is shared with install; no real installation was synchronized during verification.

## Portable unbound intent publication

`Intents.publish_unbound` and helper `--organizer-intent tty token background synthetic` retain
only latest ordinary intent under the shared per-TTY metadata lock. Ordinary publication permits
optional or exited identity as data. Synthetic publication requires an exact current observation
and live matching process/device. Neither creates target/bound/adoption records or device bytes.

Bound and unbound publication share normalization, observation freshness, synthetic proof,
regular-only repair, ordering and latest replacement. Bound publication additionally retains its
target/alias proof, late producer check and exact binding. Supersession compares delivery/producer/
device rather than a mis-keyed cached TTY field. Stale data is code 3; invalid records/storage are
code 1. The whole portable metadata operation retains one 100 ms budget, tighter than native legacy
post-lock publication. CLI success is empty output and grants no independent rendering authority.

## Portable helper dispatcher

`python3 src/core/portable_helper.py` handles finite organizer intake/context/observe/intent and managed
register/current/reconcile/check-context/background/render/forced-reset requests. Argument counts,
types, absolute roots, concrete device and parent-side identity proof precede worker mutation.
`TAVS_TEST_ROOT` confines filesystem operations to an owned temporary directory; any native
Sessions test-scope key is unsupported and refuses before input or identity work.

Success uses the existing NUL metadata pairs, Base64 context or rendered/restored/unaffected
line protocol. Stale record code 3 remains distinct from unavailable code 1. Errors contain only
fixed private text. Render stdin is a regular file/pipe, at most 16 KiB through EOF within its
original 100 ms input phase; checks after wait/read prevent delayed EOF acceptance. Intake keeps
its 1 MiB/two-second phase. Ancestry, input and device phases do not renew the device deadline.

`Renderer.background` follows native ordinary publication/current-policy timing without freezing
a pre-open render revision. Unavailable suspension disables restrictions for this ordinary route;
live native control still refuses output. Full render/reset retain frozen revision, and initial
replacement returns unaffected without paint. Reconcile retains its after-open strict revision.
Private test-root checks reject cyclic/dangling links and allow missing child paths. Native
capabilities/recovery remain unsupported. Linux schema 2 uses the same ordinary request protocol;
core hooks and standalone startup select it before intake. Linux kernel acceptance remains open.

## Portable record failure categories

`StaleRecordError` retains stale delivery/observation/intent semantics through the existing
bounded worker IPC. Generic target/path/owner failures remain unavailable even when their errno
is ESTALE. Known/unknown delivered-byte counts remain independent of that category. CLI maps
typed stale records to code 3 and all ordinary unavailability to code 1 without error text replay.

`InvalidRegularFileError` identifies metadata leaf shape/size/inode validation separately from
actual open/storage/deadline failure. Synthetic context validation converts invalid observation
records to stale delivery; synthetic publication and ordinary render validation retain their
native invalid-record failure. Lost producer during render/check context is stale, while targeted
publication's producer/owner proof remains unavailable. No error-message matching is used.

## Portable no-output managed operations

`Renderer.register`, `current` and `check_context` open the exact device under the existing
100 ms writer deadline/lock and validate current binding/descriptor before returning no bytes.
Register caches a missing target without rewriting a valid cache. Current additionally validates
the exact effect slots, preserves effects/pending output and returns unaffected when no rule
applies. Unavailable suspension disables this no-paint branch; active-state rule storage errors
and timeouts still fail. A current native rule is unavailable in the ordinary portable backend.

Check-context validates frozen synthetic observation/producer without caching or publication.
Register/check bypass policy and lease liveness; neither requires ordinary bound data. Selection
retains valid effect-only native identity hints, including preference and ambiguity rejection.
Invalid regular hints can be ignored for this identity-only operation; files are not repaired.
Current rereads its slots strictly. Ordinary/reconcile output admission retains full strict reads.
Actual owned macOS PTYs verify absent device bytes, target-cache ordering/preservation and alias
boundaries. Dispatcher isolation, CLI stale/storage classification and routing are now connected above.

## Portable helper caller proof

`portable_process_identity.caller_ancestor(caller, device=None)` starts at the helper's process,
visits at most 16 parent identities and rechecks the requested caller's generation/device before
returning. Unrelated callers, cycles, missing identity, changed birth/device and deadline expiry
refuse. The proof is separate from foreground identity and continuing terminal ownership.
Its native-style 100 ms ancestry phase precedes the separate original 100 ms device transaction;
neither promises an aggregate 100 ms command runtime. Dispatch must authenticate before mutation
and before forking a writer, preserving helper-PID ancestry semantics. Core routing is connected above.

## Portable observation publication

`publish_observation(store, context, tty, state)` creates only a strict typed observation, under
the existing per-TTY output lock. It rejects older observation times, accepts equal times and
atomically replaces the bounded record. No live/device or verified-agent authority is inferred
by publication; later output and attention checks must establish that evidence separately.
Body, display metadata, intent, target and effects are not published by this operation.

`portable_record_io.read_latest` shares ordinary-intent and observation repair behavior: invalid
regular data can be replaced; links, nonregular paths, storage errors and timeouts cannot. Strict
synthetic intent reads do not recover invalid data. Observation validation/lock/read/write share
one 100 ms metadata deadline. Owned/private tests verify ordering, regular repair, FIFO/link
refusal and lock timeout. The helper entry and core routing use this publisher.

## Portable organizer context

`portable_metadata.decode_intake` parses bounded top-level metadata once, returning legacy
display fields plus recognized event/response fields. Legacy selection remains available through
`decode_metadata`. No prompt/tool/output body or payload identity flag enters correlation.

`portable_context.capture` checks current foreground-family generations/device/group and actual
macOS executable path. Claude/Codex executable evidence is distinct from unverified foreground
fallback; interpreter basenames cannot verify an agent. Context has a fresh delivery ID/time,
provider/verification and optional process/device/event/response, encoded as standard Base64 JSON.
Context decoding rejects malformed types, unknown/duplicate fields, invalid schema/generation and
future time.
Optional event/response strings preserve native intake's length/NUL contract; observation ID
validation remains separate. Context data alone grants no live rendering or attention authority.

Owned macOS PTYs verify native foreground agreement and cross-language context/observation
compatibility. Linux scope is integrated; agent executable verification is unavailable, kernel tests open.

## Portable reconcile transaction

`Renderer.reconcile(tty, reset_legacy=True, clear_selective=False)` selects an existing current
cached target. It captures suspension after device open under the shared lock, so recovery queued
before open governs reconciliation. Current native rules or surviving selective control refuse
ordinary paint. Explicit clear cancels selective ownership only after successful restoration.

Suspension with no active effects produces no paint. Residual global presentation clears palette,
foreground and background defaults once; other residue clears only the default background. A
matching-revision preview that expires or is explicitly cleared restores latest ordinary intent.
Active reconciliation honors explicit reset and canceled globals; completed globals are retired.
No title/image/alert is replayed. Matching state removal uses the original 100 ms deadline.

The current TTY's pending OSC slot is invalidated through held parent descriptors without reading
its body. Linked/nonregular paths fail; other slots remain intact. Failed writes retain unfinished
cleanup records for retry. Unavailable suspension state remains an explicit failure. Owned macOS
PTYs verify these branches; Linux scoped records are integrated but kernel acceptance is pending.

## Portable forced-reset transaction

`Renderer.forced_reset` reuses the existing bounded transaction. Missing/replaced generations
may select a current cached target; a live same-generation producer on another device refuses
the request. Reset authority is rechecked before open and under the output lock. Title accepts
at most 512 UTF-8 bytes without control/format characters. Palette resets before default
background/title; foreground resets only for residual global presentation. No audible alert or
historical stream is added. An owned producer exits while its parent terminal remains live in
the physical PTY test. Helper/hook integration remains pending.

## Portable bound reset authority

`Intents.publish_forced_reset_unlocked` requires reset intent and a current target. A live
producer uses the existing synthetic delivery checks. An invalid/exited producer requires exact
unchanged latest/observation delivery, observation no newer than intake and a bound copy fully
equal to latest. It retains reset intent and updates binding under the original lock/deadline.
Missing PID alone grants no authority. `Store.cached_target` selects only current cached lifetimes
and refuses absent, conflicting, unknown or ambiguous mappings. No plain lifetime is invented.

## Portable ordinary transaction

`portable_renderer.Renderer.render` connects finite decoding, current ownership, intent and the
bounded worker. It pins recovery revision and publishes background intent under the shared lock
before device open. Under the output lock it revalidates context/target, republishes the frozen
intent and refuses active native control. Obsolete effects restore latest background; residual
global effects additionally reset legacy foreground/palette before the current finite style.
Synthetic output suppresses its alert and leaves observation identity unchanged.

After successful output, exact global records are removed; selective records become inactive.
Native pre-output cancellation also retains global debt until its reset actually completes.
Completion failure reports delivered bytes accurately and retains unfinished
records. All steps share the original 100 ms budget. Owned Mac PTYs verify this transaction;
helper verbs/hook routing are connected. Linux schema 2 runtime acceptance remains pending.

## Portable worker completion

`portable_device_writer.output_lock` reuses the stable owned per-TTY lock with the supplied
deadline. A before-open publisher releases it before bounded device open and output admission.
`write_managed` optionally runs `after_write(fd, deadline)` after complete output, under the same
lock and original 100 ms budget. Completion errors retain known written-byte counts, including
complete output with failed metadata completion. Parent timeout retains unknown output status.

## Portable intent publication

`portable_intent.Intents` requires the existing per-TTY lock and original deadline. Publication
checks current producer/owner and target aliases, normalizes background intent and rejects stale
deliveries. Synthetic updates match the frozen latest observation and create no new observation.
Ordinary intake can repair invalid regular intent data. It retains latest intent before binding
validation, so a corrupt bound copy reports failure without discarding the requested intent.
Strict output-context validation refuses unreadable observations and rechecks the live producer.

Binding requires full latest-record equality. A matching bound copy can restore latest background
after producer exit; unbound native intent additionally requires exact existing adoption.
`Store.resolve`/`_current` have an internal `targets_only` publication mode that excludes bound
and effect contents while preserving directory/link checks. It grants no rendering authority:
`ordinary_ownership` reads all control records. Helper verbs and hook routing are connected;
Linux scoped-record integration still needs actual kernel acceptance.

## Portable record replacement

`portable_record_io` reads and replaces bounded typed records through held parent descriptors.
Writes create private directories and an exclusive 0600 sibling temporary, then atomically
replace the destination. Linked ancestors/destinations and paths outside the runtime reject.
Existing prefixes use the policy ancestry rules; held state directories and regular destinations
must be EUID-owned without group/other writes. All held directories and the destination are
rechecked after staging and before replacement. `parent_directory` internally yields the final
descriptor and its reusable chain validator. Read-only group access remains supported.
Reads do not create directories. Encoding, reads, writes and replacement share the original
deadline. Cleanup attempts removal of only the owned temporary even when closing it fails.
A failure after replacement may mean the record committed; it never authorizes raw output.

## Portable ownership guard

`portable_ownership.Store` resolves the current continuing physical owner and prefers one exact
native alias when present. It scans every owner branch in the requested TTY bucket, including
effect-only targets, with held directory/file reads and canonical placement checks. Unreadable
state, unexplained live identity and multiple physical/native bindings refuse admission.

`ordinary_ownership` requires the shared output lock and opened TTY descriptor. It revalidates
the target and pinned suspension revision, current global policy and selective lease evidence.
Recent unknown controllers refuse output; proven exit, reuse, expiry or disabled restrictions
release obsolete ownership. A current suspended preview may still own the background.
The method returns obsolete active records for cancellation; it does not cancel or paint them.
The caller must handle residual global foreground/palette reset before ordinary rendering.
Actual owned macOS PTYs verify current output and recovery rejection. Publication, cleanup and
hook routing use this guard. Linux uses versioned scope; the guard itself advertises no capability.

## Portable record decoder

`portable_records.decode` retains native schema 1 and accepts Linux schema 2 for ordinary data.
Both reject unknown/duplicate fields, boolean integers, invalid types and nonfinite timestamps.
Native birth fields retain epoch checks; Linux boot-relative birth is not compared with wall time.
Linux generations require boot UUID, PID/time namespace device/inode pairs and both time offsets.
Namespace devices are uint64, inodes positive uint64; offsets are [int64 seconds, 0..999999999 ns].
Full scope agrees across participating generations. Native surfaces/adoption remain schema-1-only.
Native keys keep their spelling; Linux fixed-order keys retain all scope fields within 228 bytes.
Concrete Linux targets admit canonical /dev/pts/N as well as TTY names; live device checks remain.

`read_record` bounds regular reads to 8 KiB and checks the original deadline after decoding.
Missing, invalid and unreadable records stay distinct. Colors/recipes and suspension revisions
retain strict typed validation. Held parent descriptors anchor record/sibling reads; canonical
placement is checked separately. Data decoding alone establishes no live output authority.

## Portable policy reader

`portable_policy.Policy` reads the persistent marker, runtime lock and home mute files without
shell evaluation. Recovery suspension wins; otherwise effective hard locks precede fresh soft
pauses from a live app. File/type/size failures raise instead of authorizing output. A malformed
quoted rule selects no rule, matching the native predicate. Suspension must remain readable.

`capture(deadline)` holds an open marker descriptor to prevent inode reuse. `matches` compares
its filesystem device/inode, detecting atomic replacement even when the boolean is unchanged.
Missing markers require an accessible, trusted existing directory prefix. Policy acquisition and
revision matching validate root/EUID ancestors, an EUID leaf directory and no group/other writes.
Only verified Darwin system aliases and exact root-owned sticky system-temp ancestors are exempt.
`read_regular` checks EUID/no-write metadata before opening and on the opened regular file;
this shared leaf guard also applies to typed-record readers. Unsafe metadata raises EACCES,
so canonical malformed-content repair cannot replace an untrusted regular record.
All operations share the caller's original monotonic deadline. Unavailable-marker fallback
rechecks expiry even after an I/O error. Directory checks are not held across ancestor changes.
Behavior change: unsafe existing storage is unavailable and is never permission-repaired.
These readers do not publish rules or repaint terminals; the standalone helper uses them.

## Portable render decoder

`portable_render.Render` accepts the same finite 23-field, NUL-terminated request as the native
render helper, bounded to 16 KiB. It validates colors, palette actions, title text, image paths
and alert flags before encoding OSC in native order. Synthetic requests suppress the alert bell;
the iTerm2 image command keeps its required terminator. Empty background and explicit default
reset remain separate. It does not interpret arbitrary OSC streams or advertise a capability.

## Portable primitives

`portable_process_identity.inspect` reads macOS libproc with the existing generation fields.
Linux uses boot-relative tick parts with a +1 seconds offset, plus `linuxScope` containing boot
ID, PID/time namespace device/inode pairs and time offsets. It requires one self NSpid, matching
candidate namespaces, complete supported tick intervals and two matching reads from a held proc
directory. Unknown data is unavailable. Schema 2 propagates this complete scope through context,
records, cache keys and owner/producer comparisons. Actual Linux kernel acceptance remains pending.

`portable_device_writer.write_managed` accepts trusted typed-caller callbacks, not an OSC stream.
One 100 ms deadline covers fork, pre-open work, device open, lock, preparation and output. The
child closes inherited standard channels and checks expiry before new phases. It opens the TTY
before output-lock acquisition. The lock is a stable regular owned 0600 file. Policy ancestry is
checked before creating its parent or mutex and again before opening the mutex. A timeout requests
termination without blocking the caller on retirement; tests drain owned children separately.
Failures expose `bytes_written` as a known partial count or `None` when output is unknown.
Callbacks run in the child, so parent-memory mutation does not publish outcomes. Interpreter
startup and prior-child reap bookkeeping precede the device budget; OS scheduling is not hard
real-time. These modules advertise no capability and are not yet connected to production hooks.

## Public recovery commands

```bash
tavs recover
tavs recover --resume
```

Recovery saves persistent visual suspension before resolving the native helper. Suspension
survives TAVS restart and overrides pauses, locks and selective focus without a challenge.
Saved schedules, grants and session processes are preserved. Resume permits current rules again
and leaves selective focus Off. Neither operation replays historical alerts, titles or bells.
While restrictions are disabled, scheduler/startup reconciliation emits nothing for canceled
ownership or retained ordinary intent alone. Remaining active global paint resets to defaults;
remaining focus or stale preview paint resets background only. A current suspended preview still
recomposes and clears/expires to latest intent, without unrelated foreground/palette reset.
Fresh ordinary hook renders remain allowed. Generic reconciliation cannot prove a failed emergency
repaint succeeded from canceled metadata; reported failures remain retryable with `tavs recover`.
Scheduler delivery results publish on the main queue. Menu warnings distinguish earlier failed
updates from unavailable native coverage; count-only logs expose neither titles nor payloads.
Unresolved exact targets remain until restored or confirmed vanished; registration/no-output success
does not certify repaint. The existing 60-second heartbeat retries only failed bound targets
while the suspension marker is active, including after a pause/lock ends. Targeted reconciliation
reads current policy, restores legacy foreground/palette from retained global records and composes
latest ordinary/focus background. Healthy targets are not retried; no native query or timer is added.
Unknown bindings and suspended cleanup use explicit Restore Visibility. A no-output result never
proves an earlier failure resolved. A separate successful recovery can leave this in-memory warning.
While active, cleanup of an unresolved global record can also reset a fresh ordinary palette;
it preserves the latest background and replays no historical title or bell. Suspended recovery
preserves fresh complete renders. No cross-process physical-success receipt is inferred.

The helper returns JSON with `stateSaved`, `catalogueAvailable` and `items`. Each item contains
an optional validated `target` or `tty`, `status` and optional `reason`. Status is `restored`,
`vanished`, `unaffected` or `failed`. Missing catalogue access does not prevent cached healthy
targets from recovering. Unsafe registry-only targets and live delivery failures remain reported.
Registry hints never authorize output. A concrete hint is `vanished` only when current device
inspection fails and positive node-loss evidence confirms absence. Nil or contradictory inspection
remains `failed`. Malformed/unreadable entries have individual failures; directory failure means
the directory itself could not be inspected. Arbitrary entry names are excluded from reports.
An existing native binding failure is retained even beside a cached restoration on that TTY.
Failed/restored/unaffected items suppress redundant hints. A vanished historical owner suppresses
a closed hint only after device-loss proof; a live unverified hint still reports failure.

Exit 0 means the operation completed without reported failures. A nonzero CLI exit means saving
state failed, the helper was missing/unsupported, or native recovery was incomplete. When saving
state succeeds but helper resolution fails, the saved suspension remains effective.

The GUI client saves the same marker before querying the current bundle executable. It launches
`--visual-recover MARKER RUNTIME recover|resume` on a background queue, accepts valid reports on
exit 0 or 1, and displays partial failures without rolling back suspension. Capability queries
omit the three isolated launch keys; recovery retains their exact private scope. Fixture scope
uses its full validated ID set or the supplied narrower allowlist, never browsing selection.

## Internal helper compatibility

`tavs sync` refreshes the root dispatcher, core/CLI dependencies, Claude/Gemini/Codex adapters,
hook templates, both Claude hook definitions, plugin shellrc and standalone/unified installers.
Required copy/directory/permission failures return nonzero. Direct entry points regain execute
permission; preferences, schedules and lock definitions are not sync inputs. A failure may leave
earlier copies applied. Sync does not build/install the native helper or restart existing workers.
After copying, sync uses the shared ordinary selector described above. Native organizer and managed
schemas are checked together. Portable support is reported separately from native controls; no
helper availability claim exposes probe output. Sync copies all portable modules, not just the
legacy metadata reader. Core hooks can now use portable typed intake and rendering independently
of the original source checkout. Standalone shell resources are delivered; Linux support remains open.

If neither backend is supported, intake retains the bounded metadata-only reader: four legacy
fields, unavailable organizer coverage and no context/intake authority. A missing Python runtime or
invalid payload clears inherited fields and reports unavailable metadata. Selected operation
failure never invokes that reader. Successful intake uses context plus intake `1`; failed selected
intake carries its fixed choice with intake `0` and no context. Core validates the matching candidate
and hint before removing cache exports. The hints do not authenticate hostile complete environment
tuples or guarantee safety against same-path executable replacement.

Public recovery still queries native managed-output support directly.
The known `--validate-config --managed-output-capabilities` branch requires exactly
`tavs-managed-output-schema=1`; unknown support is an explicit failure. Headless entry runs before
GUI or login initialization. Ordinary core hooks and startup also require the native organizer schema.

The internal `--managed-render` request receives one bounded UTF-8 NUL-delimited stdin payload:

| Field indexes | Meaning |
|---|---|
| 0 | Optional background: empty, `reset`, or normalized hex |
| 1 | Palette action: empty, `set`, or `reset` |
| 2–17 | Sixteen optional palette colors |
| 18–19 | Title enabled flag and title |
| 20–21 | Image action and absolute image path |
| 22 | Bell enabled flag |

Exactly 23 fields and a final NUL are required, with a 16 KiB maximum. Control characters,
invalid flags and malformed colors/paths fail before output. The response is `rendered`,
`restricted` or `unaffected`. A rejected stale delivery exits 3; general failure exits 1.
These values govern title persistence and idle-worker retry. Synthetic work cannot emit a bell.
Delayed tool-error processing/subagent restoration retains its original delivery and uses the
same managed render. It skips timer cancellation, session-state publication, counter increments
and new-prompt identity work. A newer hook after precheck therefore preserves its state and timer;
final native validation still rejects the stale visual batch. Meaningful hooks retain those actions.
Tool-error restore retries code 1 once after 50 ms, rechecking its original context each attempt.
Synthetic core returns final render status; ordinary render failures retain hook exit 0.
Each helper call keeps its 100 ms budget. Persistent failures await a new hook or recovery.
Current palette, background, title and image styling is composed inside the writer transaction;
the payload is ephemeral and is not retained as output history.

## Writer ordering

`VisualRestrictionsRevision.identity` exposes only the marker's device/inode or explicit missing
identity, with strict Codable parsing. The initiating run must retain the pinned revision while
its effects or pending cleanup remain live. Stored identities are compared under the original
writer deadline; atomic replacement invalidates them even when the Boolean value is unchanged.
No descriptor, desired focus mode or extra cancellation token is serialized.

`ProcessRunner.runBoundedOutput` retains stdout and exit status, accepts an explicit environment,
and caps the process at ten seconds with bounded pipe draining. `runBounded` remains the
code-zero-only wrapper with its two-second limit for native catalogue/configuration queries.
The device writer's separate original 100 ms deadline is unchanged.

Native device admission is shared across runner instances. Validated requests supply the current
physical binding (TTY, device and continuing owner generation); native aliases share that slot.
One ordinary operation and one separate emergency-reset operation may remain in flight per
physical lifetime. Only `VisualRecovery`'s `.emergencyReset` uses the reserved lane. Both still
acquire the same output lock and revalidate policy and identity before painting. A reset blocked
by that lock or by device I/O reports a partial failure. Other healthy targets remain independent.
Admission lasts until the worker actually closes/unlocks and exits, including after caller timeout.

Fresh intent publication and exact-ID cancellation precede admission under the original deadline.
A busy native slot returns `deviceIOFailed` with `EBUSY` after available metadata is published.
Thus busy ordinary output retains its latest background without creating another stuck open.
Raw/unresolved overloads conservatively share a path slot with known lifetimes in the ordinary
lane. Syntactic path aliases are normalized; arbitrary symlink identity is not established.
This bounds repeated native I/O for the same lifetime, not every callback worker or all lifetimes
across a process. The internal overload adds `target` and `emergency`; unresolved callers retain
the existing signature. Completed reset removes exact global debt; failures keep it retryable.

`writeManagedToDevice` gives beforeOpen, prepare and optional afterWrite the same deadline.
AfterWrite runs only after complete bytes, under the same lock, within the original 100 ms.
BeforeOpen publishes validated intent and bound owner state, then releases the stable record lock.
Device open precedes the output lock. Style-only requests publish no background intent.
Full renders and forced resets pin the suspension marker before device open under the same
budget. Preparation rejects a replaced revision with `unaffected`, preserving intent without queued
palette, title or bell bytes. A new render after recovery captures the current revision.

`--managed-forced-reset` may clear an exited producer through its cached continuing-owner binding.
After producer exit it requires an unchanged observation and latest previously bound intent for
that exact delivery, TTY and device. A live producer may reset without prior intent, but any current
intent must belong to the same delivery. Checks run before open and under the output lock.
A newer delivery, standalone intent, missing binding or reused owner rejects the reset.
No native catalogue access or new helper verb is needed for this cleanup.

Per-TTY resolution uses `cachedRecords(tty:)`, traversing every owner generation and native/plain
branch of that TTY's existing cache bucket. It retains effect-only bindings and the same parser,
placement and link checks. Full recovery and launch reconciliation still use `cachedRecords()`
across all TTYs, including unreadable paths. No records are retired by lookup.

Preparation revalidates the opened descriptor, lifetime, stale delivery and current policy under
that lock. A new restriction replaces the complete ordinary render; selective backgrounds compose
over the latest ordinary intent. Failure or late open cannot claim paint or run late preparation.
When publication succeeded before a device failure, later recovery retains that intended color
or reset. If publication-lock contention consumes the whole budget, publication fails without a
new budget or late retry. No arbitrary program-set color restoration is claimed.

## Automatic occurrence foundation (Phase 9 in progress)

`AttentionState` consumes fresh native-keyed coverage and the current High set. Initialization
baselines existing observations; the activation time also excludes old records adopted later.
It retains consumed completion IDs and observed permission episodes in memory. Acknowledgement
subtracts only the captured occurrence set on its target, preserving later arrivals and other rows.
Occurrences include provider, producer generation, TTY and device, so old navigation cannot
acknowledge a replacement producer's cue. Downgrade removes eligibility without replay on promotion.

Claude completion uses its intake delivery ID; Codex requires its supported completion event and
turn ID. PermissionRequest and permission_prompt coalesce until observed processing/reset.
A prompt after a closed episode needs a fresh request anchor; ambiguous companions are ineligible.
Idle, compacting, subagent and cosmetic error restoration do not imply resumption. Invalid current
coverage removes eligibility; retained acknowledged records cannot rearm. Equal-time or older
same-producer observations do not invent an ordering. Generic Notification is diagnostic only.
Latest-only records may miss intervening hook events; no event journal or new hook was introduced.
The reducer supplies policy to the existing focus controller; it does not paint itself.

`FocusController.enableAutomatic(rows:high:coverage:)` explicitly replaces Manual and arms
Automatic with a pinned recovery revision. At zero cues it clears rendering while staying armed;
a later occurrence gets a fresh render ID. Every current High row is emphasized while any cue
remains. Changing High membership retires old effects, including a promoted row's previous dimming.
Unavailable catalogues invalidate queued rendering and preserve cue history without renewal.

Sessions supplies fresh coverage and committed priorities, keeps the existing non-Off timer,
and snapshots a target's cues before Go To. Only verified navigation success acknowledges that
snapshot. Failure changes no cue; later arrivals survive. Recovery and restart leave Off.
Sessions/menu expose Automatic Focus, per-row cue counts and completion-only acknowledgement.

`TerminalFocusRequest.isCurrent` receives the original writer deadline at each final guard.
Automatic revalidates at least one actual cue producer and its captured native binding through
`validateAttentionSource`, without taking another TTY's coverage lock. This returns valid,
vanished or unavailable for the exact cue, native surface and optional captured target. Missing
inspection preserves its cue; known process/device/application reuse or exit resolves only the
captured occurrences. Positive loss in one domain is not hidden by uncertainty in another.
Currency and the original deadline are checked again after lookup. If no source is valid, new
painting is rejected while unavailable cues remain. Already proven exits are resolved even if
a later source inspection times out. An independent worker preflight checks all-High catalogues,
with one shared 100 ms inspection deadline; it creates no nested device-writer allowance.
Restoring an unchanged observation cannot replay an acknowledged occurrence or end its episode.

`TerminalFocusRequest.didRenew` reports actual metadata publication under the writer lock.
The controller advances its common heartbeat only after every intended mapped target renews
and no write fails. Rejected predicates and zero-target fanout do not renew. A global mask may
hide bytes while still renewing metadata. More than six seconds without renewal rotates the
effect ID on the next catalogue, preserving the attention cue. Unrenewed effects are reported
as unavailable instead of being described as successfully emphasized.
Persisted focus recipes contain no cue actor; later ordinary composition relies on the accepted
lease and controller refresh/cleanup. No new cue registry or event journal was added.
Native automatic salience and active-cue UI acceptance remain unverified. Final source reviews
are complete; their remaining material corrections are tracked in the dated research package.

## Manual focus (Phase 8 source verified)

Dynamic schema-1 `focus` records use `focus.json`, separate from legacy/global `effect.json`
and `preview.json`. They require normalized `focusColors` and marker `revision`; malformed,
missing and wrong-kind fields are rejected. Canceled or expired same-ID records cannot renew,
and the generic heartbeat helper cannot extend dynamic focus. Legacy fixed records retain their
existing slot and semantics. Matching current source-built components are required for this kind.

`TerminalRenderer.focusBackground(ordinary:colors:)` supplies the Phase 8 pure dimming transform.
It reduces chroma in linear light, then tries bounded neutral adjustments for visible dark/light
background changes. Candidates need total RGB distance of 24 and luminance change at most 0.08.
Configured-text contrast stays at least 4.5:1, or does not worsen a lower baseline. Invalid or
unsafe inputs return nil. Current/reset intent handling is shared with the preview renderer.
The managed writer now composes this transform from current ordinary intent on every paint.
Only a guarded controller request advances the six-second heartbeat. Global pause and preview
retain precedence without replacing the dynamic record; clearing or expiry recomposes fresh
intent. Alias agreement compares inputs, revision, run and controller, not last computed color.
Exact-ID clear cancels metadata before device open and emits no stale repaint after replacement.
Internal `.clearFocus` accepts a defaulted `didCancel(target)` acknowledgement. It runs under the
existing TTY lock after validated alias enumeration, exact-ID/controller/revision cancellation
and an original-deadline check. It confirms point-in-time ownership cancellation, absence or
supersession; it does not confirm device repaint. Failed/incomplete metadata produces no callback.
Marker replacement still permits old metadata cancellation but suppresses old repaint. Consumers
must invalidate the old lease predicate before clearing, acknowledge briefly/thread-safely and
never invoke another writer/coverage operation from this callback. Absent IDs get no tombstone.
The optional `restoreBackground` predicate separates cancellation from outstanding repaint work.
Omitting it retains exact-effect clear behavior. False acknowledges cancellation without output;
true recomposes the current background even when the old ID is absent. Both restoration paths
preserve foreground/palette and check the pinned revision. Legacy color reset remains ordinary
reconciliation's responsibility. `applyFocus(to:request:)` creates one request per validated
physical target, retaining native-alias and cross-lifetime TTY conflict rejection before creation.
Preview and focus cleanup use independent background queues. An unrelated blocked focus clear
cannot queue ahead of a healthy preview clear. Both retain the existing per-TTY serialization
and original device deadline; conflicting writes to the same terminal remain serialized.
Stored revision mismatch cannot revive a lease after partial recovery and explicit resumption.
`FocusController.focusSelected(_:catalogue:)` captures native surface IDs independently of
browsing selection and priorities. Accepted catalogues retain that set, add new surfaces only
to its outside set, and end Manual on confirmed last-member closure. Successful empty Sessions
catalogues reconcile confirmed closure, prune selection/priorities and clear closed cues while
Automatic stays armed. Actual failed catalogues retain logical membership, invalidate queued
updates and authorize no new paint. No-surface catalogues disable new Automatic activation.
At least one captured surface needs a verified binding before any outside background is changed.

Manual updates reuse the serialized preview worker and coalesce to the latest catalogue.
Requests revalidate run identity, catalogue version, six-second age and pinned recovery revision.
Each physical target has its own effect ID and saved heartbeat; unrelated failures cannot rotate
healthy IDs. Retirement invalidates its publication predicate before clearing. Only one clear
can be in flight per lease, and unresolved ownership blocks replacement for that target alone.
Locked cancellation permits transfer of remaining repaint responsibility to an explicit current
request; failed physical restoration retains it. Removal requires restoration, confirmed vanishing,
or canceled ownership with no possible focus paint. The preparation join has a shared 100 ms
limit; each device call separately retains its original 100 ms deadline.

Sessions keeps one two-second catalogue timer while its window is open or Manual is active.
Focus Off preserves browsing selection and preview. Restore Visibility cancels both in-memory
effects before independent recovery; external suspension ends Manual on the next refresh.
Relaunch and explicit resumption start Off. Sessions and menu controls expose unavailable and
partial outcomes; the working-set row label is also included in its accessibility label.
Native dimming/readability and closed-window GUI acceptance remain unverified.

## Preview rendering foundation (Phase 7 source verified)

`TerminalRenderer.previewBackground(ordinary:colors:)` uses normalized configured background
and foreground colors. It returns a conservative tint or nil when no safe meaningful change
exists. This is a configured-text contrast bound, not a guarantee for arbitrary program colors.

The internal schema-1 effect kind `preview` uses a separate `preview.json` alongside `effect.json`
for the same exact target. It expires two seconds after its original heartbeat timestamp; neither
refresh nor a same-ID save can extend that time. Exact-ID preview cancellation preserves the
underlying selective record. Global rules take precedence; suspension permits harmless previews.
Emergency recovery discovers and cancels both records through the existing bounded writer.
Controller and GUI wiring are source-tested and checked in an isolated fixture. Use matching
source-built components for acceptance; old executables do not understand the preview record.

Selection immediately pins the suspension revision and remains cancellable while colors/targets
prepare. A successful current preparation establishes one display-start timestamp immediately
before bounded paint. `TerminalPreviewRequest`, its record and the expiry timer use that timestamp;
configuration delay does not consume the two-second lease. Late timer setup uses the remaining
duration, including zero for an already expired accepted start. Failure leaves explicit unavailable
status without an active preview or expiry timer. Fresh validated colors are queried once per
multiselection, without reuse between previews. The revision holds a read-only descriptor, preventing
inode reuse. A preview caches its validated target before comparing that revision inside the
existing writer lock. Recovery's atomic replacement rejects queued starts even if the Boolean
value is unchanged; later accepted writes are discoverable by recovery. Exact-ID clear uses the
same revision so an old clear cannot reapply ordinary color after emergency reset.

GUI replacement previews wait only for their physical target's prior cleanup.
`FocusController` accepts its existing concurrent cleanup queue as an initializer dependency.
The production default is preserved. Isolated tests supply the queue to barrier-drain cleanup
that was scheduled but not yet entered, after invalidating preview and releasing their gates.
`apply(_:to:didComplete:)`
reports each physical fanout result once, including failed/vanished/unaffected groups and aliases.
Distinct cleanup batches progress concurrently; same-target clears retain predecessor ordering.
Optional preview/clear waits run in `beforeOpen`, before admission or record-lock acquisition,
within the original 100 ms budget. Direct requests omit these callbacks. Bounded cleanup failure
reports immediately but retains an outstanding predecessor dependency until both finish. Emergency
recovery joins no preview dependency; a timed-out worker can still cause a reported busy failure.
A replaced suspension marker makes queued output a no-op; unavailable metadata and an expired
original deadline remain failures.
This uses the existing marker and adds no persistent token, schema or polling protocol.

`TerminalRenderer.configuredColors(executable:configurationFiles:runner:)` checks explicit
configuration paths and uses bounded subprocesses away from the UI. Existing nonempty config
uses `+validate-config` followed by `+show-config --changes-only=false --no-pager`. With no
nonempty configuration it uses `+show-config --default --no-pager`, which bypasses template
creation. Canonical background, foreground and theme assignments are required; duplicates,
malformed output, failed validation and unresolved dual-theme appearance are unavailable.
The [show-config source](https://github.com/ghostty-org/ghostty/blob/main/src/cli/show_config.zig)
has no supported appearance selector; the
[validator](https://github.com/ghostty-org/ghostty/blob/main/src/cli/validate_config.zig) checks
diagnostics that ordinary output can omit. Queries reload configuration rather than observe
running colors. Concurrent deletion and optional-file loading remain native CLI limitations;
path preflight does not make configured queries transactional. No live query ran in development.

See [session tables](reference/architecture.md#session-statesh-state-management),
[hard-lock reference](reference/hard-lock.md) and [bug reference](BUG_REFERENCE.md).
