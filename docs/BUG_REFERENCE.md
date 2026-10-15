# Bug Reference

Last Updated: 2026-10-15 (Europe/Vienna)
Version: 1.95

## Delivery failures lose their diagnostic stage and physical oracle

Managed helper exceptions collapsed to one message; three owned fixtures discarded failure
output. Worker checks accepted retained intent without requiring delivered color bytes. Fixed
caller-stage and allowlisted error labels now preserve privacy and return contracts. Fixtures
retain statuses, require rendered completion plus physical bytes, and use inherited ERR traps.
The four historical combined-run failures remain unattributed. A later diagnostic run reaches
all intended colors but fails a separate delayed tool-error timestamp assertion; its records
are retained. A final control also captures a native caller deadline at the newer render.
Native timeouts carry a synchronized writer boundary without waiting for the worker. Ready
native and portable results previously lacked caller-time checks; late values/errors now fail.
Portable late decoding also reports unknown bytes. Preparation and historical causes remain open.

## Concurrent lock mutations overwrite newer grants and lock ends

Atomic replacement left the read/merge/write sequence unprotected. Native scheduling and CLI
unlock could publish stale fields, including a snapshot held across a challenge. A writer
contention case failed two assertions; post-challenge CLI preservation failed before correction.
All native/Darwin semantic mutations now merge freshly under one stable advisory mutex. The
CLI uses bounded headless operations after the challenge and returns accepted fields.

A second regression reproduced a newer grant being absorbed by Scheduler's late snapshot
reread, suppressing reevaluation (two failed assertions). The watcher now retains the accepted
transaction snapshot, and timestamp-only no-ops return the actual stored record. Seven new
Swift cases and five CLI cases cover the transaction and input boundaries. All 658 Swift tests,
29 CLI checks and the release build pass. A broader 54-case shell run failed four background
cases; their focused control passes, without attribution. Non-Darwin writers and older binaries
remain outside this transaction. Full native acceptance and delivery timing work remain open.

## Native mute projection bypasses storage trust and startup repair

Mute flag reads and projection writes followed linked parents and accepted unsafe UID/write
permissions. Three regressions failed nine assertions. Checked reads now bound trusted regular
input; writer/delete guard actual objects. Canonical projection can repair trusted malformed
bytes, while unsafe objects remain preserved. Private bytes are staged before atomic rename.

Startup seeding remains pending through failed projection. A failed lock save now skips mute
replacement, preserving the old flag for repair. A successful canonical repair of an unknown
seed reconciles once without claiming its old value. Two further cases reproduced lost seeding
and missing cleanup (five assertions). Existing suspension, grants and timer semantics remain.

Eight new cases and all 651 Swift tests pass. One intervening full run failed the existing masked-
focus release-byte case; its log is retained and cause unproven. That fixture now records actual
release writer outcome/heartbeat before its PTY assertion. Final release/helper checks pass.
GUI/CLI merge races, portable/shell trust and required native/Linux acceptance remain open.

## Scheduler treats unavailable lock data as absence

The optional lock reader collapsed unavailable/unparseable storage into nil. Evaluation could
merge it as absence, rewrite mute state, consume published state, or certify a no-file shortcut.
Unsafe storage could also receive grants and watches. Four regressions failed 14 assertions.

The checked reader now distinguishes trusted absence from failure, validates parent/leaf trust
and bounds regular-file input. Scheduler failure preserves writes, paint bookkeeping and trusted
snapshots while rearming retry/transition/expiry timers. Suspension remains visible and inert.
Watch callbacks retry failed projections even for identical repaired bytes; heartbeat retries
watch startup. Manual lock/grant errors preserve timers, and successful grants remain accepted.

Success shortcuts use freshly checked data. Lock replacement now writes bounded private bytes
through an owned temporary descriptor, sets 0600 before commit and atomically renames it. No
fallible permission step follows rename. Nine new cases and all 643 Swift tests pass, as do final
release and 25 isolated helper checks. Concurrent GUI/CLI merge races and legacy mute I/O remain.

## Persistent recovery marker trusts writable or linked storage

Native and shell marker paths checked shape but omitted ownership, write bits and ancestor trust.
Three native regressions reproduced unsafe reads/revisions/replacement (15 failed assertions).
Shell regressions also reproduced unsafe metadata acceptance and pre-helper marker replacement.

Native APIs use RuntimeDirectoryTrust; core/standalone shell checks now follow its ownership and
exact system-alias rules before I/O. Unsafe storage is preserved; trusted malformed data remains
repairable. Trusted absence stays active; new directories/markers use 0700/0600 and atomic replacement.
Native revisions retain their descriptor and supplied deadline. No device budget changes.

A policy fixture isolates unsafe runtime from safe marker; focus cleanup verifies inactive metadata.
Earlier EPERM remains unattributed. The earlier 634 Swift/release and 25 marker checks passed.
New shell cleanup/private-creation tests cover failure paths; legacy/portable policy trust remains
open. Existing full-suite failures are tracked in the implementation progress.

## Native managed paths accept untrusted runtime storage

Directory-type and private-lock checks did not validate the runtime's UID, writable permissions,
or linked ancestry. Three initial cases reproduced unsafe policy, publication and device output.
A shared RuntimeDirectoryTrust guard now checks directories at storage, rule, registry, pending
and managed-writer use points. Wrong-owner, writable and user-linked paths report unavailable;
unsafe record leaves cannot be adopted or repaired. Existing safe 0755 roots remain accepted.

New directories use 0700. Bounded readlink validates macOS's root-owned /tmp and /var aliases.
The writable sticky exception is limited to root-owned system temp ancestors after a regression
reproduced an overly broad draft. The first draft also wrongly used Foundation alias resolution;
an isolated probe established its behavior before the POSIX correction. All failure logs remain.

Twelve new cases and all 631 Swift tests pass, as do the release build and 19 helper checks.
The 100 ms writer budget remains. Scheduler, marker, portable and shell trust remain separate
work; POSIX checks do not establish ACL completeness or a reproduced foreign-account attack.

## Record reads retry after the caller's deadline

The reader formerly retried interrupted/partial calls after deadline expiry. Every syscall now
checks the original deadline; three original cases retain that contract and cached bytes.
Earlier 619 Swift/release and 19 isolated background checks passed; syscalls remain non-preemptible.
The fixed 8 KiB buffer allocated/requested 8,193 bytes for a 122-byte cached record. It now
uses checked file size plus one, while retaining actual EOF and the cumulative 8,192-byte cap.
Three added cases verify footprint and same-inode growth: oversized whitespace after valid JSON,
and an invalid suffix within the cap, must both reject. Six focused reader checks pass.
Metadata, context, identity and both trust walks remain. This does not establish a latency fix
or explain the earlier native unavailable/stale mismatch and broader deadline failures.

## Existing provider contexts cannot publish observations for synthetic updates

Contexts accepted Gemini/OpenCode/unknown, but both observation validators admitted only
Claude/Codex. Immediate ordinary rendering could proceed without an observation; later idle/error
updates required an exact observation and were rejected. Native and portable regressions failed
at observation publication before the fix.

