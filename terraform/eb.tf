data "aws_elastic_beanstalk_application" "lib-haxe-org" {
  name = "lib.haxe.org"
}

resource "aws_elastic_beanstalk_environment" "development-lib-haxe-org" {
  name        = "development-lib-haxe-org"
  application = data.aws_elastic_beanstalk_application.lib-haxe-org.name
}

resource "aws_elastic_beanstalk_environment" "master-lib-haxe-org" {
  name        = "master-lib-haxe-org"
  application = data.aws_elastic_beanstalk_application.lib-haxe-org.name
}

data "aws_elastic_beanstalk_hosted_zone" "current" {}
