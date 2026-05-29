# Ghostty Special Elements During Pause Styling

Last Updated: 2026-05-29
Version: 1.0

## Executive Summary

Ghostty is not failing to apply the TAVS pause colors. TAVS currently changes
the terminal default foreground and background with `OSC 10/11`, and Ghostty
does apply those defaults where terminal cells use default colors.

The elements that remain visually distinct are usually not default-colored
cells. They fall into separate rendering layers:

- Cells styled with ANSI palette colors.
- Cells styled with explicit TrueColor RGB values.
- Hyperlink metadata and hover affordances from `OSC 8` or URL detection.
- Ghostty-owned UI overlays such as selection, search matches, previews,
  split dividers, tabs, or titlebar behavior.

There is no portable terminal protocol for "change hyperlink color", "change
link hover style", or "recolor all terminal-owned special UI". Ghostty exposes
some useful adjacent controls, but none are a direct fix for link affordances.

Recommended product direction:

1. Document the boundary clearly.
2. Consider optional cursor color support with `OSC 12/112`.
3. Treat palette mutation (`OSC 4/104`) as a future, opt-in experiment only.
4. Treat Ghostty config/theme mutation as a non-goal for TAVS pause state.
5. If TAVS prints its own links, style that visible link text with SGR while
   wrapping it in `OSC 8`.

## Research Inputs

Four Gemini web research subagents investigated the topic from independent
angles. Raw reports are preserved here:

- `/tmp/gemini-web-research-ghostty-rendering-first-principles-20260529.md`
- `/tmp/gemini-web-research-ghostty-config-theming-controls-20260529.md`
- `/tmp/gemini-web-research-terminal-protocol-link-styling-20260529.md`
- `/tmp/gemini-web-research-tavs-ghostty-special-elements-strategy-20260529.md`

This synthesis also checked current public Ghostty and Kitty documentation.

## Fundamental Model

Terminal visuals are not one flat layer. They are resolved from several
different sources.

### Default Colors

`OSC 10` changes the terminal default foreground. `OSC 11` changes the
terminal default background. Ghostty supports both, and TAVS already uses them.

These only affect cells that resolve to the terminal default colors. They do
not override every explicit color that an application has already printed.

### Palette Colors

`OSC 4` changes palette entries. This affects cells that reference those
palette entries, including common ANSI colors used by shells, prompts, and
command-line programs.

Ghostty documents `OSC 4` palette mutation and `OSC 104` palette reset. It
also maps indices above `255` to special colors such as bold and underline.

This is broader than `OSC 10/11`, but it is also much riskier. If a pause state
mutates the palette and resume fails, the whole terminal color scheme can look
wrong until reset.

### Explicit RGB Colors

If an application emits explicit RGB SGR colors, terminal defaults and palette
changes do not change those cells. The application has already specified the
exact color.

This is expected for syntax-highlighted output, rich CLI tools, TUIs, and many
modern prompts.

### Hyperlinks

`OSC 8` marks cells as hyperlinks. It does not carry a color, hover color, or
underline style. The visible text still uses normal cell styling. The terminal
emulator decides how to show hover/activation affordances.

A link can therefore be affected in three different ways:

- The visible text may follow `OSC 10/11` if it uses default colors.
- The visible text may follow `OSC 4` if it uses palette colors.
- The hover underline, URL detector, pointer behavior, and previews remain
  terminal-owned UI behavior.

## Ghostty Capabilities Relevant to TAVS

### Supported and Useful In-Band Controls

These are the controls that fit TAVS's per-session PTY model:

| Surface | Sequence | Status | TAVS Fit |
|---|---|---|---|
| Default foreground | `OSC 10` | Supported | Already implemented |
| Default background | `OSC 11` | Supported | Already implemented |
| Cursor color | `OSC 12` | Supported | Good optional addition |
| Palette entries | `OSC 4` | Supported | Future opt-in only |
| Palette reset | `OSC 104` | Supported | Already emitted defensively |
| Dynamic reset | `OSC 110/111/112` | Supported | Add `112` if cursor added |
| Special colors | `OSC 5`, `OSC 4` > 255 | Supported | Too broad for core pause |
| Hyperlink metadata | `OSC 8` | Supported | Not a styling API |
| Kitty color protocol | `OSC 21` | Supported | Future Ghostty/kitty option |

### Unsupported for This Problem

Ghostty documents dynamic color slots `10` through `19`, including pointer and
highlight colors. It currently supports only `10` through `12`. The other
dynamic colors are ignored. The reset page makes the same point for
`110` through `119`: only `110` through `112` are currently supported.

This means these are not viable fixes for Ghostty today:

