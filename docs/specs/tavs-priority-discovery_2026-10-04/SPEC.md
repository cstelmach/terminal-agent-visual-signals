---
type: spec
spec-id: tavs-priority-discovery_2026-10-04
title: "TAVS: Ghostty organizer and reversible focus"
status: in-progress
phase: 8
created: 2026-10-05
updated: 2026-10-12
author: Codex
---

# TAVS: Ghostty organizer and reversible focus

Last Updated: 2026-10-05 (Europe/Vienna)
Version: 1.1 (discovery finalized; implementation not started)

## Project Overview

Extend the existing native TAVS companion with a local Ghostty session organizer, then manual
and automatic visual focus. Users can recognize every open terminal, assign importance,
select and briefly highlight several surfaces, and deliberately navigate to one. Focus reduces
background salience without blocking agents or input. Independent recovery restores visibility
and prevents restrictions returning until the user explicitly resumes them.

The audience is the existing macOS operator supervising several coding sessions. This package
reuses IPC17 and the existing [research synthesis](RESEARCH-REPORT.md). Eighteen choices were
confirmed one at a time. The October 3 direction requiring immediate reversal remains binding.
The directory retains the research-start date; this specification was authored October 5.

The work has not started. `status: draft` describes implementation status, not review quality.

## Goals & Success Criteria

- G1: Enumerate every native local Ghostty terminal surface, including ordinary shells, and
  distinguish duplicate titles/directories using exact native identity.
- G2: Preserve High/Normal/Low priorities through TAVS restart for still-open surfaces. New
  surfaces start Normal. Priority never transfers merely because a TTY or directory is reused.
- G3: Selection highlights exact surfaces for two seconds without activating Ghostty. Clear
  and Escape cancel previews immediately; Go To is the only organizer navigation action.
- G4: Manual focus captures a working set independently of later browsing selections.
- G5: Automatic focus reacts to supported, correlated high-priority attention observations,
  retaining all high-priority terminals and releasing after acknowledgement or resolution.
- G6: Recovery remains available during every visual restriction and when the menu app hangs.
  It preserves sessions, schedule definitions and input, and reports partial device failures.
- G7: Preview/focus changes preserve titles, foreground, palette and cursor. Their clearing
  restores current TAVS background intent or Ghostty defaults. Emergency recovery additionally
  resets legacy global foreground/palette restrictions as defined below.
- G8: Missing observations, unsupported APIs and uncertain targets are visible states, never
  inferred success, idle, task completion or permission approval.

## Architecture & Design

### Existing extension points

- `src/macos/TAVSApp/Sources/TAVSApp/TAVSApp.swift`: add a Sessions scene alongside MenuBarExtra
  and Settings. `TAVSAppMain.main()` already handles headless flags before starting SwiftUI.
- `MenuContent.swift`: add Open Sessions, Restore Visibility and explicit resumption controls.
- `Scheduler.swift`: integrate the recovery predicate with existing mute/lock evaluation.
- `Broadcaster.swift`: reuse target enumeration and title-free reset primitives; existing
  `broadcast()` replays pending OSC and must not be used as the preview/recovery renderer.
- `ProcessRunner.swift`: retain `SystemProcessRunner.writeToDevice()` and its 100 ms caller
  deadline. Its general `run()` method is not a bounded subprocess primitive.
- `src/core/terminal-osc-sequences.sh`: `send_osc_bg()` is the semantic background choke point.
- `src/core/idle-worker-background.sh`: route its direct OSC 11/111 writes through that helper.
- `src/core/trigger.sh`, `mute-gate.sh`, `lock-state-lib.sh` and `src/shell/tavs-shellrc.sh`:
  honor recovery suspension consistently wherever a visual restriction is checked or painted.
- Include idle max-runtime forced resets, debug pending replay and delayed tool-error updates;
  none may bypass suspension, background ownership or pending-output invalidation.
- `tavs` and existing `src/cli/` dispatch patterns: expose independent recovery commands.

Keep catalogue/navigation, focus policy and rendering separate concerns within small modules.
Reuse existing timers, clock injection, file watching and test doubles. No server, database,
network API, generic adapter SDK or replacement theme system is required.

