# Codex specification review and source-verified dispositions

Last Updated: 2026-10-05 (Europe/Vienna)
Version: 1.0
Target: [SPEC.md](../SPEC.md), original version 1.0, 419 lines
Source baseline: `c1dd8b470f546cc383cbc96c27d5248b0b7d2127`

## Execution and result

The independent canonical Codex CLI invocation completed with exit 0, one completed turn,
no failed turn and a nonempty final report. Mode was file/partial, standard spec calibration,
read-only and noninteractive. The command configured `gpt-5.6-sol` with high effort. This is
runtime configuration evidence, not server-side model attestation. CLI elapsed time was
286.990 seconds; the reviewer made no repository changes.

Original verdict: **CONCERN, 6/10, Medium risk**. Scores were clarity 6, completeness 5,
consistency 5, testability 6 and scope control 9. The mean is 31/5 = 6.2; the provider reported
a technical grade of 6/10. No revised-target score or approval is claimed.

The raw review classified all four findings IMPORTANT. Source evaluation retained three HIGH
findings and downgraded R2 to LOW. This document is a complete findings synopsis with parent
dispositions, not a verbatim transcript or a new Codex review of version 1.1.

Full evaluated report: `/tmp/codex-review-tavs-organizer-spec-20261005.md`.
Raw output: `/private/tmp/codex-review-files-terminal-agent-visual-signals-`
`tavs-organizer-spec-20261005_100354.md` (one filename, wrapped here for readability).
Independent CLI thread: `01a10b17-3e2b-7cb1-b65f-c0b6b73f2e96`.
Ephemeral files may subsequently move to the daily tmp archive. No private JSONL is included.

## R1: Intent must not transfer across TTY reuse

**HIGH, confirmed.** Ordinary intent was described per TTY, but restoring that record after
revalidating a new surface's ID-to-TTY mapping does not prove the record came from that surface.

Verification: installed Ghostty dictionary properties `id` and `tty` are separate. Existing
`src/core/session-state.sh:73-101` stores TTY/state/priority/time/timer without a surface-lifetime
binding. Original SPEC identity and observation requirements did not explicitly bind intent.

Resolution: version 1.1 binds/adopts intent against a verified surface or producer lifetime and
rejects unbound, old and late prior-lifetime records. Phase 1 tests close A, reuse its TTY for B,
then deliver a late A record. Clearing B must restore B's intent or OSC 111, never A's color.
Separate per-TTY files remain sufficient; no shared database is introduced.

## R2: Application-instance token needs a constructible source

**LOW clarification after evaluation.** Original SPEC already required reuse-safe application
identity. Selecting its internal token is ordinary implementation design, not a HIGH blocker.

Verification: Ghostty's installed dictionary has no application-instance property. AppKit's
installed `NSRunningApplication.h:103-112` exposes PID and nullable launch date, warns against
PID-only process comparison, and documents launch-date gaps outside LaunchServices.

Resolution: version 1.1 selects PID plus verified launch/start time, explicitly treating missing
generation evidence as unavailable. Tests retain priorities across TAVS-only restart, reset them
for a different Ghostty generation, and reject missing identity evidence. No proof machinery
for reports, prompts or deployments is justified by this runtime identity requirement.

## R3: Permission coalescing and navigation acknowledgement are ambiguous

**HIGH, confirmed.** Paired provider observations can otherwise rearm one acknowledged request.
A new cue arriving during asynchronous Go To can also be cleared without being visited.

Verification: `hooks/hooks.json:28-38` routes PermissionRequest and `66-76` routes
Notification(permission_prompt) to the same permission command. Existing core recording has
no cue-occurrence deduplication. This confirms the contract gap, not measured paired live delivery.

Resolution: version 1.1 defines one observed permission episode until verified resumption/exit,
coalesces companion observations and prevents their acknowledgement from rearming. Intake
delivery identity is stable through polling; supported turn IDs deduplicate completion delivery.
Completion-only providers can still create new completion occurrences. Ambiguous repeats cannot
trigger focus. Go To snapshots cue identities at dispatch and acknowledges only those on verified
success, leaving newer cues intact. Failure acknowledges nothing. Isolated fixtures cover each case.
No unsupported logical request identifier or additional provider hook is assumed.

## R4: Debug logging can retain prohibited payloads

**HIGH, confirmed conditionally.** Allowlisted observation records alone do not prevent the
existing reused debug path from retaining prompts, tool arguments or complete payloads.

Verification: `src/agents/claude/trigger.sh:16-22` captures stdin and `48-52` exports the raw
payload. `src/core/trigger.sh:114-166`, invoked at line 218, logs payload/direct stdin, arguments,
directory and process command lines under DEBUG_ALL. `session-state.sh:51-54` defaults DEBUG_ALL
to 0. No current private configuration or historical log was inspected; enabled logging is not
asserted as a workstation fact.

Resolution: version 1.1 extends the no-retention boundary to touched debug sinks, requiring
metadata extraction before raw discard. Existing legitimate metadata behavior must survive.
Future isolated tests enable debug and inject sentinel prompt/tool strings through exported
payload and direct-stdin branches, asserting absence from newly written files. Historical logs
are outside scope and must not be read, removed or rewritten by this work.

## Falsified objections retained

- Test isolation is specified. Scheduler already injects URLs/collaborators at lines 199-225;
  production TAVSApp construction uses real paths today. A small test launch route is future
  implementation work, not an absent isolation requirement.
- The strict device deadline is already required and implemented in ProcessRunner.swift:27-73.
  General subprocess `run()` is explicitly unsuitable. Neither observation justifies replacing
  the bounded writer or running the unsafe scheduling E2E script against the real home.

## Disposition and limits

All four findings were source-checked before changes. Version 1.1 resolves their contract gaps
and preserves D01-D18. No fresh provider review of that revision occurred. Local source and
dictionary/header checks cannot establish live AppleEvent behavior, provider delivery, Spaces
visibility or visible OSC rendering. Those remain isolated implementation acceptance work.

Related: [Claude review](CLAUDE-SPEC-REVIEW.md), [research synthesis](../RESEARCH-REPORT.md).
