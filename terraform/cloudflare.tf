locals {
  cloudflare = {
    account_id = "09c8df40903546d43dba5a1924ee4b43"
    zones = {
      haxe-org = {
        zone_id = "01d9191b31046d86b5d7ba8f44c89b7c"
      }
    }
  }
}

resource "cloudflare_record" "lib-haxe-org" {
  zone_id = local.cloudflare.zones.haxe-org.zone_id
  name    = "lib"
  type    = "CNAME"
  ttl     = "1800"
  value   = "do-k8s.haxe.org"
}

resource "cloudflare_record" "development-lib" {
  zone_id = local.cloudflare.zones.haxe-org.zone_id
  name    = "development-lib"
  type    = "CNAME"
  ttl     = "1800"
  value   = "do-k8s.haxe.org"
}

resource "cloudflare_record" "do-lib" {
  zone_id = local.cloudflare.zones.haxe-org.zone_id
  name    = "do-lib"
  type    = "CNAME"
  ttl     = "86400"
  value   = "do-k8s.haxe.org"
}

resource "cloudflare_record" "do-development-lib" {
  zone_id = local.cloudflare.zones.haxe-org.zone_id
  name    = "do-development-lib"
  type    = "CNAME"
  ttl     = "86400"
  value   = "do-k8s.haxe.org"
}
