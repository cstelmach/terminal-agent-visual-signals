#!/usr/bin/env python3
"""Extract bounded legacy hook metadata without claiming organizer correlation."""

import fcntl
import json
import os
import select
import stat
import sys
import time
import unicodedata


def read_input(limit=1_048_576, timeout=2, regular_or_pipe=False):
    fd = sys.stdin.fileno()
    if regular_or_pipe:
        mode = os.fstat(fd).st_mode
        if not (stat.S_ISREG(mode) or stat.S_ISFIFO(mode)):
            raise ValueError("Render input unavailable")
    flags = fcntl.fcntl(fd, fcntl.F_GETFL)
    deadline = time.monotonic() + timeout
    data = bytearray()
    try:
        fcntl.fcntl(fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0 or not select.select([fd], [], [], remaining)[0]:
                raise ValueError("Metadata input unavailable")
            if time.monotonic() >= deadline:
                raise ValueError("Metadata input unavailable")
            try:
                chunk = os.read(fd, min(16_384, limit + 1 - len(data)))
            except (InterruptedError, BlockingIOError):
                continue
            if time.monotonic() >= deadline:
                raise ValueError("Metadata input unavailable")
            if not chunk:
                return data
            data.extend(chunk)
            if len(data) > limit:
                raise ValueError("Metadata input unavailable")
    finally:
        fcntl.fcntl(fd, fcntl.F_SETFL, flags)


def reject_constant(_):
    raise ValueError("Invalid metadata")


PROVIDERS = {"claude", "codex", "gemini", "opencode", "unknown"}
EVENTS = {"UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure", "PermissionRequest",
          "Stop", "SessionStart", "SessionEnd", "PreCompact", "SubagentStart", "SubagentStop"}


def _metadata(data, provider):
    if provider not in PROVIDERS or len(data) > 1_048_576:
        raise ValueError("Invalid provider")
    values = json.loads(data, parse_constant=reject_constant)
    if not isinstance(values, dict):
        raise ValueError("Invalid metadata")

    def string(key, limit=4096):
        value = values.get(key)
        if value is None:
            return ""
        if not isinstance(value, str) or len(value.encode("utf-8")) > limit or "\0" in value:
            raise ValueError("Invalid metadata")
        if key in {"session_id", "thread-id"} and any(
            unicodedata.category(char) in {"Cc", "Cf"} for char in value
        ):
            raise ValueError("Invalid metadata")
        return value

    mode = "default" if provider == "codex" else string("permission_mode", 128)
    if mode not in {"default", "plan", "acceptEdits", "dontAsk", "bypassPermissions"}:
        mode = "default"
    fields = {
        "TAVS_PERMISSION_MODE": mode,
        "TAVS_TRANSCRIPT_PATH": "" if provider == "codex" else string("transcript_path"),
        "TAVS_SESSION_ID": string("thread-id" if provider == "codex" else "session_id", 512),
        "TAVS_CWD": string("cwd"),
    }
    return fields, string


def decode_metadata(data, provider):
    return _metadata(data, provider)[0]


def decode_intake(data, provider):
    fields, string = _metadata(data, provider)
    event, response = None, None
    if provider == "codex":
        if string("type", 128) == "agent-turn-complete":
            event = "agent-turn-complete"
        response = string("turn-id", 256) or None
    else:
        hook = string("hook_event_name", 128)
        if hook in EVENTS:
            event = hook
        if hook == "Notification":
            kind = string("notification_type", 128)
            if kind in {"permission_prompt", "idle_prompt"}:
                event = kind
    return fields, event, response


def main():
    try:
        if len(sys.argv) != 3 or sys.argv[1] != "--legacy-intake":
            raise ValueError("Invalid request")
        fields = decode_metadata(read_input(), sys.argv[2])
        fields["TAVS_LEGACY_METADATA_INTAKE"] = "1"
        output = "".join(key + "\0" + value + "\0" for key, value in fields.items())
        sys.stdout.buffer.write(output.encode("utf-8"))
    except (ValueError, OSError, UnicodeError, RecursionError):
        print("tavs: legacy metadata unavailable", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
