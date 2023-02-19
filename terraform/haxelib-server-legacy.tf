resource "kubernetes_deployment_v1" "do-haxelib-server-legacy" {
  for_each = local.haxelib_server.stage

  metadata {
    name = "haxelib-server-${each.key}-legacy"
    labels = {
      "app.kubernetes.io/name"     = "haxelib-server"
      "app.kubernetes.io/instance" = "haxelib-server-${each.key}-legacy"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "haxelib-server"
        "app.kubernetes.io/instance" = "haxelib-server-${each.key}-legacy"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"     = "haxelib-server"
          "app.kubernetes.io/instance" = "haxelib-server-${each.key}-legacy"
        }
      }

      spec {
        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "kubernetes.io/hostname"
          when_unsatisfiable = "ScheduleAnyway"
          label_selector {
            match_labels = {
              "app.kubernetes.io/instance" = "haxelib-server-${each.key}-legacy"
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
              cpu    = "50m"
              memory = "100Mi"
            }
            limits = {
              memory = "500Mi"
            }
          }

          env {
            name  = "HAXELIB_DB_HOST"
            value = "haxelib-mysql-57-primary"
          }
          env {
            name  = "HAXELIB_DB_PORT"
            value = "3306"
          }
          env {
            name  = "HAXELIB_DB_NAME"
            value = "haxelib"
          }
          env {
            name  = "HAXELIB_DB_USER"
            value = "haxelib"
          }
          env {
            name = "HAXELIB_DB_PASS"
            value_from {
              secret_key_ref {
                name = data.kubernetes_secret_v1.haxelib-mysql-57.metadata[0].name
                key  = "mysql-password"
              }
            }
          }

          env {
            name  = "HAXELIB_CDN"
            value = each.value.HAXELIB_CDN
          }

          volume_mount {
            name       = "legacy"
            mount_path = "/src/www/legacy/haxelib.db"
            sub_path   = "haxelib.db"
            read_only  = true
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

        init_container {
          name  = "rclone"
          image = "rclone/rclone:1.61"
          args = [
            "copyto", "--verbose", "do:${digitalocean_spaces_bucket.haxelib.name}/legacy/haxelib.db", "/legacy/haxelib.db"
          ]

          env {
            name = "RCLONE_CONFIG_DO_ACCESS_KEY_ID"
            value_from {
              secret_key_ref {
                name = data.kubernetes_secret_v1.haxelib-server-do-spaces.metadata[0].name
                key  = "SPACES_ACCESS_KEY_ID"
              }
            }
          }
          env {
            name = "RCLONE_CONFIG_DO_SECRET_ACCESS_KEY"
            value_from {
              secret_key_ref {
                name = data.kubernetes_secret_v1.haxelib-server-do-spaces.metadata[0].name
                key  = "SPACES_SECRET_ACCESS_KEY"
              }
            }
          }

          volume_mount {
            name       = "rclone-config"
            mount_path = "/config/rclone"
            read_only  = true
          }

          volume_mount {
            name       = "legacy"
            mount_path = "/legacy"
            read_only  = false
          }
        }

        security_context {
          fs_group = 33 # www-data
        }

        volume {
          name = "legacy"
          empty_dir {}
        }

        volume {
          name = "rclone-config"
          config_map {
            name = kubernetes_config_map_v1.rclone-config.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_pod_disruption_budget_v1" "do-haxelib-server-legacy" {
  for_each = local.haxelib_server.stage

  metadata {
    name = "haxelib-server-${each.key}-legacy"
  }
  spec {
    min_available = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "haxelib-server"
        "app.kubernetes.io/instance" = "haxelib-server-${each.key}-legacy"
      }
    }
  }
}

resource "kubernetes_service_v1" "do-haxelib-server-legacy" {
  for_each = local.haxelib_server.stage

  metadata {
    name = "haxelib-server-${each.key}-legacy"
  }

  spec {
    selector = {
      "app.kubernetes.io/name"     = "haxelib-server"
      "app.kubernetes.io/instance" = "haxelib-server-${each.key}-legacy"
    }

    port {
      name     = "http"
      protocol = "TCP"
      port     = 80
    }
  }
}

resource "kubernetes_ingress_v1" "do-haxelib-server-legacy" {
  for_each = local.haxelib_server.stage

  metadata {
    name = "haxelib-server-${each.key}-legacy"
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-production"

      # Do not force https at ingress-level.
      # Let the Apache in the haxelib server container handle it.
      "nginx.ingress.kubernetes.io/ssl-redirect" = false
    }
  }

  spec {
    ingress_class_name = "nginx"
    tls {
      hosts       = [each.value.host]
      secret_name = "haxelib-server-${each.key}-tls"
    }
    rule {
      host = each.value.host
      http {
        path {
          backend {
            service {
              name = kubernetes_service_v1.do-haxelib-server-legacy[each.key].metadata[0].name
              port {
                number = 80
              }
            }
          }
          path = "/index.n"
        }

        path {
          backend {
            service {
              name = kubernetes_service_v1.do-haxelib-server-legacy[each.key].metadata[0].name
              port {
                number = 80
              }
            }
          }
          path = "/legacy"
        }
      }
    }
  }
}
