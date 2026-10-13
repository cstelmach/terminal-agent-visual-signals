# Final review leads and verified corrections

Last Updated: 2026-10-13 (Europe/Vienna)
Version: 1.0
Original review target: `5bd0bd2`, implementation base `e113fb8`.
Corrected product target: `71e0f60`.

## Review execution status

Neither original provider invocation produced an accepted final review. Codex's native call
exited zero and returned four concrete leads, but omitted the required scores, phase coverage
and verdict. Claude's Hub stage exhausted 1800 seconds with SessionStartTimeout; its automatic
fallback failed report validation. No scores or readiness verdict are inferred from either.

- [Codex failure](final-codex-failure-2026-10-13.md) and
  [imported raw leads](final-codex-raw-2026-10-13.md).
- [Claude failure](final-claude-failure-2026-10-13.md), including retained diagnostic paths.
- [AGY unavailable](final-agy-unavailable-2026-10-13.md): the installed fingerprint requirement
  still conflicts with the user's instructions. No provider dispatch or fingerprint occurred.

Fresh Codex file-mode profile execution and explicitly selected Claude CLI wrapper reviews
were requested for corrected target `71e0f60`. They cover all nine phases and the original
83 changed non-Markdown product/test paths, with adjacent dependencies. They are pending;
this document is parent verification of leads, not a substitute final provider verdict.

## Findings adjudicated against source and execution

1. **Queued full render (`4940466`).** An owned-PTY open barrier reproduced stale output after
   recovery and resume. Pin the marker before open and compare under output serialization;
   fresh hooks remain allowed.
2. **Delayed tool-error restore (`9f660ef`).** A real adapter/core PTY test reproduced legacy
   `processing` after a newer Stop. Check retained delivery before launching the synthetic trigger.
3. **Idle notification handoff (`95a391f`).** A real Stop-to-idle test reproduced a delivery
   mismatch and absent graduated color. Restart with current context at the first idle stage.
4. **Exited-producer timeout reset (`71e0f60`).** Entry/owned-PTY tests reproduced code 3, no reset
   and retained idle intent despite a live shell. Use its validated cached binding and unchanged
   observation/latest bound intent.

The cleanup fix checks current intent identity before both live and orphaned publication paths,
then repeats validation after device open. It rejects missing bound orphan intent, newer delivery,
new standalone intent and owner reuse. Forced resets also pin the recovery revision, preventing
late palette or directory-title output after suspension changes. The original 100 ms writer
budget covers these checks; no helper verb, title guessing or native catalogue access was added.

An independent [focused source check](forced-reset-followup-2026-10-13.md) found a race in the
first cleanup draft: live publication could overwrite a newer standalone intent and become its
own bound evidence after producer exit during open. `TtcCjQ` reproduced three assertions.
The common unchanged-intent guard fixes it before the first mutation. A further green regression
checks standalone intent arriving during open. This source check found no further concrete
bypass within the one-delivery-per-intake contract; it ran no builds, tests or device operations.

## Verification and retained failures

All runs use `tests/run-isolated.sh`, explicit source-built helpers, private roots and owned PTYs.
Log IDs below belong to
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.ID/command.log`.

| Check | Result | Log ID |
|---|---|---|
| Queued-render initial regression | Four assertions failed before correction | `DgsRi0` |
| Tool-error-to-Stop regression | Failed with unexpected processing | `8urFZB` |
| Stop-to-idle handoff regression | Failed with retained completion delivery | `9PIOVW` |
| Exited-producer reset regression | Code 3, missing bytes and unchanged color | `iwLJPF` |
| Live-to-orphan standalone-intent race | Three assertions failed before common guard | `TtcCjQ` |
| Final full Swift suite | 497/497, 8.040 seconds, no warnings | `L6yRjc` |
| Final product release build | Passed in 11.86 seconds | `c7aA6M` |
| Broad isolated Bats audit | 165/165 before final common-intent guard | `uaFGiJ` |
| Audited Python modules | 230/230, 10.02 seconds | `6bEfyY` |
| Final release-helper connected Bats | 50/50 after common-intent guard | `CKXAQ5` |

Fixture failures are retained separately: immutable-context assignment (`HT7w0o`), stale simulated
ancestry (`6voVmp`), future virtual timestamp (`eJFKcV`) and throwing code in a nonthrowing open
seam (`5aJZRM`). Corrected fixtures precede passing runs. They are not product regressions.
The default Python lacked pytest (`xXZPzS`); the installed `pytest` command passed without any
dependency installation. The final during-open case was added after the guard and is a green
check, not claimed initial red evidence. Scratch/backups: `/tmp/tavs-final-review-fixes-20261013/`.

## Remaining work

Read and verify fresh provider reports before acting on findings. Active-cue UI, relaunch UI,
and the required physical/native cases in Phases 2/7/8/9 remain incomplete. Ghostty access was
denied; no alternate native automation, device painting, installation, sync, personal preference
or schedule change, or shutdown of a user session occurred. The earlier owned fixture remains
running; its relaunch Computer Use attachment timed out. No repeated unchanged retry occurred.

The SPEC body and PLAN are fixed. Phase 9 remains In Progress; the master goal remains active.
