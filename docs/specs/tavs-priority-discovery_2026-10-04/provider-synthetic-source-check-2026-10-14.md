# Ordinary provider synthetic-update checks

Last Updated: 2026-10-14 (Europe/Vienna)
Version: 1.0
Source baseline: `fd261c8`.

## Parent verification and limits

The context/observation provider mismatch is confirmed in both implementations. Observation
readers now accept exactly the five existing context providers. Native attention eligibility and
the existing cue reducer still require Claude/Codex. Other-provider coverage explicitly reports
that automatic focus is unavailable. No executable matching, hooks, schema or integrations changed.

| Check | Result | Isolated log ID |
|---|---|---|
| Native ordinary-provider RED | Two cases rejected observations | SwPCvp |
| Portable publication/intent RED | Two cases failed publication | CnYNUY |
| First native connected run | 83 cases, one old invalid-provider fixture failure | K196Ro |
| Corrected native connected run | 83/83 | Cyzjrn |
| Portable unit modules | 175/175, 7.77 seconds | SvTlyh |
| Release build | Passed, 13.99 seconds | mOZ2ui |
| New native/portable owned-PTY cases | 2/2 | 33GdzH |
| Full connected background suite | 19/19 | HARtuA |

Existing rejection fixtures used unknown/Gemini, which are already legal context providers;
they now use truly unsupported names. Native tests preserve observation bytes and reject
superseded synthetic intent while preventing claimed verified/Claude-event data from becoming
eligible. Portable tests preserve the same delivery boundary. Owned-PTY scripts cover all three
ordinary providers and the actual Gemini idle worker through both selected backends. They do not
run Gemini/OpenCode applications or prove visible Ghostty rendering.

The read-only cleanup concern was checked against the worker's installed TERM exit-zero trap.
The test waits for distinct worker output before killing only that owned worker and preserves
strict wait status. No blanket suppression was added. Both actual runs pass. Copied helpers
already include the reused metadata provider constant; its import is acyclic. Installed copies
were not inspected or changed, and the native repair requires updated helper code.

The 100 ms writer and frozen producer/device/delivery checks are unchanged. Linux support,
headless feedback, root trust, palette limits, historical timing attribution and native acceptance
remain open. No live app, install, settings/schedule change, VM or existing-session shutdown occurred.
This source check is not a replacement for final provider reviews or physical acceptance.

## Full-suite verification remains incomplete

7cN3d0 ran 616 tests with two unexpected failures in one existing process-timeout test: the
expected timeout occurred, but the child PID marker was absent. DRTemo passed that case alone.
2S03Yz then ran 616 tests with 12 failures, 10 unexpected, in existing store/recovery cases,
including explicit organizer/device deadline errors. d5oHgL passed the nine affected cases alone.
Both full runs remain failures; the focused passes do not establish a cause or full-suite success.
No third unchanged full run, production deadline relaxation or assertion suppression occurred.

A read-only snapshot after the first failure showed load13.34/11.18/16.88 and 14257.31MB swap used.
This supports investigating test/host timing but does not identify the cause. The provider cases
passed in both full runs. The source correction is functionally verified by its connected checks;
Phase9 and whole-goal acceptance remain incomplete, with these failures preserved for diagnosis.

## Full read-only source exploration

The report below is preserved unchanged, including the cleanup concern and its disposition.

# Existing provider compatibility for synthetic ordinary updates

Read-only source exploration, 2026-10-14.
Workspace: `/Users/cs/local/code/apps/terminal-agent-visual-signals`.
No repository edits, suites, live apps, terminal device output, or settings changes.

## Finding

Confirmed: Gemini, OpenCode, and unknown contexts are accepted, but their observations are
rejected in both implementations. Synthetic ordinary updates require the original observation,
so the rejection prevents existing idle transitions and tool-error return updates. Immediate
ordinary rendering can proceed when the observation is absent because ordinary validation does
not require an exact matching observation. Ordinary compatibility and automatic attention
eligibility need separate provider boundaries.

