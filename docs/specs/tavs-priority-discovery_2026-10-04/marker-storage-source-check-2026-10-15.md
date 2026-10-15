# Suspension marker storage source check

Last Updated: 2026-10-15
Version: 1.0

Reviewed the uncommitted four-file suspension-marker trust change over HEAD `add5f3a`.
Scope was the core shell module, its standalone shellrc copies, the two named Bats files,
and connected native trust/store and caller source. No repository edits, live helpers,
hooks, tests, user configuration, or live TAVS runtime roots were used. A private guard-only
probe was run and retained below. No other agent reports were consulted.

## Result

No material production defect found in the current change. The shell path guard matches
the requested native directory ownership, missing-suffix and system-alias rules. Reads and
writes use its checked physical result. Unsafe existing prefixes are rejected before the
guard creates a missing directory; recover refuses persistence before querying a helper.

There are two small test gaps: no injected failure after marker temporary creation, and
the creation-mode fixture reuses the directories first created by Bash when it reaches
zsh. These are coverage improvements, not evidence that the current source misbehaves.

## Native contract comparison

The relevant native contract is `runtime-directory.swift:5-60` and
`visual-restrictions-state.swift:107-165`.

| Contract | Current shell source | Assessment |
| --- | --- | --- |
| EUID-owned final directories and files; no group/other write | Core lines 3-25, 51-64, 77-78, 102-104 | Matches `RuntimeDirectoryTrust.owned` and strict directory leaf handling. Root ownership alone is not enough for a leaf when EUID differs. |
| Root/EUID-owned existing ancestors; no group/other write | Core lines 12-24 and per-component walk | Matches the native ancestor rule. |
| Shared sticky directory exception is restricted | Core lines 20-23 | Darwin permits only root-owned sticky `/private/tmp` or `/private/var/tmp`, matching native lines 52-55. A user-owned private sticky ancestor is rejected. Linux recognizes its corresponding system temporary paths. |
| Only exact root-owned macOS system aliases | Core lines 53-61 | Only non-leaf `/tmp` and `/var`, with the exact absolute or root-relative native target, are admitted. `/private` is separately checked as a root-owned non-link non-writable directory. Arbitrary user links and loops fail. |
| Missing suffix beneath an already trusted prefix is allowed for reads | Core lines 42-49 | Matches native early return for ENOENT. The reader then reports an absent marker as active. It does not require nonexistent directories to have an owner. |
| Creation proceeds component by component | Core lines 38-64 | Each prior existing component has already passed trust before a subsequent mkdir. New directories use a scoped umask 077 and are checked immediately afterward, including the EEXIST race path. |

The shell guard additionally rejects control characters, trailing separators and dot
components up front, and bounds the complete marker spelling to 4096 bytes in C locale.
These are conservative path refusals, not new authorization. The current whole-path dot
check at line 34 occurs before any `mkdir`, including when `..` follows a missing prefix.

The variable-valued slash replacement at line 33 normalizes duplicate separators in both
shells without inserting literal backslashes. The checked path is not merely advisory:
the reader assigns it to `file` at line 72; the writer assigns it at line 101 and uses that
value for its temporary directory, revalidation, and final rename. System aliases therefore
cannot redirect later operations through an unchecked old spelling.

The native reader has stronger descriptor-level checks: `O_NOFOLLOW | O_NONBLOCK`, fstat
identity/type/ownership checks, and inode matching at native lines 111-127. The shell still
uses its existing bounded `read` redirection. This change does not add those native FD
guarantees or claim protection against hostile same-UID mutation between shell checks and
open. The newly checked nonreplaceable directory ancestry prevents the other-UID ancestor
substitution relevant to this slice.

## Parsing, copies and fail-closed behavior

Core lines 79-88 preserve the existing maximum 128-byte read and exact two permitted
serialized strings. A full 128-byte read remains unavailable. Content is never sourced or
evaluated. The only parser-related addition is `LC_ALL=C`, which makes the byte/count
assumptions explicit. Unknown, malformed or unsafe storage leaves the status unavailable.
The predicate at lines 92-95 returns true for unavailable as well as suspended, so those
states cannot authorize restrictive painting.

I compared the complete `_trusted`, `_path`, `_read` and `_suspended` blocks in both source
files. They are currently byte-identical after trimming the surrounding blank lines.
The standalone shellrc has the same storage decision as the core helper.

## Writer lifetime and failure paths

The writer at core lines 98-121 is a function with a subshell body. Its umask, EXIT cleanup
and HUP/INT/TERM traps remain scoped to that invocation. Directory creation has its own
subshell umask as well. No caller descriptor is replaced.

The temporary is obtained from `mktemp` in the checked marker directory, written only
after successful allocation, and tracked in an initially empty local variable. Each
failure after allocation reaches the scoped EXIT cleanup for that exact temporary.
There is no glob cleanup or removal of a caller-owned unrelated file. A successful rename
clears the temporary variable, so EXIT cannot delete the marker after publication.

Before rename, the writer repeats the path guard, requires the same physical spelling,
and repeats the existing leaf's regular-file/non-link/ownership check. Failed validation
or rename returns failure; none is converted into successful persistence. The old marker
is not opened for truncation. A failed creation can leave already-created private
directories, as the native component-by-component creation can; no foreign directory is
adopted, chmodded or repaired.

## Helper-dispatch ordering

`cmd-recover.sh:31-34` returns on writer failure before selecting or executing a helper.
The helper capability query begins only at lines 42-45, and recovery dispatch is at 53-54.
The new `cmd-recover.bats:98-107` fixture checks a permission refusal, unchanged previous
marker bytes, nonzero status, and absence of the capture file. That capture includes the
capability query, so the assertion excludes even an early helper query.

