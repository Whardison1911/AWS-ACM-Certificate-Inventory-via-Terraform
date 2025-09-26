# -----------------------------------------------------------------------------
# File: outputs.tf
# Purpose: Outputs for created resources
# -----------------------------------------------------------------------------

output "reports_bucket_name" {
  description = "S3 bucket for ACM reports"
  value       = aws_s3_bucket.reports.bucket
}

output "acm_reporter_lambda_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.acm_reporter.function_name
}

output "acm_reporter_sns_topic_arn" {
  description = "SNS topic ARN for email summaries"
  value       = aws_sns_topic.acm_reporter.arn
}

output "acm_reporter_api_url" {
  description = "API Gateway URL for manual triggers"
  value       = var.enable_api_gateway ? "${aws_api_gateway_stage.acm_reporter[0].invoke_url}/trigger" : null
}