An in-memory `python3 -B` probe called `validate_context` and `portable_records.decode` for
each provider. Claude and Codex passed both. Gemini, OpenCode, and unknown passed context
validation and failed observation decoding with `Invalid agent observation`. No test suite ran.

## Source trace

- Native contexts: `organizer-intake.swift:25`, `:81`, `:128-134` accept
  `claude`, `codex`, `gemini`, `opencode`, `unknown`.
- Portable contexts: `portable_metadata.py:50` defines that same provider set;
  `portable_context.py:15-37` validates it.
- Both executable identity checks deliberately verify only Claude/Codex:
  `organizer-intake.swift:202-203` and `portable_context.py:60-62`. Captured Gemini,
  OpenCode, and unknown contexts therefore remain unverified. No identity support expansion
  is needed for ordinary rendering.
- Gemini and OpenCode wrappers already set their provider and delegate to the unified trigger:
  `src/agents/gemini/trigger.sh:11-15`, `src/agents/opencode/trigger.sh:11-15`.
  Generic shell calls use `${TAVS_AGENT:-unknown}` at `organizer-state.sh:67-73`.
- `trigger.sh:101-106` publishes the ordinary state observation. Synthetic invocations preserve
  it instead: `organizer-state.sh:65` skips observation publication.
- Observation rejection: `terminal-visual-state.swift:901-906` and
  `portable_records.py:150-156` accept only Claude/Codex. Observation construction itself
  retains the context provider: `organizer-intake.swift:101-109` and
  `portable_observation.py:13-29`.
- Synthetic exact-delivery, device, and producer matching remains mandatory:
  `terminal-visual-state.swift:695-721`, `:748-754` and
  `portable_intent.py:82-86`, `:162-173`.
- The idle worker sets the synthetic flag at `idle-worker-background.sh:72` and reuses it
  during managed flush. Tool errors call managed context validation before returning to
  processing/subagent with the synthetic flag at `trigger.sh:411-418`.
- Portable managed render runs intent publication and context checks before output:
  `portable_renderer.py:175-205`. Synthetic bells remain suppressed at
  `portable_render.py:91-92` and `organizer-state.sh:130`.

## Smallest fix

1. Widen native observation validation and portable observation decoding to the existing five
   context providers. Keep state/event schemas, timestamps, identity bounds, and stale-delivery
   checks unchanged. The portable validator can use the existing `portable_metadata.PROVIDERS`
   set; there is no need for a new module or schema.
2. Add an explicit Claude/Codex provider restriction to native
   `TerminalVisualStateStore.attentionEligible`, currently at `terminal-visual-state.swift:892`.
   It presently handles Codex specially and then treats every other accepted provider as Claude
   for Stop/Permission events. That implicit assumption is valid only while observation
   storage accepts two providers.
3. Keep `AttentionState.reconcile`'s existing Claude/Codex gate at `attention-state.swift:37-39`.
   Its completion/permission/resume recognition already has explicit provider checks.
   No hook files, adapter behavior, executable verification, or integration expansion is needed.

Do not bypass observation matching for synthetic updates. That would discard the existing
protection against stale idle/error workers writing after a newer delivery.

## Native reading of portable records

The native store and portable store both use `<runtime>/organizer`:
`terminal-visual-state.swift:111`, `portable_ownership.py:104`. Native record paths use
base64url TTY keys and `observation-<key>.json` at `terminal-visual-state.swift:964-970`.
Native `TerminalObservation` decoding accepts the same serialized fields, including optional
device/producer/event/responseID, at `:1134-1149`. `coverage(for:)` then calls observation
validation at `:801-805` and computes eligibility at `:834-835`.

Consequently, widening only Python would still leave native coverage rejecting portable
Gemini/OpenCode/unknown observations. Widening both validators plus the eligibility gate
allows serialized ordinary observations to be adopted while keeping attention eligibility
false even for a manually serialized `verifiedAgent: true` record with a Claude-like event.
The existing `AttentionState` provider gate also prevents such records from creating cues.

## Focused regression coverage

- Native store: loop existing synthetic-intent preservation behavior over Gemini/OpenCode/unknown
  and idle/tool_error observations. Assert observation bytes and identity remain unchanged,
  ordinary background intent changes, and stale/mismatched contexts still fail.
