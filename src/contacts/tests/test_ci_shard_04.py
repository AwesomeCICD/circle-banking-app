"""CI parallelism shard: valid routing numbers."""
import re
import unittest

ROUTING = re.compile(r"\A[0-9]{9}\Z")


class TestContactsShard04(unittest.TestCase):
    def test_valid_routing_numbers(self):
        for routing in ("123456789", "987654321", "000000000"):
            self.assertTrue(ROUTING.match(routing))
