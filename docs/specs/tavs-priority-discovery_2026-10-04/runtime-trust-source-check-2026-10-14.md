# Runtime trust source findings and native correction

Last Updated: 2026-10-14 (Europe/Vienna)
Version: 1.1

The reports below describe their inspected baselines, not the final implementation. The parent
verified findings against source and controlled fixtures. Final outcomes and open scope follow.

# Native runtime-directory trust source exploration

Last Updated: 2026-10-14 (Europe/Vienna)
Version: 1.0
Tracked source: `d11a04a fix: Bound interrupted organizer record reads`.
Workspace: `/Users/cs/local/code/apps/terminal-agent-visual-signals`.
Scope: read-only source inspection and directory-metadata inspection of system path aliases.
No edits to the repository, tests, app/native actions, settings, other-process inspection or web.
This report is the only authored output.

## Recommendation

Add one small shared native POSIX directory-trust helper, and call it at the actual runtime
consumers rather than only in the CLI factory. The existing native code has no such helper.

For an existing runtime root, require a real directory owned by the effective UID, with no
group/other write bits (`mode & 0022 == 0`). Require the same for existing runtime child
directories used as organizer storage, record parents, pending output or registry containers.
Create a missing write root with 0700 only after checking its existing ancestor chain; recheck
ownership/type/mode after creation. Never chmod/chown/adopt an existing untrusted directory.

Use the original optional deadline when a consumer already has one, checking before/after each
metadata operation. Preserve the 100 ms writer deadline, its start before global dispatch, and
its late-worker protection. Do not move trust inspection synchronously ahead of that bounded
worker merely to simplify call sites. Initialization-only trust caching is insufficient.

The minimum complete consumer coverage is:

1. TerminalVisualStateStore storage boundaries, covering publication, coverage, unlocked helpers
   and cached enumeration, including verification before directory creation.
2. VisualRestrictionPolicy's runtime lock-rule read, independent of managed output.
3. VisualRecovery's registry/pending operations and the managed writer path before runtime
   metadata publication or device output.
4. Scheduler's existing runtime lock read/write/watch path if the promised scope includes all
   native policy/projection consumers. Its separate LockStateReader path otherwise remains open.

Strengthen existing leaf-file checks with effective-UID ownership and no group/other write for
policy/typed records. Add effective-UID checking to the existing exact-0600 writer-lock checks.
Directory integrity prevents entry substitution; leaf integrity prevents another UID changing
the bytes of a writable existing file inside an otherwise protected directory.

A CLI-only check or a check solely at TerminalVisualStateStore.withLock is incomplete: GUI
constructors bypass the CLI, cachedRecords bypasses withLock, several unlocked helpers are
called directly, registry/pending use another root member, and policy can be used independently.

## POSIX first principles and what the guard means

- Filesystem operations use effective credentials. Use `geteuid()` for owner trust, not the
  default directory name's `getuid()` as a substitute. The normal unprivileged app has equal
  real/effective UIDs, but the ownership check should express the actual access boundary.
- A directory's write/search permissions govern creating, unlinking and renaming names. A
  0600 file inside a directory writable by another UID does not protect its pathname against
  replacement. The directory owner can change its mode; foreign ownership is therefore a
  trust problem even when a foreign directory currently has 0755 permissions.
- File write permissions independently govern changing existing contents. Protecting the
  parent does not make a 0666 policy/observation file immutable to other users.
- A sticky shared directory such as /private/tmp restricts unlink/rename of entries by other
  users, but allows them to create an unused predictable name first. `/tmp/tavs-<victim uid>`
  is predictable. A preexisting foreign-owned root must be rejected, not trusted because its
  parent is sticky or its name contains the victim UID.
- `lstat(path)` does not follow the final symlink, but follows symlink ancestors during lookup.
  `open(path, O_NOFOLLOW)` likewise addresses the final component, not an arbitrary linked
  ancestor. Both are useful existing protections, neither validates a complete root path.
- `FileManager.createDirectory(..., withIntermediateDirectories: true, attributes:0700)`
  expresses creation mode. Current code does not inspect or repair ownership/modes of existing
  directories. It is not a trust predicate for an existing path.
- Full-path resolvingSymlinksInPath before checking the supplied root loses evidence that the
  root itself was linked. Check the runtime leaf and user/runtime-controlled path components
  before blind full-path resolution. Merely comparing resolved containment is an isolation
  constraint, not ownership/integrity verification.

System aliases inspected in this task:

| Path | Observed object |
|---|---|
| /tmp | root:wheel symlink to private/tmp |
| /private | root:wheel directory 0755 |
| /private/tmp | root:wheel directory 01777 |
| /var | root:wheel symlink to private/var |
| /var/folders | root:wheel directory 0755 through the /var alias |

Blanket ancestor-symlink rejection would reject the legitimate default `/tmp/tavs-UID` and
legitimate injected native temporary paths beginning `/var/folders/...`.

Small ancestor rule: permit ordinary ancestors owned by root or the effective UID and not
writable by group/other; permit trusted-owner sticky shared temporary ancestors, while checking
the actual child root's own UID/mode. Handle root-owned system aliases such as /tmp and /var
by validating the alias is not substitutable through its protected parent, then checking the
resolved directory chain. Do not extend that exception to a runtime leaf symlink or an
organizer/targets/pending/active-ttys symlink.

For non-system symlink ancestors, a deliberate rejection is the smallest conservative rule.
If a real existing supported configuration requires a user-owned alias ancestor, inspect that
configuration before adding an exception. Existing explicit test roots inspected here require
only the macOS system aliases, not arbitrary alias support.

Do not require every ancestor to be owned by the user, private0700, or non-sticky. System
ancestors belong to root and shared temporary ancestors are intentionally writable. Do not
require a literal /tmp/tavs-UID basename: arbitrary injected private roots are already supported.

## Caller and data-flow map at d11a04a

### Direct organizer publication

`organizer-intake.swift:101-118` calls `store().publishObservation` / `publishIntent`.
`store`, lines 137-140, chooses TAVS_RUNTIME_DIR or `/tmp/tavs-\(getuid())`, constructs the store
and performs no runtime trust check. It does not call ManagedOutputEntry.validateRoot.

`TerminalVisualStateStore.init`, `terminal-visual-state.swift:106-119`, appends organizer to the
supplied runtime and saves injected identity/device callbacks. It does not inspect ownership.

Publication at lines609-632 goes through withLock. WithLock,979-1029, creates organizer with
0700 attributes, checks only directory type, opens a no-follow lock and requires regular-file
0600 mode. No directory/lock st_uid check exists. The runtime ancestor is not checked.

