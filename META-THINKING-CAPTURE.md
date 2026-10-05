---
capture_format: 2
---

# META-THINKING-CAPTURE

Per-session capture of *how* problems were approached: framing moves,
strategy selection, decision forks, failure arcs, verification habits —
with model attribution for cross-model comparison.

**Epistemic caveat:** a model has no privileged access to its own weights
or activations. `[O]` = observed behavior (trace/transcript/diffs);
`[R]` = post-hoc reconstruction — a hypothesis, never ground truth.

**How to read this file:** future sessions read the Pattern Index (and
Model Profiles) only. The Session Log is append-only evidence.

---

# Pattern Index

| ID | Pattern | Rule | Count | Models | Sessions |
|----|---------|------|-------|--------|----------|
| P1 | verify-constants-by-computing | Never hardcode a hash/digest/magic value in a test without computing it in the shell first | 1 | fable-5 | 2026-07-13 |
| P2 | probe-shell-semantics-before-harness | Before writing tests that depend on shell edge behavior (interactive flags, special vars), run a 1-line empirical probe of each shell | 1 | fable-5 | 2026-07-13 |
| P3 | run-suites-under-live-feature-state | After building a feature that mutates global machine state, re-run the full suite WHILE that state is active; leaks surface as themed failures | 1 | fable-5 | 2026-07-13 |
| P4 | set-e-last-command-guard | In sourced CLI functions, never end a function with `[[ ]] && ...`; use if-blocks + explicit `return 0` (dispatcher runs `set -e`, test harness may not) | 1 | fable-5 | 2026-07-13 |
| P5 | same-size-diff-means-substitution | A golden-file diff with identical byte counts points at an embedded variable token (icon, id, timestamp), not logic drift; go straight to xxd/cmp | 1 | fable-5 | 2026-07-13 |
| P6 | live-vs-tests | Sample the live process after tests | 1 | unverified | 2026-10-03 |
| P7 | capability-before-version | Check installed API capabilities before treating a version or current documentation as proof of local support | 2 | gpt-6 (self-reported; variant unverified) | 2026-10-04, 2026-10-05 |
| P8 | adjudicate-review-remedies | Verify each review finding in source, then select the smallest remedy for the actual gap | 1 | gpt-6 (self-reported; variant unverified) | 2026-10-05 |

---

# Model Profiles

<!-- One block per model string; only tendencies with evidence from ≥2
     sessions of that model. See the skill's references/distillation.md. -->

---

# Session Log

## 2026-07-13 · claude-fable-5 · tavs-hard-lock-discovery-to-deploy

meta:
  model: claude-fable-5
  model_source: observed (trace: 495 fable-5 turns vs 15 opus-4-8 subagent turns)
  interface: claude-code
  thinking: extended (ultrathink requested)
  session: 286d3a15
  trace: observed

**Framing** — Request: three rough feature ideas (autolaunch cleanup, all-terminal
coverage + "new sessions cannot be started", hard-to-reverse pause) plus a mandated
discovery Q&A phase. The literal "block new sessions" wording was contradicted by the
user's round-1 answer ("Visual only"); resolved by an explicit contradiction-check
question in round 2 rather than silently picking either reading `[O]`. Adjusted scope
became: visual commitment device, honest-friction framing.

**Strategy** — Parallel Explore agents (3) for research → adversarial review
(codex-reviewer, as user-directed advisor substitute after the advisor tool errored) →
2 AskUserQuestion rounds → Plan agent for implementation design → 6 phased execution
with per-phase suites and live verification. The reviewer's critique deleted planned
machinery (HMAC, watchdog, PATH shims) before any code existed; the deciding tradeoff
was "friction-honest beats security theater on an owner-controlled machine" `[O]`.

**Action trace [O]**

| # | Move | Object | Note |
|---|------|--------|------|
| 1 | Agent ×3 | Explore: autolaunch / mute / reach | parallel; plan-mode blocked /tmp reports → inline |
| 2 | Read ×3 | mute-gate, Broadcaster, trigger | verified subagent claims before design |
| 3 | Agent | codex-reviewer on vision doc | killed HMAC/shims; demanded failure-story |
| 4 | AskUserQuestion ×2 | scope/challenge/hardening + contradiction check | D1-D7 locked |
| 5 | Agent | Plan agent implementation design | anchors spot-checked afterwards (grep) |
| 6 | Write/Edit/Bash | phases 0-5, ~15 commits | suites after every phase |
| 7 | Bash | live: lock now, pkill-free fail-closed checks, app reinstall | found F1, F3 |

