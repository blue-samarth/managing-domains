resource "google_compute_ssl_policy" "ssl_policy" {
  name            = lower(join("-", [local.org_shorthand, local.environment, "ssl", "policy", "gke", "ingress"]))
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}