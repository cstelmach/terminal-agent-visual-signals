# TAVS: priority discovery and research synthesis

Last Updated: 2026-10-05 (Europe/Vienna)
Version: 1.2
Status: Discovery finalized through D18; SPEC implementation status remains draft.
Source checkout: `/Users/cs/local/code/apps/terminal-agent-visual-signals`
Source commit: `b047a33761144f7a6fa0eca90a656dab21033fc6`

## 1. Recommendation and initial vision

Build a session organizer in the existing macOS companion, starting with local Ghostty terminal
surfaces. Let the user recognize sessions, inspect observed state, select several, and explicitly
navigate to one. Add manual priorities before automatic selective dimming. Every new visual
effect must have immediate undo without interrupting an agent or reconstructing a session.

This is the strongest product direction because it addresses the newest original request and
provides the target selection needed for later focus controls. Existing scheduling, quiet
periods, pause colors, themes and identity should be reused. A broad analytics, learning,
marketplace or standards project would delay this concrete benefit.

A second, potentially smaller project is updating the Codex adapter. Its completion-only
implementation reflects old integration assumptions, while current official documentation
offers substantially more lifecycle events. Exact runtime hookup still needs validation.
[OpenAI hooks][openai-hooks]

There are two distinct priorities:

- **Product priority:** organize and locate sessions, then support manual priorities.
- **Recovery prerequisite:** prove undo for any new highlight or restriction before relying on it.
  This does not require completing unrelated lock/reboot acceptance before a read-only list.

The initial vision is a small control surface for attention and navigation. It shows what TAVS
actually knows, lets the user decide what matters, and preserves useful awareness. It does not
infer task success from a green signal or user intent from whichever agent produced an event.

## 2. Research method, scope and evidence limits

Three Explore agents investigated architecture, plans and author requirements, and verification.
Three native web-research specialists then worked concurrently on distinct domains, beginning
with definitions and foundational rules before comparing approaches:

1. [Architecture exploration][explore-architecture]: current modules, metadata and recovery.
2. [Plans exploration][explore-plans]: original Obsidian passages, prior specs and duplicate work.
3. [Verification exploration][explore-verification]: tests, isolation, dependencies and live gaps.
4. [Targeting research][research-targeting]: native terminal APIs, highlighting, Spaces and
   permissions.
5. [Attention research][research-attention]: interruption evidence, control, breaks and
   notifications.
6. [Integration research][research-integrations]: provider events, metadata, analytics, themes
   and learning.

The full reports were recovered in the linked October 4 archive after the computer crash.
This synthesis retains their consequential
findings, disagreements, sources and limitations so the recommendations do not depend on those
ephemeral files remaining available. It removes repeated background rather than concatenating
the reports.

Before external research, `llm-wiki recall` searched the existing hub. Results did not answer
the TAVS engineering questions. The likely related AI-adoption synthesis concerned a different
research programme. Verdict: **proceed**. No wiki was created, promoted or modified.

The parent also directly checked key code, original journal passages, installed Ghostty's
dictionary, Codex's installed version, and central official web sources. Relevant memory was
used as a locator and then checked against current local evidence.

This was read-only product research. No live hook, AppleEvent, Accessibility probe, OSC write,
focus action, app restart, installer or production setting change was performed. No functional
test suite was run. Source presence and earlier test records are distinguished from current
live acceptance. No conversation bodies or transcript contents were inspected.

The 214-source intake is a bounded source index, not proof of semantic completeness. We read
the original passages supporting every proposed strand and the relevant implementation/spec
material; we did not reread every indexed file in full. The seven groups remain unconfirmed.
No idea-capture grounding, strand promotion, new project brief or duplicate disposition occurred.

## 3. Existing author decisions and source reconciliation

The strongest current author requirements are the October 2 request for higher/lower priorities,
marking windows, a better viewer/organizer, selection highlighting, possible navigation across
desktops, and multiple selection. Immediate reversibility is explicit in that original passage.
[October 2 journal][october-request]

The October 3 saved decision requires all testing restrictions to remain immediately reversible.
Stronger reversal friction is deferred until supported restriction/recovery paths are validated
without known unresolved defects and the operator confirms readiness. Finite tests cannot prove
absolute bug-freeness. This is already decided and should not be reopened in initial Q&A.
[Current progress decision][progress-decision], [deferred hardening task][hardening-todo]

