# Phase 6 current global policy and composition
Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0
Inspected HEAD: 43914a0
Repository: /Users/cs/local/code/apps/terminal-agent-visual-signals
Method: current source and fixture reads only. No live runtime files, process/native queries,
builds, tests, edits, terminal/GUI actions or commands exposing process arguments.

## Minimum implementation

Add a small global policy reader/composer in the typed recovery coordinator. Reuse:
- VisualRestrictionsStateStore.read() for the first precedence check.
- LockStateReader.parse(text), avoiding its unbounded read(at:).
- LockStateData.isEffectivelyLocked(now:) for the hard-lock/grant predicate.
- PauseVisual.normalizedHexColor and PauseVisual for sanitized resolved colors.
- Current Broadcaster byte order for legacy global paint/clear.
- TerminalVisualStateStore's deadline-aware regular-file read pattern, without its JSON decode.

The current managed writer already opens before locking and calls prepare(fd, deadline) inside
the stable advisory lock. It checks the original deadline before and after prepare and before
device bytes. The callback should only validate local target state, bounded-read the marker and
current lock/mute projections, derive the current enum policy, persist its effect and construct
small bytes. No AppKit, subprocess, Automation, full config reload, schedule transition scan or
nested fresh deadline belongs there.

A concrete enum such as unrestricted / paused(visual) / locked(visual, until) / disabled(status)
is enough. Unavailable read state must not authorize restrictive paint; report unavailability
rather than making an unknown file an effective lock. Ordinary output and recovery behavior
remain separate typed operations.

## Current policy precedence

### 1. Suspension

visual-restrictions-state.swift:25-61 already implements a bounded 128-byte canonical reader:
lstat regular file, O_NOFOLLOW/O_NONBLOCK/O_CLOEXEC, fstat inode/device identity and strict LF
text comparison. Absent accessible-parent state is active; valid true is suspended; malformed,
unknown, unreadable/special/symlink state is unavailable. Both suspended and unavailable disable
restrictions. The same bounded schema is copied into standalone shellrc and used by shell gates.

Reuse this status, with deadline checks immediately before and after the call. Do not reinterpret
unavailable as permission to paint, and do not make recovery repaint conditional on an effective
global rule: a safely bound old effect can still require reset.

Scheduler.finishEvaluation reads status at the start and still evaluates raw rules, merges
lock/grant and arms timers. It overrides only projected mute/hard-lock visibility and skips all
broadcaster operations while disabled. This existing behavior must remain.

### 2. Hard lock and grant

Exact predicate:
locked && now < lockUntilEpoch && !(now < unlockUntilEpoch)

An effective hard lock wins over soft-state absence, dead app PID, old heartbeat or soft expiry.
It deliberately has no APP_PID/heartbeat requirement. It ends at the exact lock epoch. A grant
ends at its exact epoch and then re-engages the remaining lock. There are no indefinite hard locks.

LockStateReader.parse:
- accepts quoted or unquoted key/value text and last occurrence of a key;
- requires LOCKED and numeric LOCK_UNTIL_EPOCH;
- accepts absent schema as 1 and rejects unknown schema;
- malformed/missing grant parses to 0;
- absent/unreadable/malformed read means no effective lock;
- carries LOCK_BG/LOCK_FG already resolved by the writer.

Shell hard predicates require decimal digits for lock/grant epochs. Swift Int64 also accepts
signed forms. This is a small parity edge: a +future epoch can lock or grant in Swift while shell
rejects it. Validate known epoch fields as digits before using parse in the coordinator, or
tighten that parser with fixture tests. Do not replicate shell arithmetic on arbitrary data.

LockStateMerge remains the writer's authority:
- active manual end survives schedule projection using max end;
- if schedule end is later, schedule reason wins; later manual end retains manual reason;
- unknown schedule end is capped at now + 24 h;
- unexpired grant is preserved, expired grant dropped;
- merge refreshes resolved colors, never creates an infinite hard lock.

Do not rerun merge or mutate underlying definitions in every device callback.

### 3. Independent soft mute

mute-gate's current full check and shellrc apply:
- MUTED must be literal true.
- SCHEMA_VERSION defaults to 1; unknown schema releases.
- nonempty APP_PID must pass kill -0.
- nonempty, nonzero UNTIL_EPOCH releases only when until < now.
- nonempty WRITTEN_EPOCH releases when now - written > 120.

