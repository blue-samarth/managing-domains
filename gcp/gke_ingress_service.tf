resource "kubernetes_ingress_v1" "ingress_service" {
    metadata {
      name = lower(join("-", [local.org_shorthand, local.environment, "ingress"]))
      namespace = local.namespace[0]
      annotations = {
        "kubernetes.io/ingress.class" = "gce"
        "networking.gke.io/managed-certificates" = lower(join("-", [local.org_shorthand, local.environment, "managed-cert"]))
        "networking.gke.io/ingress.global-static-ip-name" = lower(join("-", [local.org_shorthand, local.environment, "gke","ip"]))
        "networking.gke.io/v1beta1.FrontendConfig" = lower(join("-", [local.org_shorthand, local.environment, "frontend", "config"]))
        "netwroking.gke.io/v1beta1.BackendConfig" = lower(join("-", [local.org_shorthand, local.environment, "backend", "config"]))
        "sessionAffinity" = "ClientIP"
      }
    }
    spec {
      default_backend {
        service {
          name = "<KUBERNETES__FRONTEND_SERVICE_NAME>"
          port {
            number = "<KUBERNETES__FRONTEND_SERVICE_PORT>"
          }
        }
      }

      rule {
        host = local.domain

        http {
          path {
            path = "/"
            path_type = "ImplementationSpecific"

            backend {
              service {
                name = "<KUBERNETES__FRONTEND_SERVICE_NAME>"
                port {
                  number = "<KUBERNETES__FRONTEND_SERVICE_PORT>"
                }
              }
            }
          }
        }
      }
    }
}

resource "kubernetes_manifest" "manifest_ingress_frontend_config" {
    manifest = {
        apiVersion = "networking.gke.io/v1beta1"
        kind = "FrontendConfig"
        metadata = {
            name = lower(join("-", [local.org_shorthand, local.environment, "frontend", "config"]))
            namespace = local.namespace[0]
        }
        spec = {
            sslPolicy = lower(join("-", [local.org_shorthand, local.environment, "ssl", "policy", "gke", "ingress"]))

            redirectToHttps = {
                enabled = true
            }
        }
    }
}

resource "kubernetes_manifest" "manifest_ingress_backend_config" {
    manifest = {
        apiVersion = "cloud.google.com/v1beta1"
        kind = "BackendConfig"
        metadata = {
            name = lower(join("-", [local.org_shorthand, local.environment, "backend", "config"]))
            namespace = local.namespace[0]
        }
        spec = {
            timeoutSec = 3000
            connectionDraining = {
                drainingTimeoutSec = 300
            }
            sessionAffinity = "CLIENT_IP"
        }
    }
}

resource "kubernetes_manifest" "manifest_managed_certificate" {
    manifest = {
        apiVersion = "networking.gke.io/v1beta1"
        kind = "ManagedCertificate"
        metadata = {
            name = lower(join("-", [local.org_shorthand, local.environment, "managed", "cert"]))
            namespace = local.namespace[0]
        }
        spec = {
            domains = [
                local.domain,
                "www.${local.domain}",
                "api.${local.domain}",
                "app.${local.domain}"
            ]
        }
    }
  
}