Coverage at lines798 onward also uses withLock. Cached-record enumeration at417-441 instead
begins with organizer/targets type checks and FileManager enumeration, without withLock.
Unlocked record/effect/intent helpers also perform reads/writes directly. Target-parent creation
at554-585 checks each encountered component's type, but does not check UID or writable mode.
Read/write helpers at1032-1117 have bounded size/type/final-no-follow and atomic replacement
protections, but no leaf UID/non-writable-mode checks.

### Managed helper and headless recovery

`ManagedOutputEntry.run`, managed-output-entry.swift:43-57, obtains absolute runtime/marker URLs,
calls validateRoot, and for visual recovery saves the restriction marker before constructing
recovery. `makeRecovery`,238-260, uses the supplied runtime for organizer and runtime/lock.state.

`validateRoot`,195-204, returns immediately unless one of the session-test scope keys exists.
Inside a test scope it compares fully resolved marker/runtime paths with a fully resolved
TAVS_SESSIONS_TEST_ROOT under temporary directories. It does not check UID or permissions.

`VisualRecovery.recoverHeadlessly`,74-96, calls the same validateRoot and persists the marker,
then probes and launches the helper with runtime as an argument. Therefore strengthening only
that scoped validation would leave ordinary headless runs unchecked.

### GUI Sessions and focus

`SessionsModel.createDefault`, TAVSApp.swift:188-192, selects TAVS_RUNTIME_DIR/default /tmp root.
`create`,195-220, directly builds TerminalVisualStateStore, VisualRestrictionPolicy,
VisualRecovery and FocusController. No managed entry-point check covers initial GUI creation.

FocusController receives those objects directly (`focus-controller.swift:42-50`) and eventually
performs managed writes through recovery. It has no independent root validation. No separate
focus trust framework is needed if shared storage/recovery/policy boundaries are protected.

IsolatedSessionsLaunch atTAVSApp.swift:135-160 resolves its root, checks temporary containment
and optionally a fixture path. It does not check the root UID/mode. Its model uses a child
runtime under that injected root (line164). Those injected roots must remain valid inputs to
the shared validator, without relying on a TAVS_SESSIONS_TEST_ROOT environment waiver.

### Policy

VisualRestrictionPolicy.current, visual-restriction-policy.swift:27-50, checks the original
deadline, reads the restriction marker, then runtime lock.state, optionally the home mute rule.
If restrictions are disabled it returns nil before reading the lock rule. `readRule`,100-136,
checks file type/size, final no-follow and opened inode/device correlation. It does not check
root/ancestor trust or leaf UID/group/other-write permissions.

A runtime lock file from an untrusted directory can therefore be accepted as policy at the
source level, subject to valid contents. A guard only in the ordinary publication store cannot
cover this independent consumer. Reject an untrusted configured runtime at the policy boundary
with unavailable; do not translate it into absent/nil lock content and thus unlocked policy.
An absent trusted runtime has no lock rule and may retain existing nil behavior.

### Recovery cache, registry and pending output

VisualRecovery.apply,439-485, starts native discovery, reads state.cachedRecords, fans out cached
and native targets, and then calls registryHints. Individual write/render calls enter
performWrite and SystemProcessRunner's existing100ms worker. Preparing each target invokes
cacheTargetUnlocked, so runtime state is involved even for fresh native targets.

RegistryHints,633-657, lstats runtime/active-ttys, lists entries, validates concrete TTY-shaped
names and regular-file leaves. It checks no UID/write modes. Registry names become hints and
failed/vanished diagnostics; registry membership alone does not authorize a paint. A planted
entry is not sufficient evidence that arbitrary device output is possible.

InvalidatePending,614-631, checks runtime/pending type and target .osc regular-file type, then
unlinks that path with deadline checks. Neither root/container nor leaf ownership is checked.
Protecting only organizer storage does not cover pending-file invalidation or registry reads.

### Scheduler projection: separate consumer requiring explicit scope

Scheduler.createDefault atTAVSApp.swift:278-301 passes runtime/lock.state separately to Scheduler,
in addition to recovery's policy object. Scheduler has injected lock URLs and may derive its
lockURL from muteURL's parent when no explicit URL is passed (Scheduler.swift:233-234).

LockStateReader.read, LockState.swift:58-60, uses String(contentsOf:) and has no no-follow/type,
UID or runtime trust guard. LockStateWriter.write,49-52, atomically writes the supplied URL.
Scheduler reads this rule in lockNow, grantUnlock, finishEvaluation and watcher callbacks;
startRuntimeWatch creates/watches the parent atScheduler.swift:542-558. Its writer at579-615
checks the existing leaf's usable regular-file shape, creates the parent with0700 attributes
and invokes LockStateWriter, without parent trust or UID checking.

A policy-only repair leaves those reads/writes/watchers using the same untrusted root. For
complete native runtime coverage, reuse the shared helper at these boundaries too. Existing
projectionSaved gating (Scheduler.swift:419-450) already prevents broadcasting a projection
that failed to persist; make the trust failure flow through that existing failure behavior.
Do not silently present an untrusted record as an absent lock for scheduling decisions.

## Existing compatibility constraints

- TerminalVisualStateTests setup, terminal-visual-state-tests.swift:60-68, constructs a unique
  root URL but does not create it. First publication creates it. Rejecting all missing roots
  at init would break a deliberate supported write path.
- VisualRecoveryTests setup at400-410 and ManagedOutputEntryTests setup at20-26 create private
  nested directories with FileManager but do not force every directory to0700. Accepting only
  exact0700 or `mode&0077==0` is stricter than the required cross-user write boundary and can
  reject ordinary0755 directories inside private roots. Use `mode&0022==0`, plus owner checks.
- Test read paths already return empty cache/nil observations when trusted paths are absent.
  Keep absence separate from an existing wrong-owner/writable/linked object.
- VisualRestrictionsStateStore normally resides under the user's home marker parent, not the
  runtime. A runtime guard should not accidentally demand the marker be a child of runtime.
  Keep existing test-scope containment checks, and validate marker-parent trust separately only
  if that broader home-state scope is part of the chosen correction.
- The shell `_tavs_resolve_runtime_dir`, mute-gate.sh:20-29, creates runtime0700 when absent,
  but accepts an existing directory and creates active-ttys/pending inside it. Native rejection
  of an existing untrusted root is compatible with safe fresh creation; it is not a repair of
  this separate shell acceptance gap.