**Decision points** — (1) Visual-only vs blocking: explicit user confirmation.
(2) Login-item doctor as shell helper reusing existing `--unregister-login-item`
instead of a new Swift flag: explicit deviation, recorded in PROGRESS (SMAppService
cannot enumerate foreign registrations). (3) Scheduler init params default-derived
from muteStateURL so 3 existing test constructions stay untouched: resolved silently
in code comment — a default worth watching. (4) App-side puzzle pool embedded in
Swift rather than shared file: explicit (puzzles are per-side ephemeral).

**Failure arcs**

- **F1** · root: wrong mental model (set -e context)
  Symptom `[O]`: `./tavs lock now` printed nothing, exit 1; status "Lock: none".
  Reaction: re-ran with `bash -x`. Probe: trace ended at `[[ -z #4A4A4A ]]`.
  Correction: `[[ ]] &&` as a function's last line returns 1 under the dispatcher's
  `set -euo pipefail`; bats had sourced without set -e and hidden it. If-block +
  `return 0`. Residue: subsequent shell functions written with explicit terminators;
  P4 added.
- **F2** · root: environment surprise (test-infra isolation gap)
  Symptom `[O]`: `DIFF reset: baseline=77 bytes, current=77 bytes`.
  Reaction: ran diff twice (flakiness probe), then xxd + cmp. Probe: single 4-byte
  substitution = dir flag 🇧🇬→🇧🇪. Hypothesis (held): live identity registry leaks
  into "isolated" capture. Correction: isolate TAVS_RUNTIME_DIR in _capture_one.
  Residue: P5; and primed F3's diagnosis.
- **F3** · root: same class as F2, wider
  Symptom `[O]`: 10 bats failures (`stale heartbeat treated as unmuted` etc.) during
  the final suite run — which ran while my own live 2-minute verification lock was
  active. Reaction: hypothesis from failure NAMES alone (all fail-open assertions =
  suppression leaking). Probe: re-run post-expiry → 1 residual failure → read
  `_diff_all` → second un-isolated `env -i` (the earlier fix only covered
  `_capture_one`). Correction: isolated 4 test files; then deliberately re-ran the
  full suite UNDER a live 4m lock as proof (142/0). Residue: P3; hermeticity-under-
  live-lock became an acceptance criterion.
- **F4 (near-miss)** · root: fabricated constant
  Hardcoded a SHA-256 test vector from memory, computed `printf 'aabbsecret'|shasum`
  immediately after `[O]` → mismatch → fixed before any test run. P1.

**Heuristics** — P1-P5; also: cite file:line from subagents but re-read load-bearing
files before designing (caught nothing false this time, but F2/F3 show the same
discipline applied to test infrastructure paid off).

**Verification** — Every phase: swift test + bats + targeted live checks on the real
machine (real CLI, real app reinstall, real lock engage/expiry observed to the
second). Not verified: menu-bar dialogs and multi-terminal broadcast paint (require
interactive user; explicitly parked as V1-V10 checklist), Gemini/Codex/OpenCode
adapters under lock (out of scope, hooks unchanged).

**Pattern candidates** — P3 (run-suites-under-live-feature-state) is the promotable
one: generalizes to any feature that mutates ambient machine state (env kill
switches, daemons, global config). Watch for recurrence before promoting.

**Confidence** — Trace, symptoms, corrections `[O]`. Root-cause classifications and
the claim that F2 primed F3's fast diagnosis `[R]`.

---

## 2026-10-03 · model-unverified · tavs-terminal-restoration

meta:
  model: unverified (system context identifies GPT-6; exact runtime ID not verified)
  model_source: self-reported, reconstructed [R]
  interface: codex-desktop
  thinking: user requested ultrathink; runtime setting unverified
  session: 01a100cb
  trace: observed actions in the current conversation
  reviewers: Claude Opus requested but timed out; direct Codex reviewer model ID unverified

**Framing** [O]: The user reported gray Ghostty windows with disappearing text after a
nightly TAVS pause. Investigation established a daily 23:59-to-midnight gap and matching
pause foreground/background colors. The user explicitly retained that pause and requested
a manual baseline reset. Implementation therefore preserved settings and session lifetimes
while repairing terminal I/O and adding one active-only menu action.

