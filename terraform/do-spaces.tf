resource "random_string" "do-haxelib-bucket-suffix" {
  length  = 8
  lower   = true
  upper   = false
  special = false
}

resource "digitalocean_spaces_bucket" "haxelib" {
  name   = "haxelib-${random_string.do-haxelib-bucket-suffix.result}"
  region = "fra1"
  acl    = "public-read"
}

resource "digitalocean_cdn" "haxelib" {
  origin = digitalocean_spaces_bucket.haxelib.bucket_domain_name
}

provider "aws" {
  alias = "do-spaces"

  access_key = data.kubernetes_secret.haxelib-server-do-spaces.data.SPACES_ACCESS_KEY_ID
  secret_key = data.kubernetes_secret.haxelib-server-do-spaces.data.SPACES_SECRET_ACCESS_KEY
  endpoints {
    s3 = "${digitalocean_spaces_bucket.haxelib.region}.digitaloceanspaces.com"
  }

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

resource "aws_s3_bucket_policy" "do-public-read" {
  provider = aws.do-spaces
  bucket   = digitalocean_spaces_bucket.haxelib.name
  policy   = data.aws_iam_policy_document.do-public-read.json
}

data "aws_iam_policy_document" "do-public-read" {
  provider = aws.do-spaces
  statement {
    sid = "PublicReadGetObject"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::${digitalocean_spaces_bucket.haxelib.name}/*",
    ]
  }
}

data "kubernetes_secret" "haxelib-server-do-spaces" {
  provider = kubernetes.do

  metadata {
    name = "haxelib-server-do-spaces"
  }
}

resource "kubernetes_secret" "rclone-haxelib-s3-to-spaces-config" {
  provider = kubernetes.do

  metadata {
    name = "rclone-haxelib-s3-to-spaces-config"
  }

  data = {
    "rclone.conf" = <<-EOT
      [s3]
      type = s3
      env_auth = true
      region = eu-west-1
      acl = private

      [spaces]
      type = s3
      env_auth = false
      access_key_id = ${data.kubernetes_secret.haxelib-server-do-spaces.data.SPACES_ACCESS_KEY_ID}
      secret_access_key = ${data.kubernetes_secret.haxelib-server-do-spaces.data.SPACES_SECRET_ACCESS_KEY}
      endpoint = ${digitalocean_spaces_bucket.haxelib.region}.digitaloceanspaces.com
      acl = private
    EOT
  }
}

resource "kubernetes_job" "rclone-haxelib-s3-to-spaces" {
  provider = kubernetes.do

  metadata {
    name = "rclone-haxelib-s3-to-spaces"
  }
  spec {
    template {
      metadata {
        name = "rclone-haxelib-s3-to-spaces"
      }
      spec {
        container {
          name  = "rclone"
          image = "bitnami/rclone:1.57.0"
          command = [
            "rclone",
            "--config=/rclone-config/rclone.conf",
            "-vv",
            "sync",
            "s3:lib.haxe.org",
            "spaces:${digitalocean_spaces_bucket.haxelib.name}",
          ]

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

          volume_mount {
            name       = "rclone-config"
            mount_path = "/rclone-config"
            read_only  = true
          }
        }

        volume {
          name = "rclone-config"
          secret {
            secret_name = kubernetes_secret.rclone-haxelib-s3-to-spaces-config.metadata[0].name
          }
        }
        restart_policy = "Never"
      }
    }
  }
  wait_for_completion = false
}
