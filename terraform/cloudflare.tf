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

# Let web pages read the library files (Access-Control-Allow-Origin: *), so tools that run
# in a browser (a Haxe compiler in a page, playgrounds, documentation sites) can download
# libraries straight from haxelib. The files are public and need no credentials; the
# header only lets pages read what anyone can already download, and `*` excludes
# requests that carry cookies or credentials.
resource "cloudflare_ruleset" "haxe-org-response-headers" {
  zone_id     = local.cloudflare.zones.haxe-org.zone_id
  name        = "Response headers"
  description = "Response header transform rules for the haxe.org zone"
  kind        = "zone"
  phase       = "http_response_headers_transform"

  rules {
    description = "haxelib files: readable by web pages (CORS)"
    expression  = "(http.host eq \"${local.r2.domain_access}\")"
    action      = "rewrite"
    action_parameters {
      headers {
        name      = "Access-Control-Allow-Origin"
        operation = "set"
        value     = "*"
      }
    }
    enabled = true
  }
}
