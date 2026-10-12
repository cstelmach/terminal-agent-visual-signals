# TAVS Phase 9 observation contract

Last Updated: 2026-10-13
Version: 1
Source: `d96cc9d`+
## Scope and conclusion

This is a read-only source assessment of existing observation intake, shell adapters, native
correlation and Phase 9 requirements. No build, test, native query, device write, installation,
hook invocation or real-home change was performed. Only this requested report was created.

The existing record supplies enough information for a conservative pure reducer: stable hook
delivery identity, supported Codex completion identity, actual state/event pairs, verified
producer generation, controlling device and coverage adopted against a native surface lifetime.
It does not supply a permission request/episode ID, a provider source timestamp or an event
history. The reducer must use observed episode boundaries and preserve ambiguity as ineligible.

One concrete small eligibility mismatch exists: generic Claude `Notification` is currently
accepted as a permission cue although the intake recognizes only permission/idle subtypes.
Remove generic Notification from attention eligibility and add its regression. No new hook,
observation journal, lifecycle service or state control plane is needed for that fix.

All source paths below are relative to:
`/Users/cs/local/code/apps/terminal-agent-visual-signals/`.

Short Swift paths beginning `Sources/` or `Tests/` are within `src/macos/TAVSApp/`.

## Actual record and intake fields

The current type is `TerminalObservation`, not `AgentObservation`, in
`src/macos/TAVSApp/Sources/TAVSApp/terminal-visual-state.swift:4`. It contains:

- schema, concrete TTY path, device number and optional producer PID/start generation;
- provider, verifiedAgent, state and optional event;
- deliveryID, optional responseID and observedAt.

`OrganizerContext` in `Sources/TAVSApp/organizer-intake.swift:10` carries those identity/event
inputs. `--organizer-intake` creates one UUID and one intake time. The shell preserves that
context through core rendering; polling does not create another UUID.

Session/thread ID, cwd and transcript path are extracted into allowlisted shell environment
fields for existing metadata-dependent behavior. They are deliberately absent from the
context/observation. Prompt, response and tool bodies are discarded. Reducer identity cannot
depend on row title/directory or assume it has a provider session ID.

Codex decoding recognizes `type == agent-turn-complete` and takes `turn-id` as responseID.
Missing turn-id stays nil. Claude decoding recognizes supported hook_event_name values;
Notification becomes `permission_prompt` or `idle_prompt` only when notification_type matches.
Other Notification subtypes have no event authority. Claude response IDs are not parsed here.

IDs in persisted observation records must satisfy the existing nonempty, at-most-128-byte ASCII
ID allowlist. Intake permits turn-id strings up to 256 bytes, so a longer or otherwise unsupported
ID can decode at intake but still be rejected on observation publication. Do not assume every
supplied ID is supported merely because the JSON decoder accepted its string.

## Correlation and attentionEligible

`OrganizerIntake.producer` walks at most 16 ancestors, inspecting process generations and
controlling/foreground TTY metadata. Native Claude/Codex executables are recognized by resolved
provider path; interpreter executables are not accepted as verified agents. Ancestor presence
alone does not establish verification: `ProcessIdentity.foregroundFamilyContains` also requires
matching generation, device and actual foreground process-group membership.

`TerminalVisualStateStore.coverage(for:)` at line 697 is called only for a fresh successful
catalogue row. A missing/ambiguous mapping yields no eligible observation. `adopt` at line 760
requires the same current TTY device and live producer generation, then either:

1. current foreground-family correlation against the native surface; or
2. the exact delivery already adopted against that same native surface ID, while the producer
   still has its original generation and controlling device.

The native ID includes Ghostty application generation and terminal ID. Persisted adoption cannot
silently rebind to a different terminal/application lifetime. A backgrounded but still valid
already-adopted delivery can remain eligible. Its status can say Last-known; that text alone is
not a reason to override the explicit coverage boolean. A new delivery needs fresh correlation.

`attentionEligible` at line 799 is a candidate classifier, not an occurrence or acknowledgement
state. It requires verifiedAgent and currently accepts:

- Codex: state complete, event agent-turn-complete, nonnil supported responseID;
- Claude: state complete with Stop;
- Claude: state permission with PermissionRequest, permission_prompt or generic Notification.

The last generic Notification case is broader than intake's verified subtype contract. The
smallest remedy is to remove that case while retaining legacy generic records as diagnostic
data if needed. Do not widen unknown events into attention.

## What each transition actually provides

| Transition | Available evidence | Reducer consequence |
|---|---|---|
| New Codex completion | complete + agent-turn-complete + supported turn-id, delivery ID, live adopted producer | Deduplicate turn ID within provider/producer/native lifetime; a different supported ID can create a new occurrence without an intervening processing hook. |
| Repeated completion poll | Exact observation/delivery/response ID unchanged | Never creates another occurrence. |
| Claude completion | complete + Stop + fresh intake delivery ID, live adopted producer | Identifies a separate supported hook intake. No independent Claude response token is supplied; do not invent one or claim exactly-once provider-turn coverage. |
| Permission companions | permission + PermissionRequest or permission_prompt, distinct intake IDs | Distinct IDs do not imply distinct permission requests. Coalesce within the same observed episode, including acknowledged companions. |
| Explicit Claude processing | processing + UserPromptSubmit or PostToolUse from existing hooks | Verified observed processing can end the permission episode and resolve attention; state text with no supported event is not proof of provider resumption. |
| Explicit reset | reset + SessionStart or SessionEnd | Existing lifecycle signal can resolve prior eligibility. Do not infer reset from a background reset intent alone. |
| Real idle notification | idle + idle_prompt | Neither a new permission/completion cue nor verified processing. It must not resolve completion solely because the row is idle. |
| Generated idle gradient | Ordinary intent changes; meaningful observation unchanged | Never creates or resolves a cue. No synthetic flag is required in the observation because no new observation is published. |
| Delayed error restoration | Original tool_error/PostToolUseFailure observation and intake identity retained | The generated return to processing is synthetic and must not masquerade as an observed resumption. |
| Producer exit/reuse | Adoption fails when inspect is absent/zombie/exiting, generation changes or controlling device mismatches | No current eligible record. Retire or disable the cue's eligibility without claiming that age proves exit. |
| Stale native binding | mapping issue, changed native ID/application generation, failed adoption or catalogue unavailable | No automatic activation from retained row data; invalidate current eligibility. |

Scope supported completion dedup by native surface plus provider and producer generation.
Do not dedup unrelated producers globally by an opaque turn ID. Claude intake delivery ID is
the local delivery authority; it is not a manufactured provider request ID.

## Shell and synthetic behavior

`src/agents/claude/hooks.json` already supplies all relevant signals: UserPromptSubmit and
PostToolUse processing, PermissionRequest, Stop completion, Notification permission_prompt/idle,
SessionStart/SessionEnd reset. No additional hooks are required.

Claude adapter stdin is consumed only by allowlisted intake, then core gets fixed arguments and
empty stdin. Codex adapter reads the appended JSON from its second argument, then also delegates
fixed state arguments with empty stdin. Installer notify is `[bash, adapterPath, complete]`;
`src/agents/codex/hooks.json` remains a placeholder. Production notify is completion-only.
Manual fixed-state Codex invocations are not evidence of missing native processing hooks.

`src/core/trigger.sh:101` publishes the meaningful state before ordinary visual-state gating.
Subagent start/stop are recorded as subagent; the core's later cosmetic return to processing is
not an independent processing observation. Unsupported state/event associations are diagnostic.

`src/core/organizer-state.sh:53`, `_tavs_organizer_begin`, skips publication whenever
TAVS_ORGANIZER_SYNTHETIC is 1. `idle-worker-background.sh:72` sets that flag. Delayed tool-error
restoration in `trigger.sh:418` also sets it and retains the original context. Existing native
synthetic validation rejects a frozen delivery once a newer meaningful observation supersedes
it. Synthetic paint cannot establish a fresh event or inferred resumption.

## Concrete gaps and smallest remedies

