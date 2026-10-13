# Verification failure diagnosis

Scope: read-only source and owned logs/fixtures. No tests, builds, device writes, app or native calls.
Baseline requested: c6b4d2c. Current git diff has five files, including shell integration text and the
Swift cleanup catch. I did not edit tracked files.

## Bats lJxcb9

Source log: /var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.lJxcb9/command.log
It records exactly three failing cases, 162, 171, and 175 (175/178 passing).

1. Priority case 175: verified managed permission render failure.
   - priority-1/pty-1.out contains two successful pause batches, with
     `Managed output unavailable.` and `tavs: current render unavailable` between them.
   - priority-1/permission.json is identical to first.json: background #112233 and delivery
     C12C9520-2BF8-4173-8782-5982CD06C073. It did not publish permission color #445566.
   - The final intent is #112233 with a new delivery C1962330-A2E3-4163-BAC9-E6BDCCC4C07C.
   - Python line 7 is the expected three-color assertion, not the grace-period check.
   - trigger.sh ends with `_tavs_render_flush || true; exit 0`, explaining why the PTY
     process status passes while a failed permission render leaves the old intent.
   - The helper's managed-output-entry.swift general catch maps all other errors to the
     same `Managed output unavailable.` message. The actual underlying Swift error is
     absent. A timeout/deadline or other storage/target failure remains unproven.
   - OvWVpc's priority-1/pty-1.out contains three successful pause batches with no error.

2. Standalone case 162: only nonzero child exit is retained.
   - background-intent.bats:117 fails immediately after send_osc_bg reset in an owned PTY.
   - The test does not print `$output` on this failure, unlike the recovery case.
   - send_osc_bg returns managed-render failure except status 3, which it normalizes to 0.
     Therefore a stale-context status 3 alone cannot explain the failing exit assertion.
   - Its fixture uses BATS_TEST_TMPDIR. No retained corresponding fixture was found under
     the owned isolated root. Exact child diagnostic and exit code cannot be recovered.

3. Recovery case 171: failure occurred during recover, before resume.
   - Log contains RECOVER_BEGIN and reset OSC 104/110/111, but no RECOVER_DONE or RESUME_BEGIN.
   - The set-e child next runs `tavs recover > recover.json`, then `test ! -e "$pending"`.
     It exited in one of those two steps; the log does not identify which.
   - Recovery's emergency reset invalidates pending before returning reset bytes.
     A reset batch alone does not prove whole-report success: apply() subsequently registers
     the native alias and can replace a restored item with a failed registration item.
   - The exact recover.json is needed to resolve that hypothesis. BATS_TEST_TMPDIR was not
     retained in the owned root, so the report and recovery-calls are unavailable here.

## Swift SmKc4f

The log explicitly names cleanup-probe `deviceWriteTimedOut("/dev/ttys028")` at test call sites
496 (physical aliases/reused lifetimes) and 541 (emergency admission independence).
The old waitForAdmissionRelease retried EBUSY but immediately failed any timeout. Each probe
uses a real bounded write with nil preparation. Its own scheduling/open/lock path can expire
within the existing 100 ms production budget, even while the outer cleanup budget is 1 s.
The new catch retries this specific timeout within the existing 1 s loop. It preserves the
requirement for eventual successful admission and no paint. Its efficacy is not verified here.

## Actionable next check

Preserve the Bats temporary directory on the next authorized run and print failed standalone
`$status/$output`, plus recover.json when recover fails. Do not classify the three Bats failures
as system pressure or a cache regression from the present evidence. The verified priority
failure is a real failed publication, masked by the core's normal exit behavior; rerun success
would establish intermittency, not identify the underlying Swift error.
