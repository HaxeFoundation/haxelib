locals {
  haxe_org_zoneid = "ZNT6UZLXKF3IS"
}

resource "aws_route53_record" "lib" {
  zone_id = local.haxe_org_zoneid
  name    = "lib.haxe.org"
  type    = "CNAME"
  ttl     = "86400"
  records = ["k8s.haxe.org"]
}

resource "aws_route53_record" "development-lib" {
  zone_id = local.haxe_org_zoneid
  name    = "development-lib.haxe.org"
  type    = "CNAME"
  ttl     = "86400"
  records = ["k8s.haxe.org"]
}

# Verify domain for the "haxelib" GitHub org
# https://github.com/haxelib/
resource "aws_route53_record" "_github-challenge-haxelib" {
  zone_id = local.haxe_org_zoneid
  name    = "_github-challenge-haxelib.lib.haxe.org"
  type    = "TXT"
  ttl     = "300"
  records = ["6ea186783d"]
}
