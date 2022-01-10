resource "kubernetes_secret" "do-haxelib-db" {
  provider = kubernetes.do
  metadata {
    name = "haxelib-db"
  }
  data = {
    HAXELIB_DB_PASS = var.HAXELIB_DB_PASS
  }
}

resource "kubernetes_deployment" "do-haxelib-server" {
  for_each = local.haxelib_server.stage

  provider = kubernetes.do
  metadata {
    name = "haxelib-server-${each.key}"
    labels = {
      "app.kubernetes.io/name"     = "haxelib-server"
      "app.kubernetes.io/instance" = "haxelib-server-${each.key}"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "haxelib-server"
        "app.kubernetes.io/instance" = "haxelib-server-${each.key}"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"     = "haxelib-server"
          "app.kubernetes.io/instance" = "haxelib-server-${each.key}"
        }
      }

      spec {
        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "kubernetes.io/hostname"
          when_unsatisfiable = "ScheduleAnyway"
          label_selector {
            match_labels = {
              "app.kubernetes.io/instance" = "haxelib-server-${each.key}"
            }
          }
        }
        # affinity {
        #   node_affinity {
        #     preferred_during_scheduling_ignored_during_execution {
        #       preference {
        #         match_expressions {
        #           key      = "node.kubernetes.io/instance-type"
        #           operator = "In"
        #           values   = ["s-4vcpu-8gb"]
        #         }
        #       }
        #       weight = 1
        #     }
        #   }
        # }

        container {
          image = each.value.image
          name  = "haxelib-server"

          port {
            container_port = 80
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "200M"
            }
          }

          env {
            name  = "HAXELIB_DB_HOST"
            value = aws_db_instance.haxe-org.address
          }
          env {
            name  = "HAXELIB_DB_PORT"
            value = aws_db_instance.haxe-org.port
          }
          env {
            name  = "HAXELIB_DB_NAME"
            value = "haxelib"
          }
          env {
            name  = "HAXELIB_DB_USER"
            value = var.HAXELIB_DB_USER
          }
          env {
            name = "HAXELIB_DB_PASS"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.do-haxelib-db.metadata[0].name
                key  = "HAXELIB_DB_PASS"
              }
            }
          }

          env {
            name  = "HAXELIB_CDN"
            value = "d1smpvufia21az.cloudfront.net"
          }

          env {
            name  = "HAXELIB_S3BUCKET"
            value = aws_s3_bucket.lib-haxe-org.bucket
          }

          env {
            name = "AWS_ACCESS_KEY_ID"
            value_from {
              secret_key_ref {
                name = "haxelib-server"
                key  = "AWS_ACCESS_KEY_ID"
              }
            }
          }
          env {
            name = "AWS_SECRET_ACCESS_KEY"
            value_from {
              secret_key_ref {
                name = "haxelib-server"
                key  = "AWS_SECRET_ACCESS_KEY"
              }
            }
          }
          env {
            name = "AWS_DEFAULT_REGION"
            value_from {
              secret_key_ref {
                name = "haxelib-server"
                key  = "AWS_DEFAULT_REGION"
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_pod_disruption_budget" "do-haxelib-server" {
  for_each = local.haxelib_server.stage

  provider = kubernetes.do
  metadata {
    name = "haxelib-server-${each.key}"
  }
  spec {
    min_available = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "haxelib-server"
        "app.kubernetes.io/instance" = "haxelib-server-${each.key}"
      }
    }
  }
}

resource "kubernetes_service" "do-haxelib-server" {
  for_each = local.haxelib_server.stage

  provider = kubernetes.do
  metadata {
    name = "haxelib-server-${each.key}"
  }

  spec {
    selector = {
      "app.kubernetes.io/name"     = "haxelib-server"
      "app.kubernetes.io/instance" = "haxelib-server-${each.key}"
    }

    port {
      name     = "http"
      protocol = "TCP"
      port     = 80
    }
  }
}

resource "kubernetes_ingress" "do-haxelib-server" {
  for_each = local.haxelib_server.stage

  provider = kubernetes.do
  metadata {
    name = "haxelib-server-${each.key}"
    annotations = {
      "cert-manager.io/cluster-issuer"                    = "letsencrypt-production"
      "nginx.ingress.kubernetes.io/proxy-buffering"       = "on"

      # https://nginx.org/en/docs/http/ngx_http_proxy_module.html
      "nginx.ingress.kubernetes.io/configuration-snippet" = <<-EOT
        proxy_cache mycache;
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
        proxy_cache_background_update on;
        proxy_cache_revalidate on;
        proxy_cache_lock on;
        add_header X-Cache-Status $upstream_cache_status;
      EOT
    }
  }

  spec {
    tls {
      hosts       = [each.value.host_do]
      secret_name = "haxelib-server-${each.key}-tls"
    }
    rule {
      host = each.value.host_do
      http {
        path {
          backend {
            service_name = kubernetes_service.do-haxelib-server[each.key].metadata[0].name
            service_port = 80
          }
          path = "/"
        }
      }
    }
  }
}