1. **Occurrence/acknowledgement state is not implemented.** FocusMode currently has Off/Manual,
   and coverage only classifies a candidate. Add the one pure AttentionState reducer already
   named by PLAN Phase 9. Feed it fresh row coverage and priority, baseline all existing
   observations on enable, and retain consumed identities through acknowledgement/downgrade so
   returning High does not replay them. No extra state service or hook is required.
2. **Permission episode identity is observational.** There is no request ID or episode field.
   Keep one observed episode per native/producer lifetime and coalesce both hook variants. An
   acknowledged episode remains consumed until an explicit verified boundary. A post-resolution
   companion with insufficient evidence of a new request is ambiguous and ineligible.
3. **Only the latest observation is retained.** `publishObservation` atomically replaces one
   record per TTY and rejects older intake times. A processing/reset event can be overwritten by
   a subsequent permission or completion before the two-second catalogue poll. The reducer
   cannot reconstruct that missed sequence from state, color, age or UUID. Treat underdetermined
   permission repeats conservatively; report observed/partial coverage rather than adding a
   journal or pretending every provider event was seen.
4. **Candidate classification accepts generic Notification.** Narrow the existing helper to
   PermissionRequest/permission_prompt and regression-test the generic event as ineligible.
5. **Exit certainty is not a coverage enum.** Failed adoption returns nil observation and generic
   unavailable status, whether the producer exited or inspection failed. That is enough to
   disable eligibility safely. Do not display an asserted exit reason from this boolean; the
   existing coverage/source boundary needs no new exit hook.
6. **Go To has no acknowledgement callback wiring yet.** `sessions-model.swift:236` dispatches
   navigation and reports failures. Capture only that row's reducer cue IDs before dispatch;
   acknowledge exactly those on success and none on failure. New IDs arriving in flight survive.

## Source tests and their limits

Existing OrganizerIntakeTests cover Codex supplied/missing ID, unknown Notification subtype,
metadata bounds and provider executable recognition. TerminalVisualStateTests cover stable
adoption, backgrounded retention versus new correlation, generation/device/native reuse,
unverified eligibility, synthetic identity preservation and missing Codex ID.

`tests/integration/hook-observations.bats` verifies adapter extraction, fixed arguments, empty
stdin, discarded body fields, Codex supplied/missing IDs and installed notify argv shape. Its
core is a capture stub. Those tests do not independently prove native producer correlation or
permission episode semantics. `background-intent.bats` and the Swift state tests already verify
that idle/error restoration preserve meaningful observation identity.

Required small extensions are:

- table-driven reducer cases for baseline, same-delivery polling, duplicate supported Codex ID,
  distinct completion IDs with no processing between, missing ID and unrelated producer scope;
- permission variants, acknowledged late companion, observed processing/reset resolution and
  ambiguous repeats when an intervening boundary was not observed;
- idle/compacting/subagent/tool-error states do not act as guessed resumption; synthetic intent
  updates leave cues unchanged;
- producer exit/reuse, changed native binding and unavailable catalogue remove eligibility;
  transient coverage recovery must not manufacture a new delivery;
- generic Notification ineligible, supported subtype eligible, priority downgrade/re-upgrade
  without replay, and Go To snapshot success/failure with an in-flight new cue;
- adapter fixtures for PermissionRequest, permission_prompt, idle_prompt, Stop, PostToolUse and
  SessionStart/SessionEnd state/event pairing, reusing the existing body-safe capture harness.

SPEC product phase 3 and PLAN phase 9 require supported correlated observed occurrences, not
inferred task success or invented provider lifecycle. Codex completion means response end only;
direct Codex work resumption cannot be detected by the existing notify channel. Keep Go To
acknowledgement, known invalidation, Focus Off and recovery explicit in its UI coverage message.

## Parent adjudication

The generic Notification finding was verified in current source and reproduced by `KzZUGo`.
`176aab7` narrows eligibility; `axXugB` passed 76 affected Swift checks. `42f512c` adds the
pure reducer and 12 deterministic cases. Full `QZWkHD` passed 479 tests; isolated hook/intent
`2V3r9L` passed 27 cases. Latest-only and completion-only limitations remain explicit.
Controller, navigation, GUI and physical automatic-focus acceptance are still pending.
