import base64
import json
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import time
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "src/core"))
import portable_context as context
import portable_metadata as metadata
from portable_records import decode, key
import test_portable_ownership as fixture


def generation(pid):
    return {"pid": pid, "startSeconds": 100, "startMicroseconds": 0}


class PortableContextTests(unittest.TestCase):
    def setUp(self):
        self.values = {pid: {"generation": generation(pid), "parentPID": parent, "device": device,
                             "group": 43, "foregroundGroup": 43}
                       for pid, parent, device in [(44, 43, 123), (43, 90, 123), (90, 1, 999)]}

    def capture(self, provider="claude", **changes):
        options = dict(lookup=self.values.get, executable=lambda pid: "/bin/python3",
                       commands=[], clock=lambda: 1000)
        options.update(changes)
        return context.capture(provider, 44, **options)

    def test_foreground_fallback_is_not_verified_agent(self):
        first, second = self.capture(), self.capture()
        self.assertEqual(first["producer"], generation(43))
        self.assertEqual(first["device"], 123)
        self.assertFalse(first["verifiedAgent"])
        self.assertNotEqual(first["deliveryID"], second["deliveryID"])
        self.assertEqual(context.decode_context(context.encode_context(first, 1000), 1000), first)

    def test_native_provider_executable_verifies_ancestor_not_interpreter(self):
        self.assertEqual(self.capture(executable=lambda pid: "/opt/claude")["producer"], generation(44))
        self.assertTrue(self.capture(executable=lambda pid: "/opt/claude")["verifiedAgent"])
        self.assertFalse(self.capture("gemini", executable=lambda pid: "/opt/gemini")["verifiedAgent"])
        for name in ("node", "nodejs", "bun", "bash", "zsh", "sh", "dash", "python", "python3"):
            self.assertFalse(context.matches_provider("claude", "/bin/"+name, ["/bin/"+name]))

    def test_versioned_provider_symlink_is_executable_evidence(self):
        root = Path(tempfile.mkdtemp(prefix="provider-", dir=os.environ["TAVS_TEST_ROOT"]))
        version = root / "1.0.43"
        version.write_text("owned path fixture")
        command = root / "claude"
        command.symlink_to(version)
        self.assertTrue(context.matches_provider("claude", str(version), [str(command)]))
        self.assertFalse(context.matches_provider("claude", "claude", [str(command)]))

    def test_unrelated_foreground_or_reused_generation_cannot_verify(self):
        self.values[44]["group"] = 44
        self.assertEqual(self.capture()["producer"], generation(43))
        self.values[43]["group"] = 44
        self.assertNotIn("producer", self.capture(executable=lambda pid: "/opt/claude"))
        self.values[43]["group"] = 43
        calls = {}
        def reused_lookup(pid):
            value = self.values.get(pid)
            calls[pid] = calls.get(pid, 0)+1
            if pid == 44 and calls[pid] > 1:
                return dict(value, generation=dict(value["generation"], startSeconds=101))
            return value
        result = self.capture(lookup=reused_lookup, executable=lambda pid: "/opt/claude" if pid == 44 else "/bin/python")
        self.assertFalse(result["verifiedAgent"])
        self.assertEqual(result["producer"], generation(43))

    def test_missing_foreground_is_explicit_uncorrelated_context(self):
        self.values[43]["foregroundGroup"] = 0
        value = self.capture()
        self.assertNotIn("producer", value)
        self.assertNotIn("device", value)
        self.assertFalse(value["verifiedAgent"])
        for provider, caller in (("fake", 44), ("claude", True), ("claude", 0)):
            with self.assertRaises(ValueError):
                context.capture(provider, caller)

    def test_context_rejects_unknown_fields_nonfinite_future_and_linux_scope(self):
        value = self.capture()
        invalid = [dict(value, body="must not enter context"), dict(value, observedAt=1001),
                   dict(value, observedAt=float("nan")), dict(value, verifiedAgent=1),
                   dict(value, producer=dict(value["producer"], linuxScope={}))]
        for record in invalid:
            token = base64.b64encode(json.dumps(record).encode()).decode()
            with self.assertRaises(ValueError):
                context.decode_context(token, 1000)
        with self.assertRaises(ValueError):
            context.decode_context("x"*8193, 1000)
        duplicate = b'{"schema":1,"schema":1}'
        with self.assertRaises(ValueError):
            context.decode_context(base64.b64encode(duplicate).decode(), 1000)

    def test_intake_keeps_top_level_event_and_response_without_payload_body(self):
        payload = {"type": "agent-turn-complete", "thread-id": "thread-43", "turn-id": "turn-43",
                   "cwd": "/owned path", "last-assistant-message": "private output",
                   "verifiedAgent": True, "nested": {"turn-id": "wrong"}}
        fields, event, response = metadata.decode_intake(json.dumps(payload).encode(), "codex")
        self.assertEqual(event, "agent-turn-complete")
        self.assertEqual(response, "turn-43")
        self.assertEqual(fields["TAVS_SESSION_ID"], "thread-43")
        self.assertNotIn("private output", str((fields, event, response)))
        for kind in ("permission_prompt", "idle_prompt", "unrelated"):
            data = json.dumps({"hook_event_name": "Notification", "notification_type": kind}).encode()
            self.assertEqual(metadata.decode_intake(data, "claude")[1], None if kind == "unrelated" else kind)

    def test_new_intake_fields_are_bounded_without_changing_legacy_selection(self):
        for value in (43, "x"*129, "bad\0event"):
            data = json.dumps({"hook_event_name": value, "session_id": "session-43"}).encode()
            self.assertEqual(metadata.decode_metadata(data, "claude")["TAVS_SESSION_ID"], "session-43")
            with self.assertRaises(ValueError):
                metadata.decode_intake(data, "claude")
        for value in (False, "x"*257, "bad\0turn"):
            with self.assertRaises(ValueError):
                metadata.decode_intake(json.dumps({"turn-id": value}).encode(), "codex")