- Portable helper `_roots`, portable_helper.py:38-49, verifies ownership/private mode only of
  TAVS_TEST_ROOT when that environment variable is present. It is not a general production
  runtime-root trust validator. Portable descriptor-relative record-directory operations
  protect traversal/inode identity but do not establish user ownership by themselves.

## Guard placement with the smallest useful process

Recommended implementation shape: one shared helper, no new root registry, binding object,
manifest, lock layer or trust cache. The helper inspects POSIX objects and can create only
missing required directories. Return a small absent/trusted result or throw existing unavailable
errors through each consumer's established error path. Supply existing deadline where present.

Storage: check root before withLock/prepareTargetDirectory attempts to create descendants;
protect shared read/write helpers so direct unlocked callers do not bypass the check; check
cachedRecords before enumeration. Validate the descendant directory chain used by the current
operation, not merely runtime leaf plus organizer. Reject symlink/writable/foreign-owned targets,
TTY key directories and per-binding directories before using them.

Recovery: require runtime trust before apply consumes registry/cache and before managed callbacks
publish or prepare output. For device paths, perform the check inside the existing bounded
worker using its original deadline. Check active-ttys and pending containers at their own access
methods. The same helper can serve explicit targets, headless calls and GUI creation.

Policy: validate the runtime parent of lockURL before accepting lock-rule bytes; existing
readRule leaf checks should check owned/non-writable file before and after open alongside the
existing inode/device check. Do not assume that policy always sits behind recovery.

Scheduler: reuse the helper with its lockURL parent for actual read/write/watch operations;
retain support for an injected adjacent-to-mute parent. Do not specialize it to one basename.

ManagedOutputEntry.validateRoot may call the shared helper unconditionally as an early failure
boundary, but that call supplements rather than replaces the actual consumer checks. In
recoverHeadlessly/recover, saving the user's trusted restriction marker before a subsequent
runtime failure remains useful safe suspension; whether an early runtime failure prevents
marker persistence should retain the existing recovery contract and be decided explicitly.
There is no need to rewrite all nonthrowing constructors to make trust initialization mandatory.

Runtime trust applies to existing mutable filesystem objects at use, so no init-only Boolean
is a sufficient solution. However, do not walk the entire ancestry for every small read unless
needed. An operation can inspect the root/parent chain once immediately before its existing
critical section, with focused child/leaf checks during accesses. Any attempt to reuse a trusted
path across later operations must revalidate it; caching is not a reason to trust mutation.

## Source gaps versus exploitation and remaining TOCTOU

Confirmed source gaps: no native st_uid checks; no directory/record group-other-write checks;
no general production root check; final O_NOFOLLOW does not protect ancestors; path-scoped test
checks do not cover unscoped constructors/direct consumers.

Cross-user exploitation was not reproduced. The independent review's scenario about another
account planting records relies on additional conditions: access to create the path, ability to
produce matching current device/process/controller bindings, readable record permissions and
consumer behavior. This task did not inspect another user's process visibility and cannot
confirm that macOS proc_pidinfo exposes all required generations to that account. Registry
spoofing alone remains an unverified hint, not an authorized paint.

A predictable-root preclaim can cause an unavailable runtime; a correct fail-closed guard does
not restore availability when another account owns the configured name. Do not delete/chown
that account's object automatically or select another runtime fallback silently.

A path-based lstat/open guard has check/use races. If an untrusted user can rename an ancestor
between checks, leaf no-follow/inode matching does not fully anchor the path. Ancestor-owner and
write/sticky checks remove ordinary foreign-UID substitution opportunities for protected paths;
they do not create a universal race-proof guarantee. Root and same-UID actors are outside this
cross-user trust boundary and can still rename/chmod their paths. Descriptor-relative traversal
(openat/mkdirat/renameat with held verified directory descriptors) would provide stronger binding,
but would be a larger filesystem-I/O refactor. Do not claim the small guard implements it.

POSIX UID/mode checks also do not inspect macOS ACL write grants. If hostile ACLs are part of the
required threat model, that needs a targeted ACL check or permission-backed verification. No ACL
change is proposed, and no claim of full ACL security should accompany a mode-only correction.
Root ownership/write checks do not authenticate records intentionally written by the same UID.

## Suggested bounded verification, not executed

Reuse existing private-root tests rather than introduce an injected filesystem or control plane:

- existing owned0755 root under a private temporary parent succeeds;
- missing write root is created0700; missing read root is empty; default /tmp and native /var
  temporary aliases are accepted;
- linked runtime leaf, linked runtime child, group/other-writable root or child are rejected;
- a foreign-owned directory or lock metadata is rejected. Test the ownership predicate with
  synthetic stat fields, or an authorized foreign-UID fixture if available; do not chown live paths;
- direct organizer publication, independent policy, cache/registry recovery and selected output
  paths all reject the same unsafe root before effects;
- malformed root under original100ms callback retains deadline failure behavior, with no reset.

These would establish the stated POSIX guard and caller coverage, not a cross-user exploit or a
race-proof/ACL-complete root system. No tests were executed during this investigation.

## Capture and memory

Repository edits were explicitly excluded, so no META-THINKING-CAPTURE entry was appended by
this subagent. Parent can capture the combined session. The investigation traced each actual
consumer before choosing guard locations and distinguished mode/UID correctness from exploitation.

Memory supplied macOS /tmp-alias context, then current directory metadata confirmed it locally.
Registry citation: MEMORY.md:945; historical rollout id01a0fe2d-3cc9-7d10-9eaf-d0ac87048005.


---

# Portable runtime-directory trust exploration

Last Updated: 2026-10-14
Version: 1

Checkout: `/Users/cs/local/code/apps/terminal-agent-visual-signals`, clean HEAD `d11a04a`.
Scope: source and test inspection only. No tests, apps, native actions, private runtime contents,
or process changes were performed. The only created file is this requested report.

## Conclusion

Production portable requests accept absolute runtime paths without checking the runtime directory's
UID, writable mode bits, or final symlink. Existing record and lock checks protect particular
objects, but do not establish trust in the root that names those objects. Connected shell callers
also read or write runtime paths before portable helper validation.

The smallest useful rule is: the actual runtime root must be a directory owned by the effective
UID, with no group or other write bits (`mode & 0o022 == 0`), and its final component must not be a
symlink. Create a missing runtime root explicitly with mode `0700`. Reject an existing unsafe
root; do not chmod or adopt it. Existing UID-owned `0755` roots remain compatible with this
integrity rule. This is distinct from a confidentiality requirement that would demand `0700` for
all existing roots.

