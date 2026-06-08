output "eks_cluster_name" {
  description = "EKS cluster name — pass to aws eks update-kubeconfig --name"
  value       = data.aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = data.aws_eks_cluster.main.endpoint
}

output "eks_oidc_issuer" {
  description = "EKS OIDC issuer URL — used to construct IRSA trust policies"
  value       = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "ecr_registry" {
  description = "ECR registry base URI — prefix for all image references"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "ecr_repo_uris" {
  description = "Map of service name to ECR repository URI"
  value       = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}

output "dynamodb_table_names" {
  description = "Map of logical table name to DynamoDB table name"
  value = {
    users        = aws_dynamodb_table.users.name
    contacts     = aws_dynamodb_table.contacts.name
    transactions = aws_dynamodb_table.transactions.name
    balances     = aws_dynamodb_table.balances.name
  }
}

output "iam_role_app_dynamodb" {
  description = "IRSA role ARN for app services (DynamoDB access)"
  value       = aws_iam_role.app_dynamodb.arn
}

output "iam_role_tempo_s3" {
  description = "IRSA role ARN for Tempo (S3 trace storage)"
  value       = aws_iam_role.tempo_s3.arn
}


output "acm_certificate_arn" {
  description = "ACM wildcard certificate ARN"
  value       = aws_acm_certificate.wildcard.arn
}

output "route53_zone_id" {
  description = "Route 53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "route53_nameservers" {
  description = "Nameservers to set at your domain registrar"
  value       = aws_route53_zone.main.name_servers
}

output "tempo_traces_bucket" {
  description = "S3 bucket name for Tempo trace storage"
  value       = aws_s3_bucket.tempo_traces.bucket
}
