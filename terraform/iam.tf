# IRSA role for the app pods (ServiceAccount circle-banking-app-sa) on the
# EKS cluster in var.existing_cluster_name, plus any clusters in
# var.irsa_extra_cluster_names (kept during a cluster move so the old
# cluster's pods keep working until DNS switches). Least privilege: the services
# only talk to their DynamoDB tables; secrets are injected by CI as
# Kubernetes Secrets, so no Secrets Manager access is needed here.

data "aws_eks_cluster" "irsa" {
  for_each = toset(concat([local.cluster_name], var.irsa_extra_cluster_names))
  name     = each.key
}

data "aws_iam_openid_connect_provider" "irsa" {
  for_each = data.aws_eks_cluster.irsa
  url      = each.value.identity[0].oidc[0].issuer
}

locals {
  dynamodb_table_arns = [
    aws_dynamodb_table.users.arn,
    aws_dynamodb_table.contacts.arn,
    aws_dynamodb_table.transactions.arn,
    aws_dynamodb_table.balances.arn,
  ]
}

# One trust statement per cluster OIDC provider.
data "aws_iam_policy_document" "app_assume" {
  dynamic "statement" {
    for_each = data.aws_iam_openid_connect_provider.irsa
    content {
      actions = ["sts:AssumeRoleWithWebIdentity"]
      principals {
        type        = "Federated"
        identifiers = [statement.value.arn]
      }
      condition {
        test     = "StringEquals"
        variable = "${replace(statement.value.url, "https://", "")}:sub"
        values   = ["system:serviceaccount:${var.k8s_namespace}:circle-banking-app-sa"]
      }
      condition {
        test     = "StringEquals"
        variable = "${replace(statement.value.url, "https://", "")}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
  }
}

data "aws_iam_policy_document" "app_dynamodb" {
  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:TransactWriteItems",
      "dynamodb:TransactGetItems",
      "dynamodb:ConditionCheckItem",
      "dynamodb:DescribeTable",
    ]
    resources = concat(local.dynamodb_table_arns, [for arn in local.dynamodb_table_arns : "${arn}/index/*"])
  }
}

resource "aws_iam_role" "app" {
  name               = "circle-banking-app-${var.environment}-pods"
  assume_role_policy = data.aws_iam_policy_document.app_assume.json
}

resource "aws_iam_role_policy" "app_dynamodb" {
  name   = "dynamodb"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app_dynamodb.json
}
