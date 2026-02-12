---
name: tavs-setup
description: >
  Interactive TAVS configuration assistant. Detects terminal and agent,
  asks targeted questions about theme, faces, titles, and visual preferences,
  then applies settings via tavs set commands. Use when a user wants to
  customize TAVS visual signals, set up their terminal appearance, or
  configure agent-specific settings. Triggers: "tavs setup", "customize tavs",
  "configure terminal visuals", "set up visual signals".
---

# TAVS Setup Assistant

Conversational configuration for Terminal Agent Visual Signals. Walks users
through setup with smart defaults based on their terminal environment.

## When to Use

- User wants to set up or customize TAVS visual signals
- User asks about configuring terminal colors, faces, titles, or themes
- User says "tavs setup", "configure tavs", "customize terminal visuals"
- User just installed the TAVS plugin and wants to configure it

## Prerequisites

Before starting, verify the TAVS CLI is available:

```bash
# Check tavs CLI exists and show version
./tavs version 2>/dev/null || echo "TAVS CLI not found"
```

If unavailable, inform the user they need the `config-ux-overhaul` branch or
that the `tavs` CLI is part of TAVS v3.0.0+.

## Workflow

### Phase 1: Environment Detection (Automatic)

Run these commands silently to detect the user's environment:

```bash
# Get current config state
./tavs status 2>/dev/null

# Terminal detection
echo "TERM_PROGRAM=${TERM_PROGRAM:-unset}"
echo "GHOSTTY_RESOURCES_DIR=${GHOSTTY_RESOURCES_DIR:-unset}"
echo "ITERM_SESSION_ID=${ITERM_SESSION_ID:-unset}"
echo "KITTY_PID=${KITTY_PID:-unset}"
echo "COLORTERM=${COLORTERM:-unset}"
echo "TERM=${TERM:-unset}"

# Agent detection
echo "TAVS_AGENT=${TAVS_AGENT:-claude}"

# Dark mode detection (macOS)
defaults read -g AppleInterfaceStyle 2>/dev/null || echo "light"
```

Present a brief summary of findings:
> "I detected **[Terminal]** in **[dark/light]** mode running **[Agent]**.
> Here's what I recommend for your setup..."

Mention terminal-specific notes if relevant (see `references/terminal-guide.md`).

### Phase 2: Essential Questions (2-3 via AskUserQuestion)

**Q1: Theme Preference**

Use AskUserQuestion with these options (tailor recommendations to detected terminal):

- **Nord** — Arctic blue palette, clean and calm (Recommended for dark terminals)
- **Catppuccin Mocha** — Warm pastel dark theme, very popular
- **Dracula** — Vibrant dark theme with high contrast
- **Tokyo Night** — Modern city-lights aesthetic
- Other (show full list: catppuccin-frappe, catppuccin-latte, catppuccin-macchiato,
  solarized-dark, solarized-light)
- **No theme** — Use default static colors

If user picks a theme, plan: `tavs set theme <name>`

**Q2: Face Mode**

Show visual examples in the question description:

- **Standard (Recommended)** — Text-based faces: `Ǝ[• •]E 🟠 ~/project`
- **Compact** — Emoji eyes, denser info: `Ǝ[🟧 🟠]E ~/project`
- **Off** — No faces, just colors and status icons

If standard: `tavs set faces true` + `tavs set face-mode standard`
If compact: `tavs set faces true` + `tavs set face-mode compact`
If off: `tavs set faces false`

**Q3: Title Mode**

Adapt recommendations to the detected terminal:

- **Skip Processing (Recommended)** — TAVS handles non-processing titles,
  Claude Code keeps its spinner. Safe default, no config needed.
- **Prefix Only** — TAVS adds `Ǝ[• •]E 🟠` prefix to your tab name.
  Great if you name your tabs.
- **Full** — TAVS owns all titles with animated spinner eyes.
  Requires `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` in Claude settings.
- **Off** — No title changes, only background colors.

If title-mode is full or prefix-only, plan: `tavs set title-mode <mode>`

### Phase 3: "Want More?" Gate

