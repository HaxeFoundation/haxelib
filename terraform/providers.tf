terraform {
  required_version = ">= 1.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.34"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.17"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.20"
    }
    github = {
      source  = "integrations/github"
      version = "~> 4.26"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.11"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.5"
    }
    mysql = {
      source  = "winebarrel/mysql"
      version = "~> 1.10"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.3"
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

provider "kubernetes" {
  alias = "do"

  config_path = "${path.module}/kubeconfig_do"
}


provider "helm" {
  alias = "do"

  kubernetes {
    config_path = "${path.module}/kubeconfig_do"
  }
}

provider "cloudflare" {
  api_token = data.aws_ssm_parameter.cloudflare_api_token.value
}
