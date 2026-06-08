locals {
  # Strip the https:// prefix — IAM condition keys use the bare issuer URL.
  oidc_issuer = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

# ---------------------------------------------------------------------------
# App services — DynamoDB access (IRSA)
# Covers: frontend, userservice, contacts, balancereader, ledgerwriter,
#         transactionhistory. Each service gets its own Kubernetes service
#         account annotated with this role ARN.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "app_dynamodb_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringLike"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.k8s_namespace}:*"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "app_dynamodb_policy" {
  statement {
    sid    = "DynamoDBAccess"
    effect = "Allow"
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
      "dynamodb:DescribeTable",
    ]
    resources = [
      aws_dynamodb_table.users.arn,
      aws_dynamodb_table.contacts.arn,
      aws_dynamodb_table.transactions.arn,
      aws_dynamodb_table.balances.arn,
    ]
  }
}

resource "aws_iam_role" "app_dynamodb" {
  name               = "${local.cluster_name}-app-dynamodb"
  assume_role_policy = data.aws_iam_policy_document.app_dynamodb_trust.json
}

resource "aws_iam_role_policy" "app_dynamodb" {
  name   = "dynamodb-access"
  role   = aws_iam_role.app_dynamodb.id
  policy = data.aws_iam_policy_document.app_dynamodb_policy.json
}

# ---------------------------------------------------------------------------
# Tempo — S3 access for trace storage (IRSA)
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "tempo_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:observability:tempo"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "tempo_s3_policy" {
  statement {
    sid    = "TempoS3Access"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.tempo_traces.arn,
      "${aws_s3_bucket.tempo_traces.arn}/*",
    ]
  }
}

resource "aws_iam_role" "tempo_s3" {
  name               = "${local.cluster_name}-tempo-s3"
  assume_role_policy = data.aws_iam_policy_document.tempo_trust.json
}

resource "aws_iam_role_policy" "tempo_s3" {
  name   = "s3-trace-access"
  role   = aws_iam_role.tempo_s3.id
  policy = data.aws_iam_policy_document.tempo_s3_policy.json
}

# ---------------------------------------------------------------------------
# CircleCI OIDC — NOT managed here.
# The OIDC provider and CI role (fieldeng_aws_ci_oidc_oauth_role) are
# pre-provisioned by fe-eks-cluster. This repo's pipeline references
# that role directly via the aws_ci_role_arn pipeline parameter.
# ---------------------------------------------------------------------------
