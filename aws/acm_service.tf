module "acm_service" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 5.1.0"

  domain_name = local.domain
  zone_id     = local.zone_id

  subject_alternative_names = [
    "www.${local.domain}",
    "api.${local.domain}",
    "app.${local.domain}"
  ]

  create_route53_records  = false
  validation_method       = "DNS"
  validation_record_fqdns = cloudflare_dns_record.dns_record_validation[*].name

  tags = merge(module.tags.tags, {
    Name = local.domain
  })
}

resource "cloudflare_dns_record" "dns_record_validation" {
  count = length(module.acm_service.distinct_domain_names)

  zone_id = local.cloudflare_zone_id
  name    = trimsuffix(element(module.acm_service.validation_domains, count.index)["resource_record_name"], ".")
  type    = element(module.acm_service.validation_domains, count.index)["resource_record_type"]
  ttl     = 300

  content = trimsuffix(element(module.acm_service.validation_domains, count.index)["resource_record_values"], ".")
  comment = "ACM DNS validation for ${local.domain} - ${element(module.acm_service.validation_domains, count.index)["resource_record_type"]}"

  proxied = false
}