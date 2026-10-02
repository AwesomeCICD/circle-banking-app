"""CI parallelism shard: username special characters."""
import re
import unittest

USERNAME = re.compile(r"\A[a-zA-Z0-9_]{2,15}\Z")


class TestUserserviceShard04(unittest.TestCase):
    def test_special_chars_rejected(self):
        for name in ("user-name", "user.name", "user@name"):
            self.assertFalse(USERNAME.match(name))
