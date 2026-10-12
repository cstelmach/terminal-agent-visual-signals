# Phase 6 managed style design

Read-only source reconnaissance, 2026-10-12. No source/test edits, build, helper execution,
UI, native catalogue or real-home action. Current source was compared with confirmed Codex R2.

## Recommendation

Collect typed styling for the current invocation and send one managed-render transaction through
VisualRecovery.write and the existing ProcessRunner.writeManagedToDevice. Fresh policy, target
validation, delivery validation, palette/background/title/image/bell composition and device write
must stay under that existing per-TTY lock and original 100 ms device deadline. Do not send the
background first and then perform ordinary style writes outside the lock.

Keep the collector process-local and ephemeral. Never persist style payloads or turn them into
pending caches. Recovery/resume continues to use current semantic background intent and rules;
it does not reapply the historical title, image, palette or alert from a collected invocation.

## Concrete finite API hypothesis

--managed-render MARKER RUNTIME TTY CONTEXT SYNTHETIC0/1

Use exactly 23 NUL-delimited stdin fields emitted by Bash printf '%s\0', avoiding a dependency,
JSON quoting helper or arbitrary OSC parser:

1. Optional background: empty means no background request; otherwise normalized color or reset.
2. Palette action: empty, set, reset.
3. Sixteen indexed optional colors: empty or normalized #RRGGBB.
4. Title-present 0/1, then current title text. This distinguishes no request from an empty title.
5. Image action: empty, iterm2-set, iterm2-clear; then raw image path.
6. Bell 0/1.

Validate strict field count, bounded UTF-8, color syntax, action enums, Boolean flags and no control
characters in title/path. The native side generates only the existing known OSC templates; the
shell never supplies escape bytes. Keep title/path out of diagnostics. A small finite payload
value beside ManagedVisualOperation is sufficient; no protocol registry or new service is needed.
A fixed argv transport is also valid but requires the same typed fields and exposes title/path
in process arguments. Foundation JSON is valid but shell encoding adds unnecessary machinery.

Old managed helpers may recognize schema1 but reject the new verb. That is safe only when the
new shell fails closed without raw fallback. No speculative new capability subsystem is needed.
If support diagnostics distinguish renderer support, use the existing safe --validate-config
pattern rather than invoking a possibly UI-starting unknown top-level capability verb.

### Native execution

- Add a render operation carrying optional ordinary intent and current typed style values.
- Resolve/authenticate the same exact target as existing managed background. Continuing shell
  owner may differ from observation producer, as covered by the latest regression.
- Under the opened-device/shared-lock callback, validate the current delivery. Synthetic render
  must repeat latest matching live observation/device/delivery checks here, even if the shell
  previously performed validation-only. Ordinary style-only render also rejects a newer
  observation when present, while retaining legitimate no-observation ordinary signaling.
- If a background was requested, publish/bind its semantic intent using existing rules. If absent,
  do not publish reset or change the current ordinary intent merely to authorize a title/palette.
- Read fresh global policy. If restrictive, emit only the complete restriction payload, suppressing
  all queued ordinary style and bell. If not restrictive, compose the current controlled
  background when requested plus queued ordinary style in one returned Data buffer.
- Preserve existing palette-before-background ordering in this complete ordinary buffer, then
  title/image and fresh ordinary bell. Synthetic ticks must not create an alert occurrence;
  suppress their bell request. Existing background-only and forced-reset verbs remain typed.
- Check policy and deadline as the current managed writer already does; do not introduce a second
  lock, separate style writer, reset deadline, or detached output subprocess.
- Return a small finite result distinguishing ordinary style emitted from restriction/unaffected.
  Title state must record TITLE_LAST_SET only after ordinary title was actually delivered, not
  while it was queued or suppressed by the fresh native rule.

## Complete OSC caller census

Current source has eleven emit_osc sites, each with a known typed meaning:

| Location | Existing template/data | Typed change |
| --- | --- | --- |
| terminal-osc-sequences.sh:38 | Standalone BEL | Queue fresh bell Boolean |
| terminal-osc-sequences.sh:152 | %b from _build_osc_palette_seq | Queue 16 palette values and set action |
| terminal-osc-sequences.sh:158 | OSC104 reset | Queue palette reset |
| terminal-osc-sequences.sh:239 | OSC0 title | Queue title from legacy send_osc_title |
| idle-worker-background.sh:28 | Palette %b | Call shared typed palette collector |
| idle-worker-background.sh:35 | OSC104 reset | Call shared typed palette reset |
| idle-worker-background.sh:180 | OSC0 composed title | Queue current idle title |
| title-management.sh:526 | OSC0 full title | Queue title and defer last-set persistence |
| title-management.sh:569 | OSC0 base title | Queue reset title and defer persistence |
| backgrounds.sh:78 | OSC1337 encoded path | Queue raw validated iTerm2 path |
| backgrounds.sh:86 | OSC1337 empty value | Queue iTerm2 clear action |

send_osc_bg at terminal-osc-sequences.sh:92 must queue its normalized intent in an active batch
instead of writing early. Outside a batch, typed helper APIs can flush a single-item invocation.
No raw emit_osc implementation should remain available to these production callers.

