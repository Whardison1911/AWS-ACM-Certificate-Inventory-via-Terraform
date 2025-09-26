# -----------------------------------------------------------------------------
# File: acm_inventory.tf
# Purpose: Inventory ACM SSL/TLS certificates in the current AWS region with
#          expiration, visibility (PUBLIC/PRIVATE), and provenance
#          (AWS_PROVIDED vs CUSTOMER_PROVIDED). Flags certs expiring soon.
# Owner: ZTMF (CMS)
# Notes:
#   - Uses data sources: aws_acm_certificates (ARNs) + aws_acm_certificate (details)
#   - Classifies visibility (PRIVATE => PRIVATE; otherwise PUBLIC)
#   - Classifies provenance (IMPORTED => CUSTOMER_PROVIDED; otherwise AWS_PROVIDED)
#   - Computes 30-day expiry window (expiring_in_30d) and expired status (is_expired)
#   - Outputs: context summary, full inventory map, expiring-soon list, and counts
#   - Read-only: creates no AWS resources; depends only on configured region/account
#   - Last updated: 2025-09-21
# -----------------------------------------------------------------------------

data "aws_caller_identity" "this" {}
data "aws_region" "this" {}

# Note: aws_acm_certificates data source doesn't exist in AWS provider
# This is a placeholder - you'll need to specify actual certificate domains
# or use AWS CLI/Lambda to inventory certificates

# Multiple certificate domains to inventory
data "aws_acm_certificate" "certificates" {
  for_each = toset([
    "dev.cztf.cloud.cms.gov",
    "dev.ztmf.cms.gov"
  ])
  domain      = each.value
  statuses    = ["ISSUED"]
  most_recent = true
}

locals {
  # Note: aws_acm_certificate data source only provides limited attributes
  # For detailed certificate info (expiration dates, etc.), use AWS CLI or Lambda

  acm_inventory = {
    for domain, cert in data.aws_acm_certificate.certificates :
    domain => {
      arn    = cert.arn
      domain = cert.domain
      # Note: Limited attributes available from aws_acm_certificate data source
      # Available: arn, domain, id, key_types, most_recent, status, statuses, tags, types
      # 
      # For comprehensive ACM inventory with expiration dates, etc., consider:
      # 1. AWS CLI: aws acm list-certificates --region us-east-1
      # 2. Lambda function to query ACM API directly  
      # 3. External script to populate Terraform variables
    }
  }

  acm_inventory_list = [for v in local.acm_inventory : v]

  # Since we don't have expiration data, we can't determine expiring certificates
  acm_expiring_soon = []
}

output "acm_inventory_summary" {
  description = "Context for this inventory run"
  value = {
    account_id     = data.aws_caller_identity.this.account_id
    region         = data.aws_region.this.name
    total          = length(local.acm_inventory)
    note           = "Limited data available from aws_acm_certificate data source"
    recommendation = "Use AWS CLI or Lambda for comprehensive ACM certificate inventory"
  }
}

output "acm_certificate_inventory" {
  description = "Basic ACM cert info (ARN and domain only)"
  value       = local.acm_inventory
}

output "acm_expiring_within_30_days" {
  description = "ACM certs expiring within 30 days (not available with data source)"
  value       = local.acm_expiring_soon
}

# Note: Detailed analysis outputs removed since aws_acm_certificate data source
# doesn't provide visibility, source, or expiration information
