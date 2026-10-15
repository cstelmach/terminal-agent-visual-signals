# S4 shared session table source check

Last updated: 2026-10-15. Version: 1.

Scope: the uncommitted `src/core/session-state.sh` and
`tests/unit/test_session_state_concurrency.py` changes over HEAD
`5cda4b753eeb55f66ffff8c6059a2eddb65ce889`, plus their direct source callers.
No project files were changed. No hooks, native helpers, or test suites were executed;
no live runtime roots were accessed. Two bounded private shell probes were performed,
described below. Parent-reported suite outcomes are not independent evidence
from this review.

## Finding

The shared transaction correctly covers the complete table replacement for all three
existing mutation APIs. One conditional opening risk remains: the immediate parent and
leaf guards do not exclude an ancestor another UID can replace. Such substitution can
redirect the new lock open to a FIFO before the lock timeout begins. The default direct
`/tmp/tavs` placement beneath root-owned sticky `/tmp` does not present that condition.
For arbitrary configured roots, make a localized ancestor-admission correction before the
first lock open; no second locking mechanism is needed.

The removed `/dev/fd/9` inode comparison is absent in the source inspected here. I did not
repeat the earlier FD-lock primitive probe. Mac acceptance of that primitive and any parent
test results must be attributed to those runs; Linux kernel acceptance remains unrun here.

## Transaction coverage and callers

- `session-state.sh:99-154` holds the stable `${db}.lock` FD across validation of the table,
  fresh `mktemp`, filtering, construction of the new row, and successful rename. It acquires
  the lock before either the table read or timestamp calculation. `state` and `colors` have
  separate locks, which matches their existing independent file formats.
- `write_session_state` at lines 157-164, `write_session_colors` at lines 223-238, and
  `clear_session_colors` at lines 278-282 all use that helper. `record_state` at 187-189
  returns the state writer's status. I found no other production writer/remover of either
  shared table and no source cleanup that unlinks the new stable lock files.
- The state callers are `trigger.sh:230,243,298,316,363,384,406` and
  `idle-worker-background.sh:101,135,144,146`. The color callers are
  `dynamic-color-calculation.sh:134,226`. No current source caller bypasses the transaction.
- Priority admission in `should_change_state`, timer cancellation, per-TTY skip files,
  and native delivery currentness remain separate existing operations. This change fixes
  cross-row table loss; it does not make the entire hook or a state/color pair atomic.
  There is no source reason to broaden this slice into those transactions.

## Bash, zsh, descriptors and failures

- The function's `(...)` body scopes FD 9, umask, and cleanup/signal traps to one invocation.
  Replacing FD 9 there does not replace the caller's descriptor. The lock file is opened
  in append mode, never truncated or unlinked by this helper. All normal subprocesses are
  awaited, so there is no deliberate detached descendant retaining FD 9.
- The Mac branch invokes descriptor-mode `lockf`; the Linux branch uses inherited FD 9
  with `fcntl.flock`. Neither reopens a different lock path inside the lock backend.
  A nonzero backend result returns failure before any table temporary is created.
  The Linux alarm handler raises an exit status rather than silently continuing unlocked.
- The syntax introduced here uses features supported by the requested Bash 3.2 and zsh:
  subshell function bodies, `local`, `[[ ... ]]`, base-8 arithmetic, command substitutions,
  FD redirection, and scoped traps. The previously problematic `/dev/fd` predicate is gone.
- `mktemp`, `awk`, priority/time retrieval, row append, and `mv` have checked statuses.
  Failed filtering cannot publish the partial temporary. Failed rename retains the old
  table and runs the scoped cleanup. The cleanup names only the current `mktemp` result.
  A successful publication clears that variable, so cleanup does not remove the table.
- SIGKILL cannot run shell cleanup; the crash fixture correctly checks kernel lock release
  and inode retention, rather than promising removal of a killed writer's temporary.
  Any inherited descriptor closes only when its last holder exits; killing the fixture's
  entire owned process group satisfies that condition.

The private probe at `/tmp/tavs-session-trap-probe-20261015.meoznj1l/results.json` sourced
only this module under new private HOME/tmp/state roots. In both `/bin/bash` and `/bin/zsh`,
an early rejected write returned 1 without running the caller's EXIT trap inside the helper.
The caller's trap ran exactly once at its own exit. This rules out an extra caller-cleanup
execution on the pre-lock return path in those shells. It is not a repeat lock primitive
test or proof of Linux behavior.