Shell startup has a different existing contract: `tavs-shellrc.sh:162-174` still registers
the terminal before reading the suspension predicate, then omits current-policy dispatch
for unavailable/suspended storage. Registration is not restrictive painting;
`visual-recovery.swift:246-249` caches the binding and returns no payload for `.register`.
This diff does not change that startup ordering. The pre-helper permission refusal claim
above is specifically the recover CLI's persistence boundary.

## Tests and smallest useful additions

The new Bats cases check unsafe marker/final-parent/HOME modes, an unsafe prefix above a
missing suffix with no directory creation, foreign marker/ancestor metadata, arbitrary
links and loops, physical and lexical system spellings, readable 0644 markers, private
creation, and whole-path dot refusal. Existing content fixtures, special-file refusal,
inaccessible parent handling, absent suffixes, persistence and explicit resumption remain.
The foreign stat double compares a resolved physical path, matching the guard's input
after system alias handling.

Two precise coverage gaps remain in the source read:

1. A failure after `mktemp` is not injected. One case overriding `mv` to return nonzero
   could assert failure, exact previous marker bytes, no `.visual-restrictions.*` leak,
   and unchanged caller umask/trap. A guard failure on the second path check would also
   exercise the new cleanup branch. Current source checks and traps look correct.
2. The creation fixture at test lines 114-135 uses the same `$HOME/new/nested/state` for
   both shells. The Bash iteration creates the directories, so the zsh iteration tests
   reuse rather than zsh creation. Use a per-shell private path if that distinction is
   intended to be covered by the committed regression.

These do not require another production mechanism or a broader trust framework.

## Independent private probe and limits

Artifact: `/tmp/tavs-marker-guard-check-20261015.bovsf2jq/results.json`.

For both `/bin/bash` and `/bin/zsh`, and separately for core and shellrc definitions, the
guard-only probe verified:

- A trusted missing suffix returns its physical path without creating it.
- Creation produces new 0700 directories.
- An unsafe existing prefix and a dot component fail before creating their suffix.
- Duplicate separators normalize correctly, arbitrary user aliases fail, and a
  user-owned sticky ancestor fails.
- Lexical `/tmp` resolves to the expected `/private/tmp` physical path.

Each shell/library combination used its own fresh private HOME/tmp/runtime fixture.
No helper selection or native helper dispatch occurred. This is Mac shell/guard evidence;
it does not establish Linux runtime acceptance, full-suite results, physical terminal
behavior, or another provider's approval. `git diff --check` passed during this review.

Observed method: compare native ownership/alias/absence rules directly, trace creation and
publication in order, compare the embedded copies, then probe only the remaining concrete
guard semantics under private roots. No project session-log edit was made in this read-only
scope; the parent can capture the combined session.

## Addendum: Bash 5.3 versus 3.2 persistence investigation

The current source read confirms the earlier two test suggestions are implemented:
per-shell creation paths at `visual-restrictions-state.bats:117`, and injected rename
and second-validation failures at lines 150-175. The latter requires nonzero status,
unchanged old marker bytes, and absence of marker temporaries after both shells run.

I compared `/bin/bash` 3.2.57 with `/opt/homebrew/bin/bash` 5.3.15 using only fresh private
HOME/tmp/runtime roots and the current shell guard/writer functions. The probe and results
are retained at `/tmp/tavs-marker-bash-versions-20261015.rta1w5ur/`. Each initial save and
subsequent resume used separate owned shell processes, matching that part of the Bats
contract. Both versions used the same explicit tool PATH, with Homebrew first.

| Private cases per Bash version | Observed result |
| --- | --- |
| Initial true write, no xtrace | Status 0, exact true bytes, no temporary leak |
| Existing-marker false write, no xtrace | Status 0, exact false bytes, no temporary leak |
| Initial true write, xtrace | Same successful result |
| Existing-marker false write, xtrace | Same successful result |
| Injected rename failure | Status 1, exact previous true bytes, no temporary leak |
| Injected second-validation failure after temporary creation | Status 1, exact previous true bytes, no temporary leak |

All twelve invocations retained the caller's trap definition and umask 0027. There was no
observed Bash-version difference in the path assignment, command substitution, writer
subshell, successful EXIT cleanup, or failed-publication cleanup. The traced stderr files
and the exact probe source are retained beside `results.json`. This was a bounded probe,
not a claim that intermittent integration failures have been reproduced or fixed.

I also read the specified retained logs. `iWgpsp/command.log` records the initial persistence
assertion failure, and `JI11l9/command.log` records the later resume assertion failure.
Those logs do not include a failing writer branch or command diagnostic. The retained
`IyVFAO/marker-writer-initial.log` and `marker-writer-resume.log` both reach successful
`mv`, clear `tmp`, execute `return 0`, and finish with the successful empty-temporary EXIT
trap. The combined log read also marks the targeted persistence test successful. These
successful traces cannot identify the cause of the earlier failed invocations.

No real source-semantic difference explaining the failure was identified. There is no
evidence here supporting an attribution to load, caching, or Bash 5.3 itself. Keep the
nonzero-status assertion and retain the next actual failing invocation's trace rather
than selecting another interpreter to make this leg pass. The smallest discriminating
diagnostic is the existing retained failing xtrace, with `BASH_VERSION` and resolved tool
paths recorded in that child. If it stops on an empty failed stat assignment, capture
that command's currently suppressed stderr and status in the private fixture while
preserving its normal stdout and return value. No production change is justified by the
evidence currently available.
