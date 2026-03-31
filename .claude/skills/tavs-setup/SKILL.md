---
name: tavs-setup
description: >
  TAVS setup, configuration, and profile management assistant. Three workflows:
  (1) Interactive setup wizard for first-time configuration — detects terminal
  and agent, asks targeted questions, applies settings.
  (2) Targeted config changes — modify individual settings with backup, preview,
  and verification. Supports both CLI aliases and raw variables.
  (3) Profile management — save, list, apply, and delete named configuration sets.
  Triggers: "tavs setup", "customize tavs", "configure terminal visuals",
  "set up visual signals", "tavs config", "change tavs", "tavs profile",
  "save tavs config".
---

# TAVS Setup & Configuration Assistant

Conversational configuration for Terminal Agent Visual Signals. Handles initial
setup, ongoing config changes, and named profile management — all with backup,
preview, and verification.

## When to Use

- **Setup:** First-time configuration, re-setup, "tavs wizard", "tavs setup"
- **Config:** Modify a setting, change theme, adjust colors, "tavs config"
- **Profiles:** Save/load/apply named config sets, "tavs profile"
- **Agent settings:** Per-agent color, face, or title format overrides

## Prerequisites

Verify the TAVS CLI is available:

```bash
./tavs version 2>/dev/null || echo "TAVS CLI not found"
```

If unavailable, the `tavs` CLI is part of TAVS v3.0.0+.

## Intent Detection

Determine which workflow to use based on the user's request:

| Keywords | Workflow |
|----------|----------|
| "set up", "configure from scratch", "wizard", "first time", "install" | **A: Setup Wizard** |
| "change", "modify", "set", "switch", "update", "enable", "disable" | **B: Config Change** |
| "profile", "save config", "load config", "apply profile", "list profiles" | **C: Profile Management** |

When unclear, ask the user:
- **Run the setup wizard** — Full guided configuration
- **Change a specific setting** — Quick, targeted modification
- **Manage profiles** — Save or load a named configuration

---

## Workflow A: Setup Wizard

Guided multi-step configuration. Best for first-time users or full reconfiguration.

### Phase 1: Environment Detection (Automatic)

Run silently to detect the user's environment:

```bash
./tavs status 2>/dev/null
echo "TERM_PROGRAM=${TERM_PROGRAM:-unset}"
echo "GHOSTTY_RESOURCES_DIR=${GHOSTTY_RESOURCES_DIR:-unset}"
echo "ITERM_SESSION_ID=${ITERM_SESSION_ID:-unset}"
echo "KITTY_PID=${KITTY_PID:-unset}"
echo "COLORTERM=${COLORTERM:-unset}"
echo "TERM=${TERM:-unset}"
echo "TAVS_AGENT=${TAVS_AGENT:-claude}"
defaults read -g AppleInterfaceStyle 2>/dev/null || echo "light"
```

Present: "I detected **[Terminal]** in **[dark/light]** mode running **[Agent]**."
Mention terminal-specific notes from `references/terminal-guide.md`.

### Phase 2: Essential Questions (2-3 via AskUserQuestion)

**Q1: Theme Preference**
- **Nord** — Arctic blue, calm (Recommended for dark)
- **Catppuccin Mocha** — Warm pastel dark
- **Dracula** — Vibrant, high contrast
- **Tokyo Night** — Modern city-lights
- Other (catppuccin-frappe/latte/macchiato, solarized-dark/light)
- **No theme** — Default static colors

Plan: `tavs set theme <name>`

**Q2: Face Mode** (show visual examples in descriptions)
- **Standard (Recommended)** — `Ǝ[• •]E 🟠 ~/project`
- **Compact** — `Ǝ[🟧 🟠]E ~/project` (emoji eyes, denser)
- **Off** — No faces, just colors and icons

Plan: `tavs set faces true/false` + `tavs set face-mode standard/compact`

**Q3: Title Mode** (adapt to detected terminal)
- **Skip Processing (Recommended)** — TAVS handles non-processing titles
- **Prefix Only** — TAVS adds prefix, preserves tab names
- **Full** — TAVS owns all titles with animated spinners
- **Off** — No title changes, only background colors

Plan: `tavs set title-mode <mode>`

### Phase 3: "Want More?" Gate

> "Those are the essentials! Want to dive into advanced options?"

- **Yes, show me more** — Continue to Phase 4
- **No, apply these settings** — Skip to Phase 5

### Phase 4: Advanced Options (Conditional)

Ask only questions relevant to earlier choices. Use AskUserQuestion for each group.

**If title-mode = full:**
- Spinner style: braille, circle, block, eye-animate, random (Recommended)
- Eye sync mode: sync, opposite, mirror, random (Recommended)

