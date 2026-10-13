# M5 lookup diff follow-up review

Last Updated: 2026-10-13 (Europe/Vienna)
Version: 1.0
Product checkpoint: `70e5e74`. Review was source-only before the commit.

Reviewed the current uncommitted changes in terminal-visual-state.swift,
visual-recovery.swift, terminal-visual-state-tests.swift and visual-recovery-tests.swift.
Read source and the supplied Foundation enumeration probe only. No commands that
build, test, launch apps or access devices/native catalogues were run.

## Concrete defects introduced by this diff

None found within the requested scope.

## Verified source behavior

- cachedRecords(tty:) starts at targets/key(tty), not the owner directory. Every
  owner-generation branch beneath the requested TTY remains enumerated.
- Both bindings and effects remain collected; resolution still unions their
  target bindings. An effect-only native binding remains a candidate, without
  requiring a target.json beside it.
- Both targets and the selected TTY bucket are lstat-checked as actual directories
  before enumeration. A static symlink at either level returns an unreadable path
  and empty records. Descendant symlinks still return unreadable and are never
  parsed as target/effect records.
- The supplied enumeration-probe.log shows the exact prior skipDescendants fault:
  skipLinks=true enumerated 11-100-1 but omitted its plain/target.json subtree;
  skipLinks=false enumerated that subtree and did not enter linked-records.
  Removing skipDescendants from the symlink branch is supported by this evidence
  and retains link rejection. The extra comment describes the observed reason.
- The same record parser is used for scoped and full calls. Target schema=1,
  validate(target), effect schema/payload checks, canonical placement checks,
  bound-intent validation and read's regular-file/size/no-follow checks persist.
- target(tty:owner:) still captures the continuing owner, validates generations,
  rejects another live physical owner, prefers at most one native alias and
  enforces allowedSurfaces. cachedTarget keeps preferredTarget's identical guards.
  equivalentBindingsUnlocked and held-lock write validation are untouched.
- apply(_:) and reconcilePriorEffects() retain cachedRecords() with no TTY scope.
  Thus full recovery and prior-effect enumeration still see unrelated records and
  unreadable paths. Removing the faulty skipDescendants also allows them to retain
  healthy sibling records that the old scanner could accidentally prune.

## Added tests inspected

The tests explicitly cover scoped isolation from another TTY's corruption/link,
all same-TTY owner branches, an effect without target.json, missing TTY buckets,
symlinked targets and TTY roots, descendant symlinks, malformed records and
misplaced effects. Full snapshot assertions retain unrelated records/corruption.
The recovery tests add cachedTarget rejection for two native aliases and two live
owners. Existing tests still exercise target and generation/allowlist behavior.
No new source-level fixture error was found: the hardcoded native effect path
matches generation(11), surface().id/application(43), terminal-43 and key().

## Pre-existing limitations, not defects introduced here

- target/cachedTarget ignore snapshot.unreadable and filter non-valid generations.
  They do not themselves reject every malformed or unavailable cache record.
  Later held-lock alias validation is stricter. This diff leaves that policy intact.
- Organizer ancestors above targets are not rejected by this scanner. It checks
  targets and, for scoped calls, the selected TTY root. Existing TOCTOU limitations
  of filesystem enumeration likewise are not solved or expanded into new machinery.
- Scoped discovery still traverses all retained history for the requested TTY.
  It removes unrelated TTY work; it does not add deadlines or a cache index.

Validation limit: this is a source review plus inspection of the parent's supplied
probe log. It does not claim the current tests pass or provide native acceptance.