Observation validation now matches the existing context provider set. Native attention eligibility
explicitly stays Claude/Codex-only, and coverage labels other observations as ordinary-only.
Frozen delivery/producer/device checks are unchanged. Provider rejection fixtures now use truly
unsupported strings. Owned-PTY tests exercise synthetic output and the Gemini idle worker through
native and portable helpers without running those agent applications or adding hooks.

## Enabled quiet periods with missing bounds validate but never apply

Both validators checked only values that were present. Missing selected-kind bounds passed,
while the evaluator returned false and ignored the enabled rule. Six missing-pair cases and the
scheduler loader reproduced this silent no-op; the shell/native parity case also failed.

Both selected bounds are now required. Disabled drafts remain permitted, and complete ranges keep
their wrapping/one-minute/overnight behavior. Preferences displays an actionable ID/kind hint.
The scheduler rejects malformed files without rewriting them and accepts a later repaired rule.
CLI resume previously accepted all validation warnings; it now allows only its documented empty-
window exception and preserves the saved file on other validation errors. Private parity tests
cover that exception and rejection. No schedule schema, timer or focus behavior changed.

## Failed projection writes consume later repaint transitions

Scheduler ignored lock/mute write errors and advanced previousMuted and last-painted state anyway.
A later successful storage repair could then save the requested pause without repainting it.
Heartbeat terminal retries also continued after failed persistence, reading stale rules.

Both writers now report outcomes. Transition/paint bookkeeping and terminal retries advance only
after required persistence succeeds. Timers and disk observations remain active; an existing status
message exposes storage failure. Direct lock/grant callers propagate failure, and durable grants
remain accepted if a subsequent projection fails. No-op lock checks distinguish usable absence or
unchanged regular records from unavailable/unknown paths without overwriting those records.

Seven initial cases failed 13 assertions. Thirteen final regressions cover failure/repair, pause
color changes, suspension, invalid paths, direct grants and expiry. Owned-PTY integration proves
one requested paint after repair and no duplicate heartbeat paint. All 609 Swift tests pass.
Broader reader/root trust and live native acceptance remain separate work.

## Failed release clears receive no active heartbeat retry

The scheduler retried only while muted, and Broadcaster used currentRestriction for failed targets.
After release, that operation emits no bytes without a rule. A failed clear could therefore leave
legacy foreground/palette changes on a plain shell even after its device became writable.

The heartbeat now retries bound failures while the suspension marker remains active, including
unmuted state. Targeted reconciliation restores current policy/background and handles canceled
global metadata after a failed prepared write. Healthy targets are untouched. Four owned-PTY
cases cover failure stages and no title/bell replay. Canceled globals formerly survived success,
so later retries reset a fresh palette. Native/portable completion now removes exact reset debt
after full bytes under the same lock/deadline. New renders reset before palette; failures retain debt.

## Successful GUI recovery leaves canceled focus leases stuck

Painted leases retained their old marker revision after Restore Visibility. Later Focus Off could
never restore through that revision, producing a false cleanup failure after successful recovery.
Marker replacement and canceled metadata alone cannot settle a failed physical target.

The GUI now applies per-target recovery outcomes to its captured canceled cohort. Confirmed
restored/vanished bindings retire only the same lease object; failed or unconfirmed targets remain
retryable. Seven regressions cover recovery/resumption/refocus, mixed device failure, uncertain
reports, owner reuse, late confirmation, fresh ordinary output and proven disappearance.
Independent headless recovery still lacks outcome feedback to the live controller and remains open.

## Effects trust cached native associations

Preview and focus captured physical bindings from the last organizer rows. Current owner/device
checks did not prove that those native IDs still owned the same TTY. Three regressions reproduced
paint after native closure, changed association or lookup failure while the old physical owner
remained valid. Effects now use a fresh exact-ID/TTY catalogue after color preparation, including
current foreground identity and ambiguity rejection. Surviving moved panes still paint.

The catalogue snapshot's queue wait was previously unbounded despite a bounded subprocess. A
blocked-queue regression reproduced late success and an expired native call. Queue wait and
subprocess now share two seconds; expired queued work is skipped. Native work stays outside the
100 ms writer deadline. A draft checked emphasized capture before classifying a known sole cue
producer exit; its regression failed, and source validation now runs first. Existing dimming
clears on exit without another poll. Query failure preserves recoverable ownership and cues.

The historical initial-paint failure recurred in the masked-focus fixture during this verification.
It now records original writer outcomes and awaits cleanup. The cause remains unestablished;
passing retry is not attribution. Physical Ghostty and the separate partial-mapping status gap
remain open.

## Decodable invalid schedules crash startup or reload

The scheduler decoded schedule.json without calling the existing semantic validator. An enabled
window with start `bad` therefore reached a force-unwrapped time parser. A private startup
regression reproduced the trap at Scheduler.swift:147. Preferences and public validation already
checked time syntax; the file load/watcher path omitted that check.

The scheduler now validates a candidate before adopting it. Invalid rules follow the existing
no-config projection, including continuing manual locks, and status reports schedule rejection.
Saved files are untouched. Startup and watcher regressions verify no invalid pause, unchanged
data, subsequent valid reload and continuing manual locks. All 573 isolated Swift tests pass.
Missing quiet-period bounds and projection/release retries are corrected above.

## Paint failures lack the original writer result

The initial focus fixture recorded thrown errors but not successful `false` returns. Its status
wait also accepted a failed fanout containing `outside`. The late-preview fixture only proved that
open was entered; generic recovery status hid the original error and stage timing.

Both cases now record caller Boolean/error, open result, beforeOpen/prepare entry and outcome,
elapsed time and supplied deadline remainder without logging payloads. The recorder preserves
nil callbacks, exact physical target, non-emergency admission, flags and errno. Successful clear
paths await controller cleanup publication before teardown. Seven fresh-process pairs passed;
the historical first-paint and EPERM causes remain unestablished.

The full TJMEY4 run exposed two other recovery-race failures. Their paused-open barrier included
independent recovery and reset-byte assertions in the original 100 ms device budget. Revision
fixtures now publish once under a bounded call, pause outside the device budget, then invoke the
original preparation with a fresh real writer deadline. Full recover/reset/resume and old-output
rejection remain asserted. Production retains one 100 ms deadline. Four focused and all 570 Swift
tests pass. TJMEY4 also timed out in a subsequent fresh render; that cause remains unattributed.

## Identical catalogue polls discard slow focus preparation

Every catalogue tick incremented the active focus version, even when all rendering inputs were
identical. A color lookup spanning two-second polls could finish successfully and still lose its
version before painting. Two blocked-preparation regressions reproduced missing initial effects.

The controller now coalesces identical in-flight rendering inputs while refreshing catalogue age.
Display-only title changes do not cancel painting. Actual binding, emphasized-set or cue changes
still invalidate work. Heartbeats start after preparation, and each write requires fresh catalogue
coverage. Five regressions cover Manual/Automatic polling beyond six seconds, a new cue, changed
foreground PID and expired coverage without polling. No device deadline was widened.

