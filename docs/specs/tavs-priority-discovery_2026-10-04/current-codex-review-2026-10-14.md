# TAVS current implementation Codex review

Last Updated: 2026-10-14T12:31:58
Version: 1.3

## Invocation and result

- Wrapper status: SUCCESS. All three canonical provider passes completed and were evaluated.
- Review target: current tracked implementation at commit `7ecfba2`, file mode, full depth.
- The checkout was clean at dispatch and remains clean at final inspection, with HEAD `7ecfba2`.
- Scope: three caller-supplied cohesive partitions (20, 32 and 66 target entries).
- Focus: all nine PLAN phases against SPEC D01-D18, exact native targeting, reversible
  visual-only composition/recovery, observation occurrences, delivery and existing compatibility.
- Repository read-only: no edits, builds, tests, native requests, app/container launches,
  installations, real-home operations or terminal output. Wrapper writes stayed under `/tmp`.
- No other reviewer output was read. No provider failure, restart, automatic continuation
  or silent scope reduction occurred. The first two providers attempted a report write that
  their read-only sandbox rejected; they returned complete final reports and exit/lifecycle
  checks passed. Raw output retains those messages. The runner persisted all report evidence.

## Canonical reports and execution

| Partition | Raw and evaluated report | Evidence | Thread |
|---|---|---|---|
| Native catalogue, Sessions and focus | [codex-review-files-terminal-agent-visual-signals-tavs-native-sessions-focus-20261014_113807.md](/private/tmp/codex-review-files-terminal-agent-visual-signals-tavs-native-sessions-focus-20261014_113807.md) | [codex-review-artifacts-files-terminal-agent-visual-signals-tavs-native-sessions-focus-20261014_113807](/private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-native-sessions-focus-20261014_113807) | `01a139c6-bb39-7a73-8f47-516517ceb218` |
| Visual state, recovery and scheduler | [codex-review-files-terminal-agent-visual-signals-tavs-visual-state-recovery-20261014_115422.md](/private/tmp/codex-review-files-terminal-agent-visual-signals-tavs-visual-state-recovery-20261014_115422.md) | [codex-review-artifacts-files-terminal-agent-visual-signals-tavs-visual-state-recovery-20261014_115422](/private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-visual-state-recovery-20261014_115422) | `01a139d5-9b0e-7af3-91fa-6f4dacb33797` |
| Ordinary hooks and shell delivery | [codex-review-files-terminal-agent-visual-signals-tavs-ordinary-shell-delivery-20261014_121013.md](/private/tmp/codex-review-files-terminal-agent-visual-signals-tavs-ordinary-shell-delivery-20261014_121013.md) | [codex-review-artifacts-files-terminal-agent-visual-signals-tavs-ordinary-shell-delivery-20261014_121013](/private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-ordinary-shell-delivery-20261014_121013) | `01a139e4-228b-7f60-9397-82e2ddefa8be` |

- Requested/default delegated engine: Sol; configured model: `gpt-5.6-sol`.
- Requested level/floor and effective effort: full/xhigh throughout; no effort increases.
- Profile: canonical `code-review`, include-all-confirmed noninteractive policy.
- Original start: Unix `1791970687.162588`; whole-review allowance: 7200 seconds.
- Provider completion elapsed from that shared start: 2899.409 seconds (48.32 minutes).
- Serial partitions shared the original clock using `--previous-report`; no fresh budgets.
- Model/effort are configuration evidence, not server attestation.

## Evaluated findings synopsis

Counts: **CRITICAL 2, IMPORTANT 8, MINOR 1**. All 11 raw findings received a verdict.
One severity was upgraded; the installer false-success subclaim in partition 1 was technically
falsified for the normal CLI entry. No host-only finding was added.

| ID | Severity | Checked mechanism | Smallest direction |
|---|---|---|---|
| N1 | IMPORTANT | Cached rows authorize effects without a fresh native ID/TTY mapping | Fresh bounded native snapshot after color preparation, before capture/fanout |
| N2 | IMPORTANT | App destination is removed before replacement copy | Stage and validate before retiring prior bundle |
| N3 | MINOR | Automatic help names permission but omits completion | Describe both supported High-priority triggers |
| R1 | CRITICAL | Enabled decoded bad time reaches a forced parser | Validate loaded config; reject safely; eliminate trapping parser path |
| R2 | IMPORTANT | Failed projection commits transition/paint memory; no later repaint | Make persistence outcome visible and missed transition retryable |
| R3 | IMPORTANT | Enabled quiet rules without bounds validate and do nothing | Require kind-specific bounds for enabled rules |
| S1 | CRITICAL | Linux ordinary signaling cannot select a usable backend | Complete Linux generation/TTY proof and typed renderer, then kernel/PTy tests |
| S2 | IMPORTANT | Predictable runtime root lacks owner/mode/ancestor-link trust | Reject untrusted roots before policy read/registry/output |
| S3 | IMPORTANT | Child installer ignores subprocess failure and prints success | Explicit preview/apply status checks |
| S4 | IMPORTANT | Shared whole-file state/color updates lose concurrent TTY rows | Bounded transaction lock or per-TTY records across all mutations |
| S5 | IMPORTANT | lock-gate env-i drops roots/helper and tests obsolete pending bytes | Repair isolation first, then current owned-PTY policy assertions |

Important qualifications:

- N1: Current process/device checks block common exited-target cases. They do not prove the
  supplied native surface still owns that physical TTY. Native revalidation stays outside the
  unchanged 100 ms device deadline; serialized physical checks remain necessary.
- N2: Normal `tavs` has `set -euo pipefail` and a direct function call, so copy failure does
  terminate before its success print. The prior-bundle loss mechanism remains confirmed.
- R2: Missing or readable-unmuted policy makes the attempted restriction unaffected, so no
  failed-target retry is retained. Policy-read errors can follow a different retry path.
- S2: Confirmed exposure is fake rule/state interference and TTY registry names, not input
  injection or automatic readability of every victim-owned mode-0600 record body.
- S3: Agent installers are separate Bash processes without errexit; the main CLI option does
  not protect them. This differs from N2.
- S5: Do not run the existing fixture against workstation defaults to reproduce its leak.

## Scores and derived outcome

| Partition | Correctness | Security | Maintainability | Test Coverage | Performance | Evaluated grade |
|---|---:|---:|---:|---:|---:|---:|
| Native/Sessions/focus | 6 | 8 | 7 | 7 | 7 | 7 |
| Visual/recovery/scheduler | 4 | 8 | 7 | 6 | 8 | 4 (CRITICAL cap) |
| Ordinary/shell delivery | 4 | 5 | 6 | 5 | 6 | 4 (CRITICAL cap) |

Consolidated risk: **High**, because CRITICAL findings exist. Calibration verdict: **VETO**,
because evaluated correctness is below 5 in two partitions. No unsupported average of
partition scores is substituted for their independently evaluated five-dimensional scores.
Workflow SUCCESS means the requested review completed, not product approval or acceptance.

## Action plan and verification limits

