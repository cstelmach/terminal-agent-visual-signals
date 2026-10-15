#!/usr/bin/env python3
"""Finite macOS/Linux ordinary helper entry; no native control or recovery capability."""

import os
from pathlib import Path
import re
import stat
import sys
import time

from portable_context import capture, decode_context, encode_context
from portable_intent import Intents
from portable_metadata import PROVIDERS, decode_intake, read_input
from portable_observation import publish_observation
from portable_policy import Policy
from portable_process_identity import caller_ancestor, device_number, inspect
from portable_records import StaleRecordError, _text, current_schema, generation_schema
from portable_ownership import Store
from portable_render import Render, normalized_background
from portable_renderer import Renderer


_SCOPE_KEYS = {"TAVS_SESSIONS_TEST_ROOT", "TAVS_SESSIONS_TEST_TARGETS", "TAVS_SESSIONS_TEST_FIXTURE"}
_COUNTS = {"--organizer-intake": 4, "--organizer-context": 4, "--organizer-observe": 5, "--organizer-intent": 6,
           "--managed-register": 6, "--managed-current": 6, "--managed-reconcile": 6,
           "--managed-check-context": 6, "--managed-background": 8,
           "--managed-render": 7, "--managed-forced-reset": 7}


def _path(value):
    _text(value, 4096)
    path = Path(value)
    if not path.is_absolute():
        raise ValueError("Absolute helper path required")
    return path


def _resolved_test_path(path):
    missing = []
    while True:
        try:
            return Path(os.path.normpath(path.resolve(strict=True).joinpath(*reversed(missing))))
        except FileNotFoundError:
            if path.is_symlink() or path.parent == path:
                raise ValueError("Helper test path unavailable") from None
            missing.append(path.name)
            path = path.parent


def _roots(marker, runtime, environment):
    marker, runtime = _path(marker), _path(runtime)
    if "TAVS_TEST_ROOT" in environment:
        root = _path(environment["TAVS_TEST_ROOT"]).resolve(strict=True)
        # Installed Darwin SDK: _CS_DARWIN_USER_TEMP_DIR is 65537, independent of test TMPDIR.
        temporary = [Path("/tmp").resolve()]
        if sys.platform == "darwin":
            temporary.insert(0, _path(os.confstr(65537)).resolve())
        info = root.stat()
        if (not any(base in root.parents for base in temporary) or not stat.S_ISDIR(info.st_mode)
                or info.st_uid != os.geteuid() or info.st_mode & 0o077
                or root not in _resolved_test_path(marker).parents
                or root not in _resolved_test_path(runtime).parents):
            raise ValueError("Helper test roots unavailable")
    return marker, runtime


def _pid(value):
    if not isinstance(value, str) or re.fullmatch(r"\+?[0-9]+", value) is None:
        raise ValueError("Invalid caller PID")
    digits = value.lstrip("+").lstrip("0") or "0"
    if len(digits) > 10 or not 0 < int(digits) <= 2**31-1:
        raise ValueError("Invalid caller PID")
    return int(digits)


def _flag(value):
    if value not in {"0", "1"}:
        raise ValueError("Invalid synthetic flag")
    return value == "1"


def _failure_label(error):
    # Exception messages and subclass names can contain private caller data.
    if isinstance(error, OSError):
        code = error.errno
        return "os-"+str(code) if type(code) is int and 1 <= code <= 4095 else "os"
    for kind, label in ((UnicodeError, "unicode"), (ValueError, "value"), (TypeError, "type"),
                        (KeyError, "key"), (OverflowError, "overflow"),
                        (RecursionError, "recursion"), (RuntimeError, "runtime")):
        if isinstance(error, kind):
            return label
    return "other"


