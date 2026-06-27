"""CI parallelism shard: invalid routing numbers."""
import re
import unittest

ROUTING = re.compile(r"\A[0-9]{9}\Z")


class TestContactsShard05(unittest.TestCase):
    def test_invalid_routing_numbers(self):
        for routing in ("12345", "1234567890", "abcdefghi"):
            self.assertFalse(ROUTING.match(routing))
