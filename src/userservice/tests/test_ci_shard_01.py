"""CI parallelism shard: valid usernames."""
import re
import unittest

USERNAME = re.compile(r"\A[a-zA-Z0-9_]{2,15}\Z")


class TestUserserviceShard01(unittest.TestCase):
    def test_valid_usernames(self):
        for name in ("ab", "user_1", "ValidUser123"):
            self.assertTrue(USERNAME.match(name))
