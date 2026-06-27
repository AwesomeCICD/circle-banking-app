"""CI parallelism shard: short account numbers."""
import re
import unittest

ACCOUNT = re.compile(r"\A[0-9]{10}\Z")


class TestContactsShard02(unittest.TestCase):
    def test_short_accounts_rejected(self):
        for acct in ("1", "12345", "123456789"):
            self.assertFalse(ACCOUNT.match(acct))
