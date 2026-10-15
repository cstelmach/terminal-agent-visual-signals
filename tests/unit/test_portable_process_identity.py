import ctypes
import errno
import json
import os
from pathlib import Path
import pty
import select
import signal
import sys
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "src/core"))
import portable_process_identity as identity
from test_portable_records import linux_generation


class PortableProcessIdentityTests(unittest.TestCase):
    def test_linux_foreground_and_ancestry_cannot_bridge_namespace_scopes(self):
        first, second = linux_generation(43), linux_generation(100)
        second["linuxScope"]["timeNamespace"][1] += 1
        values = {43: {"generation": first, "parentPID": 100, "device": 123,
                       "group": 100, "foregroundGroup": 100},
                  100: {"generation": second, "parentPID": 1, "device": 123,
                        "group": 100, "foregroundGroup": 100}}
        self.assertFalse(identity.foreground_family_contains(first, second, 123, values.get))
        self.assertIsNone(identity.continuing_owner(first, 123, values.get))
        with self.assertRaises(OSError):
            identity.caller_ancestor(100, 123, lookup=values.get, start=43, deadline=2**63-1)

    def test_caller_ancestor_requires_actual_chain_and_current_generation_device(self):
        def process(pid, parent, device=43):
            return {"generation": {"pid": pid, "startSeconds": 100, "startMicroseconds": 1},
                    "parentPID": parent, "group": 10, "device": device, "foregroundGroup": 10}
        values = {10: process(10, 20), 20: process(20, 30), 30: process(30, 1, 99)}
        self.assertEqual(identity.caller_ancestor(20, 43, lookup=values.get, start=10), values[20]["generation"])
        self.assertEqual(identity.caller_ancestor(30, lookup=values.get, start=10), values[30]["generation"])
        for pid, device in ((99, None), (30, 43), (True, None), (0, None)):
            with self.assertRaises(OSError):
                identity.caller_ancestor(pid, device, lookup=values.get, start=10)
        values[20]["parentPID"] = 10
        with self.assertRaises(OSError):
            identity.caller_ancestor(30, lookup=values.get, start=10)

    def test_caller_ancestor_rechecks_device_birth_and_original_deadline(self):
        generation = {"pid": 43, "startSeconds": 100, "startMicroseconds": 1}
        process = {"generation": generation, "parentPID": 1, "device": 123}
        for changed in (dict(process, device=124), dict(process, generation=dict(generation, startSeconds=101))):
            with patch("portable_process_identity.inspect", side_effect=[process, changed]):
                with self.assertRaises(OSError):
                    identity.caller_ancestor(43, 123, start=43)
        with self.assertRaises(OSError) as failure:
            identity.caller_ancestor(43, lookup=lambda pid: process, start=43, deadline=time.monotonic_ns()-1)
        self.assertEqual(failure.exception.errno, errno.ETIMEDOUT)

    def test_caller_ancestor_depth_and_late_lookup_do_not_extend_the_budget(self):
        def process(pid):
            return {"generation": {"pid": pid, "startSeconds": 100, "startMicroseconds": 1},
                    "parentPID": pid+1, "device": 123}
        self.assertEqual(identity.caller_ancestor(25, lookup=process, start=10), process(25)["generation"])
        with self.assertRaises(OSError):
            identity.caller_ancestor(26, lookup=process, start=10)
        deadline = time.monotonic_ns()+5_000_000
        def late_lookup(pid):
            time.sleep(0.01)
            return process(pid)
        with self.assertRaises(OSError) as failure:
            identity.caller_ancestor(10, lookup=late_lookup, start=10, deadline=deadline)
        self.assertEqual(failure.exception.errno, errno.ETIMEDOUT)

    @unittest.skipUnless(sys.platform == "darwin", "Current macOS process evidence")
    def test_real_helper_caller_ancestry_is_distinct_from_unrelated_pty_actor(self):
        self.assertEqual(identity.caller_ancestor(os.getpid()), identity.inspect(os.getpid())["generation"])
        self.assertEqual(identity.caller_ancestor(os.getppid()), identity.inspect(os.getppid())["generation"])

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
