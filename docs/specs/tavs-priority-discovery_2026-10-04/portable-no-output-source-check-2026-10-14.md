# Portable caller ancestry and no-output source checks

Last Updated: 2026-10-14 (Europe/Vienna)
Version: 1.0

Sources: `e938da6` (ancestry) and `dfd00a1` (no-output managed operations). Source reports are
separate from executed acceptance.

## Parent disposition and verification

Native `visual-recovery.swift:498-506` includes cached effect targets in native preference and
ambiguity checks. Confirmed source P2: target-only selection omitted valid effect-only native
aliases. ZUN61m reproduced both wrong plain caching and missing ambiguity rejection. Internal
identity-hint lookup now retains valid canonical effect targets, skips invalid regular effect
hints without repair and excludes bound data. Actual output admission remains strict. j94ivS
passed 15 no-output cases after correction; the appended source check found no introduced bypass.

Native operation ordering at `visual-recovery.swift:213-238,316-317` keeps register/check separate
from policy/lease admission. Current validates effect slots and treats unavailable suspension as
disabled without paint. Portable current retains this behavior, while active-marker rule storage
errors and deadlines fail. Caller proof follows native `managed-output-entry.swift:216-235` with
16 visits, final birth/device recheck and its own unchanged deadline.

A5OER6: 10 initial missing-method errors. C6uOKG: three initial missing-ancestry errors. 6QwIK3:
10 initial no-output cases; 1St1Rj: nine identity cases; hcBiw5: 134 portable checks. After the
alias correction and three extra boundaries, final Koqo6I passed 139/139 in 4.213 seconds.
IGAoZf passed 561/561 Swift regressions in 10.323 seconds; Swift source did not change in the
later Python alias correction. Changed Python syntax and staged ownership/secrets/whitespace
checks passed. Owned macOS PTYs prove absent device bytes and cache/state boundaries. Opaque
native IDs in alias fixtures are synthetic; no physical Ghostty navigation/visibility was tested.

Interfaces remain internal. CLI still needs caller authentication before fork/mutation, safe
isolated-root validation and operation-specific failure classification. In particular, do not
map every ESTALE target failure to stale code 3; native synthetic invalid observation file shape
is stale delivery, while actual storage/deadline failure is unavailable. Existing Python errno
and worker IPC do not yet fully preserve this distinction. Dispatcher/capability/routing, Linux
schema/runtime validation and required physical acceptance remain open.

## Native contract extraction

# Portable caller ancestry and no-output verb contracts

Read-only current-source extraction; no edits, tests, UI/provider/device or goals.
Focus: native side-effect ordering and reuse of the planned shared no-output
callback, not completed render/reset/reconcile or broader helper routing.

## Caller ancestry

managed-output-entry.swift:216-240 starts from HELPER getpid(), with one100 ms
phase deadline, seen PID set and at most16 visited processes. Each lookup must
return generation.pid equal to queried PID, positive startSeconds and microseconds
<1M. Check deadline before/after lookup. Before reaching requested PID, reject
parent<=1, parent>Int32.max, repeated PID or missing identity. At requested PID,
require supplied device if nonnil, then lookup again and require exact generation
AND same device, still before deadline. Return that generation. No foreground
group, provider executable or same-TTY requirement for intervening ancestors.

Register/current supply current node device. Caller must be positive Int32 and
must actually occur in helper ancestry. This is unrelated to continuing_owner,
which walks from seed toward oldest TTY owner. Target selection then separately
resolves continuing_owner and current aliases. Run caller proof before mutation;
if inside a writer callback pass its deadline without renewal. If run before
fork, retain helper PID semantics; starting a supervised child adds an ancestry
hop and changes the exact16-hop bound. Native ancestry and writer have separate
100 ms phases, not one combined native entry wall-clock100 ms promise.

## Exact after-open order

All three use normal managed admission, actual TTY open, shared output lock and
current target/descriptor validation before preparing. No before-open publication.

| Verb | Native after-open actions, in order |
| --- | --- |
| checkSynthetic/check_context | require valid target+descriptor; require intent tty/device equal target; validate synthetic typed context, latest observation and live producer; return nil. |
| register | require valid target+descriptor; cacheTargetUnlocked; equivalentBindingsUnlocked; return nil. |
| current/currentRestriction | require valid target+descriptor; cacheTargetUnlocked; read all three effect slots across equivalent bindings; read current global policy; if nil return nil. |

This ordering is visual-recovery.swift:213-238,316-317. `nil` returns false; CLI
success is code0/unaffected newline. An actual open/flock/validation failure is
still failure even though no bytes were requested. No write-success callback or
metadata cancellation is required for these no-paint returns.

