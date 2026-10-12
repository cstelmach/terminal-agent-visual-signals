# Ghostty color preview research gap

Last Updated: 2026-10-12
Version: 1.0
Scope: bounded primary-source research for TAVS Phase 7. No Ghostty execution,
native UI, AppleEvents, installation, or repository/home edits occurred.

## Executive summary

The upstream implementation supports parsing canonical color assignments from
`ghostty +show-config --changes-only=false --no-pager`. It does not provide a
supported `+show-config` appearance or theme override flag. Separate light/dark
themes therefore need an explicit unavailable state when the application needs
appearance-specific preview colors. Exit zero alone also fails to establish valid
configuration. These are conclusions from source inspection, not installed 1.3.2
runtime observations. Sources and limitations follow.

## Foundations and output contract

`show_config.Options` contains exactly `default`, `changes-only`, `docs`, and
`no-pager`. `changes-only` defaults true. `run()` loads user configuration unless
`--default` is used, formats it, flushes output, and returns zero. Output order is
unspecified. Do not use `--default` to obtain user colors.
[Upstream show_config.zig, Options and run](https://github.com/ghostty-org/ghostty/blob/main/src/cli/show_config.zig)
([retrieved raw source](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/cli/show_config.zig)).

`Config.load()` finalizes after files and CLI input. Theme values are resolved,
then overridden by explicit settings. `Color.formatBuf()` emits lowercase
`#rrggbb`. Upstream defaults are background `#282c34`, foreground `#ffffff`.
[Config.zig, load, finalize, loadTheme, Color.formatBuf, background, foreground](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/config/Config.zig).

`FileFormatter` visits non-private fields; disabling changes filtering includes
both scalar color fields. `formatter.formatEntry()` emits `name = value` followed
by a newline. Thus canonical examples are:

```text
background = #123abc
foreground = #f1e2d3
```

[FileFormatter.format](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/config/formatter_file.zig),
[formatter.formatEntry](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/config/formatter.zig).

The input grammar additionally allows bare six-digit hex and named X11 colors.
Those input forms are normalized by color serialization; they need not be
reimplemented to consume canonical output.
[Background](https://ghostty.org/docs/config/reference#background),
[foreground](https://ghostty.org/docs/config/reference#foreground).

## Appearance and override findings

The documented pair syntax is
`theme = light:Rose Pine Dawn,dark:Rose Pine`. Both branches are required; branch
order and surrounding whitespace may vary. GUI theme selection follows system
appearance.
[Theme reference](https://ghostty.org/docs/config/reference#theme),
[Separate light and dark themes](https://ghostty.org/docs/features/theme#separate-light-and-dark-themes).

The CLI starts with `conditional.State.theme = .light`.
[conditional.State](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/config/conditional.zig).
`loadTheme()` uses that initial state; `Config.load()` does not query appearance.
The inspected CLI therefore resolves the light branch. Matching a running
dark-mode window cannot be assumed. This is a source inference.
[Config.zig, _conditional_state and loadTheme](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/config/Config.zig),
[show_config.run](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/cli/show_config.zig).

The exact GUI configuration values are `window-theme = auto`, `system`, `light`,
`dark`, and `ghostty` (Linux only). These describe window styling; they are not
`show-config` selectors.
[Window theme reference](https://ghostty.org/docs/config/reference#window-theme).

Although ordinary Ghostty launches accept configuration flags, an action parses
its own options. `show-config` first calls `args.parse(Options, ...)`. That options
type lacks diagnostics, so unknown fields propagate `InvalidField` rather than
being accepted. Its iterator skips `+` actions and still exposes ordinary flags.
Therefore no supported `--appearance`, `--theme`, `--window-theme`, or
`--config-file` override exists for this inspected `+show-config` path, regardless
of flag placement. Do not invent such invocations.
[General CLI configuration syntax](https://ghostty.org/docs/config#syntax),
[args.parse and ArgsIterator](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/cli/args.zig).

## Configuration errors and concrete side effects

Parsing into `Config` records recoverable invalid fields and values in diagnostics
and continues. Parsing action options instead returns errors.
[args.parse](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/cli/args.zig).
Theme open failures similarly append diagnostics and return null.
[theme.open and openAbsolute](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/config/theme.zig).

`FileFormatter` excludes underscore-prefixed fields, including diagnostics.
Together with `show-config` returning zero after successful formatting, this means
valid-looking output and exit zero can coexist with invalid configuration or a
missing theme. Neither parsing the two colors nor requiring empty stderr proves
that the selected theme loaded.
[FileFormatter.format](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/config/formatter_file.zig),
[show_config.run](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/cli/show_config.zig).

`+validate-config` is the diagnostic-aware action. With no arguments it loads
normal configuration, prints diagnostics to stdout, and returns one when any
exist; otherwise it returns zero. It supports its own `--config-file` option.
Fatal load/parse errors propagate. Proposed future qualification can inspect this
action, but it was not executed here.
[validate_config.runInner](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/cli/validate_config.zig).

`loadDefaultFiles()` creates a template when all default configurations are absent.
Optional file read failures are logged and ignored. Both actions can write home;
validation cannot prove all optional files were read.
[Config.zig, loadDefaultFiles, writeConfigTemplate, loadOptionalFile](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/config/Config.zig).

## Parser examples and unavailable states

Recommended parser scope: inspect stdout line by line, split only at the first
`=`, trim spaces/tabs, and accept only exact lowercase keys `background` and
`foreground`. For those values, require `^#[0-9A-Fa-f]{6}$`. Require exactly one
valid assignment per key. Ignore unrelated configuration keys. Do not strip an
inline `#` comment: hex colors begin with `#`, and Ghostty comments occupy their
own line. This is a deliberately small output parser, not a Ghostty input parser.
[Syntax](https://ghostty.org/docs/config#syntax),
[config-template](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/config/config-template).

| Illustrative stdout | Recommended result |
|---|---|
| `background = #123abc` and `foreground = #f1e2d3` | Accept the pair |
| `background = #123abc` with missing foreground | Unavailable: incomplete output |
| `background = red` | Unavailable: unexpected canonical output |
| `background = #123abc # note` | Unavailable: invalid color value |
| Two `background` assignments | Unavailable: duplicate scalar output |
| Empty stdout from an omitted `changes-only=false` flag | Unavailable, never substitute built-in colors |

Identical theme branches serialize to one name; different branches produce
`theme = light:<light>,dark:<dark>`. Unset themes yield an empty assignment.
Detect differing branches from this value.
[Config.zig, Theme.formatEntry](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/config/Config.zig),
[Optional-value formatting](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/config/formatter.zig).

The small parser choice avoids reproducing theme lookup, includes, X11 names, or
configuration precedence. A hand-written input resolver could select both
branches, but it would require those semantics and extends this research gap into
a new implementation. The scoped recommendation is to preserve honest unavailable
states instead.

| Condition | Safe product state |
|---|---|
| Executable absent or installed flags unqualified | Colors unavailable |
| Timeout, nonzero exit, decode failure, malformed/missing colors | Colors unavailable |
| Configuration diagnostics or failed validation | Colors unavailable |
| Different light/dark theme branches and selected appearance cannot be resolved | Appearance-specific colors unavailable |
| Default configs absent and the task requires no home writes | Do not launch default-loading actions; colors unavailable |
| Successful ordinary single-theme config with qualified installed behavior | Configured base colors available |

## Smallest query without creating configuration files

For absent default configuration, use the explicit defaults action:

```sh
ghostty +show-config --default --no-pager
```

Upstream this takes `Config.default()`, bypassing file loading, finalization, and
template creation. `--changes-only=false` is unnecessary in this mode. The result
must be labeled Ghostty defaults, not the user's configured or running colors.
The installed manual also documents `--default` as loading defaults instead of
user configuration and documents `--no-pager`.
[show_config.run](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/cli/show_config.zig),
[installed ghostty.1.md:317](</Applications/Ghostty.app/Contents/Resources/ghostty/doc/ghostty.1.md:317>).

For existing default configuration, the ordinary query remains:

```sh
ghostty +show-config --changes-only=false --no-pager
```

First confirm a default configuration path exists as a regular nonempty file.
That avoids the observed template-creation branch in normal use. An existence
check is not atomic with another process deleting the file; no runtime claim was
tested here. Do not add unsupported `--config-default-files=false` to this action.

The standard macOS candidate paths are:

| Directory | Legacy filename | Current filename |
|---|---|---|
| `$XDG_CONFIG_HOME/ghostty` (default `$HOME/.config/ghostty`) | `config` | `config.ghostty` |
| `$HOME/Library/Application Support/com.mitchellh.ghostty` | `config` | `config.ghostty` |

[file_load path functions](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/config/file_load.zig),
[documented file locations](https://ghostty.org/docs/config#file-location),
[installed ghostty.5.md:11](</Applications/Ghostty.app/Contents/Resources/ghostty/doc/ghostty.5.md:11>).

For four regular/nonempty files, source loads XDG legacy, XDG current, macOS
legacy, macOS current. Later values win. macOS uses the preferred path; if that
equals legacy, it avoids a duplicate load.
[Config.zig, loadDefaultFiles](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/config/Config.zig),
[file_load.preferredAppSupportPath](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/config/file_load.zig).
The current website lists current before legacy, which differs from this source
ordering. The installed manual establishes macOS precedence but not legacy/current
filename order. Prefer the inspected source ordering for upstream; installed
filename ordering remains untested.
[Website location list](https://ghostty.org/docs/config#file-location),
[installed ghostty.5.md:5145](</Applications/Ghostty.app/Contents/Resources/ghostty/doc/ghostty.5.md:5145>).

An existing explicit file can be validated with:

```sh
ghostty +validate-config --config-file=/absolute/path/to/existing/config.ghostty
```

The installed action manual explicitly supports this option. Upstream initializes
defaults, loads that file and its recursive includes, then finalizes; it does not
load default files or create their template. It validates that file's include and
theme graph, not every other default file that the ordinary query might load.
[validate_config.runInner](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/cli/validate_config.zig),
[installed ghostty.1.md:349](</Applications/Ghostty.app/Contents/Resources/ghostty/doc/ghostty.1.md:349>).

A configured base-color preview does not establish live per-terminal state after
OSC changes, transparency, images, or shader effects. The command reloads
configuration rather than interrogating a running surface. Avoid labeling it as
an exact rendering of an existing window.
[show_config.run](https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/cli/show_config.zig),
[background opacity](https://ghostty.org/docs/config/reference#background-opacity).

## Limitations and bibliography

The installed manuals were reread for the follow-up question. Their header is
`1.3.2-main-+260288614`, which is a development build label, not evidence of a
stable 1.3.2 release. They confirm the named CLI flags and current file paths;
binary behavior remains untested. Attempts to retrieve both `v1.3.2` and `1.3.2`
tagged raw source URLs failed. Direct GitHub `v1.3.2` source/release pages returned
404. This does not establish the exact source used to build the installed app.
[installed version header](</Applications/Ghostty.app/Contents/Resources/ghostty/doc/ghostty.5.md:1>).
GitHub HTML and raw main views also returned different total source line counts;
the report uses retrieved functions and file links instead of claiming a pinned
commit or stable GitHub line numbers.

All sources above are Ghostty-owned documentation or upstream source retrieved on
2026-10-12. The key files are `show_config.zig`, `args.zig`, `Config.zig`,
`conditional.zig`, `formatter_file.zig`, `formatter.zig`, `theme.zig`, and
`validate_config.zig`. Documentation anchors identify the theme, background,
foreground, window-theme, syntax, and opacity contracts.

Skipped: installed binary execution, GUI appearance checks, native acceptance,
and any implementation. Risk: upstream findings must be qualified against the
installed version before claiming working light/dark previews.
