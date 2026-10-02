"""CI parallelism shard: invalid label lengths."""
import re
import unittest

LABEL = re.compile(r"^[0-9a-zA-Z][0-9a-zA-Z ]{0,29}$")


class TestContactsShard08(unittest.TestCase):
    def test_too_long_labels_rejected(self):
        self.assertFalse(LABEL.match("A" + "b" * 30))