### Catalogue and identity

One row represents one Ghostty native terminal surface. Store the current Ghostty application
instance, terminal ID, parent tab/window IDs and exact local TTY association. Application-instance
identity must distinguish process reuse. Native IDs are opaque, not eight-character conversation
keys, icons, titles or directory names. Moving a surviving surface does not change its priority.
Use PID plus verified launch/start time for the instance token. AppKit's nullable `launchDate`
alone is not always available; missing generation evidence is unavailable, never PID-only reuse.

Ghostty's installed dictionary currently supplies native IDs, TTY, foreground PID and focus.
Its tagged 1.3.1 dictionary lacks TTY/PID. Capability-check the installed API rather than asserting
an unsupported minimum semantic version. Missing permission/property, absent app, ambiguous
mapping and vanished target have explicit unavailable states. Do not substitute title matching.

Enumerate and navigate away from the main thread using serialized native requests with a
two-second deadline and at most one pending refresh. Bounded configuration subprocesses drain
output while running and terminate on the same deadline. Catalogue refresh is two seconds
while the organizer is open or mode is not Off, including Automatic armed with zero cues.
Revalidate the native target and TTY association immediately before navigation or a surface effect.
Timeout does not prove an action had no effect: inspect its result before any explicit retry.
Do not apply new effects from a catalogue whose identity refresh failed; show stale/unavailable
coverage while existing valid effect records remain recoverable.

Go To is one per-row deliberate action. It never sends terminal input, keys or permission
responses. Native focus is used for other Spaces; no private Space APIs, simulated desktop
switches or window movement. Visibility depends on macOS settings and must be tested.
Allow only property reads, `focus`, `select tab` and `activate window` in the adapter. Do not
construct `perform action`, input, key, split, close or quit commands. Hidden-tab hints use
supported selected-tab properties; do not invent minimized/Space visibility from missing data.

### Rows and persistent user state

Show title, directory/worktree context where available, provider where known, last observed
TAVS state and observation age. Distinguish shell/other-process rows from missing agent coverage.
An observed completion means a response ended, not that requested work succeeded.

Use High, Normal and Low. Sort by priority, retaining native window/tab/surface order within
each level. Priorities belong to native surfaces, survive TAVS restart while Ghostty's instance
and surface remain valid, and do not follow a conversation into a new terminal. Reconcile
closed/invalid surfaces on refresh. New surfaces, including after Ghostty restart, start Normal.

Focus mode is Off, Manual or Automatic. Browsing selection, captured working set, priorities
and attention cues are separate state. Focus starts Off on every TAVS launch, even if it was
active before. Closing the organizer cancels previews but does not terminate the menu app or
cancel an explicitly active focus mode. Persistent recovery suspension still takes precedence.
Each selection change restarts one two-second preview for all currently selected rows and
clears deselected rows. Clear, Escape and closing Sessions cancel the preview immediately.

### Observations and ordinary background intent

Use existing provider signals. Capture small per-TTY observations containing state/event,
observation identity/time and sufficient emitting-process identity for current correlation.
Read records as data, not sourced shell code. Do not retain prompts, answers, tool arguments,
transcript bodies or full provider payloads. Local titles/directories are display metadata,
not diagnostic log content or identity authority.
This boundary includes touched debug sinks, even with `DEBUG_ALL=1`. Extract needed allowlisted
metadata before discarding raw payloads; do not propagate or log full JSON, free-form arguments,
process command lines or stdin. Preserve existing legitimate metadata-dependent behavior.

Meaningful hook observations remain independent of timer-generated idle gradients. If the
emitting process or destination cannot be correlated, show last-known/unavailable coverage;
the record cannot trigger automatic focus. Age alone does not prove that a long-running agent
or shell exited. Codex completion-only coverage remains partial rather than inferred processing.
Correlation requires the same current native surface/TTY lifetime and a verified emitting-agent
process generation on that controlling TTY, belonging to its current foreground process family.
An ancestor lookup alone is insufficient. Alternatively, retain an observation already adopted
against that verified binding while its producer remains valid. Missing, mismatched, exited or
unverifiable generations are ineligible; elapsed age alone neither validates nor invalidates one.

