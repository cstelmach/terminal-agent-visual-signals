# Portable context and observation source checks

Last Updated: 2026-10-14 (Europe/Vienna)
Version: 1.0

Sources: `a932802` (context) and `46ee18b` (observation). Source-only reports are distinct from
executed private-root/native-helper checks.

## Parent disposition and executed checks

Confirmed P2 against `organizer-intake.swift:37-54`: selected turn-id strings reject NUL and
excess length, while observation publication applies validID separately. Xsbmzl reproduced a
source-built native token with newline/format response characters failing portable decoding.
The decoder now preserves the intake string contract. UZehVK passed 11 context cases, including
native-token acceptance and strict observation rejection. The original source report is retained
below, including its statement that the response-control regression was absent at review time.
No capability or routing used the draft. No additional concrete defect was reported.

Initial Ib970N failed on the missing context module. Ps7cv8 passed the initial 13 combined cases.
Tests were then split by context and publication for their two logical commits. KrRKhe passed
116 portable cases before the extra interoperability regression; final KrzC8M passed 117/117
in 3.016 seconds. rsITTi passed 561/561 Swift tests in 10.588 seconds. eF7MUl passed 23/23 isolated
hook-observation checks. Changed/new Python syntax, staged ownership/secrets and whitespace checks
passed. Owned macOS PTYs established current foreground agreement, native/Python interchange and
no device bytes from these data-only operations. They do not establish physical Ghostty/UI cases.

The new interfaces remain internal. Caller ancestry, managed register/current/check-context,
helper dispatcher, capability advertisement/routing, Linux versioned scope and actual Linux
kernel/device validation remain open. Context decoding uses a conservative finite schema subset,
not native Codable's unknown-key permissiveness. Raw body/display metadata does not enter context.

## Source exploration report

# Portable organizer context and remaining helper verbs

Source exploration only; no tests, execution of product/provider code, edits to
project, UI, web, goal calls or fingerprints. Sources: organizer-intake.swift,
process-identity.swift, terminal-visual-state.swift, managed-output-entry.swift,
their intake/entry tests, organizer-state.sh and current portable primitives.

## Finite intake and token contract

| Interface | Native shape and result |
| --- | --- |
| organizer-intake provider callerPID | Exactly two operands; positive Int32 caller. Read <=1 MiB stdin through EOF within 2 s, restore stdin flags. Emit six key/value NUL pairs, including context then success marker. |
| organizer-context provider callerPID | Same operands, no stdin. Fresh context token plus newline; no legacy metadata/event/responseID. |
| organizer-observe tty token state | Exactly three operands. Decode token, construct typed observation, publish; success stdout empty. |
| decodedContext(token) | <=8192 UTF-8 bytes, standard Base64 JSON (not URL-safe), Codable types, schema==1 and known provider. |

Context required fields: schema=1, deliveryID UUID string, observedAt Unix Double,
provider, verifiedAgent bool. Optional fields: producer generation, device UInt32,
event and responseID. Generation keys are pid/startSeconds/startMicroseconds.
Generated optional nil fields are omitted by JSONEncoder. Providers accepted for
intake/context are claude/codex/gemini/opencode/unknown. No prompt/tool/output body,
session ID, cwd or transcript path enters the token or observation.

Native decodedContext uses synthesized Codable, so it ignores unknown keys and
does NOT independently validate deliveryID syntax, timestamp freshness, event,
responseID bounds or generation positivity. Subsequent typed records/entry checks
perform those checks. The token is correlation data, not a signature or independent
authority; no new authentication machinery is required.

Reuse portable_metadata.read_input/decode_metadata for the four legacy fields.
Add event/response extraction from the SAME parsed top-level JSON, preserving
legacy output ordering. Do not parse stdin twice. Existing portable decoder does
not inspect hook_event_name/type/notification_type/turn-id, so wrong-type/control/
oversize checks for those fields are currently missing.

All selected strings: null/absent/empty -> absent; wrong type, NUL or excess UTF-8
bytes -> error. mode/hook/type/notification_type <=128, session/thread <=512,
cwd/transcript <=4096, Codex turn-id <=256. Session/thread additionally reject
Foundation control characters (Cc/Cf). Codex event only type=agent-turn-complete;
responseID from turn-id. Other providers recognize UserPromptSubmit, PreToolUse,
PostToolUse, PostToolUseFailure, PermissionRequest, Stop, SessionStart/End,
PreCompact, SubagentStart/Stop. Notification becomes permission_prompt/idle_prompt
only for those two notification_type values. Unknown event/mode is ignored/default.
No payload-derived verifiedAgent flag is honored.

## Producer and caller proofs are distinct