## Continuing focus reuses its initial configured colors indefinitely

Manual and continuing Automatic runs cached their first configured background/foreground pair.
Subsequent catalogue ticks renewed focus with that old pair, bypassing current lookup failures
and potentially evaluating contrast against an obsolete foreground after a configuration change.
Four controller regressions failed before correction. Removing only the cache would violate
immutable same-ID focus recipe checks; the controller now refreshes once per update and retires
the old lease only when the accepted pair changes. Healthy unchanged recipes keep their IDs.

Lookup failure clears old owned focus through existing cleanup, preserving the logical mode,
working set and cues. Changed colors under a global mask remain ready for later unmasking.
Blocked renewal after Focus Off cannot publish or paint. The old catalogue-failure fixture now
blocks only its initial preparation, allowing the newly required later lookup. Native reload and
readability acceptance remain open. Slow identical polling is covered by the correction above.

## Restore test rejects a legitimate completion timer transition

The completion race fixture compared the entire session-state file while its live timer could
advance `complete` to `idle`. A controlled 2.5-second delay reproduced the original mismatch before
stale restoration was released; state was identical before/after its stale code 3. The same timer,
counter, Stop observation and delivery were preserved. A passing retry alone did not establish this.

The completion case now checks allowed forward state progression, matching priority, nonregressing
time and the exact new live timer. Other cases retain byte equality. Stale code 3, counter,
observation, graduated color and delivery checks remain required. Original deleted case artifacts
prevent definitive attribution of every historical failure; the reproduced mechanism is confirmed.

## Shell startup drops its helper choice inside the loader function

Sourcing the shared selector inside the shellrc loader made plain `typeset +x` localize the cache
to that function. Later registration/current calls therefore probed again and could replace the
chosen backend. The new function-source regression failed before correction. Bash now removes
exports with `export -n`; zsh uses global `typeset -g +x`. Both preserve a private shell-wide cache.

The source check also reproduced a bare-filename loader failure: stripping a directory from
`tavs-shellrc.sh` or `helper-selection.sh` left the filename rather than `.`. Prefixing `./` only
when there is no slash preserves shell source semantics. Both-shell regressions cover this case.
Install and sync now copy every adjacent helper dependency before the standalone entry point;
failed copying cannot publish a new shellrc or fences. A linked helper leaf cannot overwrite
unrelated preferences. Owned Bash/zsh PTYs verify actual installed registration and suspension
without a checkout. Physical Ghostty and Linux acceptance remain pending.
Sync's generic core copy initially preceded the new helper-leaf guard. A linked selection module
regression confirmed unrelated preference overwrite. Guarded helper delivery now runs first.

## Core ordinary routing still requires the native companion

Separate native-only selectors originally prevented standalone hooks from using the portable
helper. The shared selector now chooses a complete native capability pair or portable ordinary
protocol before intake and retains that choice through exec, including failed intake.

Linux still rejected every request. Its scoped generations also failed native schema-1 parsing,
and keys discarded namespace identity. Explicit schema 2 now carries boot/namespace/time-offset
identity through context, records, binding, publication and cleanup. Linux birth uses boot time;
observation wall time stays separately validated. Full scope participates in keys and admission.

Linux roots avoid the Darwin-only temp API. A host reproduction also showed non-strict path
resolution accepting a cyclic private marker path; strict existing-prefix resolution now refuses
cycles/dangling links while allowing missing children. Generic native-format unit fixtures use
explicit platform/identity doubles; separate Linux PTY/hook classes require a real Linux kernel.
Focused format/dispatch checks pass. Broader failures and Linux/native acceptance remain open.

## Portable intent supersession includes a mis-keyed TTY field

The previous latest-intent comparison included current.tty as a reason for authorized delivery
supersession. Native compares delivery ID, producer and device only. A valid-shaped record stored
under the wrong TTY key could therefore permit an older replacement without a new delivery.
Shared bound/unbound ordering now compares the native identity fields; exact observation matching
still includes TTY. The regression verifies refusal and preserves the original record. Unbound
data publication does not authorize painting; existing target/binding proofs remain required.

## Portable dispatcher draft misses EOF, background and path boundaries

The reader checked time before readiness but accepted a delayed EOF after the input deadline.
A deterministic clock/readiness fixture reproduced that acceptance. It now checks time after
wait/read and before EOF. The background wrapper also inherited full render's pre-open revision,
incorrectly suppressing ordinary writes after queued suspension and rejecting unavailable marker
before intent retention. Native ordinary uses current policy; the wrapper now follows that route
while full render/reset stay frozen and reconcile stays strict after open. Owned-PTY regressions
reproduced and verified both branches. Finally, Python 3.11 symlink-loop resolution escaped as a
RuntimeError exposing the path; the fixed private error boundary catches it. The source reports
were preserved separately after two agents wrote the same temporary filename. Routing/capabilities
never used these drafts.

## Portable worker discards stale-record failure identity

The internal worker serialized errno alone, but ESTALE represented both obsolete delivery data
and unavailable targets/owners. Blanket conversion would give incorrect CLI stale code 3 for
target failure, while nonregular synthetic observations incorrectly lost native stale semantics.
Typed stale records now survive the existing IPC alongside delivered-byte counts. Metadata leaf
validation is distinct from storage errors; only synthetic context validation converts invalid
observation data to stale delivery. Regression tests cover worker category preservation, FIFO
observation, storage denial and changed target. No routing used the earlier internal interface.

## Portable no-output draft omits effect-only native identity

Target-only selection dropped native bindings retained solely in valid effect records. It could
cache a plain target instead of the preferred native target and accept two ambiguous native IDs.
Native target selection includes effect targets. The owned-PTY regressions reproduced both gaps.
Identity-only selection now retains valid canonical effect hints while excluding malformed regular
effect/bound data from register/check admission. Current rereads selected slots strictly; ordinary
output guards remain strict. No advertised helper or routing used this draft.

## Portable context draft rejects native opaque response metadata

The first context decoder applied observation control-character policy to optional response IDs.
Native intake accepts bounded, non-NUL response strings and permits ordinary rendering even when
later observation ID validation refuses them. The source-built native helper reproduced a token
with newline/format characters that the draft rejected. Context now preserves the native intake
string contract; strict typed observation validation still rejects that ID. The interoperability
regression verifies both boundaries. No advertised helper or hook routing used the draft.

## Portable forced-reset draft broadens orphan entry

The first renderer treated a same-generation producer on another device as an orphan, allowing
unchanged old bound records to authorize reset. Native entry selects the orphan path only for
missing/replaced generations. The renderer now follows that distinction; a moved-device live
producer must pass ordinary target capture and fails. The regression retained matching old
records, reproduced unintended output and then verified refusal. Direct reset publication keeps
its native invalid-producer contract; entry selection is the additional boundary. No helper
capability or production routing used this draft.

## Portable intent draft rejects before retaining latest

