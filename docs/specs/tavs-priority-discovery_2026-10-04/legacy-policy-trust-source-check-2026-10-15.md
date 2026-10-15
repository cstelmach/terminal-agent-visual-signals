# Legacy shell policy and registry trust gaps

Last Updated: 2026-10-15
Version: 1.0
Initial inspected source: clean HEAD `780995b`,
`/Users/cs/local/code/apps/terminal-agent-visual-signals`.
The parent subsequently committed copy-only help change `8a12cc9`; no S2 source/test change was
reported during this investigation. This report uses current S2 source, not another agent report.
Read-only: no hooks/helpers/tests/native apps, Docker, live roots/settings or process actions were
executed. Only this report was written.

## Recommended next slice: remove redundant unsafe raw registry publication

Yes, the installed shellrc can remove all raw runtime mkdir/registry writes before helper
selection while retaining its existing `--managed-register` call as authoritative registration.
The core raw active-TTY touch can also be removed. This is the smallest immediate correction for
the concrete data-loss path. It does not close the separate suspension-marker and policy trust gaps.

Important precision: neither native nor portable managed-register writes `active-ttys`.
They publish a typed, validated organizer `target.json`. The current scheduler/recovery consumes
those bindings directly; it does not require new legacy registry rows to paint later.

### Concrete unsafe operation

`src/shell/tavs-shellrc.sh:98-104` creates runtime directories if needed and then executes:

```sh
: >| "$_rt/active-ttys/$_tty_safe"
```

It checks neither directory owner/mode nor leaf type. In a precreated attacker-controlled runtime,
a registry leaf symlink can point at a file writable by the victim user. Shell startup follows the
symlink and truncates that destination before helper selection at line 106. A later helper rejection
cannot undo that write. This is a reachable conditional filesystem data-loss mechanism, not a claim
that it was executed against this workstation. Tests can reproduce it entirely inside private roots.

`src/core/mute-gate.sh:20-30,143-147,174-177` similarly creates directories and touches an unchecked
leaf. Touch changes target metadata through a symlink; the installed shellrc's redirection is the
stronger content-loss case. The raw directory paths can also follow a linked runtime/registry parent.

### Exact authoritative registration route

- Shellrc already selects one managed backend at `:106-109` and invokes `--managed-register` with
  marker/runtime/concrete TTY/caller PID at `:110-112`, including while suspended. Keep that call.
- Native dispatcher: `managed-output-entry.swift:63-79` proves caller ancestry/device and maps
  register to `.register`; lines 135-148 resolve the target and run the managed write.
- Native writer: `visual-recovery.swift:217-248` performs descriptor validation and
  `cacheTargetUnlocked` before returning nil for register. This is a real no-byte registration
  under the existing device transaction, not an mtime hint.
- Portable dispatcher: `portable_helper.py:149-157` authenticates the caller and calls
  `Renderer.register`.
- Portable register: `portable_renderer.py:31-78` resolves current owner/device before open, opens
  the exact PTY under the existing writer, caches version-correct `target.json` at lines 55-59,
  revalidates current descriptor/target at lines 62-74, and returns no bytes.
- Native ordinary render also caches its target at `visual-recovery.swift:245`.
- Portable ordinary background publication reaches `Intents.publish_unlocked`, which writes
  `target.json` and its bound intent at `portable_intent.py:126-154`.

Do not claim every portable render currently caches a binding: a title/palette-only render without
background bypasses publication in `portable_renderer.py:198-201,207-212` and currently creates no
new target cache. The old raw row was only an unverified hint in that case; it did not authorize
restoration. Removing it loses that hint, not existing managed recovery authority. Preserve this
qualification rather than introducing an extra helper call on every hot-path event in this slice.

### Schedule/global broadcasts do not depend on Sessions/focus UI

`Scheduler.createDefault` in `TAVSApp.swift:278-298` creates its own VisualRecovery with its own
TerminalVisualStateStore and `GhosttyCatalog.shared.snapshot`, then constructs
`Broadcaster(recovery:)`. It is independent of an open Sessions window or FocusController.

`Broadcaster.swift:95-128` routes registration and every global/reconcile operation through
`VisualRecovery.apply`. That method at `visual-recovery.swift:456-502`:

1. Loads cached bindings/effects at lines 462-464 and fans out to them immediately.
2. Adds fresh native catalogue targets at lines 467-490, including uncached plain Ghostty shells.
3. Reads legacy registry hints only afterward at lines 493-499. An unhandled hint becomes an
   unverified or vanished diagnostic item; it is never turned into an additional paint target.

No DiscoveryService reference exists in current `src/macos/TAVSApp/Sources/TAVSApp`. Scheduler
comments mentioning active-ttys bootstrap are historical descriptions, not the current execution
route. They must not override the actual Broadcaster/VisualRecovery path above. Existing legacy
registry entries can remain readable for their current diagnostic purpose; no deletion is needed.

### Missing-helper behavior and affected tests

When no usable backend can be selected, shellrc already prints managed-output-unavailable and
returns (`:106-109`). It has no safe generation/device registration mechanism without that helper.
An old raw filename is not such a mechanism. Preserve the diagnostic and no raw-output fallback;
do not manufacture registration success when helper registration fails.

Exact source callers of core `register_active_tty` are its definition and `_tavs_mute_gate_init`;
the direct other uses are unit tests. `_tavs_resolve_runtime_dir` must still choose/export the
runtime path, but its directory creation is not required for reading absent policy or selecting
a helper. The new authoritative cache is created by the required managed operation. Debug append
and remaining legacy readers are separate trust work, not silently fixed by deleting raw markers.

Tests requiring deliberate updates:

- `tests/unit/mute-gate.bats:25-31,42-51`: raw mkdir/touch expectations. Replace with the intended
  path-resolution/no-raw-mutation contract, not a false claim that this function registers safely.
- `tests/unit/shellrc.bats` registry-file assertions at 122,131,139,203,219,224,241-242,330,334,
  361,366: helper doubles at lines 27-39 only record protocol calls. Assert the appropriate
  managed-register/current routing and no raw file mutation; do not make a fake helper create
  authoritative data merely to preserve an obsolete marker assertion.
- Retain the real owned-PTY installed-shell acceptance at
  `tests/unit/test_portable_helper.py:289-323`. It installs the actual adjacent helper and verifies
  zero PTY output, exactly one actual `runtime/organizer/targets/**/target.json`, no invented intent,
  and suspension preservation in Bash/zsh. Its extra active-ttys assertion at line 318 is obsolete;
  keep/strengthen the typed target/actual device-generation proof instead of deleting that test.
- Keep real no-output registration checks in `tests/unit/test_portable_no_output.py:63-78,138-157`.
  They prove cache publication and exact device-open requirements independently of shell doubles.

Necessary new isolated regression: point the would-be registry leaf at a private sentinel via a
symlink, source installed shellrc in Bash/zsh with a controlled helper double, and require the
sentinel and link to remain unchanged. Cover a linked registry/runtime directory too. With a
missing selector/helper and an absent private runtime, require the existing unavailable diagnostic
and no raw runtime/registry creation. A selected-helper failure must retain its warning and backend
without a raw fallback. Run actual owned-PTY registration alongside these tests when authorized.

## Next marker slice: localized guards in the existing module and standalone reader

The recommended follow-on is a small policy-specific stat/path guard in the existing
`visual-restrictions-state.sh`, reused by its read/write functions and duplicated with its existing
standalone reader in `tavs-shellrc.sh`. This is smaller than extracting S4 into another delivered
module now: S4 lives in session-state.sh, whose sourcing initializes unrelated session paths;
a new delivered module would also require installer/copy manifests and standalone dependency
changes. Do not source session-state.sh just to borrow its guard.

The current standalone-reader duplication is already explicit at shellrc line 24. Keep its
semantics in parity with core and test the copied installed shellrc through the existing sync
path. No generic trust framework, new capability verb, native prerequisite or runtime service is
needed. A later consolidation can be justified separately if the same small guard genuinely grows.

### Current marker reader/writer defects

`visual-restrictions-state.sh:3-30` checks only absolute path, existing leaf type/link/readability,
and exact bounded content. It never checks ownership, group/other write bits, or ancestor trust.
At lines 7-17 any accessible nearest existing parent can authorize a missing marker as active,
including a foreign-controlled or replaceable parent. Existing valid-looking writable/foreign-owned
regular marker content is accepted. A linked ancestor can bypass its final-leaf symlink check.
The standalone copy at `tavs-shellrc.sh:25-58` has the same gaps.

