# Claude H1: ordinary signaling compatibility

Baseline: `470b03553c58a8e9004cbf1c5c3dca627ee6a80f`.
Scope: read-only source, SPEC, D01-D18, adapters, delivery paths and test inspection.
No tests, builds, native requests, app launches, device writes or repository edits were performed.

## Conclusion

H1 identifies real ordinary signaling and metadata regressions. Making the optional macOS
companion mandatory is not an approved D01-D18 decision. Keep the new organizer's macOS/Ghostty
scope distinct from the existing plugin's terminal/platform compatibility. Do not close H1 by
changing expected output to zero or describing all existing installs as unsupported.

The SPEC does not require a pure Bash renderer: a bounded helper can deliver ordinary output.
It does require preservation when no controller owns an effect. Current installed-helper-only
resolution fails that behavior for valid standalone installs. Linux regression is additionally
established by the repository's existing support promises, not by a Linux organizer promise.

## Source evidence

- `SPEC.md:123-132` requires allowlisted intake, raw-body disposal and preservation of existing
  legitimate metadata behavior. `SPEC.md:161-164` preserves direct ordinary signaling when
  uncontrolled. `SPEC.md:180-186` lets ordinary hooks paint after ownership expires.
- `SPEC.md:263-272` requires in-lock current policy/target checks and the bounded writer for
  managed backgrounds/restrictions. Required recovery-helper failure is explicit at `235-237`;
  this is not a statement that every ordinary hook requires the installed GUI app.
- D02 limits initial organizer surfaces to local Ghostty; D05 includes plain shells; D17 reuses
  existing provider signals. D01-D18 contain no decision to withdraw Linux/other-terminal/plugin
  support or require installing the macOS companion for ordinary hook output.
- `PLAN.md:199-203` separates metadata preservation from unavailable observation coverage.
  `PLAN.md:292-304` preserves nonbackground styling and prohibits bypassing failed managed writes.
- `organizer-state.sh:3-19,67-83` selects only an explicit test helper or the fixed app path.
  It accepts exact capability strings. No production source-built/plugin-relative path exists.
- `_tavs_render_flush`, `organizer-state.sh:164-194`, clears pending typed output and returns
  failure if that helper/context is unavailable. Background, palette, title, bell and iTerm2 image
  are all in that batch. `terminal-osc-sequences.sh:84-120,201` routes those OSC kinds to the queue.
- `trigger.sh:267,281,408,430-431` ignores flush failure and ultimately returns zero. The loss is
  accompanied by stderr diagnostics, so strictly it is not entirely silent. Worker diagnostics
  are redirected away. Existing Kitty image subprocesses are an exception to the queued kinds.
- `_tavs_organizer_intake`, `organizer-state.sh:27-50`, exports default permission mode and empty
  transcript/session/cwd when native intake is unavailable. Claude/Codex adapters continue into
  core (`src/agents/claude/trigger.sh:25-33`, `codex/trigger.sh:25-30`). Continuing dispatch alone
  does not preserve actual OSC delivery or the lost metadata-dependent behavior.
- Mode colors consume permission mode (`theme-config-loader.sh:364-379`); session identity consumes
  session ID (`session-icon.sh:61-62`); directory identity uses cwd (`dir-icon.sh:244`); context
  estimation uses transcript path (`context-data.sh:105`). These are existing product functions.
- README `47-82,92-98,277-290,1082-1087` advertises plugin/manual installs, automatic defaults,
  compatible terminals and macOS/Linux. The companion is separately installed at `926-950`.
- `cmd-sync.sh:84-107` delivers core/adapters/hooks/CLI, but no app/helper. Agent installers likewise
  do not install the companion. `cmd-uninstall-macos-app.sh:77-93` even promises normal painting
  after companion removal. This update path can strand currently working plugin installations.

## Existing routes and limits

- Reuse `ProcessRunner.swift:159-228,259-321`: 100 ms caller budget, late-open rejection, nonblocking
  write/poll, open before advisory lock and fresh checks inside preparation. An unlocked
  `writeToDevice()` call alone does not provide managed policy/recovery serialization.
- Existing `--managed-render` can already deliver complete ordinary style without active effects.
  `managed-output-entry.swift:75-133` admits a continuing owner/context; verified provider identity
  is not required for ordinary rendering. `OrganizerIntake.producer:198-199` can bind the foreground
  owner while honestly withholding agent identity. No new OSC parser or observation inference is needed.
- `TerminalRender` is a finite 23-field encoder (16 KiB cap), not arbitrary stream interpretation.
  `OrganizerIntake.decode/readInput` provides top-level JSON allowlists, a 1 MiB limit and a two-second
  input deadline. These are usable existing contracts to retain rather than discard.
- Those paths import Darwin and live in a macOS Swift executable. The package is macOS 13+.
  No existing portable bounded writer plus ownership/policy check, or finite top-level hook parser,
  was found in production shell modules. Python is used by installers/tests, not a declared hook
  runtime dependency. Old `cat` plus greedy `sed` extraction retained bodies, accepted nested keys
  and mishandled JSON escapes. Restoring it would violate the current privacy/parser contract.
- Original `emit_osc` performed direct `printf > "$TTY_DEVICE"`; it did not have the new output
  lock/deadline. TTY query timeouts, identity mkdir locks and provider hook timeouts are not substitutes.

## Smallest safe repair direction

1. Keep the typed queue and existing macOS managed renderer. Provide an ordinary transport that
   standalone supported installs actually receive. Select its capability before rendering, rather
   than raw-writing after a failed managed operation. Reuse the bounded writer/parser contracts.
2. Any ordinary compatibility transport must prove uncontrolled/current policy under the same stable
   per-TTY output lock and budget. It must reject uncertain live ownership/targets, preserve suspension
   ordering and never replace failed controlled rendering. App absence or a pre-open file check is
   not proof that a controller owns no effect. Existing stale/failed-helper no-bypass tests remain valid.
3. Extract allowlisted legacy metadata independently of native organizer availability, using one bounded
   real JSON parser. Organizer correlation/context may remain unavailable; never invent trusted cues.