The July hard-lock spec also establishes visual-only behavior. TAVS does not prevent input,
agent execution or new processes. Its older challenge/fail-closed choices describe implemented
commitment friction, but they do not override the newer testing direction.
[July authoritative plan][july-plan]

Discovery corrected several misleading locators and summaries:

- The hooks checkout resolves physically to the main TAVS repository.
- `IPC17_tavs.md` is an obsolete locator. The current [IPC17 project][project] points to that repo.
- Root PLAN/PROGRESS belong to July hard-lock work. The progress header is stale; its body has
  later implementation, repair and unfinished acceptance records. Do not overwrite that plan
  with this new feature's plan.
- `docs/specs/` is Git-ignored. Existing specs require an explicit bounded inventory that includes
  ignored files. The new dated package had no prior matching research package to continue.
- Open TaskNotes are reuse candidates, not evidence that their described features are absent.
  Branding and cross-platform notes still describe baselines that current code has surpassed.

## 4. First principles that constrain the design

### Identity, state and attention

An agent conversation, a process instance, a local TTY, a terminal surface, a tab, a window and
an OS Space are different objects. A TTY identifies an I/O endpoint; it does not identify a
permanent conversation or GUI window. Short IDs, directory paths, titles and icons help human
recognition but cannot safely choose a navigation target. A controlling-terminal session is
also distinct from a GUI surface. [Apple controlling-terminal reference][apple-tcgetsid]

Status, user priority, event urgency, selected rows and OS keyboard focus must remain separate.
A low-priority session can need permission, while a high-priority session may be computing.
Selecting several rows cannot mean giving all of them keyboard focus. A completion event
means a response ended under that provider's semantics; it does not establish task success.
[Claude hook semantics][claude-hooks]

### Awareness and interruption

Original interruption research supports managing interruption costs while retaining useful
awareness. It does not establish that hiding every other session improves coding. A workplace
email study found that suppressing notifications increased self-checking for some users and
reduced it for others. This supports an inspectable status surface as a design hypothesis,
with user testing still needed for TAVS. [Iqbal and Horvitz, 2010][awareness-paper]

Breakpoint notification research favors deferral at suitable task boundaries, but an agent
finishing is not evidence that its supervisor reached a human task boundary. Offer control
over interruption rather than automatically switching to every completed agent.
[Iqbal and Bailey, 2008][breakpoint-paper]

### Rendering and recovery

Visual dimming changes presentation. It does not stop input or computation. Clearing colors,
releasing a rule, restoring the latest agent styling, and suppressing old alerts are different
operations. Recovery is unsuccessful if the next scheduler tick immediately reapplies the
restriction. A successful device write also does not prove that the terminal displayed a
visible marker or readable content.

Selection, priority and status need text or shape as well as color. Readability must be checked
against real ANSI palettes and explicit TrueColor output. WCAG is useful guidance here, not
automatic certification of a native app. [Apple accessibility][apple-accessibility],
[W3C use of color][w3c-color]

## 5. Seven candidate strands: what exists and what remains

### 1. Organizer and window highlighting: strongest new feature

The Swift app exposes global pause/resume, restore, locks and preferences. It has no sessions
scene, organizer model, terminal activation adapter or native window/pane highlighting.
Existing icons, directory/worktree data, state and context can seed recognizable rows.
[MenuContent.swift][menu-content], [session-state.sh][session-state]

The user request is recent and concrete. Its main uncertainty is the supported surface and
meaning of highlighting. Exact Ghostty selection is promising on the installed build; native
pane borders and universal cross-Space behavior remain unproved. See section 6.

### 2. Reversible priorities and focus: adjacent second slice

User-assigned session priority is missing. Current `get_state_priority()` arbitrates competing
visual events over a short grace period; it is not task importance. Existing pauses and locks
are global. There is no selected working-set exemption or per-session dimming policy.
[session-state.sh][session-state], [scheduler][scheduler]

Start with manual ranking/pinning and explicit selection. Selective dimming is a separate choice,
with undo and failure tests. Automatic suppression when a high-priority session needs attention
should be opt-in later. Stronger locks remain deferred.

### 3. Breaks, restoration and notifications: extend the missing pieces

