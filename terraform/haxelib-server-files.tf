resource "kubernetes_deployment_v1" "do-haxelib-server-files" {
  for_each = local.haxelib_server.stage

  metadata {
    name = "haxelib-server-${each.key}-files"
    labels = {
      "app.kubernetes.io/name"     = "haxelib-server"
      "app.kubernetes.io/instance" = "haxelib-server-${each.key}-files"
    }
  }

  spec {
    replicas = each.value.replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "haxelib-server"
        "app.kubernetes.io/instance" = "haxelib-server-${each.key}-files"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"     = "haxelib-server"
          "app.kubernetes.io/instance" = "haxelib-server-${each.key}-files"
        }
      }

      spec {
        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "kubernetes.io/hostname"
          when_unsatisfiable = "ScheduleAnyway"
          label_selector {
            match_labels = {
              "app.kubernetes.io/instance" = "haxelib-server-${each.key}-files"
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
              cpu = "50m"
              # Measured over 10 days (Nov 2026): p50 23Mi, p99 47Mi.
              memory = "48Mi"
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

          env {
            name  = "HAXELIB_S3BUCKET"
            value = each.value.HAXELIB_S3BUCKET
          }
          env {
            name  = "HAXELIB_S3BUCKET_ENDPOINT"
            value = each.value.HAXELIB_S3BUCKET_ENDPOINT
          }
          env {
            name = "AWS_ACCESS_KEY_ID"
            value_from {
              secret_key_ref {
                name = each.value.AWS_ACCESS_KEY_ID.name
                key  = each.value.AWS_ACCESS_KEY_ID.key
              }
            }
          }
          env {
            name = "AWS_SECRET_ACCESS_KEY"
            value_from {
              secret_key_ref {
                name = each.value.AWS_SECRET_ACCESS_KEY.name
                key  = each.value.AWS_SECRET_ACCESS_KEY.key
              }
            }
          }
          env {
            name  = "AWS_DEFAULT_REGION"
            value = "us-east-1"
          }

          # Liveness only checks that Apache accepts TCP connections. The kernel completes the handshake
          # even when all prefork workers are busy, so a saturated (but alive) Apache is not restarted.
          liveness_probe {
            tcp_socket {
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 15
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          # Readiness goes through an Apache worker. When all workers are busy, the pod is taken out of
          # the Service endpoints until it recovers, instead of being killed.
          readiness_probe {
            http_get {
              path = "/httpd-status?auto"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
            success_threshold     = 1
          }
        }

        # No s3fs sidecar: /files/3.0 is always redirected/proxied to HAXELIB_CDN
        # (see www/.htaccess and HomeController.downloadFile), so the bucket mount is never read.

        image_pull_secrets {
          name = local.imagePullSecrets
        }

        security_context {
          fs_group = 33 # www-data
        }
      }
    }
  }
}

resource "kubernetes_pod_disruption_budget_v1" "do-haxelib-server-files" {
  for_each = local.haxelib_server.stage

  metadata {
    name = "haxelib-server-${each.key}-files"
  }
  spec {
    min_available = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "haxelib-server"
        "app.kubernetes.io/instance" = "haxelib-server-${each.key}-files"
      }
    }
  }
}

resource "kubernetes_service_v1" "do-haxelib-server-files" {
  for_each = local.haxelib_server.stage

  metadata {
    name = "haxelib-server-${each.key}-files"
  }

  spec {
    selector = {
      "app.kubernetes.io/name"     = "haxelib-server"
      "app.kubernetes.io/instance" = "haxelib-server-${each.key}-files"
    }

    port {
      name     = "http"
      protocol = "TCP"
      port     = 80
    }
  }
}