- `OSC 17` highlight background.
- `OSC 19` highlight foreground.
- `OSC 117` or `OSC 119` highlight resets.
- Any assumption that selection/highlight UI can be controlled through the
  xterm dynamic-color range.

### Config and Theme Controls

Ghostty has config/theme keys for many special surfaces, including:

- `selection-foreground`
- `selection-background`
- `search-foreground`
- `search-background`
- `search-selected-foreground`
- `search-selected-background`
- `cursor-color`
- `link-url`
- `link-previews`
- `split-divider-color`
- macOS titlebar/window behavior

Those keys are user configuration, not per-session escape-sequence state. They
are useful for user theming, but they are the wrong control plane for TAVS
pause/resume.

## Can TAVS Change Ghostty Link Design?

### Direct Link Styling

No. There is no evidence of a supported Ghostty or portable terminal sequence
that changes hyperlink color, hover style, URL detector styling, or link
preview styling from the shell hook.

`OSC 8` only attaches a URI to cells. It is not terminal CSS.

### Link Text Color

Sometimes. TAVS can only affect the visible link text through normal cell color
rules:

- Default-colored link text follows `OSC 10/11`.
- Palette-colored link text can follow `OSC 4`.
- Explicit RGB link text will not follow either default colors or palette
  remapping.

If TAVS itself prints a link, the best approach is:

1. Emit SGR colors for the visible link label.
2. Wrap the label with `OSC 8` for clickability.
3. Reset SGR after the label.

That styles only the text TAVS owns. It does not retheme Ghostty's hover UI.

### Hyperlink Underline and Hover Affordance

No direct supported control was found. Some Ghostty rendering paths may derive
underline color from the current cell foreground when no explicit underline
color exists. That is an indirect side effect, not a reliable hyperlink styling
API.

## Can TAVS Change Other Special Elements?

### Cursor

Yes. `OSC 12` changes cursor color and `OSC 112` resets it. This is the most
defensible implementation improvement because it remains PTY-scoped, reversible,
and supported by Ghostty.

### Selection and Search Highlights

Not through current Ghostty dynamic color support. The legacy xterm slots for
highlight colors exist on paper, but Ghostty currently ignores dynamic colors
outside `10` through `12`.

The Kitty color protocol (`OSC 21`) can set keys such as
`selection_background`, `selection_foreground`, `foreground`, `background`, and
`cursor`. Ghostty lists `OSC 21` as supported. This is the strongest possible
Ghostty/kitty-family path, but it is terminal-family-specific and still does
not style hyperlink hover UI.

### Palette-Colored Text

Yes, with `OSC 4`, but this is a broad visual mutation. It can affect prompts,
diffs, diagnostics, syntax highlights, and any command output using ANSI color.

This should not be a default behavior. It is suitable only for a future
explicit opt-in after manual restore testing.

### Ghostty Theme or Config Mutation

Technically possible, but not recommended.

Problems:

- Scope is app/global, not one paused TAVS session.
- It can affect unrelated Ghostty windows and tabs.
- Restore is race-prone if TAVS crashes or the user edits config concurrently.
- Some Ghostty settings do not reload live or apply only to new surfaces.
- macOS automation or AppleScript paths introduce permission prompts and
  product surprise.

This would make TAVS less trustworthy.

## Reconciled Ambiguity: OSC 5 and Special Colors

One raw report was cautious about Ghostty special colors because source-level
paths appeared ambiguous. Current Ghostty docs are clearer:

- Ghostty supports five special colors.
- They can be changed via `OSC 5` indices `0..4`.
- They can also be changed via `OSC 4` indices `256..260`.

This does not change the recommendation. Special colors are not a targeted
hyperlink styling API. They may affect styled cells such as underlined or bold
text, but they are broad and terminal-specific enough to keep out of core pause
behavior.

## Candidate Implementation Paths

### Path A: Documentation Only

Recommended now.

Update user-facing docs to explain:

- Ghostty applies TAVS pause colors to default-colored terminal cells.
- Links and special UI may not fully change because they can be palette,
  explicit RGB, or Ghostty-owned UI.
- This is not a resume bug.
- Users who want global Ghostty link/search/selection styling should configure
  Ghostty itself.

Acceptance criteria:

- Docs distinguish default colors from palette, RGB, and emulator UI.
- Docs mention Ghostty dynamic colors currently support only `10..12`.
- Docs do not promise that TAVS controls link hover or selection UI.

### Path B: Add Cursor Color Support

Recommended as the only near-term code feature worth considering.

Implement:

- Add pause cursor color to the pause visual model.
- Emit `OSC 12;<color>` during pause when configured.
- Emit `OSC 112` during resume.
- Keep it disabled or default-derived unless product wants another color knob.