Allowed windows, hourly/daily quiet periods, pause foreground/background colors, pending state
replay and an active-only color reset already exist. Their specs and prior validation should
be reused. A relative countdown/Pomodoro and native desktop notification service do not exist
in the inspected Swift app. [Scheduling reference][scheduling-reference],
[pause foreground progress][pause-progress]

The October repair bounds terminal I/O, but current visual/menu acceptance remains unfinished.
Earlier pause tests do not accept every later recovery path. A timer, a reminder and deliberate
unreadability are different products. Existing wall-clock scheduling need not be rebuilt.

### 4. Task prerequisites and SnackStudy: useful optional handoff, unclear enforcement

The March author proposal ends its study consequence mid-sentence. The related open learning
TaskNote later shifts toward collecting lessons and spaced repetition rather than requiring
answers before coding. Preserve its separate ownership. [March 29 journal][learning-request],
[existing learning task][learning-task]

SnackStudy already parses `snackstudy://review/start`; its handler opens the relevant review
window. It explicitly ignores the parsed count. This supports an optional launch action,
not proof that a chosen number of cards was reviewed or a prerequisite completed.
[URL parser][snack-url], [actual handler][snack-handler]

A launch convenience can be small. Completion callbacks, learning effectiveness and enforced
prerequisites require separate decisions. Neither study completion nor exercise should gate
emergency recovery.

### 5. External status and agent/app integrations: a concrete Codex opportunity

Claude and Gemini adapters and an OpenCode plugin already exist. Codex currently uses legacy
completion notification wiring and an empty hooks placeholder. Current official Codex hooks
include prompt, tool, permission, subagent, compaction, interrupt and lifecycle events, with
session identity. This is an actionable adapter gap, rather than a reason for a new server.
[TAVS Codex installer][codex-installer], [OpenAI hooks][openai-hooks]

The installed CLI reports `0.160.0`. Actual trusted-hook delivery, ordering and TTY binding
still need a controlled test. GUI chats may have no corresponding user-facing terminal.
The app-server API provides runtime status to its clients, but does not by itself prove that
TAVS can attach to every already-running desktop chat. [Codex app-server][openai-app-server]

OpenCode also warrants compatibility checking before broad support claims. Its local custom
callbacks differ from documented plugin interfaces, and its one processing flag is not a
multi-session model. V2 requires implementation migration; this is a source-shape concern,
not a reproduced live failure. [TAVS plugin][opencode-local],
[OpenCode V2 migration][opencode-migration]

### 6. Analytics: later and explicitly bounded

Current cost/context/duration tokens are ephemeral display metadata. Historical analytics
requires retained transitions or aggregates and a retention decision. First make current state
honest. Later, counts of unresolved attention needs or observed waiting duration may be useful.
Processing time is not human work time, parallel sessions are not additive human hours, and
completion is not successful throughput. Minimize collected content.
[OpenTelemetry data minimization guidance][otel-sensitive]

### 7. Theme sharing and ecosystem: reuse existing work

Themes, per-agent overrides, background assets and identity customization already exist.
Reuse the open branding task. A preview/gallery or validated theme import is much smaller
than a marketplace, executable extension API or standards initiative. [Existing themes][themes],
[branding task][branding-task]

Current `.conf` presets are sourced by the shell. Downloaded theme files are executable input,
even if they resemble color assignments. Any future untrusted import must parse an allowlist
of values without evaluation. Executable plugins are a separate trust decision.
[Theme loader][theme-loader], [Gemini hook security][gemini-security]

## 6. Targeting, highlighting and navigation

### Exact native mapping first

Use a current exact join from the local TTY to the terminal application's own surface ID, then
its owning tab/window. Re-enumerate before navigation. Reject absent or ambiguous matches.
Do not choose a same-title or same-directory window automatically. Treat saved mappings as
caches, especially after app restart, tab movement or TTY reuse.

The installed Ghostty dictionary exposes IDs, TTY, foreground PID, working directory and focus
commands. Upstream main also exposes TTY/PID. The checked v1.3.1 release dictionary does not.
The installed version plist is opaque, so no semantic version is assigned here. A capability
check and live test are necessary; a minimum version cannot be inferred from this evidence.
[Installed dictionary][ghostty-installed], [development dictionary][ghostty-main],
[v1.3.1 dictionary][ghostty-tag]