Include all confirmed findings. Start with an owned file-load regression for R1, then choose
one bounded fix slice at a time. Repair S5 before running that suite. Complete the Linux
ordinary path with a real Linux kernel/owned-PTY acceptance environment before claiming restored
platform support. Use the discriminating test proposals and source citations in each evaluated
report; the parent must independently verify findings before source changes.

Native visual/navigation/readability/Spaces acceptance and Linux runtime acceptance remain
unverified. Historical first-paint, EPERM and fresh-render timeout causes remain unestablished.
The review establishes source mechanisms; it does not reproduce those runtime failures or
claim that prior green suites prove physical acceptance.

For future matching fixes limited to one listed concern and its connected callers/tests, a
partial/high file review is likely sufficient. This does not downgrade the requested full
review completed here and is not permission to skip broader final acceptance.


## Follow-up Scheduler source exploration

This read-only source report informs the next correction. It is not a Codex provider review.

# Scheduler lock-state trust: focused source report

Last Updated: 2026-10-14 (Europe/Vienna)
Version: 1.0
Source:4a6dfa9; clean working tree at inspection.
Workspace:/Users/cs/local/code/apps/terminal-agent-visual-signals.
Scope:read-only Scheduler/LockState source and test inspection. No tests or source edits.
Persistent marker inspection belongs to parent and is not duplicated here.

## Smallest correction

Reuse RuntimeDirectoryTrust at actual lock read/write/watch boundaries. Add one checked throwing
reader returning LockStateData?: nil means trusted ENOENT; an unsafe, unreadable, oversized,
changed or malformed existing file throws existing POSIX/Cocoa errors. No availability enum,
status framework, filesystem abstraction or trust cache is needed.
Keep parse pure and optional. A tiny optional read(at:) wrapper can preserve passive callers
and tests, while Scheduler must call the checked entry and handle failure explicitly.
Making read itself throwing is smaller in API count but changes all optional assertion callers.

## Confirmed current gaps

| Source | Current behavior |
|---|---|
| LockState.swift:58-60 | String(contentsOf:) follows links; no bounded size/read, UID or parent check; all failures/parse rejection collapse into nil. |
| :49-52 | Data.atomic writes supplied path without parent or leaf trust. |
| Scheduler.swift:301 | lockNow reads optional state before preserving a later finite lock. |
| :323 | grantUnlock needs optional readable state, persists before reevaluation. |
| :377 | finishEvaluation merges nil as no existing lock before decisions/projections. |
| :476,553-555 | Comparison baseline and watcher use nil for unavailable and absent. |
| :579-594 | Leaf shape/parse checks exist, but parent/UID/mode checks do not; absence/equality shortcuts can return success. |
| :542-550 | Creates/watches unchecked parent; startup watch is attempted only once. |

The current shared helper preserves /tmp and /var aliases, owned0755 leaves and missing roots.
Use the actual lockURL parent, including the injected adjacent-to-mute parent. Do not require
an exact /tmp/tavs-UID name, exact0700 mode or owner write access for unchanged readable state.

## Checked bounded reader

Use the existing VisualRestrictionPolicy.readRule pattern (:100-139) locally in LockStateReader.
Do not extract a generic I/O module for this slice. Check parent trust with create:false and
one monotonic deadline. lstat leaf: only ENOENT means absence; require regular file, effective
UID, no group/other write, size0...8192. Reject symlink/FIFO/directory/oversize before open.
Open O_RDONLY|O_NOFOLLOW|O_NONBLOCK|O_CLOEXEC; fstat and correlate inode/device/type/size plus UID/mode.
Read <=8192 bytes with the same deadline before and after every syscall, including EINTR retries.
Close owned descriptor; invalid UTF-8 or parse rejection of an existing file throws unavailable.
A100ms standalone read budget matches small native state reads. Preserve any supplied deadline.
Size/retry bounds do not interrupt an already blocked syscall, so source cannot prove absolute
real-time completion. Managed terminal writer's existing100ms deadline remains untouched.
parse still returns nil for missing LOCKED/non-numeric end/unknown schema, preserving its tests.
The optional wrapper may retain nil on failure; Scheduler persistence must use the checked entry.

## Writer and shortcuts

Guard parent before writeLockStateIfChanged's lstat, no-file and equality success branches.
The no-lock/no-file shortcut (:589) needs trusted absence. A valid unchanged lock in owned0500
storage must still certify projection without an unnecessary write. Do not require W_OK merely
to certify identical readable contents. Use checked read for existing usable-record verification.
Guard LockStateWriter.write too because native callers use it directly. Check/create safe parent,
reject unsafe existing destination, retain atomic replacement, and explicitly ensure produced
metadata is safe for checked reads; Data.atomic alone is not proof under every umask.
Do not chmod/chown/replace an existing unsafe or malformed destination into compliance.
Pure parse=nil does not authorize Scheduler to repair an existing unreadable record.
Keep merge math unchanged: later unexpired manual end survives, live grant survives projection,
finite expiry remains finite, and grants suppress only hard-caused mute.

## Evaluation failure and retry

Before merging, finishEvaluation reads checked state. On error set projectionSaved=false and
report existing save-failure/retry text. Suppress lock/mute writes and broadcasts/release decisions
derived from unknown lock data. Do not infer unlocked, consume previousMuted, or advance
lastPaintedPauseVisual/lastPaintedWasLock. Preserve pending transitions for successful repair.
Re-arm heartbeat and known schedule transition: loadAndEvaluate canceled every timer at:341.
An early return without re-arming would permanently prevent autonomous repair.
Keep lastReadLockState as a trusted comparison snapshot; do not store error as accepted nil.
On success retain exact order: lock save, mute save, projectionSaved=lockSaved&&muteSaved, then
broadcasts/previous paint-state updates. heartbeat retryFailedRestrictions remains gated by
projectionSaved and restrictions enabled.
Disabled restrictions must still publish isMuted=false, isHardLocked=false and reason none,
even on projection failure. Failure text must retain the suspended/unavailable restriction
message plus save failure, while timers keep running. No paint/retry is allowed in that branch.
This is existing UI/behavior preservation, not new marker trust work.

## Watch/heartbeat repair without new state machinery

Check/create trusted parent before starting watch. Skip/stop watch on unsafe storage rather than
opening it. Retry skipped startup attachment through the existing heartbeat after repair.
FileWatcher.start is already idempotent (:18-22 stops prior watcher before open); reusing
startRuntimeWatch on heartbeat needs no new watcher status framework. Its void protocol does
not prove actual open success, so do not invent a successful-attachment Boolean.
Successful checked watcher read should reevaluate when current!=lastReadLockState OR
!projectionSaved. This catches unavailable-to-absent or identical-bytes repair missed by equality.
Healthy registry/pending churn with unchanged lock and successful projection stays suppressed.
Read errors trigger existing failure handling as needed and must not become trusted nil.
FileWatcher eventMask excludes .attrib (:26); permission repair is not guaranteed to produce a
watch callback. Heartbeat is required, including when watch could not initially be attached.

## Manual actions

