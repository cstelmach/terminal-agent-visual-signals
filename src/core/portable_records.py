"""Strict native schema-1 visual records and their canonical target paths."""

import base64
import json
import math
from pathlib import Path
import posixpath
import re
import unicodedata

from portable_policy import check_deadline, read_regular
from portable_render import normalized_background, normalized_hex


def _object(value, required, optional=()):
    if (not isinstance(value, dict) or not set(required) <= value.keys()
            or not value.keys() <= set(required) | set(optional)):
        raise ValueError("Invalid visual record shape")


def _integer(value, low, high):
    if type(value) is not int or not low <= value <= high:
        raise ValueError("Invalid visual record integer")


def _text(value, limit, nonempty=True):
    if (not isinstance(value, str) or (nonempty and not value) or len(value.encode("utf-8")) > limit
            or any(unicodedata.category(c) in {"Cc", "Cf"} for c in value)):
        raise ValueError("Invalid visual record text")


def _id(value):
    _text(value, 128)
    if re.fullmatch(r"[A-Za-z0-9.:_-]+", value) is None:
        raise ValueError("Invalid visual record identity")


def _generation(value):
    _object(value, ("pid", "startSeconds", "startMicroseconds"))
    _integer(value["pid"], 1, 2**31 - 1)
    _integer(value["startSeconds"], 1, 2**64 - 1)
    _integer(value["startMicroseconds"], 0, 999_999)


def _surface(value):
    _object(value, ("application", "terminalID"))
    _generation(value["application"])
    _text(value["terminalID"], 128)


def _tty(value, concrete=False):
    _text(value, 128)
    if (not value.startswith("/") or posixpath.normpath(value) == "/dev/tty"
            or any(c in {".", ".."} for c in value.split("/"))
            or (concrete and re.fullmatch(r"/dev/tty[A-Za-z0-9]+", value) is None)):
        raise ValueError("Invalid visual record TTY")


def _target(value):
    _object(value, ("tty", "device", "ttyOwner"), ("nativeSurface",))
    _tty(value["tty"], concrete=True)
    _integer(value["device"], 0, 2**32 - 2)
    _generation(value["ttyOwner"])
    if value.get("nativeSurface") is not None:
        _surface(value["nativeSurface"])


def _timestamp(value, now):
    if (type(value) not in (int, float) or not 0 < value <= now
            or (type(value) is float and not math.isfinite(value))):
        raise ValueError("Invalid visual record timestamp")


def _common(value, timestamp, now):
    _tty(value["tty"])
    _id(value["deliveryID"])
    _timestamp(value[timestamp], now)
    if value.get("device") is not None:
        _integer(value["device"], 0, 2**32 - 2)
    producer = value.get("producer")
    if producer is not None:
        _generation(producer)
        if producer["startSeconds"] + producer["startMicroseconds"] / 1_000_000 > value[timestamp]:
            raise ValueError("Visual record predates producer")


def _pairs(items):
    result = {}
    for key, value in items:
        if key in result:
            raise ValueError("Duplicate visual record key")
        result[key] = value
    return result


