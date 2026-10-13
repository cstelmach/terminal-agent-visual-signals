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
from portable_records import decode, read_record, target_path


GENERATION = {"pid": 43, "startSeconds": 100, "startMicroseconds": 123}
TARGET = {"tty": "/dev/ttys043", "device": 123, "ttyOwner": GENERATION}
EFFECT = {"schema": 1, "target": TARGET, "controller": GENERATION,
          "effectID": "effect:43", "kind": "preview", "background": "#123456",
          "heartbeatAt": 990, "active": True, "revision": {"device": 0, "inode": 0}}


def parse(value, kind="effect"):
    return decode(json.dumps(value).encode(), kind, now=1000)


class PortableRecordTests(unittest.TestCase):
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