Intake producer walks caller and up to 15 ancestors. For each inspected process:
device != UINT32_MAX, foregroundGroup positive Int32, inspect that group leader;
reinspect source/foreground generations and require same device, foreground.group
== foreground.foregroundGroup, source.group == source.foregroundGroup == that
foreground group. This is ProcessIdentity.foregroundFamilyContains, not ancestry
or continuing_owner. Remember the FIRST qualifying foreground owner as fallback.

For claude/codex only, read actual executable path (native proc_pidpath, <=4096).
Resolve symlinks. Reject node/nodejs/bun/bash/zsh/sh/dash and any python-prefixed
basename before accepting provider basename or equality with a resolved absolute
PATH/provider entry (versioned native installs). Unknown executable or provider
gemini/opencode/unknown cannot claim verifiedAgent. Return the matching ancestor
generation/device verified=true, otherwise fallback foreground generation/device
verified=false. No qualifying process is a successful context with both absent.

Missing portable interfaces: foreground_family_contains, bounded executable_path
(Mac ctypes proc_pidpath; Linux /proc executable reference with current generation
revalidation), and select_producer. Reuse inspect dictionaries. Do not use command
line text, metadata, inherited provider names or continuing_owner as executable
evidence. Existing Linux generations carry linuxScope and are NOT native schema1;
Linux context/records need explicit versioned encoding before integration, while
Mac schema1 stays exact. This is a concrete integration dependency, not completed
Linux acceptance.

Managed caller ancestry starts at HELPER getpid(), visits <=16 processes, and must
reach requested caller PID. Reject cycles, missing/malformed identity and parent
<=1 before reaching it. At requested PID, verify expected device when supplied,
then reinspect exact generation/device. Original native ancestry phase has its own
100 ms bound. Register/current require target TTY device; reconcile omits that
device restriction. This needs a separate caller_ancestor helper; continuing_owner
walks from producer toward a TTY owner and cannot prove helper ancestry.

## Observation publication

Native schema1 observation required: schema,tty,provider,verifiedAgent,state,
deliveryID,observedAt. Optional: device,producer,event,responseID. Unknown JSON
keys rejected, <=8192 bytes. Reuse portable_records.decode(kind=observation).
Provider for persisted observation is ONLY claude/codex, despite broader context
providers. States: processing,permission,complete,idle,compacting,reset,subagent,
tool_error. Events additionally allow Notification,permission_prompt,idle_prompt,
agent-turn-complete. IDs nonempty ASCII alnum or -.:_, <=128; thus an intake turn-id
accepted up to256 can still fail observation validation, exactly as native.

TTY absolute <=128, no control/format or . / .. components and not /dev/tty;
optional device !=UINT32_MAX; finite timestamp >0 <=now; producer positive valid
generation born no later than timestamp. Publication DOES NOT require producer
currently alive/foreground, continuing owner, actual device existence or verified
agent. Those are later output/coverage proofs.

Under the shared per-TTY writer lock: read latest observation, tolerate invalid
regular data for repair, reject links/unavailable storage, refuse older observedAt,
allow equal timestamp, atomically replace observation-Ktty.json. Do not publish an
intent or target here. Native only bounds default lock wait at100 ms; its legacy
publication IO has no supplied whole-operation deadline. Portable can use existing
bounded IO with one supplied metadata deadline; do not renew it inside helpers.

## Remaining managed verbs

| Verb | Required checks and ordinary-backend behavior |
| --- | --- |
| register(marker,runtime,tty,callerPID) | Authenticate helper ancestry/device before side effects; resolve continuing owner/current aliases. Managed writer opens actual TTY, locks, revalidates fd/target, caches target.json, returns no bytes. No intent/effect mutation or marker change. Success code0/unaffected newline. |
| current(marker,runtime,tty,callerPID) | Same caller/target proof and after-open cache/effect validation. With no current global rule: no bytes/unaffected; do not restore ordinary background, cancel effects or invalidate pending. With a rule: native needs controller and paints managed rule; ordinary portable route must explicitly fail unavailable without claiming that capability. |
| check-context(marker,runtime,tty,token) | Context producer/device required, current generation and actual device must match; synthetic route has no helper-ancestor requirement. Resolve target. After open under writer lock: strict observation same tty/device/producer/delivery, observedAt<=intake and live producer; return no bytes. No intent publication or new target cache. Success code0/unaffected. |

Check-context can reuse Intents.validate_context_unlocked with synthetic=True and
a reset-valued ephemeral intent updatedAt=now; current helper also verifies owner.
It must run before target caching. Register/current must not use ordinary_ownership
as admission: register is no paint regardless of leases, current/no-rule is no
paint without canceling leases. Reuse _current for validated alias/effect reads.

