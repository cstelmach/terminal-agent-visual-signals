# Claude specification review and source-verified dispositions

Last Updated: 2026-10-05 (Europe/Vienna)
Version: 1.0
Target: [SPEC.md](../SPEC.md), original version 1.0, 419 lines
Source baseline: `c1dd8b470f546cc383cbc96c27d5248b0b7d2127`

> WARNING: DEGRADED execution. The preferred Claude hub returned zero review characters after
> approximately 30 minutes (exit 2). The canonical transport then completed through its documented
> `claude -p` fallback, exit 0. Opus was requested; the served model version is unobserved.
> Treat findings as review inputs, but do not present this as a clean hub execution.

## Execution, substitution and result

AGY was attempted first through the guarded runner, selected Gemini 3.1 Pro (High), but exited
1 with `Eligibility check failed: failed to fetch user info: 500 Internal Server Error`.
It returned empty stdout and no valid review. No AGY approval exists. This was not an individual
quota signature, so no account fallback was attempted. The workflow permits an equivalent
independent family after a provider failure; Claude supplied the second family beside Codex.
AGY failure report: `/tmp/agy-review-tavs-organizer-spec-20261005.md`.

Claude received the full unchanged SPEC and research synthesis with bounded source excerpts,
in one tool-free review turn. No Codex findings were provided. Original result was **CONCERN,
6.0/10, Medium risk, NEEDS WORK**: zero critical, five HIGH, twelve MEDIUM and three LOW findings.
Completeness 5, consistency 7, testability 5, scope 7 and clarity 6 give 30/5 = 6.0.

Full report: `/tmp/claude-review-tavs-organizer-spec-20261005.md`.
Original output: `/tmp/claude-review-tavs-organizer-spec-20261005.raw.md`.
Transport metadata: `/tmp/claude-review-tavs-organizer-spec-20261005.transport-metadata.json`.
This durable document is a complete findings synopsis plus parent source checks/dispositions,
not a verbatim review transcript or a new Claude approval of version 1.1.

The transport's generic warning mentions kill switch, volume cap or contention. Those causes
were not established. Actual hub metadata recorded an error after 1,797,375 ms with zero output.
Body-safe probes did not establish whether the wait was network generation or transport delay.
Native extraction refused format drift; no native session body or reasoning was inspected.

## HIGH findings

### R1: Recovery can miss controller-painted plain shells

Confirmed. `Broadcaster.swift:172-200` reads active-ttys only, prunes aged entries and removes
entries on write failure. Shell integration registration is optional. Original SPEC required
all native surfaces but did not define the independent recovery target union.

Resolution: reuse the per-TTY effect records already needed by rendering. Record every affected
binding before painting; recover the union of effect records, active registry and available native
catalogue. Validate continuing bindings, retain failed live targets and test unregistered shells.
A separate recovery ledger is unnecessary.

### R2: Queued cross-process restriction writes can follow recovery

Confirmed. Scheduler.swift:425-434 and shellrc:107-119 decide before painting. The 100 ms writer
deadline does not order different processes. A generation check before an unlocked write still
races; a second repaint cannot prove safety against arbitrarily delayed dispatch.

Resolution: bounded per-TTY output serialization, acquired after device open, with suspension and
current target/policy checks inside the serialized write. Recovery persists suspension before
using the same serialization. A hung target is a reported partial failure; healthy fanout continues.
Tests pause writers before open and before their serialized check. No provenance/control plane
or generation-counter ceremony is introduced.

### R3: Global-pause release can erase focus and replay historical output

Confirmed as a missing transition contract. Scheduler.swift:393-395 and 469-473 clear then replay
pending OSC. Broadcaster.swift:38-88 resets/replays palette, background, title and possible BEL.
Original ownership/precedence requirements imply recomposition but did not expressly state it.

Resolution: global-rule release resets its legacy colors, then recomposes current background
with active focus. No opaque pending replay, old BEL or stale title. Merge Restore Terminal Colors
into Restore Visibility. Test a quiet period ending during Manual focus.

### R4: Dead ownership and previous-instance paint need cleanup

Confirmed contract gap. Mode Off on launch did not specify repainting prior effects. The existing
mute path has PID/heartbeat liveness, but no new controller-owner contract existed.

