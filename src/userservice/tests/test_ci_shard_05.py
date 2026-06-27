"""CI parallelism shard: username spaces."""
import re
import unittest

USERNAME = re.compile(r"\A[a-zA-Z0-9_]{2,15}\Z")


class TestUserserviceShard05(unittest.TestCase):
    def test_spaces_rejected(self):
        self.assertFalse(USERNAME.match("user name"))
