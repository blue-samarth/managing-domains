locals {
  domain_list = [
    "www",
    "api",
    "app"
  ]
}

resource "cloudflare_dns_record" "dns_record_base_domain" {
  zone_id = local.cloudflare_zone_id
  name    = local.domain
  type    = "CNAME"
  ttl     = 300

  content = kubernetes_ingress_v1.ingress_service.status.0.load_balancer.0.ingress.0.hostname
  tags    = ["environment:${local.environment}", "type:frontend"]

  depends_on = [kubernetes_ingress_v1.ingress_service]
}

resource "cloudflare_dns_record" "subdomain_records" {
  for_each = toset(local.domain_list)

  zone_id = local.cloudflare_zone_id
  name    = "${each.key}.${local.domain}"
  type    = "CNAME"
  ttl     = 300

  content = kubernetes_ingress_v1.ingress_service.status.0.load_balancer.0.ingress.0.hostname
  tags    = ["environment:${local.environment}", contains(each.key, "api") ? "type:backend" : "type:frontend"]

  depends_on = [kubernetes_ingress_v1.ingress_service]
}