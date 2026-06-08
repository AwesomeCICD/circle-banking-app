# Use a pre-provisioned EKS cluster (fe-runner-cluster) instead of creating one.
data "aws_eks_cluster" "main" {
  name = var.existing_cluster_name
}

data "aws_eks_cluster_auth" "main" {
  name = var.existing_cluster_name
}

data "tls_certificate" "eks_oidc" {
  url = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# OIDC provider is required for IRSA. Create if not already present on the account.
resource "aws_iam_openid_connect_provider" "eks" {
  url             = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]

  lifecycle {
    ignore_changes = [thumbprint_list]
  }
}