The writer at `visual-restrictions-state.sh:39-58` validates bool/absolute path and current leaf
type, but trusts any existing directory, follows parent links, and creates missing parents with
mkdir -p. Its same-directory mktemp/mv prevents ordinary partial writes; it does not establish
trusted path ownership. `cmd_recover:31-34` persists via this writer before any native helper probe.
It can therefore modify an unsafe supplied home path and only later report native refusal.
A leaf symlink is refused, so do not misdescribe this writer as following a final leaf symlink;
its defect is untrusted ancestor/directory admission and unchecked owner/mode of regular leaves.

### Complete marker caller map

- `_tavs_visual_restrictions_write`: production caller is `src/cli/cmd-recover.sh:31` for recover
  and explicit resume. Its persistence-failure branch must continue preventing any helper call.
- `_tavs_visual_restrictions_read`: direct CLI status at `cmd-status.sh:45`; lock status at
  `cmd-lock.sh:131`; otherwise through the suspended predicate.
- `_tavs_visual_restrictions_suspended`: mute/idle policy through `mute-gate.sh:51` and
  `idle-worker-background.sh:110-113`; lock effective predicate at `lock-state-lib.sh:57`; lock-now
  reporting at `cmd-lock.sh:107`; unlock uses `_tavs_lock_effective` at `cmd-lock.sh:189`.
- `cmd-schedule.sh:25-34` also uses `_tavs_lock_effective` to decide whether edits need its
  existing challenge. Unsafe marker acceptance can therefore change legacy gating/status, even
  when the native writer later independently refuses unsafe roots.
- Installed shell startup uses the duplicate predicate at `tavs-shellrc.sh:113-120` to skip or
  request current policy after managed registration.

No marker is sourced/evaluated as shell code in these functions. The demonstrated concern is
filesystem trust and changed gating/registration behavior, not automatic execution of marker text.

### Guard contract to preserve

Use current native `runtime-directory.swift:5-59` as the policy trust reference, and the existing
S4 stat-format/mode parsing as shell implementation material:

- Existing policy-directory leaf and existing regular marker must be current-EUID owned and have
  no group/other write bits. Read/search accessibility still matters. Do not require world-read
  bits to be zero merely because write bits are forbidden; native owned accepts safe 0644 leaves.
- Existing ancestors must be current EUID or root and nonreplaceable by others. Known root-owned
  sticky system temp ancestors are allowed by the native rule. Foreign-owned searchable parents
  remain unsafe even if mode0755; their owner can replace children.
- Permit the existing macOS root-owned `/tmp -> /private/tmp` and `/var -> /private/var` aliases,
  validating their targets/parents. Native permits only these aliases, not arbitrary user/runtime
  leaf symlinks. Preserve ordinary physical `/private/...` and Linux `/tmp` paths.
- Distinguish trusted missing suffixes from unresolved/foreign/inaccessible prefixes. Reading a
  genuinely absent marker below a trusted existing prefix may stay active without creating
  directories. A dangling or looping link, non-directory component or foreign-owned ancestor is
  unavailable, never inferred to be safe merely because the final file appears absent.
- Writer creation must occur only beneath a verified prefix, with new directories0700, followed
  by verification of any concurrently created component. Do not chmod/chown or adopt existing
  unsafe directories. Existing safe parent paths and valid leaf data must remain intact on refusal.
- Use the validated physical/canonical path for the read/write after resolving allowed aliases,
  so checking one physical directory does not then reopen an attacker-controlled lexical alias.
  Recheck a current destination before final replacement; retain atomic same-directory mktemp/mv
  and clean only the invocation's own temporary file on failure.

S4's physical-canonical ancestor behavior is not identical to native policy trust. It resolves
safe ancestor aliases, permits root or EUID ancestors, and permits a trusted sticky ancestor more
broadly; its direct directory leaf must remain nonlinked/current-owned/nonwritable. Native policy
walks lexical components and whitelists system aliases only. Do not blindly reuse/extract S4 and
thereby silently widen the marker's native alias contract. Safe system aliases and canonical
current-owned physical parents are different from an unresolved other-UID-controlled prefix.

