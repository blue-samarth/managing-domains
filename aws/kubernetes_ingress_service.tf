resource "kubernetes_ingress_v1" "ingress_service" {
  metadata {
    name      = lower(join("-", local.domain, "ingress", "service"))
    namespace = local.namespace[1]

    annotations = {
      "kubernetes.io/ingress.class"          = "alb"
      "alb.ingress.kubernetes.io/scheme"     = "internet-facing"
      "alb.ingress.kubernetes.io/group.name" = lower(join("-", local.domain, "ingress", "service"))
      "alb.ingress.kubernetes.io/actions.redirect" = jsonencode({
        type = "redirect"
        redirect = {
          host        = "${local.domain}"
          port        = "443"
          protocol    = "HTTPS"
          status_code = "HTTP_301"
        }
      })
      "alb.ingress.kubernetes.io/backend-protocol"             = "HTTPS"
      "alb.ingress.kubernetes.io/certificate-arn"              = module.acm_service.certificate_arn
      "alb.ingress.kubernetes.io/subnets"                      = join(",", module.vpc.public_subnets)
      "alb.ingress.kubernetes.io/target-type"                  = "ip"
      "alb.ingress.kubernetes.io/load-balancer-attributes"     = "routing.https2.enabled=true,idle_timeout.timeout_seconds=60"
      "alb.ingress.kubernetes.io/healthcheck-interval-seconds" = "30"
      "alb.ingress.kubernetes.io/healthy-threshold-count"      = "5"
      "alb.ingress.kubernetes.io/unhealthy-threshold-count"    = "3"
      "alb.ingress.kubernetes.io/healthcheck-timeout-seconds"  = "10"
      "alb.ingress.kubernetes.io/listen-ports" = jsonencode([{
        port     = 80
        protocol = "HTTP"
        }, {
        port     = 443
        protocol = "HTTPS"
      }])

      "alb.ingress.kubernetes.io/target-group-attributes" = "slow_start.duration_seconds=30,stickiness.enabled=true,stickiness.type=lb_cookie,stickiness.lb_cookie.duration_seconds=86400,deregistration_delay.timeout_seconds=300"
      "alb.ingress.kubernetes.io/actions.response-200" = jsonencode({
        type = "fixed-response"
        fixedResponseConfig = {
          Protocol    = "HTTPS"
          Port        = "443"
          ContentType = "text/html"
          StatusCode  = "401"
          MessageBody = "<html><body><h1>Unauthorized</h1><p>You are not authorized to access this resource.</p></body></html>"
        }
      })
      "alb.ingress.kubernetes.io/actions.ssl-redirect" = jsonencode({
        type = "redirect"
        redirect = {
          host        = "${local.domain}"
          port        = "443"
          protocol    = "HTTPS"
          status_code = "HTTP_301"
        }
      })
      "alb.ingress.kubernetes.io/actions.redirect-to-www" = jsonencode({
        type = "redirect"
        redirect = {
          Host       = "www.${local.domain}"
          Path       = "/#{path}"
          Port       = "443"
          Protocol   = "HTTPS"
          Query      = "#{query}"
          StatusCode = "HTTP_301"
        }
      })
    }
  }

  spec {
    rule {
      host = local.domain

      http {
        path {
          path      = "/*"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = "redirect-to-www"
              port {
                name   = "use-annotation"
                number = 0
              }
            }
          }
        }

      }
    }
    rule {
      host = local.domain
      http {
        path {
          path      = "/*"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = "redirect"
              port {
                name = "use-annotation"
              }
            }
          }
        }
        path {
          path      = "/*"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = "<HERE_WE_WILL_PUT_THE_FRONTEND_SERVICE_NAME_THAT_IS_EXPOSED_TO_THE_USER>"
              port {
                number = "<HERE_WE_WILL_PUT_THE_FRONTEND_SERVICE_PORT_THAT_IS_EXPOSED_TO_THE_USER>"
              }
            }
          }
        }
      }
    }
    rule {
      host = "www.${local.domain}"
      http {
        path {
          path      = "/*"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = "redirect"
              port {
                name = "use-annotation"
              }
            }
          }
        }

        path {
          path      = "/*"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = "<HERE_WE_WILL_PUT_THE_FRONTEND_SERVICE_NAME_THAT_IS_EXPOSED_TO_THE_USER>"
              port {
                number = "<HERE_WE_WILL_PUT_THE_FRONTEND_SERVICE_PORT_THAT_IS_EXPOSED_TO_THE_USER>"
              }
            }
          }
        }
      }
    }
  }
}