Create a delivery identity once at hook intake and retain it through polling/idle rendering.
Use supported response/turn IDs when available; never invent provider request IDs. For Claude,
PermissionRequest and permission_prompt notification belong to one observed permission episode
until verified processing/resumption or exit ends it. Companion/late observations of that episode
cannot rearm an acknowledged cue. New completion hook deliveries can create new occurrences
even for completion-only providers, without requiring a processing hook between them. Supported
IDs deduplicate repeated delivery; ambiguous repeats are ineligible instead of guessed new work.
Go To snapshots that surface's cue identities before dispatch. On verified success it acknowledges
only those identities; cues arriving during navigation survive. Failure acknowledges none.

Retain the latest ordinary background intent per TTY: a normalized color or reset-to-default
intent. Update it even while preview/focus or a global pause owns the visible presentation.
Use independent per-TTY records with atomic replacement, avoiding shared-file cross-session
read/modify/write loss. Generated idle updates change background intent without creating cues.
Bind intent to the verified native lifetime or adopt it only from a still-valid producer on that
lifetime. Reject unbound, prior-lifetime and late records from a closed surface after TTY reuse.

The controller composes background effects over ordinary intent. Normal writers must not race
temporary controller ownership and erase effects or repaint cancelled restrictions. Establish
one coherent ownership path for controlled backgrounds; preserve direct ordinary signaling
when no controller owns an effect. Do not parse arbitrary OSC streams inside `emit_osc()`.

### Shared state and ownership lifetime

Use existing `~/.tavs` and `/tmp/tavs-$UID` conventions. Tests inject all roots. The persistent
suspension marker must never live only in `/tmp`. Keep schemas small, versioned and parsed as
data, with atomic same-directory replacement and shared shell/Swift fixture coverage.

| Resource | Location | Owner and lifetime |
|---|---|---|
| Suspension | `~/.tavs/visual-restrictions.state` | CLI/GUI; until explicit resumption |
| Priorities | `~/.tavs/surface-priorities.json` | GUI; validated Ghostty surface lifetime |
| Observation/intent | `/tmp/tavs-$UID/organizer/` | Hooks; separate per-TTY typed records |
| Effect/ownership | Same runtime directory | Controller; every painted target |

The marker starts with schema 1 and a suspended boolean. Effect records retain the target
binding, latest effect and controller PID/start time/heartbeat before painting, so a separate
recovery process can discover affected plain shells without shell integration or Automation.
Refresh ownership every two seconds while needed. A dead generation or heartbeat older than
six seconds is not an active owner; ordinary hooks then paint their current intent. On launch,
mode Off reconciles valid prior effects and clears them to current intent/default. A plain shell
may retain paint after an abrupt crash until recovery or relaunch; no watchdog daemon is added.
Confirmed closed bindings may be retired. Timeouts/unverified live targets remain retryable.

### Rendering and precedence

Apply these rules in order:

1. Recovery suspension disables global and selective restrictions. A new explicit harmless
   selection preview remains possible; recovery itself clears current previews.
2. Without suspension, an existing global pause/lock owns its visual. Show why a selection
   preview or selective focus effect is unavailable under that global rule.
3. A selection preview temporarily overrides selective dimming on selected surfaces.
4. Manual/automatic focus applies readable de-emphasis outside its emphasized set.
5. Otherwise apply current ordinary TAVS background intent or Ghostty defaults.

New preview and focus effects change background only. Keep foreground, ANSI palette, cursor
and titles intact. Reduce chroma where useful, with a bounded luminance adjustment for neutral
backgrounds. A neutral dark and light plain shell must visibly differ from an emphasized shell;
a no-op transform fails acceptance. Use a distinct conservative tint for previews. Maintain
configured normal-text contrast of at least 4.5:1, or do not worsen an already lower baseline.
This engineering threshold uses [W3C contrast guidance][contrast]; it is not a claim that arbitrary
program colors comply. Verify representative ANSI/TrueColor readability separately. If no safe
visible effect can be produced, expose that limitation rather than claiming dimming succeeded.
Clear/expiry recomputes from latest ordinary intent,
not a snapshot captured at selection time. Clearing a preview must not release manual focus.

