# Bug Reference

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0

## Development app runs without showing Sessions

The isolated test app started successfully but appeared not to open. Its accessory activation
policy and leading MenuBarExtra left it without a Dock icon or initial window. Computer Use
could not bind that menu-only app, preventing the requested development checks.

The isolated app now uses regular activation and a primary Sessions window. Its staged bundle
sets `LSUIElement=false`. Production retains its existing menu-bar behavior. The test branch
still omits scheduler discovery, personal preferences and login registration.

Verification: 237 Swift tests pass; release build and bundle validation pass. Computer Use
opened the window, read the fixture banner and verified three-row multiselection. Runtime
metadata reports activation policy 0 (regular). Native Ghostty navigation remains unverified.

Prevention: staged UI acceptance must prove a visible window, not merely a running process.
Keep test-only launch metadata aligned with the delegate's activation policy.

## Isolated launch rejects the valid `/tmp` alias

The earlier test-root guard assumed Foundation would resolve `/tmp` to `/private/tmp`.
On this host it retained `/tmp`, causing Cocoa error 258 and exit 1 for the staged fixture.
Compare against the resolved system temporary root instead of assuming its spelling.
`testIsolatedLaunchAcceptsTheSystemTemporaryAlias` reproduced the failure before the fix.
Personal-root and escaping-fixture rejection tests still pass.

Further evidence and remaining acceptance:
[progress log](specs/tavs-priority-discovery_2026-10-04/PROGRESS.md).
