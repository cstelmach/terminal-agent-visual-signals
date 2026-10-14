> [!NOTE] EXPLICIT CLAUDE CLI REVIEW
> The caller selected real `claude -p`; Claude Hub retains disable, volume and concurrency controls.

# TAVS current implementation: actual Claude partition reviews

Target: Git commit 7ecfba2. Review date: 2026-10-14.
Overall coverage: PARTIAL. Eight real Claude subcalls completed. The final delivery/CLI-recovery
subcall exited 1 without a report. No host analysis replaces that missing review.

Selected route: claude-cli-explicit, explicitly requested by caller. Every completed subcall
returned exit 0 and that stderr execution label. Requested model: opus. Observed model and effort:
unknown. Effort requested: unspecified. Original provider NOTE banners and all findings are kept
unchanged below. No automatic fallback or degraded route was used.

No tests, builds, app launches, Ghostty control, installation, real-home/runtime inspection or
source edits were performed. Source was pre-gathered using current local files with line numbers.
No other reviewers' output was read. Native/visible/Space/readability/permission and Linux kernel
acceptance remain unverified. Source review cannot establish them.

## Coverage

| Subcall | Actual scope | Outcome |
|---|---|---|
| part01 | native catalogue, UI, priorities and startup | Full supplied subscope, exit 0 |
| part02 | attention reducer and focus controller | Full supplied subscope, exit 0 |
| part03 | visual state, renderer and bounded writer | Full supplied subscope, exit 0 |
| part04 | persistent recovery and suspension | Full supplied subscope, exit 0 |
| part05 | scheduler and broadcaster | Full supplied subscope, exit 0 |
| part06 | portable backend and ordinary compatibility | Full supplied subscope, exit 0 |
| part07a | managed hook routing | Full supplied subscope, exit 0 |
| part07b | shell colors and titles | Full supplied subscope, exit 0 |
| part08 | installation/sync/standalone delivery and CLI recovery | FAILED, exit 1, no review |

Native UI/focus and writer/recovery/scheduler partitions were reviewed. Ordinary hook/portable
behavior was reviewed, but delivery/CLI-recovery remains incomplete. Generic unchanged wizard,
status and theme CLI commands were not a target of the last scoped delivery call.

Provider scope-label correction: part03 and part06 inherited the first prompt partition label.
Their explicit inventory and named subscope were correct. Actual part03 belongs to Partition 2;
part06 belongs to Partition 3. No source or test contents were altered by this label error.

## Main actual-Claude findings to verify and resolve

The following summarizes provider findings. Host source notes are separate. Part06 returned VETO;
other completed calls returned CONCERN. No new holistic grade or host review is invented.

1. Ordinary Linux output is lost: portable capabilities/verbs reject non-Darwin, and routed output
   has no backend there. Raw fallback or README narrowing would not satisfy the agreed end state.
2. Broader-provider contexts are accepted but observations only permit Claude/Codex, whereas
   synthetic idle/tool-error renders require a matching observation. Native validation has the
   same restriction. Reproduce existing Gemini/OpenCode behavior before fixing bookkeeping.
3. Successful recovery followed by resume/refocus can retain an old painted focus lease and report
   false cleanup failure. Preserve accurate per-target failures when correcting this lifecycle.
4. Failed release reconciles lack unmuted heartbeat retries. Strict per-target effect decoding can
   also block emergency reset after target/descriptor validation. These are distinct recovery cases.
5. Idle/forced-reset titles bypass title mode/lock/base checks. Some shell suites drop private-root
   and helper variables, use stale pending assertions, or turn mismatches into skips. Do not run
   those suites unchanged against shared/live paths.

Additional findings remain in originals: unavailable marker versus full render, partial-mapping
status, effect/target retention, root ownership, title escaping, compact context eye, Bash3.2,
bell settings and diagnostics. Performance thresholds, native behavior and watcher feedback are
unmeasured or unresolved, not established defects by this host.

## Corrections and cautions

- Part01 R4 is disproved overall: real SessionsModel deferred-navigation, late-cue and failed-
  navigation tests are in focus-controller-tests.swift:158 onward, supplied in part02.
