resource "random_password" "haxelib-mysql-57-root-password" {
  length  = 10
  special = false
  lower   = true
  upper   = true
  numeric = true
}

resource "random_password" "haxelib-mysql-57-haxelib-password" {
  length  = 10
  special = false
  lower   = true
  upper   = true
  numeric = true
}

resource "random_password" "haxelib-mysql-57-replicator-password" {
  length  = 10
  special = false
  lower   = true
  upper   = true
  numeric = true
}

data "kubernetes_secret_v1" "haxelib-mysql-57" {
  metadata {
    name = "haxelib-mysql-57"
  }

  depends_on = [
    helm_release.haxelib-mysql-57
  ]
}

# https://github.com/bitnami/charts/tree/mysql/8.8.23/bitnami/mysql
resource "helm_release" "haxelib-mysql-57" {
  name       = "haxelib-mysql-57"
  repository = "./bitnami"
  chart      = "mysql"
  version    = "8.8.23"

  values = [
    yamlencode({
      # "global" : {
      #   "imagePullSecrets" : [
      #     local.imagePullSecrets
      #   ]
      # },
      "image" : {
        "repository" : "bitnamilegacy/mysql",
        "tag" : "5.7.43-debian-11-r73"
      },
      "auth" : {
        "database" : "haxelib",
        "username" : "haxelib",
      },
      "architecture" : "replication",
      "primary" : {
        "resources" : {
          "requests" : {
            "memory" : "768Mi",
          },
          "limits" : {
            "memory" : "1Gi",
          },
        },
        # Use a TCP probe instead of the chart's exec probe. An exec probe cannot run in a
        # stopped container, which kubelet treats as "unknown" rather than a failure, so it
        # never restarts a dead mysqld.
        "livenessProbe" : {
          "enabled" : false,
        },
        "customLivenessProbe" : {
          "tcpSocket" : {
            "port" : "mysql",
          },
          "initialDelaySeconds" : 5,
          "periodSeconds" : 10,
          "timeoutSeconds" : 5,
          "failureThreshold" : 3,
        },
        "command" : [
          "/bin/bash", "-ec",
          "ulimit -n 65536 && exec /opt/bitnami/scripts/mysql/entrypoint.sh /opt/bitnami/scripts/mysql/run.sh",
        ],
        "configuration" : <<-EOT
          [mysqld]
          default_authentication_plugin=mysql_native_password
          skip-name-resolve
          explicit_defaults_for_timestamp
          basedir=/opt/bitnami/mysql
          plugin_dir=/opt/bitnami/mysql/lib/plugin
          port=3306
          socket=/opt/bitnami/mysql/tmp/mysql.sock
          datadir=/bitnami/mysql/data
          tmpdir=/opt/bitnami/mysql/tmp
          max_allowed_packet=16M
          bind-address=0.0.0.0
          binlog_format=ROW
          binlog_row_image=FULL
          binlog_rows_query_log_events=1
          expire_logs_days=1
          pid-file=/opt/bitnami/mysql/tmp/mysqld.pid
          log-error=/opt/bitnami/mysql/logs/mysqld.log
          character-set-server=UTF8
          collation-server=utf8_general_ci
          gtid-mode=ON
          enforce_gtid_consistency=ON

          [client]
          port=3306
          socket=/opt/bitnami/mysql/tmp/mysql.sock
          default-character-set=UTF8
          plugin_dir=/opt/bitnami/mysql/lib/plugin

          [manager]
          port=3306
          socket=/opt/bitnami/mysql/tmp/mysql.sock
          pid-file=/opt/bitnami/mysql/tmp/mysqld.pid
        EOT
      }
      "secondary" : {
        "replicaCount" : 0,
      },
    }),
  ]

  set {
    name  = "auth.rootPassword"
    value = random_password.haxelib-mysql-57-root-password.result
  }
  set {
    name  = "auth.password"
    value = random_password.haxelib-mysql-57-haxelib-password.result
  }
  set {
    name  = "auth.replicationPassword"
    value = random_password.haxelib-mysql-57-replicator-password.result
  }
}

# Only the pods that use the database can connect to it.
# Not affected: kubelet probes (Cilium allows traffic from the local node),
# and `kubectl port-forward` (e.g. skeema diff in CI), which connects from inside the pod.
resource "kubernetes_network_policy_v1" "haxelib-mysql-57" {
  metadata {
    name = "haxelib-mysql-57"
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name"     = "mysql"
        "app.kubernetes.io/instance" = "haxelib-mysql-57"
      }
    }
    policy_types = ["Ingress"]

    ingress {
      # haxelib-server (web, api, files; dev and prod)
      from {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "haxelib-server"
          }
        }
      }
      # kubernetes_cron_job_v1.mysqldump (mysqldump.tf)
      from {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "mysqldump"
          }
        }
      }
      # kubernetes_job_v1.haxelib-mysql-57-skeema-user (mysql-skeema.tf). The label is set by Kubernetes.
      from {
        pod_selector {
          match_labels = {
            "batch.kubernetes.io/job-name" = "haxelib-mysql-57-skeema-user"
          }
        }
      }
      # Replication, in case secondaries are added.
      from {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name"     = "mysql"
            "app.kubernetes.io/instance" = "haxelib-mysql-57"
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = "3306"
      }
    }
  }
}

output "mysql-root-password" {
  value = random_password.haxelib-mysql-57-root-password.result

  sensitive = true
}