## File opening boundary

`session-state.sh:85-112` checks the immediate table directory for ownership, no leaf
symlink, and no group/other write permission. Lock creation uses noclobber and umask 077;
the existing lock must be an owned regular non-link file without group/other write bits
before append-open. The table has the corresponding regular-file check after admission.
This rejects the unsafe existing leaves and parents covered by the tests before mutation.

The immediate parent check alone cannot reduce replacement races to hostile same-UID
mutation. If the victim-owned 0700 table directory sits beneath a directory another UID
controls, that other UID can rename the protected descendant through its own parent.
It can then install a replacement directory containing a predictable `state.lock` FIFO.
Even a sticky parent permits its owner to rename children. The victim need not grant
write permission on its 0700 table directory for this ancestor substitution.

There is a concrete seam between the successful lock mode read at line 111 and
`exec 9>> "$lock_file"` at line 112. Substitution there follows the new path. FIFO open
for writing blocks while no reader exists; `lockf` and its one-second timeout have not
started. The earlier regular-file check cannot protect the later open after substitution.

A controlled private probe retained at
`/tmp/tavs-session-ancestor-probe-20261015.a7spm7d9/results.json` replaced the table directory
immediately after returning its original lock mode from `stat`. For Bash 3.2 and zsh, the
owned shell remained blocked, the replacement was a FIFO, and the shadow lock backend was
never called. Only the probe's explicitly owned process groups were terminated. The probe
uses the current UID to control its fixtures; the other-UID applicability follows from
directory-parent rename permissions, not from a claimed separate-user execution test.

This is an additional predictable lock opening under the already-open legacy ancestor
trust problem. It does not establish that the old table code was safe against the same
ancestor attacker; its predictable temporary and table operations were also exposed.
The small necessary correction is to reject other-UID-controlled or replaceable ancestors
for this table path before opening FD 9, while handling conventional root-owned aliases
and sticky temporary directories. Keep that admission local to the existing helper. This
does not remediate separate policy/registry paths or complete S2. Reintroducing the
nonportable descriptor-path equality check would neither prevent FIFO open from blocking
nor solve ancestor substitution.

## Do the tests discriminate the defect?

Yes for the pre-fix implementation. `gate_tools` at test lines 58-84 gates each `mv` only
after the replacement table has been prepared. `race` at 86-122 starts actor two while
actor one's prepared replacement is withheld. The old implementation never invokes a
lock backend, so the controller must see `two.prepared` before allowing actor one to
publish. Both therefore read the original table. Publishing them cannot preserve both
changes. The old shared `$$` temporary path also collides between the background
subshells; the assertions check both exact final rows and each writer's own status, so
neither corruption nor a failed second move can masquerade as success.

With the fixed implementation, actor two cannot prepare while actor one holds the lock.
The `two.lock-request` alternative therefore avoids fixture deadlock while still starting
the contender during the first transaction. That marker alone does not prove acquisition
or exclusion: it is written immediately before the real backend. The separate held-lock
case at lines 167-187 supplies the complementary exclusion check for state write, color
write, and color clear, using a real independently held `flock`, unchanged table bytes,
no clock invocation, and no table temporaries.

The race cases retain an unrelated row, cover state updates, color updates, and both
clear/write orders. Empty clears and literal TTY-field matching are independently checked.
They do not merely count rows or accept whichever concurrent writer happens to win.

## Rename failure and final test adjustment

The current publication-failure fixture at lines 219-245 is adequate for the injected
rename failure. It immediately verifies the old table bytes and that only an unrelated
pre-existing temporary remains, before unsetting the failing `mv` function and issuing
the recovery write. It also verifies the parent TERM trap and FD 9, the unrelated file's
contents, final recovery output, and absence of leaked transaction temporaries. This
closes the earlier blind spot in which a later successful write could hide damage.

The backend/filter failure fixture at lines 247 onward checks unchanged bytes, no
temporary leak, and successful later acquisition. The final source read confirms the
parent's correction: it exits explicitly with 0 after the expected failed write and uses
`assertEqual(returncode, 0)`. The previous unnecessary `unset` and weaker status assertion
are gone. An unrelated shell error can no longer count as the intended failed operation.