4. Deliver/preflight the selected transport through plugin/manual install and sync. Add owned-PTY cases
   for absent/old app with no owner, title/bell-only ordinary output and metadata, plus controlled/racing
   cases which still reject bypass. Preserve positive healthy-helper cases and explicit recovery failure.

## Creator decision

Preserving current ordinary compatibility is already required. The unresolved choice is how to supply
its safe transport on standalone macOS and Linux: package a plugin-local executable/runtime, or approve
one portable runtime dependency. PLAN `37-45` currently forbids an extra binary and says no new dependency.
That delivery choice needs creator input before a portability implementation; choosing Python merely
because tests use it or requiring Swift/app installation silently would add an unapproved requirement.
Resolving only the fixed app path to a scratch build fixes a developer case, not the product contract.

## Test interpretation

`hook-observations.bats:220-243` checks missing/old-helper dispatch into a substituted recording core;
it never verifies ordinary terminal bytes and does not assert preservation of the four metadata fields.
`managed-background.bats:226-238,370-385` correctly disallows raw bypass, but does not establish that
dropping all uncontrolled standalone signaling satisfies the SPEC. Extend coverage, do not weaken safety.

## Sync diagnostic follow-up

- Two-file diff preserves source-copy success independently of readiness: missing capabilities warn,
  omit the prompt-testing invitation and still report completed copying. Copy failures still return early.
- The ready branch requires both exact managed and organizer capability tokens. The `&&` short-circuits
  the organizer probe when managed support fails, which cannot falsely report readiness.
- Both existing probes use `--validate-config` and omit all three Sessions fixture launch keys.
  Current capability handlers return before native discovery, SwiftUI launch or device operations.
- This diff adds no raw output route, native catalogue query, helper installation or rendering change.
- One wording fix is needed: "Rebuild TAVS.app before testing these sources" presumes macOS and an app
  installation. On standalone/nonmac hosts it offers an unavailable remedy. Prefer "Hook rendering and
  metadata remain unavailable; sync does not build/install the helper" until creator scope is resolved.
- Added tests describe missing, unsupported and render-only probes. They were inspected, not executed.

## Approved portability direction and metadata source checks (2026-10-13)

The operator authorized all remaining steps needed for the goal. The implementation chooses
Python 3 standard-library support for standalone macOS/Linux compatibility. PLAN/SPEC bodies
remain fixed; PROGRESS records this narrow dependency/file-list exception. Metadata is the first
verified slice. H1 remains open until the safe writer, lifecycle and platform acceptance pass.

### Retained source report: explorer-tavs-portable-helper-20261013.md

# H1 Python3 portable helper route

Source-only investigation at 3144a88. No edits to project files, builds, tests,
apps, native/libproc calls, devices, web calls or parent-goal access. Python3
runtime approval is taken from the parent's brief; installed runtimes were not probed.

## Recommendation and bounded implementation order

Deliver a plugin-relative Python3 standard-library helper with the existing core
source tree. Keep the native renderer preferred whenever its exact capability
probe succeeds. The portable route must implement the complete finite ordinary
render batch, metadata and delivery lifecycle, and prove absence of applicable
control under the existing output lock. It does not replace native controller
composition or independent native recovery. Never choose it after a selected
native managed operation has failed.

First slice: portable allowlisted metadata parser plus capability/resolver wiring
and delivery preflight. This immediately repairs legacy metadata without needing
process/TTY inspection. It is useful, but cannot close H1 because it paints nothing.
Next slice: process identity bridge, compatible delivery/context records and the
bounded ordinary writer, including synthetic idle/context-check/forced-reset
paths. Test and commit those slices separately. Do not stop at the metadata slice
or silently withdraw Linux/standalone signaling to make tests pass.

Suggested small modules: src/core/portable_helper.py (verbs/intake/render parser),
portable_process_identity.py (macOS/Linux bridge), portable_output.py (records,
policy, lock and bounded write). No server, generic backend interface, index or
new persistent protocol is needed. Reuse schema-1 records on macOS. Advertise a
distinct portable ordinary-output capability until every claimed native verb is
implemented; do not claim full managed-output semantics for an uncontrolled-only
writer. Selection remains outside the render operation, not a failure handler.

## Existing contracts to retain

- SPEC:123-164 preserves top-level allowlisted metadata, drops raw bodies, creates
  one delivery identity at intake, tracks latest ordinary intent even under control,
  and preserves ordinary signaling when uncontrolled. SPEC:263-272 requires fresh
  in-lock policy/identity checks, open-before-output-lock and the 100 ms writer bound.
- helper-compatibility-check-2026-10-13.md proves native-only fixed-path resolution
  breaks standalone installs. Current plugin/manual/sync delivery does not install
  TAVS.app. Missing native recovery remains explicit; ordinary output is a different
  compatibility promise. PLAN:37-45's no-extra-dependency wording needs narrow
  updating for the newly approved Python runtime, not another approval request.
- organizer-state.sh:20-140 currently probes exact native organizer/managed tokens,
  creates contexts, observes, checks synthetic freshness, reconciles and forces
  reset. Its 23-field NUL queue/flush at 145-214 already carries the whole style.
  Preserve rendered/restricted/unaffected outcomes and code 3 stale behavior.
- OrganizerIntake:23-67 is the metadata mapping: Claude permission_mode, session_id,
  cwd, transcript_path, allowed hook_event_name/notification_type; Codex thread-id,
  cwd, type and turn-id. Keep exact byte limits, null/empty handling, decoded JSON
  strings and session-ID control rejection. Unknown/nested payload bodies are not
  retained. Input is <=1 MiB with a two-second read deadline; no cat/sed/eval route.
- TerminalRender:12-54 requires <=16 KiB, exactly 23 UTF-8 fields plus final NUL,
  finite flags/actions, normalized hex/rgb/reset, title/image control rejection.
  Preserve palette-before-background, title/image-after-background and synthetic
  BEL suppression. Title persistence happens only after actual rendered outcome.
