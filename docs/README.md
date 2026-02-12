# TAVS Documentation

## Quick Navigation

| Document | About | Read When |
|----------|-------|-----------|
| [Architecture](reference/architecture.md) | How core modules connect to agent adapters, OSC sequences, state machine design | Understanding signal flow, adding agent support, debugging |
| [Agent Themes](reference/agent-themes.md) | Per-agent faces, colors, backgrounds, override priority | Customizing agent appearance, creating custom themes |
| [Palette Theming](reference/palette-theming.md) | 16-color ANSI palette modification, TrueColor limitations, theme presets | Enabling palette theming, understanding color behavior |
| [Testing](reference/testing.md) | Manual and automated testing procedures, terminal compatibility | Verifying changes, testing installations, debugging |
| [Development Testing](reference/development-testing.md) | Plugin cache updates, live-testing workflow | Making code changes, deploying to plugin cache |
| [Troubleshooting](troubleshooting/overview.md) | Quick fixes for common problems, terminal compatibility, debug mode | When signals don't work, colors are wrong, titles missing |

## For New Users

Start with the [README](../README.md) for installation and configuration.

The most common reference: run `./tavs set` to see all 23 available settings,
or `./tavs status` for a visual preview of your current configuration.

## For Contributors

See [CONTRIBUTING.md](../CONTRIBUTING.md) for code style, testing, and PR guidelines.

## Archive

Historical planning documents from feature development:

- [PLAN: Anthropomorphising](archive/PLAN-anthropomorphising.md) — Implementation plan for ASCII faces feature
- [SPEC: Anthropomorphising](archive/SPEC-anthropomorphising.md) — Design specification for face expressions
