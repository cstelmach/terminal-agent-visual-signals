import ctypes
import json
import os
from pathlib import Path
import pty
import select
import signal
import sys
import time
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "src/core"))
import portable_process_identity as identity


class PortableProcessIdentityTests(unittest.TestCase):
    def test_linux_stat_keeps_tick_identity_and_discards_arbitrary_comm_bytes(self):
        fields = [b"S", b"1", b"43", b"43", b"34823", b"43"] + [b"0"] * 13 + [b"12345"]
        raw = b"43 (name ) \xff (name) " + b" ".join(fields)
        scope = {"bootID": "fixture-boot", "pidNamespace": [1, 2], "timeNamespace": [1, 3]}
        value = identity._parse_linux_stat(raw, 43, 100, 124_000_000_000, scope)
        self.assertEqual(value["generation"]["startSeconds"], 124)
        self.assertEqual(value["generation"]["startMicroseconds"], 450_000)
        self.assertEqual(value["device"], 34823)
        self.assertEqual(value["generation"]["linuxScope"], scope)
        self.assertNotIn("name", str(value))
        self.assertIsNone(identity._parse_linux_stat(raw, 44, 100, 124_000_000_000, scope))
        self.assertIsNone(identity._parse_linux_stat(raw, 43, 1024, 124_000_000_000, scope))
        self.assertIsNone(identity._parse_linux_stat(raw, 43, 100, 123_459_999_999, scope))
        self.assertIsNotNone(identity._parse_linux_stat(raw, 43, 100, 123_460_000_000, scope))
        for state in [b"Z", b"X", b"x", b"?"]:
            self.assertIsNone(identity._parse_linux_stat(raw.replace(b") S ", b") " + state + b" "),
                                                       43, 100, 124_000_000_000, scope))

    def test_invalid_and_missing_pids_are_unavailable(self):
        for pid in [0, -1, True, 2**31, "43"]:
            self.assertIsNone(identity.inspect(pid))

    @unittest.skipUnless(sys.platform == "darwin", "macOS libproc bridge")
    def test_libproc_layout_and_current_generation(self):
        self.assertEqual(ctypes.sizeof(identity._BSDInfo), 136)
        self.assertEqual(identity._BSDInfo.pbi_start_tvsec.offset, 120)
        self.assertEqual(identity._BSDInfo.pbi_start_tvusec.offset, 128)
        value = identity.inspect(os.getpid())
        self.assertEqual(value["generation"]["pid"], os.getpid())
        self.assertGreater(value["generation"]["startSeconds"], 0)
        self.assertLessEqual(value["generation"]["startSeconds"], time.time())
        self.assertEqual(value["parentPID"], os.getppid())
        self.assertEqual(value, identity.inspect(os.getpid()))

    def test_continuing_owner_rejects_reuse_and_preserves_top_same_device_ancestor(self):
        def process(pid, parent, device=43):
            return {"generation": {"pid": pid, "startSeconds": 100, "startMicroseconds": 1},
                    "parentPID": parent, "group": 10, "device": device, "foregroundGroup": 10}
        values = {10: process(10, 20), 20: process(20, 30), 30: process(30, 1, 99)}
        seed = values[10]["generation"].copy()
        self.assertEqual(identity.continuing_owner(seed, 43, values.get), values[20]["generation"])
        values[10]["generation"]["startMicroseconds"] = 2
        self.assertIsNone(identity.continuing_owner(seed, 43, values.get))
        values[10]["generation"] = seed
        values[20]["parentPID"] = 10
        self.assertIsNone(identity.continuing_owner(seed, 43, values.get))

    def test_device_validation_rejects_generic_regular_and_link_paths(self):
        root = Path(os.environ["TAVS_TEST_ROOT"])
        regular = root / "identity-regular"
        regular.write_text("fixture")
        link = root / "identity-link"
        link.symlink_to("/dev/null")
        for path in ["/dev/tty", "/dev/ttys../x", "/dev/null", str(regular), str(link)]:
            self.assertIsNone(identity.device_number(path))

    def test_owned_pty_has_exact_process_device_and_exited_generation(self):
        pid, master = pty.fork()
        if pid == 0:
            try:
                # Linux rejects a process before its complete birth tick has passed.
                if sys.platform == "linux":
                    time.sleep(2 / os.sysconf("SC_CLK_TCK"))
                value = identity.inspect(os.getpid())
                os.write(1, (json.dumps({"identity": value, "tty": os.ttyname(0)}) + "\n").encode())
                os.read(0, 1)
            finally:
                os._exit(0)
        try:
            data = bytearray()
            deadline = time.monotonic() + 3
            while b"\n" not in data:
                left = deadline - time.monotonic()
                self.assertGreater(left, 0)
                self.assertTrue(select.select([master], [], [], left)[0])
                data.extend(os.read(master, 4096))
                self.assertLess(len(data), 8192)
            value = json.loads(data.decode())
            source = value["identity"]
            self.assertEqual(source["generation"]["pid"], pid)
            self.assertEqual(source["group"], pid)
            self.assertEqual(source["foregroundGroup"], pid)
            self.assertEqual(identity.device_number(value["tty"]), source["device"])
            self.assertEqual(identity.inspect(pid), source)
        finally:
            alive, _ = os.waitpid(pid, os.WNOHANG)
            if alive == 0:
                os.kill(pid, signal.SIGTERM)
                os.waitpid(pid, 0)
            os.close(master)
        self.assertIsNone(identity.inspect(pid))


if __name__ == "__main__":
    unittest.main()