Register/check never read suspension marker, lock/mute policy or lease liveness.
An unavailable marker, active global rule or healthy preview does not block them.
They must not capture a marker revision or call ordinary_ownership. Current reads
policy, but does not classify/select/expire/renew/cancel leases when policy is nil.
Even active residual global records do not trigger reset or pending invalidation.

Native policy.current treats both suspended AND unavailable marker as disabled,
returns nil immediately, and does not read lock/mute files. Therefore native
current can succeed without paint despite unavailable suspension. Existing
portable Policy.restricted throws for unavailable marker: using it unchanged
introduces an intentional stricter current result, not native equivalence. For
register/check there is no reason to introduce that dependency at all. Active
marker plus lock/mute storage error is different: native current throws.

With a current global rule, native current proceeds to controlled composition,
requires controller and saves/paints native rule. The portable ordinary backend
must explicitly report unavailable and avoid controlled effect mutation/paint.
It should preserve current's earlier target-cache side effect if matching native
ordering; native may already have cached before a later policy error.

## Cache and alias validation boundaries

cacheTargetUnlocked (terminal-visual-state.swift:223-235) validates shape/current
target, reads target.json, and requires saved.schema==1 and exact target equality.
Valid existing cache is a no-op. Missing cache creates canonical parents and
target.json. Malformed/link/wrong saved target is not repairable. Native cache
can persist before later equivalent-binding or policy failure.

equivalentBindingsUnlocked scans only current TTY-owner lifetime, skips hidden,
rejects links/storage/placement errors, reads target.json ONLY, validates current
physical identity and at most one live native alias. Unavailable alias fails;
vanished alias is ignored. Register does not inspect effect/bound-intent contents.

Current then reads effect.json, preview.json, focus.json for each alias. Strict
schema, exact record.target and matching slot required, even canceled records.
Lease controller liveness/age is irrelevant at this no-rule branch. It does not
read bound-intent.json or latest intent. Missing slots are harmless.

Planned Store._current default scans/validates bound intents and every effect:
do not reuse it unchanged for register/check. Use targets_only=True for alias
proof, then current alone gets its needed strict effect reads. Store's per-TTY
all-owner fail-closed scan is already stronger than native lifetime filtering;
retain that documented safety boundary, without adding policy/lease dependence.

## Synthetic check reuse

Native validateSyntheticUnlocked requires valid finite typed intent/intakeAt,
intakeAt>0<=updatedAt; latest observation exists/valid and matches tty/device/
producer/delivery, observedAt<=intakeAt, then live producer generation+device.
Missing/invalid observation -> staleDelivery; storage/deadline errors remain
unavailable. No observation repair, no latest ordinary intent read, no publish,
no target cache, no bound copy, no pending deletion and no policy/effect read.

Intents.validate_context_unlocked(synthetic=True) is a suitable strict reuse with
ephemeral background=reset and updatedAt=now. Its _require_producer also proves
continuing owner/current target, a conservative extra validation. Do not call
publish_unlocked or ordinary_background_unlocked. CLI check_context checks current
producer/device before target selection and needs no helper-caller ancestry:
it is explicitly synthetic (managed-output-entry.swift:75-84,109).

One failure-class difference needs preservation or explicit disposition: native
validateSynthetic converts invalidRecord (including nonregular/oversized
observation) to staleDelivery. Current Intents._observation converts decode
ValueError to ESTALE, but propagates OSError EINVAL/EFBIG from file validation.
A generic future CLI error mapping would return unavailable1 for those cases,
where native returns stale3. Actual storage/permission/deadline failures should
remain unavailable. No repair or extra filesystem read is required.

## Targeted tests

- Caller unrelated/cycle/17-hop/missing identity, target lookup generation/device
  change between two reads and deadline expiry after lookup: no mutation.
- Register/check succeed no paint with unavailable marker and healthy live preview;
  malformed effect/bound data do not become policy/lease admission dependencies.
- Register refuses malformed target/ambiguous alias; existing cache not rewritten.
- Check valid observation succeeds without any target/intent cache; missing,
  malformed, superseded delivery or newer observation fails without repair;
  live producer under continuing shell works (native tests1546-1574).
- Current/no-rule validates effect slot corruption before returning, but preserves
  active/expired/global effects, pending output and ordinary intent with no paint.
- Current/unavailable marker result is explicitly chosen/documented relative to
  native disabled success; active global rule reports portable unavailable with
  no effect or marker changes. Do not conflate lock/mute IO errors with no rule.

No new architecture, capability advertisement, routing or Linux schema claim is
needed to implement these bounded interfaces.

## Draft and correction source check

# Portable no-output source check