The first publisher validated bound state before writing the requested intent. Its test also
incorrectly expected the previous intent after bound corruption. Native publication retains
valid latest intent first, then reports binding failure. Publication now uses target-only alias
proof and writes latest before strict bound validation. Rendering still checks every control
record. The corrected regression proves retained latest, unchanged corrupt bound state and
refused rendering. Another regression corrected producer validation to occur after observation
reads, preventing a late producer exit from authorizing context. These drafts were not routed.

## Portable record draft skips cleanup after close error

An exception from closing an aborted record write skipped removal of its own sibling temporary.
Native cleanup attempts both operations. A nested finally now attempts unlink after close failure.
The regression injects write and close failures, proves the previous record survives and checks
that only the owned temporary is removed. No production backend used this draft.

## Portable ownership draft reopens directory paths

The first ownership scan held directory descriptors but reopened record files through absolute
paths. A directory replaced only during a read could provide an inactive copy and then return
to its original inode before the final check, hiding an active preview. No production backend
used this draft. Record reads now accept the held parent descriptor, including sibling binding
reads, and final ancestor checks still reject lasting changes. An owned directory replacement
regression verifies that the original active preview refuses output. A separate reader test
verifies the held directory after replacement. Keep enumeration and reads in the same namespace.

## Portable writer draft enters phases after expiry

The unwired Python primitive initially checked after device opening and preparation but not
immediately before them. Delayed inspection or lock acquisition could therefore start late
opening or metadata preparation. Owned tests with delayed termination reproduced both actions.
The same absolute deadline now gates both entries. Child standard channels are closed so a
wedged worker cannot retain the hook's original pipes. Retirement is checked separately in tests.

Unannotated failures after output could also falsely report zero written bytes. They now report
unknown, while caught partial writes retain their count. A dedicated `bytes_written` attribute
avoids assigning None to Python's integer-only OSError `characters_written` property. Full
policy/record/lifecycle integration and Linux runtime validation remain required before release.

## Standalone hooks discard legacy metadata without the native companion

Organizer intake initially returned empty/default metadata when its native capability was absent.
That removed legitimate permission-mode, session/thread, directory and transcript behavior from
standalone or older installations. Intake now selects a bounded Python 3 metadata reader before
consuming the payload. Only four allowlisted fields reach core; no native context or automatic
cue authority is claimed. Native failure is explicit and is never reparsed by the portable path.

Absent/older-companion regressions failed before this change. Tests cover decoded paths, nested
body privacy, malformed/oversized/control data, an input pipe withholding EOF, missing runtime,
inherited-state clearing, failed native intake and copied installations. Sync ships the reader
and propagates copy failures. Ordinary terminal rendering without the native helper is a separate
remaining compatibility defect; this metadata correction does not close it.

## Replacement preview races its own cleanup

The start and clear queues could contend for ordinary admission on the same healthy target.
An owned PTY with finite cleanup reproduced `EBUSY`, no replacement paint and unchanged effect ID.
Per-physical completion now orders replacement before admission, within the original writer budget.
Different targets and successive cleanup batches progress independently; aliases retain grouping.

A serial-batch draft blocked healthy B behind unrelated A. A corrected fixture reproduced that gap.
A further timeout case showed a failed successor discarding its still-running predecessor. Completion
now retains that dependency through notification, while returning the bounded failure immediately.
Four controller regressions plus a fanout callback test cover finite cleanup, cross-run independence,
cancellation, timeout ancestry and fresh operation after drainage. Historical failure attribution
remains unproven; this corrects reproduced mechanisms without general retries or deadline changes.

Two preview fixtures also identified held cleanup solely by call order across concurrent queues.
A color-preparation barrier now establishes that role before replacement native work. Gates wait
for explicit release, rather than expiring during assertions. A supplied cleanup queue lets tests
barrier-drain queued work before teardown; failed prerequisites stop dependent no-paint assertions.
A teardown failure was observed before adding those drains. Its exact cause and the earlier
deadline failures remain unproven. Injected-error checks now identify the actual error and elapsed
time instead of accepting every thrown error as the intended device failure. Writer limits stay fixed.

## Preview preparation consumes its display lifetime

Selection started both the timer and effect heartbeat before configuration/target preparation.
A three-second virtual preparation reproduced no paint, expired replacement selections and lost
failure reporting. Preparation now stays cancellable by identity; successful acceptance freezes
one display-start timestamp for the effect and timer immediately before painting. Late timer setup
uses the remaining duration. Configuration failures stay visibly unavailable without an active cue.

A source follow-up found that an accepted start could expire before its timer was queued, leaving
the UI active indefinitely. A deterministic clock reproduced missing cleanup. Every accepted start
now queues exact-ID expiry before the paint-age check. Five new tests cover slow preparation,
replacement, failure, delayed setup and already expired starts; existing cancellation checks remain.
The clock fixture serializes its boundary so concurrent worker/main reads cannot defeat the test.
Fresh configuration validation remains intact. No persistent cache or native timing claim is added.

## Preview expiry erases delivery feedback

Automatic expiry used the normal Clear path, replacing successful or failed delivery results with
No preview. A selected row could therefore appear to have done nothing after a failed write.
Expiry now retains its run's result while ending the effect and scheduling the existing cleanup.
An unfinished result is reported as unconfirmed; late completion cannot overwrite it. Explicit
cancellation resets the text. Typed timeouts retain finite reasons without exposing raw paths.
Mocked failures, delayed completion, successful expiry and obsolete timer tests cover the change.
Native acceptance also exposed denied inspection of a privileged login parent. That binding defect
remains open; feedback retention is not its fix.

## Per-terminal lookup scans unrelated cache records

Both normal and exited-producer target resolution recursively scanned every retained TTY bucket.
The existing TTY partition now limits those two lookups while retaining all same-TTY owners,
aliases and effects. Recovery continues scanning all records. Three regressions cover partition
isolation, effect-only bindings, missing buckets, link rejection and malformed/misplaced records;
existing recovery tests additionally reject conflicting owners and native aliases.

The new descendant-link case also exposed `skipDescendants()` pruning the next real directory
after a symlink. A local Foundation probe reproduced missing healthy target records. Enumeration
already does not follow symlinks; recording the link as unreadable without calling that method
preserves healthy records. Both scoped and full snapshot assertions prevent recurrence.

## Adapter exec repeats an already verified organizer probe

Normal hooks launched six helpers because private capability state disappeared at exec. Successful
intake now transfers its positive cache through the existing script exec; core validates selection
and removes export attributes before children run. Incoming adapter cache is cleared. Native managed
validation and real output calls remain independent. Tests cover one organizer probe, fixed arguments,
empty stdin, raw OS argv disposal, child privacy and rejected inherited cache. Failed intake still
reprobes. A Bash-c/source candidate broke timer PID liveness and was rejected before commit.
Measured owned-terminal helper counts fall from six to five; shell startup remains three calls.
The old submillisecond/zero-fork claims are corrected. Small samples do not prove general latency.

## Sync claims hook readiness while the required helper is unavailable

