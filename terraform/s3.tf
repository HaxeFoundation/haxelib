module "s3_bucket_terraform" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "2.4.0"

  bucket = "haxelib-terraform"
  acl    = "private"

  versioning = {
    enabled = true
  }
}