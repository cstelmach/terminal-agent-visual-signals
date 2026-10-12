# Organizer and reversible focus roadmap

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.3

The current work follows the [agreed SPEC](specs/tavs-priority-discovery_2026-10-04/SPEC.md)
and [implementation progress](specs/tavs-priority-discovery_2026-10-04/PROGRESS.md).

## Verified source

- Native surface catalogue and exact navigation, Sessions rows and retained priorities.
- Typed observations, ordinary background intent and persistent visual suspension.
- Independent bounded recovery, current-policy output and complete hook render transactions.

Source and owned-terminal checks pass. Required physical Ghostty/UI acceptance remains open;
the current source has not been deployed to the installed application.

## Phase 7 source verified; native acceptance pending

Preview color composition reuses the existing hex/luminance/contrast math. It chooses a bounded
tint from current ordinary intent or configured defaults, preserving configured normal-text
contrast of 4.5:1 or the existing lower baseline. Unsafe or negligible results are unavailable.
Configured colors guide styling; they do not describe arbitrary running-program colors.

Preview ownership uses a separate two-second record so clearing it preserves an underlying
selective lease. Recovery cancels both. The controller now has one selection expiry timer and
independent cleanup, with stale callback rejection and retained failures. Color resolution is
bounded and validates configuration before parsing canonical output. Unsupported dual-theme
appearance is explicit. Sessions selection, Clear Preview, Escape and window close are connected.
Menu and Sessions recovery share the current-bundle headless client and display partial failures.
The signed fixture app verified priority/suspension retention through relaunch, recovery controls
and explicit unavailable preview status. Fake installations now verify copied recovery, adapters,
hook definitions, shell source and the Codex installer. The unused legacy reset method and its
four dedicated tests are retired; scheduler suspension tests and independent recovery remain.
Physical Ghostty acceptance is still blocked. Fixture checks do not establish real terminal
highlighting or navigation, and no production deployment has occurred.

## Later phases

Manual captured working sets follow Phase 7. Automatic attention focus follows manual focus.
Other terminal adapters, notifications, analytics and stronger locks remain deferred by the SPEC.
