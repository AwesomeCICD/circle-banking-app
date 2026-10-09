"""CI parallelism shard: non-digit account numbers."""
import re
import unittest

ACCOUNT = re.compile(r"\A[0-9]{10}\Z")


class TestContactsShard03(unittest.TestCase):
    def test_non_digit_accounts_rejected(self):
        for acct in ("abcdefghij", "123456789a", "12-3456789"):
            self.assertFalse(ACCOUNT.match(acct))