Place checks inside the existing managed device worker and its original deadline, before the
first runtime read, mkdir, lock open, or publication. Preserve ordinary injected private roots
and macOS system aliases such as `/tmp` and `/var`; rejecting every ancestor symlink would break
normal macOS paths. Shell active-TTY registration and legacy `TAVS_TMP_DIR` need separate scope.
A single helper-entry check cannot cover those preceding shell accesses.

## 1. Trust principles, grounded in the code

1. Directory write permission controls entry creation, removal, and replacement. A private lock
   file's `0600` mode does not make its parent trustworthy. The current writer verifies exactly
   that leaf file mode and effective UID, but only directory type for its parent:
   `src/core/portable_device_writer.py:36-49`.
2. `mkdir(mode=0700, parents=True, exist_ok=True)` does not validate a pre-existing directory.
   The leaf gets the supplied creation mode; automatically created intermediate parents use
   ordinary mkdir permissions. `output_lock` is asked to create `runtime/organizer`, so a missing
   intermediate runtime need not receive `0700`:
   `src/core/portable_device_writer.py:38-43`;
   `src/core/portable_record_io.py:27-29`.
3. A final-component no-follow check does not reject symlinks in ancestors. The code opens the
   complete path `runtime/organizer` with `O_NOFOLLOW`, which applies to `organizer`; a symlink at
   `runtime` remains an ancestor. Policy opens likewise operate on `runtime/lock.state`:
   `src/core/portable_ownership.py:47-64`;
   `src/core/portable_policy.py:20-36,197`.
4. UID ownership and absence of group/other write permissions are separate from object type and
   identity. `_open_directory` verifies directory type, no-follow behavior, and matching
   `(st_dev, st_ino)`, but never UID or mode permissions:
   `src/core/portable_ownership.py:47-74`.
5. Open directory descriptors and relative operations protect the selected directory during a
   transaction. They do not establish who may modify that directory. The record layer holds
   descriptors, checks directory identity before and after, and replaces relative to the held
   parent:
   `src/core/portable_record_io.py:30-60,96-122`.
6. A root-owned sticky temporary parent permits multiple users to create separate entries;
   stickiness does not make an attacker-precreated `tavs-UID` entry trustworthy. A rule that
   rejects all writable ancestors would incorrectly reject `/tmp`. A rule that ignores every
   ancestor can miss replacement through a nonsticky writable parent. Parent and alias policy
   must therefore be explicit, without making a complete adversarial TOCTOU claim.
7. The compatibility rule `euid + no 0o022` addresses POSIX mode-based integrity. It does not by
   itself prove absence of writable ACL grants, hard-link exposure, or all ancestor races.
   Those threat scenarios remain unknown in this exploration.

## 2. Portable path and object checks

| Boundary | Current behavior | Source-verified gap |
|---|---|---|
| Helper roots | `_path` bounds text and requires an absolute path. `_roots` checks a resolved private temporary test root only when `TAVS_TEST_ROOT` exists. | With no test root, there is no production runtime UID/mode/final-link validation. Test-root containment is not production root trust. |
| Cached organizer directories | `_open_directory` and `_walk` reject checked final symlinks, hold FDs, and check identities. `Store.cached` starts at `runtime/organizer`. | The runtime ancestor is not checked, and checked directories have no UID/mode check. |
| Record reads | `read_record` uses bounded regular-file reading, no-follow, and typed JSON validation. | Regular-file reads do not check UID or writable permissions. |
| Record writes | Absolute lexical confinement; reject dot-dot path components; hold parent FDs; private exclusive temporary; atomic replacement. | Runtime root creation/trust is not distinct from organizer-root creation. Existing directories and regular destination files have no UID/mode trust check. |
| Output locks | Require regular opened lock, effective UID, exact `0600`, nonblocking flock, original deadline. | Parent is only checked for directory type, and open uses the whole path instead of a held trusted parent FD. A writable directory can change which lock inode cooperating writers reach. |
| Runtime policy | `lock.state` is bounded data, never sourced as code. | A valid regular file under an untrusted root may still govern output; file UID/mode and ancestor trust are absent. |
| Suspension/mute policy | Marker has strict bytes, bounded reads, pinned inode revision; mute is bounded parsed data. | These paths are under HOME and are a separate trust boundary. Runtime-root validation does not establish HOME parent or policy-file ownership. |

Precise references:

- `src/core/portable_helper.py:30-49,95-110`.
- `src/core/portable_ownership.py:47-97,100-107,156-219`.
- `src/core/portable_record_io.py:17-60,71-85,88-130`.
- `src/core/portable_records.py` delegates file reads to `portable_policy.read_regular`.
- `src/core/portable_policy.py:20-66,137-212`.
- `src/core/portable_device_writer.py:35-60`.

## 3. Runtime use and output ordering

### Managed portable output

`write_managed` starts its 100 ms absolute deadline before creating the pipe/fork. The child runs
`_perform`; the parent waits only for the time remaining and then requests child termination.
The child does not retain hook stdin/result channels.

`_perform` ordering is:

1. Execute `before_open(deadline)`.
2. Inspect and open the concrete TTY, then verify the opened character-device identity.
3. Acquire the shared output lock.
4. Prepare policy and typed state under that lock.
5. Check the same deadline, write bytes, and complete effect records only afterward.

References: `src/core/portable_device_writer.py:63-109,112-172`.

Renderer callbacks already run inside this worker:

- Register/current/check use `before_open` to acquire the lock and resolve current ownership:
  `src/core/portable_renderer.py:40-78`.
- Reconcile acquires the lock and resolves the cached target before opening the device; policy is
  captured during preparation afterward:
  `src/core/portable_renderer.py:90-133`.
- Render/background/forced reset capture policy as appropriate, acquire the lock, resolve target,
  and may publish intent before the device opens:
  `src/core/portable_renderer.py:165-218`.

Therefore root validation belongs at the beginning of those existing worker callbacks, before
`output_lock` or any runtime-backed resolution/publication. Putting blocking filesystem trust
checks only in helper `_roots`, or in `Store.__init__`, places them outside `write_managed` and can
regress its caller bound. `_roots` is invoked at helper lines 95-110; renderer construction and
calls occur at lines 115-153.

Observation and unbound intent are data-only operations. They start their own 100 ms deadline,
then acquire an output lock and read/write typed records:
`src/core/portable_observation.py:13-30`;
`src/core/portable_intent.py:154-184`.
These deadlines are cooperative checks; unlike managed device output they do not have the outer
fork/poll enforcement. Do not claim the entire helper invocation is already capped at 100 ms:
context work and finite render input have additional stages, and input itself has its own timeout.