- managed-output-entry:78-134 verifies source generation/device/ancestry, then
  continuing owner, before rendering. TerminalVisualStateStore:695-785 checks
  synthetic delivery against latest observation and rejects superseded intake.
  Context/identity is not inferred from provider JSON, title or directory names.
- VisualRecovery:181-425 publishes typed intent, rechecks policy under serialization,
  composes native ownership, handles expired ownership and emits finite bytes.
  Portable code must not parse arbitrary OSC or reuse pending OSC files.

## Minimum identity bridge

macOS: ctypes with system libproc's proc_pidinfo(PROC_PIDTBSDINFO=3), exact returned
size, matching pbi_pid, pbi_start_tvsec/usec, PPID, PGID, e_tdev and e_tpgid.
Reject SZOMB=5 and PROC_FLAG_INEXIT=4. Local SDK headers confirm these fields and
constants (sys/proc_info.h:59-81,105,723; sys/proc.h:153; libproc.h:96).
The declared struct has 12 uint32 fields, 16+32 char bytes, five uint32 fields,
one int32 and two uint64 fields: 48+48+20+4+16=136 bytes. Assert that layout and
returned size; unsupported layout is unavailable, not a ps timestamp fallback.
proc_pidpath is needed only if porting native provider verification; ordinary
binding can honestly remain verifiedAgent=false, as OrganizerIntake:198 allows.

Linux: bounded reads of /proc/<pid>/stat, splitting after its final ')' so spaces
or parentheses in comm cannot shift fields. Required fields are state, PPID,
process group, tty_nr, foreground group and starttime ticks. Compare device numbers
through one documented Linux encoding adapter against lstat/fstat character-device
identity. Support real /dev/pts/N as well as concrete /dev/tty names; the current
macOS concreteTTY predicate cannot be copied unchanged. Never authorize /dev/tty
as a lifetime-specific target. Reject zombies, missing/mismatched generations,
unreadable proc data, absent controlling TTY and ambiguous foreground owners.
Retain start ticks as the canonical generation; if interoperable seconds/useconds
are required, derive them with integer btime+ticks/SC_CLK_TCK arithmetic and verify
stability within the boot. Do not use rounded ps start times or PID-only identity.
Linux /proc field/device/boot semantics need official or Linux-target verification
before implementation acceptance; no Linux host or external reference was queried.

For both adapters, repeat generation/device checks, cap ancestry walks at 16,
reject loops and attest the non-synthetic producer as an actual helper ancestor.
Follow the existing same-device continuing-owner rule. Synthetic workers use the
original current delivery and live producer checks, not new agent occurrences.
Permission denial or kill(0) EPERM does not establish process death. Native surface
records also require their app generation checks; unsupported/unknown identity
must reject ownership resolution rather than imply no controller.

## Complete ordinary writer boundary

Use the same organizer/writer-<URL-safe-base64-TTY>.lock (600), target-generation
paths, observation/intent schemas and bounded regular-file reads. Validate paths,
file kinds, schemas, canonical placement, aliases and same-TTY owner ambiguity.
Reject symlinks, malformed/unknown records and uncertain live ownership. Preserve
stale-delivery checks even for title/palette/BEL-only requests. Publish latest
normalized ordinary intent under the lock; no active owner means no controller
currently applicable, not merely an absent helper executable.

Evaluate the exact suspension marker, lock.state and mute.state and target effects
under the output lock, matching VisualRestrictionPolicy's current rules. Preview
lease is two seconds, other selective ownership six seconds; controller generation
must validate. Suspended restrictions can still have an explicit preview. Do not
mistake an unavailable marker for ordinary-output authorization. If native control
is applicable, use the already selected compatible native route, or return explicit
unavailable from portable output while retaining safe typed intent. No raw bypass,
no stale color/palette replay, no composition guessed from cached background alone.

For output, use os.open O_NONBLOCK/O_NOCTTY/O_NOFOLLOW, fstat device checks,
fcntl.flock LOCK_EX|LOCK_NB, monotonic deadline checks and bounded select/poll/write.
A thread alone does not establish the caller deadline if open blocks. A single
request-local supervisor plus forked worker is a small standard-library route on
both Unix platforms: one absolute 100 ms deadline starts before worker dispatch;
parent waits only to that deadline and terminates an overdue worker; child checks
expiry after late open and before metadata/output. No late paint or fresh budget
per stage. The worker opens the TTY before acquiring output serialization. Python
startup/intake are separate from this writer budget, just as native startup/input
are separate today; do not claim entire hook execution <=100 ms without measurement.

## Delivery and required verification

Resolve portable files relative to organizer-state.sh's own installed location;
use a declared/preflighted Python3 runtime, without pip/native build/GUI dependency.
Retain explicit test-helper override isolation and positive native capabilities.
Do not advertise a portable organizer capability while its context/observe/intent
verbs are absent. Metadata-only capability can ship earlier without invented cues.
The full route needs the idle check/reset/reconcile operations used at trigger:191,
413 and idle-worker-background:129, with existing stale/target-generation safety.

cmd-sync:102-107 currently copies only *.sh and *.txt from core: explicitly copy
all required Python modules and validate readiness in the destination. Plugin/full
repository installs naturally receive tracked files; agent install/preflight and
README prerequisites must acknowledge Python3. OpenCode's npm package ships only
dist/README and locates an external core tree (signal-bridge.ts:24-46); ensure that
installed core tree carries the helper. Do not infer delivery from a source checkout.

Acceptance: owned PTYs on macOS AND Linux for absent/old native app, metadata,
complete ordinary background/palette/title/BEL/image batch, synthetic freshness,
late/reused TTY, expired/dead owner, active/uncertain controller, suspension/recovery
race, held lock, blocked open and deadline expiry with no late bytes. Keep healthy
native cases and failed-native no-bypass tests. Existing hook-observations:50-78,
165,301-319 tests include metadata/privacy but missing-helper dispatch uses a fake
core; managed-background:226,370,388 protects no raw fallback. Extend them with
actual portable bytes, complete deployment copies and platform identity fixtures.
Passing metadata fixtures or a macOS-only mock does not close H1 portability.