For ordinary shells without TAVS background intent, resolved Ghostty configuration can guide
color selection. `ghostty +show-config --changes-only=false --no-pager` loads configuration;
it is not a getter for running per-surface dynamic colors. Use OSC 111 when clearing those
background-only effects. Do not use OSC 110/104 for an effect that only changed background.

Applications can paint explicit cell backgrounds or set dynamic colors outside TAVS. Such
content may obscure a cue. Exact restoration of those arbitrary colors is not promised.
Configuration changes, light/dark variants and launch overrides require live acceptance.
No OSC query/reply capture or input interception is introduced for color discovery.

When a global pause/lock ends normally, reset its legacy foreground/palette changes, then
recompose current background intent with active focus. Do not use opaque pending OSC replay
for controlled output. No historical BEL/title replay is allowed on this transition. Merge the
legacy Restore Terminal Colors action into Restore Visibility instead of retaining two resets.

## Public Controls and Recovery Contract

The GUI exposes Open Sessions, High/Normal/Low priority, Go To, Clear Preview, Focus Selected,
Focus Off, Automatic Focus, Restore Visibility and Re-enable Visual Restrictions. Focus Off
and recovery remain reachable from the menu without opening Sessions. Suspension is visible
in the menu bar, Sessions, `tavs status` and `tavs lock status`.

`tavs recover` suspends all visual restrictions and clears effects. `tavs recover --resume`
removes that suspension and allows existing rules again. Both reuse a separate headless Swift
process, not the running GUI's event loop. Required installed/built helper failures are explicit.
The CLI atomically persists suspension using the shared shell state helper before launching
Swift for repaint. A missing/failed Swift helper returns nonzero but leaves suspension saved.

Recovery must first persist suspension and invalidate temporary rendering ownership, then
repaint reachable targets. The marker/state survives app restart and reboot until explicit
resumption. Underlying schedule, lock configuration and grant definitions remain intact.
Recovery never demands a password/puzzle, quits an agent, closes a terminal or sends input.

Resume does not restore a previous Manual/Automatic mode. Focus remains Off until explicitly
enabled. Explain when an existing schedule will apply immediately on resumption.
While suspended, Manual/Automatic activation is disabled with an explanation. New legacy
locks/rules can be recorded but remain visually inert; GUI/CLI report that they apply on resume.

Global recovery sends OSC 104/110/111 to reverse existing palette/foreground/background changes
and restore configured defaults. Unlike ordinary preview/focus clear, emergency recovery does
not immediately reapply ordinary themes. The next legitimate hook can restore those themes;
old lock titles may remain until a new title event because recovery sends no OSC 0.
It must not replay historical pending OSC, bells or stale titles,
including later on resume. Invalidate obsolete pending output while preserving current typed
observations/background intent; do not strip BEL bytes indiscriminately from OSC framing.

Recovery targets the union of effect records, active-TTY registry and current native catalogue
when available. Include unregistered painted shells. Validate cached bindings through current
native identity or verified continuing TTY-owner process generation; uncertainty is a reported
failure, never authorization to paint a reused TTY. A hung GUI is not a dependency. No native
Automation access is required to restore cached targets whose binding can still be validated.

All managed background and restrictive writes use shared per-TTY output serialization. Open
the device with the bounded writer before acquiring a short advisory lock, so a hung open cannot
hold serialization. Check suspension and target/ownership validity inside that serialized write.
Recompute the current restriction policy there; do not trust a queued decision from an earlier rule.
Recovery persists suspension first, then uses the same serialization to reset targets. Thus an
earlier write finishes before reset, or its policy check rejects it after suspension. A generation
check followed by an unlocked write, or a second repaint alone, does not establish this ordering.
Shell-startup restriction paints and forced resets must use this path rather than direct printf.
Retain the 100 ms caller deadline across open, lock acquisition and write, late-open protection
and independent healthy-target fanout. Busy or unverified targets are partial failures.

