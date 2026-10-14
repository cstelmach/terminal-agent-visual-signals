# Recovery and managed output API

Last Updated: 2026-10-14 (Europe/Vienna)
Version: 1.47

## Portable record failure categories (integration pending)

`StaleRecordError` retains stale delivery/observation/intent semantics through the existing
bounded worker IPC. Generic target/path/owner failures remain unavailable even when their errno
is ESTALE. Known/unknown delivered-byte counts remain independent of that category. CLI maps
typed stale records to code 3 and all ordinary unavailability to code 1 without error text replay.

`InvalidRegularFileError` identifies metadata leaf shape/size/inode validation separately from
actual open/storage/deadline failure. Synthetic context validation converts invalid observation
records to stale delivery; synthetic publication and ordinary render validation retain their
native invalid-record failure. Lost producer during render/check context is stale, while targeted
publication's producer/owner proof remains unavailable. No error-message matching is used.

## Portable no-output managed operations (integration pending)

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
boundaries. Dispatcher/isolation, CLI stale-versus-storage classification and routing remain open.

## Portable helper caller proof (integration pending)

`portable_process_identity.caller_ancestor(caller, device=None)` starts at the helper's process,
visits at most 16 parent identities and rechecks the requested caller's generation/device before
returning. Unrelated callers, cycles, missing identity, changed birth/device and deadline expiry
refuse. The proof is separate from foreground identity and continuing terminal ownership.
Its native-style 100 ms ancestry phase precedes the separate original 100 ms device transaction;
neither promises an aggregate 100 ms command runtime. Dispatch must authenticate before mutation
and before forking a writer, preserving helper-PID ancestry semantics. Routing remains pending.

## Portable observation publication (integration pending)

`publish_observation(store, context, tty, state)` creates only a strict typed observation, under
the existing per-TTY output lock. It rejects older observation times, accepts equal times and
atomically replaces the bounded record. No live/device or verified-agent authority is inferred
by publication; later output and attention checks must establish that evidence separately.
Body, display metadata, intent, target and effects are not published by this operation.

`portable_record_io.read_latest` shares ordinary-intent and observation repair behavior: invalid
regular data can be replaced; links, nonregular paths, storage errors and timeouts cannot. Strict
synthetic intent reads do not recover invalid data. Observation validation/lock/read/write share
one 100 ms metadata deadline. Owned/private tests verify ordering, regular repair, FIFO/link
refusal and lock timeout. Helper entry points and routing remain pending.

## Portable organizer context (integration pending)

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
compatibility. Linux scope/executable encoding, helper verbs and hook routing remain pending.

## Portable reconcile transaction (integration pending)

`Renderer.reconcile(tty, reset_legacy=True, clear_selective=False)` selects an existing current
cached target. It captures suspension after device open under the shared lock, so recovery queued
before open governs reconciliation. Current native rules or surviving selective control refuse
ordinary paint. Explicit clear cancels selective ownership only after successful restoration.

Suspension with no active effects produces no paint. Residual global presentation clears palette,
foreground and background defaults once; other residue clears only the default background. A
matching-revision preview that expires or is explicitly cleared restores latest ordinary intent.
Active reconciliation honors explicit legacy reset and canceled global records. No title, image
or audible alert is replayed. All steps share the original 100 ms deadline.

The current TTY's pending OSC slot is invalidated through held parent descriptors without reading
its body. Linked/nonregular paths fail; other slots remain intact. Failed writes retain active
cleanup records for retry. Unavailable suspension state remains an explicit failure. Owned macOS
PTYs verify these branches; helper/hook routing and Linux scope remain pending.

## Portable forced-reset transaction (integration pending)

`Renderer.forced_reset` reuses the existing bounded transaction. Missing/replaced generations
may select a current cached target; a live same-generation producer on another device refuses
the request. Reset authority is rechecked before open and under the output lock. Title accepts
at most 512 UTF-8 bytes without control/format characters. Palette resets before default
background/title; foreground resets only for residual global presentation. No audible alert or
historical stream is added. An owned producer exits while its parent terminal remains live in
the physical PTY test. Helper/hook integration remains pending.

## Portable bound reset authority (integration pending)

