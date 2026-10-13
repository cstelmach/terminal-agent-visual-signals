# Portable ordinary ownership source checks

Last Updated: 2026-10-13 (Europe/Vienna)
Version: 1.0

## Parent verification after review

The retained reports describe their inspected stages. The absolute-parent read gap is fixed
by 8b9ef37, with a held-reader red fuvBJv and a later transient-copy ownership regression
first passing WLsay1. That later regression was not reported as a historical red reproduction.
The conservative native-app status-order difference was then reproduced by wJ9cRD and fixed
in b971720: proven native-app exit is checked before unavailable owner/device metadata.
The parent compared the correction with native validateTarget and reran the full portable set:
HHJ0b8, 47/47 in 1.465 seconds. Full Swift pEvu07: 561/561 in 10.461 seconds.
Shared-lock use remains a caller precondition. Publication, obsolete-record cancellation,
legacy restoration and backend routing remain open. No complete H1 or native/Linux acceptance
is claimed. These source reports are preserved here because temporary files are ephemeral;
the existing compatibility report is already close to its workflow size limit.

## Native contract source brief

# Ordinary ownership guard: native source rules and primitive gaps

Read-only source extraction. No project edits, apps, devices, goal calls or
fingerprinting. This describes the next guard; it does not claim integration.

## Per-TTY scan and selection

1. Compute the native plain binding from the requested live seed and its continuing
   same-device owner. Validate that owner again; input PID/device alone is insufficient.
2. Scan organizer/targets/K(tty), ALL owner-generation branches. K is URL-safe UTF-8
   base64 without padding. lstat targets root and TTY root as actual directories.
   Missing ENOENT root means empty; other failure/non-directory/symlink is unreadable.
3. Traverse nonhidden entries without following symlinks. Every lstat failure/link
   is unreadable, regardless of its filename. Do not invoke skipDescendants on a
   yielded link; Foundation's enumeration already does not follow it.
4. Parse target.json, effect.json, preview.json, focus.json and bound-intent.json.
   Check schema/type/value AND exact canonical path. Effects supply candidate
   bindings even WITHOUT target.json. A bound intent requires its sibling valid
   matching target.json and valid intent; its filename alone supplies no binding.
5. Native target()/cachedTarget() unions targets plus effect.target, deduplicates,
   filters exact TTY and validateTarget==valid. All selected candidates must have
   one physicalTarget (tty/device/owner, nativeSurface=nil). Two live physical
   owner generations on one TTY reject. Plain+one native prefers native; two live
   native IDs reject. A scoped allowedSurfaces set is checked AFTER ambiguity;
   do not discard an out-of-scope conflicting live alias to make selection pass.
6. target() can return newly captured plain when cache is empty and unscoped.
   cachedTarget() cannot invent one. Scoped target() may use a fresh native
   snapshot only when no cached native exists, with exactly one allowed mapping.
   The portable ordinary route must not fake that native discovery.

Sources: recovery:497-543; state:139-144,414-483,534-550.

Native pre-lock resolution ignores unreadable paths and unavailable/vanished
candidates. That is not a proof that no control exists. For portable ordinary
permission, unexplained same-TTY unreadable data or potentially-live unknown
binding must not silently disappear from the ownership decision.

## Held-lock checks and canonical placement

- Revalidate actual descriptor/device and current owner, then re-read aliases
  under the SAME stable per-TTY output lock and original deadline. No cached
  pre-open ownership decision authorizes write by itself.
- Alias enumeration is now LIMITED to the chosen physical owner lifetime:
  organizer/targets/K(tty)/G(owner), where G=pid-seconds-microseconds.
  Missing lifetime root returns supplied target; a bad root/entry/read rejects.
- Every target.json must contain schema1 target with that exact physical lifetime
  and be located at G(owner)/plain/target.json or
  G(owner)/G(application)/K(terminalID)/target.json. Validate all records before
  considering liveness. Unavailable alias fails; proven vanished can be excluded;
  valid native alias count must remain<=1.
- Read effect.json/preview.json/focus.json for every surviving alias. Each record
  must match the EXACT alias target and expected filename kind. Decoder/placement
  errors remain errors even for canceled/expired records. Alias plain/native pairs
  are one physical target for output, not two independent writes.

Sources: state:303-344,currentEffectUnlocked:237-248; recovery:effectsUnlocked.

## Unknown, vanished and control classification

| Evidence | Native classification / portable requirement |
|---|---|
| Shape invalid | unavailable; never proof of no owner |
| Existing owner with different generation | vanished old binding; cannot reset using it |
| Owner inspect unavailable + kill(pid,0) ESRCH | proven vanished |
| Inspect unavailable + live/EPERM/unsupported evidence | unavailable, not dead |
| Valid char node rdev differs | vanished old binding |
| Node absent ENOENT/ENXIO | proven vanished |
| Wrong node type/link/permission error | unavailable, not proven absent |
| Native app generation differs / ESRCH | vanished alias |
| Native app identity unavailable but not ESRCH | unavailable alias |
| Owner's current device or actual descriptor differs | unavailable |
| Canceled valid effect | not active; retain/validate record |
| Valid selective controller generation matches, age<2 preview or<=6 others | live lease |
| Controller generation provably changed, known dead, or expired heartbeat | no current selective ownership |
| Controller inspect unavailable while fresh | native lease helper returns false; portable proof must reject uncertainty |
| globalRestriction record | never a selective lease; current lock/mute policy independently determines control |