- Part07a U1 context rejection is disproved: portable_metadata.PROVIDERS includes Gemini,
  OpenCode and unknown. Observation rejection is the actual synthetic-idle issue.
- Part07b R5 overstates shared-state mutation: identity-teardown carries TAVS_TMP_DIR; counter-
  integrity drops it. Both still omit explicit helper/test-root variables.
- Part07b U1 control-byte injection is dismissed by native/portable C0/C1 render validation.
- Marker revision mismatch does not prove device restoration succeeded. Preserve partial failures.
- Reconcile(resetLegacy:false) also considers inactive global records. Verify needs before a blanket
  resetLegacy:true retry, especially for failed registrations that never applied a pause.
- Quarantine/deletion, runtime cleanup, caches and large refactors are reviewer suggestions, not
  performed or automatically accepted changes.

## Final subcall failure

The required review-via-claude-hub.sh wrapper was called with prompt
/tmp/claude-tavs-review-context-20261014/08-delivery-compatibility-prompt.md,
explicit --transport claude-cli --model opus --timeout 1800, required marker
===END_REVIEW_META===, and intended report
/tmp/claude-review-tavs-current-followup-20261014-part08.md.

Unified session 55229 ended with exit 1. Wrapper stdout and stderr are empty. Debug output and the
intended report are absent. Failure cause and observed route for that call are unknown. Per the
mandatory contract, no review exists for this subcall. It was reported immediately and was not
retried or replaced with host findings or another provider.

Failure evidence files:
- /tmp/claude-tavs-review-context-20261014/part08-wrapper.stdout
- /tmp/claude-tavs-review-context-20261014/part08-wrapper.stderr

## Host source verification notes

These validate hypotheses and are not actual Claude reviews.

### part01

# Host verification notes for actual Claude part01 output

Original provider report: /tmp/claude-review-tavs-current-followup-20261014-part01.md
Source inspected at Git commit 7ecfba2. These notes validate claims; they are not a Claude review.
No tests, apps, native requests or runtime operations were run.

- R1: Source confirms each continuing update invokes colors and the production callback resolves
  configuredColors, then publishes the focus lease and returns background output when no global
  rule owns it. Cost, escape-stream interleaving incidence and required optimization are unmeasured.
  Do not accept the proposed configuration mtime/size cache without checking included theme/config
  dependencies and preserving fresh recipe behavior. A new cache is not established as necessary.
- R2: Source confirms cancellation marks focus leases retiring, preserves mayHavePainted, and later
  clearFocus cancels exact metadata before opening. Revision mismatch can return no bytes; the
  controller only removes a lease on restored/vanished or ownershipResolved AND not mayHavePainted.
  Therefore the described false cleanup status path is supported by static source. No discriminating
  test was run. Headless recovery persists a replacement marker separately, consistent with trigger.
- R3: selection.didSet calls preview when selection differs and organizer is open/available;
  acceptCatalogue intersects selection after assigning surfaces. Thus pruning a closed selected row
  can start a new preview for survivors. Whether that behavior violates the agreed intent is a UX
  interpretation, not proved by the static code alone.
- R4: SessionsModel tests contain navigation calls but no model-level occurrence acknowledgement
  assertions. Reducer/controller tests are intentionally in part02 and were not supplied to part01.
  Treat this as a narrow integration-test gap, not absence of all acknowledgement coverage.
- Native U1-U3 remain hypotheses. No physical proof or current Ghostty state was gathered.

Part02/current-source follow-up correction:
R4 is disproved as an overall test gap. focus-controller-tests.swift:158 onward contains
 testSessionsAutomaticNavigationAcknowledgesOnlyItsSnapshotAndKeepsPolling, using a real
SessionsModel, deferred navigation and a second cue arriving before successful completion.
The immediately following test covers failed navigation. File placement outside the model-test
filename caused the part01-only coverage limitation. Preserve the original provider claim but
exclude R4 from required fixes once all scopes are combined.


### part02

# Host verification notes for actual Claude part02 output

