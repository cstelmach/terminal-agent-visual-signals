# Contributing to TAVS

Thanks for your interest in contributing to Terminal Agent Visual Signals!

## Quick Links

- [Bug reports](https://github.com/cstelmach/terminal-agent-visual-signals/issues/new?template=bug_report.yml)
- [Feature requests](https://github.com/cstelmach/terminal-agent-visual-signals/issues/new?template=feature_request.yml)
- [Discussions](https://github.com/cstelmach/terminal-agent-visual-signals/discussions)

## How to Contribute

### Reporting Bugs

1. Check [existing issues](https://github.com/cstelmach/terminal-agent-visual-signals/issues) first
2. Include your terminal (`echo $TERM_PROGRAM`), OS, and TAVS version (`./tavs version`)
3. Run `./tavs test --terminal` and include the output
4. Steps to reproduce the issue

### Submitting Changes

1. Fork the repo and create a branch from `main`
2. Make your changes
3. Test with `./tavs test` (full 8-state cycle)
4. Test on your terminal with `./tavs test --terminal`
5. Open a PR with a clear description

### Adding Themes

New theme presets are welcome. Each theme needs:

1. A `.conf` file in `src/themes/` with dark colors, light colors, and 16-color ANSI palette
2. An entry in `src/cli/aliases.sh` under `THEME_PRESET` valid values
3. An entry in `README.md` under "Available Themes"

Use an existing theme (e.g., `src/themes/nord.conf`) as a template.

### Adding Terminal Support

If your terminal supports OSC 11 (background color) but isn't listed:

1. Test with `./tavs test --terminal`
2. Add detection logic to `src/core/terminal-detection.sh`
3. Update the compatibility table in `README.md`
4. Open a PR with your terminal's name and test results

### Adding Agent Support

TAVS supports multiple AI coding agents. To add a new one:

1. Create `src/agents/<name>/trigger.sh` (see existing agents for pattern)
2. Add face definitions to `src/config/defaults.conf`
3. Add an install script to `src/install/`
4. Document in `README.md`

## Code Style

### Shell (Bash 3.2+)

TAVS must work on macOS's default Bash 3.2. This means:

- **No associative arrays** — use `case` statements instead
- **No `${var,,}` lowercase** — use `tr '[:upper:]' '[:lower:]'`
- **No `|&` pipe stderr** — use `2>&1 |`
- **No `declare -A`** — use positional patterns
- Use `local` for all function variables
- Quote all variable expansions: `"$var"`, not `$var`
- Use `[[ ]]` for conditionals, not `[ ]`

### Zsh Compatibility

The core modules are sourced in both bash and zsh contexts. Use intermediate
variables for brace defaults:

```bash
# Good — works in both bash and zsh
local _default_fmt='+{N}'
local fmt="${TAVS_AGENTS_FORMAT:-$_default_fmt}"

# Bad — fails in zsh
local fmt="${TAVS_AGENTS_FORMAT:-+{N}}"
```

### Variable Naming

- Global settings: `UPPER_SNAKE_CASE` (e.g., `THEME_MODE`)
- Local variables: `_prefixed` or `lower_snake` (e.g., `_default_val`)
- Functions: `lower_snake_case` (e.g., `compose_title`)
- Private functions: `_prefixed` (e.g., `_show_face`)

### Safe Patterns

- **Atomic writes**: `mktemp` + `mv`, never write directly to state files
- **No sourcing state files**: Use `while IFS='=' read` loops
- **Input validation**: Validate before `eval`, restrict to `[A-Za-z0-9_]`
- **Path sanitization**: Strip ASCII control characters from user-provided paths

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(scope): Add new feature
fix(scope): Fix bug description
docs: Update documentation
refactor(scope): Restructure without behavior change
test: Add or update tests
chore: Build, CI, or tooling changes
```

Common scopes: `cli`, `core`, `theme`, `title`, `spinner`, `config`, `hooks`, `faces`

## Testing

```bash
# Full visual test (cycles all 8 states)
./tavs test

# Quick test (3 states)
./tavs test --quick

# Terminal capability check
./tavs test --terminal

# Manual state testing
./src/core/trigger.sh processing
./src/core/trigger.sh permission
./src/core/trigger.sh complete
./src/core/trigger.sh reset

# Python unit tests
cd tests && python -m pytest -v
```

## Development Setup

```bash
# Clone
git clone https://github.com/cstelmach/terminal-agent-visual-signals.git
cd terminal-agent-visual-signals

# Make scripts executable
chmod +x src/core/trigger.sh tavs

# Test that it works
./tavs test --quick

# After changes, sync to plugin cache
./tavs sync
```

## License

By contributing, you agree that your contributions will be licensed under the
[MIT License](LICENSE).