**Strategy** [O]: Read source, installed configuration, projected mute state, and process
stacks before editing. Reuse the existing OSC clear operation for the menu action rather
than introduce another color reset path. Back up exact owned files and the installed app,
run real PTY tests, build/sign the replacement, then validate the installed behavior. The
first live check changed the implementation despite a passing test suite.

**Action trace [O]**

| Move | Object | Result |
|------|--------|--------|
| Inspect | Source, configuration, process sample | Blocking terminal opens identified |
| Test | Real PTYs and reset contracts | Initial 202-test suite passed |
| Install/sample | First nonblocking repair | macOS still blocked inside open |
| Fix/test | Outer completion deadline | Final 203-test suite passed |
| Recover | Installed app and live schedule | Pause/resume and fresh state updates observed |
| Review | External Claude and direct reviewer | Timeout recorded; direct source review approved |

**Decision points** [O]: Keep the operator-selected invisible pause colors rather than
replace them with a readability preference. Reuse installed ad-hoc signing rather than
create a new keychain identity. Bound the caller on a worker completion semaphore after
live evidence showed nonblocking flags did not bound this kernel condition. Keep native
device repair and an existing directory-watcher feedback concern outside the narrow patch.

**Failure arcs**

- **F1, runtime assumption** [O]: O_NONBLOCK plus a write deadline passed isolated tests,
  but the installed app again stalled in open. A fresh sample located the same native
  syscall instead of attributing the result to a stale binary. Correction: a 100 ms outer
  completion deadline and the same absolute deadline before open and writes. [R] The
  initial design treated the documented nonblocking behavior as a stronger guarantee than
  the live kernel provided. P6 records the resulting live-validation rule.
- **F2, test compilation** [O]: XCTAssertNoThrow inside an async closure was inferred as
  throwing by this compiler. Replaced it with explicit do/catch; the 64 KiB delivery test
  then compared the entire received payload successfully.
- **F3, unavailable review** [O]: The superseded Claude request was canceled and the final
  scoped request timed out without a report. Its failure record carries no scores or
  approval. A separate direct source review found no actionable regression.
- **F4, UI tooling** [O]: Computer Use rejected Ghostty and could not attach to TAVS after
  macOS retained the earlier killed processes in exiting state. Live validation used the
  existing schedule CLI and state file; visual acceptance was requested from the user.

**Verification** [O]: The final Swift suite passed 203 tests, packaged signature checks
passed, and the installed process completed a brief pause/resume cycle. Schedule and
user.conf were restored byte-for-byte. Ghostty and Claude processes were not stopped.
Fresh projected-state timestamps continued to advance. Actual menu clicks and visual
appearance remain unverified; kernel-stalled workers remain until macOS releases devices.

**Heuristics**: Treat tests as bounded evidence, sample the installed process when behavior
contradicts them, and preserve failed review status without inventing a verdict. Record
observed actions separately from explanations. Do not expand a narrow repair into unrelated
watcher changes or configuration resets.

**Confidence**: Execution results above are observed [O]. The explanation of the initial
assumption is reconstructed [R]. Exact model attribution is explicitly unverified.

### Fresh rebuild follow-up, 14:21 CEST [O]

The user explicitly requested another fresh build and replacement of /Applications/TAVS.app.
Used an unused Swift scratch directory, rebuilt release and tests, and assembled a new bundle
from the executable and source plist while retaining the icon. All 203 tests passed. Preserved
the previous app intact in the timestamped rebuild backup and relaunched the new app through
macOS using a new-instance launch. PID 23998 runs under launchd; signature checks and staged
binary/plist comparisons pass, and settings remain byte-identical. Source code was untouched.
Computer Use still cannot attach while macOS retains the older exiting app processes.

### Controlled restart follow-up, 16:50 CEST [O]

The user requested closing all TAVS processes and preserving terminal capture. Inventoried
the exact four app PIDs, backed up runtime state/settings, stopped the responsive instance,
and retried SIGKILL once for already exiting entries. Three kernel-held records remained.
Process ancestry identified 24 live GUI-terminal TTYs and four missing plain-shell markers.
Refreshed all registrations without deleting runtime data, then launched one responsive app,
PID 89556. All 24 markers exist, settings are unchanged, and Ghostty/Terminal stayed open.
Kept kernel record cleanup separate from app restart success instead of promising that a
successful signal guarantees process removal. Future automatic plain-shell discovery is a
separate optional choice; no source changes were made.