Report restored, confirmed vanished, skipped unaffected and failed/unverified targets separately.
Exit zero means suspension persisted and no live target failed; confirmed vanished targets are
not failures. Exit nonzero means persistence/helper failure or an incomplete live repaint.
Generic `deviceNotWritable` cannot establish disappearance; require native absence or validated
device/process evidence. Keep failed targets for retry. Zero affected targets is successful
suspension with zero restored. Resume reports its persisted result and any immediate rule paint.

## Decisions & Rationale

### D01: First outcome
Question: organizer, Codex signals, recovery/focus, or breaks first?
Decision: organizer first.
Rationale: newest author request; provides exact targets for later focus behavior.

### D02: Initial surfaces
Question: Ghostty, multiple terminal apps, or desktop agent chats?
Decision: local Ghostty first.
Rationale: installed native API supplies the required IDs/TTYs; one support boundary is testable.

### D03: Priority behavior and sequence
Question: ranking/marking, manual dimming, or automatic dimming?
Decision: all three desired, implemented step by step in that order.
Rationale: operator selected the staged direction rather than requiring every effect in v1.

### D04: Specification scope
Question: one phased SPEC, organizer-only SPEC, or an additional Codex workstream?
Decision: one phased SPEC for organizer/ranking, manual focus and automatic focus.
Rationale: one coherent direction; other strands do not delay the organizer.

### D05: Catalogue membership
Question: all native Ghostty terminals or recognized agent terminals only?
Decision: all Ghostty terminal surfaces, including plain shells.
Rationale: terminals remain useful targets as agents start/exit; missing coverage stays explicit.

### D06: Organizer UI
Question: resizable window, menu-bar popover, or floating panel?
Decision: dedicated resizable window opened from the menu bar.
Rationale: enough space for multiple sessions, selection and priority controls.

### D07: Highlight mechanism
Question: terminal styling, required native outline, or navigation without highlighting?
Decision: temporary terminal-surface styling; native outlines deferred.
Rationale: existing OSC path is available; exact public pane geometry remains unverified.

### D08: Highlight trigger
Question: selection automatically highlights, or a separate Locate action?
Decision: selection highlights automatically; Go To stays explicit and separate.
Rationale: identify one/many terminals during selection without stealing keyboard focus.

### D09: Priority owner
Question: priority follows the terminal surface or agent conversation?
Decision: terminal surface; new surfaces start Normal.
Rationale: consistent across agents and shells without depending on complete provider IDs.

### D10: Manual working set
Question: Focus Selected captures a set, or focus always follows high priority?
Decision: explicit Focus Selected captures the selected surfaces.
Rationale: browsing and locating another row must not change what is dimmed.

### D11: Dimming strength
Question: readable de-emphasis or strong default-text suppression?
Decision: keep text legible.
Rationale: input and agents continue; unreadability would impede safe intervention.

### D12: Recovery duration
Question: suspension until explicit resume or a timed suspension?
Decision: until the operator resumes, persisting across TAVS restart.
Rationale: avoid surprise reapplication during testing; preserve recurring settings.

### D13: Automatic trigger
Question: high-priority permission/completion cues or permission only?
Decision: supported permission requests and completed responses.
Rationale: both can require attention; response completion is not task success.

### D14: Automatic emphasized set
Question: all high-priority terminals or attention targets only?
Decision: all high-priority terminals remain emphasized.
Rationale: other important work stays visible while Normal/Low terminals lose salience.

### D15: Automatic release
Question: acknowledge by Go To/resumed work/exit, or wait only for agents to resume?
Decision: release when no unacknowledged high-priority cue remains.
Rationale: visiting a target can address awareness without approving or completing anything.

### D16: Restart behavior
Question: focus starts Off or restores its previous mode?
Decision: Off after every TAVS restart; valid surface priorities are retained.
Rationale: predictable reversible testing while preserving organizational work.

### D17: Initial provider coverage
Question: use existing signals or add modern Codex lifecycle hooks in phase 1?
Decision: existing signals first; richer Codex coverage deferred.
Rationale: keep this work focused; partial observations are useful if honestly labeled.

### D18: Convergence and defaults
Question: retain the consolidated scope/defaults or adjust a requirement?
Decision: scope confirmed; High/Normal/Low and a two-second immediately cancellable preview.
Rationale: establishes actionable defaults without additional knobs or new candidate strands.

