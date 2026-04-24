# Terraform Provider Configuration
# AWS provider setup with region and default tags

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment below to use S3 backend for state management
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "chatapp/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region
}

# This is a placeholder for AWS provider version
output "aws_provider_version" {
  value       = "AWS Provider ~> 5.0"
  description = "AWS provider version being used"
}
