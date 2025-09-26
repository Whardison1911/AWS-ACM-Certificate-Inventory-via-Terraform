# ACM Certificate Inventory Configuration
# Owner: ZTMF (CMS)

region = "us-east-1"

# Email notification settings
enable_email_summary = true
email_recipient      = "william.hardison2@cms.hhs.gov"

# S3 bucket for reports (update with your unique bucket name)
reports_bucket_name = "acm-inventory-reports-451245779631-20250125"

# Schedule for automated reports (monthly at 12:00 UTC on the 1st)
schedule_expression = "cron(0 12 1 * ? *)"

# Report formats
report_formats = ["json", "csv"]

# S3 prefix for uploaded reports
s3_prefix = "acm-inventory/"

# Lambda configuration
lambda_timeout_seconds = 60
lambda_memory_mb       = 256

# API Gateway for manual triggers
enable_api_gateway = true
