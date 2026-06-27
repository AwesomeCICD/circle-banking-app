variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID for fieldeng-sphereci.com."
  type        = string
  default     = "Z09847963AEXN7Z99V23M"
}

variable "domain_name" {
  description = "Apex domain for all subdomain records."
  type        = string
  default     = "fieldeng-sphereci.com"
}

variable "region_prefix" {
  description = "Region prefix inserted between host and apex (e.g. namer → app.namer.fieldeng-sphereci.com)."
  type        = string
  default     = "namer"
}

variable "alb_dns_name" {
  description = "DNS name of the ALB (kubectl get ingress -o jsonpath=...). Empty means no records will be created."
  type        = string
  default     = ""
}

variable "alb_zone_id" {
  description = "Hosted zone ID of the ALB (AWS-managed, not your Route 53 zone)."
  type        = string
  default     = ""
}
