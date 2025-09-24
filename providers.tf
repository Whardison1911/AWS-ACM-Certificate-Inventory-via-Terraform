# -----------------------------------------------------------------------------
# File: providers.tf
# Purpose: Configure AWS provider, optional assume-role, and default tags.
# Owner: ZTMF (CMS)
# Notes:
#   - Requires Terraform >= 1.5 and AWS provider ~> 5.0
#   - Supports optional profile-based auth (var.profile) and STS assume role
#   - External ID supported via var.assume_role_external_id when assuming role
#   - Default tags applied to all managed resources (ManagedBy/Project/Region/AccountId)
#   - Uses data sources for current account/region for tagging/context
#   - Last updated: 2025-09-22
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

provider "aws" {
  region  = var.region
  profile = var.profile != "" ? var.profile : null

  dynamic "assume_role" {
    for_each = var.assume_role_arn == "" ? [] : [1]
    content {
      role_arn     = var.assume_role_arn
      session_name = "tf-acm-inventory"
      external_id  = var.assume_role_external_id
    }
  }

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Project   = "ACM-Inventory"
      Region    = var.region
      AccountId = data.aws_caller_identity.current.account_id
    }
  }
}
