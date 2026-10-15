import copy
import errno
import json
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "src/core"))
from portable_records import decode, generation_key, read_record, target_path


GENERATION = {"pid": 43, "startSeconds": 100, "startMicroseconds": 123}
TARGET = {"tty": "/dev/ttys043", "device": 123, "ttyOwner": GENERATION}
EFFECT = {"schema": 1, "target": TARGET, "controller": GENERATION,
          "effectID": "effect:43", "kind": "preview", "background": "#123456",
          "heartbeatAt": 990, "active": True, "revision": {"device": 0, "inode": 0}}


LINUX_SCOPE = {"bootID": "00000000-0000-0000-0000-000000000043",
               "pidNamespace": [4, 4026531836], "timeNamespace": [4, 4026531834],
               "timeOffsets": [[0, 0], [0, 0]]}


def linux_generation(pid=43, scope=None):
    return {"pid": pid, "startSeconds": 2_000_000_000, "startMicroseconds": 123,
            "linuxScope": copy.deepcopy(LINUX_SCOPE if scope is None else scope)}


def parse(value, kind="effect"):
    return decode(json.dumps(value).encode(), kind, now=1000)


class PortableRecordTests(unittest.TestCase):
    def test_linux_schema_two_keeps_scoped_birth_separate_from_wall_time(self):
        producer = linux_generation()
        target = {"tty": "/dev/pts/43", "device": 123, "ttyOwner": producer}
        self.assertEqual(parse({"schema": 2, "target": target}, "target")["target"], target)
        intent = {"schema": 2, "tty": target["tty"], "device": 123, "producer": producer,
                  "deliveryID": "delivery-43", "updatedAt": 990, "background": "#123456"}
        self.assertEqual(parse(intent, "intent"), intent)
        observation = {k: v for k, v in intent.items() if k not in {"updatedAt", "background"}}
        observation.update(provider="claude", verifiedAgent=False, state="complete", observedAt=990)
        self.assertEqual(parse(observation, "observation"), observation)
        effect = dict(EFFECT, schema=2, target=target, controller=linux_generation(44))
        self.assertEqual(parse(effect), effect)
        with self.assertRaises(ValueError):
            parse(dict(intent, updatedAt=1001), "intent")

    def test_linux_scopes_and_schema_mixes_reject_before_authority(self):
        base = {"schema": 2, "target": {"tty": "/dev/pts/43", "device": 123,
                                       "ttyOwner": linux_generation()}}
        invalid_scopes = [{}, dict(LINUX_SCOPE, unknown=1), dict(LINUX_SCOPE, bootID="not-a-boot"),
                          dict(LINUX_SCOPE, pidNamespace=[True, 1]),
                          dict(LINUX_SCOPE, timeNamespace=[4, 0]),
                          dict(LINUX_SCOPE, pidNamespace=[4, 2**64]),
                          dict(LINUX_SCOPE, timeOffsets=[[0, 0]]),
                          dict(LINUX_SCOPE, timeOffsets=[[0, 10**9], [0, 0]]),
                          dict(LINUX_SCOPE, timeOffsets=[[2**63, 0], [0, 0]])]
        for scope in invalid_scopes:
            invalid = copy.deepcopy(base); invalid["target"]["ttyOwner"]["linuxScope"] = scope
            with self.subTest(scope=scope), self.assertRaises(ValueError):
                parse(invalid, "target")
        for invalid in (dict(base, schema=1), dict(base, schema=True),
                        {"schema": 2, "target": TARGET},
                        dict(base, target=dict(base["target"], nativeSurface=None))):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                parse(invalid, "target")
        controller = linux_generation(44)
        controller["linuxScope"]["timeOffsets"][0][0] = 1
        with self.assertRaises(ValueError):
            parse(dict(EFFECT, schema=2, target=base["target"], controller=controller))
        for tty in ("/dev/pts/00", "/dev/pts/-1", "/dev//pts/43", "/dev/pts/4/3", "/dev/tty"):
            with self.subTest(tty=tty), self.assertRaises(ValueError):
                parse(dict(base, target=dict(base["target"], tty=tty)), "target")

    def test_linux_generation_keys_include_every_scope_field_and_fit_a_component(self):
        values = [linux_generation()]
        paths = [("bootID",), ("pidNamespace", 0), ("pidNamespace", 1),
                 ("timeNamespace", 0), ("timeNamespace", 1),
                 ("timeOffsets", 0, 0), ("timeOffsets", 0, 1),
                 ("timeOffsets", 1, 0), ("timeOffsets", 1, 1)]
        for path in paths:
            changed = linux_generation()
            parent = changed["linuxScope"]
            for part in path[:-1]:
                parent = parent[part]
            if path == ("bootID",):
                parent[path[-1]] = LINUX_SCOPE["bootID"][:-2] + "44"
            else:
                parent[path[-1]] += 1
            values.append(changed)
        keys = [generation_key(value) for value in values]
        self.assertEqual(len(set(keys)), len(values))
        reordered = linux_generation()
        reordered["linuxScope"] = dict(reversed(list(reordered["linuxScope"].items())))
        self.assertEqual(generation_key(reordered), keys[0])
        large = linux_generation(2**31-1)
        large.update(startSeconds=2**64-1, startMicroseconds=999999)
        large["linuxScope"].update(pidNamespace=[2**64-1, 2**64-1],
                                   timeNamespace=[2**64-1, 2**64-1],
                                   timeOffsets=[[-2**63, 999999999], [-2**63, 999999999]])
        self.assertLessEqual(len(generation_key(large).encode("ascii")), 255)
        target = {"tty": "/dev/pts/43", "device": 123, "ttyOwner": values[0]}
        self.assertIn(keys[0], target_path(Path("/runtime/organizer"), target, "target.json").parts)

    def test_native_target_effect_shapes_and_canonical_placement(self):
        self.assertEqual(parse(EFFECT), EFFECT)
        target = copy.deepcopy(TARGET)
        self.assertEqual(target_path(Path("/runtime/organizer"), target, "target.json"),
                         Path("/runtime/organizer/targets/L2Rldi90dHlzMDQz/43-100-123/plain/target.json"))
        target["nativeSurface"] = {"application": GENERATION, "terminalID": "pane 👩‍💻"}
        with self.assertRaises(ValueError):
            parse({"schema": 1, "target": target}, "target")
        target["nativeSurface"]["terminalID"] = "pane-43"
        self.assertEqual(parse({"schema": 1, "target": target}, "target")["target"], target)
        self.assertEqual(target_path(Path("/r"), target, "focus.json"),
                         Path("/r/targets/L2Rldi90dHlzMDQz/43-100-123/43-100-123/cGFuZS00Mw/focus.json"))

    def test_nested_unknown_keys_duplicate_keys_and_boolean_integers_reject(self):
        for location in [(), ("target",), ("target", "ttyOwner"), ("controller",), ("revision",)]:
            record = copy.deepcopy(EFFECT)
            value = record
            for key in location:
                value = value[key]
            value["unknown"] = "hidden"
            with self.subTest(location=location), self.assertRaises(ValueError):
                parse(record)
        for key, value in [("schema", True), ("active", 1), ("heartbeatAt", True),
                           ("heartbeatAt", float("nan")), ("heartbeatAt", 1001),
                           ("effectID", "x/../y"), ("kind", []), ("kind", {}),
                           ("heartbeatAt", 10**400)]:
            record = copy.deepcopy(EFFECT)
            record[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                parse(record)
        with self.assertRaises(ValueError):
            decode(b'{"schema":1,"schema":1}', "target", now=1000)
        with self.assertRaises(ValueError):
            decode(b'x' * 8193, "target", now=1000)

    def test_focus_recipe_requires_colors_and_revision(self):
        record = copy.deepcopy(EFFECT)
        record["kind"] = "focus"
        with self.assertRaises(ValueError):
            parse(record)
        record["focusColors"] = {"background": "#000000", "foreground": "#FFFFFF"}
        self.assertEqual(parse(record), record)
        noncanonical = copy.deepcopy(record)
        noncanonical["focusColors"]["foreground"] = " #abcdﬀ "
        self.assertEqual(parse(noncanonical)["focusColors"]["foreground"], "#ABCDFF")
        record["revision"]["device"] = -1
        record["revision"]["inode"] = 43
        self.assertEqual(parse(record), record)
        for change in [lambda r: r.pop("revision"),
                       lambda r: r["focusColors"].update({"background": "rgb:0/0/0"}),
                       lambda r: r.update({"kind": "globalRestriction"}),
                       lambda r: r["revision"].update({"inode": 0})]:
            invalid = copy.deepcopy(record)
            change(invalid)
            with self.assertRaises(ValueError):
                parse(invalid)

    def test_intent_and_observation_limits_without_inventing_correlation(self):
        intent = {"schema": 1, "tty": TARGET["tty"], "producer": GENERATION,
                  "device": 123, "deliveryID": "delivery-43", "updatedAt": 990,
                  "background": "rgb:1/2/3"}
        self.assertEqual(parse(intent, "intent"), intent)
        observation = {key: value for key, value in intent.items() if key not in {"updatedAt", "background"}}
        observation.update(provider="codex", verifiedAgent=False, state="complete", observedAt=990)
        self.assertFalse(parse(observation, "observation")["verifiedAgent"])
        for change in [{"updatedAt": 100}, {"device": True}, {"producer": dict(GENERATION, linuxScope={})},
                       {"tty": "/dev/tty"}, {"tty": "/dev//tty"}, {"tty": "/dev/../ttys043"}]:
            with self.subTest(change=change), self.assertRaises(ValueError):
                parse(dict(intent, **change), "intent")
        with self.assertRaises(ValueError):
            parse(dict(observation, event="untrusted-event"), "observation")
        for change in [{"provider": []}, {"state": {}}, {"event": []}]:
            with self.assertRaises(ValueError):
                parse(dict(observation, **change), "observation")

    def test_missing_regular_files_are_distinct_from_unreadable_or_invalid_records(self):
        root = Path(tempfile.mkdtemp(prefix="records-", dir=os.environ["TAVS_TEST_ROOT"]))
        path = root / "target.json"
        deadline = time.monotonic_ns() + 100_000_000
        self.assertIsNone(read_record(path, "target", 1000, deadline))
        path.write_text(json.dumps({"schema": 1, "target": TARGET}))
        self.assertEqual(read_record(path, "target", 1000, deadline)["target"], TARGET)
        path.write_text('{}')
        with self.assertRaises(ValueError):
            read_record(path, "target", 1000, deadline)
        link = root / "alias"
        link.symlink_to(path)
        with self.assertRaises(OSError):
            read_record(link, "target", 1000, deadline)

    def test_decode_cannot_return_a_record_after_the_original_deadline(self):
        root = Path(tempfile.mkdtemp(prefix="decode-deadline-", dir=os.environ["TAVS_TEST_ROOT"]))
        path = root / "target.json"
        path.write_text(json.dumps({"schema": 1, "target": TARGET}))
        start = time.monotonic_ns()
        deadline = start + 100_000_000
        with patch("portable_policy.time.monotonic_ns", return_value=start) as clock:
            def late_decode(data, kind, now):
                result = decode(data, kind, now)
                clock.return_value = deadline
                return result
            with patch("portable_records.decode", side_effect=late_decode) as decoder:
                with self.assertRaises(OSError) as failure:
                    read_record(path, "target", 1000, deadline)
                self.assertEqual(failure.exception.errno, errno.ETIMEDOUT)
                decoder.assert_called_once()

    def test_held_parent_descriptor_does_not_follow_a_replacement_directory(self):
        root = Path(tempfile.mkdtemp(prefix="held-parent-", dir=os.environ["TAVS_TEST_ROOT"]))
        directory = root / "records"
        directory.mkdir()
        (directory / "target.json").write_text(json.dumps({"schema": 1, "target": TARGET}))
        fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
        try:
            directory.rename(root / "old")
            directory.mkdir()
            (directory / "target.json").write_text('{}')
            record = read_record("target.json", "target", 1000,
                                 time.monotonic_ns() + 100_000_000, dir_fd=fd)
            self.assertEqual(record["target"], TARGET)
        finally:
            os.close(fd)


if __name__ == "__main__":
    unittest.main()
