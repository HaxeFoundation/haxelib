resource "random_password" "rds-ghostferry-password" {
  length  = 32
  special = false
  lower   = true
  upper   = true
  number  = true
}

resource "mysql_user" "rds-ghostferry" {
  provider = mysql.rds

  user               = "ghostferry"
  host               = "%"
  plaintext_password = random_password.rds-ghostferry-password.result
  tls_option         = "SSL"
}

resource "mysql_grant" "rds-ghostferry-haxelib" {
  provider = mysql.rds

  user       = mysql_user.rds-ghostferry.user
  host       = mysql_user.rds-ghostferry.host
  database   = "haxelib"
  privileges = ["SELECT"]
}

resource "mysql_grant" "rds-ghostferry-replication" {
  provider = mysql.rds

  user       = mysql_user.rds-ghostferry.user
  host       = mysql_user.rds-ghostferry.host
  database   = "*"
  privileges = ["REPLICATION SLAVE", "REPLICATION CLIENT"]
}

resource "kubernetes_secret_v1" "ghostferry-copydb-config" {
  provider = kubernetes.do
  metadata {
    name = "ghostferry-copydb-config"
  }
  data = {
    "copy.json" = jsonencode({
      "Source" : {
        "Host" : aws_db_instance.haxe-org.address,
        "Port" : aws_db_instance.haxe-org.port,
        "User" : mysql_user.rds-ghostferry.user,
        "Pass" : random_password.rds-ghostferry-password.result,
        "Collation" : "utf8mb4_general_ci",
        "Params" : {
          "charset" : "utf8mb4",
        }
        "TLS" : {
          "CertPath" : "/ghostferry-copydb-config/rds-eu-west-1-bundle.pem",
          "ServerName" : "haxe-org.ct0xwjh6v08k.eu-west-1.rds.amazonaws.com",
        }
      },

      "Target" : {
        "Host" : "haxelib-mysql-80",
        "Port" : 6446,
        "User" : "root",
        "Pass" : random_password.haxelib-mysql-root-password.result,
        "Collation" : "utf8mb4_general_ci",
        "Params" : {
          "charset" : "utf8mb4"
        }
      },

      "CascadingPaginationColumnConfig" : {
        "FallbackColumn" : "id"
      },

      "Databases" : {
        "Whitelist" : ["haxelib"]
      },

      "VerifierType" : "ChecksumTable"
    })

    "rds-eu-west-1-bundle.pem" : file("../rds-eu-west-1-bundle.pem")
  }
}

resource "kubernetes_pod" "ghostferry-copydb-haxelib-mysql-80" {
  provider = kubernetes.do
  metadata {
    name = "ghostferry-copydb-haxelib-mysql-80"
    labels = {
      "app.kubernetes.io/name"     = "ghostferry-copydb"
      "app.kubernetes.io/instance" = "ghostferry-copydb-haxelib-mysql-80"
    }
  }
  spec {
    container {
      name  = "ghostferry-copydb"
      image = "haxe/ghostferry-copydb:ce94688"
      command = [
        "ghostferry-copydb",
        "-dryrun",
        "-verbose",
        "/ghostferry-copydb-config/copy.json",
      ]

      env {
        name  = "GODEBUG"
        value = "x509ignoreCN=0"
      }

      volume_mount {
        name       = "ghostferry-copydb-config"
        mount_path = "/ghostferry-copydb-config"
        read_only  = true
      }
    }

    volume {
      name = "ghostferry-copydb-config"
      secret {
        secret_name = kubernetes_secret_v1.ghostferry-copydb-config.metadata[0].name
      }
    }
    restart_policy = "Never"
  }
}


resource "kubernetes_service_v1" "ghostferry-copydb-haxelib-mysql-80" {
  provider = kubernetes.do
  metadata {
    name = "ghostferry-copydb-haxelib-mysql-80"
  }

  spec {
    selector = {
      "app.kubernetes.io/name"     = "ghostferry-copydb"
      "app.kubernetes.io/instance" = "ghostferry-copydb-haxelib-mysql-80"
    }

    port {
      name     = "http"
      protocol = "TCP"
      port     = 8000
    }
  }
}

resource "kubernetes_ingress_v1" "ghostferry-copydb-haxelib-mysql-80" {
  provider = kubernetes.do
  metadata {
    name = "ghostferry-copydb-haxelib-mysql-80"
    annotations = {
      "kubernetes.io/ingress.class"    = "nginx"
      "cert-manager.io/cluster-issuer" = "letsencrypt-production"
    }
  }

  spec {
    tls {
      hosts       = ["ghostferry-copydb-haxelib-mysql-80.haxe.org"]
      secret_name = "ghostferry-copydb-haxelib-mysql-80-tls"
    }
    rule {
      host = "ghostferry-copydb-haxelib-mysql-80.haxe.org"
      http {
        path {
          backend {
            service {
              name = kubernetes_service_v1.ghostferry-copydb-haxelib-mysql-80.metadata[0].name
              port {
                number = 8000
              }
            }
          }
          path = "/"
        }
      }
    }
  }
}

resource "aws_route53_record" "ghostferry-copydb-haxelib-mysql-80" {
  zone_id = local.haxe_org_zoneid
  name    = "ghostferry-copydb-haxelib-mysql-80.haxe.org"
  type    = "CNAME"
  ttl     = "60"
  records = ["do-k8s.haxe.org"]
}
