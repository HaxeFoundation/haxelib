locals {
  r2 = {
    bucket        = "haxelib-mipsgux5"
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

resource "kubernetes_config_map_v1" "rclone-config" {
  metadata {
    name = "rclone-config"
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

resource "kubernetes_cron_job_v1" "copy-r2-to-do-spaces" {
  metadata {
    name = "copy-r2-to-do-spaces"
  }
  spec {
    concurrency_policy = "Forbid"
    schedule           = "0 3 * * *" # at 03:00 daily
    job_template {
      metadata {
        name = "copy-r2-to-do-spaces"
      }
      spec {
        backoff_limit              = 0
        ttl_seconds_after_finished = 60
        template {
          metadata {
            name = "copy-r2-to-do-spaces"
          }
          spec {
            container {
              name  = "rclone"
              image = "rclone/rclone:1.61.1"
              args  = ["copy", "--verbose", "r2:${local.r2.bucket}/files/3.0", "do:${digitalocean_spaces_bucket.haxelib.name}/files/3.0"]

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

            image_pull_secrets {
              name = local.imagePullSecrets
            }

            volume {
              name = "config"
              config_map {
                name = kubernetes_config_map_v1.rclone-config.metadata[0].name
              }
            }
          }
        }
      }
    }
  }
}
