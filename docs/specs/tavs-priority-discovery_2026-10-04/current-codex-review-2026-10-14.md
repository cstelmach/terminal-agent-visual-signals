# TAVS current implementation Codex review

Last Updated: 2026-10-14T12:31:58
Version: 1.0

## Invocation and result

- Wrapper status: SUCCESS. All three canonical provider passes completed and were evaluated.
- Review target: current tracked implementation at commit `7ecfba2`, file mode, full depth.
- The checkout was clean at dispatch and remains clean at final inspection, with HEAD `7ecfba2`.
- Scope: three caller-supplied cohesive partitions (20, 32 and 66 target entries).
- Focus: all nine PLAN phases against SPEC D01-D18, exact native targeting, reversible
  visual-only composition/recovery, observation occurrences, delivery and existing compatibility.
- Repository read-only: no edits, builds, tests, native requests, app/container launches,
  installations, real-home operations or terminal output. Wrapper writes stayed under `/tmp`.
- No other reviewer output was read. No provider failure, restart, automatic continuation
  or silent scope reduction occurred. The first two providers attempted a report write that
  their read-only sandbox rejected; they returned complete final reports and exit/lifecycle
  checks passed. Raw output retains those messages. The runner persisted all report evidence.

## Canonical reports and execution

| Partition | Raw and evaluated report | Evidence | Thread |
|---|---|---|---|
| Native catalogue, Sessions and focus | [codex-review-files-terminal-agent-visual-signals-tavs-native-sessions-focus-20261014_113807.md](/private/tmp/codex-review-files-terminal-agent-visual-signals-tavs-native-sessions-focus-20261014_113807.md) | [codex-review-artifacts-files-terminal-agent-visual-signals-tavs-native-sessions-focus-20261014_113807](/private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-native-sessions-focus-20261014_113807) | `01a139c6-bb39-7a73-8f47-516517ceb218` |
| Visual state, recovery and scheduler | [codex-review-files-terminal-agent-visual-signals-tavs-visual-state-recovery-20261014_115422.md](/private/tmp/codex-review-files-terminal-agent-visual-signals-tavs-visual-state-recovery-20261014_115422.md) | [codex-review-artifacts-files-terminal-agent-visual-signals-tavs-visual-state-recovery-20261014_115422](/private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-visual-state-recovery-20261014_115422) | `01a139d5-9b0e-7af3-91fa-6f4dacb33797` |
| Ordinary hooks and shell delivery | [codex-review-files-terminal-agent-visual-signals-tavs-ordinary-shell-delivery-20261014_121013.md](/private/tmp/codex-review-files-terminal-agent-visual-signals-tavs-ordinary-shell-delivery-20261014_121013.md) | [codex-review-artifacts-files-terminal-agent-visual-signals-tavs-ordinary-shell-delivery-20261014_121013](/private/tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-ordinary-shell-delivery-20261014_121013) | `01a139e4-228b-7f60-9397-82e2ddefa8be` |

- Requested/default delegated engine: Sol; configured model: `gpt-5.6-sol`.
- Requested level/floor and effective effort: full/xhigh throughout; no effort increases.
- Profile: canonical `code-review`, include-all-confirmed noninteractive policy.
- Original start: Unix `1791970687.162588`; whole-review allowance: 7200 seconds.
- Provider completion elapsed from that shared start: 2899.409 seconds (48.32 minutes).
- Serial partitions shared the original clock using `--previous-report`; no fresh budgets.
- Model/effort are configuration evidence, not server attestation.

## Evaluated findings synopsis

Counts: **CRITICAL 2, IMPORTANT 8, MINOR 1**. All 11 raw findings received a verdict.
One severity was upgraded; the installer false-success subclaim in partition 1 was technically
falsified for the normal CLI entry. No host-only finding was added.

