terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.45"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 2.21"
    }
    github = {
      source  = "integrations/github"
      version = "~> 4.11"
    }
  }
  backend "s3" {
    bucket         = "haxelib-terraform"
    key            = "haxelib.tfstate"
    dynamodb_table = "haxelib-terraform"
    # AWS_DEFAULT_REGION
    # AWS_ACCESS_KEY_ID
    # AWS_SECRET_ACCESS_KEY
  }
}

provider "aws" {
  # AWS_DEFAULT_REGION
  # AWS_ACCESS_KEY_ID
  # AWS_SECRET_ACCESS_KEY
}

data "aws_canonical_user_id" "current" {}
