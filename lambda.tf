# -----------------------------------------------------------------------------
# File: lambda.tf
# Purpose: Package and deploy Lambda function for ACM inventory reporting
# -----------------------------------------------------------------------------

data "archive_file" "acm_reporter_zip" {
  type        = "zip"
  output_path = "${path.module}/build/acm_reporter.zip"
  source {
    content  = file("${path.module}/lambda/acm_reporter.py")
    filename = "acm_reporter.py"
  }
}

resource "aws_cloudwatch_log_group" "acm_reporter" {
  name              = "/aws/lambda/acm-inventory-reporter"
  retention_in_days = 30
}

resource "aws_lambda_function" "acm_reporter" {
  function_name = "acm-inventory-reporter"
  role          = aws_iam_role.acm_reporter.arn
  runtime       = "python3.12"
  handler       = "acm_reporter.handler"

  filename         = data.archive_file.acm_reporter_zip.output_path
  source_code_hash = data.archive_file.acm_reporter_zip.output_base64sha256

  timeout     = var.lambda_timeout_seconds
  memory_size = var.lambda_memory_mb

  environment {
    variables = {
      REPORTS_BUCKET_NAME = var.reports_bucket_name
      S3_PREFIX           = var.s3_prefix
      REPORT_FORMATS      = join(",", var.report_formats)
      SNS_TOPIC_ARN       = var.enable_email_summary ? aws_sns_topic.acm_reporter.arn : ""
    }
  }

  depends_on = [aws_cloudwatch_log_group.acm_reporter]
}


