terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

data "aws_caller_identity" "current" {}

locals {
  cluster_name = var.existing_cluster_name

  common_tags = {
    Project     = "circle-banking-app"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