lockNow: trusted absence allows a finite new manual lock; valid later unexpired lock retains its
later end; engaging cancels grants and remains one click. Checked read/write error uses existing
save-failure status and returns without reevaluation, preserving current timers. Never shorten
an unknown lock after an unavailable read. Keep existing:nil semantics for forced manual save.
grantUnlock: absence/error returns false with existing unavailable/save-failure text. For valid
state change only grant/written time, persist first, then reevaluate. A persisted grant remains
accepted (true) even if later mute projection fails. Failed save leaves bytes and timers intact.

## Tests that constrain this correction

- LockStateTests:round trip, absent read nil, pure malformed/unknown-schema parse nil.
- SchedulerTests345-379:failed mute/release retry once after repair; pending paint not consumed.
- :382-399:bad lock blocks paint; repeating and transition timers survive repair.
- :401-413:no-file shortcut cannot certify unusable destination; safe absence creates no lock.
- :415-433:suspension remains visible/inert while projection fails; timer repair works.
- :436-458:manual failure avoids reevaluation; malformed existing bytes remain preserved.
- :488-511:unchanged readable lock in owned0500 parent certifies projection; failed grant
  preserves data, hard-lock state and all existing timers.
- :514-534:persisted grant accepted despite mute failure; repair releases, expiry re-locks.
- :536-550:linked lock cannot certify projection/grant; target and link remain intact.
- SchedulerLockTests273-282:soft windows create no lock; merge/grant/expiry behavior unchanged.
Add only discriminating tests for unsafe parent/leaf, FIFO/symlink/oversize nonblocking rejection,
trusted absence versus unavailable, retry to absent/identical repair, watch reattachment, and
failed-read timer/paint preservation. Synthetic foreign UID is not a foreign-account exploit.

## Limits

No tests ran here. POSIX UID/mode helper does not provide ACL-complete or descriptor-anchored
TOCTOU protection. Persistent marker, shell/portable roots and live installation remain separate.
Source read-only scope excludes session-log edits; parent can capture the combined session.


## Follow-up checked Scheduler source check

This source inspection is separate from the original provider review and predates the final
private temporary writer. Its hypotheses were verified in source and isolated tests.

# Checked Scheduler state: scoped source check
Last Updated: 2026-10-14 (Europe/Vienna)
Version:1.0
Target:current uncommitted LockState.swift/Scheduler.swift and added tests.
Workspace:/Users/cs/local/code/apps/terminal-agent-visual-signals.
Scope:source/diff inspection only. No tests, edits, live actions, scores or approval verdict.
## Findings
No confirmed source defect was found in the requested absence/failure/repair paths.
The checked reader and Scheduler shortcuts implement the intended distinction and gating.
The limits below remain material; this source check is not behavioral or latency verification.

## Checked absence versus unavailable

LockState.swift:67-111:readChecked first validates the parent with RuntimeDirectoryTrust.
Only a subsequent ENOENT leaf result returns nil. Existing linked/FIFO/directory/writable/
foreign-owned/oversized leaves throw; invalid UTF-8 or parse rejection also throws.
The reader uses no-follow/nonblocking open, fstat inode/device/type/owner/mode correlation,
a8192-byte maximum, and original deadline checks around each read/EINTR iteration.
The legacy read wrapper (:62-63) intentionally collapses errors to nil for passive callers.
All inspected Scheduler decision/watch reads use readChecked, not that lossy wrapper.
Pure parse semantics remain unchanged, including legacy nil rejection and field defaults.

## Actual-current-data shortcuts

Scheduler.swift:611-629 performs a fresh checked read before either successful shortcut.
The no-file branch (:619) requires current==nil AND existing==nil plus no requested lock/grant.
Thus an unsafe parent with no leaf cannot certify success, and a newly existing leaf is not
mistaken for absence merely because the earlier merge snapshot was nil.
The no-change branch (:620-622) normalizes current.writtenEpoch, not the earlier existing
snapshot. existing!=nil is only the flag allowing a projection no-op; lockNow keeps existing:nil
so its manual action does not silently skip persistence.
A valid unchanged lock in owned0500 storage returns before writer invocation. No owner-write
requirement was added merely to certify a readable unchanged record.
These branches remain path-based observations, not a transaction with concurrent CLI writers.

## Pre-merge failure suppression and timers

finishEvaluation reads checked state at:390 before merge, lock projection or mute projection.
The catch (:391-406) sets projectionSaved=false, reports storage failure and returns without
those writes, broadcasts, previousMuted updates or lastPainted state consumption.
It rearms heartbeat and known schedule transition after loadAndEvaluate canceled timers.
It also rearms future expiry/grant wakes from lastReadLockState, which is a previously trusted
snapshot rather than newly accepted error-as-nil data.
For active restrictions, existing published state remains the last accepted state with an
unavailable/save-failure message; the code does not publish a newly inferred unlocked state.

For disabled restrictions, the failure branch sets isHardLocked=false, publishes muted:false,
reason:none and retains the restriction message with save-failure text. Repeating/wake timers
continue, while projectionSaved=false prevents heartbeat device retries. Existing physical paint
is not claimed restored by this UI change; the failing runtime cannot certify device output.

The healthy path retains lock save, mute save, projectionSaved=lockSaved&&muteSaved before
paint/release transitions (:466-480). previousMuted/paint state is consumed only inside that gate.

## Manual lock and grant semantics

lockNow uses checked state before its later-end comparison. Trusted absence permits a finite
manual lock. A valid later unexpired end survives. Read failure reports save failure and returns
before reevaluation; successful state cancels grants and retains existing:nil forced-write intent.
A write failure also returns before reevaluation, preserving existing timers and avoiding UI
claims that the new manual lock was accepted.

grantUnlock checked read throws/absence return false. For valid state it changes grant/written
time, persists, then calls loadAndEvaluate and returns true. Therefore a successfully persisted
grant remains accepted if the later mute projection fails. Failed persistence does not consume
or shorten the readable prior lock/grant and does not cancel its existing timers.
LockStateMerge and finite expiry behavior were not changed by this diff.

## Watch and heartbeat repair

startRuntimeWatch (:577-591) validates/creates the parent through the shared guard before watch.
It stops/skips watching on unsafe parent. heartbeatTick reattempts startRuntimeWatch after
evaluation (:538-542), permitting repaired startup storage to gain a watcher without restart.
The successful callback compares checked current state with the trusted lastReadLockState,
OR reevaluates when projectionSaved is false. Identical bytes or nil after permission/storage
repair therefore retry pending work; healthy unchanged registry/pending churn stays suppressed.
On callback read error it reevaluates through the same failure/timer path rather than saving nil.
The heartbeat still retries failed devices only with successful projection and restrictions active.
FileWatcher.start is idempotent but returns no success status; actual watch attachment is not
proved merely by calling it. Its existing event mask lacks .attrib, so heartbeat remains required
for permission-only repair and a previously skipped watch.

## Writer root and leaf guard

