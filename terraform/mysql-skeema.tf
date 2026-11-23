# A read-only MySQL user for `skeema diff` in CI (see ../skeema/ and ../.github/workflows/).
#
# Skeema's default workspace (temp-schema) runs the CREATE TABLE statements from the .sql files
# in a temporary schema on the same server, so this user also gets full privileges on that schema only.
# It has SELECT and nothing else on the haxelib schema.
# https://www.skeema.io/docs/requirements/#privileges
#
# The user is created by a k8s Job instead of the mysql provider,
# because the MySQL server is reachable only from inside the cluster.

locals {
  # Do not change it. The job below doesn't drop the user of an old name.
  haxelib-mysql-57-skeema-user = "skeema"
}

resource "random_password" "haxelib-mysql-57-skeema-password" {
  length  = 32
  special = false
  lower   = true
  upper   = true
  numeric = true
}

resource "kubernetes_secret_v1" "haxelib-mysql-57-skeema" {
  metadata {
    name = "haxelib-mysql-57-skeema"
  }

  data = {
    username = local.haxelib-mysql-57-skeema-user
    password = random_password.haxelib-mysql-57-skeema-password.result
  }
}

resource "kubernetes_job_v1" "haxelib-mysql-57-skeema-user" {
  metadata {
    name = "haxelib-mysql-57-skeema-user"
  }

  spec {
    backoff_limit = 2
    template {
      metadata {
        name = "haxelib-mysql-57-skeema-user"
      }
      spec {
        restart_policy = "Never"
        container {
          name  = "mysql"
          image = "mysql:5.7.40"
          # `_` is a wildcard in database names of GRANT statements, so it is escaped.
          # The backticks are escaped for bash.
          args = [
            "bash", "-c", <<-EOF
              set -eo pipefail
              mysql -h haxelib-mysql-57-primary -P 3306 -u root <<SQL
              CREATE USER IF NOT EXISTS '${local.haxelib-mysql-57-skeema-user}'@'%' IDENTIFIED BY '$SKEEMA_PASSWORD';
              ALTER USER '${local.haxelib-mysql-57-skeema-user}'@'%' IDENTIFIED BY '$SKEEMA_PASSWORD';
              GRANT SELECT ON haxelib.* TO '${local.haxelib-mysql-57-skeema-user}'@'%';
              GRANT ALL PRIVILEGES ON \`\_skeema\_tmp\`.* TO '${local.haxelib-mysql-57-skeema-user}'@'%';
              SQL
            EOF
          ]

          resources {
            requests = {
              cpu = "50m"
              memory = "16Mi"
            }
            limits = {
              memory = "64Mi"
            }
          }

          env {
            name = "MYSQL_PWD"
            value_from {
              secret_key_ref {
                name = data.kubernetes_secret_v1.haxelib-mysql-57.metadata[0].name
                key  = "mysql-root-password"
              }
            }
          }
          env {
            name = "SKEEMA_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.haxelib-mysql-57-skeema.metadata[0].name
                key  = "password"
              }
            }
          }
        }
      }
    }
  }

  wait_for_completion = true
  timeouts {
    create = "5m"
    update = "5m"
  }

  lifecycle {
    # Re-run the job when the password changes.
    replace_triggered_by = [
      random_password.haxelib-mysql-57-skeema-password,
    ]
  }
}
