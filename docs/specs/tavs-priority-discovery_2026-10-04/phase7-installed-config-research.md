# Phase 7 Ghostty configured-color contract

Read-only exploration on 2026-10-12. No Ghostty executable, AppleEvents, UI, device writer,
installer or build was run. The evidence below comes from freshly read repository files and
the installed app's own manuals and Info.plist, not a retained report summary.

## Verdict

Partial: local primary documentation answers command purpose, flags, syntax, theme variants,
color input formats and installed binary identity. It does not establish the CLI's canonical
color serialization or selected appearance when dumping a dual light/dark theme. Those are
the exact source-research gaps before accepting dual-theme output.

## Authoritative local contract

The installed manuals identify their version as `1.3.2-main-+260288614` on line 1 of both:

- `/Applications/Ghostty.app/Contents/Resources/ghostty/doc/ghostty.1.md`
- `/Applications/Ghostty.app/Contents/Resources/ghostty/doc/ghostty.5.md`

The installed `ghostty.1.md:297-327` documents:

- `+show-config` writes current configuration in valid Ghostty config-file syntax.
- Without flags it prints only values different from defaults, possibly nothing.
- Output order is unspecified. It preserves behavior, not input whitespace/comments.
- `--default` loads defaults instead of user configuration. It is unsuitable for resolving
  the user's configured colors.
- `--changes-only` controls changed-only output; `--no-pager` disables paging.
- `--docs` adds documentation comments and is unnecessary for the resolver.

The approved repository SPEC already names the exact argv:
`["+show-config", "--changes-only=false", "--no-pager"]` at
`docs/specs/tavs-priority-discovery_2026-10-04/SPEC.md:211-219`. It explicitly distinguishes
configuration loading from running per-surface colors, requires live acceptance for
light/dark and launch overrides, and forbids OSC query/reply capture.
`RESEARCH-REPORT.md:500-503` records the earlier source check, but does not preserve the
relevant upstream implementation text. SPEC line 555 links the primary loader source.

The installed `ghostty.5.md:19-25` defines `key = value`, ignoring whitespace around `=`.
Lines 63-66 explain valid empty assignments for default-valued optional keys. A parser must
not treat unrelated empty assignments as a whole-dump error. Background and foreground
themselves require a valid concrete color pair for this use.

At `ghostty.5.md:688-697`, both `background` and `foreground` accept `#RRGGBB`, `RRGGBB`
or named X11 colors. This describes accepted config input. It does not prove that a resolved
dump always serializes named colors as hex.

At `ghostty.5.md:631-680`, themes may be built-in names, user themes or absolute paths.
Explicit background/foreground/palette settings override theme colors. Separate appearances
use `light:theme-name,dark:theme-name`; whitespace is trimmed, ordering does not matter and
both sides are required. The desktop environment chooses the active appearance.

`window-theme` controls window presentation, per `ghostty.5.md:2411-2428`. Its `light`/`dark`
values must not be assumed to force the terminal theme or `+show-config` theme loading.

Config errors are not generally fatal, per `ghostty.5.md:73-87`; erroneous keys can use
defaults. Verify the specific `+show-config` error behavior upstream before assuming exit 0
alone means all user settings loaded successfully.

## Exact executable selection

There is no existing Ghostty CLI executable resolver in the repository. There is an existing
exact application selection pattern at
`src/macos/TAVSApp/Sources/TAVSApp/ghostty-catalog.swift:46-54`: live applications with
bundle identifier `com.mitchellh.ghostty`, requiring exactly one and resolving its verified
process generation. Native requests recheck that generation after completion at lines 122-132.

The installed `/Applications/Ghostty.app/Contents/Info.plist:51-58` confirms
`CFBundleExecutable = ghostty` and `CFBundleIdentifier = com.mitchellh.ghostty`.
The executable file is present at `/Applications/Ghostty.app/Contents/MacOS/ghostty`.
These were read as files only; they do not prove what PATH would select.

Use the application for the selected surface's verified process, not PATH or an assumed
`/Applications` location. The installed macOS SDK declares this supported API:

`/Library/Developer/CommandLineTools/SDKs/MacOSX26.1.sdk/System/Library/Frameworks/AppKit.framework/Versions/C/Headers/NSRunningApplication.h`

- Lines 94-101: `bundleIdentifier`, `bundleURL` and `executableURL`.
- Lines 160-165: running-app lookup by bundle identifier and by process identifier.

Small extension of the existing pattern: obtain the matching `NSRunningApplication` for
the surface's PID, check the bundle identifier and generation, take `executableURL`, run
the bounded config command, then recheck the generation. Return unavailable for absent,
ambiguous, missing-executable or stale matches. This is a design recommendation supported
by the local API contract, not an existing resolver implementation.