LockStateWriter.write (:50-55) checks/creates parent with RuntimeDirectoryTrust and invokes the
checked reader before replacement. Unsafe/unparseable/oversized existing destination therefore
throws before Data.atomic; it is not silently repaired or chmodded into compliance.
After atomic write, the newly produced path receives0600 mode. Parent/leaf checks support
owned0755 roots and safe missing roots while rejecting writable/linked/foreign storage.
Readonly unchanged projections avoid this writer. An actual grant/manual mutation in readonly
storage can fail as expected, preserving existing failure semantics.

## Added test source inspected

LockStateTests adds writer unsafe-parent/leaf preservation, checked trusted absence versus
invalid/UTF-8/oversize files, link/FIFO rejection and already-expired deadline tests.
SchedulerTests adds unsafe absent-root projection/watch rejection plus heartbeat repair, unreadable
lock preserving mute bytes/pending release, writable-lock grant/projection rejection, disabled UI/
retry suppression, and identical-lock watcher repair. Existing readonly unchanged-lock, failed
manual/grant and saved-grant-despite-mute-failure tests remain applicable.
These assertions were inspected but not executed by this source check. No cross-user actor,
repeated EINTR injector, blocked syscall, real watcher or terminal rendering was exercised here.

## Exact limits

The final checked reread (:506-509) occurs after success-gated broadcasts/paint-state updates.
A later read failure sets projectionSaved=false and status failure but cannot undo already
queued broadcasts. This is a late-change observation, not pre-merge suppression.
Checks/merge/atomic write do not form a transaction. A concurrent trusted CLI mutation between
reads and replacement can still race; the diff fixes stale-data no-op certification but does
not introduce shared locking or compare-and-swap around the complete merge.
Data.atomic followed by setAttributes is not a single permission-bound commit. A chmod failure
can be reported after content replacement. Same-UID/root/path races and ACL grants remain outside
this POSIX guard. Directory and file checks are not descriptor-anchored traversal.
The read deadline bounds retry checks and size, not an already blocked syscall. Writer atomic
write/permission change and watch startup have no outer wall-clock completion guard; do not claim
all Scheduler I/O is bounded100ms. The managed terminal writer's100ms deadline was not modified.
Persistent marker trust, shell/portable roots and live deployment are separate parent work.
Session-log edits were excluded; parent can capture the combined session.

## Parent Scheduler correction and final verification

LockStateReader.readChecked distinguishes trusted ENOENT from unavailable existing state and
uses the existing guard plus bounded regular-file I/O. Scheduler read failures suppress merges,
lock/mute writes, transitions and bookkeeping consumption, then rearm existing timers. Disabled
restrictions keep false/none and their message. Manual errors preserve state/timers; successful
grants remain accepted. Watch callbacks retry failed projections after identical-state repair,
and heartbeat reattempts skipped watch startup. Current checked data controls both save shortcuts.

The source check's permission-commit concern was addressed afterward: the final writer creates
an exclusive temporary, fchmods its descriptor0600 before writing, bounds output8192, writes with
one cooperative preparation/write deadline, then atomically renames. No fallible permission step
follows commit. Readonly unchanged state bypasses writing. This is local I/O in the existing
module, not a new filesystem framework. Concurrent GUI/CLI merge transactions and late state
changes remain outside this correction; no full transaction/race-proof guarantee is claimed.

Exact isolated runs:

- FsrDEZ: RED4 cases/14 failed assertions,0.190s. Unsafe absence certified pause/watch, unavailable
  lock changed mute bytes/state, and writable state was accepted for grants/replacement.
- HrVrdm:88/88 connected,0.540s;4GsvuZ:92/92,1.015s after further reader/repair cases.
- HRgM71:642/642 full Swift,18.442s, before the private temporary writer.
- iFNHUT: intermediate release18.42s, superseded by the final writer.
- QhTbiH:642/642,16.589s with private temporary; jrJgP6:final643/643,17.013s after fchmod/output bound.
- A final local release launch failed at mktemp with ENOSPC before compiler invocation. No new
  log directory existed. The next capacity snapshot showed214MiB local and207GiB external free.
- upHyLW:final fresh external scratch release17.16s. Test state stayed in private local roots.
- Yf2kjw:25/25 rebuilt-helper marker/background checks on private owned PTYs.

Logs remain under /var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.<run>/command.log.
Final build/patch/docs backups are under:
/Volumes/external/data/archive/tmp-by-day/2026-10-14/tavs-scheduler-external-0mbyhflj/.
No original scratch, report, directory or other process was deleted, moved or terminated.
The scratch relocation requires no exception to runtime-directory trust because only compiler
output is external; semantic runtime/preferences/test roots remain private local paths.

Nine new cases cover unsafe parent/leaf preservation, absent versus unparseable/UTF8/oversized
files, links/FIFO/expired deadline, bounded private output, pending release preservation, startup
watch repair, identical-state callback repair and suspended failure. Existing readonly unchanged,
manual/grant failure, saved-grant/expiry and timer cases pass. Terminal100ms remains unchanged.
Scope:two production/two test files, a shared Phase9 correction beyond its initial file list.

The final source check was not rerun against the private writer, and is not reviewer approval of
that later delta. Native MuteStateReader/Writer and writeMuteState still use legacy I/O; their
trust/bounds remain open. GUI/CLI merge serialization, portable/shell trust, Linux ordinary,
headless recovery feedback, palette/physical acceptance and final reviews also remain open.
Older timing/teardown causes are not established by these passes. Full goal remains incomplete.


## Native mute baseline exploration

Source-only evidence, separate from the original provider review. No provider approval is implied.

# Native mute-state I/O: focused source report

Last Updated:2026-10-14 (Europe/Vienna)
Version:1.0
Baseline:3df675a. Workspace:/Users/cs/local/code/apps/terminal-agent-visual-signals.
Scope:read-only MuteState/Scheduler source and tests. No execution, edits or scores.
Working files changed during investigation, so final baseline checks used git show3df675a.
This report is baseline recon, not verification of the in-flight mute correction.

## Minimal correction

Reuse RuntimeDirectoryTrust, existing checked LockState read/write patterns and one startup
pending-seed/reconciliation Boolean. Do not add a generic I/O framework or availability model.
Trust checks must distinguish unsafe storage from trusted malformed generated mute content.
The latter remains repairable by the canonical projection writer.

## Confirmed baseline gaps and callers

MuteState.swift:59-69 reads String(contentsOf:) with no parent/UID/mode/size/deadline guard,
follows leaf links and returns nil on all I/O or flag parse failures. The sole production
reader caller is Scheduler.start:258; other native references inspected are passive test checks.
MuteStateWriter.write:43-45 atomically replaces supplied destination without trust checks.
Scheduler.writeMuteState:635-643 creates parent recursively before calling this unchecked writer.
Its create failure is logged but not an early return. Trust must therefore precede creation.
The writer is also called directly by native policy/recovery/Broadcaster tests, so guarding only
Scheduler leaves that entry unprotected.

## Why trusted malformed mute projection remains repairable

Mute-state is generated output of current schedule plus checked lock state; it is not the
manual hard-lock/grant definition that must be merged and preserved. Baseline atomic write
already replaces arbitrary existing content. Adding a successful parse prerequisite would
turn a recoverable malformed projection into permanent failure until external removal.

