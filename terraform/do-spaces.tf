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
}