| ID | Severity | Checked mechanism | Smallest direction |
|---|---|---|---|
| N1 | IMPORTANT | Cached rows authorize effects without a fresh native ID/TTY mapping | Fresh bounded native snapshot after color preparation, before capture/fanout |
| N2 | IMPORTANT | App destination is removed before replacement copy | Stage and validate before retiring prior bundle |
| N3 | MINOR | Automatic help names permission but omits completion | Describe both supported High-priority triggers |
| R1 | CRITICAL | Enabled decoded bad time reaches a forced parser | Validate loaded config; reject safely; eliminate trapping parser path |
| R2 | IMPORTANT | Failed projection commits transition/paint memory; no later repaint | Make persistence outcome visible and missed transition retryable |
| R3 | IMPORTANT | Enabled quiet rules without bounds validate and do nothing | Require kind-specific bounds for enabled rules |
| S1 | CRITICAL | Linux ordinary signaling cannot select a usable backend | Complete Linux generation/TTY proof and typed renderer, then kernel/PTy tests |
| S2 | IMPORTANT | Predictable runtime root lacks owner/mode/ancestor-link trust | Reject untrusted roots before policy read/registry/output |
| S3 | IMPORTANT | Child installer ignores subprocess failure and prints success | Explicit preview/apply status checks |
| S4 | IMPORTANT | Shared whole-file state/color updates lose concurrent TTY rows | Bounded transaction lock or per-TTY records across all mutations |
| S5 | IMPORTANT | lock-gate env-i drops roots/helper and tests obsolete pending bytes | Repair isolation first, then current owned-PTY policy assertions |

Important qualifications:

- N1: Current process/device checks block common exited-target cases. They do not prove the
  supplied native surface still owns that physical TTY. Native revalidation stays outside the
  unchanged 100 ms device deadline; serialized physical checks remain necessary.
- N2: Normal `tavs` has `set -euo pipefail` and a direct function call, so copy failure does
  terminate before its success print. The prior-bundle loss mechanism remains confirmed.
- R2: Missing or readable-unmuted policy makes the attempted restriction unaffected, so no
  failed-target retry is retained. Policy-read errors can follow a different retry path.
- S2: Confirmed exposure is fake rule/state interference and TTY registry names, not input
  injection or automatic readability of every victim-owned mode-0600 record body.
- S3: Agent installers are separate Bash processes without errexit; the main CLI option does
  not protect them. This differs from N2.
- S5: Do not run the existing fixture against workstation defaults to reproduce its leak.

## Scores and derived outcome

| Partition | Correctness | Security | Maintainability | Test Coverage | Performance | Evaluated grade |
|---|---:|---:|---:|---:|---:|---:|
| Native/Sessions/focus | 6 | 8 | 7 | 7 | 7 | 7 |
| Visual/recovery/scheduler | 4 | 8 | 7 | 6 | 8 | 4 (CRITICAL cap) |
| Ordinary/shell delivery | 4 | 5 | 6 | 5 | 6 | 4 (CRITICAL cap) |

Consolidated risk: **High**, because CRITICAL findings exist. Calibration verdict: **VETO**,
because evaluated correctness is below 5 in two partitions. No unsupported average of
partition scores is substituted for their independently evaluated five-dimensional scores.
Workflow SUCCESS means the requested review completed, not product approval or acceptance.

## Action plan and verification limits

Include all confirmed findings. Start with an owned file-load regression for R1, then choose
one bounded fix slice at a time. Repair S5 before running that suite. Complete the Linux
ordinary path with a real Linux kernel/owned-PTY acceptance environment before claiming restored
platform support. Use the discriminating test proposals and source citations in each evaluated
report; the parent must independently verify findings before source changes.

Native visual/navigation/readability/Spaces acceptance and Linux runtime acceptance remain
unverified. Historical first-paint, EPERM and fresh-render timeout causes remain unestablished.
The review establishes source mechanisms; it does not reproduce those runtime failures or
claim that prior green suites prove physical acceptance.

For future matching fixes limited to one listed concern and its connected callers/tests, a
partial/high file review is likely sufficient. This does not downgrade the requested full
review completed here and is not permission to skip broader final acceptance.