def run(args, environment=None):
    environment = dict(os.environ if environment is None else environment)
    verb = args[1] if len(args) > 1 else ""
    organizer = verb.startswith("--organizer-")
    stage = "request"
    try:
        if (sys.platform in {"darwin", "linux"} and not _SCOPE_KEYS.intersection(environment) and len(args) == 3
                and args[1:] == ["--validate-config", "--portable-ordinary-capabilities"]):
            identity = inspect(os.getpid())
            if identity is None or generation_schema(identity["generation"]) != current_schema():
                raise ValueError("Process identity unavailable")
            return 0, b"tavs-portable-ordinary-schema=1\n", b""
        if (sys.platform not in {"darwin", "linux"} or _SCOPE_KEYS.intersection(environment)
                or verb not in _COUNTS or len(args) != _COUNTS[verb]):
            raise ValueError("Unsupported helper request")
        if verb in {"--organizer-intake", "--organizer-context"}:
            provider, caller = args[2], _pid(args[3])
            if provider not in PROVIDERS:
                raise ValueError("Invalid context provider")
            fields, event, response = (decode_intake(read_input(), provider) if verb == "--organizer-intake"
                                      else ({}, None, None))
            commands = [entry+"/"+provider for entry in environment.get("PATH", "").split(":") if entry.startswith("/")]
            context = capture(provider, caller, event=event, response_id=response, commands=commands)
            token = encode_context(context, time.time())
            if verb == "--organizer-context":
                return 0, (token+"\n").encode(), b""
            fields.update(TAVS_ORGANIZER_CONTEXT=token, TAVS_ORGANIZER_INTAKE="1")
            order = ("TAVS_PERMISSION_MODE", "TAVS_TRANSCRIPT_PATH", "TAVS_SESSION_ID", "TAVS_CWD",
                     "TAVS_ORGANIZER_CONTEXT", "TAVS_ORGANIZER_INTAKE")
            return 0, "".join(name+"\0"+fields.get(name, "")+"\0" for name in order).encode(), b""
        if organizer:
            marker, runtime = _roots(str(_path(environment["HOME"]) / ".tavs/visual-restrictions.state"),
                                     environment.get("TAVS_RUNTIME_DIR", "/tmp/tavs-"+str(os.getuid())), environment)
            context = decode_context(args[3], time.time())
            if context["schema"] != current_schema():
                raise ValueError("Context platform unavailable")
            store = Store(runtime, Policy(marker, runtime))
            if verb == "--organizer-observe":
                publish_observation(store, context, args[2], args[4])
            else:
                record = {"schema": context["schema"], "tty": args[2], "deliveryID": context["deliveryID"],
                          "updatedAt": time.time(), "background": args[4]}
                for field in ("device", "producer"):
                    if context.get(field) is not None:
                        record[field] = context[field]
                Intents(store).publish_unbound(record, _flag(args[5]), context["observedAt"])
            return 0, b"", b""
        stage = "roots"
        marker, runtime = _roots(args[2], args[3], environment)
        stage = "identity"
        tty = args[4]
        device = device_number(tty)
        if device is None:
            raise ValueError("Concrete helper device unavailable")
        if verb in {"--managed-register", "--managed-current", "--managed-reconcile"}:
            caller = caller_ancestor(_pid(args[5]), None if verb == "--managed-reconcile" else device)
            stage = "setup"
            renderer = Renderer(Store(runtime, Policy(marker, runtime)))
            stage = "write"
            if verb == "--managed-reconcile":
                wrote = renderer.reconcile(tty)
            else:
                wrote = (renderer.register if verb == "--managed-register" else renderer.current)(tty, caller)
        else:
            stage = "context"
            context = decode_context(args[5], time.time())
            if context["schema"] != current_schema():
                raise ValueError("Context platform unavailable")
            producer = context.get("producer")
            if producer is None or context.get("device") is None:
                raise ValueError("Context identity unavailable")
            if context["device"] != device:
                raise StaleRecordError("Context device stale")
            forced = verb == "--managed-forced-reset"
            if not forced:
                current = inspect(producer["pid"])
                if current is None or current["generation"] != producer or current["device"] != device:
                    raise StaleRecordError("Context producer stale")
            synthetic = True if forced or verb == "--managed-check-context" else _flag(args[7] if verb == "--managed-background" else args[6])
            background = normalized_background(args[6]) if verb == "--managed-background" else "reset"
            if forced:
                _text(args[6], 512, nonempty=False)
            if not synthetic and caller_ancestor(producer["pid"], device) != producer:
                raise StaleRecordError("Caller generation stale")
            record = {"schema": context["schema"], "tty": tty, "device": device, "producer": producer,
                      "deliveryID": context["deliveryID"], "updatedAt": time.time(), "background": background}
            intake = context["observedAt"]
            stage = "input"
            display = (Render(read_input(limit=16_384, timeout=0.1, regular_or_pipe=True))
                       if verb == "--managed-render" else None)
            stage = "setup"
            renderer = Renderer(Store(runtime, Policy(marker, runtime)))
            stage = "write"
            if verb == "--managed-render":
                wrote = renderer.render(display, record, synthetic, intake)
            elif verb == "--managed-background":
                wrote = renderer.background(record, synthetic, intake)
            elif forced:
                wrote = renderer.forced_reset(record, intake, args[6])
            else:
                wrote = renderer.check_context(record, intake)
        output = "rendered" if verb == "--managed-render" and wrote else "restored" if wrote else "unaffected"
        return 0, (output+"\n").encode(), b""
    except StaleRecordError:
        return 3, b"", b"" if organizer else b"Managed output stale.\n"
    except (OSError, ValueError, UnicodeError, TypeError, KeyError, OverflowError, RecursionError, RuntimeError) as error:
        diagnostic = "Managed output unavailable. stage="+stage+" failure="+_failure_label(error)+".\n"
        return 1, b"", b"Organizer metadata unavailable.\n" if organizer else diagnostic.encode()


def main():
    code, output, error = run(sys.argv)
    sys.stdout.buffer.write(output)
    sys.stderr.buffer.write(error)
    return code


if __name__ == "__main__":
    sys.exit(main())
