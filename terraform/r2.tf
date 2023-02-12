locals {
  r2 = {
    bucket        = "haxelib"
    endpoint      = "09c8df40903546d43dba5a1924ee4b43.r2.cloudflarestorage.com"
    domain_access = "haxelib-files.haxe.org"
  }
}

data "aws_ssm_parameter" "haxelib_r2_access_key_id" {
  name = "haxelib_r2_access_key_id"
}

data "aws_ssm_parameter" "haxelib_r2_secret_access_key" {
  name = "haxelib_r2_secret_access_key"
}

resource "kubernetes_secret_v1" "haxelib-server-r2" {
  metadata {
    name = "haxelib-server-r2"
  }
  data = {
    haxelib_r2_access_key_id     = data.aws_ssm_parameter.haxelib_r2_access_key_id.value
    haxelib_r2_secret_access_key = data.aws_ssm_parameter.haxelib_r2_secret_access_key.value
  }
}

resource "kubernetes_config_map_v1" "copy-do-spaces-to-r2" {
  metadata {
    name = "copy-do-spaces-to-r2"
  }
  data = {
    "rclone.conf" = <<-EOF
        [r2]
        type = s3
        provider = Cloudflare
        env_auth = false
        endpoint = https://${local.r2.endpoint}

        [do]
        type = s3
        provider = DigitalOcean
        region = ${digitalocean_spaces_bucket.haxelib.region}
        endpoint = ${digitalocean_spaces_bucket.haxelib.region}.digitaloceanspaces.com
    EOF
  }
}

resource "kubernetes_cron_job_v1" "copy-do-spaces-to-r2" {
  metadata {
    name = "copy-do-spaces-to-r2"
  }
  spec {
    concurrency_policy = "Forbid"
    schedule           = "0 3 * * *" # at 03:00 daily
    job_template {
      metadata {
        name = "copy-do-spaces-to-r2"
      }
      spec {
        backoff_limit              = 0
        ttl_seconds_after_finished = 60
        template {
          metadata {
            name = "copy-do-spaces-to-r2"
          }
          spec {
            container {
              name  = "rclone"
              image = "rclone/rclone:1.61.1"
              args  = ["copy", "--verbose", "do:${digitalocean_spaces_bucket.haxelib.name}", "r2:${local.r2.bucket}"]

              volume_mount {
                name       = "config"
                mount_path = "/config/rclone"
              }

              env {
                name = "RCLONE_CONFIG_R2_ACCESS_KEY_ID"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.haxelib-server-r2.metadata[0].name
                    key  = "haxelib_r2_access_key_id"
                  }
                }
              }
              env {
                name = "RCLONE_CONFIG_R2_SECRET_ACCESS_KEY"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.haxelib-server-r2.metadata[0].name
                    key  = "haxelib_r2_secret_access_key"
                  }
                }
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

            volume {
              name = "config"
              config_map {
                name = kubernetes_config_map_v1.copy-do-spaces-to-r2.metadata[0].name
              }
            }
          }
        }
      }
    }
  }
}
