module "s3_bucket_terraform" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "2.4.0"

  bucket = "haxelib-terraform"
  acl    = "private"

  versioning = {
    enabled = true
  }
}

resource "aws_s3_bucket" "lib-haxe-org" {
  bucket = "lib.haxe.org"

  grant {
    id = data.aws_canonical_user_id.current.id
    permissions = [
      "READ",
      "READ_ACP",
      "WRITE",
      "WRITE_ACP"
    ]
    type = "CanonicalUser"
  }
  grant {
    id = "c4c1ede66af53448b93c283ce9448c4ba468c9432aa01d700d3878632f77d2d0"
    permissions = [
      "FULL_CONTROL",
    ]
    type = "CanonicalUser"
  }

  website {
    index_document = "index.html"
  }
}
