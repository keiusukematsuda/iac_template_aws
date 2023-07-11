#------------------------------
# terraform configuration
#------------------------------
terraform {
  # バックエンド:S3の場合
  backend "s3" {
    bucket = "iac-bucket-tfstate"
    key    = "dev/main/terraform.tfstate"
    region = var.aws_region
  }

  # バックエンド:ローカルの場合
  # backend "local" {
  #   path = "terraform.tfstate"
  # }

  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "dev"
      Project     = "iac"
      ManagedBy   = "terraform"
    }
  }
}