Sync copied updated hooks without building the helper, then always suggested submitting a prompt.
Absent or older helpers drop current managed rendering and metadata, so source-copy success did
not establish hook readiness. Sync now checks both exact capabilities and emits a separate warning
without exposing probe output or isolated launch keys. Successful copying still returns zero;
copy failures retain nonzero status. Tests cover missing, unsupported and render-only helpers.
The broader standalone macOS/Linux rendering regression remains open. The approved implementation
uses a Python 3 standard-library helper; this first slice restores legacy metadata only.

## Scheduler delivery failures disappear without a visible retry path

Broadcaster results had no production consumer. Unchanged pause/lock evaluations skipped paint
even after a failed target, and later registration/no-output success could obscure that failure.
Main-thread callbacks now expose earlier failures and native-coverage limitations in the menu;
logs contain counts only. Failed exact bindings stay retained until restored or confirmed vanished.
The existing heartbeat retries active restriction paint on those targets alone, with queue
coalescing and current policy checked by the bounded writer. Healthy terminals are not repainted.
Release/suspended failures remain explicit recovery retries: automatic palette resets could erase
new hook colors. Tests cover publication, targeted recovery, retention, coalescing, suspension and
unbound targets. Earlier-failure wording avoids asserting a current fault after independent recovery.

## Scheduler reconciliation undoes emergency recovery defaults

After suspension, scheduler release and startup cleanup recomposed retained ordinary backgrounds.
Canceled global records and caller reset flags also reset freshly restored hook colors. Disabled
reconciliation now distinguishes remaining active paint from canceled ownership under the shared
writer lock. Canceled records alone produce no output; residual restrictions clear to defaults.
Current suspended previews retain normal background-only composition and clearing. An unavailable
marker cannot exempt preview ownership merely because its inode still matches. Active-mode release
and legitimate hook renders keep their existing behavior. Regressions cover repeated/delayed clears,
startup, fresh complete renders, preview expiry, unavailable markers and post-open suspension.
Canceled ownership is not proof of repaint; failed emergency recovery still needs explicit retry.

## One failed focus target rotates healthy ownership and grows cleanup

Focus renewal used one heartbeat for the entire catalogue. A failed target prevented it from
advancing, so healthy targets acquired new IDs and old cleanup accumulated every six seconds.
The controller now keeps one lease per physical target, invalidates retiring predicates and
coalesces each lease's clear. Unknown cancellation blocks replacement; acknowledged cancellation
can transfer remaining repaint work to a current request. Healthy IDs and heartbeats continue.
Regressions cover twelve two-second refreshes with a failed peer, six explicit mode changes,
recovery and preserved working membership. Alias conflicts are rejected before request creation.
Focus restoration emits only background bytes, including after a global rule ends; ordinary
reconciliation still resets legacy foreground/palette. Suppressed restoration cancels without paint.

## Unrelated focus cleanup delays a healthy preview clear

Preview and focus retirement shared one serial cleanup queue. A stalled focus target therefore
prevented a healthy terminal's preview clear from starting, despite independent device fanout.
Dedicated queues now separate those batches while the shared per-TTY writer still orders actual
conflicting output. The regression holds one focus cleanup, clears a preview on another owned
PTY before releasing it, and checks exact background reset plus canceled preview metadata.
The later per-target lease correction above bounds retained ownership without dropping old IDs.
The internal clear callback now distinguishes successful locked metadata cancellation from
failed or suppressed physical repaint. Tests cover failures before/after that stage, marker
replacement, global masking, unknown aliases, the original deadline and physical deduplication.
Callback absence cannot prove no save, because record rename precedes a final deadline check.
The controller retains uncertain cancellation until a later locked acknowledgement or recovery.

## Repeated timeouts accumulate native device workers

The 100 ms writer deadline returned control while a kernel-stalled open continued on its worker.
Every later retry could start another open for that same terminal. Process-wide admission now
retains one ordinary slot for the validated physical lifetime until actual worker cleanup. Native
aliases share a slot, and an old completion cannot free a different owner's slot after TTY reuse.
Unresolved/raw requests share normalized path admission with known calls. Available metadata
publishes before busy rejection, preserving the latest ordinary intent and exact-ID cancellation.

The first implementation also excluded same-process recovery while an ordinary open was held.
Full-suite failures exposed that conflict. A separate single emergency-reset slot preserves an
independent recovery attempt with the same output lock, target checks and original deadline.
Repeated recovery retries cannot multiply that slot. Recovery blocked after open remains partial.
Owned-PTY tests cover repeated opens, metadata updates, healthy fanout, aliases, lifetime reuse,
blocked preparation, both lanes and late-output rejection. Cleanup waits for actual slot release,
not the injected open callback's return. Retained focus cleanup and arbitrary callback/global
worker limits are separate unresolved review concerns; this correction does not claim those fixed.

## Recovery misclassifies closed registry hints and hides live hints behind vanished owners

Registry-only candidates always failed, even when the device was positively absent. Malformed
names also set a whole-directory failure. Recovery now distinguishes proven node loss from
unavailable/live hints and reports malformed entries individually, preserving healthy fanout.
Hints remain observational and cannot authorize device output. Reporting deduplicates an existing
native binding failure without hiding it behind a successful cached TTY. A focused source check
also found that a vanished cached owner hid a still-live hint. Such hints now remain failed;
only additional device-loss proof avoids that failure. Tests cover private malformed entries,
closed/live hints, owner exit, contradictory metadata, native capture failure and owned-PTY reset.

## Automatic focus loses cues when coverage is temporarily unavailable

The reducer cleared nil coverage, and a Boolean final-source check acknowledged every captured
cue when none could be verified. Unavailable process data therefore erased unresolved attention.
An all-High catalogue skipped the writer predicate entirely, retaining known exits. Unaffected
write results also advanced the heartbeat without proving metadata renewal, risking expired-ID
reuse after recovery. The reducer now preserves unknown cues and occurrence history. Source
validation distinguishes unavailable from positively vanished lifetimes, checks before fanout
and at final output, and resolves only exact proven snapshots. Independent positive evidence
survives uncertainty or a later inspection timeout. A post-save callback reports real renewal,
including globally masked focus; rejected writes do not extend ownership. Status exposes missing
renewal. Regressions cover gaps, permission episodes, mixed sources, all-High catalogues,
prolonged rejection, masked renewal and deadline ordering with private roots and owned PTYs.

## Priority integration tests select the installed helper and require removed replay files

The priority fixture's child `env -i` discarded the explicit source-built helper. Its regular-file
TTY stand-ins, unsupported mute reason and pending-file assertions also bypassed the current
typed-intent contract. The suite now requires the isolated runner, inherits its explicit helper
and private roots, uses owned PTYs and a valid pause, and retains diagnostic captures. Tests cover
latest intent, simultaneously live independent terminals, pause precedence and no historical
title/bell replay on resumption. A child environment check prevents helper/root regression.
BEL assertions distinguish OSC terminators from standalone alert bells. The repaired suite and
the connected isolated Bats audit pass without invoking the installed app or any user terminal.

## A successful empty catalogue preserves confirmed closed sessions

