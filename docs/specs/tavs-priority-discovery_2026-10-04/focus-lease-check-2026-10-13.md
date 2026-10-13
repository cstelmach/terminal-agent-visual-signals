# Per-physical focus lease source investigation

Reviewed baseline `3b69d1d` and the current uncommitted source/tests on 2026-10-13.
Read-only scope: no builds, tests, running-process inspection, native/device calls or peer reports.
All source paths below are under
`/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/`.

## Verdict

The lease change bounds controller ownership to one lease per physical target and one caller-level
clear in flight per lease. Healthy target IDs no longer depend on unrelated target success.
No confirmed new debt-loss, pin-loss or DispatchGroup imbalance was found in the reviewed paths.
The full background-only guarantee is incomplete because of the existing shared legacy-reset path.

## Actionable finding

- [P2, existing baseline behavior] A focus clear can reset foreground and palette after a global
  rule ends. `Sources/TAVSApp/visual-recovery.swift:312-316` returns only background bytes while
  a current rule exists, but `:331` sets `resetLegacy` whenever cached active globalRestriction
  metadata remains. With no current rule, `:378` emits OSC104 and OSC110 before background.
  Reproduction from source: paint focus; activate a global rule and call currentRestriction;
  end that rule without first reconciling its cached record; clear painted focus with requested
  restoration. Its output is not limited to OSC11/111. The added test at
  `Tests/TAVSAppTests/visual-recovery-tests.swift:238-247` covers the current-rule branch only.
  Recommendation: make focus clear explicitly omit legacy foreground/palette reset bytes and
  add the ended-rule case if strict background-only restoration is the intended contract.

## Verified source properties

- Healthy reuse is per physical target (`focus-controller.swift:414-423`); only that target's
  successful metadata save updates its heartbeat (`:314-323`). Failed targets retain one old
  lease instead of creating retired Runs on each catalogue tick. The added regression at
  `focus-controller-tests.swift:565-605` checks stable healthy ID/heartbeat and bounded attempts.
- Stale owner/version/retiring checks occur in `focus-controller.swift:408-411`; recovery checks
  the request repeatedly before save (`visual-recovery.swift:262-282`). Cancellation holds the
  same TTY writer lock as publication (`:185-201`). A save that wins that lock records possible
  paint unconditionally even if the catalogue changes meanwhile (`focus-controller.swift:318-319`).
- `mayHavePainted` precedes actual device output; completed `.unaffected` results restore the
  captured prior debt (`focus-controller.swift:326-335`). Failures keep the conservative debt.
  Removal requires restoration/vanishing or cancellation plus no paint possibility (`:461-468`).
- An unresolved old lease cannot be replaced. A resolved lease transfers debt into the fresh
  lease under the controller lock (`focus-controller.swift:430-446`). Leases hold the revision
  and owner (`:528-540`), retaining its open inode pin (`visual-restrictions-state.swift:68-73`).
  Changed markers prevent old restoration (`visual-recovery.swift:289-293`) without discarding
  painted debt; a fresh explicitly current run can inherit it after metadata cancellation.
- Group entries are guarded by `clearing` (`focus-controller.swift:425-432,475-478`); every clear
  returns through its leave (`:470`), with the weak-self queue branch also leaving (`:482-484`).
  The shared preparation wait retains its deadline across recursion; each device call separately
  keeps the existing 100ms outer deadline (`ProcessRunner.swift:217-229`).
- Request factory fanout keeps duplicate native-alias and cross-lifetime TTY conflict rejection
  before creating leases (`visual-recovery.swift:517-535`). The added factory tests at
  `visual-recovery-tests.swift:208-235` cover both. Stored alias ambiguity also rejects output
  (`terminal-visual-state.swift:303-344`). This validates the passed outside targets, not every
  row including the working set (`focus-controller.swift:268-270`). That input scope predates
  the diff and should not be described as full-row-catalogue validation.
- Switching modes retires all leases and clears pending/latest requests (`:135-151,230-242`);
  outstanding update callbacks recheck owner/version before status publication (`:344-345`).
  Existing SystemProcessRunner admission still bounds a wedged admitted device worker per
  physical lifetime (`ProcessRunner.swift:239-256`); this diff does not add cancellation of
  workers blocked in kernel calls. Clear coalescing bounds caller work, not every possible
  pre-admission filesystem stall, which remains an existing deadline limitation.

## Focused remaining coverage

Root should run existing tests and verify: a save followed by catalogue-version invalidation;
one clear timing out while a new request waits; metadata-success/device-failure debt transfer;
masked `.unaffected` completion concurrent with Focus Off; and ended-global-rule clear bytes.
These are proposed tests, not assertions of observed runtime failure.

## Follow-up on suppression and retirement fixes (2026-10-13)

Scope: freshly reread current focus-controller/visual-recovery source and the new failure,
mode-change and ended-global-rule tests. No builds/tests, device/native calls or source edits.
Earlier line references describe the earlier snapshot; references below describe this reread.

- No additional confirmed defect found. The earlier background-only finding is addressed in
  source: requested restoration returns background bytes before legacy-reset assembly
  (`visual-recovery.swift:381-384`); current rules also return background only (`:315-319`).
  Global metadata can be canceled but its record remains, allowing reconciliation to detect
  and reset legacy colors (`:334-338`). The new test at `visual-recovery-tests.swift:250-264`
  exercises both the restricted focus clear and subsequent full reconciliation.
- Optional restoration has coherent semantics: nil retains exact-effect legacy behavior;
  false returns no bytes after beforeOpen cancellation; true recomposes current background
  while checking the same pinned revision (`visual-recovery.swift:185-201,288-296`). False
  cannot suppress a possible focus paint that already saved metadata: that writer holds the
  same TTY lock through unconditional didRenew (`:283-284`) before cancellation can acquire it.
  A writer that runs later sees retirement/version invalidation before save or a canceled
  effect rejected by saveEffectUnlocked. Failed writes retain the conservative possible debt.
- Late `.unaffected` completion cannot erase retirement debt now: it restores priorPaint only
  for the identical non-retiring lease under the controller lock
  (`focus-controller.swift:332-338`). Retirement flags never revert, so a concurrent failed
  restoration cannot have its debt flag cleared by an older masked request's completion.
  A masked request retiring before that completion may conservatively trigger restoration;
  retaining that obligation is sound because retirement may itself already have attempted paint.
- Completion retry now requires both wanted and explicitly blocked target state
  (`focus-controller.swift:497-504`), preventing an unrelated finished clear from replaying a
  successful catalogue update. Blocks are recorded only for the current owner/version (`:301-304`)
  and cleared on a fresh preparation, mode retirement or catalogue unavailability.
- Test source now checks repeated explicit mode changes cannot publish a new ID while old
  cancellation fails (`focus-controller-tests.swift:619-658`), alongside the finite failed-target
  sequence (`:569-616`). Execution results remain root-owned and unverified by this investigation.
- Useful remaining focused assertion: an explicit false restoration with a matching focus
  record should acknowledge cancellation and emit no bytes, including under a global rule.
