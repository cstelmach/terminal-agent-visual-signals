# Agent Visual Identity Reference

Each supported agent has its own face style, color palette, and spinner template.

## Agent Face Styles

| Agent | Style | Example (Processing) | Variants per State |
|-------|-------|---------------------|-------------------|
| Claude Code | Pincer | `Ǝ[• •]E` | 6 |
| Gemini CLI | Bear | `ʕ•ᴥ•ʔ` | 1 |
| Codex CLI | Cat | `ฅ^•ﻌ•^ฅ` | 1 |
| OpenCode | Minimal kaomoji | `(°-°)` | 1 |
| Unknown | Kaomoji fallback | `(°-°)` | 1 |

### Claude Code Faces (6 variants per state)

| State | Faces |
|-------|-------|
| Processing | `Ǝ[• •]E` `Ǝ[• ◕]E` `Ǝ[■ ■]E` `Ǝ[◔ ◔]E` `Ǝ[｡ ｡]E` `Ǝ[. .]E` |
| Permission | `Ǝ[° °]E` `Ǝ[○ ○]E` `Ǝ[□ □]E` `Ǝ[ʘ ʘ]E` `Ǝ[՞ ՞]E` `Ǝ[o o]E` |
| Complete | `Ǝ[✦ ✦]E` `Ǝ[★ ★]E` `Ǝ[✧ ✧]E` `Ǝ[❀ ❀]E` `Ǝ[✿ ✿]E` `Ǝ[* *]E` |
| Subagent | `Ǝ[⇆ ⇆]E` `Ǝ[↔ ↔]E` `Ǝ[⟺ ⟺]E` `Ǝ[⇄ ⇄]E` `Ǝ[↺ ↺]E` `Ǝ[⟳ ⟳]E` |
| Tool Error | `Ǝ[✕ ✕]E` `Ǝ[× ×]E` `Ǝ[✗ ✗]E` `Ǝ[⨯ ⨯]E` `Ǝ[✖ ✖]E` `Ǝ[╳ ╳]E` |
| Idle (stage 0-5) | Alert → Relaxed → Drowsy → Sleeping |

### Gemini CLI Faces

| State | Face |
|-------|------|
| Processing | `ʕ•ᴥ•ʔ` |
| Permission | `ʕ๏ᴥ๏ʔ` |
| Complete | `ʕ♥ᴥ♥ʔ` |
| Subagent | `ʕ⇆ᴥ⇆ʔ` |
| Tool Error | `ʕ✕ᴥ✕ʔ` |

### Codex CLI Faces

| State | Face |
|-------|------|
| Processing | `ฅ^•ﻌ•^ฅ` |
| Permission | `ฅ^◉ﻌ◉^ฅ` |
| Complete | `ฅ^♥ﻌ♥^ฅ` |
| Subagent | `ฅ^⇆ﻌ⇆^ฅ` |
| Tool Error | `ฅ^✕ﻌ✕^ฅ` |

### OpenCode Faces

| State | Face |
|-------|------|
| Processing | `(°-°)` |
| Permission | `(°□°)` |
| Complete | `(^‿^)` |
| Subagent | `(⇆-⇆)` |
| Tool Error | `(✕_✕)` |

## Spinner Face Templates

When title-mode is `full`, the face's eyes are replaced with animated spinners:

| Agent | Template | Example (braille) |
|-------|----------|-------------------|
| Claude | `Ǝ[{L} {R}]E` | `Ǝ[⠋ ⠙]E` |
| Gemini | `ʕ{L}ᴥ{R}ʔ` | `ʕ⠋ᴥ⠙ʔ` |
| Codex | `ฅ^{L}ﻌ{R}^ฅ` | `ฅ^⠋ﻌ⠙^ฅ` |
| OpenCode | `({L}-{R})` | `(⠋-⠙)` |

`{L}` and `{R}` are replaced with spinner animation frames.

## Spinner Styles

| Style | Frames | Visual |
|-------|--------|--------|
| braille | `⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏` | Rotating dots |
| circle | `○ ◔ ◑ ◕ ● ◕ ◑ ◔` | Filling/emptying circle |
| block | `▁ ▂ ▃ ▄ ▅ ▆ ▇ █ ▇ ▆ ▅ ▄ ▃ ▂` | Pulsing bar |
| eye-animate | `• ◦ · ° ○ ◌ ◎ ● ◉ ⊙ ⊚ ⦿ ⦾ ◍ ◐ ◑` | Random eyes |
| none | (static face) | No animation |
| random | (per session) | Random style chosen at session start |

## Compact Face Mode

Replaces text eyes with emoji. State info is embedded in the face itself.

### Standard vs Compact

```
STANDARD:  Ǝ[• •]E 🟠 +2 🦊 ~/proj    (face + icon + count + session + path)
COMPACT:   Ǝ[🟧 +2]E 🦊 ~/proj         (emoji eyes encode state + count)
```

### Compact Themes

**Semantic** (default) — Meaningful emoji per state:
| State | Eyes |
|-------|------|
| Processing | `🟠 🟠` `🟧 🟠` `🟧 🟧` `🧡 🧡` |
| Permission | `🔴 🔴` `🟥 ⭕` `⭕ ⭕` `🟥 🟥` |
| Complete | `✅ ✅` `🟢 🟢` `🟢 ✅` `🟩 🟩` |
| Subagent | `🔶 🔶` `🟡 🟡` `💛 💛` `🔸 🔸` |
| Tool Error | `❌ ❌` `❌ ⭕` `⛔ ⛔` `🔴 ❌` |

**Circles** — Uniform round emoji (one pair per state):
Processing `🟠 🟠`, Permission `🔴 🔴`, Complete `🟢 🟢`

**Squares** — Bold block emoji:
Processing `🟧 🟧`, Permission `🟥 🟥`, Complete `🟩 🟩`

**Mixed** — Asymmetric pairs (multiple variants):
Processing `🟧 🟠`, Permission `🟥 ⭕`, Complete `✅ 🟢`

## Agent Color Palettes

Each agent has unique dark/light background colors. Example (dark mode):

| State | Claude | Gemini | Codex | OpenCode |
|-------|--------|--------|-------|----------|
| Base | `#2E3440` | `#2B3540` | `#303035` | `#3A3530` |
| Processing | `#473D2F` | `#3D4A47` | `#454035` | `#504030` |
| Permission | `#4A2021` | `#4A2028` | `#452830` | `#502520` |
| Complete | `#473046` | `#304640` | `#354538` | `#404538` |

Claude has Anthropic purple accents, Gemini has Google blue influence,
Codex uses neutral tones, OpenCode has warm amber/earth tones.

## Customizing Agent Appearance

Override per-agent settings in `~/.tavs/user.conf`:

```bash
# Custom Claude processing faces
CLAUDE_FACES_PROCESSING=('Ǝ[⊕ ⊕]E' 'Ǝ[⊗ ⊗]E')

# Custom Gemini dark base color
GEMINI_DARK_BASE="#1E2030"

# Custom spinner face frame
CLAUDE_SPINNER_FACE_FRAME='C[{L} {R}]C'
```

Resolution priority: User config > Agent-specific defaults > Generic defaults.
