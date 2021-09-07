resource "kubernetes_secret" "haxelib-db" {
  metadata {
    name = "haxelib-db"
  }
  data = {
    HAXELIB_DB_PASS = var.HAXELIB_DB_PASS
  }
}

resource "kubernetes_deployment" "haxelib-server" {
  metadata {
    name = "haxelib-server"
    labels = {
      "app.kubernetes.io/name" = "haxelib-server"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "haxelib-server"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "haxelib-server"
        }
      }

      spec {
        container {
          image = "haxe/lib.haxe.org:9c1cb344c689dc59b8e89aee5c8b38c632044daf"
          name  = "haxelib-server"

          port {
            container_port = 80
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "200M"
            }
          }

          env {
            name  = "HAXELIB_DB_HOST"
            value = aws_db_instance.haxe-org.address
          }
          env {
            name  = "HAXELIB_DB_PORT"
            value = aws_db_instance.haxe-org.port
          }
          env {
            name  = "HAXELIB_DB_NAME"
            value = "haxelib"
          }
          env {
            name  = "HAXELIB_DB_USER"
            value = var.HAXELIB_DB_USER
          }
          env {
            name = "HAXELIB_DB_PASS"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.haxelib-db.metadata[0].name
                key  = "HAXELIB_DB_PASS"
              }
            }
          }

          env {
            name  = "HAXELIB_CDN"
            value = "d1smpvufia21az.cloudfront.net"
          }

          env {
            name  = "HAXELIB_S3BUCKET"
            value = aws_s3_bucket.lib-haxe-org.bucket
          }

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
          env {
            name = "AWS_DEFAULT_REGION"
            value_from {
              secret_key_ref {
                name = "haxelib-server"
                key  = "AWS_DEFAULT_REGION"
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_pod_disruption_budget" "haxelib-server" {
  metadata {
    name = "haxelib-server"
  }
  spec {
    min_available = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "haxelib-server"
      }
    }
  }
}

resource "kubernetes_service" "haxelib-server" {
  metadata {
    name = "haxelib-server"
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "haxelib-server"
    }

    port {
      name     = "http"
      protocol = "TCP"
      port     = 80
    }
  }
}

resource "kubernetes_ingress" "haxelib-server" {
  metadata {
    name = "haxelib-server"
  }

  spec {
    rule {
      host = "lib-k8s.haxe.org"
      http {
        path {
          backend {
            service_name = kubernetes_service.haxelib-server.metadata[0].name
            service_port = 80
          }
          path = "/"
        }
      }
    }
  }
}

resource "aws_route53_record" "haxelib-server" {
  zone_id = "ZNT6UZLXKF3IS" # haxe.org
  name    = "lib-k8s"
  type    = "CNAME"
  ttl     = "30"
  records = ["k8s.haxe.org"]
}