## Bounded implementation recommendation

Reuse `ProcessRunner.runBounded` rather than another subprocess wrapper. Current
`ProcessRunner.swift:32-79` caps the deadline at two seconds, drains both streams and
propagates nonzero exit. Lines 96-101 cap collected stdout at 1 MiB. Run resolution off the
main thread; do not block a preview-selection event while loading config.

For a small parser:

1. Decode complete output as UTF-8 and preserve failure for invalid encoding or oversized data.
2. Ignore blank lines and full-line comments. Split each relevant assignment at its first `=`;
   trim surrounding whitespace. Match exact `background`, `foreground` and `theme` keys,
   so `selection-background`, `cursor-color`, palette entries and doc comments cannot match.
3. Require exactly one concrete background and foreground. Reject repeated relevant keys
   rather than guessing a precedence. Do not strip `#` as an inline-comment marker: it is
   part of a color literal. Reject trailing tokens on relevant values.
4. Accept six ASCII hex digits with or without `#`, add `#` for the bare form, then reuse
   `PauseVisual.normalizedHexColor` (`PauseVisual.swift:16-25`) and `TerminalRenderer.Colors`
   (`terminal-renderer.swift:4-12`). Reject named colors and unsupported encodings until
   upstream serialization is established. Avoid an X11 lookup table or CSS color parser.
5. Until appearance behavior is verified, reject a dual-theme assignment containing
   `light:` or `dark:` even if a concrete pair appears in the dump. The dump alone currently
   does not prove that pair belongs to the visible appearance. A theme with a single ordinary
   name and a complete concrete pair is sufficient configured-color input.
6. Never supply guessed default colors for missing/unavailable output. Return unavailable,
   so the existing preview behavior can explain that no safe visible cue was produced.

The parser recommendation is deliberately narrower than Ghostty's full configuration input
language. It handles concrete resolved colors only. It does not claim to read current OSC
colors, launch overrides, application-painted cells, opacity-composited desktop pixels or
per-surface appearance.

## Parser and resolver fixtures

These are proposed fixture inputs, not captured Ghostty executions:

| Input or condition | Expected |
| --- | --- |
| `background = #171717` plus `foreground = #eeeeee` | `#171717`, `#EEEEEE` |
| `foreground= ffffff` plus `background = 282c34`, reordered and surrounded by whitespace | `#282C34`, `#FFFFFF` |
| Comment containing `background = #FFFFFF`, unrelated `selection-background`, empty `font-family`, real background/foreground pair | Ignore irrelevant lines; accept actual pair |
| No background, no foreground, empty relevant value, truncated UTF-8 or named `red` | Unavailable |
| Two background assignments, including identical repetitions | Unavailable |
| `background = #12345G`, `#ABC`, `0x112233`, `rgb:11/22/33`, quoted hex or hex with trailing tokens | Unavailable |
| `theme = Rose Pine` with complete hex pair | Configured pair accepted |
| `theme = light:Rose Pine Dawn,dark:Rose Pine` | Appearance unresolved, unavailable |
| Reversed dual theme, extra surrounding spaces or absolute theme paths on each side | Appearance unresolved, unavailable |
| Binary missing, wrong bundle identifier, multiple matching apps, generation changes during subprocess | Unavailable |
| Runner timeout, nonzero exit, output-limit failure | Unavailable, no preview bytes |

Add appearance-specific success fixtures only after the primary loader contract is verified.
Keep dynamic-color and launch-override limitations visible in live acceptance rather than
inventing a parser guarantee.

## Exact remaining primary-source research

1. Verify `--changes-only=false` implementation and full resolved output rather than only
   documented config syntax: [loader source](https://github.com/ghostty-org/ghostty/blob/main/src/cli/show_config.zig).
2. Trace that loader's `Config` load/finalize path for dual-theme selection, any supported
   explicit appearance parameter and config-error handling. Do not infer it from window-theme:
   [config source](https://github.com/ghostty-org/ghostty/blob/main/src/config/Config.zig),
   [theme reference](https://ghostty.org/docs/config/reference#theme).
3. Trace background/foreground serialization in the loader's config writer. Confirm whether
   named X11 input is always normalized to six-digit hex in output:
   [background reference](https://ghostty.org/docs/config/reference#background),
   [foreground reference](https://ghostty.org/docs/config/reference#foreground).

Prefer the installed source revision `260288614` if upstream can resolve it; otherwise
distinguish current-main findings from the installed manual version. The unrelated local
`ghostty-config-docs.txt` snapshot was inspected but adds no provenance or CLI contract beyond
the authoritative installed manuals and should not be used as the implementation authority.
