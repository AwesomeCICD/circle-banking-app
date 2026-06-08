variable "existing_cluster_name" {
  description = "Name of the pre-provisioned EKS cluster to deploy into."
  type        = string
  default     = "fe-runner-cluster"
}

variable "install_alb_controller" {
  description = "Install AWS Load Balancer Controller via Helm. Set false if already on the cluster."
  type        = bool
  default     = true
}

variable "install_cilium" {
  description = "Install Cilium CNI + Hubble via Helm. Set false if the cluster already has a CNI."
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Base domain name for the application (e.g. bankapp.example.com). A wildcard ACM cert is issued for *.{domain_name}."
  type        = string
}

variable "environment" {
  description = "Deployment environment. Controls resource naming and tagging."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "circleci_org_id" {
  description = "CircleCI organization ID (UUID). Used to scope the OIDC trust relationship for CI/CD."
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace where bankcorp application services are deployed."
  type        = string
  default     = "bankcorp"
}

variable "terraform_state_bucket" {
  description = "S3 bucket name that holds Terraform remote state. Created outside of this module (bootstrap)."
  type        = string
}

variable "terraform_state_lock_table" {
  description = "DynamoDB table name used for Terraform state locking. Created outside of this module (bootstrap)."
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the ALB created by the AWS Load Balancer Controller. Set after first apply once the Ingress is deployed."
  type        = string
  default     = ""
}

variable "alb_zone_id" {
  description = "Hosted zone ID of the ALB (AWS-managed, not your Route 53 zone). Required for alias records."
  type        = string
  default     = ""
}
