# TAVS current implementation Codex review

Last Updated: 2026-10-14T12:31:58
Version: 1.0

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
