resource "aws_dynamodb_table" "haxelib-terraform" {
  name           = "haxelib-terraform"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}