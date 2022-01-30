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

# kubectl create secret generic rds-mysql-haxelib --from-literal=user=FIXME --from-literal=password=FIXME
data "kubernetes_secret" "aws-rds-mysql-haxelib" {
  metadata {
    name = "rds-mysql-haxelib"
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
    replicas = each.key == "prod" ? 2 : 1

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
            value_from {
              secret_key_ref {
                name = data.kubernetes_secret.aws-rds-mysql-haxelib.metadata[0].name
                key  = "user"
              }
            }
          }
          env {
            name = "HAXELIB_DB_PASS"
            value_from {
              secret_key_ref {
                name = data.kubernetes_secret.aws-rds-mysql-haxelib.metadata[0].name
                key  = "password"
              }
            }
          }

          env {
            name  = "HAXELIB_CDN"
            value = digitalocean_cdn.haxelib.endpoint
          }

          env {
            name  = "HAXELIB_S3BUCKET"
            value = digitalocean_spaces_bucket.haxelib.name
          }
          env {
            name  = "HAXELIB_S3BUCKET_ENDPOINT"
            value = "${digitalocean_spaces_bucket.haxelib.region}.digitaloceanspaces.com"
          }

          env {
            name = "AWS_ACCESS_KEY_ID"
            value_from {
              secret_key_ref {
                name = "haxelib-server-do-spaces"
                key  = "SPACES_ACCESS_KEY_ID"
              }
            }
          }
          env {
            name = "AWS_SECRET_ACCESS_KEY"
            value_from {
              secret_key_ref {
                name = "haxelib-server-do-spaces"
                key  = "SPACES_SECRET_ACCESS_KEY"
              }
            }
          }
          env {
            name  = "AWS_DEFAULT_REGION"
            value = "us-east-1"
          }

          liveness_probe {
            http_get {
              path = "/httpd-status?auto"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 15
            timeout_seconds       = 5
          }
        }
      }
    }
  }
}

resource "kubernetes_pod_disruption_budget" "haxelib-server" {
  for_each = {for k, v in local.haxelib_server.stage: k => v if k == "prod"}

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
      "nginx.ingress.kubernetes.io/proxy-buffering" = "on"

      # https://nginx.org/en/docs/http/ngx_http_proxy_module.html
      "nginx.ingress.kubernetes.io/configuration-snippet" = <<-EOT
        proxy_set_header Cookie "";
        proxy_cache mycache;
        proxy_cache_key "$scheme$request_method$host$request_uri";
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