## 4. Connected shell paths

### `TAVS_RUNTIME_DIR`

- `mute-gate.sh:20-30` chooses `/tmp/tavs-$(id -u)` or the injected runtime; it skips root creation
  for anything satisfying `-d`, including a directory symlink, and creates pending/active dirs
  without trust checks.
- `mute-gate.sh:49-79` reads runtime `lock.state` with shell regular-file tests and ordinary
  redirection. This follows symlinks and does not impose a bounded file size.
- `mute-gate.sh:143-147` touches the active-TTY candidate entry after calling the resolver; it
  does not stop if that resolver fails. `:174-177` resolves, reads mute/lock, and registers.
- `trigger.sh:46-67` loads helpers and invokes mute initialization before organizer begin at
  `:101-106`. Portable validation alone cannot protect the earlier shell reads/writes.
- `tavs-shellrc.sh:98-112` creates runtime/active directories and truncates the current active-TTY
  entry before selecting the helper and requesting managed registration. A linked leaf entry or
  linked active-TTY directory can therefore be followed before any helper check.
- `lock-state-lib.sh:21-50,71-88` directly derives the root, reads policy, and publishes a temporary
  lock state with mkdir/mktemp/mv. It is another caller of the runtime trust rule.
- Long-running shell mute checks are reached by `idle-worker-background.sh:111-112`; root trust
  must not be a permanent success flag that outlives directory replacement.

Small shell hardening scope: validate/resolve the actual runtime before shell runtime policy or
registry access, propagate resolver failure before subsequent I/O, and check the accessed
active-TTY directory/leaf without blindly following links. Installed shellrc needs the same rule
before its line 104 write. A portable-only change must explicitly report these as remaining scope.

### Separate `TAVS_TMP_DIR` identity/state root

`session-state.sh:16-28` uses `${TAVS_TMP_DIR:-/tmp/tavs}`, initializes it at source time, and only
creates/chmods when `-d` is false. It is distinct from `/tmp/tavs-UID` runtime storage.

`identity-registry.sh:50-75` uses that root's `identity` directory for ephemeral mode, or spinner
cache for persistent mode. Existing directories have no trust validation. Reads use shell `-f`
and redirection; counter/registry updates use mkdir-based locks and temporary replacement:
`:86-118,130-175,188-248`. Stale-lock recovery reads `lock_dir/pid` and may recursively remove
`lock_dir`; comments claiming TOCTOU-safe locking are not a demonstrated trust guarantee.

Do not silently migrate identity/state roots as part of a portable runtime fix. Report and scope
this legacy storage separately; a `TAVS_RUNTIME_DIR` guard does not cover it.

## 5. Smallest guard recommendation

Use existing modules and transaction boundaries rather than a new validator process per access.
An existing Python module can hold the shared root check, avoiding a new copied resource.

1. Preserve lexical absolute-path validation. On first actual runtime I/O, open/validate the
   actual root: final component is a real directory, effective UID matches, `st_mode & 0o022` is
   zero, and lstat/open/fstat directory identity agrees. Missing creation uses an explicit `0700`
   mkdir for the runtime itself before creating organizer. Do not repair unsafe existing roots.
2. Perform that check in managed `before_open` callbacks under their original worker deadline;
   perform it before the lock/publication in observation and unbound intent under their original
   deadline. Reuse existing deadline checks; do not start a fresh deadline for the validator.
3. Preserve trusted system alias ancestors. On macOS `/tmp` and `/var` can be system aliases into
   `/private`; canonicalize/handle trusted parent aliases while continuing to reject a symlink at
   the runtime root itself. Checking all ancestors with blanket `O_NOFOLLOW` breaks normal paths.
   Check the canonical parent's trust where arbitrary injected ancestors are accepted. Accept
   private injected roots under `/tmp`, Darwin per-user temp paths, and ordinary user-owned paths.
4. Reuse the existing held-directory mechanism for organizer and consumed record directories,
   adding UID/no-group-or-other-write checks at each accessed directory rather than recursively
   scanning the whole tree. Root-only protection cannot establish integrity of previously
   writable children beneath a traversable `0755` root. If records/policy files themselves are
   group/other writable or foreign-owned, leaf trust also needs rejection at bounded read time.
5. Keep scope honest: these checks close static untrusted-root acceptance. They do not by
   themselves prove all cross-user races, ACL cases, writable-ancestor replacement, or shell
   redirection races are covered. Full held-root FD routing through all policy/lock reads is a
   larger follow-on if that threat model is requested.

No new runtime manifest, hashing, or control-plane mechanism is necessary.

## 6. Copied-install delivery

The finite list in `src/cli/cmd-install-shell-integration.sh:20-30` copies one shell selector and
13 Python modules beside the installed shellrc. `_tavs_install_shellrc_files` publishes shellrc
only after those dependencies copy (`:33-36`).

`cmd-sync.sh:108-112` reuses the same copy helper for plugin roots; `:66-69` refreshes installed
shell integration. Editing a module already in this list needs no new delivery entry. Adding a
Python trust module would require the production list and explicit fixture/assertion lists:

- `tests/integration/hook-observations.bats:14-18`.
- `tests/unit/shellrc.bats:245-262`.
- `tests/unit/cmd-sync.bats:89-107,228-244`.

`tests/unit/test_portable_helper.py:207-238` exercises installed bash/zsh startup with the checkout
absent and an owned PTY. No delivery command was run in this exploration.

## 7. Tests inspected and coverage limits

Source already contains:

- Private `0600` lock creation, stable inode, lock contention and no late paint checks:
  `test_portable_device_writer.py:45-89,122-157`.
- Child channel closure and post-output failure reporting:
  `test_portable_device_writer.py:91-101,169-192`.
- Atomic private record replacement, linked checked ancestors, path escape rejection, deadline
  expiry, and failed temporary cleanup:
  `test_portable_record_io.py:27-94`.
- Per-bucket link rejection, cached directory replacement under held FDs, policy-before-pixels,
  exact target generation/device checks:
  `test_portable_ownership.py:71-119,161-170,210-229`.
- Suspension inode replacement, malformed policy, leaf symlink/FIFO rejection, bounded file size,
  stale soft state and finite locks:
  `test_portable_policy.py:25-96`.
- Owned test-root containment rejection before device lookup:
  `test_portable_helper.py:78-86`.
