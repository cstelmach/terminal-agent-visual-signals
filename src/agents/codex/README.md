# Codex CLI Integration - NOT YET AVAILABLE

## Status: Waiting for Codex Hooks Feature

As of January 2025, **Codex CLI does not have a hooks system**.

Hooks are currently a [feature request](https://github.com/openai/codex/discussions/2150)
in the Codex repository.

## Current Workarounds

While waiting for hooks, you can use:

1. **Notifications via config.toml:**
   ```toml
   notify = ["bash", "-lc", "afplay /System/Library/Sounds/Blow.aiff"]
   ```

2. **JSON event stream:**
   ```bash
   codex --json  # Outputs newline-delimited JSON events
   ```

3. **TUI notifications:**
   Configure `tui.notifications` to filter events like:
   - `agent-turn-complete`
   - `approval-requested`

## When Codex Adds Hooks

Once Codex implements hooks (likely similar to Claude/Gemini), update:
1. `hooks.json` with the actual event names
2. Remove this README placeholder

## References

- [Codex Hooks Discussion](https://github.com/openai/codex/discussions/2150)
- [Codex CLI Features](https://developers.openai.com/codex/cli/features/)
