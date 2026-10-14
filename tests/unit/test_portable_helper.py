import errno
import json
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "src/core"))
import portable_helper as helper
import portable_metadata as metadata
from portable_context import encode_context, decode_context
from portable_records import StaleRecordError, key
import portable_record_io as records
import test_portable_ownership as fixture


def render_input(color="#123456"):
    fields = [""]*23
    fields[0], fields[18], fields[22] = color, "0", "0"
    return ("\0".join(fields)+"\0").encode()


class PortableHelperTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix="helper-", dir=os.environ["TAVS_TEST_ROOT"]))
        self.environment = dict(os.environ, HOME=str(self.root / "home"), TAVS_RUNTIME_DIR=str(self.root / "runtime"))
        self.marker = str(self.root / "home/.tavs/visual-restrictions.state")
        self.runtime = str(self.root / "runtime")
        self.context = {"schema": 1, "deliveryID": "delivery-43", "observedAt": time.time(),
                        "provider": "claude", "verifiedAgent": False}

    def test_unsupported_recovery_capabilities_and_counts_have_private_errors_without_mutation(self):
        requests = [["helper", "--visual-recover", self.marker, self.runtime, "recover"],
                    ["helper", "--validate-config", "--managed-output-capabilities"],
                    ["helper", "--organizer-context", "claude"],
                    ["helper", "--managed-render", self.marker, self.runtime, "/dev/tty", "private-token", "1", "extra"]]
        for args in requests:
            result = helper.run(args, self.environment)
            self.assertEqual(result[0], 1)
            self.assertEqual(result[1], b"")
            self.assertNotIn(b"private-token", result[2])
        self.assertFalse(Path(self.marker).exists())
        self.assertFalse(Path(self.runtime).exists())

    def test_scope_presence_even_empty_refuses_before_input_or_identity(self):
        for key in ("TAVS_SESSIONS_TEST_ROOT", "TAVS_SESSIONS_TEST_TARGETS", "TAVS_SESSIONS_TEST_FIXTURE"):
            env = dict(self.environment, **{key: ""})
            with patch("portable_helper.read_input") as read, patch("portable_helper.capture") as capture:
                result = helper.run(["helper", "--organizer-intake", "claude", str(os.getpid())], env)
            self.assertEqual(result[0], 1)
            read.assert_not_called()
            capture.assert_not_called()

    def test_managed_test_roots_cannot_escape_owned_directory(self):
        env = dict(self.environment, TAVS_TEST_ROOT=str(self.root))
        escaped = str(self.root.parent / "outside-marker")
        args = ["helper", "--managed-register", escaped, self.runtime, "/dev/ttys043", str(os.getpid())]
        with patch("portable_helper.device_number") as device:
            result = helper.run(args, env)
        self.assertEqual(result[0], 1)
        device.assert_not_called()
        self.assertFalse(Path(self.runtime).exists())

    def test_intake_uses_complete_fixed_order_and_keeps_body_out_of_context(self):
        payload = json.dumps({"session_id": "session-43", "hook_event_name": "Stop", "prompt": "private-body"}).encode()
        with patch("portable_helper.read_input", return_value=payload), patch("portable_helper.capture", return_value=self.context):
            result = helper.run(["helper", "--organizer-intake", "claude", str(os.getpid())], self.environment)
        self.assertEqual(result[0], 0)
        parts = result[1].split(b"\0")
        self.assertEqual(parts[::2][:-1], [b"TAVS_PERMISSION_MODE", b"TAVS_TRANSCRIPT_PATH", b"TAVS_SESSION_ID",
                                         b"TAVS_CWD", b"TAVS_ORGANIZER_CONTEXT", b"TAVS_ORGANIZER_INTAKE"])
        decoded = decode_context(parts[9].decode(), time.time())
        self.assertNotIn("private-body", str(decoded))
        self.assertEqual(parts[11], b"1")

    def test_bad_payload_does_not_emit_any_success_marker_or_exception_text(self):
        with patch("portable_helper.read_input", return_value=b'{"session_id": 43, "prompt":"private-body"}'):
            result = helper.run(["helper", "--organizer-intake", "claude", str(os.getpid())], self.environment)
        self.assertEqual(result, (1, b"", b"Organizer metadata unavailable.\n"))

    def test_invalid_provider_is_rejected_before_consuming_input(self):
        with patch("portable_helper.read_input") as read:
            result = helper.run(["helper", "--organizer-intake", "unsupported", str(os.getpid())], self.environment)
        self.assertEqual(result[0], 1)
        read.assert_not_called()

    def test_render_reader_rejects_delayed_eof_without_renewing_deadline(self):
        clock = {"now": 0, "waits": 0}
        def ready(read, write, errors, timeout):
            clock["waits"] += 1
            if clock["waits"] == 2:
                clock["now"] = 0.2
            return read, [], []
        with tempfile.TemporaryFile() as stream:
            stream.write(render_input())
            stream.seek(0)
            with patch("portable_metadata.sys.stdin", stream), \
                    patch("portable_metadata.time.monotonic", side_effect=lambda: clock["now"]), \
                    patch("portable_metadata.select.select", side_effect=ready):
                with self.assertRaises(ValueError):
                    metadata.read_input(limit=16_384, timeout=0.1, regular_or_pipe=True)

    def test_symlink_loop_root_failure_does_not_escape_private_error_boundary(self):
        loop = self.root / "loop"
        loop.symlink_to(loop)
        args = ["helper", "--managed-register", str(loop / "marker"), self.runtime,
                "/dev/ttys043", str(os.getpid())]
        self.assertEqual(helper.run(args, self.environment), (1, b"", b"Managed output unavailable.\n"))

    def test_observation_publication_remains_data_only_and_stale_has_code_three(self):
        token = encode_context(self.context, time.time())
        args = ["helper", "--organizer-observe", "/dev/ttys043", token, "complete"]
        self.assertEqual(helper.run(args, self.environment), (0, b"", b""))
        older = dict(self.context, observedAt=self.context["observedAt"]-1, deliveryID="older")
        args[3] = encode_context(older, time.time())
        self.assertEqual(helper.run(args, self.environment), (3, b"", b""))

    def test_dispatch_does_not_classify_generic_target_estale_as_stale_data(self):
        producer = {"pid": 43, "startSeconds": 100, "startMicroseconds": 0}
        value = dict(self.context, producer=producer, device=123)
        token = encode_context(value, time.time())
        args = ["helper", "--managed-render", self.marker, self.runtime, "/dev/ttys043", token, "1"]
        for error, code in ((OSError(errno.ESTALE, "private-path target changed"), 1),
                            (StaleRecordError("private-token data changed"), 3)):
            with patch("portable_helper.device_number", return_value=123), \
                    patch("portable_helper.inspect", return_value={"generation": producer, "device": 123}), \
                    patch("portable_helper.read_input", return_value=render_input()), \
                    patch("portable_helper.Renderer") as renderer:
                renderer.return_value.render.side_effect = error
                result = helper.run(args, self.environment)
            self.assertEqual(result[0], code)
            self.assertEqual(result[1], b"")
            self.assertNotIn(b"private-", result[2])


