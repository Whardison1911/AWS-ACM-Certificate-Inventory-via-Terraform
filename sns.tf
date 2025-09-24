# -----------------------------------------------------------------------------
# File: sns.tf
# Purpose: SNS topic and optional email subscription for ACM inventory summary
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "acm_reporter" {
  name = "acm-inventory-reporter"
}

resource "aws_sns_topic_subscription" "email" {
  count = var.enable_email_summary && var.email_recipient != "" ? 1 : 0

  topic_arn = aws_sns_topic.acm_reporter.arn
  protocol  = "email"
  endpoint  = var.email_recipient
}