Original provider report: /tmp/claude-review-tavs-current-followup-20261014-part02.md
These are source checks at 7ecfba2, not a host-authored Claude review. No tests or native/runtime
operations were performed.

- R1: The recovery/resume/refocus revision mismatch and mayHavePainted bookkeeping mechanism
  is supported by source, consistent with part01 R2. Existing recovery test creates a new
  controller and does not exercise recovery/resume/refocus on the same one.
- R2: Source confirms renewed requires targets.count == outside.count. A healthy mapped subset
  can have actual successful output while the summary says background effects were not renewed.
  The proposed status-count fix is distinct from changing painting safety or target verification.
- R3: Source confirms every changed automatic High set calls retireFocus, which retires all
  current leases and creates a new run. Clear/reset plus repaint for unchanged outside targets
  is a source-grounded mechanism; visible flashing and measured cost remain unverified.
- Scope completion: all supplied reducer/controller tests and connected native state/writer code
  are named in the provider metadata. Startup and physical native behavior were correctly kept
  outside this subcall and unverified. No material source finding was silently omitted.


### part03

# Host verification notes for actual Claude part03 output

Original provider report: /tmp/claude-review-tavs-current-followup-20261014-part03.md
Source checked at 7ecfba2. These notes are not a substitute review. No tests/runtime were run.

- R1: Source confirms emergencyReset calls cacheTargetUnlocked and effectsUnlocked before its
  branch. The latter strictly validates effect records, including heartbeatAt <= wall clock.
  A bad/future effect record therefore prevents reset bytes after descriptor validation. The
  effect-record variant is supported statically. An unavailable native alias is a separate target
  confidence issue, not automatically a healthy target. Preserve ambiguity/scope checks when
  designing a remedy; do not blindly bypass all alias validation or quarantine/delete records.
- R2: Source confirms bindOrdinaryIntentUnlocked reads existing boundIntent before replacement;
  bound records have strict decoding/validation without the latest-record recoverInvalid path.
  Treat preservation of unsupported schemas and valid fresh-publication repair separately.
- R3: Target-directory/withLock checks enforce file types and mode 0600 for lock files, but the
  inspected native store/entry/intake sources do not check st_uid. Source supports missing native
  ownership validation. Multi-user spoofing exploit and blast radius were not reproduced.
- R4: Source confirms fanout catches unspecified errors as a fixed generic reason. It preserves
  target/status but loses cause distinctions. This is a diagnosis limitation; the proposed large
  closure refactor is optional and not established as necessary by a specific defect.
- Scope labelling: provider metadata calls this Partition 1 because the reusable prompt header
  retained the first label. Actual named subscope 03-visual-writer and explicit source/test list
  correspond to the caller's Partition 2. This does not change the supplied reviewed contents.


### part04

# Host verification notes for actual Claude part04 output

Original provider report: /tmp/claude-review-tavs-current-followup-20261014-part04.md
Source inspected at 7ecfba2. No tests, native/runtime or real-home operations were performed.

- R1: Source confirms Scheduler heartbeat only calls retryFailedRestrictions while muted and
  restrictions active; Broadcaster targeted retry uses currentRestriction. A failed release
  reconcile after unmute therefore has no heartbeat retry, and manually invoking that targeted
  method under no current rule yields no restoration. Existing healthy full rebroadcast methods
  remain available; the gap is retrying a failed transition for a plain shell without another event.
- R2: captureRevision refuses unavailable marker status; full render/forced reset beforeOpen
  calls it. Policy status text says restrictions disabled until repaired. Source confirms the
  distinction from background-only ordinary writes. Any remedy must retain inode pinning and
  no-follow/nonregular-file refusal; do not equate unknown regular schema with arbitrary unsafe
  marker objects.
- R3: Confirmed source lacks native closed-target directory retirement. Exact cost/report growth
  impact is unmeasured; indiscriminate recursive deletion is not an acceptable direct remedy.
- R4: Large closure is evident but refactoring is optional absent a specific behavior defect.
- Broader-provider parity from part06: terminal-visual-state.swift:902 limits observations to
  claude/codex, matching the portable validator limitation. Existing normalized bookkeeping for
  Gemini/OpenCode therefore also requires source/runtime verification on native path.