## Implementation Phases

### Phase 1: Organizer, ranking, previews and independent recovery

Inputs: current Ghostty API, existing TAVS signals/configuration, native SwiftUI app and
bounded I/O.
Outputs: Sessions window, exact catalogue/navigation, persistent priorities, preview renderer,
ordinary-intent/observation records, and GUI/headless recovery available before previews ship.
Implement in this order within phase 1: (1a) catalogue, priorities and Go To without background
painting; (1b) shared suspension and independent recovery; (1c) intent ownership and previews.
These are delivery slices, not additional approval gates.

Acceptance:

- All native surfaces appear, including plain shells and duplicate-titled sessions.
- Tab/split moves retain identity; a reused TTY never inherits a closed surface's priority.
- Reused TTYs reject old and late intent/observation records; a new shell clears to its own
  validated intent or OSC 111, never the previous surface's color.
- New surfaces are Normal; valid priorities survive TAVS restart and no focus mode resumes.
- Multirow selection does not focus Ghostty; two-second expiry/Clear/Escape restore current
  background without title or BEL replay, even when idle/agent color changes during preview.
- Go To uses the exact revalidated native target; denied/unsupported mappings are explicit.
- GUI and separate-process recovery suspend overlapping global rules without a challenge;
  suspension persists across restart/reboot and partial failures are accurately reported.
- Recovery from another terminal restores an unregistered painted plain shell. A paused GUI
  cannot later repaint queued restrictions; healthy targets restore despite hung/open-busy ones.
- Missing helper still persists suspension and reports repaint failure. Confirmed closed targets
  do not produce false failure; unknown bindings and live timeouts do.
- Suspended focus controls explain their state; new locks/rules remain inert and status reports
  suspension. Re-enabling warns about an immediately applicable schedule and leaves focus Off.
- Configuration, schedule definitions and live agent processes remain intact.
- Launch clears prior valid effects. After a killed controller, the next ordinary hook does not
  defer to dead/stale ownership. Failed targets remain retryable.

Verification: model/parser tests, shell intent/observation tests, owned PTYs and isolated GUI cases.

### Phase 2: Manual focus

Depends on phase 1 recovery and targeting acceptance.
Inputs: validated catalogue, priorities, selection and ordinary intent.
Outputs: Focus Selected/Focus Off and background composition for a captured working set.

Acceptance:

- Browsing selections and priority edits do not alter the captured working set.
- New surfaces remain outside it until included; losing the last target ends manual focus.
- Outside surfaces stay readable; titles, foreground, palette, cursor and input are preserved.
- Neutral dark/light plain shells are visibly de-emphasized, with the configured-text contrast
  bound satisfied. Representative ANSI/TrueColor content remains readable in live acceptance.
- Focus Off clears selective styling; Restore Visibility additionally suspends all rules.
- Previewing an outside surface does not remove it from dimming after preview expiry.
- Schedule transitions, sleep/wake, app exit and relaunch do not leave uncancellable effects.
- Ending a global pause while focus is active restores its dimmed set using current intent,
  without a bell or stale title replay.

Verification: pure focus-policy cases, rendering-byte tests, mixed-device failure and
live readability.

### Phase 3: Automatic focus

Depends on phase 2 manual focus and recovery acceptance.
Inputs: supported correlated meaningful observations, priorities and successful navigation.
Outputs: explicit Automatic mode and per-surface unacknowledged attention occurrences.

Acceptance:

- Enabling Automatic baselines existing observations; subsequent new eligible occurrences
  create cues. Old cached completion, polling and generated idle do not invent a new event.
- Permission/completion cues observed on High surfaces activate focus; Normal/Low or unknown
  observations do not. All High surfaces remain emphasized while any eligible cue remains.
- Paired permission observations coalesce; acknowledging an episode prevents its companion
  from rearming it. A new genuine eligible occurrence can create a new cue.
- Successful Go To acknowledges only its captured cue identities on that target; a later cue
  survives in-flight navigation. Failed navigation acknowledges nothing.
