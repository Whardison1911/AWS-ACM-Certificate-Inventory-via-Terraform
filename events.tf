# -----------------------------------------------------------------------------
# File: events.tf
# Purpose: EventBridge schedule to trigger the ACM reporter Lambda
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "acm_reporter_schedule" {
  name                = "acm-inventory-reporter-schedule"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "acm_reporter_target" {
  rule      = aws_cloudwatch_event_rule.acm_reporter_schedule.name
  target_id = "acm-inventory-reporter"
  arn       = aws_lambda_function.acm_reporter.arn
}

resource "aws_lambda_permission" "allow_eventbridge_invoke" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.acm_reporter.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.acm_reporter_schedule.arn
}


