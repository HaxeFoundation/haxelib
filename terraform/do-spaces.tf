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
  ttl    = 86400 # 1 day
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
