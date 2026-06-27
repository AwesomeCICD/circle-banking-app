"""CI parallelism shard: valid contact labels."""
import re
import unittest

LABEL = re.compile(r"^[0-9a-zA-Z][0-9a-zA-Z ]{0,29}$")


class TestContactsShard06(unittest.TestCase):
    def test_valid_labels(self):
        for label in ("A", "Checking", "Savings 1", "ContactLabel30charslong123456"):
            self.assertTrue(LABEL.match(label))