## Remaining legacy policy reads after those slices

- `_tavs_lock_read` at `lock-state-lib.sh:31-51` accepts anything readable, including a symlink or
  FIFO, and reads to EOF without a byte bound. CLI status/effective/unlock/schedule gating can
  encounter it before any native helper. A readable FIFO can block at open; an enormous regular
  file can consume unbounded scan time. Exact behavior has not been executed here.
- `_tavs_check_mute_state` at `mute-gate.sh:55-100` uses -f, so an unchanged FIFO leaf is excluded,
  but follows regular-file symlinks and reads lock/mute data without owner/mode/ancestor or byte
  bounds. Date/PID/heartbeat parsing is not a filesystem trust check. Selected native output later
  rechecks policy, but these shell reads have already occurred and can influence suppression.
- `_tavs_lock_write` on Darwin delegates to the native transaction (`lock-state-lib.sh:88-90`).
  Its non-Darwin branch at 92-107 still writes through untrusted runtime parents with no equivalent
  guard. Native-only mutation hardening does not cover it.
- `cmd-schedule.sh:347-361` directly reads mute.state for display. This is a bounded-scope ancillary
  caller to guard when legacy mute reading is corrected, not a new parser API to invent.
- `_tavs_debug_mute:160-165` appends to a runtime path without leaf/ancestor trust when debugging is
  enabled. Removing registry writes alone does not close that optional write path.

Existing portable `open_regular/read_regular` in `portable_policy.py:20-66` already supplies
nofollow, pre/post inode/type/size checks and bounded reads, useful principles. At this inspected
source it does not itself validate owner/write modes or the complete parent chain. It is therefore
not a complete trust predicate to call unchanged from shell. Native `registryHints` already checks
runtime/directory trust and regular owned entries (`visual-recovery.swift:654-679`), but it runs
after unsafe raw shell mutation, which is why removal is the immediate correction.

## What S4 already fixes, and what it does not

`session-state.sh:85-168` protects `_tavs_update_session_table` whole-file mutations. It checks
current-owned safe directory/lock/table leaves, canonical physical ancestors with trusted root/UID
ownership and sticky handling, and holds one stable lock across read/modify/rename. Existing
regressions in `test_session_state_concurrency.py:269-361` cover writable/foreign ancestors,
linked/unsafe leaves, safe physical aliases and sticky ancestors. That protection applies to
session state/color table transactions; it is never called by marker, legacy lock/mute or registry
code. It is not a global root-admission gate. Initialization and independent table reads are also
not transformed into checked policy reads by this mutation guard.

## Bash3.2/zsh details and marker regressions

- Preserve the reader's status contract: `_tavs_visual_restrictions_read` returns0 and writes the
  caller's `_TAVS_VISUAL_RESTRICTIONS_STATUS`; failure leaves unavailable. The suspended predicate
  treats any nonactive state as disabling restrictions. A subshell that loses that global result,
  or a new nonzero return triggering inherited errexit, changes callers.
- Preserve exact marker bytes, including final newline. Command substitution strips trailing
  newlines; do not replace the bounded builtin read with unqualified `data=$(cat ...)`. Keep the
  separate Bash `read -d '' -n128` and zsh `read -k128 -u0` semantics or a deliberate byte-exact
  equivalent. Use a C locale if claiming a byte rather than character limit.
- BSD stat uses `-f '%u:%Op'`; GNU uses `-c '%u:%a'`. Validate decimal owner and octal mode text
  before arithmetic and use explicit octal conversion. Separate local declaration from command
  assignment so local does not hide stat failure. Keep variable names away from zsh's readonly
  `status` and special `path`, and do not use Bash4 associative arrays or readarray.
- Shell redirection itself lacks an O_NOFOLLOW option. Trust the parent chain and refuse unsafe
  leaves before opening; do not rely on `>|`/touch to validate them. If a stronger same-UID
  concurrent-writer adversary is intended, name that separate threat instead of claiming simple
  stat checks eliminate every TOCTOU race. No process-control framework is warranted.
- Scope umask/traps used for atomic writer cleanup so sourcing this helper does not alter the
  caller's shell behavior. Preserve readable missing-marker behavior without creating live roots.