@unittest.skipUnless(sys.platform == "darwin", "Owned macOS helper/device acceptance")
class PortableHelperPTYTests(fixture.OwnedPTYFixture, unittest.TestCase):
    child_producer = True

    def setUp(self):
        super().setUp()
        self.helper_path = Path(__file__).resolve().parents[2] / "src/core/portable_helper.py"
        self.context = {"schema": 1, "deliveryID": "delivery-43", "observedAt": time.time(),
                        "provider": "claude", "verifiedAgent": False, "device": self.store.device(self.tty),
                        "producer": self.producer, "event": "Stop"}
        self.token = encode_context(self.context, time.time())
        self.env = dict(os.environ, TAVS_RUNTIME_DIR=str(self.runtime))

    def observe(self, **changes):
        value = dict(self.context, tty=self.tty, state="complete", **changes)
        path = self.store.directory / ("observation-"+key(self.tty)+".json")
        records.write(self.store.directory, path, value, "observation", time.time(), time.monotonic_ns()+100_000_000)
        return path

    def invoke(self, verb="--managed-render", tail=None, input=render_input()):
        tail = [self.token, "1"] if tail is None else tail
        return subprocess.run([sys.executable, str(self.helper_path), verb, str(self.marker), str(self.runtime),
                               self.tty, *tail], input=input, env=self.env, capture_output=True, timeout=3)

    def test_synthetic_render_is_exact_and_unrelated_ordinary_caller_never_switches_mode(self):
        self.observe()
        failed = self.invoke(tail=[self.token, "0"])
        self.assertEqual(failed.returncode, 1)
        self.assertEqual(failed.stdout, b"")
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])
        self.assertFalse((self.store.directory / ("intent-"+key(self.tty)+".json")).exists())
        rendered = self.invoke()
        self.assertEqual((rendered.returncode, rendered.stdout, rendered.stderr), (0, b"rendered\n", b""))
        self.assertTrue(select.select([self.master], [], [], 1)[0])
        self.assertEqual(os.read(self.master, 4096), b"\x1b]11;#123456\x1b\\")

    def test_stale_observation_and_record_type_keep_code_three_without_pixels(self):
        self.observe(deliveryID="other-delivery")
        failed = self.invoke(verb="--managed-check-context", tail=[self.token], input=b"")
        self.assertEqual((failed.returncode, failed.stdout, failed.stderr),
                         (3, b"", b"Managed output stale.\n"))
        path = self.store.directory / ("observation-"+key(self.tty)+".json")
        path.rename(path.with_name("saved-observation"))
        os.mkfifo(path)
        failed = self.invoke(verb="--managed-check-context", tail=[self.token], input=b"")
        self.assertEqual(failed.returncode, 3)
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])

    def test_marker_change_queued_during_open_returns_unaffected_without_pixels(self):
        self.observe()
        original_open = os.open
        def recover(path, flags, *args, **kwargs):
            if str(path) == self.tty:
                replacement = self.root / "replacement"
                replacement.write_bytes(b'SCHEMA_VERSION="1"\nSUSPENDED="true"\n')
                replacement.replace(self.marker)
            return original_open(path, flags, *args, **kwargs)
        args = ["helper", "--managed-render", str(self.marker), str(self.runtime), self.tty, self.token, "1"]
        with patch("portable_helper.read_input", return_value=render_input()), patch("portable_device_writer.os.open", side_effect=recover):
            self.assertEqual(helper.run(args, self.env), (0, b"unaffected\n", b""))
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])

    def test_render_input_without_eof_times_out_before_intent_or_device_output(self):
        self.observe()
        args = [sys.executable, str(self.helper_path), "--managed-render", str(self.marker), str(self.runtime),
                self.tty, self.token, "1"]
        process = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, env=self.env)
        try:
            process.stdin.write(render_input())
            process.stdin.flush()
            process.wait(timeout=1)
            self.assertEqual(process.returncode, 1)
            self.assertEqual(process.stdout.read(), b"")
            self.assertEqual(process.stderr.read(), b"Managed output unavailable.\n")
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=1)
            process.stdin.close()
            process.stdout.close()
            process.stderr.close()
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])
        self.assertFalse((self.store.directory / ("intent-"+key(self.tty)+".json")).exists())

    def test_render_input_rejects_oversize_and_character_device_without_consuming_it(self):
        self.observe()
        failed = self.invoke(input=b"x"*16_385)
        self.assertEqual(failed.returncode, 1)
        args = [sys.executable, str(self.helper_path), "--managed-render", str(self.marker), str(self.runtime),
                self.tty, self.token, "1"]
        failed = subprocess.run(args, stdin=self.master, env=self.env, capture_output=True, timeout=3)
        self.assertEqual(failed.returncode, 1)
        self.assertFalse(select.select([self.master], [], [], 0.05)[0])
        self.assertFalse((self.store.directory / ("intent-"+key(self.tty)+".json")).exists())


if __name__ == "__main__":
    unittest.main()