### part05

# Host verification notes for actual Claude part05 output

Original provider report: /tmp/claude-review-tavs-current-followup-20261014-part05.md
Source checked at 7ecfba2; no build/test/app/native/runtime operation was performed.

- R1 duplicates part04 release-retry mechanism, adding a source-supported post-prepare device
  failure variant. However, reconcile(resetLegacy:false) also considers any stored global record,
  including canceled ones, at visual-recovery.swift:365. Therefore the alleged reset obligation is
  not lost to a later reconcile, although ordinary render alone differs. Do not blanket-reset
  unrelated failed registrations without verifying which failure actually requires legacy reset.
- R2: Source ordering places inherited test-env isolated launch before several later diagnostic
  CLI branches. This is a narrow test-environment robustness edge, not a real-home permission claim.
- R3: Production ignores visual arguments and reads persisted policy; Scheduler evaluates provider
  again during projection. Mock-only visual assertions cannot prove projected colors. This is a
  test-design concern; a production discrepancy would require a provider/config change between
  calls, not assumed from the test names.
- H5: Directory watcher plus unconditional atomic mute-state rewrites suggest feedback, but no
  runtime verification was performed here. Keep it unresolved, including whether it predates the
  organizer implementation.
- Broadcaster tests were supplied to part04. Statements about their absence in part05 are local
  input limitations, not absence of whole-repository coverage.


### part06

# Host verification notes for actual Claude part06 output

Original provider report: /tmp/claude-review-tavs-current-followup-20261014-part06.md
Source inspected at 7ecfba2. These checks are not a Claude review; no tests or runtime were run.

- R1: Confirmed statically: portable_helper gates all supported verbs/capabilities to darwin;
  helper-selection cannot select that backend on Linux, and render_flush emits no raw OSC. This
  contradicts the existing ordinary standalone Linux promise. Implementing Linux support is the
  scoped remedy; raw printf on no-helper failure conflicts with the agreed managed-output boundary.
- R2 provider variant: Confirmed mechanism: metadata/context accepts broader providers but
  observation decoder only accepts claude/codex; synthetic intents require a matching observation.
  Gemini/OpenCode/unknown synthetic renders therefore lack that required record. Expanding safe
  ordinary bookkeeping must preserve automatic focus eligibility and payload privacy. Manual
  transient-producer variant remains conditional on exact foreground/caller lineage, not proved
  for every documented invocation here. Native parity requires separate inspection.
- R3: Source confirms cached walks all owner-generation directories in a per-TTY bucket and checks
  each candidate; no portable closed-generation retirement path was found. Exact timeout threshold
  and effect under runtime load are unmeasured. Proposed unlink/prune and the synthetic 500-entry
  test are not automatically authorized runtime deletion operations and must preserve unknown/live
  bindings; no such cleanup was performed by this reviewer.
- R4: Multiple helper launches are present, but latency is unmeasured. Cache proposals must keep
  actual selection/failure and changed-helper behavior correct.
- R5: Concrete-device validation rejects generic /dev/tty. The claim that every deep agent falls
  back there requires the actual resolver/TTY ownership path; treat this as a compatibility edge,
  with concrete resolution inside the trusted helper as a proposed remedy rather than guessed ID.
- R6: _text rejects Unicode format characters, while Render safe_text rejects C0/C1 controls only;
  forced_reset invokes the stricter validator. ZWJ-containing titles can therefore differ. No owned
  shell reproduction was run.
- R7: Output lock checks st_uid, but inspected parent creation/directory validation does not check
  root UID/modes. Multi-user exploit remains untested. No private/runtime state was inspected.
- Scope label correction: actual portable backend scope belongs to caller Partition 3; inherited
  prompt label caused provider metadata to say Partition 1. File lists and reviewed content remain
  the explicit portable/helper-selection/hook/idle scope.


### part07a

# Host verification notes for actual Claude part07a output

Original provider report: /tmp/claude-review-tavs-current-followup-20261014-part07a.md
Source inspected at 7ecfba2. No suite or runtime/native action was executed.

