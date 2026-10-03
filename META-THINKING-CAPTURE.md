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

## Stubs

<!-- Mid-task micro-captures (observe action). Folded into the next full
     entry, then deleted. -->
