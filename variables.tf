# -----------------------------------------------------------------------------
# File: variables.tf
# Purpose: Input variables for region/profile and optional assume role.
# Owner: ZTMF (CMS)
# Notes:
#   - region is required; profile, assume_role_arn, and external_id are optional
#   - Use profile for local dev; use assume_role_* for cross-account inventory
#   - Compatible with providers.tf default tagging and assume-role logic
#   - Last updated: 2025-09-22
# -----------------------------------------------------------------------------

variable "region" {
  type        = string
  description = "AWS region to inventory (e.g., us-east-1)"
}

variable "profile" {
  type        = string
  default     = ""
  description = "AWS named profile (optional)"
}

variable "assume_role_arn" {
  type        = string
  default     = ""
  description = "Role ARN to assume for cross-account (optional)"
}

variable "assume_role_external_id" {
  type        = string
  default     = ""
  description = "External ID for assume role (optional)"
}
