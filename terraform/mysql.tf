resource "random_password" "haxelib-mysql-root-password" {
  length  = 64
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
