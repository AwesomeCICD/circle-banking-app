locals {
  alb_ready = var.alb_dns_name != "" && var.alb_zone_id != ""

  prefix = var.env_prefix == "" ? "" : "${var.env_prefix}."

  subdomains = local.alb_ready ? {
    app     = "app.${local.prefix}${var.domain_name}"
    grafana = "grafana.${local.prefix}${var.domain_name}"
    hubble  = "hubble.${local.prefix}${var.domain_name}"
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
