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

# -----------------------------------------------------------------------------
# Reporting/Automation variables
# -----------------------------------------------------------------------------

variable "reports_bucket_name" {
  type        = string
  description = "S3 bucket name to upload ACM reports to (will be created if not existing)."
}

variable "enable_email_summary" {
  type        = bool
  default     = false
  description = "Whether to send a summary email via SNS."
}

variable "email_recipient" {
  type        = string
  default     = ""
  description = "Email address to subscribe to SNS for summaries (required if enable_email_summary)."
}

variable "schedule_expression" {
  type        = string
  default     = "cron(0 12 * * ? *)" # every day at 12:00 UTC
  description = "EventBridge schedule expression for the Lambda."
}

variable "report_formats" {
  type        = list(string)
  default     = ["json", "csv"]
  description = "Report formats to generate and upload to S3. Supported: json, csv."
}

variable "s3_prefix" {
  type        = string
  default     = "acm-inventory/"
  description = "S3 key prefix for uploaded reports."
}

variable "lambda_timeout_seconds" {
  type        = number
  default     = 60
  description = "Lambda timeout in seconds."
}

variable "lambda_memory_mb" {
  type        = number
  default     = 256
  description = "Lambda memory in MB."
}