**If face-mode = compact:**
- Compact theme: semantic (Recommended), circles, squares, mixed
- See `references/agent-visual-identity.md` for examples

**Session icons** (always): Keep or disable? Plan: `tavs set session-icons <bool>`

**Background images** (only iTerm2/Kitty): Plan: `tavs set backgrounds true`
Note iTerm2 prerequisite: Preferences > Profiles > Window > Background Image.

**Palette theming**: Explain TrueColor limitation. Options: false, auto, true.
Plan: `tavs set palette <value>`

**Mode-aware colors**: Currently enabled by default. Keep or disable?
Plan: `tavs set mode-aware <bool>`

**Bell notifications**: Options: permission only (default), permission + complete, off.
Plan: `tavs set bell-permission/bell-complete <bool>`

### Phase 5: Apply Settings

1. **Summary** — Show all planned `tavs set` commands
2. **Confirm** via AskUserQuestion: Apply all / Edit first / Cancel
3. **Execute** each command sequentially
4. **Verify** with `./tavs status --colors`
5. **Demo** (optional): `./tavs test --quick`
6. **Post-setup notes** (terminal-specific):
   - Ghostty: `shell-integration-features = no-title`
   - iTerm2: Enable background images in preferences
   - Full title: Add `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` to settings
   - Palette: TrueColor limitation and `COLORTERM=` workaround

---

## Workflow B: Configuration Changes

Quick, targeted setting modifications. For detailed procedure, read
`references/config-workflow.md`.

### Steps

1. **Understand** what the user wants to change
2. **Back up** current config: `~/.tavs/backups/user.conf.TIMESTAMP`
3. **Resolve** setting type:
   - CLI alias (28 known)? -> `./tavs set <alias> <value>` — see `references/config-options.md`
   - Raw variable? -> Edit `~/.tavs/user.conf` — see `references/raw-variables.md`
   - Unknown? -> Suggest closest match
4. **Preview** planned changes: `Setting: current -> new`
5. **Confirm** via AskUserQuestion: Apply / Edit / Cancel
6. **Apply** — CLI for aliases, Edit for raw variables
7. **Verify** with `./tavs status` and optionally `./tavs test --quick`

### Rollback

If something went wrong, restore from backup:
```bash
ls -1t ~/.tavs/backups/   # List backups
cp ~/.tavs/backups/user.conf.TIMESTAMP ~/.tavs/user.conf
```

### Setting Types

**CLI aliases** (validated, use `./tavs set`): theme, mode, faces, face-mode,
title-mode, spinner, identity-mode, and 21 more. Full list in `config-options.md`.

**Raw variables** (direct edit): per-agent colors (`CLAUDE_DARK_PROCESSING`),
per-agent faces (`CLAUDE_FACES_PROCESSING`), per-state title formats
(`TAVS_TITLE_FORMAT_PERMISSION`), feature toggles, timers, and more.
Full catalog in `raw-variables.md`.

---

## Workflow C: Profile Management

Save, list, apply, and delete named configuration sets. For detailed procedure,
read `references/profiles.md`.

### Operations

**Save:** Extract settings from current `user.conf` into `~/.tavs/profiles/<name>.conf`.
Ask which settings to include (specific or all active).

**List:** Show all profiles in `~/.tavs/profiles/` with setting count and summary.

**Apply:** Back up first, preview each setting's current vs. profile value, confirm,
apply (CLI for aliases, Edit for raw), verify with `./tavs status`.

**Delete:** Confirm, then remove the profile file.

Profiles are **additive** — they only overwrite settings they contain, not a full
config replacement.

---

## Reference Files

| File | Purpose |
|------|---------|
| `references/config-options.md` | All 28 CLI setting aliases with valid values |
| `references/config-workflow.md` | Config change procedure (backup, resolve, apply, verify) |
| `references/raw-variables.md` | All 50+ raw variables beyond CLI aliases |
| `references/profiles.md` | Profile save/list/apply/delete procedure |
| `references/terminal-guide.md` | Terminal detection and recommendations |
| `references/agent-visual-identity.md` | Per-agent faces, colors, spinners |
| `references/preset-themes.md` | All 9 theme presets with descriptions |
| `troubleshooting/lessons-learned.md` | Known issues and fixes (setup + config) |

## Important Notes

- All settings stored in `~/.tavs/user.conf` (takes effect on next hook trigger)
- Use `tavs set` for validated changes; Edit tool for raw variables
- The `theme` alias is compound — sets both `THEME_PRESET` and `THEME_MODE`
- Run `./tavs status` to see current configuration
- Run `./tavs test` to demo all visual states
- Backups: `~/.tavs/backups/user.conf.TIMESTAMP`
- Profiles: `~/.tavs/profiles/<name>.conf`
- Plugin cache sync: `./tavs sync` (only needed after source code changes, not config)