Recommended writer rule: check/create trusted parent, lstat destination, permit absent or a
regular effective-UID-owned non-group/other-writable file. Reject link/FIFO/directory/foreign/
writable leaves. Do not require reading or parsing its existing contents before replacement.
A trusted malformed, invalid-UTF8 or oversized regular projection can be replaced with bounded
canonical new bytes; a wrong-owner/writable record cannot be repaired into compliance.
This also permits repair of a trusted unreadable generated leaf when its parent permits atomic
replacement. Do not transfer the stricter LockStateWriter parse-preservation rule to mute output.

Use a private0600 unique temporary file, bounded serialized output and partial-write/EINTR
handling with one original monotonic deadline, then rename as the commit point. The current
in-flight LockState writer pattern is available locally; no fallible chmod should follow commit.
Do not claim deadline checks interrupt a blocked syscall or make path operations race-free.
Move parent creation responsibility into guarded MuteStateWriter, removing Scheduler's earlier
unchecked create attempt. Preserve its returned false on failure and projectionSaved gating.

## Checked startup flag read

Add readMutedFlagChecked using the local no-follow, regular-file, UID/mode, inode/device and
8192-byte/deadline pattern. Preserve a legacy optional wrapper for passive callers.
A strict checked reader can return nil only for trusted ENOENT and throw for unusable present
flag/invalid UTF8/oversize, without changing the writer's permission to repair trusted content.
Retain the existing flag interpretation; full schema validation is unnecessary for seeding
previousMuted, and old/dead APP_PID must not defeat restart cleanup of a true persisted flag.
Never open a FIFO or follow a linked leaf to discover startup state.

An initial checked read failure must not certify previousMuted=false as an absent seed, nor
invent previousMuted=true. Keep a single pending startup seed/reconciliation flag.
Retry that checked seed before a subsequent evaluation overwrites old mute bytes. On trusted
valid true/false, seed exactly that value. On trusted absence, resolve to the existing no-prior
state behavior, retaining no-clear fresh startup and normal first pause paint.

If read still fails but writer can safely repair a trusted malformed projection, successful
canonical projection can resolve the pending startup work through explicit reconciliation:
when current projected state is unmuted, perform the existing clear/reconcile path once;
when muted, the normal new restrictive paint establishes the current state. Consume pending
only after the existing projectionSaved success gate. Do not name this a successful old-state
read or claim its unknown value was true/false.
Unsafe storage makes guarded projection fail, so pending remains for heartbeat/storage repair.
After repair, retry the seed before replacing a now-readable prior true flag; otherwise that
flag can be overwritten by false before its required cleanup transition is recognized.

## Preserve startup, suspension and retries

Do not abort start before discover/watch/wake/timer setup merely because the seed failed.
Existing discover/reconcile is independently guarded and remains useful for cached effects.
Keep loadAndEvaluate running so trusted malformed mute output can be repaired. Writer failure
keeps projectionSaved=false, preserves previousMuted/lastPainted state and prevents paint or
release consumption; existing heartbeat/transition timers must remain armed.

Suspended or unavailable restrictions still publish isMuted=false, isHardLocked=false and
reason none, while retaining their status message. Valid prior MUTED=true still produces
[discover,broadcastPausedClear,broadcast] once after successful projection, even in those modes.
Do not gate valid seeding/reconciliation solely on restrictions being active. On failed unsafe
storage, disabled UI remains visible but output cannot be certified; device retry stays disabled.
A persisted unlock grant remains accepted even if generated mute projection later fails.

## Delete API actual use

Search of native source/tests found no production MuteStateWriter.delete caller.
Only MuteStateTests:194 and:200 call it, for owned-file removal and nonexistent no-op.
Baseline delete uses fileExists then removeItem, so it lacks root/leaf trust and can accept
objects beyond a regular file. Do not add deletion to Scheduler or recovery, and do not remove
this API as unrelated cleanup. If the slice promises all MuteState I/O is guarded, apply the
same parent/regular-owned-leaf check and unlink a validated file; trusted ENOENT remains no-op.
No deletion was performed by this investigation. API hardening is not authorization for live
cleanup or deletion of unsafe storage.

## Existing test constraints at3df675a

- MuteStateTests131-183:atomic create/overwrite and concurrent readers see complete10-line schema.
- :188-200:owned delete and absent no-op; no production deletion flow is implied.
- SchedulerTests345-361:failed pause projection paints nothing; heartbeat repair retries once.
- :476-491:failed release does not consume old paint; repair clears/reconciles once.
- :626-645:persisted grant true survives failed mute projection, then repair/expiry works.
- :795-815:suspended startup seeds old true, writes false, clears once; repeated startup stays inert.
- :841-860:unavailable marker startup still reconciles prior true without rewriting marker/rules.
- :1539-1562:restart with true muted projection must clear when current schedule is active.
- :1599 onward:true absence retains first muted-start paint and does not invent an old transition.
Add discriminating safe-malformed repair, unsafe startup pending/repair, FIFO/link/oversize bounded
read, wrong-mode/owner non-replacement, and no-duplicate reconciliation tests. Tests were not run.

## Limits

Parent is inspecting persistent marker separately. Shell/portable roots, ACL grants, cross-user
exploitation, descriptor-anchored TOCTOU and live rendering remain separate. Plain file deadline
checks do not prove absolute100ms syscall completion. This report requests no execution or cleanup.


## Native mute scoped source check

Source-only evidence, separate from the original provider review. No provider approval is implied.

# Native mute-state correction: scoped source check

Last Updated:2026-10-14 (Europe/Vienna)
Version:1.0
Target:uncommitted MuteState.swift/Scheduler.swift and added tests on3df675a.
Workspace:/Users/cs/local/code/apps/terminal-agent-visual-signals.
Scope:read-only source inspection; no tests, edits, live actions, scores or approval verdict.
Final MuteState source was reread after parent's parsing-deadline correction.

## Finding and correction

Initially readMutedFlagChecked returned true/false after decoding/scanning without a final
check of the supplied deadline. I reported that source gap. Parent added checkDeadline after
value trimming at MuteState.swift:147, before both successful returns. The final read confirms
this correction in source. No behavioral reproduction or historical cause is claimed.
No further confirmed source defect was found in the requested trust/repair/startup paths.

## Parent and leaf guards

Reader validates parent through RuntimeDirectoryTrust, then accepts only trusted ENOENT as nil.
Existing regular leaf must be effective-UID-owned, non-group/other-writable and<=8192 bytes.
Leaf symlinks/FIFOs/directories/oversize fail before open. No-follow/nonblocking open and
fstat inode/device/type/size/owner/mode correlation retain the observed object check.
The legacy readMutedFlag wrapper remains lossy for passive callers, but Scheduler uses checked read.