- Processing/resumption, exit, reset or invalid destination clears its cue. Downgrading a
  surface removes its cue eligibility; restoring High does not replay an old occurrence.
- Acknowledged occurrences stay acknowledged until a new genuine trigger; synthetic idle
  does not clear a still-unacknowledged completion merely because its background graduated.
- Multiple cues coexist; clearing one preserves the rest; zero cues releases dimming.
- Completion-only rows explain "Go To acknowledges". Direct work resumption cannot clear a
  cue without an observable signal; Go To, known exit, Focus Off or recovery remains available.
- Focus Selected switches to Manual; Automatic replaces Manual only by explicit activation.
- No automatic navigation, permission approval, input injection or inferred task success occurs.

Verification: deterministic occurrence/acknowledgement tests, process/TTY reuse cases and
isolated UI.

### Timing acceptance

The following are engineering defaults, not new user settings. Measure on healthy dedicated
targets; unavailable/backpressured targets must instead return explicit bounded failures.

- Healthy catalogue changes appear within four seconds (two-second cadence plus request bound).
- Preview duration is two seconds with 250 ms tolerance. UI cancellation is immediate; clearing
  a validated target, Focus Off and recovery paint finish within one second of the policy change.
  Any necessary native revalidation has its separate two-second bound.
- An eligible observation affects styling within one second after catalogue/producer validation.
- The device caller still returns within 100 ms, including serialization acquisition.

## Constraints & Boundaries

- macOS 13+; current Swift tools 6.0 / target language mode 5; Bash 3.2-compatible hooks.
- Local Ghostty native tabs/panes only. Outer surfaces hosting SSH/tmux can be listed, but
  remote conversations and inner multiplexer panes are not separately mapped or controlled.
- Supported installed native properties and actual Automation permission are prerequisites
  for exact navigation. No synthetic input, private Spaces APIs or guessed title targets.
- Color effects are background cues, not uniform cell/content opacity or execution controls.
- Every testing restriction remains immediately reversible. Stronger reversal friction is deferred.
- Existing provider coverage is partial; no raw chat/session-body inspection to fill gaps.
- New terminal adapters, desktop chats, native borders, richer Codex hooks, notifications,
  analytics, study prerequisites, theme sharing, marketplaces and protocol standardization
  are deferred.

## Rejected Alternatives

- Native pane outlines now: exact Ghostty-ID-to-rectangle mapping was not established.
- Agent-only catalogue: would omit useful ordinary-shell targets and lifecycle transitions.
- Conversation-owned priorities: provider identity is incomplete and would exclude plain shells.
- Automatic navigation with attention: conflicts with explicit Go To and keyboard-focus control.
- Unreadable dimming: conflicts with the selected readable behavior and intervention needs.
- Timed recovery resumption: would reapply restrictions without the operator's deliberate choice.
- Universal SDK/server/history database: no current requirement justifies these dependencies.
- Replaying entire pending OSC on preview/recovery clear: can restore stale titles and alerts.

## Verification Strategy

Use existing Swift and isolated Bats patterns. Source counts and earlier successful runs are
historical context, not proof of this feature. No claim of absolute bug-freeness is permitted.

Test identity under duplicate names, tab moves, process exit and TTY reuse; missing/malformed
records and property/permission failures; priority persistence; meaningful versus synthetic
observations; acknowledgement and multiple cues; concurrent records; and two-second expiry.

Use owned PTYs for background/reset bytes, healthy/dead fanout, backpressure, independent
recovery and delayed restrictive-write rejection. Preserve the 100 ms completion deadline.
Inject a writer paused before device open and another paused before the serialized policy check;
release them after suspension to prove neither can repaint old restrictions. Kill an owner and
test lease expiry/relaunch cleanup. Check constructed native commands against the allowlist.
Assert no new foreground/palette/title/cursor changes from background-only effects and no
historical alert replay during recovery or later resume. Run representative dark/light,
ANSI/TrueColor and configuration-change readability cases.
With debug enabled, inject sentinel prompt/tool strings into exported-payload and direct-stdin
paths. New observation/debug/state files must contain only allowed metadata, never the sentinels.

