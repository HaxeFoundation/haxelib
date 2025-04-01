locals {
  imagePullSecrets = data.kubernetes_secret_v1.dockerhub-imagepullsecrets.metadata[0].name
  haxelib_server = {
    stage = {
      dev = {
        host  = "development-lib.haxe.org"
        image = var.HAXELIB_SERVER_IMAGE_DEVELOPMENT != null ? var.HAXELIB_SERVER_IMAGE_DEVELOPMENT : try(data.terraform_remote_state.previous.outputs.haxelib_server.stage.dev.image, null)

        replicas = 1

        bucket_gateway_url        = "http://${kubernetes_service_v1.do-haxelib-minio-r2.metadata[0].name}:9000"
        HAXELIB_CDN               = local.r2.domain_access
        HAXELIB_S3BUCKET          = local.r2.bucket
        HAXELIB_S3BUCKET_ENDPOINT = local.r2.endpoint
        AWS_ACCESS_KEY_ID = {
          name = kubernetes_secret_v1.haxelib-server-r2.metadata[0].name
          key  = "haxelib_r2_access_key_id"
        }
        AWS_SECRET_ACCESS_KEY = {
          name = kubernetes_secret_v1.haxelib-server-r2.metadata[0].name
          key  = "haxelib_r2_secret_access_key"
        }
      }
      prod = {
        host  = "lib.haxe.org"
        image = var.HAXELIB_SERVER_IMAGE_MASTER != null ? var.HAXELIB_SERVER_IMAGE_MASTER : try(data.terraform_remote_state.previous.outputs.haxelib_server.stage.prod.image, null)

        replicas = 2

        bucket_gateway_url        = "http://${kubernetes_service_v1.do-haxelib-minio-r2.metadata[0].name}:9000"
        HAXELIB_CDN               = local.r2.domain_access
        HAXELIB_S3BUCKET          = local.r2.bucket
        HAXELIB_S3BUCKET_ENDPOINT = local.r2.endpoint
        AWS_ACCESS_KEY_ID = {
          name = kubernetes_secret_v1.haxelib-server-r2.metadata[0].name
          key  = "haxelib_r2_access_key_id"
        }
        AWS_SECRET_ACCESS_KEY = {
          name = kubernetes_secret_v1.haxelib-server-r2.metadata[0].name
          key  = "haxelib_r2_secret_access_key"
        }
      }
    }
  }
}

output "haxelib_server" {
  value = local.haxelib_server
}

data "kubernetes_secret_v1" "dockerhub-imagepullsecrets" {
  metadata {
    name = "dockerhub-imagepullsecrets"
  }
}
resource "kubernetes_secret_v1" "do-haxelib-minio-s3fs-config" {
  metadata {
    name = "haxelib-minio-s3fs-config"
  }

  data = {
    "passwd" = "${data.kubernetes_secret_v1.haxelib-server-do-spaces.data.SPACES_ACCESS_KEY_ID}:${data.kubernetes_secret_v1.haxelib-server-do-spaces.data.SPACES_SECRET_ACCESS_KEY}"
  }
}

# kubectl create secret generic rds-mysql-haxelib --from-literal=user=FIXME --from-literal=password=FIXME
data "kubernetes_secret_v1" "do-rds-mysql-haxelib" {
  metadata {
    name = "rds-mysql-haxelib"
  }
}


resource "kubernetes_config_map_v1" "haxelib-rclone-config" {
  metadata {
    name = "haxelib-rclone-config"
  }
  data = {
    "rclone.conf" = <<-EOF
        [s3]
        type = s3
        provider = Cloudflare
        env_auth = false
        endpoint = https://${local.r2.endpoint}
    EOF
  }
}
