output "ecr_registry" {
  description = "ECR registry base URI."
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "ecr_repo_uris" {
  description = "Map of service name to ECR repository URI."
  value       = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}

output "dynamodb_table_names" {
  description = "Map of logical table name to DynamoDB table name."
  value = {
    users        = aws_dynamodb_table.users.name
    contacts     = aws_dynamodb_table.contacts.name
    transactions = aws_dynamodb_table.transactions.name
    balances     = aws_dynamodb_table.balances.name
  }
}