Ghostty's documented focus action brings its window forward. Keep it behind explicit **Go To**.
Its release history includes a fix for tab selection unexpectedly activating the application,
which reinforces the need to test the actual build. [AppleScript guide][ghostty-script],
[1.3.1 release notes][ghostty-release]

### Three separate interactions

| Interaction | Intended effect |
|---|---|
| Select one or several rows | Change TAVS selection without changing keyboard focus |
| Locate/preview | Briefly mark currently visible exact surfaces; immediately clearable |
| Go To one row | Intentionally activate its mapped terminal tab/pane/window |

An OSC tint or label is a terminal-surface mark. It is not a native border. Hidden tabs,
minimized windows and other Spaces do not become visible merely because TAVS paints them.
Selection must not silently activate them to reveal their marker. When a preview ends, render
the latest state rather than an outdated pre-preview state. OSC resets restore configured
defaults, not arbitrary transient styling. [XTerm control reference][xterm-controls]

A true native Ghostty border remains an open capability question. Its scripting dictionary
provides no bounds, and no public exact join from its text IDs to CGWindowID or AX geometry
was verified. App PID or title alone cannot identify the correct rectangle. Test public AX
identifiers on duplicate-titled windows and splits before promising that feature.

Terminal.app's installed dictionary exposes tab TTY and owning-window bounds, giving it a
plausible containing-window outline route. That is still not a pane outline or validated
cross-Space navigation. iTerm2 documents more explicit session/tab/window selection semantics,
and is a good later adapter. [Apple Terminal scripting][terminal-script],
[iTerm2 scripting][iterm-script]

The targeting researcher favors Ghostty plus Terminal.app initially. The synthesis recommends
Ghostty first to constrain implementation and acceptance, while leaving Terminal expansion
as a genuine user option. Supporting more adapters gives breadth but increases permissions,
geometry and rendering combinations before the first organizer is useful.

### Spaces, permissions and broader surfaces

Use native targeted focus and verify its result. macOS application switching behavior depends
on user settings and display/Space assignment. No public arbitrary Space-number switching API
was verified. Do not substitute private APIs, simulated desktop-switch keys or window movement.
Multiple selected sessions across Spaces can remain selected; only currently visible members
can be highlighted. [Apple Spaces guide][apple-spaces]

AppleEvents Automation and Accessibility are separate permission paths. Test permission flows
from the actual built TAVS app. Request AX only for a feature that needs it. Keep enumeration
and actions bounded and off the UI path. After action timeout, inspect the actual result before
retrying a focus change. [Apple scripting guidance][apple-scripting]

tmux inner panes can have several clients or none; SSH terminal paths belong to the remote
machine. Neither is an exact local GUI binding. Leave those destinations explicitly unresolved
until an adapter establishes the relationship. [tmux concepts][tmux-concepts],
[OpenSSH terminal environment][ssh-manual]

## 7. Recovery and focus policy

The existing Restore Terminal Colors action refuses muted and locked states. Master Resume
re-evaluates the schedule, which may still demand a pause. The kill switch stops future output
but does not clear existing paint. None is a complete emergency recovery control.
[MenuContent.swift][menu-content], [scheduler][scheduler], [mute gate][mute-gate]

If recovery is selected, recommend one clear action outside the affected terminal that cancels
the active testing visual effect and prevents automatic reapplication until deliberately resumed.
Reuse bounded I/O and color-clear primitives. A CLI path is valuable if the menu app hangs.
Its exact scope over existing manual/scheduled hard locks must be decided before implementation;
this research does not change those locks or enable them.

Keep these meanings distinct in later controls:

- Stop the current focus effect until explicitly resumed.
- Suspend a rule until a displayed time, accepting that it will reapply.
- Skip one scheduled occurrence while preserving later occurrences.
- Disable the recurring rule itself.

Only one immediate escape action is needed initially. Implementing all four would exceed that
need. Temporary suspension or skip semantics can be added only if chosen. An override that
survives relaunch prevents a surprise reapplication; whether this belongs in the chosen slice
is an author decision rather than an assumed new state subsystem.

Recovery can be partial. Restore healthy targets promptly and name unreachable targets. Do
not close agent sessions to recover. Existing I/O tests cover stalled/backpressured devices,
but a kernel-blocked worker may outlive the caller deadline. Pruned terminals need a way to
rejoin discovery. [ProcessRunner.swift][process-runner], [broadcaster][broadcaster]

