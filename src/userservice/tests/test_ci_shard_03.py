"""CI parallelism shard: too-long usernames."""
import re
import unittest

USERNAME = re.compile(r"\A[a-zA-Z0-9_]{2,15}\Z")


class TestUserserviceShard03(unittest.TestCase):
    def test_long_usernames_rejected(self):
        self.assertFalse(USERNAME.match("a" * 16))