Therefore soft until == now and heartbeat age == 120 still pass under existing shell semantics.
Preserve these edges unless explicitly changing the contract. Missing optional PID/epoch fields
currently skip their checks, and existing fixtures intentionally use APP_PID="" with a fresh
heartbeat. A future written timestamp is not currently rejected solely for being future.

MuteStateReader.readMutedFlag is only Scheduler startup history. It parses MUTED and does not
validate full schema, app liveness, timestamps or colors. It is not a reusable current policy
reader. Introduce a bounded parse of the few mute keys, never source shell data. Reject malformed
numeric fields safely rather than reproducing variable-name/arithmetic evaluation.

Use an injected PID-liveness function for deterministic tests. A production implementation can
perform a direct POSIX liveness check without spawning ps. This recon did not make such calls.

A grant releases hard-caused muting only. It must not disable a separate soft master pause,
outside-hours or quiet period. SchedulerLockTests.testGrantDoesNotAffectSoftMute pins this.

Important current projection edge:
MUTED=true with REASON=hard_lock can linger until Scheduler reacts to a changed grant/expiry.
It is a mirror of a hard restriction, not an independent soft cause. A new native reader must
not resurrect that mirror after lock release. The current shell check ignores REASON and can
briefly continue suppressing it. Add a regression for native policy behavior.

Do not discard schedule_window/quiet_period indiscriminately while a manual grant exists:
mute.state does not encode whether these causes were hard or soft, and separate soft rules
remain valid. If raw schedule distinction is needed for an explicit resume, use existing
ScheduleEvaluator.evaluate once on a validated bounded config. Its nextTransition scans up to
48 h minute-by-minute and must remain outside a 100 ms device callback.

Legacy liveness fixtures use REASON=test. Treat unknown informational reasons as generic soft
mute when all validity fields pass, or replace fixtures deliberately with canonical soft reasons;
do not accidentally release all those cases by a new closed reason enum.

## Current resolved colors and appearance

Scheduler obtains a fresh PauseVisualProvider value and serializes resolved PAUSE_BG/PAUSE_FG
into mute.state. LockStateMerge serializes resolved LOCK_BG/LOCK_FG. These are the quickest,
current local color source for a headless coordinator.

PauseVisualResolver.resolveForCurrentAppearance calls NSApplication.shared.effectiveAppearance
and then loads UserConfStore through an unbounded String(contentsOf:). It assumes the main queue.
Do not call it from prepare or headless recovery. Use persisted resolved colors there.

Defaults:
- dark background #3A3A3A, foreground #F2F2F2;
- light background #D0D0D0, foreground #202020.

PauseVisual normalizes whitespace/case to #RRGGBB and rejects nonhex strings. Missing/malformed
foreground is derived for readable contrast; valid explicit low-contrast foreground is preserved.
Do not alter valid user choices, including equal foreground/background, in this Phase 6 policy fix.

Standalone shellrc currently:
- uses LOCK_BG/FG, background default #3A3A3A; skips OSC 10 when foreground is absent;
- uses PAUSE_BG/FG with the same background default; skips absent foreground;
- gives hard lock styling precedence over soft paint.

Legacy CLI lock now reads only dark pause config keys and can write blank FG; the app later
refreshes appearance-resolved values. A typed reader should preserve the absence of a resolved FG
or explicitly normalize it through the existing PauseVisual rule. This is an observable
compatibility choice, so pin it in a fixture rather than silently introducing white foreground
for every old blank-FG record. New current app projections already contain a resolved FG.

## Byte composition and titles

Current global pause:
OSC 104, OSC 10 resolved FG, OSC 11 resolved BG, OSC 1337 image clear, all BEL-terminated.
Foreground precedes background. Soft paint has no OSC 0.

Current hard lock:
same legacy palette/foreground/background/image bytes, then
OSC 0 with "🔒 locked until HH:MM".
This is the deliberate existing global-lock exception to title-free effects.
Derive local HH:MM from the CURRENT lock expiry without a date subprocess.

Global clear/recovery:
OSC 104, OSC 110, OSC 111 in that order. No OSC 0 or empty-title reset.
The old locked title can remain until the next real title event, as already documented.

Normal global release under future controlled output:
clear legacy foreground/palette, then recompose current ordinary background/active focus.
Emergency recovery:
defaults reset only; do not immediately reapply ordinary theme or consume cached title/alerts.
Background-only selective clear:
OSC 11 current intent or OSC 111; no foreground/palette/title/cursor change.

