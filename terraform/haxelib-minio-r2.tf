# This is a proxy/cache to the bucket for performance improvement as well as cost reduction.
# MinIO gateway is deprecated https://blog.min.io/deprecation-of-the-minio-gateway/
# Consider migrating to something else, e.g.
# https://github.com/seaweedfs/seaweedfs/wiki/Gateway-to-Remote-Object-Storage

resource "kubernetes_deployment_v1" "do-haxelib-minio-r2" {
  metadata {
    name = "haxelib-minio-r2"
    labels = {
      "app.kubernetes.io/name"     = "minio"
      "app.kubernetes.io/instance" = "haxelib-minio-r2"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "minio"
        "app.kubernetes.io/instance" = "haxelib-minio-r2"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"     = "minio"
          "app.kubernetes.io/instance" = "haxelib-minio-r2"
        }
      }

      spec {
        container {
          image = "docker.io/bitnamilegacy/minio:2022.1.28"
          name  = "minio"

          command = [
            "minio",
            "gateway",
            "s3",
            "https://${local.r2.endpoint}",
            "--console-address", ":9001",
          ]

          port {
            container_port = 9000
          }
          port {
            container_port = 9001
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "200Mi"
            }
            limits = {
              memory = "1Gi"
            }
          }

          env {
            name = "MINIO_ROOT_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.haxelib-server-r2.metadata[0].name
                key  = "haxelib_r2_access_key_id"
              }
            }
          }
          env {
            name = "MINIO_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.haxelib-server-r2.metadata[0].name
                key  = "haxelib_r2_secret_access_key"
              }
            }
          }

          // https://docs.min.io/docs/minio-disk-cache-guide.html
          env {
            name  = "MINIO_CACHE"
            value = "on"
          }

          env {
            name  = "MINIO_CACHE_DRIVES"
            value = "/var/pod-haxelib-s3fs-cache"
          }

          env {
            name  = "MINIO_CACHE_AFTER"
            value = "1"
          }

          env {
            name  = "MINIO_CACHE_QUOTA"
            value = "90"
          }

          env {
            name  = "MINIO_CACHE_WATERMARK_LOW"
            value = "70"
          }

          env {
            name  = "MINIO_CACHE_WATERMARK_HIGH"
            value = "90"
          }

          volume_mount {
            name       = "pod-haxelib-s3fs-cache"
            mount_path = "/var/pod-haxelib-s3fs-cache"
            read_only  = false
          }
        }

        volume {
          name = "pod-haxelib-s3fs"
          empty_dir {}
        }

        volume {
          name = "pod-haxelib-s3fs-cache"
          empty_dir {
            size_limit = "100Gi"
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "do-haxelib-minio-r2" {
  metadata {
    name = "haxelib-minio-r2"
  }

  spec {
    selector = {
      "app.kubernetes.io/name"     = "minio"
      "app.kubernetes.io/instance" = "haxelib-minio-r2"
    }

    port {
      name     = "api"
      protocol = "TCP"
      port     = 9000
    }
    port {
      name     = "console"
      protocol = "TCP"
      port     = 9001
    }
  }
}

# The MinIO console is not exposed publicly. Access it via port-forwarding:
#   kubectl port-forward svc/haxelib-minio-r2 9001:9001
# then open http://localhost:9001 and log in with the R2 access key id / secret
# (MINIO_ROOT_USER / MINIO_ROOT_PASSWORD above).
