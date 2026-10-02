"""CI parallelism shard: invalid label prefixes."""
import re
import unittest

LABEL = re.compile(r"^[0-9a-zA-Z][0-9a-zA-Z ]{0,29}$")


class TestContactsShard07(unittest.TestCase):
    def test_invalid_label_prefixes(self):
        for label in (" leading", "-bad", "_bad"):
            self.assertFalse(LABEL.match(label))
