"""Finite organizer correlation and current foreground/provider identity."""

import base64
import json
import os
from pathlib import Path
import time
import uuid

from portable_metadata import PROVIDERS
from portable_process_identity import executable_path, foreground_family_contains, inspect
from portable_records import _generation, _id, _integer, _object, _pairs, _timestamp, current_schema, generation_schema


def validate_context(value, now):
    _object(value, ("schema", "deliveryID", "observedAt", "provider", "verifiedAgent"),
            ("producer", "device", "event", "responseID"))
    _integer(value["schema"], 1, 2)
    _id(value["deliveryID"])
    _timestamp(value["observedAt"], now)
    if not isinstance(value["provider"], str) or value["provider"] not in PROVIDERS:
        raise ValueError("Invalid context provider")
    if type(value["verifiedAgent"]) is not bool:
        raise ValueError("Invalid context identity flag")
    if value.get("device") is not None:
        _integer(value["device"], 0, 2**32-2)
    producer = value.get("producer")
    if producer is not None:
        _generation(producer, value["schema"])
        if (value["schema"] == 1
                and producer["startSeconds"] + producer["startMicroseconds"] / 1_000_000 > value["observedAt"]):
            raise ValueError("Context predates producer")
    for field, limit in (("event", 128), ("responseID", 256)):
        if value.get(field) is not None:
            text = value[field]
            if not isinstance(text, str) or len(text.encode("utf-8")) > limit or "\0" in text:
                raise ValueError("Invalid context metadata string")
    return value


def encode_context(value, now):
    validate_context(value, now)
    token = base64.b64encode(json.dumps(value, ensure_ascii=False, allow_nan=False,
                                     separators=(",", ":")).encode("utf-8")).decode("ascii")
    if len(token) > 8192:
        raise ValueError("Oversized context token")
    return token


def decode_context(token, now):
    if not isinstance(token, str) or len(token.encode("utf-8")) > 8192:
        raise ValueError("Invalid context token")
    try:
        data = base64.b64decode(token, validate=True)
        value = json.loads(data.decode("utf-8"), object_pairs_hook=_pairs)
        return validate_context(value, now)
    except (ValueError, UnicodeError, RecursionError, TypeError) as error:
        raise ValueError("Invalid context token") from error


def matches_provider(provider, path, commands):
    if provider not in {"claude", "codex"} or not isinstance(path, str) or not path.startswith("/"):
        return False
    try:
        executable = Path(path).resolve()
        name = executable.name.lower()
        if name in {"node", "nodejs", "bun", "bash", "zsh", "sh", "dash"} or name.startswith("python"):
            return False
        return name == provider or any(Path(command).resolve() == executable for command in commands)
    except (OSError, RuntimeError):
        return False


def capture(provider, caller, event=None, response_id=None, lookup=inspect, executable=executable_path,
            commands=None, clock=time.time):
    if provider not in PROVIDERS or type(caller) is not int or not 0 < caller <= 2**31-1:
        raise ValueError("Invalid context request")
    if commands is None:
        commands = [entry+"/"+provider for entry in os.environ.get("PATH", "").split(":") if entry.startswith("/")]
    pid, owner, verified, visited = caller, None, False, set()
    for _ in range(16):
        if pid in visited:
            break
        visited.add(pid)
        source = lookup(pid)
        if source is None:
            break
        group = source["foregroundGroup"]
        foreground = lookup(group) if 0 < group <= 2**31-1 else None
        if foreground is not None and foreground_family_contains(
                source["generation"], foreground["generation"], source["device"], lookup):
            owner = owner or foreground
            if matches_provider(provider, executable(pid), commands):
                owner, verified = source, True
                break
        parent = source["parentPID"]
        if not 0 < parent <= 2**31-1 or parent == pid:
            break
        pid = parent
    schema = generation_schema(owner["generation"]) if owner is not None else current_schema()
    value = {"schema": schema, "deliveryID": str(uuid.uuid4()), "observedAt": clock(),
             "provider": provider, "verifiedAgent": verified}
    if owner is not None:
        value.update(producer=owner["generation"], device=owner["device"])
    if event is not None:
        value["event"] = event
    if response_id is not None:
        value["responseID"] = response_id
    return validate_context(value, value["observedAt"])