Managed paths absolute <=4096 without Cc/Cf; concrete TTY/device validation before
target selection. Exact argument counts; malformed/unsupported verb returns fixed
private error. Isolated-test keys require explicit safe-root/allowlist handling;
never silently ignore them in a future callable helper.

Failures: organizer general invalid/IO -> code1 fixed private metadata error;
stale observation/delivery/intent ->3. Managed malformed arguments, ancestry,
target/storage/policy/timeout ->1; reused/missing token producer or wrong device
at entry, superseded observation/delivery/intent/effect ->3. No error echoes input.
Do not map every internal ESTALE to code3: native targetUnavailable is code1.

## Smallest coherent next slice

Implement one portable organizer module exposing metadata+event decoding,
context generate/decode, producer selection and bounded observation publication;
extend existing process identity only with the two missing evidence helpers and
caller ancestry. Add renderer register/current/check_context no-output interfaces
using the current writer, plus finite internal dispatch/result tests. Keep CLI
capability lines and hook routing absent until all advertised verbs, isolation and
delivery are supported. Existing organizer capability also includes organizer-intent;
do not advertise it based only on context/observe. No second process framework is
needed. Tests should distinguish foreground fallback from verified executable,
unrelated caller from ancestor, stale observation from invalid storage, and no
paint/no intent/no heartbeat for all three no-output verbs.

## Draft source check

# Portable context and observation source check

Read-only review of portable_context.py, portable_observation.py, metadata/process
identity/record IO/intent diffs and test_portable_context.py against current native
source. No tests, imports/product execution, devices, UI/provider or goal calls.

## Concrete compatibility finding

P2: portable_context.py:32-34 uses _text, rejecting Cc/Cf characters in responseID.
Native OrganizerIntake.decode string(turn-id) only checks type, <=256 UTF-8 bytes
and NUL (organizer-intake.swift:37-54), then can emit a canonical context token
with that value. Example Codex payload {"turn-id":"turn\n43"}: decode_intake
accepts it, but capture(response_id="turn\n43") and decode_context of the native
token fail. Native managed ordinary rendering ignores responseID and can still
use that context. Native observation publication separately rejects this ID via
validID, so rejecting its context earlier is an additional compatibility change.

Smallest fix: validate optional context string type/UTF-8 bound/NUL without
applying observation control/ID policy. Retain strict observation validation in
portable_records.decode. A regression should show context accepts native intake's
opaque response value while observation refuses it and ordinary context stays
usable. No need to allow any raw terminal output or persist the invalid ID.

## Checked without further concrete defects

- foreground_family_contains matches native repeated generation/device proof,
  current foreground leader group and source group. capture uses caller ancestry
  up to16, first eligible foreground fallback and separate actual executable
  evidence; interpreter basenames cannot verify and unsupported providers remain
  unverified. It does not take verifiedAgent or nested IDs from hook JSON.
- Mac proc_pidpath ctypes signature/buffer matches native4096-byte path retrieval.
  Symlink-resolved versioned provider commands are accepted only after interpreter
  exclusion. Source proof and executable lookup are separate snapshots, as in
  native; this code adds no stronger atomic-executable/generation guarantee.
- decode_intake shares one parsed object, extracts allowlisted top-level events
  and response ID, preserves legacy decode_metadata selection, rejects selected
  field type/NUL/size errors and discards body fields. No payload body enters
  generated context, observation or errors here.
- Observation validates typed record before opening lock/state. It does not fake
  live/foreground output authority. Shared-lock read_latest refuses older time,
  allows equal time, repairs only invalid regular data, and preserves links/FIFOs
  or unavailable storage errors. Atomic publication uses existing held parents.
- read_latest propagates timeout and nondata errors; its extraction into shared
  record IO preserves Intents ordinary repair versus synthetic strictness.
- One metadata100 ms deadline starts before observation context/record validation
  and is passed to locking, reads and writes. Late validation reaches deadline
  guards before publication; no helper renews the budget. Native legacy observation
  publication itself only bounds lock contention, so this is intentionally tighter.

## Explicit limits and deferred work

Context validation is generally stricter than native synthesized Codable: unknown
keys/duplicates, ID/time/generation bounds and canonical integer types are rejected
early. This can be a documented internal subset, but the responseID finding above
also affects tokens native actually generates from accepted intake.

Caller-ancestry helper and managed register/current/check-context, CLI dispatch,
capability advertisement and routing remain deferred. Linux executable lookup is
not implemented, and linuxScope generation cannot enter native schema1 context;
explicit Linux context/record versioning remains necessary before integration.
These are bounded scope limits, not requests for an unrelated framework.

Tests inspected cover identity fallback/verification, generation change during
foreground proof, body privacy, field bounds, token validation, stale/equal ordering,
regular repair/nonregular refusal, lock timeout and owned Mac/native interoperability.
They were not run here; response control compatibility is not currently covered.