Writer:44-70 checks/creates trusted parent with its one100ms deadline and validateDestination.
Destination validation is metadata-only: absent or regular owned/non-writable leaves are allowed.
It never requires valid previous MUTED text. Trusted malformed, invalid-UTF8, oversized or
unreadable generated regular content therefore remains canonically repairable. Unsafe owner,
write mode, links or special objects remain rejected rather than repaired into compliance.
Scheduler's earlier unguarded parent creation was removed; writer owns safe creation.

Delete:73-89 checks parent and the same regular-owned/non-writable leaf before unlink.
Trusted ENOENT is a no-op. No recursive removeItem remains. It has no production caller found
in this investigation; existing and added tests exercise it. No deletion was performed here.

## Private atomic writer and bounds

Serialized new bytes are capped8192 before staging. Temp uses O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC,
0600 creation plus fchmod0600 on the owned descriptor before any bytes/rename. Partial writes
advance offset; EINTR returns to the same deadline-checked loop. One check precedes rename.
Successful rename is the commit point; there is no fallible permission/deadline step afterward.
The defer closes/unlinks the owned temporary name. Oversize new output leaves old bytes intact.
Reader caps accumulated bytes and checks deadline before/after every read, including EINTR.
The new final parsing check prevents reporting a successful flag after the parse stage expired.

## Startup pending seed and success gating

previousMuteSeedPending starts true and is reset by start. Each pending finishEvaluation attempts
checked seed before reading/merging lock state or overwriting mute bytes (:388-395).
Valid flags are used in wasMuted without inventing a value for failed reads. Trusted absence
retains no-prior-state behavior. Error is kept as muteSeedReadFailed for this evaluation.
Pending is consumed only inside projectionSaved at:474-476, after lock/mute persistence succeeds.

Mute write is short-circuited by lockSaved&&writeMuteState at:470. A failed lock save cannot
replace the still-pending prior mute projection. Read/save failure retains pending for later
heartbeat repair. On repair the seed is retried before canonical bytes replace the prior state.

A successfully repaired unknown seed with unmuted current projection uses the explicit
(wasMuted||muteSeedReadFailed)&&!projectedMuted reconciliation condition (:482).
After success pending=false and previousMuted=false, so later healthy evaluations do not repeat
that cleanup. A muted projection follows the normal pause paint and establishes current state.
Existing restrictive state, rules and grants are not derived from the untrusted prior flag.

## Suspension, grant and timer behavior

Checked lock failure still rearms heartbeat/transition/prior trusted expiry wakes and skips merge/
projection. Mute save failure flows through existing projectionSaved=false, preserving previous
paint state and pending release. Timers remain armed through the existing evaluation tail.
Disabled restriction UI still publishes false/none and its restriction message on lock failures;
normal disabled projection suppresses restrictive paint and heartbeat device retries.
A valid persisted true startup flag still clears/reconciles once even while suspended/unavailable.
No startup read failure aborts discover/watch/wake setup. grantUnlock semantics are unchanged:
a persisted grant stays accepted even if later generated mute projection fails.

## Added assertions inspected, not executed

Tests cover unsafe parent/leaf preservation, linked parents, special read/write/delete objects,
true absence versus malformed/UTF8/oversize/expired reads, private0600 output, safe malformed repair,
oversized output preserving bytes/no leftover temp, unsafe startup seed repair, failed initial
lock save preserving prior mute, and one-time malformed startup reconciliation.
Existing suspended/unavailable startup, genuine absent startup, saved grant and timer/repair tests
remain applicable. Test source does not prove actual cross-user, syscall-stall or live rendering behavior.

## Exact limits

POSIX checks do not inspect ACL grants or anchor all operations to held parent descriptors.
Metadata-check/use and concurrent trusted-writer races remain; no transaction/compare-and-swap was added.
Deadlines bound retry checks, not an already blocked syscall. Rename may finish after its preceding
check; returning success reflects committed complete private bytes, not a hard100ms wall guarantee.
Delete has no explicit operation deadline; this slice adds its trust/type guard, not live cleanup.
A flag read preserves legacy flag interpretation, not full-schema validation of all mute fields.
Physical restoration and full-suite success were not verified here. Parent handles those results.

## Parent native mute correction and verification

Native mute flag read now validates storage and bounds regular-file input/UTF8/flag parsing.
The passive optional wrapper remains; Scheduler retries a checked pending startup seed before
replacing old bytes. Pending is consumed only after projectionSaved. Failed lock persistence
skips mute writing. Safely repaired unknown startup state uses one explicit reconciliation when
current projection is unmuted, without asserting the old Boolean. Fresh trusted absence stays
no-prior-state. Existing suspension/unavailable UI, grant acceptance and timers remain.

Writer/delete validate parent and leaf metadata. Trusted malformed generated bytes remain
repairable; unsafe metadata does not. Writer stages bounded private0600 output before rename;
there is no fallible permission step afterward. The delete API remains unused in production;
its existing owned-file tests and new rejection tests do not authorize live cleanup.

Exact isolated runs:

- H2vewo:initial RED3/9 failed assertions,0.534s; unsafe reads/replacement and startup consumption.
- Tai1lI:87/87 connected,0.420s with initial trust/pending implementation.
- ueWFoc:RED2/5,0.133s; failed initial lock write overwrote pending mute and malformed repair
  omitted reconciliation. Short-circuiting mute write and explicit unknown-seed cleanup fixed both.
- ziBMkj:89/89 connected,0.653s.
- 7bS15i:651/651 full Swift,15.388s before final parsing-deadline check.
- zWROWf:651 tests/2 assertions (1 unexpected),17.515s. Existing masked-focus release read
  found no bytes and timed out at focus-controller-tests.swift:718/93. No writer outcome was
  asserted specifically for that release; historical cause remains unproven.
- shatpL:focused failed-case/mute/Scheduler control passed before instrumentation. It establishes
  that separated run's outcome, not attribution of zWROWf.
- bBIGar:final651/651,16.235s after the release fixture records fresh writer Boolean/error trace
  and requires its current heartbeat before the unchanged PTY byte assertion.
- bG6i3E:final external scratch release18.74s.
- lJzKjR:25/25 rebuilt-helper marker/background checks on private owned PTYs.

The source check reported the final flag-return deadline gap; the parent had just added that
check and the report reread it. No further source defect was reported in the scoped paths.
Eight new cases cover unsafe/linked/special storage, checked invalid/oversized/expired input,
private atomic output, trusted malformed repair, pending startup repair and failed-save seeding.
A test-only release recorder change preserves physical target/emergency/nil-callback/errno and
100ms semantics; no production focus/render behavior changed.

Logs use /var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.<run>/command.log.
Release scratch remains on the external drive under tavs-scheduler-external-0mbyhflj/build;
semantic runtime/preference roots remain private local paths. No installed app/state changed.
Scope:two production/three test files, shared Phase9 correction beyond its initial file list.

Plain-file deadlines do not preempt blocked syscalls. ACL/TOCTOU and concurrent writer/GUI-CLI
merge races remain outside this guard. Portable/shell trust, Linux ordinary, headless feedback,
palette/physical acceptance and final reviews remain open. The earlier missing-byte failure and
older timing/teardown causes are not attributed by these passes. Full goal remains incomplete.