The Sessions model treated `.success([])` as unavailable and retained rows, priorities, Manual
membership and Automatic cues. Enumeration already reports unavailable access as a failure;
zero surfaces is a valid successful result. Empty success now uses ordinary reconciliation,
clears previews/selection/priorities, ends the last Manual set and clears closed cues while
Automatic stays armed. Activation is disabled with no surfaces. Native failures still retain
last-known display and priorities. Regressions reproduced retained state and disabled-control
failure; the mock lifetime/writer setup cannot open any real device.

## Idle timeout cleanup rejects an exited agent despite a live continuing shell

The forced reset required the inherited producer to remain live. After an unexpected agent
exit it rejected the reset, ended the timer and retained the idle color on its continuing shell.
The existing typed reset now resolves an orphaned request through the cached target. Under the
same output budget it requires a valid continuing owner, unchanged observation delivery and
latest intent previously bound to that owner. It retains the same checks during final preparation.
Existing intent must match even while the producer is live, before the first metadata publication.
This prevents a newer standalone intent from being erased before the producer exits during open.
Missing bound intent, newer observation or standalone intent, and owner reuse refuse output.
The reset also shares the queued-render revision check, preventing a late directory-title replay
after recovery. Owned-PTY regressions verify cleanup, those refusals and recovery ordering.

## An idle notification leaves its timer on the completion delivery

Adapter intake publishes a new idle delivery. Sending only a skip signal left the old timer
carrying the completion delivery, so its next paint was correctly rejected and progression ended.
The idle branch now retires that timer and starts one with the current context at the first idle
stage. The worker accepts an internal `idle` start argument without repainting completion.
An owned-PTY regression verifies the notification's delivery reaches a later graduated color;
connected timer, mute and managed-render checks still pass.

## A delayed tool-error restore cancels a newer completion timer

A newer hook could arrive after restore precheck; stale handlers then killed its timer, changed
session state or incremented its subagent count despite rejected output. Synthetic restores now
skip those mutations and new-prompt identity work, while final managed validation rejects stale
batches. Real-helper barriers verify unchanged state/count/observation and later timer bytes.
A separate single helper failure could abandon current restoration. The worker now retries
code 1 once after 50 ms, checks context again and stops at stale 3. Synthetic core returns its
render status so render failures can retry; ordinary hooks retain exit 0 on render failure.
Seven regressions cover retry, stale/error limits and statuses. Owned-PTY checks wait for the
expected processing bytes with the producer alive. Persistent failures remain possible; the
historical missing restore is not attributed to a captured helper failure.

## A queued ordinary render replays titles and bells after recovery

Recovery preserves typed observations and background intent. The full-render validator therefore
accepted a hook paused during device open after suspension replaced the marker, replaying its
palette, title and bell after the reset. Full renders now pin the marker before device open within
the existing writer budget and compare it under the output lock. Replacement yields no output,
including after explicit resume. A barrier regression reproduces both cases and verifies that a
fresh hook can still render normally. Typed intent is retained without replaying style history.

## An emphasized shell can outlive the agent that authorized Automatic focus

The initial Automatic integration reused Manual's any-emphasized-binding guard. If a cue's
producer exited during queued color lookup, another High plain shell still passed that guard
and allowed new outside dimming. A regression kept the cue's continuing shell owner alive,
removed its producer and reproduced a new focus record and output on an owned Normal PTY.
Automatic now validates actual cue producers and their own bindings at the managed decision,
using the original deadline without nested coverage locks. Zero valid sources release old effects.
The post-lookup run/version check also prevents Focus Off during the final metadata check from
authorizing late paint. Tests cover producer reuse, device mismatch, backgrounded retention,
separate continuing ownership and identical deadline forwarding. Budget expiry preserves cues.

## Generic notifications are misclassified as permission requests

The attention classifier accepted permission state with a generic Notification event. Intake
requires a recognized permission_prompt subtype, so the generic event alone supplies no request
authority. Eligibility now requires PermissionRequest or permission_prompt; legacy generic records
remain diagnostic. A red/green correlation regression covers generic, idle and supported events.
Adapter fixtures also check state/event pairing, fresh delivery IDs and discarded payload bodies.

## Unmapped outside surfaces falsely keep a manual paint ID fresh

The controller initially advanced its common heartbeat when no mapped target reported failure.
An unmapped outside row produced no failure item even though its saved lease was not renewed.
After remapping, the controller reused an expired ID that the writer correctly rejected.
Heartbeat now advances only when every outside row is mapped and every delivery avoids failure.
A virtual-clock/owned-PTY regression reproduces expiry through repeated unmapped catalogues,
then verifies immediate fresh-ID ownership after remapping. Failed/empty catalogue tests also
check that queued and coalesced work cannot paint after native coverage becomes unavailable.

## Recovery releases a preview's revision before pending metadata cleanup

Recovery invalidated the in-memory preview and discarded its pinned marker revision. A partial
device failure could leave the old record active while subsequent atomic marker writes reused
an unpinned inode. Retired preview runs now remain in pending cleanup, and exact-ID cleanup
cancels metadata before device open. Changed revisions suppress visual repaint. A controller
regression checks repeated replacement, retained mismatch and cleanup with no emitted bytes.
Manual runs now preserve the same pin lifetime while effects or pending cleanup remain live.

## Synced installations retain stale or non-executable entry points

Sync omitted the root dispatcher, Codex adapter/installer, hook definitions and plugin shellrc.
Copying subcommands alone left recovery unreachable or reinstalled old lifecycle code. Existing
0644 targets also kept that mode after plain cp. The connected files now copy explicitly, their
required directories are created, and direct entry points regain execute permission.
Required operations propagate errors even when Bash errexit is suppressed by a conditional
caller. Seven fake-install tests compare bytes, execute copied CLI/adapters/installers, preserve
user state, refuse missing helpers and inject a copy failure. No real installation was modified.

## GUI recovery loses partial reports or its isolated target scope

The existing code-zero process API discarded stdout on exit 1 and capped requests at two
seconds. Independent recovery needs its JSON even on partial failure and can outlast discovery.
The GUI client now persists suspension first, probes the current bundle's capability, and keeps
valid exit-1 reports within a separate ten-second process bound. Device writes retain 100 ms.
Tests cover persistence before probing, missing helpers, unsafe roots and partial reports.
Fixture GUI launches derive explicit IDs when absent and preserve any supplied narrower scope.
They do not invoke a native catalogue or silently widen recovery to real terminals.

## Concurrent terminal registration fails on a shared parent directory

Different TTY writers created the common targets directory after separate absence checks.
One then failed directory creation and reported unavailable storage, losing a multiselection cue.
The controller test reproduced this; pre-creating only that shared directory removed the failure.
Creation now accepts a directory another writer created, then repeats type and deadline checks.
Symlinks and non-directories still fail. A stress regression caches 32 targets in four fresh
roots; the full 434 Swift tests pass.

## Preview record rewrite can extend its expiry