Broadcaster.broadcast() still replays opaque pending streams. Scheduler
clearPausedVisualAndReplayPending currently calls it after color clear. Those calls must be
replaced for controlled output; do not make a generic OSC parser or strip BEL terminators.

Byte tests should compare expected sequences/no OLD_TITLE or ALERT_SENTINEL. A blanket
"no BEL byte" assertion is wrong because BEL terminates valid OSC sequences.

## Deadline-aware bounded file reading

LockStateReader.read and MuteStateReader use unbounded String(contentsOf:).
TerminalVisualStateStore:688-726 already has the reusable local pattern:
1. Check supplied original deadline.
2. lstat absent versus error; reject nonregular/oversized file.
3. O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC.
4. fstat compares inode/device with earlier lstat and validates bounds.
5. Read with size cap, EINTR handling and deadline checks.
6. Decode as data and recheck deadline.

For lock/mute projection text, a small fixed cap is sufficient because actual writers emit
eight short lines. A targeted 4 KiB or 8 KiB cap is an implementation limit to test, not a new
operator setting. Reject size growth beyond the bound and invalid UTF-8/NUL/control syntax.
Do not expose a generalized file toolkit merely to read these two formats.

No second lock/deadline should be acquired from inside prepare. The current record-store lock
functions normally start another deadline; reuse only their deadline-aware read pattern.
Avoid time-of-check decisions queued before output serialization. In the callback read current
policy after target validation, before persisting the final effect and composing bytes.

## Fixtures and tests to preserve or extend

Existing authoritative cases:
- LockStateTests: parse unknown/missing/non-numeric fields, expiry exactly, grant expiry,
  manual/schedule max merge, 24 h cap.
- SchedulerLockTests: hard allowed/quiet rules, master never hard, active grant releases hard,
  grant never releases soft, manual lock in allowed hours, expiry and suspension definitions.
- tests/integration/lock-gate.bats: no mute file/dead PID/stale heartbeat under effective lock,
  grant/expiry/malformed release and worker predicates.
- tests/integration/liveness.bats: missing/false/unknown schema, empty PID, dead PID,
  stale heartbeat and expired soft epoch.
- tests/unit/shellrc.bats: lock colors/title versus soft no-title, both shells, precedence,
  suspension/unavailable state and standalone copied-file semantics.
- PauseVisualTests: normalization, malformed BG/FG, derived readable FG and valid low contrast.
- PreferencesPauseVisualPreferenceColorsTests: stored malformed values preserved when unchanged;
  changed BG/FG edits stay scoped.
- BroadcasterTests: exact legacy byte ordering, no soft/reset OSC 0, healthy/dead PTY fanout.
- shared visual-restrictions fixture and Swift/Bats parity keep canonical marker classification.

Minimal new coordinator cases:
- original callback deadline expired before policy read and between read/composition: no bytes;
- policy changes from hard to suspended while queued: no stale restriction;
- hard valid versus soft dead/stale, then grant plus independent soft pause;
- soft equality boundaries age 120/121 and until == now / now - 1;
- a hard_lock mirror after expired/granted lock does not become a soft pause;
- absent optional fields and malformed numbers, duplicate keys, signed epochs, special files,
  symlink/unreadable/oversize/growing projection;
- current PAUSE/LOCK color differences, blank FG compatibility, malformed color never enters OSC;
- queued lock expiry title uses current end; recovery/normal release no historical titles/alerts;
- recompose latest intent without full config/appearance lookup.

Safety issue in current test source:
tests/integration/liveness.bats teardown:23-27 STILL constructs live /tmp/tavs-UID and deletes
pending/_var_folders_*.osc and active-ttys/_var_folders_* with wildcards despite private setup.
Do not execute this file until that teardown only touches its private runtime. The parent was
notified during recon. No deletion occurred here.

## Surgical file scope

Minimum native work: visual-recovery.swift coordinator plus a small bounded local projection
reader, reusing LockState.parse and PauseVisual. Existing ProcessRunner prepare API is ready.
Add focused coordinator policy tests and a targeted shared fixture where shell parity matters.
Fix only the live cleanup lines in liveness.bats before it is used.

Do not refactor ScheduleEvaluator, UserConfStore, global configuration, unrelated title code,
or all shell predicates just to install the native coordinator. Preserve the raw scheduler
merge/timer authority and route its final global writes into fresh native policy.