Prefer legible de-emphasis over hiding terminal text. Older author passages deliberately propose
unreadability, so this is a recommendation to discuss, not a silent deletion of that intent.
Any unreadable mode must retain recovery outside the affected terminal. Do not equate visual
restriction with enforcement of coding or process limits.

## 8. Notifications, breaks and optional learning

Use persistent status as the dependable attention record. Add native notifications only if
selected. Permission waiting, confirmed intervention needs and completion warrant different
policies; tool progress normally needs none. Deduplicate meaningful transitions, withdraw
obsolete notices, respect quiet periods, and never approve a permission from a notification.
Apple's urgency guidance supports ordinary notification levels for routine events, rather
than bypassing Focus by default. [Apple notification management][apple-notifications]

Visual dimming, sound and desktop delivery should be separately controllable. BEL behavior is
terminal-dependent and can even raise a window. BEL also terminates OSC sequences. Therefore
do not remove every BEL byte from pending data to suppress alerts. Separate alert events from
visual framing, or regenerate current visuals without historical alerts. Test for unwanted
alert bursts after recovery. [Ghostty BEL reference][ghostty-bel]

Fixed Pomodoro presets, adjustable relative timers and existing wall-clock quiet periods serve
different needs. A student study comparing break strategies does not establish an optimal
coding interval; laboratory vigilance findings also do not prove a software-work benefit.
Offer an optional adjustable timer if that is the chosen outcome, and test usefulness rather
than claiming universal productivity improvement. [Biwer et al., 2023][break-study],
[Ariga and Lleras, 2011][vigilance-study]

Voluntary prerequisites and a SnackStudy launch are viable contrasting approaches to harder
enforcement. Opening a study window is not verified completion. The user must choose whether
the goal is a reminder, a learning handoff or an enforceable condition. Stronger restriction
design remains deferred under the existing decision.

## 9. Metadata, integrations and history

For a first list, join existing metadata with native surface enumeration. Show missing fields
and observation age. Existing directories, emojis and short IDs are presentation hints.
Do not interpret 24-hour registry pruning, a missing hook or a quiet model request as death.
Revalidate identity when a TTY is reused or a conversation resumes elsewhere.

If adapter changes are needed, a small per-session metadata record is the recommended next
step: provider, full session identity, observed state/event, observation time, and optional
turn/subagent and destination identity. Keep user priorities separate from provider-written
state. No prompts, responses, raw tool arguments or transcript bodies are needed.

Separate records avoid cross-session overwrites. Current shared state/colors updates can lose
simultaneous changes because both writers read an old file then rename replacements. This is
a verified code-shape risk, not a reproduced bug. Same-session event ordering still needs tests.
Atomic replacement prevents partial reads; it does not merge concurrent updates.
[session-state.sh][session-state], [Apple rename semantics][apple-rename]

A local file contract is enough to begin. A Unix socket becomes worth considering only if
measured delivery/order needs cannot be met simply. Local HTTP, a new server, universal SDK,
database and marketplace are not prerequisites. Provider work must continue when TAVS is absent.

Gemini's documented inputs supply session identity; its best-effort session teardown means
absence still needs reconciliation. Subagent finish events must not finish the parent.
Codex async hook completion can reorder observations, so an older turn ending must not replace
a newer turn's processing state. [Gemini hooks][gemini-hooks], [OpenAI hooks][openai-hooks]

Desktop hooks may improve status coverage, but a GUI session requires an actual GUI-thread
binding. A tool's temporary terminal is not the user's chat window. Do not resume a chat or
inspect native session bodies merely to invent that association.

Analytics, if selected later, should begin with opt-in local aggregates and an explicit finite
retention choice. Paths and titles can be private too. Observed wait durations require coverage
labels; interrupted or missing intervals cannot silently count as successful work.

## 10. Verification appropriate to a chosen first slice

Current source contains 203 Swift test functions and 142 Bats cases. The latest recorded Swift
run passed 203 tests on October 3. These are source counts and historical results, not a fresh
suite run. The V1-V10 live hard-lock checklist and October visual/menu acceptance remain open.
[Current progress][progress-record]

For a read-only organizer, test inventory/identity, stale and ambiguous rows, same-directory
sessions, short-ID collisions, app restart, and missing metadata. No unrelated lock/reboot
programme is needed for that slice.

For navigation and visual effects, later acceptance should include:

