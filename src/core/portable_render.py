"""Decode the finite native render request without interpreting arbitrary OSC."""

import base64
import re


# Foundation's whitespace/newline set differs from Python's default strip set.
_TRIM = ("\t\n\v\f\r \u0085\u00a0\u1680\u2000\u2001\u2002\u2003\u2004\u2005"
         "\u2006\u2007\u2008\u2009\u200a\u200b\u2028\u2029\u202f\u205f\u3000")


def normalized_hex(value):
    result = value.strip(_TRIM).upper()
    if re.fullmatch(r"#[0-9A-F]{6}", result) is None:
        raise ValueError("Invalid render color")
    return result


def normalized_background(value):
    if len(value.encode("utf-8")) > 32:
        raise ValueError("Invalid render color")
    if value == "reset":
        return value
    try:
        return normalized_hex(value)
    except ValueError:
        pass
    if re.fullmatch(r"rgb:[0-9a-fA-F]{1,4}/[0-9a-fA-F]{1,4}/[0-9a-fA-F]{1,4}", value) is None:
        raise ValueError("Invalid render color")
    result = "#"
    for part in value[4:].split("/"):
        maximum = 16 ** len(part) - 1
        result += "%02X" % ((int(part, 16) * 255 + maximum // 2) // maximum)
    return result


def _safe_text(value, limit):
    if len(value.encode("utf-8")) > limit or any(ord(c) < 32 or 127 <= ord(c) <= 159 for c in value):
        raise ValueError("Invalid render text")
    return value


class Render:
    def __init__(self, data):
        if len(data) > 16_384 or not data.endswith(b"\0"):
            raise ValueError("Invalid render payload")
        fields = data[:-1].decode("utf-8").split("\0")
        if len(fields) != 23:
            raise ValueError("Invalid render payload")
        self.background = normalized_background(fields[0]) if fields[0] else None
        if (fields[1] not in {"", "set", "reset"} or fields[18] not in {"0", "1"}
                or fields[20] not in {"", "iterm2-set", "iterm2-clear"}
                or fields[22] not in {"0", "1"}):
            raise ValueError("Invalid render action")
        self.palette_action = fields[1]
        self.palette = []
        for value in fields[2:18]:
            if value and self.palette_action != "set":
                raise ValueError("Invalid render palette")
            self.palette.append(normalized_hex(value) if value else None)
        _safe_text(fields[19], 8192)
        if fields[18] == "0" and fields[19]:
            raise ValueError("Invalid render title")
        self.title = fields[19] if fields[18] == "1" else None
        self.image_action = fields[20]
        self.image_path = _safe_text(fields[21], 4096)
        if (self.image_action == "iterm2-set" and not self.image_path.startswith("/")) \
                or (self.image_action != "iterm2-set" and self.image_path):
            raise ValueError("Invalid render image")
        self.bell = fields[22] == "1"

    def encode(self, synthetic=False):
        result = ""
        if self.palette_action == "reset":
            result += "\x1b]104\x1b\\"
        elif self.palette_action == "set":
            values = "".join(";%d;rgb:%s/%s/%s" % (i, color[1:3], color[3:5], color[5:7])
                             for i, color in enumerate(self.palette) if color is not None)
            if values:
                result += "\x1b]4" + values + "\x1b\\"
        if self.background == "reset":
            result += "\x1b]111\x1b\\"
        elif self.background is not None:
            result += "\x1b]11;" + self.background + "\x1b\\"
        if self.title is not None:
            result += "\x1b]0;" + self.title + "\x1b\\"
        if self.image_action == "iterm2-set":
            result += "\x1b]1337;SetBackgroundImageFile=" + base64.b64encode(self.image_path.encode()).decode() + "\a"
        elif self.image_action == "iterm2-clear":
            result += "\x1b]1337;SetBackgroundImageFile=\a"
        if self.bell and not synthetic:
            result += "\a"
        return result.encode("utf-8")
