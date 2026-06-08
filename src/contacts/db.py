"""
db manages interactions with DynamoDB
"""

import logging
import os

import boto3
from boto3.dynamodb.conditions import Key


class ContactsDb:
    """DynamoDB-backed contacts store."""

    def __init__(self, table_name=None, logger=logging):
        self.table_name = table_name or os.environ["DYNAMODB_CONTACTS_TABLE"]
        self.logger = logger
        self.table = boto3.resource("dynamodb").Table(self.table_name)

    def add_contact(self, contact):
        item = {
            "userId": contact["username"],
            "contactId": f"{contact['account_num']}#{contact['routing_num']}",
            "label": contact["label"],
            "account_num": contact["account_num"],
            "routing_num": contact["routing_num"],
            "is_external": contact["is_external"],
        }
        self.logger.debug("PUT contact %s", item["contactId"])
        self.table.put_item(Item=item)

    def get_contacts(self, username):
        self.logger.debug("Query contacts for %s", username)
        resp = self.table.query(
            KeyConditionExpression=Key("userId").eq(username),
        )
        contacts = []
        for row in resp.get("Items", []):
            contacts.append({
                "label": row["label"],
                "account_num": row["account_num"],
                "routing_num": row["routing_num"],
                "is_external": row["is_external"],
            })
        self.logger.debug("Fetched %d contacts", len(contacts))
        return contacts