### Retained source report: explorer-tavs-portable-metadata-followup-20261013.md

# Portable metadata-first diff review

Source-only review of current portable_metadata.py, organizer-state.sh, connected
intake/tests and the latest sync source. No edits to project files, builds/tests,
apps, native/device/web actions or parent-goal reads. H1 rendering is not solved.

## Findings

No concrete introduced parser, privacy or stale-export defect found in the
inspected implementation. The brief's initially pending sync copy is now present
in current source; this review does not claim that its red test has been rerun.

## Checked contracts

- read_input uses nonblocking fd reads and select with one monotonic two-second
  input deadline. It reads at most 1 MiB plus one rejection byte and restores
  stdin flags in finally. A pipe withholding EOF expires instead of waiting forever.
  The bound covers stdin reading, not Python process startup or a separate hard
  deadline around json.loads, matching the native read/decode distinction.
- json.loads requires a top-level object and rejects nonstandard constants. The
  four field mappings match OrganizerIntake: Claude mode/session/cwd/transcript,
  Codex default mode/thread-id/cwd with empty transcript. Missing/null values clear
  to empty, unsupported mode clears to default, wrong types are rejected.
- Field limits are UTF-8 BYTES (128 mode, 512 session, 4096 paths), with NUL rejected.
  Session/thread IDs reject Cc and Cf. The installed CoreFoundation CFCharacterSet.h
  defines kCFCharacterSetControl as exactly those two Unicode categories, matching
  the native CharacterSet.controlCharacters check. Decoded newline in cwd remains
  data, and terminal/control syntax in metadata is not executed as shell code.
- Only four fields and TAVS_LEGACY_METADATA_INTAKE are emitted as NUL pairs, after
  all metadata validation succeeds. Raw JSON, unknown/nested fields and body text
  are not logged, forwarded or persisted. Malformed UTF-8/surrogates, parse recursion,
  I/O and validation failures use a generic body-free diagnostic, without traceback.
- The portable path intentionally does not validate/extract provider event/turn
  fields because it creates no organizer context or observations. This differs
  from native event validation, but does not grant observation authority or change
  the requested four legacy-field contract.
- organizer-state.sh chooses the native route from its exact capability probe
  before intake, then executes only that chosen branch. A failed native intake
  is not reparsed with Python. Unsupported/absent native helper selects Python
  before reading the payload. Metadata success still returns organizer-unavailable.
- Every call unsets raw payload, organizer context/intake and helper caches, uses
  local default/empty legacy fields, then exports the resulting four fields. Missing
  Python, missing script, malformed input or native failure cannot preserve prior
  context/intake. Portable success does not export a native helper cache or trusted
  TAVS_ORGANIZER_INTAKE. The private marker is consumed as a local flag only.
- command-v failure avoids Python invocation and produces the generic metadata
  unavailable status. Invocation/parser failures likewise leave safe defaults.
  Existing adapters intentionally continue fixed signal dispatch, but no portable
  terminal writer is provided by this slice.
- Current cmd-sync.sh:104-107 explicitly copies portable_metadata.py and returns
  nonzero on copy failure. Python invokes the file directly, so executable mode
  is unnecessary. The comparison test checks both existing installation targets;
  it does not replace missing-helper render readiness with a success claim.

## Tests inspected and remaining useful coverage

New tests cover missing/old native helpers preserving decoded metadata, Codex
escapes/newlines, nested-body privacy, invalid types, NUL/session controls, lone
surrogates, invalid constants, oversized input and an open-pipe deadline. Existing
native metadata/privacy cases remain; the fixture now copies the Python helper.

Add a supported native capability whose intake consumes stdin then fails, with
valid portable-readable metadata, and assert empty/default fields, no context and
no portable reparse. Add missing-runtime and missing-file cases with stale legacy
fields/context/intake preseeded, asserting clearing and generic failure. Include
TAVS_ORGANIZER_INTAKE in capture assertions because current portable tests inspect
context but do not directly assert absence of that trust hint. Exact 512-byte /
multibyte boundaries would strengthen byte-limit parity without duplicating tests.

Delivery/runtime caveat: installers/docs still need the approved Python3 prerequisite
and later helper readiness work. The current native-render readiness warning can
remain explicit during this bounded metadata slice. Neither portable metadata
success nor source-copy success establishes ordinary OSC output or H1 closure.

## Portable primitives: source synopsis (2026-10-13)

`764e22b` adds process/device identity; `1029d4e` adds the bounded device transaction.
These are foundations, not a working standalone hook backend. They advertise no capability.
The metadata reader remains the only connected portable path. H1 remains incomplete.

[Native Linux research](portable-linux-identity-research-2026-10-13.md) and
[partial AGY research](portable-linux-identity-agy-partial-2026-10-13.md) were read and compared.
Wiki recall found irrelevant passages, so the verdict was proceed. The AGY public-web contract
passed and its one Flash call completed. No repository was supplied or fingerprinted. Its
claims about numeric PID reservation and extended-minor device mismatch remain rejected leads.
The independent native report and retrieved kernel/man-pages support the narrower conclusions.

Linux identity avoids btime conversion, requires aligned proc numbering, compares namespace
pairs/offsets and accepts only after the full birth tick has passed under the exact conversion
branch. Two reads use one held proc directory. Live namespace continuity is an explicit proof
condition; arbitrary restoration/migration and older/masked kernel properties remain unsupported
until separately evidenced. `linuxScope` is not native schema-1 JSON; future records require
explicit Linux versioning. No scope field is silently inserted into Mac records.

Current validation: 14 isolated primitive checks, real macOS owned PTYs, parser fixtures and
full Swift 561/561. Linux runtime remains pending the Docker startup question; its daemon is
stopped. No container or new VM was started. Complete finite render decoding, policy/ownership,
publication/binding, synthetic reset/reconciliation, backend selection and install/sync delivery
remain next work. Interpreter startup and bookkeeping are not counted as device time.

