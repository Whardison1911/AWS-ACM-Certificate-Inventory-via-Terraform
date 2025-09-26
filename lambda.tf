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

# API Gateway for manual triggers
resource "aws_api_gateway_rest_api" "acm_reporter" {
  count       = var.enable_api_gateway ? 1 : 0
  name        = "acm-inventory-reporter-api"
  description = "API Gateway for manual ACM certificate inventory triggers"
}

resource "aws_api_gateway_resource" "trigger" {
  count       = var.enable_api_gateway ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.acm_reporter[0].id
  parent_id   = aws_api_gateway_rest_api.acm_reporter[0].root_resource_id
  path_part   = "trigger"
}

resource "aws_api_gateway_method" "post" {
  count         = var.enable_api_gateway ? 1 : 0
  rest_api_id   = aws_api_gateway_rest_api.acm_reporter[0].id
  resource_id   = aws_api_gateway_resource.trigger[0].id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  count       = var.enable_api_gateway ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.acm_reporter[0].id
  resource_id = aws_api_gateway_resource.trigger[0].id
  http_method = aws_api_gateway_method.post[0].http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.acm_reporter.invoke_arn
}

resource "aws_lambda_permission" "api_gateway" {
  count         = var.enable_api_gateway ? 1 : 0
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.acm_reporter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.acm_reporter[0].execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "acm_reporter" {
  count = var.enable_api_gateway ? 1 : 0
  depends_on = [
    aws_api_gateway_integration.lambda,
  ]

  rest_api_id = aws_api_gateway_rest_api.acm_reporter[0].id
}

resource "aws_api_gateway_stage" "acm_reporter" {
  count         = var.enable_api_gateway ? 1 : 0
  deployment_id = aws_api_gateway_deployment.acm_reporter[0].id
  rest_api_id   = aws_api_gateway_rest_api.acm_reporter[0].id
  stage_name    = "prod"
}


