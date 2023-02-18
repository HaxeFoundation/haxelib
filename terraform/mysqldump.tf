resource "kubernetes_secret_v1" "mysqldump-config" {
  metadata {
    name = "mysqldump-config"
  }

  data = {
    "mysql.config" = <<-EOF
      [client]
      host = "haxelib-mysql-57-primary"
      port = 3306
      user = "root"
      password = "${data.kubernetes_secret_v1.haxelib-mysql-57.data.mysql-root-password}"
    EOF
  }
}

resource "kubernetes_cron_job_v1" "mysqldump" {
  metadata {
    name = "mysqldump"
  }
  spec {
    concurrency_policy = "Forbid"
    schedule           = "0 2 * * *" # at 02:00 daily
    job_template {
      metadata {
        name = "mysqldump"
      }
      spec {
        backoff_limit              = 0
        ttl_seconds_after_finished = 60
        template {
          metadata {
            name = "mysqldump"
          }
          spec {
            container {
              name  = "mysqldump"
              image = "mysql:5.7.40"
              args = [
                "bash", "-c", <<-EOF
                    set -exo pipefail
                    mysqldump \
                        --defaults-extra-file="/mysqldump-config/mysql.config" \
                        --set-gtid-purged=OFF \
                        --single-transaction \
                        haxelib \
                        | gzip -c \
                        | rclone rcat "do:${digitalocean_spaces_bucket.haxelib.name}/mysqldump/haxelib_$(date +%Y-%m-%d_%H-%M-%S).sql.gz"
                EOF
              ]

              volume_mount {
                name       = "rclone-config"
                mount_path = "/root/.config/rclone/"
                read_only  = true
              }
              volume_mount {
                name       = "mysqldump-config"
                mount_path = "/mysqldump-config"
                read_only  = true
              }

              volume_mount {
                name       = "share-bin"
                mount_path = "/share_bin"
                read_only  = true
              }

              env {
                name  = "PATH"
                value = "/share_bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
              }

              env {
                name = "RCLONE_CONFIG_DO_ACCESS_KEY_ID"
                value_from {
                  secret_key_ref {
                    name = "haxelib-server-do-spaces"
                    key  = "SPACES_ACCESS_KEY_ID"
                  }
                }
              }
              env {
                name = "RCLONE_CONFIG_DO_SECRET_ACCESS_KEY"
                value_from {
                  secret_key_ref {
                    name = "haxelib-server-do-spaces"
                    key  = "SPACES_SECRET_ACCESS_KEY"
                  }
                }
              }
            }

            init_container {
              name  = "rclone-binary"
              image = "rclone/rclone:1.61"
              command = [
                "cp", "/usr/local/bin/rclone", "/share_bin/rclone"
              ]

              volume_mount {
                name       = "share-bin"
                mount_path = "/share_bin"
                read_only  = false
              }
            }

            volume {
              name = "rclone-config"
              config_map {
                name = kubernetes_config_map_v1.rclone-config.metadata[0].name
              }
            }

            volume {
              name = "mysqldump-config"
              secret {
                secret_name = kubernetes_secret_v1.mysqldump-config.metadata[0].name
              }
            }

            volume {
              name = "share-bin"
              empty_dir {}
            }
          }
        }
      }
    }
  }
}