Resolution: effect records retain owner PID/start time and heartbeat, renewed every two seconds
and expired after six seconds. Ordinary hooks ignore dead/stale owners. Relaunch reconciles
valid prior paint to current intent/default. Plain shells can retain paint after abrupt death until
recovery/relaunch; no watchdog daemon is promised. Test next-hook and relaunch restoration.

### R5: Neutral backgrounds may show no de-emphasis

Confirmed acceptance gap. Reducing zero chroma produces no visible difference. The original
word "prefer" did not mandate a chroma-only algorithm, so that part of the review was overstated.

Resolution: allow bounded luminance adjustment and require visible de-emphasis of neutral dark
and light plain shells, plus configured normal-text contrast of 4.5:1 or no worsening of an already
lower baseline. Test ANSI/TrueColor separately. Report an unavailable safe effect honestly;
do not claim exact knowledge or contrast compliance for arbitrary application colors.

## MEDIUM findings

### R6: Shared state paths and lifetime are unspecified

Clarification accepted. Persistence across reboot was already required, but `/tmp` alone cannot
satisfy it. TAVSApp.swift uses both runtime and `~/.tavs` state roots.

Resolution: a short shared-resource table places suspension/priorities under `~/.tavs` and typed
per-TTY runtime records under `/tmp/tavs-$UID/organizer`. Atomic schema-1 parsing has common
shell/Swift fixtures; cleanup follows binding invalidation, not arbitrary observation age.
Application identity uses verified PID/start time with unavailable handling.

### R7: Deployed copies can retain the old restriction predicate

Confirmed deployment risk. cmd-sync.sh:65-67 and 85-99 updates installed shellrc and hook copies;
lock-state-lib.sh:8-13 names duplicated predicates. No source claim needs the review's unsourced
"project memory notes" reference.

Resolution: shared fixture parity plus existing sync and dedicated deployed acceptance, including
owned old idle workers that loaded previous functions. Preserve agents. Version stamps and
additional deployment-warning machinery are not needed.

### R8: Emergency restoration bytes are ambiguous

Clarification accepted. Background-only clear and global palette/foreground recovery were both
specified, but their final results were not sufficiently distinguished.

Resolution: preview/Focus Off restores valid current background intent or OSC 111 only. Emergency
recovery emits OSC 104/110/111 and leaves configured defaults; the next genuine hook may restore
ordinary theming. No OSC 0 is sent, so an old lock title can remain until the next title event.

### R9: Activation while suspended is unspecified

Clarification accepted. Suspension already takes precedence; mode-control behavior remained open.

Resolution: disable Manual/Automatic activation with an explanation. Harmless previews remain
possible. New global rules/locks are recorded but visually inert, with GUI/CLI status explaining
application on explicit resume. Focus stays Off on resume.

### R10: Vanished and failed targets need different outcomes

Confirmed reporting gap. Registry entries can outlive surfaces. ProcessRunner.swift:60-62 collapses
open errors into deviceNotWritable, so that error alone cannot prove disappearance.

Resolution: restored, confirmed vanished, skipped unaffected and failed/unverified outcomes.
Confirmed disappearance is not an error; live timeout or uncertain binding is. Persistence/helper
failure is nonzero. Retain failed targets. Do not silently infer errno the writer did not expose.

### R11: A missing helper should not prevent suspension persistence

Accepted resilience improvement, not a contradiction: original SPEC explicitly reported helper
failure. lock-state-lib.sh:64-88 already supplies an atomic shell-write pattern.

Resolution: the CLI persists suspension before launching the separate Swift repaint helper.
Helper failure leaves suspension saved and reports a nonzero incomplete repaint.

### R12: Existing bypass writers need explicit coverage

Confirmed. idle-worker-background.sh:127-149 forces unsuppressed resets; trigger.sh:291-323
replays cached bytes directly, and 534-554 dispatches a delayed tool-error update.

Resolution: name these paths in the extension points and test their ownership/suspension behavior.
Forced resets use the bounded serialized path. Invalidated pending bytes cannot be replayed later.
Current legitimate title generation is preserved; historical replay is not restoration.

### R13: Eligible observation correlation needs a predicate

Confirmed contract gap. TTY ancestry alone is weaker than native-surface/producer lifetime binding.
Ghostty's PID is foreground process information, not necessarily the hook process itself.

