"""
db manages interactions with DynamoDB
"""

import logging
import random
import os

import boto3
from boto3.dynamodb.conditions import Key


class UserDb:
    """DynamoDB-backed user store."""

    def __init__(self, table_name=None, logger=logging):
        self.table_name = table_name or os.environ["DYNAMODB_USERS_TABLE"]
        self.logger = logger
        self.table = boto3.resource("dynamodb").Table(self.table_name)

    def add_user(self, user):
        """Create a new user; fails if userId already exists."""
        passhash = user["passhash"]
        if isinstance(passhash, bytes):
            passhash = passhash.decode("utf-8")
        item = {
            "userId": user["accountid"],
            "username": user["username"],
            "passhash": passhash,
            "firstname": user["firstname"],
            "lastname": user["lastname"],
            "birthday": (user["birthday"].isoformat()
                         if hasattr(user["birthday"], "isoformat")
                         else str(user["birthday"])),
            "timezone": user["timezone"],
            "address": user["address"],
            "state": user["state"],
            "zip": user["zip"],
            "ssn": user["ssn"],
        }
        self.logger.debug("PUT user %s", item["username"])
        self.table.put_item(Item=item, ConditionExpression="attribute_not_exists(userId)")

    def generate_accountid(self):
        """Generate a unique 10-digit account ID."""
        self.logger.debug("Generating an account ID")
        while True:
            accountid = str(random.randint(10**9, 10**10 - 1))
            resp = self.table.get_item(Key={"userId": accountid})
            if "Item" not in resp:
                return accountid

    def get_user(self, username):
        """Look up a user by username via the GSI."""
        self.logger.debug("Query user %s", username)
        resp = self.table.query(
            IndexName="username-index",
            KeyConditionExpression=Key("username").eq(username),
            Limit=1,
        )
        items = resp.get("Items", [])
        if not items:
            return None
        item = items[0]
        return {
            "accountid": item["userId"],
            "username": item["username"],
            "passhash": (item["passhash"].encode()
                         if isinstance(item["passhash"], str)
                         else item["passhash"]),
            "firstname": item["firstname"],
            "lastname": item["lastname"],
            "birthday": item["birthday"],
            "timezone": item["timezone"],
            "address": item["address"],
            "state": item["state"],
            "zip": item["zip"],
            "ssn": item["ssn"],
        }