_build_osc_palette_seq already separates palette construction from writing. Reuse its palette
selection logic and raw PALETTE_DARK_0..15/PALETTE_LIGHT_0..15 values, not its escape-byte output.
_get_palette_mode and should_send_bg_color remain the existing configuration decision points.
Title composition, explicit user title locks/respect modes, face/spinner construction and image
selection remain in their current shell helpers. reset_spinner only removes state; it emits no
terminal bytes and needs no managed output change.

## Minimal caller changes

- trigger.sh: begin one empty batch before state dispatch; flush after each complete synchronous
  render. Flush before launching complete/idle timer or delayed tool-error worker so it cannot
  inherit queued parent styles or race initial semantic intent publication. Preserve bookkeeping.
  Subagent-stop with remaining children is title-only and still needs a managed flush.
- idle-worker-background.sh: each stage creates a new empty batch, queues background/palette/title,
  then performs one flush. Native synthetic validation belongs in that flush. Preserve whole
  typed max-runtime reset. A background-disabled stage carries no background but still validates.
- terminal-osc-sequences.sh and organizer-state.sh: finite collector/flush helpers and typed
  wrappers. Do not classify arbitrary printf formats or parse OSC after the fact.
- title-management.sh and backgrounds.sh: queue semantic values rather than escape templates;
  defer successful title-state bookkeeping until flush confirms actual ordinary title delivery.
- managed-output-entry.swift and visual-recovery.swift: bounded finite payload validation,
  operation mapping and current-invocation encoding under the existing writer. A small type
  beside the consumer can hold values without creating another architecture layer.
- Existing standalone shell startup, recover CLI and typed forced reset already compose inside
  the managed writer and do not need a new style collector.

## Smaller alternatives and why they fail

- Updating _TAVS_SUPPRESS_OUTPUT from background-helper output fixes only the policy observed by
  that earlier operation. A rule can activate after helper return and before palette/title/image.
- Re-reading state immediately before every printf leaves a check-to-write race, ignores writer
  serialization, and does not stop a superseded synthetic delivery between check and raw write.
- Keeping the managed lock only around background retains the demonstrated R2 gap.
- Serializing each typed style item individually is smaller than batching and can preserve safety
  if every operation validates policy/delivery under the same lock. It still creates multiple
  native launches/deadlines and partial style updates, whereas one invocation batch is the
  smallest coherent complete correction for the coupled existing render path.
- Locking Bash around printf creates a second writer implementation and still must duplicate
  native target identity, policy, deadline, stale delivery and failure handling.
- Buffering raw printf output then replaying/parsing it creates an opaque OSC channel and risks
  historical title/BEL replay. Typed values avoid that problem entirely.
- Disabling all palette/title/image output would avoid the race by removing requested legitimate
  styling, so it is not a complete compatibility-preserving correction.

## Required bounded tests

1. Native policy flips between shell collection and native prepare: ordinary palette/title/image
   and bell absent; exact current hard/soft restriction remains the only output.
2. Synthetic observation is superseded after collection: entire batch rejected, including title,
   palette, image and bell, and no semantic intent changes.
3. Active ordinary invocation: existing palette/title/image/bell semantics preserved in one Data
   buffer; user title lock/off/respect modes still suppress the title request.
4. Background-disabled title/palette-only invocation: no intent/reset publication, fresh policy
   still governs output, continuing-owner/producer split remains valid.
5. Recovery/resume does not replay prior style/bell; no pending cache is created or republished.
6. Missing/old/failed helper, malformed typed fields, and deadline failure: zero raw fallback.
7. Shell fixture verifies one flush per render and no production direct style writes. Owned PTY
   verifies actual payload, current restriction dominance and zero stale synthetic bytes.
8. Keep actual 100 ms output/target/deadline tests and existing background/privacy/title regression
   checks. Add title-state persistence assertion for a suppressed fresh native rule.

Use existing VisualRecovery/ManagedOutputEntry tests, managed-background and background-intent
fixtures. Title persistence/composition Python suites are connected. Legacy emit-osc.bats still
has an env-i path dropping helper/private roots and live-risk fixture assumptions; audit and fix
its isolation before running it as a connected regression. No broad suite was executed here.

## Explicit extra writer requiring a disposition

backgrounds.sh:105-155 implements Kitty images through kitten @ subprocesses outside emit_osc,
using the same old shell suppression flag. A typed OSC batch does not serialize that side effect.
kitten is not on PATH in this session, so there is no verified installed contract to reuse here.
Ghostty rejects stylish-image support in supports_background_images, so this route is not part
of a Ghostty render, but it remains an existing opt-in compatibility feature.

Do not remove Kitty styling silently or claim all terminal backends repaired from the OSC batch.
If R2 scope includes Kitty remote images, the same typed image item needs a verified, exact-target,
bounded Kitty backend using the existing writer lock and original deadline. A generic subprocess
runner or an old flag recheck is not sufficient; routing, timeout/late effects and restoration
must be checked against its actual protocol before implementation. Otherwise explicitly retain
this separate legacy backend limitation. I cannot establish its complete safe implementation
from this checkout and absent executable alone.

No native/physical acceptance is claimed by this design. Parent owns source implementation,
reviews, builds and acceptance decisions.
