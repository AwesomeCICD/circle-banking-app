resource "aws_route53_zone" "main" {
  name = var.domain_name
}

# ---------------------------------------------------------------------------
# ALB alias records — three host-based routes into the single ALB.
#
# The ALB DNS name and zone ID are not known until after the first apply
# deploys the Ingress and the AWS LB Controller provisions the ALB.
# Set var.alb_dns_name and var.alb_zone_id, then re-run terraform apply.
# ---------------------------------------------------------------------------
locals {
  alb_records_ready = var.alb_dns_name != "" && var.alb_zone_id != ""

  alb_subdomains = {
    app     = "app.${var.domain_name}"
    grafana = "grafana.${var.domain_name}"
    hubble  = "hubble.${var.domain_name}"
  }
}

resource "aws_route53_record" "alb" {
  for_each = local.alb_records_ready ? local.alb_subdomains : {}

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