1. Duplicate titles/directories, reordered tabs, moved splits and TTY reuse select correctly.
2. Row multiselection leaves the frontmost app and typing destination unchanged.
3. Explicit Go To reaches the intended tab/pane; unsupported/denied mappings show why it cannot.
4. Preview clear/expiry, new agent events, app failure and relaunch preserve current state.
5. Healthy terminals recover when another device stalls; partial failure is visible.
6. Existing quiet schedules do not immediately defeat an explicit recovery action.
7. Light/dark, grayscale, Increase Contrast, ANSI/TrueColor, hidden tabs and fullscreen behave
   within the stated support boundary.
8. Other Spaces, minimized windows and multiple displays are tested on the actual app build.
9. Hooks with missing/reordered events retain honest status and do not leak payload text.
10. If notifications are included, denial/Focus/quiet periods and obsolete alerts are handled.

Use dedicated test surfaces rather than working-session destruction. Real app behavior still
needs Computer Use or direct operator observation where tool access is unavailable.

The Swift suite, selected isolated Bats tests and sandboxed hard-lock E2E are useful later.
Do not casually run `tests/e2e/menubar-scheduling.sh`: it writes real schedule/mute state and
its cleanup removes mute.state. Legacy pytest fixtures also inherit real HOME in some paths.
Audit isolation before broad workstation runs. A green byte test is not a live appearance test.
[Scheduling E2E source][scheduling-e2e], [legacy fixtures][python-fixtures]

## 11. Initial Q&A and technical questions (research-start snapshot)

At this initial snapshot, no D01-DN decisions had been accepted. The recommendations here were
hypotheses. The subsequent one-by-one answers and D18 convergence are recorded in SPEC.md.
The inherited visual-only and immediately reversible testing requirements remain binding.

The first round should resolve four choices:

1. **First outcome:** recommend organizer/locate, versus recovery/selective focus, modern Codex
   signals, or break reminders. This determines which problem the first SPEC solves.
2. **Initial surface:** recommend local Ghostty tabs/panes, versus multiple terminal adapters or
   desktop chats. More surfaces require distinct identity and acceptance contracts.
3. **Priority behavior:** recommend manual marking/order first, versus immediate manual dimming
   or automatic attention-driven suppression. Only the latter two add restriction/recovery work.
4. **Output scope:** recommend one focused SPEC reusing existing notes, versus two separate specs
   or completing the seven-strand idea-intake output first. No duplicate projects are needed.

Subsequent rounds can decide visible marking versus true border, multiselect meaning, recovery
override duration/scope, which providers need richer metadata, ordinary-shell inclusion,
notification needs and support for remote/multiplexed sessions. Do not reopen settled choices.

Concrete technical uncertainty remains for live Ghostty ID lookup/focus behavior, exact AX
geometry, cross-Space visibility, trusted provider-hook delivery, and current OpenCode runtime
compatibility. Documentation cannot replace those small controlled probes. No minimum provider
version, universally correct freshness threshold, or TAVS productivity effect is established.

Initial convergence assessment: **not yet ready to draft a SPEC**. Research had narrowed the useful
space, but user intent and the first support boundary are still open. After answers, continue
only gap-directed research and decision rounds. Then draft the scoped SPEC, obtain the invoked
workflow's independent reviews, and stop at its handoff. This report is the starting material,
not an implementation plan or approval to activate restrictions.

## 12. Source register

All external pages linked here were retrieved on 2026-10-04 by the named research lanes or the
parent. Tagged releases, development source, installed dictionaries and empirical studies are
kept distinct. Some Apple web API pages exposed JavaScript shells; the targeting researcher
cross-checked the relevant installed SDK definitions. Blocked papers were not used as evidence.

Local source links refer to the inspected checkout and original Obsidian author passages.
The repository contains no product implementation from discovery. The selected specification,
source-linked research update, required review reports and session capture are the delivery work.

## 13. Confirmed scope and crash recovery, 2026-10-05

The operator completed one-by-one Q&A and confirmed D01-D18. The selected direction is one
phased SPEC: all local Ghostty native surfaces, a resizable organizer, surface-owned priorities,
two-second selection previews, explicit Go To, readable manual focus and opt-in automatic focus.
Recovery suspends visual restrictions until explicit resumption, including after TAVS restart.
Focus starts Off after restart. Existing provider signals are used; other strands remain deferred.