@unittest.skipUnless(sys.platform == "darwin", "Owned macOS foreground proof and native schema")
class PortableContextPTYTests(fixture.OwnedPTYFixture, unittest.TestCase):
    child_producer = True

    def test_real_foreground_fallback_matches_source_built_native_context(self):
        value = context.capture("claude", self.producer_pid)
        native = subprocess.run([os.environ["TAVS_TEST_HELPER_BIN"], "--organizer-context", "claude",
                                 str(self.producer_pid)], capture_output=True, timeout=3, check=True)
        expected = context.decode_context(native.stdout.decode().strip(), time.time())
        self.assertEqual(value["producer"], expected["producer"])
        self.assertEqual(value["device"], expected["device"])
        self.assertFalse(value["verifiedAgent"])
        self.assertFalse(expected["verifiedAgent"])
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])

    def test_python_token_is_accepted_by_native_observation_publisher_without_paint(self):
        value = context.capture("claude", self.producer_pid)
        value["event"] = "Stop"
        token = context.encode_context(value, time.time())
        subprocess.run([os.environ["TAVS_TEST_HELPER_BIN"], "--organizer-observe", self.tty, token, "complete"],
                       capture_output=True, timeout=3, check=True)
        path = self.store.directory / ("observation-"+key(self.tty)+".json")
        # Native organizer verbs use the explicit runtime environment, independent of this Store.
        native_path = Path(os.environ["TAVS_RUNTIME_DIR"]) / "organizer" / path.name
        saved = json.loads(native_path.read_bytes())
        self.assertEqual(saved["producer"], value["producer"])
        self.assertEqual(saved["deliveryID"], value["deliveryID"])
        self.assertFalse(saved["verifiedAgent"])
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])

    def test_native_intake_response_controls_do_not_break_ordinary_context(self):
        response = "turn\n43\u200d"
        native = subprocess.run([os.environ["TAVS_TEST_HELPER_BIN"], "--organizer-intake", "codex",
                                 str(self.producer_pid)],
                                input=json.dumps({"type": "agent-turn-complete", "turn-id": response}).encode(),
                                capture_output=True, timeout=3, check=True)
        pairs = native.stdout.split(b"\0")
        fields = dict(zip(pairs[::2], pairs[1::2]))
        value = context.decode_context(fields[b"TAVS_ORGANIZER_CONTEXT"].decode(), time.time())
        self.assertEqual(value["responseID"], response)
        self.assertEqual(context.capture("codex", self.producer_pid, response_id=response)["responseID"], response)
        with self.assertRaises(ValueError):
            decode(json.dumps(dict(value, tty=self.tty, state="complete")).encode(), "observation", time.time())
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])


if __name__ == "__main__":
    unittest.main()
