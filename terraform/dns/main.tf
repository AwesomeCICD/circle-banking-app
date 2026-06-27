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
}

# Existing hosted zone managed outside this module.
data "aws_route53_zone" "main" {
  zone_id = var.hosted_zone_id
}