- Native consumer: write portable-shaped JSON for all three providers, then assert coverage
  retains the observation and ordinary intent but `attentionEligible` stays false. Include
  `verifiedAgent: true` with Stop/PermissionRequest/agent-turn-complete to exercise the new gate.
- Attention state: extend the existing unknown-provider no-cue case to Gemini/OpenCode,
  including apparently eligible input. Existing Claude/Codex completion and permission cases
  should retain their behavior.
- Portable: extend synthetic renderer/intent tests over the three providers. Retain exact bytes,
  no synthetic bell, unchanged observation, and stale-generation/delivery checks.
- Correct existing rejection fixtures: native
  `testInvalidObservationBoundsFailWithoutPayloadDiagnostics` currently treats `unknown` as
  invalid at `terminal-visual-state-tests.swift:415`; portable
  `test_observation_rejects_unsupported_provider_state_and_invalid_response` treats Gemini as
  invalid at `test_portable_observation.py:61`. Replace those provider sentinels with a truly
  unsupported string. The native `unsupported-provider` fixture at `:1089` can remain.

These are source-grounded proposed changes, not verified implementation results.

## Follow-up source check of actual diff

Read current working diff on 2026-10-14. No test execution or repository edits in this check.

The implemented production diff widens only the two observation validators and adds the
explicit native attention gate and ordinary-provider diagnostic status. The native consumer
still decodes the shared fields and calls the widened validator before adoption. A portable
Gemini/OpenCode/unknown observation therefore follows the accepted ordinary-record path;
the native eligibility guard rejects all three before event matching, even with a claimed
verified flag. `AttentionState` retains its independent Claude/Codex check. Claude/Codex
event recognition, producer/device correlation, frozen delivery matching, and timestamp
validation were not modified.

Copied helper dependencies are complete in source: `_tavs_copy_ordinary_helper_files` already
includes both `portable_metadata.py` and `portable_records.py` at
`src/cli/cmd-install-shell-integration.sh:23-26`. Shell installation uses that helper at `:35`;
`src/cli/cmd-sync.sh:109` reuses it for the synced core directory. The new import is acyclic:
`portable_metadata.py` imports only standard-library modules and protects its CLI main with
`if __name__ == "__main__"`. This check did not inspect or replace installed copies.

The changed native tests cover all three accepted ordinary providers, preserved observation
bytes, synthetic intent updates, stale replacement delivery rejection, and claimed verified
flags with Claude completion/permission events. Native invalid-provider fixtures now use a
truly unsupported string. Portable tests exercise observation publication and stale synthetic
supersession for all three; their invalid-provider fixture uses `other`.

Negative boundaries remain in the actual source: unsupported provider strings, invalid states,
unknown events, malformed response IDs, nonfinite/future timestamps, and invalid producer/device
data still reject. Synthetic writes still require an exact live producer and matching
observation. No hook/adaptor or provider executable-verification expansion appears in the diff.

One integration-test source issue was relayed immediately: the new owned-PTY helper has
`set -e`, then intentionally kills the Gemini idle worker and calls `wait "$worker_pid"`
without tolerating its expected termination status. A normal SIGTERM wait can return 143 and
abort that helper. Its existing EXIT trap already tolerates kill/wait failures. This is a
source-grounded expected failure to correct or verify, not a test result from this check.

The parent's reported Python pass count is not independently verified by this source check.

### Cleanup concern disposition

The parent identified the worker's existing `trap 'exit 0' TERM INT`. I retrieved
`idle-worker-background.sh:69-108` afresh and confirmed that the trap is installed at `:84`,
before entering the loop or painting. The test waits for distinct `#CCBBDD` worker publication
before the cleanup at `background-intent.bats:111`. Thus this worker is expected to exit zero
on TERM, and strict `wait` checks unexpected failure rather than requiring blanket suppression.
My earlier generic SIGTERM concern does not establish a defect in this actual worker path.
Keep strict cleanup and verify with the parent's BATS run. No cleanup fix was made or requested
after this source verification.