## 2026-10-04 · model-unverified · tavs-priority-research

meta:
  model: gpt-6 (self-reported; exact variant unavailable)
  model_source: self-reported
  interface: codex-desktop
  thinking: unknown
  session: 01a10879
  trace: reconstructed

**Framing.** [O] The user asked which existing TAVS ideas should be implemented and explicitly
invoked discovery-to-spec, initial Q&A and parallel native research. The research pass therefore
identified current implementation gaps and prepared decisions rather than implementing an
unselected feature. The existing author decision keeps testing restrictions immediately
reversible. Proposed intake groups were not treated as accepted requirements.

**Strategy.** [O] Three Explore tasks covered architecture, source requirements and verification.
Three native web specialists then covered terminal targeting, attention/recovery and integrations
concurrently. All six reports were read. The parent checked consequential findings against current
code, original journal passages and official sources before combining them into one report.
[R] Separating product priority from recovery prerequisites appears useful: a read-only organizer
does not need unrelated reboot acceptance, while new visual effects require their own undo checks.

**Action trace [R].** Reconstructed from the visible conversation, not a native transcript parser.

| # | Move | Object | Result |
|---|------|--------|--------|
| 1 | Read skills and memory locators | Discovery, research and recent TAVS history | Preserve scope and existing decisions |
| 2 | Inspect paths and Git | Physical checkout, ignored specs, original journals | Clean source baseline and corrected project locator |
| 3 | Recall wiki | Existing registered hub | No useful TAVS engineering coverage; proceed |
| 4 | Delegate exploration | Architecture, plans and tests | Distinguish existing capabilities from missing organizer |
| 5 | Delegate native research | Targeting, attention and integrations | Compare first principles and competing approaches |
| 6 | Check primary evidence | Ghostty dictionaries, Codex docs, code and studies | Capability differences and support limits retained |
| 7 | Synthesize and validate | Research report, links and text | Seven candidates assessed; first Q&A prepared |

**Decision points.** [O] The user explicitly selected native research, so AGY was not substituted.
The obsolete Obsidian project path was replaced as a locator after discovery of the current parent.
Existing state-event priority was kept distinct from user task priority. Ghostty's installed TTY
property was distinguished from its absence in tagged 1.3.1. Temporary surface marking was kept
distinct from a native pane border, whose exact geometry join remains unverified. [R] These
distinctions reduce the risk of writing acceptance criteria around unsupported assumptions.

**Failure arc F1: output budgeting.** [O] An initial combined tool result exceeded its output
budget, hiding portions of the skill/inventory reads. The next reads were split and results were
stored for selective retrieval. [R] The cause was aggregation beyond the direct result budget,
not missing files. Residue: separate essential source reads from large supporting inventories.

**Failure arc F2: stale locator.** [O] The old IPC17_tavs.md path did not exist. A bounded filename
search found the current project parent, which points to the same repository. No replacement
project or duplicate idea note was created. Residue: verify current locators before interpreting
a missing file as missing project context.

**Verification.** [O] Report checks verified reference definitions, every local source path,
coverage of all seven candidates, and absence of new em dash characters. The capture edit was
backed up first. No functional test, AppleEvent, terminal write, app action or production setting
change occurred. Earlier successful test counts were labeled historical; source counts were not
presented as a fresh run. No chat bodies or full prior capture log were read.

**Pattern candidate.** P7 records capability-before-version. A provider or terminal's current
documentation and an installed version string do not establish the exact available API or its
live behavior. This is one observation, so no model-profile generalization or skill promotion is
justified. The synthesis favors organizer/navigation and manual priorities, with Codex hooks as a
separate small candidate; those remain recommendations until the user answers the initial round.

**Confidence.** [O] labels refer to visible actions and checked results. The trace and causal
interpretations are [R]. Exact executor model attribution was unavailable; GPT-6 is self-reported
from the session environment, with its variant unverified. Research is complete for the opening
round. The SPEC, independent spec reviews and implementation remain pending scope decisions.

## 2026-10-05 · model-unverified · tavs-spec-recovery-and-review

