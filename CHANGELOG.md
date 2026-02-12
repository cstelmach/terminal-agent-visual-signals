# Changelog

All notable changes to TAVS are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/).

## [3.0.0] — 2026-02-12

### Added
- **`tavs` CLI tool** with 12 subcommands: `set`, `status`, `wizard`, `theme`, `test`, `migrate`, `config`, `install`, `sync`, `help`, `version`
- **Three-tier configuration UX**: zero-config defaults, quick `tavs set` one-liners, and full `tavs wizard`
- **Interactive pickers** for settings with constrained values (themes, spinners, eye modes)
- **`tavs set` aliases** — 23 friendly names (e.g., `tavs set theme nord` instead of editing config files)
- **`tavs status`** — visual summary with color swatches and face previews
- **`tavs migrate`** — automatic v2 → v3 config migration with backup
- **`tavs config validate`** — check config for typos and invalid values
- **`tavs theme --preview`** — side-by-side color swatches for all 9 themes
- **Mode-aware processing colors** — subtle hue shift based on Claude Code permission mode (plan, acceptEdits, bypassPermissions)
- **`tavs-setup` skill** — conversational configuration assistant that ships with the plugin
- **v3 config template** — organized into 5 documented sections

### Changed
- Reorganized directory structure: wizard and install scripts moved under `src/`
- Config template updated to v3 format with inline documentation
- README rewritten with three-tier configuration approach

### Fixed
- `((x++))` crash on bash strict mode (3 occurrences)
- `eval` injection in `get_config_value` — replaced with `${!var:-}`
- Path traversal in help dispatcher and install scripts
- EDITOR support for commands with flags (e.g., `code --wait`)
- Variable name validation rejects names not starting with letter/underscore

## [2.0.0] — 2026-02-08

### Added
- **Compact face mode** — emoji eyes with status info embedded in face: `Ǝ[🟧 +2]E`
- **4 compact themes**: semantic, circles, squares, mixed
- **Session icons** — unique animal emoji per terminal tab (pool of 25, registry-based dedup)
- **Subagent tracking** — counter in title shows active Task tool agents: `+2`
- **Tool error state** — orange-red flash on tool execution failure, auto-returns after 1.5s
- **`{AGENTS}` and `{SESSION_ICON}` title format tokens**

### Changed
- **Renamed project** from `terminal-visual-signals` to TAVS (`tavs`)
- Config directory: `~/.terminal-visual-signals/` → `~/.tavs/`
- Plugin naming: `tavs@terminal-agent-visual-signals`
- Title tokens: `{EMOJI}` → `{STATUS_ICON}`, `{ICON}` → `{SESSION_ICON}`

### Fixed
- Session icon shows immediately on session start
- Stale subagent counter reset on new prompt
- 3 compact face mode bugs in state handling

## [1.2.0] — 2026-01-29

### Added
- **Terminal title system** with 4 modes: skip-processing, prefix-only, full, off
- **Animated spinner eyes** in full title mode (braille, circle, block, eye-animate)
- **Spinner eye sync modes**: sync, opposite, stagger, mirror, clockwise, counter
- **Per-agent spinner faces** — each agent's face style preserved during animation
- **Palette theming** — optional 16-color ANSI palette modification via OSC 4
- **9 theme presets** with full ANSI palettes: Catppuccin (4), Nord, Dracula, Solarized (2), Tokyo Night
- **TrueColor mode handling** with override options (off, muted, full)
- **Intelligent title management** with user override detection
- **Ghostty shell integration guidance** (`no-title` config)
- **Plugin hooks system** v1.2.0 with async execution

### Changed
- Title format template with 5 configurable tokens
- Prefix-only mode preserves user's custom tab names

### Fixed
- Zsh compatibility for config loading and title formatting
- Readonly variable errors on re-source
- Spinner cache state management

## [1.1.0] — 2026-01-15

### Added
- **Agent-centric theming** — per-agent faces, colors, and backgrounds
- **4 agent identities**: Claude (pincer), Gemini (bear), Codex (cat), OpenCode (kaomoji)
- **Background images** per state (iTerm2 via OSC 1337, Kitty via remote control)
- **Terminal detection module** — auto-detect capabilities (OSC 4/11/1337)
- **Dynamic color computation** — query terminal background, compute matching state colors
- **Hierarchical config** — defaults → user → theme → agent-specific overrides
- **OpenCode plugin** — TypeScript npm package for OpenCode integration

### Changed
- Modularized codebase into 17 focused shell modules
- Configuration consolidated into single `defaults.conf`
- Face definitions moved from per-agent files to centralized config

## [1.0.0] — 2025-12-20

### Added
- **7 visual states**: processing, permission, complete, idle, compacting, subagent, tool_error
- **Background color changes** via OSC 11 escape sequences
- **Graduated idle timer** — purple fade over 6 configurable stages
- **State priority system** — higher-priority states protected from overwrite
- **Claude Code hooks** — 14 hook routes for all lifecycle events
- **Gemini CLI support** — 8 event hooks
- **Codex CLI support** — limited (1 event)
- **ASCII faces** per state: `Ǝ[• •]E` processing, `Ǝ[> <]E` permission, etc.
- **Terminal escape injection prevention** — strip control characters from paths
- **TAVS_STATUS env var** — quick disable with `TAVS_STATUS=false`
- **Async hooks** with configurable timeouts (5s processing, 10s idle)
- **Light/dark mode** auto-detection with force override

[3.0.0]: https://github.com/cstelmach/terminal-agent-visual-signals/compare/v2.0.0...v3.0.0
[2.0.0]: https://github.com/cstelmach/terminal-agent-visual-signals/compare/v1.2.0...v2.0.0
[1.2.0]: https://github.com/cstelmach/terminal-agent-visual-signals/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/cstelmach/terminal-agent-visual-signals/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/cstelmach/terminal-agent-visual-signals/releases/tag/v1.0.0
