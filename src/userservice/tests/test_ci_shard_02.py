"""CI parallelism shard: too-short usernames."""
import re
import unittest

USERNAME = re.compile(r"\A[a-zA-Z0-9_]{2,15}\Z")


class TestUserserviceShard02(unittest.TestCase):
    def test_short_usernames_rejected(self):
        for name in ("", "a"):
            self.assertFalse(USERNAME.match(name))
