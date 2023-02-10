locals {
  haxe_org_zoneid = "ZNT6UZLXKF3IS"
}

resource "aws_route53_record" "lib" {
  zone_id = local.haxe_org_zoneid
  name    = "lib.haxe.org"
  type    = "CNAME"
  ttl     = "1800"
  records = ["do-k8s.haxe.org"]
}

resource "aws_route53_record" "development-lib" {
  zone_id = local.haxe_org_zoneid
  name    = "development-lib.haxe.org"
  type    = "CNAME"
  ttl     = "1800"
  records = ["do-k8s.haxe.org"]
}

resource "aws_route53_record" "do-lib" {
  zone_id = local.haxe_org_zoneid
  name    = "do-lib.haxe.org"
  type    = "CNAME"
  ttl     = "86400"
  records = ["do-k8s.haxe.org"]
}

resource "aws_route53_record" "do-development-lib" {
  zone_id = local.haxe_org_zoneid
  name    = "do-development-lib.haxe.org"
  type    = "CNAME"
  ttl     = "86400"
  records = ["do-k8s.haxe.org"]
}
