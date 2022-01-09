terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.45"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.16"
    }
    github = {
      source  = "integrations/github"
      version = "~> 4.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.4"
    }
    mysql = {
      source  = "winebarrel/mysql"
      version = "~> 1.10"
    }
  }
  backend "s3" {
    bucket         = "haxe-terraform"
    key            = "haxelib.tfstate"
    dynamodb_table = "haxe-terraform"
    # AWS_DEFAULT_REGION
    # AWS_ACCESS_KEY_ID
    # AWS_SECRET_ACCESS_KEY
  }
}

data "terraform_remote_state" "previous" {
  backend = "s3"

  config = {
    bucket         = "haxe-terraform"
    key            = "haxelib.tfstate"
    dynamodb_table = "haxe-terraform"
    # AWS_DEFAULT_REGION
    # AWS_ACCESS_KEY_ID
    # AWS_SECRET_ACCESS_KEY
  }
}

provider "aws" {
  # AWS_DEFAULT_REGION
  # AWS_ACCESS_KEY_ID
  # AWS_SECRET_ACCESS_KEY
  assume_role {
    role_arn = "arn:aws:iam::045355064871:role/haxe2021-haxelib-operator"
  }
}

data "aws_canonical_user_id" "current" {}

provider "digitalocean" {
  # DIGITALOCEAN_ACCESS_TOKEN
  # SPACES_ACCESS_KEY_ID
  # SPACES_SECRET_ACCESS_KEY
}

provider "kubernetes" {
  config_path = "${path.module}/kubeconfig_haxe2021"

  experiments {
    manifest_resource = true
  }
}

provider "mysql" {
  endpoint = aws_db_instance.haxe-org.endpoint
  username = var.HAXELIB_DB_USER
  password = var.HAXELIB_DB_PASS
}

provider "kubernetes" {
  alias = "do"

  config_path = "${path.module}/kubeconfig_do"
}