## Evidence limits

The parent reported all 10 current test groups and 52 connected Bats cases passing. I did
not execute or inspect those run logs in this review. The source analysis, private shell
probes, and prior parent-owned Mac primitive evidence support the transaction's Mac
mechanics, subject to the ancestor-admission concern above.
They do not establish Linux kernel acceptance, physical terminal acceptance, or another
provider's approval.

Observed review method: read the whole helper and mutation callers first; traced the lock
and rename failure paths; re-read the changing tests; used one private probe to settle
the early-return EXIT-trap question and one to confirm the ancestor/FIFO opening. Source
changes were not inferred from old
reports or from the parent's pass counts.

## Addendum: localized ancestor correction

The source re-read after the narrow correction resolves the conditional lock-opening
finding above. This supersedes that finding for the new implementation; it does not claim
completion of S2 for unrelated legacy policy, registry, or reader paths.

At current `session-state.sh:108-118`, the helper resolves the table directory physically
with `cd -P` and `pwd -P`, validates each physical ancestor up to `/`, validates the final
table directory again under the stricter leaf rule, and builds both `db` and `lock_file`
from that physical directory. A later change to an original lexical ancestor alias cannot
redirect those operations. Canonicalization is used for subsequent operations, rather
than only for checking a path that is later opened through its old alias.

At lines 85-100, each ancestor must belong to EUID or root and must not permit group/other
write, except when it is sticky. Lower descendants have already passed the ownership
checks, so a trusted sticky ancestor protects the next trusted child against another UID's
rename. Another UID's own sticky directory is rejected by ownership before that exception.
The final table directory and lock/table leaves still require EUID ownership and do not
receive the sticky exception. Thus the other-UID ancestor owner used in the earlier attack
cannot replace the checked physical tree before the new FD open.

### Arithmetic and BSD stat corrections independently checked

The final source uses explicit `8#22` and `8#1000` masks at lines 97 and 99. This is
necessary: the private arithmetic probe retained at
`/tmp/tavs-session-ancestor-bits-20261015.gd1phdgr/results.json` found that Bash 3.2 reads
`0022` and `01000` as 18 and 512, while native zsh reads them as 22 and 1000. The bare zsh
sticky expression incorrectly returns nonzero for a non-sticky 0777 directory; the bare
write mask incorrectly rejects a readable 0644 file. Both explicit masks produce the
correct values and bit decisions in both shells.

The Darwin metadata read is now `stat -f '%u:%Op'`; Linux remains `stat -c '%u:%a'`.
The final private probe at
`/tmp/tavs-session-ancestor-final-20261015._s7mgu2u/results.json` independently found BSD
`%Lp=777` and `%Op=41777` for a private 01777 directory. The full `%Op` value retains the
sticky bit, while the explicit masks ignore unrelated file-type bits correctly.

That probe called the current permission helper under both real shells with fresh private
HOME/tmp/state roots. Both returned: sticky ancestor accepted (0), sticky final directory
rejected (1), writable non-sticky ancestor rejected (1), readable 0604 leaf accepted (0).
Both resolved a legitimate ancestor alias under lexical `/tmp` to the expected physical
`/private/tmp/...` table directory. No live root, hook, native helper, or test suite was used.

### Current tests and remaining scope

The final source read confirms `UNTRUSTED_PARENT = str(ancestor.resolve())` at test line
303. The other-owner stat double now observes the physical path production actually
checks; the earlier lexical alias mismatch is corrected. The writable-ancestor case uses
an actual 0777 directory. Both rejection cases require unchanged table bytes and absence
of a newly created lock, so they require rejection before the new opening surface.

The added acceptance fixture at test lines 320-339 covers an ancestor alias with both
0700 and actual 01777 parent modes, and 0604 table/lock leaves. It checks a successful
writer status and exact final table contents. These cases distinguish legitimate read
permissions, sticky ancestry, and alias handling from the unsafe ancestor cases. Existing
strict final-parent and unsafe-leaf fixtures remain present.

No further actionable source defect found in this correction. Lock ordering, checked
publication failures, scoped traps/FDs, and the stable-inode lifetime are retained. I did
not run the expanded suite or claim Linux kernel acceptance; the private probes establish
Mac Bash/zsh arithmetic, metadata, and path-resolution behavior only.
