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

          env {
            name  = "HAXELIB_S3BUCKET"
            value = each.value.HAXELIB_S3BUCKET
          }
          env {
            name  = "HAXELIB_S3BUCKET_ENDPOINT"
            value = each.value.HAXELIB_S3BUCKET_ENDPOINT
          }
          env {
            name  = "HAXELIB_S3BUCKET_MOUNTED_PATH"
            value = "/var/haxelib-s3fs"
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

          volume_mount {
            name              = "pod-haxelib-s3fs"
            mount_path        = "/var/haxelib-s3fs"
            mount_propagation = "HostToContainer"
            read_only         = false
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

        container {
          image = "haxe/s3fs:latest"
          name  = "s3fs"
          command = [
            "s3fs", each.value.HAXELIB_S3BUCKET, "/var/s3fs",
            "-f",
            "-o", "url=${each.value.bucket_gateway_url}",
            "-o", "use_path_request_style",
            "-o", "umask=022,uid=33,gid=33", # 33 = www-data
            "-o", "allow_other",
          ]

          security_context {
            privileged = true
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "50Mi"
            }
          }

          env {
            name = "AWSACCESSKEYID"
            value_from {
              secret_key_ref {
                name = each.value.AWS_ACCESS_KEY_ID.name
                key  = each.value.AWS_ACCESS_KEY_ID.key
              }
            }
          }
          env {
            name = "AWSSECRETACCESSKEY"
            value_from {
              secret_key_ref {
                name = each.value.AWS_SECRET_ACCESS_KEY.name
                key  = each.value.AWS_SECRET_ACCESS_KEY.key
              }
            }
          }

          volume_mount {
            name              = "pod-haxelib-s3fs"
            mount_path        = "/var/s3fs"
            mount_propagation = "Bidirectional"
            read_only         = false
          }
        }

        security_context {
          fs_group = 33 # www-data
        }

        volume {
          name = "pod-haxelib-s3fs"
          empty_dir {}
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

resource "kubernetes_ingress_v1" "do-haxelib-server-files" {
  for_each = local.haxelib_server.stage

  metadata {
    name = "haxelib-server-${each.key}-files"
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
              name = kubernetes_service_v1.do-haxelib-server-files[each.key].metadata[0].name
              port {
                number = 80
              }
            }
          }
          path      = "/files/3.0"
          path_type = "Prefix"
        }
      }
    }
  }
}
