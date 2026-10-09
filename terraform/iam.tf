# IRSA role for the app pods (ServiceAccount circle-banking-app-sa) on the
# EKS cluster in var.existing_cluster_name. Least privilege: the services
# only talk to their DynamoDB tables; secrets are injected by CI as
# Kubernetes Secrets, so no Secrets Manager access is needed here.

data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

data "aws_iam_openid_connect_provider" "cluster" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

locals {
  oidc_issuer_host = replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
  dynamodb_table_arns = [
    aws_dynamodb_table.users.arn,
    aws_dynamodb_table.contacts.arn,
    aws_dynamodb_table.transactions.arn,
    aws_dynamodb_table.balances.arn,
  ]
}

data "aws_iam_policy_document" "app_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.cluster.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:${var.k8s_namespace}:circle-banking-app-sa"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
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
