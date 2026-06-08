# Cilium is deployed in chaining mode alongside the AWS VPC CNI.
# This gives eBPF-based network policy and Hubble observability without
# replacing the ENI-based networking that EKS managed nodes depend on.
resource "helm_release" "cilium" {
  count = var.install_cilium ? 1 : 0

  name       = "cilium"
  repository       = "https://helm.cilium.io"
  chart            = "cilium"
  namespace        = "kube-system"
  version          = "1.15.3"

  set {
    name  = "cni.chainingMode"
    value = "aws-cni"
  }

  set {
    name  = "cni.exclusive"
    value = "false"
  }

  set {
    name  = "enableIPv4Masquerade"
    value = "false"
  }

  set {
    name  = "tunnel"
    value = "disabled"
  }

  # Hubble — network observability UI and relay
  set {
    name  = "hubble.relay.enabled"
    value = "true"
  }

  set {
    name  = "hubble.ui.enabled"
    value = "true"
  }

  set {
    name  = "hubble.metrics.enabled"
    value = "{dns,drop,tcp,flow,icmp,http}"
  }
}