Read-only review of current caller_ancestor, renderer register/current/check_context
and shared callback, Policy.restricted change and added ancestry/no-output tests.
No tests/import execution, edits to project, UI/provider/device or goal calls.

## Concrete finding

P2: portable_renderer.py:38-44 uses targets_only=True for target selection and
alias proof, so valid effect-only native aliases disappear. Native
VisualRecovery.target (visual-recovery.swift:498-513) selects from cached.bindings
PLUS cached.effects.map(target), then rejects multiple current native aliases.

Counterexample: same valid physical TTY/owner, two live native application/surface
bindings stored only in valid canonically placed effect/preview records, with no
target.json for either. Native target() rejects ambiguity before caching/open.
Portable register/current/check resolve a plain binding and can succeed; register
and current cache plain. With one effect-only native alias, native prefers it and
caches it before current effect validation; portable selects plain and current
never checks that native slot. This does not immediately paint unsafe bytes, but
it returns/cache-identifies the wrong target and weakens established alias proof.

Smallest required boundary: preserve valid effect-only alias hints during target
selection without making malformed regular effect/bound data a dependency of
register/check. Merely switching to full strict cached() would regress those
data-only contracts. A targeted test can write two valid effect-only native records
and assert register/check refusal plus no plain cache; one alias should retain
native preference and current's exact slot validation. Existing tests only use
plain effect-only fixtures, which cannot expose missing native identity.

## Other checked behavior

- caller_ancestor matches16 visited helper-parent processes, final generation/device
  recheck, cycle/parent bounds and one phase deadline. Checks surround every lookup;
  explicit deadline is reused. continuing_owner is correctly not substituted.
  Actual register/current CLI caller authentication is still deferred; Renderer
  methods accept a generation and do not invoke caller_ancestor themselves.
- Shared writer opens/locks/revalidates descriptor and runs one original100 ms
  transaction. Register/check do not read marker, rules or lease liveness, and
  malformed regular effect/bound content is ignored. No frozen policy revision
  is introduced for these data-only verbs.
- Check validates strict observation/current producer before any target cache or
  intent publication; no repair/cancel/heartbeat/pending mutation is introduced.
- Register/current only create a missing validated canonical target cache. Saved
  target is strictly decoded, compared by _binding (all allowed native schema1
  identity components), and not rewritten when equal. After caching, alias proof
  is repeated. Alias prevalidation before cache is conservative relative to native
  cache-before-equivalent failure ordering, not another unsafe output defect.
- Current reads exact three slots for its discovered aliases, requires exact
  binding/kind, and ignores ordinary bound data. No-rule preserves active/expired
  effects and pending output. Rule present is EBUSY without controlled mutation.
- unavailable_disabled=True only suppresses suspension read errors in current;
  timeout and active-marker lock/mute IO errors still propagate. Default False
  keeps ordinary/reconcile policy behavior. Disabled current produces no bytes
  and does not manufacture a marker or native rule record.

## Scope and verification

No further concrete defect found in inspected branches. Tests were read, not run.
CLI stale-versus-storage classification, helper dispatch/capability/routing and
Linux context/record versioning remain deferred. The new no-output interfaces
do not establish those contracts or full H1 completion. No new process framework
or broader machinery is needed to address the missing-alias boundary.

## Correction check

The current identity_hints correction resolves the reported alias gap. Parent
reports ZUN61m reproduced two failures and j94ivS passed15 cases; I did not run
or independently verify those results.

Valid effect/preview/focus records now contribute canonical target hints during
no-output selection and repeated alias proof. Shape, correct effect slot and
canonical path are checked before hint admission; current owner/app/device status,
competing physical owner and native ambiguity checks still apply. Bound data is
excluded. Thus one effect-only native alias is preferred and two are rejected.

Malformed regular effect JSON or EINVAL/EFBIG regular-data failures are ignored
only in the internal hint mode. Timeout, IO/permission/storage, symlink/nonregular,
ancestor/path and correctly decoded misplacement errors are not swallowed. Each
ignored decode/data error checks the original deadline. Reads remain relative to
held parent descriptors, and ancestor identities are checked before returning.

This is NOT lease admission: hint mode is enabled only in _no_output's resolve/
_current calls. Current still strictly rereads all discovered aliases' slots before
policy evaluation. Actual ordinary/reconcile output ownership uses _current with
default identity_hints=False, so malformed active/canceled records cannot authorize
paint or bypass leases. No-output hint caching does not change that strict guard.

No concrete introduced bypass/regression found in this narrow correction.
The original finding is retained above as history, now source-verified resolved.
Deferred CLI stale/storage classification and Linux/schema/routing scope remain.
