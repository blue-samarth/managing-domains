resource "cloudflare_dns_record" "dns_record_domain_verification"{
    zone_id = local.cloudflare_zone_id
    name    = local.domain
    type    = "TXT"
    ttl     = 300
    proxied = false
    
    content = "\"google-site-verification=${local.google_site_verification_token}\""
    tags    = ["environment:${local.environment}", "type:verification"]
    
    comment = "DNS verification record for ${local.domain} for Google services"
}

resource "cloudflare_dns_record" "dns_record_google_cert_manager_dns_authorization" {
    zone_id = local.cloudflare_zone_id
    name    = trim(google_certificate_manager_dns_authorization.cert_manager_dns_authorization.dns_resource_record[0].name, ".")
    type    = google_certificate_manager_dns_authorization.cert_manager_dns_authorization.dns_resource_record[0].type
    content = trim(google_certificate_manager_dns_authorization.cert_manager_dns_authorization.dns_resource_record[0].data, ".")
    ttl     = 300
    proxied = false

    tags    = ["environment:${local.environment}", "type:verification"]

    comment = "DNS verification record for ${local.domain} for Google services"
}