- R1: Linux ordinary output regression is already confirmed in part06. Narrowing the README
  promise would shrink the agreed compatibility scope and is not an acceptable implementation
  remedy. No raw output fallback should be added on reviewer authority alone.
- R2: Confirmed source: lock-gate.bats uses env -i without explicit helper/test-root or TAVS_TMP_DIR,
  makes a regular-file fake TTY, and asserts obsolete pending replay. Dropped TAVS_TMP_DIR causes
  session-state to use shared /tmp/tavs, despite an outer isolated harness. Do not run unchanged.
  No installed app binary or live runtime was inspected by this reviewer.
- R3: session-state defaults to shared /tmp/tavs and only creates/chmods it if absent. Existing
  directory ownership is not checked. State temp path is predictable and ordinary shell redirects
  follow symlinks. Title state uses mktemp but has a predictable-path fallback. Pre-existing
  multi-user risk is statically supported, but no exploit or user-file write was performed.
- R4: Source confirms hardcoded BELL_ON_* assignments after theme configuration loading and
  separate ENABLE_BELL_* defaults. Existing configuration intent should be checked before changing
  defaults; notification additions remain deferred.
- R5: Helper launches are evident, cost unmeasured. Persisted probe caches may hide changed helper
  behavior and are optional, not a required fix without measurement.
- R6/R7: Test dependency and weak-assertion observations are narrow test-quality notes. No tests ran.
- U1 is disproved as context intake rejection: portable_metadata.PROVIDERS includes gemini,
  opencode and unknown. Actual synthetic-idle issue is observation rejection from part06.
- U2 Store ownership/policy was supplied in part06; it must not be treated as missing overall.


### part07b

# Host verification notes for actual Claude part07b output

Original provider report: /tmp/claude-review-tavs-current-followup-20261014-part07b.md
Source checked at 7ecfba2. No tests, live/native or real-home operations were performed.

- R1 overlaps confirmed Linux/absent-backend output regression. Status text alone would not restore
  ordinary compatibility, and README narrowing would not satisfy the original requested end state.
- R2: Source confirms idle stages only check ENABLE_TITLE_PREFIX and build a title from SHORT_CWD;
  forced reset unconditionally passes SHORT_CWD. These paths bypass normal should_send_title and
  title-management lock/base logic. Actual owned-PTY title-off/lock reproduction remains to run.
- R3: Save escapes quotes/backslashes; read only strips outer quotes. The non-inverse roundtrip is
  evident and can compound when re-saved. No title-file mutation or reproduction was performed.
- R4: Face selection reads agent-resolved COMPACT_CONTEXT_EYE, title token suppression only reads
  the global variant. The configuration mismatch is statically supported; exact rendered duplicate
  count remains a test obligation.
- R5 correction: counter-integrity drops TAVS_TMP_DIR and uses || skip count assertions. In contrast,
  identity-teardown DOES pass TAVS_TMP_DIR (line55). Both omit explicit helper/test-root keys; do
  not repeat the claim that both mutate shared /tmp/tavs. Fixed fake TTY paths also need private
  scope review before any suite run.
- R6: Bash-4 ,, and ^^ expansions exist in terminal-detection.sh. Their reached image/query paths
  and behavior under Bash3.2 were not run here.
- R7: Documentation/default drift is a secondary observation, not an independent behavior fix.
- U1 is dismissed overall: native TerminalRender.safeText and portable Render.safe_text reject
  C0/C1 terminal controls before output. They deliberately allow format scalars used by joined
  emoji. No raw-title-control exploit is established.
- U2 is a pre-existing iTerm2-only query hypothesis and outside the Ghostty organizer's native
  acceptance. Do not turn it into an unrequested terminal-adapter redesign.



## Preserved provider output appendices

- [current-claude-native-2026-10-14.md](current-claude-native-2026-10-14.md)
- [current-claude-recovery-portable-2026-10-14.md](current-claude-recovery-portable-2026-10-14.md)
- [current-claude-shell-2026-10-14.md](current-claude-shell-2026-10-14.md)
