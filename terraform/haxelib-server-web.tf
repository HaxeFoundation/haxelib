resource "kubernetes_deployment_v1" "do-haxelib-server" {
  for_each = local.haxelib_server.stage

  metadata {
    name = "haxelib-server-${each.key}"
    labels = {
      "app.kubernetes.io/name"     = "haxelib-server"
      "app.kubernetes.io/instance" = "haxelib-server-${each.key}"
    }
  }

  spec {
    replicas = each.value.replicas

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

        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                label_selector {
                  match_labels = {
                    "app.kubernetes.io/name" : "mysql"
                  }
                }
                topology_key = "kubernetes.io/hostname"
              }
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
              memory = each.key == "prod" ? "1Gi" : "200Mi"
            }
            limits = {
              memory = "1Gi"
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

          env {
            name = "RCLONE_CONFIG_S3_ACCESS_KEY_ID"
            value_from {
              secret_key_ref {
                name = each.value.AWS_ACCESS_KEY_ID.name
                key  = each.value.AWS_ACCESS_KEY_ID.key
              }
            }
          }
          env {
            name = "RCLONE_CONFIG_S3_SECRET_ACCESS_KEY"
            value_from {
              secret_key_ref {
                name = each.value.AWS_SECRET_ACCESS_KEY.name
                key  = each.value.AWS_SECRET_ACCESS_KEY.key
              }
            }
          }

          volume_mount {
            name              = "pod-haxelib-s3fs"
            mount_path        = "/var/haxelib-s3fs"
            mount_propagation = "HostToContainer"
            read_only         = false
          }

          volume_mount {
            name       = "haxelib-rclone-config"
            mount_path = "/var/www/.rclone.conf"
            sub_path   = "rclone.conf"
            read_only  = true
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

        image_pull_secrets {
          name = local.imagePullSecrets
        }

        security_context {
          fs_group = 33 # www-data
        }

        volume {
          name = "pod-haxelib-s3fs"
          empty_dir {}
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
        volume {
          name = "haxelib-rclone-config"
          config_map {
            name = kubernetes_config_map_v1.haxelib-rclone-config.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_pod_disruption_budget_v1" "do-haxelib-server" {
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

resource "kubernetes_service_v1" "do-haxelib-server" {
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

resource "kubernetes_ingress_v1" "do-haxelib-server" {
  for_each = local.haxelib_server.stage

  metadata {
    name = "haxelib-server-${each.key}"
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-production"

      # Do not force https at ingress-level.
      # Let the Apache in the haxelib server container handle it.
      "nginx.ingress.kubernetes.io/ssl-redirect" = false

      # https://nginx.org/en/docs/http/ngx_http_proxy_module.html
      "nginx.ingress.kubernetes.io/proxy-buffering"       = "on"
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
              name = kubernetes_service_v1.do-haxelib-server[each.key].metadata[0].name
              port {
                number = 80
              }
            }
          }
          path      = "/"
          path_type = "Prefix"
        }
      }
    }
  }
}