- No-output registration/current/context operations and rule-storage failures:
  `test_portable_no_output.py:63-105,138-155,221-234`.

The normal portable fixtures often create nested runtime directories with ordinary `mkdir()`:
`test_portable_policy.py:18-19` and `test_portable_ownership.py:59-61`. Requiring exact `0700` for
all existing roots would alter those tests and user compatibility unnecessarily. The no-`0o022`
rule preserves user-owned `0755` integrity while new default roots are still created `0700`.

Recommended new bounded regressions, once implementation is authorized:

- Foreign UID root rejected before runtime reads, mkdir, lock creation, record publication, or TTY
  open; a mock verifies the rule but is not evidence of a real cross-user exploit test.
- Current-UID group/world-writable root and root symlink rejected; existing safe `0755` and injected
  private roots accepted.
- Missing runtime is explicitly created `0700`, including a normal umask that would otherwise
  create intermediate parents `0755`.
- `/tmp` alias and `/var` per-user temp alias accepted, while final runtime symlink remains denied.
- A delayed root validator remains inside the original device-worker caller bound and produces no
  late pixels.
- Shell bad-root resolution stops before policy read and active-TTY touch/truncation; copied
  installed shellrc retains its guard without access to the checkout.

Cross-user exploit coverage: UNKNOWN. No real second-UID actor or attack was executed.
Adversarial root/ancestor/lock/policy TOCTOU coverage: UNKNOWN. The existing nested-directory
replacement test is narrower than a full cross-user runtime-root race.
ACL trust coverage: UNKNOWN. No ACL state or private runtime metadata was inspected.
Test outcomes for this checkout: UNVERIFIED. Tests were read, never executed.

## 8. Observable exploration note for the parent capture

[O] The exploration separated root validation from leaf no-follow/inode checks, traced the first
shell accesses before helper calls, then examined deadlines and explicit install resource lists.
[O] No repository changes or runtime operations occurred. The combined task's capture is deferred
to the parent so this read-only subtask does not append project documentation.


---

# Native runtime guard scoped source check

Last Updated: 2026-10-14 (Europe/Vienna)
Version: 1.0
Target: uncommitted native runtime trust diff on tracked baseline d11a04a.
Workspace: `/Users/cs/local/code/apps/terminal-agent-visual-signals`.
Read-only scope: source/diff inspection only. No tests, file mutations outside this requested
report, app/native actions, settings or process inspection. No scores or approval verdict.

The helper inspected was `src/macos/TAVSApp/Sources/TAVSApp/runtime-directory.swift` as first
provided in this task, including the broad sticky exception at lines52-53. Parent subsequently
reported adding a regression and planning to narrow that exception; that later edit/test result
was not independently inspected or executed by this source check.

## Answers to the requested questions

| Question | Source-grounded answer |
|---|---|
| Actual macOS /tmp and /var aliases retained? | Yes for descendants, using root-owned alias checks, bounded128-byte readlink, exact absolute/relative targets and a protected /private check. |
| Foreign/writable/linked runtime leaf rejected before creating descendants? | Yes when the configured runtime is checked as the helper leaf. Store explicitly checks runtime first; existing unsafe leaves are not adopted or chmodded. |
| Every writable runtime child rejected? | Not in the inspected version. Broad non-leaf sticky allowance can admit organizer01777 during deeper cache/unlocked calls. |
| Original100ms deadline retained? | Yes. Managed checks run inside existing completeDeviceWrite, use its supplied absolute deadline and do not create another deadline/worker. |
| Unsafe leaf records silently repaired? | No in the inspected typed-store/policy paths. Wrong UID or group/other-write causes unavailable/storage errors; writes independently reject unsafe existing leaves. |
| All native runtime consumers covered? | Store, native rule readers, managed writer, registry and pending are covered subject to the sticky finding. Scheduler's separate projection reader/writer/watch path remains outside. |

## Confirmed finding: writable sticky child accepted as an ancestor

Situation: RuntimeDirectoryTrust.check at runtime-directory.swift:49-55 requires owned,
non-group/other-writable mode only for the supplied leaf. Any earlier directory with trusted
root/effective-UID ownership is accepted when either non-writable OR sticky, without limiting
where the sticky directory is located.

Behavior: consider an effective-UID-owned0755 runtime, existing organizer01777, and existing
owned0755 targets/per-binding directories with safe record leaves. The store's
trustedDirectory(root) checks runtime as a leaf, then checks a deeper URL. During the latter
check, organizer is non-leaf and its sticky bit satisfies lines52-53. cachedRecords checks
organizer/targets, and shared read/write helpers check each record parent. Those paths can
therefore traverse this writable organizer instead of rejecting it. withLock checking organizer
as its own leaf would reject it, but cache enumeration/direct unlocked reads do not require
withLock first.

Impact: the stated property that runtime child directories must be effective-UID-owned and
non-group/other-writable is not enforced for sticky children. This is a source-confirmed guard
coverage defect. It is not, by itself, reproduced cross-user spoofing: POSIX sticky protections
still prevent another UID renaming existing victim-owned child entries, and other record,
identity and leaf checks remain in effect.

Suggestion: limit the writable sticky exception to the deliberately trusted system temporary
ancestors. Parent's proposed root-owned /private/tmp and /private/var/tmp paths with S_ISVTX
are narrow enough to preserve normal temp ancestry without treating organizer/targets/pending
or arbitrary user paths as shared system temporary containers. Do not weaken the leaf rule.
A source regression must exercise cache and an unlocked read with organizer01777, not solely
withLock or generic writable0777 ancestry, which already fail.

No behavioral reproduction was run by this agent. Parent has reported starting a RED regression;
that report is context, not an independently verified result in this document.

## Alias handling details

runtime-directory.swift:30-46 permits symlinks only when all these conditions hold:

- the symlink is non-leaf;
- its UID is0;
- its path is exactly /tmp or /var;
- readlink yields nonempty UTF-8 with a result strictly smaller than the128-byte buffer;
- target is exactly /private/tmp or /private/var, or the equivalent relative private/tmp or
  private/var spelling;
- /private is a root-owned non-group/other-writable real directory;
- the resolved alias target then passes the normal directory/ancestor check.

This accepts the actual previously inspected system aliases, /tmp -> private/tmp and
/var -> private/var. The128-byte buffer is a length bound, not an interrupting syscall wall-time
bound. The original deadline is checked before walking each component and after alias processing.

User/runtime symlinks are rejected, including a linked configured runtime leaf. Calling check
on /tmp itself rejects it as a leaf; that is appropriate because the shared system temp directory
is not an effective-UID-owned private runtime root. Descendants use the ancestor exception.

