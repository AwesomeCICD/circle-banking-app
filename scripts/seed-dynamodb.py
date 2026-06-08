#!/usr/bin/env python3
"""Seed DynamoDB with demo users, contacts, and starting balances."""

import os
import sys

import bcrypt
import boto3

ENV = os.environ.get("ENVIRONMENT", "dev")
REGION = os.environ.get("AWS_REGION", "us-east-1")

USERS = [
    ("1011226111", "testuser", "Test", "User"),
    ("1033623433", "alice", "Alice", "User"),
    ("1055757655", "bob", "Bob", "User"),
    ("1077441377", "eve", "Eve", "User"),
]
LOCAL_ROUTE = "883745000"
STARTING_BALANCE = 1_000_000  # $10,000.00 in cents
PASSWORD = b"circleci"


def main():
    ddb = boto3.resource("dynamodb", region_name=REGION)
    users = ddb.Table(f"bankcorp-users-{ENV}")
    contacts = ddb.Table(f"bankcorp-contacts-{ENV}")
    balances = ddb.Table(f"bankcorp-balances-{ENV}")

    pw_hash = bcrypt.hashpw(PASSWORD, bcrypt.gensalt()).decode()

    for account_id, username, first, last in USERS:
        users.put_item(Item={
            "userId": account_id,
            "username": username,
            "passhash": pw_hash,
            "firstname": first,
            "lastname": last,
            "birthday": "2000-01-01",
            "timezone": "-5",
            "address": "Bowling Green, New York City",
            "state": "NY",
            "zip": "10004",
            "ssn": "111-22-3333",
        })
        balances.put_item(Item={"accountId": account_id, "balance": STARTING_BALANCE})
        print(f"seeded user {username} ({account_id})")

    # contacts among demo users
    for owner, label, acct in [
        ("testuser", "Alice", "1033623433"),
        ("testuser", "Bob", "1055757655"),
        ("testuser", "Eve", "1077441377"),
        ("alice", "Testuser", "1011226111"),
        ("bob", "Testuser", "1011226111"),
        ("eve", "Testuser", "1011226111"),
    ]:
        contacts.put_item(Item={
            "userId": owner,
            "contactId": f"{acct}#{LOCAL_ROUTE}",
            "label": label,
            "account_num": acct,
            "routing_num": LOCAL_ROUTE,
            "is_external": False,
        })

    # external bank contact for each user
    for owner in ["testuser", "alice", "bob", "eve"]:
        contacts.put_item(Item={
            "userId": owner,
            "contactId": "9099791699#808889588",
            "label": "External Bank",
            "account_num": "9099791699",
            "routing_num": "808889588",
            "is_external": True,
        })

    print("seed complete")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"seed failed: {exc}", file=sys.stderr)
        sys.exit(1)
