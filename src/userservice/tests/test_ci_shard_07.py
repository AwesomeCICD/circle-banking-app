"""CI parallelism shard: numeric usernames."""
import re
import unittest

USERNAME = re.compile(r"\A[a-zA-Z0-9_]{2,15}\Z")


class TestUserserviceShard07(unittest.TestCase):
    def test_numeric_usernames_allowed(self):
        self.assertTrue(USERNAME.match("12345"))
