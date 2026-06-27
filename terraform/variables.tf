variable "existing_cluster_name" {
  description = "Name of the pre-provisioned EKS cluster. Used for resource naming only — TF does not interact with the cluster directly."
  type        = string
  default     = "fe-runner-cluster"
}

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
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

variable "k8s_namespace" {
  description = "Kubernetes namespace where circle-banking-app application services are deployed."
  type        = string
  default     = "circle-banking-app"
}

variable "domain_name" {
  description = "Apex domain name."
  type        = string
  default     = "fieldeng-sphereci.com"
}

variable "region_prefix" {
  description = "Regional subdomain prefix (e.g. namer, emea)."
  type        = string
  default     = "namer"
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID for domain_name."
  type        = string
  default     = "Z09847963AEXN7Z99V23M"
}