meta:
  model: gpt-6 family self-report; exact variant unavailable [R]
  model_source: API environment self-report; no native transcript extraction
  interface: api (Codex desktop)
  thinking: unknown
  session: 01a10879-eec9-7202-be6a-df90356d7009
  trace: reconstructed from visible conversation and tool reports [R]

**Framing [R].** The operator asked to implement a plan whose final explicit boundary was
specification delivery, independent review and a fresh-conversation implementation-planning
handoff. The caller stated that interpretation before work. Eighteen product choices were
already confirmed individually; reopening them would not resolve the remaining technical gaps.
The useful output was a grounded SPEC with source-verified review dispositions, rather than
product code or another planning layer.

**Strategy [R].** Recovery after the computer crash began from the committed synthesis and
archived research reports. Existing dated-package reuse avoided another competing specification.
The selected workstream remained all local Ghostty surfaces, organizational priorities, manual
focus and opt-in automatic focus, with visual recovery first. Documentation was backed up before
editing. Independent review was held against one unchanged initial SPEC while local source
checks tested the findings. Product implementation and live settings were left for the handoff.

**Decision points [R].** First, ordinary background intent needed lifetime binding even though
files could remain per TTY; matching the new terminal's TTY did not authenticate an older record.
Second, recovery needed effect records for painted plain shells, but no separate ledger or
deployment-stamp system. Third, a pre-write generation check and a second repaint could still
race arbitrarily delayed work. The revised contract instead serializes per-TTY output after
bounded device open, checks suspension inside the write, and reports busy targets independently.
Finally, coalescing an observed permission episode avoids rearming a companion notification,
while Go To acknowledges only captured cue identities and leaves newer arrivals untouched.

**Failure arc F1 [R], environment surprise.** Temporary source reports disappeared after the
crash. The operator supplied the hourly archive location; all six October 4 reports were found
there. The existing committed synthesis survived. The correction was to repair source links and
continue from the locked decisions, without recreating discovery or inventing lost approval.

**Failure arc F2 [R], provider transport.** The AGY report records HTTP 500 during eligibility
lookup, empty stdout and no review. No quota signature authorized an alternate-account attempt.
The workflow allowed substituting another independent family. Claude then encountered a hub
timeout with zero output before its canonical CLI fallback completed. Process existence alone
did not establish generation. The final documents retain degraded execution and unobserved
served version, instead of presenting a generic success or an AGY approval.

**Failure arc F3 [R], context budgeting.** A batched report read exceeded the aggregate output
budget despite individually bounded commands. Narrower line ranges recovered missing findings.
One patch then failed because its expected sentence began mid-line in the target. A targeted
read corrected the context and the patch applied. The correction was to budget combined output
and inspect exact patch anchors, not to broaden scans or overwrite the whole file.

**Verification [O/R].** Current source checks confirmed paired Claude permission routes,
conditional raw-payload debug logging, registry pruning, direct forced resets and old full pending
replay. Installed Ghostty exposes input/close operations as well as navigation; the SPEC limits
constructed commands. AppKit documents nullable launch dates and warns against PID-only identity.
P7 recurs through this capability check. D01-D18 remain unchanged. Document validation checks
required sections, links, formatting, secret patterns and append-only capture preservation.
No app installation, OSC write, unsafe real-home E2E run or live rendering acceptance is claimed.

**Pattern candidate and limits [R].** P8 records source adjudication before adopting reviewer
remedies. A valid independent report does not establish that every suggested mechanism is useful.
Original CONCERN verdicts remain attached to version 1.0; the caller's revisions are not provider
approval of version 1.1. Neither P7's count nor this reconstructed entry identifies an exact model
variant, so Model Profiles gain no model-specific tendency. No skill-promotion threshold is met.

| Move [R] | Object | Observable result |
|---|---|---|
| Recover | Commit and daily tmp archive | Six source reports available |
| Consolidate | Eighteen choices | One phased SPEC, implementation status draft |
| Delegate | AGY, Codex and substituted Claude | Two complete reviews; failure warning retained |
| Adjudicate | Source, dictionary and SDK header | Minimal runtime-contract revisions |
| Preserve | SPEC, research, review synopses and capture | Durable source-linked handoff |

## Stubs

<!-- Mid-task micro-captures (observe action). Folded into the next full
     entry, then deleted. -->