Why:

- Ghostty explicitly supports this.
- It improves pause-state coherence.
- It preserves per-session scope and restore symmetry.

Tests:

- Unit coverage for emitted `OSC 12` on pause.
- Unit coverage for emitted `OSC 112` on resume.
- Regression coverage that title OSCs are still not emitted.
- Manual Ghostty check with at least two tabs to prove scope stays local.

### Path C: Optional Palette Mutation

Defer.

Possible implementation:

- Add an explicit opt-in setting.
- Emit `OSC 4` entries for selected ANSI colors during pause.
- Emit `OSC 104` on resume, or query and restore exact values if supported.

Risks:

- Orphaned palette state is more disruptive than orphaned default colors.
- ANSI output may lose semantic color meaning.
- Cross-terminal behavior varies.
- It still does not solve Ghostty hover/link-preview UI.

Acceptance criteria before any implementation:

- A small spec.
- Manual Ghostty tests for interruption and resume.
- Manual tests inside and outside tmux/zellij.
- Screenshots or byte captures proving reset behavior.
- Explicit user-facing opt-in.

### Path D: Ghostty/Kitty OSC 21 Mode

Defer unless we intentionally add a terminal-family-specific enhancement.

Possible implementation:

- Detect or explicitly configure Ghostty/kitty-family mode.
- Use `OSC 21;foreground=...;background=...;cursor=... ST`.
- Optionally include `selection_background` and `selection_foreground`.
- Reset with key names without values, or query/push/pop if practical.

Pros:

- More expressive than old numeric xterm dynamic-color slots.
- Ghostty lists `OSC 21` as supported.
- Can target selection colors where classic `OSC 17/19` does not work.

Cons:

- Not portable.
- Needs careful reset semantics.
- Still not a hyperlink-hover styling mechanism.
- Adds a terminal-specific branch to a currently simple feature.

### Path E: Mutate Ghostty Config or Theme

Do not implement.

This violates TAVS's core design: a pause signal should be local, temporary,
and reversible through the terminal session. Editing user config is global,
persistent, and failure-prone.

### Path F: Output Rewriting

Do not implement.

Rewriting user PTY output to recolor links would turn TAVS into a terminal
multiplexer/filter. It would be brittle with OSC 8, ANSI parsing, TrueColor,
full-screen TUIs, tmux/zellij, copy/paste, and application semantics.

## Recommended Next Work

If we want the smallest useful improvement:

1. Add a documentation update now.
2. Open a small follow-up spec for optional cursor color support.
3. Leave palette and `OSC 21` work as future explicit opt-in research items.

Do not try to solve Ghostty link affordance styling in TAVS. The correct answer
is to document the terminal boundary and improve only the surfaces Ghostty
actually exposes as session-scoped runtime state.

## Source Notes

Primary source links:

- Ghostty dynamic colors (`OSC 10..19`):
  https://ghostty.org/docs/vt/osc/1x
- Ghostty dynamic color resets (`OSC 110..119`):
  https://ghostty.org/docs/vt/osc/11x
- Ghostty palette mutation (`OSC 4`):
  https://ghostty.org/docs/vt/osc/4
- Ghostty special colors (`OSC 5`):
  https://ghostty.org/docs/vt/osc/5
- Ghostty color concepts:
  https://ghostty.org/docs/vt/concepts/colors
- Ghostty VT reference:
  https://ghostty.org/docs/vt/reference
- Ghostty external protocols (`OSC 8`, `OSC 21`):
  https://ghostty.org/docs/vt/external
- Ghostty configuration reference:
  https://ghostty.org/docs/config/reference
- Ghostty theme docs:
  https://ghostty.org/docs/features/theme
- OSC 8 hyperlink specification:
  https://gist.github.com/egmontkob/eb114294efbcd5adb1944c9f3cb5feda
- Kitty color protocol:
  https://sw.kovidgoyal.net/kitty/color-stack/

## Final Answer

It is not possible to fully recolor Ghostty links and special elements from
TAVS using the current `OSC 10/11` approach, and no direct link-styling escape
sequence was found.

It is possible to improve adjacent surfaces:

- Cursor: yes, use `OSC 12/112`.
- Palette-colored content: yes, use `OSC 4/104`, but only as opt-in.
- Ghostty/kitty-family selection/default/cursor colors: possibly, use `OSC 21`,
  but only as terminal-specific opt-in.
- Link text TAVS owns: yes, use SGR plus `OSC 8`.

It is not advisable to mutate Ghostty config/theme files or rewrite terminal
output to chase this behavior.