### Retained exact writer contracts

# Exact portable ordinary-writer contracts

Source extraction only. No project edits, builds/tests, native/apps/devices,
web or goal calls. References below use TAVSApp Sources/TAVSApp filenames.
`?` means a JSON field may be omitted or null; all other listed keys are required.

## Schema-1 JSON shapes

| Value | Required keys | Optional keys |
|---|---|---|
| ProcessGeneration | pid, startSeconds, startMicroseconds | none |
| Native surface ID | application (generation), terminalID | none |
| Target binding | tty, device, ttyOwner (generation) | nativeSurface? |
| Cached target | schema, target | none |
| Observation | schema, tty, provider, verifiedAgent, state, deliveryID, observedAt | device?, producer?, event?, responseID? |
| Intent / bound intent | schema, tty, deliveryID, updatedAt, background | device?, producer? |
| Effect | schema, target, controller, effectID, kind, background, heartbeatAt, active | focusColors?, revision? |
| Colors | background, foreground | none |
| Revision identity | device, inode | none |
| Adoption | schema, tty, device, producer, surface | observationDeliveryID?, intentDeliveryID? |
| OrganizerContext | schema, deliveryID, observedAt, provider, verifiedAgent | producer?, device?, event?, responseID? |

Records, nested generation/surface/color/revision values reject unknown JSON keys
(terminal-visual-state:1121-1250, terminal-renderer:19-24). OrganizerContext uses
synthesized Codable: decodedContext:128-135 checks token<=8192 bytes, base64, schema=1,
provider allowlist; it does not itself validate authority or reject unknown keys.
A context encoder must never insert raw payload/legacy display metadata into it.

All schema fields equal integer 1. Python must distinguish JSON bool from integer.
Process pid is positive Int32; startSeconds>0 UInt64, microseconds UInt64<1,000,000.
Target device is UInt32 except UINT32_MAX. Revision device is native filesystem
dev_t and inode ino_t, NOT the target's UInt32 TTY device. Valid revision requires
inode!=0 OR device==0; missing-file sentinel is exactly {device:0,inode:0}.

## Exact names and paths

Let O=<runtime>/organizer, K(s)=URL-safe base64 of UTF-8 s without '=' padding,
G(g)=decimal pid-startSeconds-startMicroseconds, P=O/targets/K(tty)/G(owner).
K replaces '+' with '-' and '/' with '_'; it is reversible, not a digest.

| Object | Canonical path |
|---|---|
| Output/metadata lock | O/writer-K(tty).lock |
| Latest observation / intent | O/observation-K(tty).json / O/intent-K(tty).json |
| Plain target directory | P/plain/ |
| Native alias directory | P/G(application)/K(terminalID)/ |
| Cached / bound records | target.json / bound-intent.json in target directory |
| globalRestriction or selectiveBackground | effect.json in target directory |
| Preview / focus | preview.json / focus.json in target directory |
| Adoption | O/adoption-K(tty)-G(producer).json |
| Obsolete pending OSC | <runtime>/pending/<tty with '/' replaced by '_'>.osc |
| Suspension / soft pause | marker path / marker's sibling mute.state |
| Hard lock | <runtime>/lock.state |

Sources: state:533-550,963-973; recovery:617-631. Canonical placement is validated
against decoded target, including effect kind. Filename presence alone authorizes
nothing. Target records are <=8192 bytes; reads require lstat/fstat regular files,
matching inode/device, O_NOFOLLOW|O_NONBLOCK|O_CLOEXEC and bounded reads. Writes use
600 temporary sibling files, bounded writes and atomic rename. Stable lock is a
600 regular file; target directories must be actual directories, not symlinks.

## Validation, selection and ordinary intent

| Contract | Exact existing condition |
|---|---|
| Common observation/intent | tty absolute <=128 UTF-8 bytes, no ./../control components, standardized tty != /dev/tty; ID valid; finite timestamp 0<t<=now; optional producer's epoch start<=t; device != UINT32_MAX |
| ID | Nonempty <=128 UTF-8 bytes; ASCII A-Z,a-z,0-9 or '- . : _' |
| Observation | provider claude/codex only; fixed state/event sets; optional responseID valid ID |
| Target shape | Native concrete /dev/tty suffix is ASCII alphanumeric and nonempty; owner generation valid; native terminalID nonempty <=128 bytes without controls |
| Target live status | Changed owner generation/device or proven owner/device loss => vanished; absent unproven identity, owner-device/descriptor mismatch => unavailable; native app generation also validates |
| Resolution | Scan requested TTY across ALL owner lifetimes; union cached targets AND effect targets; live conflicting physical owners reject; plain+one native preferred; >one live native rejects |
| Held-lock aliases | Exact physical lifetime only; validate every target.json/placement; unavailable alias rejects; valid plain+one native allowed; >one live native rejects |
| Bound intent read | Valid intent plus schema1 exact matching target.json; same tty/device; producer nonnull |
| Bind intent | Live producer's continuing owner equals target owner; latest intent equals normalized supplied intent in ALL fields; write target and bound copy |
| Restore intent | Latest same tty/device/non-null producer; exact full equality to ANY equivalent bound copy permits after producer exit; otherwise producer live with same continuing owner; native target additionally needs matching adoption and delivery |
| Effect shape | Valid target/controller/ID/background; 0<finite heartbeat<=now; kind in globalRestriction,selectiveBackground,preview,focus |
| Focus/revision | focusColors exists iff kind focus; focus requires revision; revision otherwise only preview; colors normalized hex and revision identity valid |
| Lease active | active=true; valid record; controller lookup generation equal; preview age<2 seconds; other selective age<=6; globalRestriction never selective |
| Same-ID save | Controller equal; canceled record cannot revive; preview heartbeat immutable; focus same colors/revision, current lease live, nondecreasing heartbeat |

Sources: state:151-174,214-268,303-411,499-529,880-961; recovery:497-542.
Native cached resolution ignores unreadable paths/non-valid bindings, but held-lock
alias/effect reads are stricter. Portable proof must not interpret unreadable or
unknown live ownership as absence merely by copying that pre-lock filtering.

