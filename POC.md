# Proof of Concept: ACM Inventory with Automated Reporting

This PoC demonstrates end-to-end deployment of the Terraform stack, scheduled Lambda inventory, S3 report exports, and optional email summary via SNS.

## Prerequisites
- Terraform >= 1.5
- AWS CLI credentials with permissions to create IAM, S3, SNS, Lambda, EventBridge, and to read ACM
- jq (optional, for pretty-printing JSON outputs)

## 1) Configure Variables
Create a `terraform.tfvars` (or copy `terraform.tfvars.example`). Replace values as needed.

```
region                 = "us-east-1"
# profile              = "my-aws-profile"             # optional
# assume_role_arn      = "arn:aws:iam::123:role/Role" # optional
# assume_role_external_id = "example"                 # optional

reports_bucket_name    = "my-acm-inventory-reports-<unique>"
schedule_expression    = "cron(0 12 * * ? *)"  # daily at 12:00 UTC
report_formats         = ["json", "csv"]
s3_prefix              = "acm-inventory/"
lambda_timeout_seconds = 60
lambda_memory_mb       = 256

enable_email_summary   = false                 # set true to enable email
email_recipient        = "me@example.com"      # required if enabled
```

## 2) Deploy
```
terraform init
terraform apply -auto-approve
```

Outputs include the reports bucket name, lambda function name, and SNS topic ARN (if created).

## 3) Validate Terraform-Only Inventory (Immediate)
You can immediately query the Terraform data-source based inventory:
```
terraform output acm_inventory_summary
terraform output -json acm_certificate_inventory | jq '.[0:3]'
terraform output -json acm_expiring_within_30_days | jq
terraform output acm_public_vs_private_counts
terraform output acm_aws_vs_customer_counts
```

## 4) Trigger Lambda On-Demand
Generate reports right away without waiting for the schedule. Use the AWS Console to test, or CLI:
```
aws lambda invoke \
  --function-name acm-inventory-reporter \
  --payload '{}' \
  /tmp/acm-report-out.json && cat /tmp/acm-report-out.json | jq
```
Expect a JSON response with totals and S3 keys for uploaded artifacts.

## 5) Verify Artifacts in S3
List the uploaded objects:
```
aws s3 ls s3://$(terraform output -raw reports_bucket_name)/acm-inventory/
```
You should see files like:
- acm-inventory-<account>-<region>-<timestamp>.json
- acm-inventory-<account>-<region>-<timestamp>.csv

## 6) (Optional) Confirm Email
If `enable_email_summary = true`, check your email and confirm the SNS subscription. You will then receive an email each time the Lambda runs on schedule.

## 7) Cleanup
```
terraform destroy -auto-approve
```
If the S3 bucket contains objects, Terraform may fail on destroy. Empty the bucket and retry:
```
aws s3 rm s3://$(terraform output -raw reports_bucket_name) --recursive
terraform destroy -auto-approve
```

## Notes
- Lambda environment variables control bucket, prefix, formats, and SNS topic.
- IAM policy grants least-privilege for logs, ACM read, S3 writes, and optional SNS publish.
- EventBridge rule triggers the Lambda based on `schedule_expression`.
