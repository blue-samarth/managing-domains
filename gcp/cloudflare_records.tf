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
  type    = "A"
  ttl     = 300

  content = google_compute_global_address.compute_global_address_for_gce_endpoints.address
  tags    = ["environment:${local.environment}", "type:frontend"]
}