`Intents.publish_forced_reset_unlocked` requires reset intent and a current target. A live
producer uses the existing synthetic delivery checks. An invalid/exited producer requires exact
unchanged latest/observation delivery, observation no newer than intake and a bound copy fully
equal to latest. It retains reset intent and updates binding under the original lock/deadline.
Missing PID alone grants no authority. `Store.cached_target` selects only current cached lifetimes
and refuses absent, conflicting, unknown or ambiguous mappings. No plain lifetime is invented.

## Portable ordinary transaction (integration pending)

`portable_renderer.Renderer.render` connects finite decoding, current ownership, intent and the
bounded worker. It pins recovery revision and publishes background intent under the shared lock
before device open. Under the output lock it revalidates context/target, republishes the frozen
intent and refuses active native control. Obsolete effects restore latest background; residual
global effects additionally reset legacy foreground/palette before the current finite style.
Synthetic output suppresses its alert and leaves observation identity unchanged.

Obsolete active effects are cancelled after successful output, using exact record snapshots.
This differs from native pre-output cancellation to keep retry work discoverable after failed
portable writes. Completion failure reports delivered bytes accurately and retains unfinished
records. All steps share the original 100 ms budget. Owned Mac PTYs verify this transaction;
helper verbs, hook routing and Linux record integration remain pending.

## Portable worker completion (integration pending)

`portable_device_writer.output_lock` reuses the stable owned per-TTY lock with the supplied
deadline. A before-open publisher releases it before bounded device open and output admission.
`write_managed` optionally runs `after_write(fd, deadline)` after complete output, under the same
lock and original 100 ms budget. Completion errors retain known written-byte counts, including
complete output with failed metadata completion. Parent timeout retains unknown output status.

## Portable intent publication (integration pending)

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
`ordinary_ownership` always reads all control records. Helper verbs, hook routing and Linux scope
integration remain pending.

## Portable record replacement (integration pending)

`portable_record_io` reads and replaces bounded typed records through held parent descriptors.
Writes create private directories and an exclusive 0600 sibling temporary, then atomically
replace the destination. Linked ancestors/destinations and paths outside the runtime reject.
Reads do not create directories. Encoding, reads, writes and replacement share the original
deadline. Cleanup attempts removal of only the owned temporary even when closing it fails.
A failure after replacement may mean the record committed; it never authorizes raw output.

## Portable ownership guard (integration pending)

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
Actual owned macOS PTYs verify current output and recovery rejection. Linux scope, publication,
cleanup and hook routing remain pending; this guard advertises no capability.

## Portable record decoder (integration pending)

`portable_records.decode` validates native schema-1 target, effect, observation, intent and
adoption records, including nested allowlists, required fields, scalar types, generation bounds,
timestamps, focus recipes and suspension revisions. Focus colors are canonicalized as native
`Colors` does. Unknown/duplicate keys, boolean integers and nonfinite timestamps are rejected.
Integer identity fields require canonical JSON integer tokens; exponent or decimal forms are
outside this internal reader's accepted subset. Linux scope-bearing generations are rejected.

`read_record` uses bounded 8 KiB regular-file reads and checks the original deadline after JSON
decoding. Missing data is distinct from invalid or unreadable data. `target_path` reproduces
native base64/owner/surface placement; decoding does not establish liveness or attention authority.
Live ownership, placement checks and writer integration are still required before backend use.
An optional held parent `dir_fd` anchors record and sibling reads during directory enumeration;
an absolute path is used for canonical placement, not to reopen a previously verified parent.

## Portable policy reader (integration pending)

`portable_policy.Policy` reads the persistent marker, runtime lock and home mute files without
shell evaluation. Recovery suspension wins; otherwise effective hard locks precede fresh soft
pauses from a live app. File/type/size failures raise instead of authorizing output. A malformed
quoted rule selects no rule, matching the native predicate. Suspension must remain readable.

`capture(deadline)` holds an open marker descriptor to prevent inode reuse. `matches` compares
its filesystem device/inode, detecting atomic replacement even when the boolean is unchanged.
Missing markers require an accessible directory. `read_regular` validates a no-follow regular
file before bounded reads. All operations share the caller's original monotonic deadline.
These readers do not publish rules, repaint terminals or provide a standalone backend yet.