States: processing,permission,complete,idle,compacting,reset,subagent,tool_error.
Events: UserPromptSubmit,PreToolUse,PostToolUse,PostToolUseFailure,PermissionRequest,
Notification,Stop,SessionStart,SessionEnd,PreCompact,SubagentStart,SubagentStop,
permission_prompt,idle_prompt,agent-turn-complete. verifiedAgent=false can bind
ordinary intent. It cannot create automatic-focus authority. Claude eligible events
are complete/Stop or permission/PermissionRequest|permission_prompt; Codex is
complete/agent-turn-complete WITH responseID (state:891-897).

## Freshness and lifecycle operations

| Operation | Required behavior |
|---|---|
| Observe | Validate record, lock TTY, reject observedAt older than latest; recover invalid latest only if a regular file; atomically publish |
| Publish ordinary | intake finite 0<intake<=updatedAt; reject latest observation observedAt>intake; normalize background; require updatedAt>=current intent unless exact matching current observation proves a superseding delivery/producer/device |
| Publish synthetic | Same ordinary ordering PLUS latest observation must match tty/device/producer/deliveryID and producer must be live; no new observation/cue |
| Validate render context | Non-synthetic: valid record, observation not newer than intake, producer live; synthetic: frozen latest observation exact match and observation time<=intake, live producer |
| Check synthetic context | Validate under existing writer lock, emit no bytes, publish/cache no target/intent/effect; writer/lock open itself still occurs |
| Forced reset, live producer | background reset only; same target tty/device/live owner; latest intent if present must keep producer/delivery; synthetic observation freshness; producer continuing owner equals target; publish/bind reset |
| Forced reset, non-live producer | Latest intent REQUIRED and unchanged producer/device/delivery; observation exact match and time<=intake; a validated live target owner; any equivalent bound intent must equal latest FULL record; publish reset and direct bound copy |
| Reconcile | Resolve cached valid same-TTY bindings, not a raw pending OSC replay; invalidate pending file; compose latest bound/current intent with current policy/leases; cancel requested selective effects; preserve current suspended preview revision |

Sources: state:607-619,632-790; recovery:222-246,301-425. Native forced-reset's
non-live branch uses validProducer=false, not a separate proof of producer death;
its safety comes from exact unchanged delivery/bound intent and live continuing
owner. Do not broaden it to any old intent after missing identity.

Ordinary publish can ignore invalid latest observation and recover invalid REGULAR
intent, but synthetic cannot. Render-context validation is strict even for style-only
requests. Deadline/storage errors never become permissive invalid-record recovery.
Stale delivery/observation/intent/effect returns code 3 in the managed entry; ordinary
unavailability/storage/policy failure returns nonzero. Do not rewrite stale synthetic
context into a fresh delivery. Forced reset rechecks before open AND inside output lock.

## Revision, suspension and global policy

| Policy item | Exact rule |
|---|---|
| Marker serialization | SCHEMA_VERSION="1" newline SUSPENDED="true" or "false" newline, exactly; <128 bytes regular file |
| Missing marker | Active only if nearest existing parent is a searchable directory; otherwise unavailable |
| Disabled restrictions | Status suspended OR unavailable; policy.current returns nil, but this alone does NOT establish safe typed rendering |
| Capture revision | Reject unavailable marker; hold read-only no-follow FD for existing file until request ends; missing sentinel otherwise |
| Match revision | Missing path matches only 0/0 sentinel with available parent; existing regular path matches exact filesystem dev/inode and nonzero inode; no Boolean/content equality substitute |
| Rule files | <=8192 regular no-follow/inode-checked bytes; UTF-8 quoted KEY="VALUE" lines; no NUL/duplicate keys; schema absent defaults1, otherwise1 |
| Hard lock | Bool LOCKED and decimal Int64 LOCK_UNTIL_EPOCH; optional UNLOCK_UNTIL_EPOCH/WRITTEN_EPOCH default0; effective = locked && now<lockUntil && !(now<unlockUntil) |
| Soft pause | MUTED bool; (REQUESTED_MUTED??MUTED)==true; recognized REASON; MUTE_LEVEL soft, or absent except hard_lock; hard/unknown level ignored |
| Pause liveness/time | Decimal UNTIL_EPOCH/WRITTEN_EPOCH/APP_PID; pid>0 Int32 and alive; until==0 or now<=until; written<=now and now-written<=120 |
| Selection/recheck | Hard lock wins, otherwise soft pause; re-read suspension before returning current rule |

Sources: visual-restrictions-state:5-151; visual-restriction-policy:24-120;
LockState:30-32. Mute reasons: schedule_window,quiet_period,master_paused,hard_lock,"".
Native malformed rule TEXT selects no rule; file I/O/type/size errors throw.
Revision identity is independent of content validity. Typed render/forced reset
capture revision before publication/open and compare under output lock, so atomic
recovery replacement invalidates queued output even when SUSPENDED value is unchanged.

Selective precedence: explicit current preview > active focus > selectiveBackground;
focus/selective suppressed when restrictions disabled, but valid suspended preview
can remain. Applicable aliases must agree in effectID/controller/revision/colors
(and background unless focus). Native nil controller lookup yields inactive; Python
cannot treat an UNKNOWN fresh owner as proven absent to authorize uncontrolled output.

## Finite render protocol and output boundary

| NUL field index | Constraint |
|---|---|
| 0 | Empty means no background; otherwise normalized hex/rgb/reset |
| 1 | Palette action empty/set/reset |
| 2..17 | Empty or normalized #RRGGBB; nonempty requires palette set |
| 18 / 19 | Title flag 0/1; title<=8192 UTF-8 bytes; flag0 requires empty |
| 20 / 21 | Image action empty/iterm2-set/iterm2-clear; path<=4096; set requires absolute; others empty |
| 22 | Bell flag 0/1 |

