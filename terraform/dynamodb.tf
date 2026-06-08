resource "aws_dynamodb_table" "users" {
  name         = "bankcorp-users-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "username"
    type = "S"
  }

  global_secondary_index {
    name            = "username-index"
    hash_key        = "username"
    projection_type = "ALL"
  }
}

resource "aws_dynamodb_table" "contacts" {
  name         = "bankcorp-contacts-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"
  range_key    = "contactId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "contactId"
    type = "S"
  }
}

resource "aws_dynamodb_table" "transactions" {
  name         = "bankcorp-transactions-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "accountId"
  range_key    = "timestampTxnId"

  attribute {
    name = "accountId"
    type = "S"
  }

  attribute {
    name = "timestampTxnId"
    type = "S"
  }
}

resource "aws_dynamodb_table" "balances" {
  name         = "bankcorp-balances-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "accountId"

  attribute {
    name = "accountId"
    type = "S"
  }
}