Live Computer Use acceptance must use dedicated Ghostty surfaces and temporary preference,
schedule and runtime paths. Restrict the test catalogue/output targets to those surfaces;
an isolated registry alone is insufficient if discovery repopulates it with working sessions.
Exercise hidden tabs, splits, minimized/fullscreen windows, other Spaces and multiple displays.
If tool access prevents a visual case, obtain direct operator observation and leave it
unverified until then. Do not claim that a successful byte write proves visible rendering.

Do not run `tests/e2e/menubar-scheduling.sh` against the real home directory: it changes live
schedule/mute state. Audit legacy pytest fixture isolation before broad workstation runs.
Use source-only builds and tests before any live install. Protect app/settings/runtime state
before an authorized deployment; preserve terminal/agent sessions and stage exact owned paths.
Commit each implemented logical feature with its tests after verification, without
ceremony commits.

Before live deployment, test shared suspension semantics across core, shellrc and GUI fixtures.
Use the existing sync path for cache/marketplace and `~/.tavs/shellrc` copies; restart only owned
old idle workers whose loaded code would bypass it, preserving agents. Verify deployed behavior
on dedicated surfaces. No deployment-stamp system is needed. Phase 1 updates hard-lock/recovery
reference documentation and CLI help/status to distinguish configured locks from suspended visuals.

## Open Questions and Empirical Limits

No product-scope question remains open after D18. Capability and behavior checks remain work
for implementation: native ID specifiers, target focus/visibility across Spaces, current color
reset behavior, Automation permission from the built bundle and installed provider delivery.
Failure of a prerequisite is a reported unsupported/blocked capability, not permission to
substitute guessed targeting, another provider, stronger locks or a new control plane.

## Sources and Review Notes

Primary local evidence: [research synthesis](RESEARCH-REPORT.md),
[current recovery decision](../../../PROGRESS.md#^focus-restriction-testing-decision),
[hard-lock limits](../../reference/hard-lock.md), and the extension points named above.

Primary external references:
- [Ghostty scripting](https://ghostty.org/docs/features/applescript)
- [Installed versus tagged source](https://github.com/ghostty-org/ghostty/blob/v1.3.1/macos/Ghostty.sdef)
- [Background reset](https://ghostty.org/docs/vt/osc/11x)
- [Configuration loader](https://github.com/ghostty-org/ghostty/blob/main/src/cli/show_config.zig)
- [BEL and OSC framing](https://ghostty.org/docs/vt/control/bel)

Independent reviews examined the unchanged 419-line version 1.0, with source baseline `c1dd8b4`:

- AGY was invoked but failed eligibility lookup with HTTP 500 and returned no review. No AGY
  approval exists. The workflow's technical-failure substitution used independent Claude.
- [Codex review](reviews/CODEX-SPEC-REVIEW.md): CONCERN, 6/10; three material contract gaps and
  one lower-severity identity clarification after source verification.
- [Claude review](reviews/CLAUDE-SPEC-REVIEW.md): CONCERN, 6/10; five HIGH, twelve MEDIUM and
  three LOW findings. The canonical hub timed out with no output, then its documented CLI
  fallback completed. Execution is DEGRADED; Opus was requested, served version unobserved.

All findings were checked against source before revision. Version 1.1 clarifies lifetime binding,
cue coalescing/acknowledgement, debug privacy, recovery target coverage/write ordering, ownership
liveness, pause release, restoration bytes, suspended controls, test deployment and visible/timed
acceptance. These changes preserve D01-D18. Reviewer proposals for a separate ledger, deployment
stamps and extra phase gates were not adopted. Per-TTY effect state and output serialization
address actual runtime failures, not process provenance.

Accepted risks: the substituted Claude path is degraded, and no reviewer assigned a new score
to version 1.1. Detailed dispositions are in the linked reports. Investigating the hub timeout
is an infrastructure follow-up, not part of this product. Native behavior, provider delivery and
live visual acceptance remain unverified implementation work. This is a finalized discovery
document with implementation status `draft`, not a claim of shipped functionality or approval
of the revised target. Continue through the requested fresh-conversation planning handoff.

[contrast]: https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
