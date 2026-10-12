# Organizer and reversible focus roadmap

Last Updated: 2026-10-13 (Europe/Vienna)
Version: 1.7

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

## Phase 8 source verified; native acceptance pending

Phase 8 now has a tested transform and dynamic writer for current/reset intent, visible neutral
changes and configured-text contrast bounds. Separate focus records survive pause/preview;
ordinary writes do not renew ownership, and old recovery revisions cannot rearm a lease.
Captured native IDs now stay independent of browsing and priority edits. New surfaces remain
outside the set; confirmed last-member closure ends Manual. One Sessions refresh timer remains
active while the window is open or Manual is active. Missing coverage invalidates queued updates
without dropping logical membership; no verified working binding means no outside paint.
Manual runs retain revision pins through cleanup and replace expired IDs, including after an
unmapped target returns. Focus Off clears only manual styling; recovery and restart leave Off.
Sessions/menu controls and working-set labels are connected. The private fixture verified
captured membership while browsing, but current Computer Use attachment attempts time out.
Physical dimming/readability, recovery controls in Manual and window close/reopen acceptance
remain unverified. The installed app has not been changed.

## Later phases

Phase 9 has a tested pure occurrence reducer: activation baselines, independent High cues,
permission episodes, supported completion deduplication and exact acknowledgement snapshots.
Consumed IDs prevent replay after acknowledgement, downgrade or temporary missing coverage.
Unknown/unverified signals and ambiguous late permission companions cannot create cues.
The permission classifier now requires a recognized event rather than generic Notification.
Only the latest hook observation is stored, so overwritten episode boundaries remain unknown.
Automatic mode, renderer integration, navigation acknowledgement and GUI controls are pending.
Native acceptance remains required across all product phases; the installed app is unchanged.
Other terminal adapters, notifications, analytics and stronger locks remain deferred by the SPEC.