def decode(data, kind, now):
    if len(data) > 8192:
        raise ValueError("Oversized visual record")
    try:
        value = json.loads(data.decode("utf-8"), object_pairs_hook=_pairs)
    except (UnicodeError, RecursionError) as error:
        raise ValueError("Invalid visual record JSON") from error
    if kind == "target":
        _object(value, ("schema", "target"))
        _target(value["target"])
    elif kind == "effect":
        _object(value, ("schema", "target", "controller", "effectID", "kind", "background", "heartbeatAt", "active"),
                ("focusColors", "revision"))
        _target(value["target"])
        _generation(value["controller"])
        _id(value["effectID"])
        _timestamp(value["heartbeatAt"], now)
        if type(value["active"]) is not bool or not isinstance(value["kind"], str) or value["kind"] not in {
                "globalRestriction", "selectiveBackground", "preview", "focus"}:
            raise ValueError("Invalid visual effect")
        if not isinstance(value["background"], str):
            raise ValueError("Invalid visual background")
        normalized_background(value["background"])
        colors, revision = value.get("focusColors"), value.get("revision")
        if ((value["kind"] == "focus") != (colors is not None)
                or (value["kind"] == "focus" and revision is None)
                or (revision is not None and value["kind"] not in {"focus", "preview"})):
            raise ValueError("Invalid visual effect recipe")
        if colors is not None:
            _object(colors, ("background", "foreground"))
            for component, color in colors.items():
                if not isinstance(color, str):
                    raise ValueError("Invalid visual focus color")
                colors[component] = normalized_hex(color)
        if revision is not None:
            _object(revision, ("device", "inode"))
            _integer(revision["device"], -2**31, 2**31 - 1)
            _integer(revision["inode"], 0, 2**64 - 1)
            if revision["inode"] == 0 and revision["device"] != 0:
                raise ValueError("Invalid suspension revision")
    elif kind in {"intent", "observation"}:
        if kind == "intent":
            _object(value, ("schema", "tty", "deliveryID", "updatedAt", "background"), ("device", "producer"))
            if not isinstance(value["background"], str):
                raise ValueError("Invalid visual background")
            normalized_background(value["background"])
            _common(value, "updatedAt", now)
        else:
            _object(value, ("schema", "tty", "provider", "verifiedAgent", "state", "deliveryID", "observedAt"),
                    ("device", "producer", "event", "responseID"))
            if (not isinstance(value["provider"], str) or value["provider"] not in {"claude", "codex"}
                    or type(value["verifiedAgent"]) is not bool or not isinstance(value["state"], str)
                    or value["state"] not in {"processing", "permission", "complete", "idle", "compacting",
                                              "reset", "subagent", "tool_error"}):
                raise ValueError("Invalid agent observation")
            event = value.get("event")
            if event is not None and (not isinstance(event, str) or event not in {
                    "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure", "PermissionRequest",
                    "Notification", "Stop", "SessionStart", "SessionEnd", "PreCompact", "SubagentStart",
                    "SubagentStop", "permission_prompt", "idle_prompt", "agent-turn-complete"}):
                raise ValueError("Invalid agent observation event")
            if value.get("responseID") is not None:
                _id(value["responseID"])
            _common(value, "observedAt", now)
    elif kind == "adoption":
        _object(value, ("schema", "tty", "device", "producer", "surface"),
                ("observationDeliveryID", "intentDeliveryID"))
        _tty(value["tty"], concrete=True)
        _integer(value["device"], 0, 2**32 - 2)
        _generation(value["producer"])
        _surface(value["surface"])
        for key in ("observationDeliveryID", "intentDeliveryID"):
            if value.get(key) is not None:
                _id(value[key])
    else:
        raise ValueError("Unknown visual record kind")
    _integer(value["schema"], 1, 1)
    return value


def read_record(path, kind, now, deadline, dir_fd=None):
    data = read_regular(path, deadline, 8192, dir_fd=dir_fd)
    result = decode(data, kind, now) if data is not None else None
    check_deadline(deadline)
    return result


def key(value):
    return base64.urlsafe_b64encode(value.encode("utf-8")).decode("ascii").rstrip("=")


def generation_key(value):
    _generation(value)
    return "%(pid)d-%(startSeconds)d-%(startMicroseconds)d" % value


def target_path(directory, target, filename):
    _target(target)
    if filename not in {"target.json", "bound-intent.json", "effect.json", "preview.json", "focus.json"}:
        raise ValueError("Invalid visual target filename")
    result = Path(directory) / "targets" / key(target["tty"]) / generation_key(target["ttyOwner"])
    surface = target.get("nativeSurface")
    return (result / generation_key(surface["application"]) / key(surface["terminalID"]) if surface
            else result / "plain") / filename
