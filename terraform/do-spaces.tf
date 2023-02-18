resource "random_string" "do-haxelib-bucket-suffix" {
  length  = 8
  lower   = true
  upper   = false
  special = false
}

resource "digitalocean_spaces_bucket" "haxelib" {
  name   = "haxelib-${random_string.do-haxelib-bucket-suffix.result}"
  region = "fra1"
  acl    = "private"
  versioning {
    enabled = true
  }
  lifecycle_rule {
    enabled = true
    prefix  = "mysqldump/"
    expiration {
      days = 30
    }
  }
}

resource "digitalocean_cdn" "haxelib" {
  origin = digitalocean_spaces_bucket.haxelib.bucket_domain_name
  ttl    = 86400 # 1 day
}

resource "digitalocean_spaces_bucket_policy" "haxelib" {
  region = digitalocean_spaces_bucket.haxelib.region
  bucket = digitalocean_spaces_bucket.haxelib.name
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "PublicReadGetObject",
        "Effect" : "Allow",
        "Principal" : "*",
        "Action" : "s3:GetObject",
        "Resource" : [
          "arn:aws:s3:::${digitalocean_spaces_bucket.haxelib.name}/files/*"
        ],
      }
    ]
  })
}

data "kubernetes_secret_v1" "haxelib-server-do-spaces" {
  metadata {
    name = "haxelib-server-do-spaces"
  }
}

resource "kubernetes_secret_v1" "rclone-haxelib-s3-to-spaces-config" {
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
      access_key_id = ${data.kubernetes_secret_v1.haxelib-server-do-spaces.data.SPACES_ACCESS_KEY_ID}
      secret_access_key = ${data.kubernetes_secret_v1.haxelib-server-do-spaces.data.SPACES_SECRET_ACCESS_KEY}
      endpoint = ${digitalocean_spaces_bucket.haxelib.region}.digitaloceanspaces.com
      acl = private
    EOT
  }
}
