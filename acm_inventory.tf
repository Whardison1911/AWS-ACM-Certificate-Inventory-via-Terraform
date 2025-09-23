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

data "aws_acm_certificates" "all" {
  types = ["AMAZON_ISSUED", "IMPORTED", "PRIVATE"]
  # statuses = ["ISSUED"]
}

data "aws_acm_certificate" "details" {
  for_each = toset(data.aws_acm_certificates.all.arns)
  arn      = each.value
}

locals {
  now        = timestamp()
  in_30_days = timeadd(timestamp(), "720h") # 30 days

  acm_inventory = {
    for arn, cert in data.aws_acm_certificate.details :
    arn => {
      arn               = arn
      domain_name       = cert.domain_name
      subject_alt_names = cert.subject_alternative_names
      status            = cert.status
      not_before        = cert.not_before
      not_after         = cert.not_after
      in_use_by         = cert.in_use_by
      issuer            = try(cert.issuer, null)
      key_algorithm     = try(cert.key_algorithm, null)
      acm_type          = cert.type
      visibility        = cert.type == "PRIVATE" ? "PRIVATE" : "PUBLIC"
      source            = cert.type == "IMPORTED" ? "CUSTOMER_PROVIDED" : "AWS_PROVIDED"
      expiring_in_30d   = can(timecmp(cert.not_after, local.in_30_days)) ? (timecmp(cert.not_after, local.in_30_days) <= 0) : false
      is_expired        = can(timecmp(cert.not_after, local.now)) ? (timecmp(cert.not_after, local.now) < 0) : false
    }
  }

  acm_inventory_list = [for v in local.acm_inventory : v]

  acm_expiring_soon = [
    for v in local.acm_inventory_list : v
    if v.expiring_in_30d && !v.is_expired
  ]
}

output "acm_inventory_summary" {
  description = "Context for this inventory run"
  value = {
    account_id = data.aws_caller_identity.this.account_id
    region     = data.aws_region.this.name
    total      = length(local.acm_inventory)
    expiring_within_30_days = length(local.acm_expiring_soon)
  }
}

output "acm_certificate_inventory" {
  description = "All ACM certs with details (keyed by ARN)"
  value       = local.acm_inventory
}

output "acm_expiring_within_30_days" {
  description = "ACM certs expiring within 30 days (list)"
  value       = local.acm_expiring_soon
}

output "acm_public_vs_private_counts" {
  description = "Counts of PUBLIC vs PRIVATE"
  value = {
    PUBLIC  = length([for v in local.acm_inventory_list : 1 if v.visibility == "PUBLIC"])
    PRIVATE = length([for v in local.acm_inventory_list : 1 if v.visibility == "PRIVATE"])
  }
}

output "acm_aws_vs_customer_counts" {
  description = "Counts of AWS_PROVIDED vs CUSTOMER_PROVIDED"
  value = {
    AWS_PROVIDED      = length([for v in local.acm_inventory_list : 1 if v.source == "AWS_PROVIDED"])
    CUSTOMER_PROVIDED = length([for v in local.acm_inventory_list : 1 if v.source == "CUSTOMER_PROVIDED"])
  }
}
