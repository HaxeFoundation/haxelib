locals {
  haxe_org_zoneid = "ZNT6UZLXKF3IS"
}

resource "aws_route53_record" "lib" {
  zone_id = local.haxe_org_zoneid
  name    = "lib.haxe.org"
  type    = "CNAME"
  ttl     = "30"
  records = ["k8s.haxe.org"]
}

resource "aws_route53_record" "master-lib" {
  for_each = toset(["A", "AAAA"])

  zone_id = local.haxe_org_zoneid
  name    = "master-lib.haxe.org"
  type    = each.key
  alias {
    name                   = aws_elastic_beanstalk_environment.master-lib-haxe-org.cname
    zone_id                = data.aws_elastic_beanstalk_hosted_zone.current.id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "development-lib" {
  for_each = toset(["A", "AAAA"])

  zone_id = local.haxe_org_zoneid
  name    = "development-lib.haxe.org"
  type    = each.key
  alias {
    name                   = aws_elastic_beanstalk_environment.development-lib-haxe-org.cname
    zone_id                = data.aws_elastic_beanstalk_hosted_zone.current.id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "staging-lib" {
  for_each = toset(["A", "AAAA"])

  zone_id = local.haxe_org_zoneid
  name    = "staging-lib.haxe.org"
  type    = each.key
  alias {
    name                   = aws_elastic_beanstalk_environment.development-lib-haxe-org.cname
    zone_id                = data.aws_elastic_beanstalk_hosted_zone.current.id
    evaluate_target_health = false
  }
}