Native validateTarget's ordering checks generation reuse/proven loss before other
metadata. Keep this distinction when a healthy new target shares a reused TTY:
old vanished records must not grant reset authority or permanently block the new
verified ordinary lifetime. Re-read identity immediately before publication/write.
Sources: state:151-174,214-221,knownDeviceMissing/knownProcessMissing:584-592.

A current revision-matching explicit preview may remain while suspended. Focus/
selectiveBackground do not. Matching selected aliases must agree on owner effect
ID/controller/revision/recipe; focus uses normalized colors rather than equality
of old computed backgrounds. Current global rule or selected live native lease
requires native composition or explicit rejection, not a guessed cached-color paint.
Valid residual active global records with no current global rule need legacy
foreground/palette cleanup, distinct from live ownership. Canceled global records
alone do not require that prefix in ordinary rendering; explicit reconcile can.

## Non-obvious gaps in current portable primitives

- inspect() returns None for MANY reasons (missing, zombie/exiting, unavailable
  libproc, permission, immature Linux tick, namespace/scope failure). It supplies
  no dead/unknown distinction. Add a bounded, scope-correct proven-missing check;
  do not use None or portable_policy._pid_alive(false) as proof of death. Do not
  read a stale ctypes errno after a validation-based None result.
- device_number() likewise conflates absence with invalid type/path/permission.
  Keep independent lstat absence evidence. Writer fstat proves node identity,
  not that its process owner/generation or native app is still valid.
- continuing_owner's final check is generation equality, like Swift; typed output
  must additionally compare its current device under the writer lock.
- portable_records.read_record validates contents, but does NOT compare location
  with target_path or inspect ancestor directories. target_path builds names only.
  open_regular O_NOFOLLOW protects the FINAL component, not symlinked ancestors.
  The ownership scan must perform the directory/path checks above.
- Effect-only aliases must participate in the broad conflict scan before narrowing;
  iterating just target.json or just the seed owner's branch weakens native rejection.
- Linux inspect emits linuxScope and boot-relative birth-tick fields; native schema1
  decoder/path builder correctly rejects that extra scope. Do not strip linuxScope
  to make equality/path building pass. Explicitly version Linux records, retain
  scope in physical equality, and do not interpret a foreign-scope PID's local
  ESRCH as proof that the recorded process died. Linux acceptance remains separate.
- Native cached scan has no deadline parameter; portable must keep its bounded
  traversal and decoding inside the existing writer budget, with no fresh budget
  per alias. Safe primitive I/O alone does not supply the missing ownership guard.

## Implementation source review

# Portable ownership source check

Read-only inspection of portable_ownership.py, its tests and connected record/I/O
primitives. No tests, devices/apps, goal calls, edits to project files or fingerprints.

## Finding and current disposition

The initial traversal pinned directory descriptors but yielded absolute record
paths, which read_record then reopened through unpinned ancestors. A transient
swap to an inactive foreign copy and restoration before final inode comparison
could evade that final comparison. This was a concrete ABA path-proof gap.

Latest source is SOURCE-VERIFIED FIXED: _walk yields path plus held parent_fd;
cached opens both each record and bound-intent's sibling target.json relative to
that descriptor; read_regular/open_regular propagate dir_fd and O_NOFOLLOW with
lstat/fstat inode checks. Absolute paths are now only canonical-name comparisons.
Ancestor path identities remain checked before the scan returns. The parent
reports fuvBJv was the held-parent reader red (missing dir_fd). The full transient-copy
ownership regression was added after that support and passed WLsay1 (14 ownership cases).
The parent also reports Dolgpn 46 portable checks and pEvu07 561 Swift checks passing;
I did not run or independently verify those tests.

No remaining concrete unsafe ordinary-admission or expired-success return defect
was found in this bounded source inspection.

## Checks and remaining scope limits

- Scan includes all same-TTY owner branches and effect-only candidates, rejects
  malformed/linked/misplaced data, distinguishes unknown from proven missing,
  and rejects physical/native ambiguity before selecting an alias.
- Fresh unknown selective controller fails; ESRCH/reused controller or expired
  lease can release it. Current native policy blocks ordinary output; suspended
  selective effects and stale revisions are returned as obsolete, not composed.
- Chosen target/device and revision are revalidated at resolve/admission return.
  Lookup, directory, decoding and final admission checks keep the supplied deadline.
- Minor conservative native-order difference: status checks unknown/mismatched owner
  device before native-app disappearance. Native validateTarget checks app generation
  first. Thus a demonstrably vanished native alias can remain unavailable here if
  its owner metadata is unknown, causing refusal rather than unsafe admission.
- Shared output-lock ownership is an explicit caller precondition, not enforced
  by Store itself. This is Mac schema1 only, with no routing/capability or complete
  H1 claim. Returned obsolete records have not been canceled by this guard.

Owned-PTY tests exercise actual Mac process/device primitives when run, but source
inspection alone does not establish device, deadline or Linux acceptance.
