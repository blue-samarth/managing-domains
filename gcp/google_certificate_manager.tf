resource "google_certificate_manager_dns_authorization" "cert_manager_dns_authorization" {
    project = module.project.project_id
    name = lower(join("-", [local.domain, "cert", "manager", "dns", "auth"]))

    location = "global"
    description = "DNS Authorization for Certificate Manager for ${local.domain}"
    domain = local.domain
  
}

resource "google_certificate_manager_certificate" "cert_manager_root" {
    project = module.project.project_id
    name = lower(join("-", [local.domain, "cert", "manager", "root"]))
    description = "Wildcard Certificate for ${local.domain} using Certificate Manager"
    
    managed {
        domains = [local.domain,
        "*.${local.domain}"
        ]
        dns_authorizations = [ google_certificate_manager_dns_authorization.cert_manager_dns_authorization.id ]
    }
}

resource "google_certificate_manager_certificate_map" "cert_manager_map" {
    project = module.project.project_id
    name = lower(join("-", [local.domain, "cert", "manager", "map"]))
    description = "Certificate Map for ${local.domain} using Certificate Manager"
}

resource "google_certificate_manager_certificate_map_entry" "cert_manager_map_entry" {
    project = module.project.project_id
    name = lower(join("-", [local.domain, "cert", "manager", "map", "entry"]))
    description = "Certificate Map Entry for ${local.domain} using Certificate Manager"
    
    map = google_certificate_manager_certificate_map.cert_manager_map.id
    certificates = [google_certificate_manager_certificate.cert_manager_root.id]
    hostname = "*.${local.domain}"
}