## Portable render decoder (integration pending)

`portable_render.Render` accepts the same finite 23-field, NUL-terminated request as the native
render helper, bounded to 16 KiB. It validates colors, palette actions, title text, image paths
and alert flags before encoding OSC in native order. Synthetic requests suppress the alert bell;
the iTerm2 image command keeps its required terminator. Empty background and explicit default
reset remain separate. It does not interpret arbitrary OSC streams or advertise a capability.

## Portable primitives (integration pending)

`portable_process_identity.inspect` reads macOS libproc with the existing generation fields.
Linux uses boot-relative tick parts with a +1 seconds offset, plus `linuxScope` containing boot
ID, PID/time namespace device/inode pairs and time offsets. It requires one self NSpid, matching
candidate namespaces, complete supported tick intervals and two matching reads from a held proc
directory. Unknown data is unavailable. Linux scope is not native schema-1 generation JSON;
integration must version its records explicitly. Actual Linux kernel acceptance remains pending.

`portable_device_writer.write_managed` accepts trusted typed-caller callbacks, not an OSC stream.
One 100 ms deadline covers fork, pre-open work, device open, lock, preparation and output. The
child closes inherited standard channels and checks expiry before new phases. It opens the TTY
before output-lock acquisition. The lock is a stable regular owned 0600 file. A timeout requests
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
does not certify repaint. The existing 60-second heartbeat retries only failed restriction targets
while a pause/lock remains active, through the coalesced queue and fresh writer policy. Unknown
bindings, release failures and suspended cleanup use explicit Restore Visibility, preserving fresh
hook colors. No native query, additional timer or persistent retry registry is added by retries.

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

`tavs sync` refreshes the root dispatcher, core/CLI dependencies, Claude/Codex adapters,
both Claude hook definitions, plugin shellrc and Codex installer in existing plugin roots.
Required copy/directory/permission failures return nonzero. Direct entry points regain execute
permission; preferences, schedules and lock definitions are not sync inputs. A failure may leave
earlier copies applied. Sync does not build/install the native helper or restart existing workers.
After copying, sync checks both managed-render and organizer-metadata capabilities through their
existing validation branches, excluding isolated GUI launch keys. Missing/unsupported capability
warns separately from source-copy success and does not claim hooks are ready. Probe output is not
echoed. This diagnostic does not repair the pending standalone ordinary-signaling regression.
Sync also copies `src/core/portable_metadata.py`. When native organizer capability is absent or
unsupported, intake selects this Python 3 reader before consuming input. It preserves the four
legacy metadata fields, returns unavailable organizer coverage and exports no context/trust hint.
It accepts a top-level JSON object, caps input at 1 MiB with a two-second read deadline, rejects
invalid field types and enforces the native byte/control limits. Conversation bodies and nested
metadata do not reach core. A missing runtime or invalid payload clears inherited fields and
reports metadata unavailable. A selected native intake failure never invokes a second parser.
This path supplies metadata only; ordinary rendering without the native companion remains open.
Successful Claude/Codex intake transfers the existing positive organizer capability cache across
the unchanged core script exec. Core accepts an imported cache only with the existing intake/context
hint, matching selected helper and executable presence, then removes its export attributes. Intake
clears inherited cache before probing. Managed support remains independently validated; actual
observation/render calls still determine success. These hints do not authenticate hostile complete
environment tuples or guarantee safety against same-path executable replacement.

The shell queries `--validate-config --managed-output-capabilities` and requires exactly
`tavs-managed-output-schema=1`. This known validation branch is safe with older executables.
Unknown support is an explicit failure. Headless entry runs before GUI or login initialization.

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
the existing signature. No helper payload, persisted schema or command changes are required.

`writeManagedToDevice(path:lockURL:beforeOpen:prepare:)` gives both callbacks the original
absolute 100 ms deadline. Background requests publish validated intent and the exact continuing
owner's bound copy in `beforeOpen`, then release the stable record lock before opening the device.
Style-only requests do not publish background intent. Device open precedes the output lock.
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

See [hard-lock reference](reference/hard-lock.md), [bug reference](BUG_REFERENCE.md) and
[implementation progress](specs/tavs-priority-discovery_2026-10-04/PROGRESS.md).