## Parent native lock transaction correction

The native/Darwin RMW correction uses one stable private regular mutex across fresh read,
merge and replacement. Native manual/grant/schedule paths and typed headless CLI operations
share it. Semantic no-ops return stored bytes' record; unused absence still leaves no rule.
The watcher baseline is the accepted transaction snapshot, so a later grant remains detectable.
CLI acquisition follows the challenge; accepted lock ends drive messages. Colors are canonical
before serialization; invalid requests cannot enter the UI. Device100ms is unchanged.

[Both complete source reports and disposition](PROGRESS_appendix_phase-9_review-source-checkpoints.md#native-lock-transaction-source-checks-2026-10-14).
Reports are source checks, not final independent provider approval. Verified findings produced
compile-fragment repair, color normalization and the additional watcher correction.

Isolated runs, with log roots /var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.RUN/:

- HJSQtD: RED1/2 assertions,0.132s; writer replaced bytes despite held mutation mutex.
- hB7jjO: RED1 CLI case; post-challenge replacement lost a newer lock end.
- dtMlIt: compile failure from a leftover Scheduler catch/read fragment; corrected directly.
- il24iO: connected100/100,0.692s; DACDUW: intermediate full655/655,22.054s.
- V47Mgv: intermediate release34.44s; Kawukn: color-corrected release40.54s.
- mC7wtG: fixture compile failure, throwing inference inside nonthrowing visual callback;
  explicit do/catch retained publication errors and removed the mismatch.
- tBfZkL: watcher RED1/2 assertions,0.471s; late snapshot absorbed the new grant.
- U29ZpU: connected checks pass after snapshot correction.
- LMLHFu: final658/658 Swift,17.013s; Y5UCeP: final release19.15s.
- i5itEP:54 Bats,4 failures. All29 cmd-lock and6 marker cases pass; background cases38/39/42/45
  fail (native/portable provider synthetic updates, standalone muted write, owned synthetic PTY).
  The initial tail showed only42/45; full-log inspection corrected that count. Helper/render
  unavailable is shown for45; the other assertions lack precise stage attribution.
- dQrEwk: focused four-case control passes with failure-output printing. This establishes the
  separated run's result; it does not explain the combined-run failures. No full rerun erased them.

Seven new Swift and five CLI cases cover mutex scope/contended preservation, fresh schedule and
post-challenge merges, watcher snapshot ordering, no-op/deadline behavior, unsafe mutex objects,
canonical colors/input rejection, missing helper and headless operation. Changed shell syntax
and diff checks pass. Tests used private roots and the explicit external source-built helper;
no installed app, real preference/schedule, live terminal or unrelated process changed.
Scope:6 production/3 test files; shared Phase9 correction beyond the original phase list.
Earlier Bug Reference isolation/launch text moved unchanged to its focused appendix; reconstruction
passed. The finished mute progress entry moved unchanged to the existing review appendix.

Non-Darwin writers, old non-cooperating binaries, pre-challenge duration semantics, ACL/TOCTOU
and hard syscall bounds remain outside this correction. Shell/portable trust, headless physical
feedback, palette release, Linux ordinary support, final reviews and native acceptance remain
open. All earlier timing failures, plus i5itEP's four failures, remain unattributed. Goal/Phase9
remain incomplete; SPEC/PLAN bodies are fixed.

## N2 app replacement correction, 2026-10-15

Current installer source now stages on the destination volume and validates the copied executable,
plist syntax/identity and strict signature before process handling. Guarded moves retain the prior
bundle without merging; activation failure restores it only to a free destination. A conflict or
failed restoration preserves and reports the prior path. Main command propagation also works
when caller errexit is suppressed. Dry-run stays mutation-free. Two moves are not crash-atomic;
restoring the bundle does not relaunch the stopped app. Successful updates retain the prior copy.

Verification: 9RvzjJ baseline has 8/9 failures, including actual prior-file loss. X96exD has 9/9
passing; nlwLvo and final MRnm0e each have 26/26 passing (11 installer, 15 sync). The first O5wldI
run was invalid evidence: canonical fixture paths did not match an aliased wrapper root, so its
path guard rejected all calls. Canonicalizing the test root fixed the harness before behavioral RED.
8HZPkW uses real copy/moves, ad-hoc signing and strict signature verification on an owned private
bundle with the source-built release helper. Replacement and both static headless capability
probes pass; process/open commands are stubbed. Bash 3.2 syntax and diff checks pass. A source-only
Explore follow-up found no further actionable defect after two missing discriminating tests were
added: real mv-n skip and full-command conditional invocation. This is source assessment, not a
new provider or physical acceptance verdict. Historical provider VETO remains unchanged.

Reports, original logs and prior files are retained in
`/Volumes/external/data/archive/tmp-by-day/2026-10-15/tavs-install-replacement-ngeg6cgh/`.
No production install/launch, settings/schedule edit, terminal paint or process shutdown occurred.
N2 is corrected in source; S3 remains a separate child-installer fix. Earlier Swift/portable full
suite failures and native/Linux acceptance stay unresolved. Goal/Phase 9 remain incomplete.

## S3 agent installer correction, 2026-10-15

Gemini and unified previews now inspect actual Python status rather than diagnostic strings;
failed previews cannot reach confirmation/apply. Failed apply returns nonzero before per-agent
success. Unified installation continues other agents but preserves aggregate failure and omits
Done on failure. The public `tavs install gemini` caller propagates its child's status unchanged.
Independent successful settings writes remain applied; no multi-agent rollback is promised.

A real-Python successful-rerun control also exposed unified nested-hook duplication: missing
flat command fields compared as None versus empty string. Complete-entry equality prevents
exact duplicate additions while preserving distinct matcher/metadata entries and user settings.
A dedicated control compares the complete template map plus a same-command/different-matcher
user entry and requires byte-identical rerun. No provider hook definition or schema changed.

5bM7ch: behavioral RED, 6/8 cases fail (five status/preview failures plus actual rerun mutation).
SNtaKN: initial 34/34 pass. RnICtW: final 35/35 pass, including the added distinct-entry control
(9 new, 11 app replacement, 15 sync). Successful merges use actual inline Python; failure modes
inject only child exit43 on private target paths. Original settings bytes and absent apply calls
are asserted. Bash 3.2 syntax passes for both modified scripts. Swift source was untouched;
prior broad-suite, Linux kernel and native acceptance results remain open, not superseded.

Original logs and prior files are retained under
`/Volumes/external/data/archive/tmp-by-day/2026-10-15/tavs-agent-installer-vup05e2p/`.
No real install/sync, user settings/schedule change, terminal paint or provider/session stop occurred.
S3 is corrected in source. Historical provider VETO remains unchanged. Goal/Phase 9 incomplete.

The reused Explore source check found no actionable defect. Its recommended distinct-entry
regression was added and source-verified. This read-only assessment is not a new provider review
or live acceptance verdict. The report is retained beside the original test logs above.

Connected delivery correction: sync previously copied only the Codex installer. It now copies
both corrected scripts, Gemini trigger/hooks and the Codex template through the existing checked
list, with required script execute permissions. tYeAUf reproduced two failures: stale copied
bytes and Gemini CLI exit127. Final YiNtUz passes36/36 (9 child, 11 app, 16 sync), including copied
Gemini/unified preview rejection in both plugin roots. Original logs are retained above.

## S4 source disposition: 2026-10-15

Confirmed: atomic rename did not serialize the shared state/color table snapshot. ILtZl2
reproduced four lost-update failures across real Bash 3.2/zsh. All existing mutation APIs now
hold one stable per-table descriptor through fresh read, filter, unique staging and rename.
Color write/clear also return explicit success instead of inheriting the disabled-debug status.
State timestamps follow admission. No row schema, reader layout or device deadline changed.

The [independent source check](session-table-source-check-2026-10-15.md) found a conditional
ancestor/FIFO opening before lock acquisition. Its private substitution results and source seam
were checked; a new four-subcase red reproduced missing ancestor rejection (EwS9ed). Physical
path use and local root/EUID ancestor admission fix it. Explicit base-8 masks avoid zsh's decimal
leading-zero interpretation; BSD `%Op` retains sticky bits omitted by `%Lp`. Further tests cover
safe aliases, actual sticky ancestry and read permissions. Separate S2 policy/reader paths remain.

G0PFko: **12/12 groups pass**; zReAgt: **52/52 connected Bats pass**. Held-lock, crash, filter/
backend/rename failure, unchanged old data, empty clear and caller trap/FD checks are included.
Bash/zsh syntax passes. ShellCheck reports the same six existing SC2034 exports as the backup;
excluding that category passes. The first extra `/dev/fd` equality guard failed on Bash and was
removed before final testing. Earlier failures and final logs are retained under
`/Volumes/external/data/archive/tmp-by-day/2026-10-15/tavs-session-table-transactions-v4uzunle/`.

S4 is corrected in source with Mac shell evidence. Linux kernel acceptance, mixed old lockless
workers and native Ghostty acceptance are unverified. The prior Swift full-suite failures remain;
Swift source was untouched and was not rerun here. This is a source disposition, not a new final
provider verdict. Historical VETO and the active/incomplete goal remain unchanged.

## N3 help correction: 2026-10-15

Automatic help now names newly observed High permission requests and response completions,
states that response completion does not confirm task success, and conditions acknowledgement
on successful Go To. Isolated source build RqLGWi passes in 10.89 seconds. This text-only change
adds no behavioral test; native presentation remains unverified. The reducer is unchanged.

## S2 raw registration correction: 2026-10-15

The [source investigation](legacy-policy-trust-source-check-2026-10-15.md) found a concrete
pre-helper truncation through shellrc registry symlinks, plus core touch/mkdir through untrusted
paths. 12sboq reproduced four failures in private sentinel/absent-runtime cases. Shellrc now
delegates registration entirely to the already-required managed helper and stops after its
failure. Core mute initialization resolves its path without mkdir or raw hint publication.
Existing hints remain readable; no user files or runtime directories are deleted.

Verified in source: Scheduler's own Broadcaster/VisualRecovery targets cached typed bindings and
fresh native surfaces independently of Sessions/focus. Raw active-ttys rows only add diagnostic
failures. Removing their creation does not remove broadcast targets. Native managed registration
and ordinary render cache target.json; portable registration and background publication do too.
Portable title/palette-only rendering still has no new cache, so no broader claim is made.

KMvaND: **49/49 Bats pass**. 9Wu7hO: **25 Python tests pass, 8 Linux-only tests skipped**.
The real installed-startup matrix now covers both native/portable backends, Bash/zsh and
suspended/unsuspended states, with exact owned TTY/cache matching, no bytes/intent/new legacy
hints and unchanged marker. Fake-helper assertions check exact verb/TTY lines, not hint files.
An intermediate copied-shell assertion failed while the test helper cleared preceding logs;
that test-only clearing was removed before final runs. Syntax and checked ShellCheck pass.

Connected wlIXDk: **73/74 pass**; portable provider synthetic rendering fails write/os-60.
Focused candidate 4qYjwm repeats that timeout. Clean baseline 8a12cc9 in an isolated managed
worktree also fails the portable scenario (rrdeCp), but with metadata-unavailable/stale output.
These differing failures do not prove the exact timeout's cause or close it. No deadline changed.
Logs and before-files: `/Volumes/external/data/archive/tmp-by-day/2026-10-15/tavs-validated-registration-gg8rclht/`.
The clean baseline worktree was recoverably archived after its child completed.

The source checker found no registration/discovery defect and its exact-line assertion suggestion
was applied. S2 remains open for marker core/standalone read/write trust, legacy lock/mute reads,
debug append and portable paths. Native/Linux acceptance and earlier full Swift failures remain
open. No real install/sync, settings change, native catalogue action, paint or user-session stop.

## S2 shell suspension-marker trust: 2026-10-15

f4mWYr reproduced five safety failures: writable marker/parents, unsafe absence, arbitrary links,
foreign metadata and pre-helper recovery replacement. Core and embedded standalone reads now
check current-owned parent/file leaves, root/current-owned ancestors, write bits and only exact
root-owned macOS system aliases. I/O uses the checked physical path. Trusted absence remains
active without creating directories. Whole-path dot refusal precedes any mkdir.

Core writes create/check private components, retain the canonical 0600 atomic format, and recheck
before rename. Scoped cleanup/traps/umask preserve the caller and old data on failure. Injected
post-mktemp validation and rename failures cover cleanup; Bash/zsh create independent prefixes.
Exact content/NUL fixtures remain, with an explicit C locale for the 128-byte shell read.
[Independent source/probe check](marker-storage-source-check-2026-10-15.md) found no material defect.
Native descriptor-level no-follow/inode guarantees are stronger than these shell checks.

IyVFAO: **72/72 connected Bats pass**, including installed copies, shared native fixtures and
persistence-before-helper behavior. pDIqxp: all eight real startup combinations pass; one inherited
Linux class is skipped. ShellCheck and Bash/zsh syntax pass. No Swift source/deadline changed.
An initial escaped-slash probe inserted backslashes; Lw91NP proved the corrected variable form.

Two intervening persistence assertions failed (iWgpsp initial, JI11l9 resume); focused CxbjKQ and
the final combined run pass. The retained failed logs do not identify the failed writer branch.
Twelve independent Bash3.2/5.3 probes pass exact save/resume, cleanup, trap and umask checks with
and without xtrace. No Bash-version or load cause is established. Initial/resume fixture traces
now retain version/tool paths for the next actual failure; successful retries do not close it.
Logs/probes/before-files: `/Volumes/external/data/archive/tmp-by-day/2026-10-15/tavs-suspension-storage-vlyhppcs/`.

S2 remains open for legacy lock/mute bounded trust, debug append and portable policy paths.
Earlier portable timeout, full Swift failures and native/Linux acceptance remain open. No live
settings, install/sync, catalogue operation, paint, or user-session termination was performed.
