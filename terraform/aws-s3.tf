resource "aws_s3_bucket" "lib-haxe-org" {
  bucket = "lib.haxe.org"
}

resource "aws_s3_bucket_acl" "lib-haxe-org" {
  bucket = aws_s3_bucket.lib-haxe-org.bucket
  access_control_policy {
    grant {
      grantee {
        id   = data.aws_canonical_user_id.current.id
        type = "CanonicalUser"
      }
      permission = "FULL_CONTROL"
    }

    grant {
      grantee {
        id   = "c4c1ede66af53448b93c283ce9448c4ba468c9432aa01d700d3878632f77d2d0"
        type = "CanonicalUser"
      }
      permission = "FULL_CONTROL"
    }

    owner {
      id = data.aws_canonical_user_id.current.id
    }
  }
}

resource "aws_s3_bucket_website_configuration" "lib-haxe-org" {
  bucket = aws_s3_bucket.lib-haxe-org.bucket

  index_document {
    suffix = "index.html"
  }
}