The old open-question lists above describe the initial research snapshot, not current product
uncertainty. [SPEC.md](SPEC.md) records choices, alternatives, rationale and acceptance criteria.
Live native behavior remains empirical implementation work; it has not been verified by this Q&A.

After the crash, all six /tmp reports were found in
`/Volumes/external/data/archive/tmp-by-day/2026-10-04/`. Their links below now point there.
The saved synthesis remained in commit `c1dd8b4`. No terminal/app restart or live settings change
was needed to resume discovery. No Ideas batch promotion or duplicate TaskNote creation occurred.

The final source check confirmed configured Ghostty colors can be read with `+show-config`.
That is configuration loading, not current per-surface dynamic-color capture. The selected
renderer uses background-only effects and restores current TAVS intent or Ghostty defaults;
it does not claim uniform dimming or exact preservation of application-painted cell colors.

## 14. Specification reviews and finalization, 2026-10-05

[SPEC.md](SPEC.md) version 1.1 preserves all eighteen decisions and includes three product phases.
Within phase 1, catalogue/priorities/navigation precede independent recovery, then previews.
Implementation planning and product code have not started; the invoked workflow now hands off
to a fresh conversation. Root PLAN/PROGRESS remain the separate existing hard-lock workstream.

Independent Codex and Claude reviews examined the unchanged version 1.0 specification. Both
returned CONCERN, with a reported technical grade of 6/10. Findings were verified against source
before revision; their complete source-verified dispositions are saved in
[Codex review](reviews/CODEX-SPEC-REVIEW.md) and [Claude review](reviews/CLAUDE-SPEC-REVIEW.md).
No provider assigned a new score or approval to the revised document.

AGY was attempted but failed HTTP 500 eligibility lookup without a report. The allowed technical-
failure substitution used Claude. Claude's canonical hub timed out with zero output, then its
documented CLI fallback completed; that execution remains DEGRADED, with served version
unobserved. The infrastructure follow-up is retained in its report rather than silently omitted.

The revisions define per-surface intent lifetime, permission-episode coalescing, navigation cue
cutoff and privacy across touched debug sinks. Recovery covers cached affected plain shells,
uses per-TTY write ordering with suspension checked inside the write, retains failed targets and
reports vanished versus unverified ones. Ownership expiry/relaunch, pause-end recomposition,
neutral-background visibility, timing and deployed-copy acceptance are now explicit.
These are runtime contracts for the selected feature, not a separate ledger or control plane.

Future implementation must still validate actual native API behavior, signal delivery and visible
effects using temporary paths and dedicated surfaces. Source review is not live acceptance.

