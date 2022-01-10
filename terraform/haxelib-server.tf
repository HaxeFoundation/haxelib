locals {
  haxelib_server = {
    stage = {
      dev = {
        host    = "development-lib.haxe.org"
        host_do = "do-development-lib.haxe.org"
        image   = var.HAXELIB_SERVER_IMAGE_DEVELOPMENT != null ? var.HAXELIB_SERVER_IMAGE_DEVELOPMENT : try(data.terraform_remote_state.previous.outputs.haxelib_server.stage.dev.image, null)
      }
      prod = {
        host    = "lib.haxe.org"
        host_do = "do-lib.haxe.org"
        image   = var.HAXELIB_SERVER_IMAGE_MASTER != null ? var.HAXELIB_SERVER_IMAGE_MASTER : try(data.terraform_remote_state.previous.outputs.haxelib_server.stage.prod.image, null)
      }
    }
  }
}

output "haxelib_server" {
  value = local.haxelib_server
}

resource "kubernetes_secret" "haxelib-db" {
  metadata {
    name = "haxelib-db"
  }
  data = {
    HAXELIB_DB_PASS = var.HAXELIB_DB_PASS
  }
}

resource "kubernetes_deployment" "haxelib-server" {
  for_each = local.haxelib_server.stage

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
                name = kubernetes_secret.haxelib-db.metadata[0].name
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

resource "kubernetes_pod_disruption_budget" "haxelib-server" {
  for_each = local.haxelib_server.stage

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

resource "kubernetes_service" "haxelib-server" {
  for_each = local.haxelib_server.stage

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

resource "kubernetes_ingress" "haxelib-server" {
  for_each = local.haxelib_server.stage

  metadata {
    name = "haxelib-server-${each.key}"
    annotations = {
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
    rule {
      host = each.value.host
      http {
        path {
          backend {
            service_name = kubernetes_service.haxelib-server[each.key].metadata[0].name
            service_port = 80
          }
          path = "/"
        }
      }
    }
  }
}