Marker regression matrix, limited to private fixtures and both `/bin/bash`3.2 and zsh:
existing valid active/suspended, trusted absence/missing directories, writable/foreign marker,
writable/foreign directory or intermediate ancestor, final/intermediate/dangling/looping link,
FIFO/directory leaf, inaccessible/non-directory prefix, exact accepted system temp aliases,
trusted physical paths, writer refusal preserving old bytes and creating no temp output, and
owned0700/0600 output on a new safe prefix. Use stat doubles for foreign ownership rather than
requiring chown or touching real homes. Keep hostile-content/NUL/oversize fixtures unchanged.

Extend the existing `visual-restrictions-state.bats`, shellrc parity/copy tests, and
`cmd-recover.bats` persistence-before-helper tests; do not replace them with tests that merely
exercise the metadata guard. A rejected recover write must make zero helper calls. Accepted core
writes must still read identically in copied installed shellrc and Swift. All runtime verification
is still future work; no source conclusion here substitutes for those tests.


## Raw-registry removal source check over 8a12cc9

Inspected the current five-file source/test diff without execution. No concrete registration or
schedule-discovery defect was found in this bounded change. Core `register_active_tty` and its
call are removed, and no references remain in current source/tests. The runtime resolver still
selects/exports its path but performs no mkdir. Existing legacy hint reading/retention remains.

Installed shellrc no longer creates raw runtime/registry directories or truncates a registry
leaf. It still selects one helper and performs `--managed-register` before policy handling. A
failed register retains the warning/backend and returns before `--managed-current`; it does not
use a raw or alternate-backend fallback. Successful suspended startup still registers, then skips
current-policy paint. This removes the pre-validation truncation mechanism rather than merely
checking a risky raw leaf before truncating it.

The fake-helper cases now observe verb and TTY arguments, which is the correct boundary for those
unit doubles. Their absence-of-files assertions are complemented by real registration coverage:
`test_portable_helper.py:289-332` installs actual adjacent resources without checkout access,
runs Bash/zsh on owned PTYs, checks the selected backend, requires exactly one real target.json,
and compares its tty to the child PTY's TTY_DEVICE. `owned_shell:334-338` obtains that value from
`os.ttyname(0)`, so this is not a fake hardcoded TTY comparison. No intent or terminal bytes may
be created, suspension must remain unchanged, and active-ttys must remain absent. The matrix now
uses native and portable backends on macOS, suspended and unsuspended; Linux remains portable.
This preserves actual target publication instead of replacing it with call-log success.

The four added Bats cases cover linked registry destination preservation, no raw runtime creation,
and core initialization not touching legacy hints. The mute sentinel gets an old mtime before
initialization, so content-preserving touch would still be detected through changed metadata.
The parent reports these cases failed against old source (`12sboq`) and passed after the fix.
That runtime status was not independently read or rerun here.

Minor assertion precision: the new shellrc log is exact verb-plus-TTY text, but current
`grep -qF` checks accept a matching substring. `grep -qxF` would make each assertion match the
whole expected log line if exact TTY spelling is the intended claim. This is a small test-only
precision improvement, not a production registration/discovery defect.

Rechecked schedule reachability: `TAVSApp.swift:278-298` creates scheduler recovery independently
of Sessions/focus; `Broadcaster.swift:118,124` delegates to recovery;
`visual-recovery.swift:462-490` targets cached bindings/effects and fresh native rows. Legacy
active-ttys rows at `:493-499` only add unverified/vanished diagnostics. The changed shell writes
therefore do not remove schedule/global paint targets for a newly registered plain shell.
No current DiscoveryService dependency was found.

The prior qualification remains: portable title/palette-only renders currently do not themselves
create a target cache, while ordinary background rendering does. Their former raw hints supplied
no paint authority. This slice does not claim complete S2 closure or fix marker/legacy policy root
trust, debug appends, or portable trust gaps recorded above. Linux kernel acceptance and live
platform behavior are not inferred from source inspection.

Host follow-up: the suggested exact-line `grep -qxF` correction is applied. New missing-resource
startup coverage requires the unavailable diagnostic and no runtime mutation in both shells.
