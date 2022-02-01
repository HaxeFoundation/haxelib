resource "random_password" "haxelib-mysql-root-password" {
  length  = 32
  special = false
  lower   = true
  upper   = true
  number  = true
}

resource "kubernetes_secret_v1" "haxelib-mysql-80-root" {
  provider = kubernetes.do
  metadata {
    name = "haxelib-mysql-80-root"
  }
  data = {
    "rootUser"     = "root"
    "rootHost"     = "%"
    "rootPassword" = random_password.haxelib-mysql-root-password.result
  }
}

resource "kubernetes_manifest" "haxelib-mysql-80" {
  provider = kubernetes.do
  manifest = {
    "apiVersion" = "mysql.oracle.com/v2alpha1"
    "kind"       = "InnoDBCluster"
    "metadata" = {
      "name"      = "haxelib-mysql-80"
      "namespace" = "default"
    }
    "spec" = {
      "secretName" = kubernetes_secret_v1.haxelib-mysql-80-root.metadata[0].name
      "instances"  = 3
      "router" = {
        "instances" : 1
      }
    }
  }
}

resource "random_password" "haxelib-mysql-57-root-password" {
  length  = 10
  special = false
  lower   = true
  upper   = true
  number  = true
}

resource "random_password" "haxelib-mysql-57-haxelib-password" {
  length  = 10
  special = false
  lower   = true
  upper   = true
  number  = true
}

resource "random_password" "haxelib-mysql-57-replicator-password" {
  length  = 10
  special = false
  lower   = true
  upper   = true
  number  = true
}

data "kubernetes_secret_v1" "haxelib-mysql-57" {
  provider = kubernetes.do
  metadata {
    name = "haxelib-mysql-57"
  }

  depends_on = [
    helm_release.haxelib-mysql-57
  ]
}

resource "helm_release" "haxelib-mysql-57" {
  provider = helm.do

  name       = "haxelib-mysql-57"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "mysql"

  values = [
    yamlencode({
      "image" : {
        "tag" : "5.7.37-debian-10-r12"
      },
      "auth" : {
        "database" : "haxelib",
        "username" : "haxelib",
      },
      "architecture" : "replication",
      "primary" : {
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
      }
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