Resolution: current native lifetime/TTY plus verified emitting-agent generation on that controlling
TTY in its foreground process family, or a previously adopted record with a still-valid binding.
Missing/mismatched generations are ineligible. Reject the suggested first-catalogue timestamp
rule: it would also reject legitimate records after TAVS-only restart. Age alone proves neither exit
nor currency.

### R14: Completion-only release needs an honest coverage explanation

Confirmed consequence of D15/D17, not authority for new hooks. Current Codex adapter is completion
only; direct work resumption cannot be observed through it.

Resolution: rows explain that Go To acknowledges; test that direct resumption alone is not inferred.
Known exit, Focus Off and recovery remain available. No native-focus acknowledgement or richer
Codex lifecycle integration is added.

### R15: Phase 1 needs useful internal delivery order

Planning refinement accepted. Original phase did not require one atomic all-output delivery.

Resolution: catalogue/priorities/Go To first, independent recovery second, previews/intent ownership
third. These remain phase 1 slices and introduce no approval gates or ceremony commits.

### R16: Timing needs observable bounds

Clarification accepted. Two-second refresh/preview and 100 ms device deadline already existed;
native/config requests and cancellation tolerance were not numeric.

Resolution: two-second request deadline, four-second healthy catalogue update, preview tolerance
250 ms, one-second paint after validated policy change and existing 100 ms caller deadline.
Validation latency is bounded separately. These are engineering defaults, not new user knobs.

### R17: Suspension status and resume wording need clarity

Clarification accepted. Resume Visual Restrictions was already qualified, but persistent status
and legacy reset overlap could still confuse users.

Resolution: Re-enable Visual Restrictions in GUI; keep `tavs recover --resume`. Show suspension
in menu bar, Sessions and CLI status, explain immediate schedule application and merge old Restore.

## LOW findings

### R18: Selection timer, armed refresh and menu reachability

Accepted: each selection change restarts the shared two-second timer; deselection/closing clears
preview. Any non-Off mode refreshes, including Automatic with zero cues. Focus Off is in the menu.
Visibility hints require native evidence; unsupported minimized/Space information is not promised.

### R19: Limit constructed native commands

Accepted small test safeguard. The review's perform-action knowledge was not supplied in its
excerpt. Parent inspection of installed Ghostty.sdef confirmed explicit input text, send key,
perform action, split, close and quit alongside focus/tab/window operations.

Resolution: allow property reads, focus, select tab and activate window only, with a command-
construction test. No guessed action semantics, private Space API or input automation is needed.

### R20: Hard-lock help/status must explain recovery suspension

Accepted implementation documentation task. Current hard-lock.md:5-21 and cmd-lock.sh:113-154
describe lock/challenge behavior without the future independent suspension. This is not evidence
of a missing feature already claimed as shipped.

Resolution: phase 1 updates help/reference/status to distinguish configured locks from visual
suspension. October reversible testing and D12 authorize recovery without a challenge.

## Falsified objections and remaining limits

Installed Ghostty does expose native ID/TTY/PID. General ProcessRunner.run is unbounded and
unsuitable. Recovery bypass of legacy locks is the selected scope, not a July-spec contradiction.
Harmless preview during suspension is consistent. Native focus acknowledgement would change
D15. A last-dispatch cache can still contain an old BEL; no historical replay is justified.
No measured AppleEvent polling cost or new mid-sequence injection defect was established.
The scheduling E2E isolation warning is supported by its real-home cleanup and inherited HOME.

The raw summary departed from falsification-first calibration by including praise; that style
deviation does not replace source verification. All 20 findings were evaluated before version 1.1
changes. No live AppleEvent, OSC, provider delivery, app installation or visual test occurred,
and no new Claude score/approval of version 1.1 is claimed.

## Accepted execution risk and follow-up

- [ ] TODO: investigate the Claude hub timeout that forced the degraded CLI path. Start with
  `claude-hub doctor`, its operating runbook and `/Users/cs/local/code/apps/claude-hub/`
  `logs/2026-10-05.jsonl`. This infrastructure follow-up is outside TAVS implementation scope.

Related: [Codex review](CODEX-SPEC-REVIEW.md), [research synthesis](../RESEARCH-REPORT.md).