After essentials, ask:

> "Those are the essentials! Want to dive into advanced options like spinners,
> session icons, background images, or palette theming?"

Use AskUserQuestion:
- **Yes, show me more** — Continue to Phase 4
- **No, apply these settings** — Skip to Phase 5

### Phase 4: Advanced Options (Conditional)

Only ask questions relevant to the user's earlier choices. Use AskUserQuestion
for each group, presenting 2-4 options per question.

**If title-mode = full:**
- Spinner style: braille, circle, block, eye-animate, random (Recommended)
- Eye sync mode: sync, opposite, mirror, random (Recommended)
- Plan: `tavs set spinner <style>`, `tavs set eye-mode <mode>`

**If face-mode = compact:**
- Compact theme: semantic (Recommended), circles, squares, mixed
- Show examples from `references/agent-visual-identity.md`
- Plan: `tavs set compact-theme <theme>`

**Session icons** (always applicable):
- Currently enabled by default. Ask if they want to keep or disable.
- Plan: `tavs set session-icons <true|false>`

**Background images** (only if iTerm2 or Kitty detected):
- Explain: "Your terminal supports background images per state."
- Plan: `tavs set backgrounds true`
- Note iTerm2 prerequisite (enable in Preferences > Profiles > Window)

**Palette theming** (explain TrueColor limitation):
- Explain: "Palette theming modifies your terminal's 16-color ANSI palette
  for a cohesive look. Note: Claude Code uses TrueColor by default, which
  bypasses the palette. You'd need to launch with
  `TERM=xterm-256color COLORTERM= claude` for full effect."
- Options: false (default), auto, true
- Plan: `tavs set palette <value>`

**Mode-aware processing colors:**
- Explain: "Processing color shifts subtly based on Claude's permission mode.
  Plan mode gets a green-yellow tinge, bypass mode gets a reddish warning."
- Currently enabled by default. Ask if they want to keep or disable.
- Plan: `tavs set mode-aware <true|false>`

**Bell notifications:**
- Options: permission only (default), permission + complete, all off
- Plan: `tavs set bell-permission <true|false>`,
  `tavs set bell-complete <true|false>`

### Phase 5: Apply Settings

1. **Show summary** of all planned `tavs set` commands:

```
Here's what I'll configure:

  tavs set theme nord
  tavs set face-mode standard
  tavs set title-mode prefix-only

Apply these settings?
```

2. **Ask for confirmation** via AskUserQuestion:
   - **Apply all** — Execute commands
   - **Edit first** — Let user modify choices
   - **Cancel** — Abort without changes

3. **Execute** each `tavs set` command sequentially:

```bash
./tavs set theme nord
./tavs set face-mode standard
./tavs set title-mode prefix-only
```

4. **Verify** the result:

```bash
./tavs status --colors
```

5. **Quick demo** (optional, ask first):

```bash
./tavs test --quick
```

6. **Terminal-specific post-setup notes:**

   - **Ghostty**: Remind about `shell-integration-features = no-title` if title
     mode is not "off"
   - **iTerm2**: Remind about enabling background images in preferences if
     backgrounds were enabled
   - **Full title mode**: Remind to add `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1`
     to `~/.claude/settings.json` env section
   - **Palette theming**: Remind about TrueColor limitation and the
     `COLORTERM=` workaround

## Reference Files

For detailed information on specific topics, read:

- `references/config-options.md` — All 23 setting aliases with valid values
- `references/terminal-guide.md` — Terminal detection and recommendations
- `references/agent-visual-identity.md` — Per-agent faces, colors, spinners
- `references/preset-themes.md` — All 9 themes with descriptions
- `troubleshooting/lessons-learned.md` — Known issues and fixes

## Important Notes

- All settings are written to `~/.tavs/user.conf` (takes effect immediately)
- Use `tavs set` commands (not direct file edits) to ensure validation
- The `theme` alias is compound: it sets both `THEME_PRESET` and `THEME_MODE`
- Run `tavs status` anytime to see current configuration
- Run `tavs test` to demo all visual states