TerminalRender:12-96: exactly 23 fields and final NUL, <=16384 bytes, strict UTF-8.
Title/image reject scalar<32 and 127..159; format characters remain allowed.
Palette reset OSC104 ST; set OSC4 ;i;rgb:RR/GG/BB ST. Background reset OSC111 ST,
color OSC11 ;#RRGGBB ST. Then title OSC0 ST, iTerm image with BASE64 path and BEL
framing, then ordinary audible BEL. Synthetic suppresses only audible bell, not
image framing. Hex trims whitespace and uppercases; rgb components have 1..4 hex
digits, scale via (value*255+maximum/2)/maximum integer division, maximum=16^digits-1.

Python minimum under ONE existing writer deadline/lock: validate current lifetime,
all relevant record shapes/aliases and frozen delivery; compare pinned revision;
publish/bind current intent; recompute policy and applicable leases. Any applicable
native control must stay on the selected native path or explicitly fail, never
fake composed bytes or claim ordinary rendered after suppression.

Once genuinely uncontrolled, clear expired/canceled selective ownership as native
would and use current bound/latest intent, not an old OSC snapshot. Residual active
globalRestriction records additionally require finite legacy cleanup OSC104 BEL
and OSC110 BEL before ordinary background/style; forced reset also emits OSC104 BEL
when that legacy prefix was unnecessary, then reset background and its safe title.
Implement that cleanup exactly or leave a stated compatibility gap. Rejecting every
expired cached owner forever does not preserve ordinary-after-ownership behavior.

Native render result: actual ordinary style write => rendered, actual global rule
write => restricted, no bytes => unaffected. Selective composition can still render
ordinary palette/title/image/BEL. These statuses cannot substitute for capability
support. Reconcile while suspended cancels obsolete active effects, resets legacy
palette/foreground when needed, and never replays the ordinary theme after a fully
completed recovery unless an explicit current preview still needs its ordinary base.

### Retained primitive source review

# Portable identity/writer primitive source review

Source-only inspection of portable_process_identity.py, portable_device_writer.py
and their two unit-test files. No imports/execution, tests/builds, apps/devices,
web or goal access. These primitives are unwired; no capability or H1 completion
claim is made. Linux kernel acceptance remains pending.

## Concrete issues found and latest-source disposition

The initial source omitted a deadline check after device_number/lstat and before
os.open, and omitted a check between successful flock and prepare. An expired
transaction could therefore open or enter metadata-mutating preparation before
its next check. Latest source now includes both checks. This restores the native
writer's explicit checkpoints without resetting the original deadline.

Initial child error serialization defaulted an unannotated error to bytes=0.
A lock/device close error AFTER successful output could then falsely imply no
paint. Latest source defaults that field to None (unknown), and normalizes an
OSError with absent/zero errno to EIO. Known write-loop partial counts are retained.
No runtime reproduction or test-pass claim is inferred from these source repairs.

No remaining concrete introduced correctness defect found in the latest inspected
primitives, subject to the explicit lifecycle/platform limitations below.

## Narrow checks

- _BSDInfo mirrors the installed SDK struct: twelve uint32s, 16+32 char bytes,
  five uint32s, one int32, two uint64s =136 bytes; birth fields at120/128. pidinfo
  flavor3, returned-size equality, matching PID, positive seconds, microseconds
  bound, zombie and INEXIT rejection match the Swift bridge. Mac generation keys
  remain pid/startSeconds/startMicroseconds.
- Linux parses after the final ') ', bounds stat input and numbers, discards
  arbitrary comm bytes and rejects exited/zombie/unsupported states. It accepts
  only after the complete birth tick, derives an injective tick representation
  for supported rates and avoids wall-clock btime identity. Two reads must agree
  in returned generation, parent/group/device/foreground fields.
- Linux requires self NSpid exactly one current PID, target/self PID AND time
  namespace inode/device equality, a valid boot UUID, complete numeric time
  offsets, and stable target namespace identity after reads. Missing evidence
  returns unavailable; no ps/PID-only fallback is introduced.
- Continuing-owner rejects mismatched seed generation/device, bad parent links,
  loops and unavailable parents, climbs only same-device parents, then rechecks
  generation. Its final equality matches the existing native helper; the typed
  writer must still validate current owner/device under the lock at integration.
- Parent creates ONE monotonic deadline before pipe/fork. Child receives that same
  deadline through before_open, open, flock, prepare and write. Late open and
  preparation now have explicit checks. Child closes inherited fd0/1/2 except
  an internal result descriptor occupying one of those numbers; it never retains
  the caller's original stdin/stdout/stderr endpoints via those descriptors.
- Output checks exact character-device rdev, stable regular private/owned lock,
  finite bytes payload and partial writes; timeout/malformed/no child result means
  unknown bytes, not success. Parent signals only its own tracked fork PID; waits
  use waitpid(pid), not waitpid(-1). No generic retries or native composition exists.

## Lifecycle and acceptance limitations

write_managed's finally performs WNOHANG, requests SIGKILL if still alive, then
polls again. If termination is not yet observable, the owned PID remains in
_children until a later reap_completed/write. A final call therefore does NOT
prove child retirement on return. Current unit tearDown polls once; it likewise
cannot prove an overdue child exited before PTY teardown. Keep the 100 ms caller
bound, but add a separate test-owned bounded drain/retirement assertion before
claiming all children retired. Do not turn unknown output into a retry because
kill was requested. Kernel-stalled children may delay actual exit despite SIGKILL.

Initial reap_completed occurs before deadline creation; process startup and that
prior-child bookkeeping are outside the device budget. Parent may also resume
late after select; source cannot promise hard wall-time scheduling guarantees.
A captured prepare callback runs in a forked child: in-memory mutations do not
publish back to the parent. Future outcomes must use typed IPC/durable records.

Linux tests currently include only a parser fixture and platform-conditional
current/PTY checks. They do not establish actual Linux acceptance until run there.
Especially verify kernel starttime versus CLOCK_BOOTTIME with nonzero time offsets,
PID/proc mount namespace evidence, birth-tick boundary, tty_nr/rdev encoding and
unavailable namespace files. Do not infer these facts from macOS fixture success.
linuxScope plus boot-relative startSeconds is NOT native schema1 generation JSON;
future Linux records need explicit versioning, while Mac keys stay unchanged.

