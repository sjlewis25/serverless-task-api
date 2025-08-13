terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }

  backend "s3" {
    bucket         = var.tf_state_bucket
    key            = "${var.project}/${var.environment}.tfstate"
    region         = var.region
    dynamodb_table = var.tf_lock_table
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      Owner       = var.owner
    }
  }
}
