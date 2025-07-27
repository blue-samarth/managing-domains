resource "cloudflare_dns_record" "caa_acm_amazon_issuer" {
  zone_id = local.cloudflare_zone_id

  name = local.domain
  type = "CAA"
  ttl  = 300

  data = {
    tag   = "issue"
    value = "amazon.com"
  }

  comment = "CAA record for ACM to issue certificates from Amazon"
}

resource "cloudflare_dns_record" "caa_acm_amazon_trust_issuer" {
  zone_id = local.cloudflare_zone_id

  name = local.domain
  type = "CAA"
  ttl  = 300

  data = {
    tag   = "issuewild"
    value = "amazontrust.com"
  }

  comment = "CAA record for ACM to issue wildcard certificates from Amazon Trust Services"
}