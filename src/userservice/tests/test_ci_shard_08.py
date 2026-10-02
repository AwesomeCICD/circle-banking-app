"""CI parallelism shard: mixed-case usernames."""
import re
import unittest

USERNAME = re.compile(r"\A[a-zA-Z0-9_]{2,15}\Z")


class TestUserserviceShard08(unittest.TestCase):
    def test_mixed_case_allowed(self):
        self.assertTrue(USERNAME.match("UserName"))