The initial preview foundation rejected heartbeat refresh, but the generic same-ID save path
still accepted a new timestamp. A regression reproduced the changed expiry with two failed
assertions. Preview saves now preserve the original timestamp for that ID; a new selection uses
a new ID. The normal six-second selective lease keeps its existing heartbeat behavior.
Tests cover both renewal paths, expiry and controller exit, with 416 Swift tests passing.

## Failed device entry drops ordinary background intent

Intent publication ran only after device open and output-lock acquisition. A failed or wedged
open therefore discarded the requested color or reset, leaving recovery to restore older state.
The managed writer now publishes and binds validated semantic intent before open, releasing its
record lock before device entry. Preparation repeats stale validation under the output lock.
Publication, open, lock and paint share the original 100 ms deadline; no second budget is added.

Device failure still reports failure. Publication-lock contention can exhaust that budget before
intent is saved, and is reported honestly. Regression tests cover retained color/reset, late open,
output-lock failure, stale/malformed reset, style-only preservation and newer intake during open.
The full 405 Swift tests pass. These checks use owned PTYs and injected identities.

## Ordinary style escapes the managed background transaction

A hook checked suppression, wrote its background through fresh managed policy, then emitted
palette/title/image/bell bytes directly using the old check. A newly active restriction or newer
synthetic delivery could be overwritten. The complete current render is now validated and
composed in one managed transaction; current restrictions replace all queued ordinary styling.
Style-only requests do not publish or reset background intent, and do not read unrelated corrupt
intent when no controlled background needs cleanup. Whole-batch stale rejection preserves intent.

Typed entry, policy-flip, selective-overlay, stale-batch and style-only tests pass with the full
390 Swift suite. The actual helper's owned-PTY rule-flip and superseded-batch tests also pass.

## Plain and native aliases compose different visual state

Hooks bound intent to a plain target while native registration used a separate alias. Recovery
could write two different backgrounds into one terminal, and ordinary hooks missed a native
selective lease. Composition now reads validated equivalent bindings of the same TTY, device
and continuing owner, with one physical write/report and exact scope checks. Recovery cancels
matching alias effects under its existing lock. Multiple live native IDs remain unavailable.

Proven owner exit or changed generation is vanished; unavailable metadata is still a failure.
A related legacy adoption leak let a changed owner reuse an old producer's color. Live adoption
now snapshots the exact owner-bound intent; unbound fallback requires a live matching owner.
Producer exit preserves the original owner's bound copy, while a new owner cannot inherit it.
Twelve regressions and the full 379 Swift tests pass without schema or deadline changes.

## Suspended relaunch skips retained-effect cleanup

The scheduler skipped discovery and transition cleanup when suspension disabled restrictions.
That was appropriate for the old raw broadcaster, but it also skipped the new safe cached-effect
cleanup after a failed recovery repaint. Startup now always requests typed reconciliation, and
cached effects clear before optional native discovery. A transition into suspension also requests
safe cleanup after saving the new projection. Tests cover active, suspended and unavailable states
with blocked native discovery, saved definitions and no restrictive disabled paint.

## Shell suppression accepts invalid soft-pause liveness

The legacy shell gate accepted absent PID/heartbeat fields and future heartbeat timestamps.
It could suppress ordinary signals while the managed Swift writer considered the rule invalid.
The shared gate now requires a live positive PID, valid decimal times and a nonfuture heartbeat
within 120 seconds. It preserves legacy absent-schema handling and rejects explicit invalid
schemas. Isolated regressions cover the rejected metadata and hard-mirror expiry/grant behavior.

## Synthetic styling confuses producer and shell owner

An agent observation names its producer generation, while the managed target retains the
continuing shell owner's generation. Requiring equality rejected valid background-disabled
idle styling from an agent child. Validation now binds the target by TTY/device and verifies
the producer independently against the latest live observation. A regression reproduces an
agent under a continuing shell owner and proves validation produces no paint or cached target.

## Startup resets unaffected shell backgrounds

Registration followed by unrestricted reconciliation painted OSC 111 into newly discovered
plain shells. Startup now registers without paint and reconciles only cached effect targets.
An inactive global effect still requires palette/foreground cleanup because cancellation can
succeed before device output fails. Owned-PTY regressions cover both cases and preserve the
background of an untouched shell. Broadcaster routing and startup checks pass with 340 Swift
tests; headless and shell integration remain in progress.

## Suspension loses the rule needed for independent resume

The scheduler's suspension override writes effective MUTED=false. A current-rule reader then
cannot distinguish that override from an inactive soft rule. Schema 1 now retains requested
mute and hard/soft cause fields, with the requested rule's finite expiry and resolved colors.
The persistent marker still disables all restrictions before those fields are considered.

The old unmute path also cleared visuals before writing the new projection. Managed output
would read the old rule and could repaint it. The scheduler now saves both projections before
requesting reconciliation. Two regression cases exposed five assertions, then an expiry check
caught two more. All 47 related and 353 full isolated Swift tests pass. Production routing and
physical recovery remain unfinished.

## Headless catalogue needs an off-main completion

Waiting on `GhosttyCatalog.refresh` from headless main would block its main-thread callback.
The new synchronous `snapshot` explicitly enqueues enumeration on the existing native queue
and publishes its result through a semaphore, sharing request bounds and target filters.

The first implementation used `queue.sync`. Its test caught native work executing on main.
An explicit asynchronous enqueue fixes that contract; no native result callback needs the UI
event loop. Two new cases pin off-main work, dedicated scope, denial and application reuse.
All 14 catalogue and 314 full isolated Swift tests pass. Live Ghostty remains unverified.

## Writer race fixture waits past its real deadline

The full Phase 6 Swift run exposed a timeout in the paused-open test despite all store cases
passing. Its XCTest main-loop wait and suspension write occurred inside the real 100 ms writer
budget. The fixture now waits directly on a semaphore for the open barrier. No production
deadline or rejection assertion changed. Focused 57 and full 312 isolated Swift tests pass.

Keep failure logs when a timing test fails, and remove harness scheduling latency before
considering a timeout change. A timed-out writer must still reject late bytes and release its
owned resources.

## Suspension readers and policy projection

Treating suspension as an ordinary unmute would reset colors and replay opaque pending output,
including old titles/alerts. The scheduler now evaluates saved rules and expiries normally,
then disables their visual projection and skips every broadcaster path while suspended or
unavailable. Configured master activation is separate from effective mute, so menu controls
still edit the intended saved state. Independent physical recovery remains a later phase.

The shell reader initially treated inaccessible parent directories as missing active state.
An isolated permission test reproduced the mismatch with Swift. Both readers now distinguish
inaccessible/non-directory/dangling parents from an absent marker beneath accessible parents.
Canonical schema fixtures cover both shells and Swift without executing marker content.

The private app initially used a marker beside its priority file rather than under its private
HOME. A red fixture test exposed that discrepancy; explicit injection now matches
`root/home/.tavs/visual-restrictions.state`. Suspension survives relaunch and remains visible
even when catalogue refresh fails. Focus stays Off after explicit resumption.

Mute debug logging had a fixed `/tmp/tavs-mute-trace.log` sink. A source-only red assertion
avoided writing there, then the corrected logger was exercised in an injected private runtime.
This preserves test isolation without changing unrelated existing diagnostic files.

