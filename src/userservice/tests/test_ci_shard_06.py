"""CI parallelism shard: underscore usernames."""
import re
import unittest

USERNAME = re.compile(r"\A[a-zA-Z0-9_]{2,15}\Z")


class TestUserserviceShard06(unittest.TestCase):
    def test_underscore_allowed(self):
        self.assertTrue(USERNAME.match("_user_name_"))