[explore-architecture]: /Volumes/external/data/archive/tmp-by-day/2026-10-04/explore-tavs-architecture-20261004.md
[explore-plans]: /Volumes/external/data/archive/tmp-by-day/2026-10-04/explore-tavs-plans-20261004.md
[explore-verification]: /Volumes/external/data/archive/tmp-by-day/2026-10-04/explore-tavs-verification-20261004.md
[research-targeting]: /Volumes/external/data/archive/tmp-by-day/2026-10-04/web-tavs-targeting-20261004.md
[research-attention]: /Volumes/external/data/archive/tmp-by-day/2026-10-04/web-tavs-attention-20261004.md
[research-integrations]: /Volumes/external/data/archive/tmp-by-day/2026-10-04/web-tavs-integrations-20261004.md
[project]: /Users/cs/Obsidian/_/kn/projects/IPC17_terminal-agent-visual-signals/IPC17_terminal-agent-visual-signals.md
[october-request]: /Users/cs/Obsidian/_/journal/day/JD_20261002.md:36
[progress-decision]: /Users/cs/local/code/apps/terminal-agent-visual-signals/PROGRESS.md:370
[progress-record]: /Users/cs/local/code/apps/terminal-agent-visual-signals/PROGRESS.md:294
[hardening-todo]: /Users/cs/local/code/apps/terminal-agent-visual-signals/docs/todo/tPC17_20261003_gate-focus-restriction-hardening-after-reversible-testing.md
[july-plan]: /Users/cs/.claude/plans/i-had-following-thoughts-reflective-naur.md:57
[menu-content]: /Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/MenuContent.swift
[scheduler]: /Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/Scheduler.swift
[session-state]: /Users/cs/local/code/apps/terminal-agent-visual-signals/src/core/session-state.sh
[mute-gate]: /Users/cs/local/code/apps/terminal-agent-visual-signals/src/core/mute-gate.sh
[process-runner]: /Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/ProcessRunner.swift
[broadcaster]: /Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/Broadcaster.swift
[scheduling-reference]: /Users/cs/local/code/apps/terminal-agent-visual-signals/docs/reference/scheduling.md
[pause-progress]: /Users/cs/local/code/apps/terminal-agent-visual-signals/docs/specs/pause-foreground-control_2026-05-29/PROGRESS.md
[learning-request]: /Users/cs/Obsidian/_/journal/day/JD_20260329.md:26
[learning-task]: /Users/cs/Obsidian/_/todo/tasks/t_learn-while-ai-coding.md
[snack-url]: /Users/cs/local/code/apps/snack-study-app/SnackStudy/IPC/URLSchemeHandler.swift
[snack-handler]: /Users/cs/local/code/apps/snack-study-app/SnackStudy/SnackStudyApp.swift:504
[codex-installer]: /Users/cs/local/code/apps/terminal-agent-visual-signals/src/install/install-codex.sh
[opencode-local]: /Users/cs/local/code/apps/terminal-agent-visual-signals/src/agents/opencode/src/index.ts
[themes]: /Users/cs/local/code/apps/terminal-agent-visual-signals/src/themes/README.md
[branding-task]: /Users/cs/Obsidian/_/todo/tasks/tPC17_20260105-2008_agent-themes-branding-marketing-theme-collection.md
[theme-loader]: /Users/cs/local/code/apps/terminal-agent-visual-signals/src/core/theme-config-loader.sh
[ghostty-installed]: /Applications/Ghostty.app/Contents/Resources/Ghostty.sdef
[scheduling-e2e]: /Users/cs/local/code/apps/terminal-agent-visual-signals/tests/e2e/menubar-scheduling.sh
[python-fixtures]: /Users/cs/local/code/apps/terminal-agent-visual-signals/tests/conftest.py
[openai-hooks]: https://learn.chatgpt.com/docs/hooks
[openai-app-server]: https://learn.chatgpt.com/docs/app-server
[claude-hooks]: https://code.claude.com/docs/en/hooks
[gemini-hooks]: https://geminicli.com/docs/hooks/reference/
[gemini-security]: https://geminicli.com/docs/hooks/best-practices/#hook-security
[opencode-migration]: https://opencode.ai/v2/docs/build/plugins/migrate-v1
[otel-sensitive]: https://opentelemetry.io/docs/security/handling-sensitive-data/
[ghostty-main]: https://github.com/ghostty-org/ghostty/blob/main/macos/Ghostty.sdef
[ghostty-tag]: https://github.com/ghostty-org/ghostty/blob/v1.3.1/macos/Ghostty.sdef
[ghostty-script]: https://ghostty.org/docs/features/applescript
[ghostty-release]: https://ghostty.org/docs/install/release-notes/1-3-1
[ghostty-bel]: https://ghostty.org/docs/vt/control/bel
[terminal-script]: https://support.apple.com/guide/terminal/trml1003/mac
[iterm-script]: https://iterm2.com/documentation-scripting.html
[xterm-controls]: https://invisible-island.net/xterm/ctlseqs/ctlseqs.html
[apple-spaces]: https://support.apple.com/guide/mac-help/work-in-multiple-spaces-mh14112/mac
[apple-scripting]: https://developer.apple.com/forums/thread/759287
[apple-tcgetsid]: https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/tcgetsid.3.html
[apple-rename]: https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/rename.2.html
[apple-accessibility]: https://developer.apple.com/design/human-interface-guidelines/accessibility
[apple-notifications]: https://developer.apple.com/design/human-interface-guidelines/managing-notifications
[w3c-color]: https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html
[awareness-paper]: https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/253n-iqbal.pdf
[breakpoint-paper]: https://interruptions.net/literature/Iqbal-CHI08.pdf
[break-study]: https://bpspsychub.onlinelibrary.wiley.com/doi/10.1111/bjep.12593
[vigilance-study]: https://pubmed.ncbi.nlm.nih.gov/21211793/
[tmux-concepts]: https://github.com/tmux/tmux/wiki/Getting-Started
[ssh-manual]: https://man.openbsd.org/ssh.1
