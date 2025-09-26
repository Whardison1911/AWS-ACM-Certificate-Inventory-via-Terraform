# -----------------------------------------------------------------------------
# File: iam.tf
# Purpose: IAM role and policies for Lambda ACM inventory reporter
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "acm_reporter" {
  name               = "acm-inventory-reporter-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "acm_reporter" {
  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }

  statement {
    sid    = "ReadACM"
    effect = "Allow"
    actions = [
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "acm:ListTagsForCertificate",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "WriteS3"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:AbortMultipartUpload",
      "s3:ListBucketMultipartUploads",
    ]
    resources = [
      "arn:aws:s3:::${var.reports_bucket_name}",
      "arn:aws:s3:::${var.reports_bucket_name}/*",
    ]
  }

  statement {
    sid    = "PublishSNS"
    effect = "Allow"
    actions = [
      "sns:Publish"
    ]
    resources = [
      aws_sns_topic.acm_reporter.arn
    ]
    condition {
      test     = "Bool"
      variable = "aws:ResourceTag/ManagedBy"
      values   = ["Terraform"]
    }
  }
}

resource "aws_iam_policy" "acm_reporter" {
  name   = "acm-inventory-reporter-policy"
  policy = data.aws_iam_policy_document.acm_reporter.json
}

resource "aws_iam_role_policy_attachment" "acm_reporter_attach" {
  role       = aws_iam_role.acm_reporter.name
  policy_arn = aws_iam_policy.acm_reporter.arn
}