## Small concrete regression additions

1. Direct _perform with a clock advancing during device validation: open must not
   run after expiry. Repeat by advancing at flock acquisition: prepare must not run.
2. Inject close failure after a completed payload: report known full count or
   unknown, never zero. Retain the existing three-byte partial-write test.
3. Hold open/prepare through parent timeout, separately confirm owned child exit
   and reap, then assert no late bytes and no held caller stdio channels.
4. Run the real Linux identity/PTY cases and explicit namespace/offset rejection
   cases on Linux. This is required platform evidence, not another mock substitute.

### Parent review resolution

The two missing phase checkpoints were verified in source and reproduced in `CLpU4A` with
termination deliberately delayed on owned targets. Restored checks produce passing outcomes.
Errors carry a known partial count or unknown. A Python integer-only exception-property draft
failed in `mir9tF`; the dedicated `bytes_written` attribute fixes it. Test teardown now separately
polls/reaps owned children before closing PTYs, without increasing the writer deadline.
The final primitives are unwired; this review does not establish controlled policy or Linux
kernel acceptance. Producer/owner validation remains required in the typed preparation layer.

## Retained portable reader comparison: 2026-10-13

# Portable policy/render and record source comparison

Read-only comparison against native VisualRestrictionPolicy, VisualRestrictionsState,
TerminalRender, Colors Codable and terminal-visual-state record validation.
No repository changes, helper tests, apps, device output, web or goal calls.
Two parent-authorized pure Swift/Foundation string/JSON probes ran through stdout;
they touched no application or terminal target. No file/report fingerprinting.

## Findings and latest-source disposition

1. Hex normalization parity was incorrect initially and is now SOURCE-VERIFIED FIXED.
   Python default strip excludes U200B and includes U001C..001F, while installed
   Foundation behaves oppositely. Native also uppercases BEFORE validating the six
   canonical hex digits. The string '#abcdﬀ' therefore becomes '#ABCDFF' (seven
   total characters), while the original portable code rejected it. Latest source
   uses the exact probed trim set, uppercases first and shares normalization from
   normalized_background instead of using its former pre-normalization regex.

   Exact installed Foundation trim set, verified by querying all Unicode scalars:
   U0009..U000D, U0020, U0085, U00A0, U1680, U2000..U200B,
   U2028, U2029, U202F, U205F, U3000.
   Equivalent Python literals:
   '\t\n\v\f\r \u0085\u00a0\u1680\u2000\u2001\u2002\u2003'
   '\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u200b\u2028'
   '\u2029\u202f\u205f\u3000'

2. Focus-color record normalization was discarded initially and is now
   SOURCE-VERIFIED FIXED. Native Colors.init(from:) stores canonical background/
   foreground values. Portable decode originally validated normalized_hex but
   returned raw case/whitespace strings, changing alias recipe equality. Current
   decode assigns colors[component] = normalized_hex(color), matching native value
   semantics. Other effect/intent background strings are validated but need not
   be rewritten at decode: native normalizes those when publishing, not in Codable.

3. Post-decode deadline check was absent initially and is now SOURCE-VERIFIED FIXED.
   Native state.read checks the supplied deadline AFTER JSONDecoder returns.
   Portable read_record originally returned decode directly. Current code saves
   the result, calls existing check_deadline(deadline), then returns. JSON parsing
   or validation cannot grant a fresh deadline or return an expired record as valid.
   The parent reports red u5OOFR and 31 passing portable checks in 011F9n; those
   helper tests were not run or independently verified during this review.

4. Numeric lexical acceptance is an intentional COMPATIBILITY SUBSET.
   The pure Foundation JSONDecoder probe accepted 1.0/1e0 in Int/UInt64 fields and
   rejected Boolean-as-number and numeric-as-Boolean. Portable _integer rejects
   integral floats/exponent-decoded floats, while accepting canonical JSONEncoder
   integer fields and correctly rejecting bool. Parent explicitly retains that
   strict canonical-record contract and will document it. Do not describe the
   decoder as accepting every JSON lexical representation native Codable accepts.
   This is not an ownership bypass or a reason to expand numeric coercion blindly.

5. Leading-zero epoch handling was an initial SAFETY MISMATCH, already corrected
   during review. Native Int64 accepted 32 zeros+'2000' in the string probe.
   The initial portable raw-length<=19 gate could treat that valid active lock or
   pause as inactive. Current _epoch strips leading zeros before digit-length/
   Int64-range checks. Existing all-digit validation, nonnegative range and overflow
   rejection remain. No runtime policy result was inferred from the string probe.

## Other requested checks

Policy file bounds, regular-file/no-follow/inode checks, exact suspension bytes,
missing searchable-parent behavior, pinned revision identity, hard-lock boundaries,
unlock grants, soft pause reasons/level/requested state and liveness/120-second
freshness match the inspected native decisions. Portable unavailable marker raises
an internal exception, while native exposes unavailable/disabled status; that is
intentional conservative ordinary-output handling, not an accidental active-state
conversion. Policy.restricted returns a Boolean because portable code identifies
native control rather than synthesizing its visual colors.

Render field count/final NUL/16 KiB cap, UTF-8 byte limits, title/image control
rejection, palette-before-background ordering, reset distinctions, iTerm base64/BEL
framing and suppression of only the synthetic audible bell match source.

Record decoding rejects missing/unknown nested keys, duplicate keys, wrong types,
invalid IDs, future/non-finite timestamps, bad generation ranges and invalid focus/
revision combinations. No malformed-record path was found that gains authority.
Duplicate-key rejection and canonical numeric restriction are conservative parsing
choices. Linux scope-bearing generation records remain outside native schema1.

No remaining concrete unintended safety or ordinary-render mismatch found in the
latest inspected code. Integration must still consume these APIs correctly; this
review does not establish complete H1 rendering or Linux/device acceptance.