The code does not blindly resolve the full submitted path. It walks lstat components, preserving
the opportunity to reject runtime/user-linked objects. Root UID is allowed for safe ancestors;
the actual supplied leaf still requires effective UID. Thus legitimate private roots under
/var/folders or /tmp are compatible without a basename whitelist.

## Creation and absence

runtime-directory.swift:21-28:

- ENOENT with create=false returns after a deadline check. No missing path is created.
- With create=true, it calls mkdir(component,0700), permits EEXIST for a concurrent creator,
  then lstats and applies the same type/UID/mode rules.
- Traversal checks previous existing ancestors before reaching a missing child, so a
  wrong-owner/non-sticky-writable/linked ancestor is rejected before mkdir of that child.
- Existing untrusted objects are never chmodded, chowned, deleted or replaced by the helper.
- owned uses geteuid and mode&0022==0, so owned0755 roots are accepted alongside0700 roots.

TerminalVisualStateStore.trustedDirectory checks the configured runtime before the requested
record parent, for both creation and reading. Missing initial store fixtures remain supported;
read-only cache/data checks retain their subsequent ENOENT empty-state behavior. The broad
sticky finding is the exception to the intended writable-ancestor rejection.

## Original writer semantics and coverage

ProcessRunner.writeManagedToDevice remains inside completeDeviceWrite. completeDeviceWrite's
100ms creation before global dispatch and parent semaphore wait are unchanged. New trust calls
use that exact supplied deadline and run on the worker. Error mappings call checkDeviceDeadline
before translating an error to deviceIOFailed(EACCES), retaining timeout priority when expired.

The managed writer checks the lock parent before beforeOpen, creates/checks it after beforeOpen,
then performs admission/device open, and rechecks the directory after open. The opened lock
file keeps its regular-file/exact0600 checks plus a new effective-UID check. Target/emergency
admission key handling, partial writes, EINTR/EAGAIN handling, final descriptor checks and
late-worker paint rejection were not changed.

One order change is deliberate and should be described accurately: directory creation now
precedes device admission/open, whereas previously the lock parent was created after device
open. It does not restart or widen the deadline. Busy retries still prepublish metadata before
admission. Raw writeToDevice has no runtime metadata context and is unchanged; this guard
covers the managed writer, not every generic device-write utility call.

Caller coverage inspected:

| Consumer | Guard placement and effect |
|---|---|
| Direct organizer publication | withLock invokes trustedDirectory(create:true) before organizer/lock creation; shared record read/write check parents/leaves. OrganizerIntake constructs this store, so no separate CLI-only waiver is needed. |
| GUI/native focus/recovery | Same store and managed writer objects protect operations despite direct GUI constructors. No constructor-only cached trust Boolean was added. |
| cache/equivalent aliases | cachedRecords/equivalentBindings check runtime and traversal parent before enumeration; cachedRecords rejects unsafe child directory metadata and skips descendants. Deeper sticky ancestry remains the confirmed issue. |
| unlocked effect/intent helpers | Shared private read/write helpers check runtime plus record parent and leaf; target preparation delegates to the same helper for creation. |
| managed output preparation | Real ProcessRunner verifies lock parent before optional metadata callback/device open and after open, with original deadline; store validation protects runtime root explicitly. |
| VisualRestrictionPolicy | readRule checks rule parent, then owned non-writable leaf before/after open, preserving inode/device matching and deadline checks. This applies to runtime lock and home mute rule when used. |
| registry hints | runtime and active-ttys are explicitly checked as separate leaves; regular entry leaves must be owned and non-writable. Failure returns registry-unavailable evidence. |
| pending invalidation | runtime and pending explicitly checked as leaves; regular .osc leaf must be owned/non-writable before unlink, with deadline checks. |

Policy retains the earlier ordering: when suspension/unavailable marker disables restrictions,
current returns nil before reading runtime rules. This is not acceptance of untrusted rule bytes;
no runtime rule is read in that branch. The managed output path still checks its storage before
painting. Stronger mandatory root rejection before any disabled-policy return would be a distinct
behavior change and is not required to prevent reading those rules.

VisualRecovery.apply still starts native discovery before cache/registry guards. Rejection of
runtime-backed state does not imply native discovery never runs. Cache errors are reported;
managed output from native candidates still encounters writer/store checks before bytes.

## Unsafe leaf metadata and repair behavior

Typed read now throws TerminalVisualStateError.storageUnavailable when the lstat or fstat
record metadata fails owned. It does not misclassify these metadata failures as invalidRecord.
readLatest catches only invalidRecord, so it cannot convert an unsafe UID/mode read into a
repairable absent record. A trusted owned regular file with malformed JSON may still follow
existing non-synthetic repair behavior, which is outside this trust change.

write independently lstats an existing destination and requires regular+owned before temp
creation and rename. Therefore an unsafe existing destination cannot be replaced even if an
earlier reader skipped it. publishIntentUnlocked still ignores a non-synthetic observation
read failure and may proceed with a separate safe intent record; it does not replace the unsafe
observation itself. Coverage may omit unreadable observation/intent and report invalid status.
Neither behavior is a silent ownership/mode repair of that leaf.

The helper does not change filesystem permissions of existing untrusted roots or record leaves.
Tests restore permissions only on their owned fixtures; those tests were read, not executed here.

## Explicit boundaries and remaining gaps

- Scheduler: LockStateReader.read still uses String(contentsOf:), LockStateWriter still uses
  Data.atomic, and Scheduler's runtime watch/create/read/write path is unchanged. This slice
  must not be described as hardening every native runtime projection consumer.
- Persistent restriction marker: VisualRestrictionsStateStore's root/UID/ACL behavior is
  unchanged. Policy's soft mute reader gains parent/leaf checks, but marker persistence and
  revisions do not receive a general trust guard from this diff.
- Shell/TAVS_TMP_DIR: shell creation/use of its roots and old helper/runtime paths are separate.
  The native guard rejects an unsafe root it receives; it does not repair shell-created unsafe
  state or enforce a separate shell temp variable.
- Portable: portable helper test-root checks and descriptor-relative storage are unchanged.
  No parity or production portable runtime-trust claim follows from the native diff.
- ACL: owned checks POSIX UID/write bits only. macOS ACL write grants are not inspected.
- TOCTOU: path-based lstat/mkdir/readlink/open/rename still leave check/use races. Leaf inode
  matching and no-follow remain useful, but this is not descriptor-relative anchored traversal.
  Root/same-UID changes or hostile ACLs can invalidate previously checked paths.
