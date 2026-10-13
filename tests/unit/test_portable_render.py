import base64
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "src/core"))
from portable_render import Render, normalized_background, normalized_hex


def payload(**changes):
    fields = [""] * 23
    fields[18] = fields[22] = "0"
    for index, value in changes.items():
        fields[int(index)] = value
    return ("\0".join(fields) + "\0").encode()


class PortableRenderTests(unittest.TestCase):
    def test_complete_style_preserves_native_order_and_synthetic_bell_suppression(self):
        image = "/fixture/image 🐈.png"
        style = Render(payload(**{"0": "rgb:f/80/0000", "1": "set", "2": "#123456",
                                  "18": "1", "19": "title 👩‍💻", "20": "iterm2-set",
                                  "21": image, "22": "1"}))
        self.assertEqual(style.background, "#FF8000")
        expected = (b"\x1b]4;0;rgb:12/34/56\x1b\\\x1b]11;#FF8000\x1b\\"
                    + "\x1b]0;title 👩‍💻\x1b\\".encode()
                    + b"\x1b]1337;SetBackgroundImageFile=" + base64.b64encode(image.encode()) + b"\a")
        self.assertEqual(style.encode(synthetic=True), expected)
        self.assertEqual(style.encode(synthetic=False), expected + b"\a")

    def test_empty_background_is_distinct_from_reset(self):
        self.assertEqual(Render(payload()).encode(), b"")
        self.assertEqual(Render(payload(**{"0": "reset"})).encode(), b"\x1b]111\x1b\\")
        self.assertEqual(Render(payload(**{"1": "reset", "20": "iterm2-clear"})).encode(),
                         b"\x1b]104\x1b\\\x1b]1337;SetBackgroundImageFile=\a")

    def test_protocol_rejects_malformed_sizes_utf8_flags_and_control_injection(self):
        invalid = [b"", b"\0" * 23, b"\0" * 25, payload()[:-1], b"\xff\0" * 23,
                   payload(**{"1": "unknown"}), payload(**{"2": "#123456"}),
                   payload(**{"18": "2"}), payload(**{"19": "hidden"}),
                   payload(**{"18": "1", "19": "\x1b]11;red"}),
                   payload(**{"18": "1", "19": "\u0085"}),
                   payload(**{"20": "iterm2-set", "21": "relative"}),
                   payload(**{"21": "/unused"}), payload(**{"22": "2"}),
                   payload(**{"18": "1", "19": "界" * 3000}), b"x" * 16385]
        for data in invalid:
            with self.subTest(size=len(data)), self.assertRaises(ValueError):
                Render(data)

    def test_background_normalization_matches_native_integer_scaling(self):
        self.assertEqual(normalized_background(" #abcdef \n"), "#ABCDEF")
        self.assertEqual(normalized_background("rgb:1234/ab/c"), "#12ABCC")
        for value in ["#abc", "red", "rgb:12345/0/0", "rgb:1/2", "RESET", "\x1b"]:
            with self.assertRaises(ValueError):
                normalized_background(value)

    def test_native_trim_set_and_unicode_uppercase_precede_hex_validation(self):
        self.assertEqual(normalized_hex("\u200b#abcdﬀ\u0085"), "#ABCDFF")
        self.assertEqual(normalized_background("#abcdﬀ"), "#ABCDFF")
        for scalar in range(0x1C, 0x20):
            with self.assertRaises(ValueError):
                normalized_hex(chr(scalar) + "#123456")


if __name__ == "__main__":
    unittest.main()
