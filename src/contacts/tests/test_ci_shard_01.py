"""CI parallelism shard: valid account numbers."""
import re
import unittest

ACCOUNT = re.compile(r"\A[0-9]{10}\Z")


class TestContactsShard01(unittest.TestCase):
    def test_valid_account_numbers(self):
        for acct in ("1234567890", "1011226111", "0000000000"):
            self.assertTrue(ACCOUNT.match(acct))