Verification: 288 Swift tests, 55 suspension/gate Bats cases, 55 earlier Bats regressions and
230 audited Python cases pass. Computer Use checked the private Sessions banner, relaunch,
unavailable state and resumption. Real menu rendering and physical recovery remain unverified.

## Organizer intake and restoration defects

The old Codex notify command let Bash consume appended JSON as `$0`. Direct argv now supplies
the adapter's second argument, with root TOML placement and escaping verified in private files.
Existing multiline notify arrays are refused before mutation instead of being partly replaced.

Core debug logging previously retained full hook JSON, free-form arguments, stdin, titles,
directories and process arguments. Intake now discards bodies and debug sinks retain fixed
metadata only. Decoded session/thread identifiers reject terminal and line control characters
before they reach title composition or identity state. A complete pending-byte capture exposed
the regression; a regular-file capture contained only the final bell and missed prior writes.

Debug appends also followed linked sinks, stalled on a FIFO and inherited public file modes.
One shared append helper now checks trusted parents, regular owner/mode metadata and link count,
creates private output and preserves optional logging failures. A debug-only hard-link check
prevents appending into an outside file sharing the inode. Existing formats and filtering remain.
Isolated regressions cover these failures and a real core title trace; same-user path races remain
outside this static correction. [Source/results](specs/tavs-priority-discovery_2026-10-04/legacy-policy-trust-source-check-2026-10-15.md#optional-debug-sink-trust-2026-10-15).

Late background rendering could overwrite a newer intent by using its newer render timestamp.
Publication now compares frozen intake time under the same per-TTY lock. Idle and delayed
error rendering preserve observation bytes and delivery identity. Standalone background writers
inspect their own process before ancestors and can retain intent without inventing an event.

Independent review confirmed that Claude's native installer resolves `claude` to a version
filename. Verification now recognizes resolved provider command paths while rejecting generic
interpreters and retaining generation/device/foreground checks. Damaged regular latest records
can be replaced by fresh legitimate publications; synthetic writes and corrupt native adoption
bindings remain fail-closed. Special-file replacements remain refused.

Verification: 273 Swift tests, 55 isolated Bats cases and 230 audited Python cases pass.
Computer Use confirmed coverage labels and failed-refresh retention in the private fixture app.
Real provider hooks, Ghostty rendering and later recovery/focus ownership remain unverified.

## Test and development failures

Isolation, PTY lifetime, recovery fixtures, app replacement, installer status and launch corrections:
[details](BUG_REFERENCE_appendix_test-isolation-and-development-launch.md). Native acceptance is pending.
The [valid `/tmp` alias correction](BUG_REFERENCE_appendix_test-isolation-and-development-launch.md#isolated-launch-rejects-the-valid-tmp-alias)
is resolved.

## Legacy shell state and registration

Shared snapshots lost TTY rows; inherited `$$` temporary names collided. Private unique staging and
[stable table locks](reference/architecture.md#session-statesh-state-management) serialize updates.
Raw registry publication followed links before validation, truncating content or changing timestamps.
[Managed startup](API_REFERENCE.md#standalone-shell-helper-delivery) now owns registration; mute init
resolves its runtime path. Owned-PTY checks cover registration.
Raw legacy policy reads also accepted links/writable files and could block on a FIFO or parse
unbounded content. The shared checked reader rejects these static cases and NUL bodies, and
retains trusted absence separately. CLI errors preserve definitions instead of claiming no lock
or allowing a schedule edit. Recovery bypass and missing-final-newline compatibility are tested.
Path/open races, debug writes and portable write serialization remain open.
Isolated Homebrew Bash 5.3.15 runs also expose exit139 after valid marker reads. A matching-time
SIGSEGV report reaches locale restoration through libintl/CoreFoundation. System Bash and an
explicit C-locale control pass; a minimal locale-only probe does not reproduce the crash.
The [source/results](specs/tavs-priority-discovery_2026-10-04/legacy-policy-trust-source-check-2026-10-15.md#checked-legacy-rule-snapshots-2026-10-15)
retain this compatibility failure without attributing all historical failures to it.

Zero-prefixed lock times were treated as octal; oversized durations could wrap into valid small
values. Portable merge could consequently shorten a longer saved lock. One shared decimal
normalizer validates the Int64 domain before arithmetic; duration products/sums and absolute
ends are checked, and remaining-minute display avoids adding59 near Int64.max.
A source check caught the new invalid-clock branch bypassing the schedule gate. Its regression
reproduced a changed schedule; failed normalization now reports unavailable after recovery's
bypass. Numeric boundary, grant, merge, display and interactive-duration checks cover these cases.

## Portable policy accepts unsafe storage or loses error meaning

Bounded no-follow reads omitted UID/write-bit and directory ancestry checks; marker absence and
revision identity could therefore accept unsafe storage. Policy checks now enforce native-style
trust, including checked aliases, without repairing existing objects or creating missing parents.
The shared regular reader also rejects unsafe typed-record leaves as EACCES, preserving the
difference between untrusted storage and repairable malformed content. A late I/O failure cannot
be swallowed as disabled restrictions after the original deadline. Regression details and remaining
Store-write/ancestor-race limits are in the [source check](specs/tavs-priority-discovery_2026-10-04/legacy-policy-trust-source-check-2026-10-15.md#portable-policy-storage-trust-2026-10-15).

## Portable CLI lock updates overwrite a newer accepted definition

The portable writer replaced complete files atomically but read/merge decisions were outside
any shared mutex. Two successful commands reproduced an accepted eight-hour lock being replaced
by a stale four-hour update. Grants had the same post-challenge race. Both operations now use
one trusted read/merge/replace transaction with the stable lock-state mutex. The native route
is preserved. A new dependency is also copied into installed CLI trees.

Eleven helper cases cover merge/grant, concurrent writers, contention, unsafe storage and
cleanup failures. Two injected close failures exposed incorrect failure-after-commit reporting
and a leftover owned temporary; both are fixed. Real CLI mutex and copied-installation cases
guard the integration. Verification and preserved failed runs are in the
[source/results](specs/tavs-priority-discovery_2026-10-04/legacy-policy-trust-source-check-2026-10-15.md#portable-lock-mutation-transactions-2026-10-15).

## Portable publication accepts unsafe parent directories

A missing observation bypassed existing-record checks, allowing its mutex and new record under
a writable runtime. Typed replacement also accepted unsafe directories or destination ownership.
Shared directory opens now check ancestry, EUID and write bits; mutex creation checks ancestry
first. Replacement revalidates every held directory and the regular destination before committing.
A source check exposed an intermediate-directory staging race; its regression proved that the
initial fix reported failure after changing bytes. The complete pre-replacement check fixes it.
Tests preserve accepted bytes on rejection, permit read-only group access and cover real
observation publication. [Source/results](specs/tavs-priority-discovery_2026-10-04/legacy-policy-trust-source-check-2026-10-15.md#portable-record-publication-trust-2026-10-15).
