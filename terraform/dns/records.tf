locals {
  alb_ready = var.alb_dns_name != "" && var.alb_zone_id != ""

  subdomain_suffix = "${var.region_prefix}.${var.domain_name}"

  subdomains = local.alb_ready ? {
    app     = "circle-banking-app.${local.subdomain_suffix}"
    grafana = "grafana.${local.subdomain_suffix}"
  } : {}
}

resource "aws_route53_record" "alias" {
  for_each = local.subdomains

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

output "records_created" {
  value = [for r in aws_route53_record.alias : r.name]
}

output "hosted_zone_name" {
  value = data.aws_route53_zone.main.name
}