- Actual foreign-user exploitation: synthetic UID predicate coverage is not a foreign-account
  attack. No another-user record visibility, app rendering or cross-user process inspection
  was tested by this task.
- Timing: the deadline value and behavior structure are unchanged, but repeated ancestry checks
  add work inside the existing100ms budget. Source-only inspection cannot certify latency or
  attribute prior full-suite failures.

## Verification scope

Read current uncommitted diff and complete helper source. Inspected added test source for safe
modes/missing roots/system aliases, linked/writable ancestry, synthetic foreign UID, writer
rejection before callbacks, unsafe store files, writable cache parent, policy, registry and pending.
Those assertions were not executed here. No test success, performance success or approval is
claimed. Parent should keep the sticky-ancestor finding separate from later behavioral results.

Repository edits were excluded, so session capture remains with the parent. The source-check
method was to enumerate bypass candidates first, then trace each against the exact changed
consumer and distinguish rejection properties from unreproduced exploitation.


---

## Parent verification and final scope

The shared native helper and five native production paths now reject unsafe POSIX directory
ownership/write permissions and user/runtime symlinks. Store boundaries include unlocked calls,
cache enumeration and creation; policy includes runtime lock and home mute reads; managed writer
checks precede callbacks and device open; registry and pending checks precede consumption/unlink.
Unsafe file metadata is storage unavailability and cannot take the invalid-data repair path.
Existing safe 0755 paths are preserved. Missing write components use 0700; missing reads stay empty.

The initial alias comparison incorrectly assumed resolvingSymlinksInPath canonicalizes /var into
/private/var. A fresh isolated Swift probe, fPhLxD, printed /var after resolving. The guard now
uses bounded POSIX readlink and exact root-owned system aliases. The source-check report identified
an overly broad sticky-ancestor exception. A new organizer01777 cache/unlocked-read case failed
before the final correction. Only root-owned /private/tmp and /private/var/tmp with S_ISVTX may
be writable ancestors; runtime and organizer children do not inherit that exception.

Exact runs through tests/run-isolated.sh with the existing owned scratch and explicit helper:

- TzBVlr: initial behavioral RED, 3 cases and 10 failed assertions, 0.788 seconds. Unsafe policy
  was accepted, organizer records created and writer callbacks/open/pixels occurred.
- JSDgL7: first guard draft, 220 tests and 393 assertions (267 unexpected), 36.211 seconds.
  Safe /var test roots were rejected. This is the reproduced alias implementation error.
- fPhLxD: isolated Foundation/POSIX metadata probe established the alias comparison error.
- EpyDjm: 6/6 focused cases, 0.020 seconds, after bounded readlink correction.
- iM40rR: 228/228 connected checks, 7.331 seconds, before the source-check sticky correction.
- HlHIlG: intermediate release, 20.68 seconds; its broader sticky rule is superseded.
- pomoPO: sticky organizer behavioral RED, 1 case and 2 failed assertions, 0.150 seconds.
- EP1Q21: final full Swift suite, 631/631, 16.422 seconds, including all 12 new cases.
- yCpWOG: final serial release, 20.00 seconds.
- noTOPS: final rebuilt-helper background-intent suite, 19/19, with private owned PTYs.

Logs remain under /var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.<run>/command.log.
The scratch remains /tmp/tavs-focus-leases-84v8mqbc/build. No deployed app was changed.
The current caller deadline is still 100 ms. Passing runs do not attribute older timing failures.

Scope: one new shared native module, four existing native production files and four existing test
files. This is a Phase 9 review correction spanning shared Phase 4/6 I/O paths beyond the original
Phase 9 file list. The common guard is needed because direct GUI/metadata/recovery consumers bypass
CLI validation. There is no new trust cache, registry, worker, schema or control plane.

Open trust consumers: Scheduler's independent projection read/write/watch path; persistent marker
read/write/revisions; portable Python and shell pre-helper policy/registry/legacy TAVS_TMP_DIR paths.
The native source check predates the final sticky correction and is not a later reviewer approval.
Synthetic UID metadata tests prove the predicate, not a foreign-account attack. ACL and complete
adversarial TOCTOU coverage remain unverified. Native pane/Space/readability, Linux ordinary
implementation, headless recovery feedback, palette restoration and final review remain open.
The complete goal stays active and incomplete; SPEC/PLAN bodies and live state were not changed.

## Native persistent marker correction

VisualRestrictionsStateStore now checks parent and leaf trust for reads, captureRevision,
identity matching and writes. Unavailable metadata disables restrictions and cannot authorize
revision matching or replacement. Safe missing paths, explicit repair of trusted malformed data,
atomic 0600 marker replacement and pinned inode lifetimes remain. Matching reuses its deadline.
No raw device output, new deadline, watcher, schema or restoration fallback was added.

Three cases reproduced writable parent, writable marker and linked existing-parent acceptance.
Their original bytes remain unchanged after failed writes in the corrected source. The policy
root fixture now separates its safe marker parent from an unsafe runtime child: otherwise the
new unavailable marker correctly overrides rule reads, making the old expected throw misleading.
An existing focus test now waits for successful cleanup publication and inactive metadata before
its owned fixture is removed. This fixes that fixture lifetime gap, not an established EPERM cause.

- mNJfIe: behavioral RED, 3 tests/15 assertions, 0.125s.
- I03h0W: connected run, 201 tests/3 assertions (1 unexpected), 4.946s. Two policy expectations
  failed because their marker was also made unsafe; the other error was fixture teardown EPERM.
- Owned failed root inspection found mode0700 and no listed immutable flag/ACL on root/organizer.
  It neither establishes every descendant's metadata nor explains the earlier deletion failure.
- Id3daK: 131/131 connected/previously failing case checks, 1.903s, after policy fixture repair.
  The old focus case passed here before its cleanup wait was added; no cause is inferred.
- 3YczDC: final full Swift suite, 634/634, 15.371s, after cleanup fixture correction.
- Bv21PX: final serial release, 22.04s.
- YqetLK: 25/25 isolated marker-parity/background-intent checks with rebuilt helper and owned PTYs.

Logs use the existing /var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.<run>/command.log.
Native marker trust is now covered; shell and portable marker trust remain open. Scheduler's
checked-reader/projection/watch correction is still unimplemented. Its full source investigation
is retained in current-codex-review-2026-10-14.md as a separate source appendix, not a new provider
review or approval. Other native/Linux/headless/palette/review and timing limits remain open.
