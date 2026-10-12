# Organizer and reversible focus roadmap

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.1

The current work follows the [agreed SPEC](specs/tavs-priority-discovery_2026-10-04/SPEC.md)
and [implementation progress](specs/tavs-priority-discovery_2026-10-04/PROGRESS.md).

## Verified source

- Native surface catalogue and exact navigation, Sessions rows and retained priorities.
- Typed observations, ordinary background intent and persistent visual suspension.
- Independent bounded recovery, current-policy output and complete hook render transactions.

Source and owned-terminal checks pass. Required physical Ghostty/UI acceptance remains open;
the current source has not been deployed to the installed application.

## Phase 7 in progress

Preview color composition reuses the existing hex/luminance/contrast math. It chooses a bounded
tint from current ordinary intent or configured defaults, preserving configured normal-text
contrast of 4.5:1 or the existing lower baseline. Unsafe or negligible results are unavailable.
Configured colors guide styling; they do not describe arbitrary running-program colors.

Preview ownership uses a separate two-second record so clearing it preserves an underlying
selective lease. Recovery cancels both. The controller now has one selection expiry timer and
independent cleanup, with stale callback rejection and retained failures. Color resolution is
bounded and validates configuration before parsing canonical output. Unsupported dual-theme
appearance is explicit. Selection/GUI recovery wiring, copied-install coverage and visible
acceptance remain pending.

## Later phases

Manual captured working sets follow Phase 7. Automatic attention focus follows manual focus.
Other terminal adapters, notifications, analytics and stronger locks remain deferred by the SPEC.
