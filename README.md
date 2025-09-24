# Terraform ACM Inventory Repository

## 📋 Overview
This educational repository provides Terraform configurations to **inventory AWS Certificate Manager (ACM) SSL/TLS certificates** in an AWS account/region. It reports **expiration dates**, whether certificates are **PUBLIC vs PRIVATE**, and whether they are **AWS-provided vs customer-provided**. It also highlights certificates **expiring within 30 days** so you can act before outages occur.

## Key Features
- 🧾 **Full Inventory:** Lists all ACM certificates in-region with key attributes (domain(s), status, issuer, algorithms, usage).
- ⏳ **Expiry Awareness:** Flags certificates expiring within 30 days and those already expired.
- 🌍 **Public vs Private:** Classifies visibility using ACM type (PRIVATE → private; otherwise public).
- 🏷️ **Provenance:** Distinguishes **AWS_PROVIDED** (AMAZON_ISSUED/PRIVATE) vs **CUSTOMER_PROVIDED** (IMPORTED).
- ⚙️ **Simple Inputs:** Minimal variables for region/profile and optional cross-account assume-role.
- 🔁 **Portable:** Run per region; extendable to multi-region via provider aliases.
- 📨 **Automated Reporting (optional):** Scheduled Lambda exports JSON/CSV to S3 and can email a summary via SNS.

## 🏗️ Repository Structure

```
├── acm_inventory.tf    # Data sources & outputs that build the certificate inventory
├── providers.tf        # AWS + archive providers, tagging, optional assume-role
├── variables.tf        # Inputs for region/profile/assume-role + reporting settings
├── iam.tf              # IAM role/policy for Lambda (logs, ACM read, S3 put, SNS publish)
├── s3.tf               # S3 bucket for report artifacts (encrypted, versioned, private)
├── sns.tf              # SNS topic and optional email subscription for summaries
├── lambda.tf           # Lambda function packaging (archive_file) and deployment
├── events.tf           # EventBridge schedule and permission to invoke Lambda
├── outputs.tf          # Useful outputs (bucket, lambda, sns)
└── lambda/
    └── acm_reporter.py # Python Lambda that inventories ACM and writes reports
```

## 🚀 Quick Start

1. **Clone the repository**:

```
git clone https://github.com/Whardison1911/AWS-ACM-Certificate-Inventory-via-Terraform.git
cd terraform-acm-inventory
```

2. **Provide configuration (create terraform.tfvars)**:

``` 
region = "us-east-1"
# Optional settings
# profile                 = "my-aws-profile"
# assume_role_arn         = "arn:aws:iam::123456789012:role/OrgAuditRole"
# assume_role_external_id = "my-external-id"

# Automated reporting (Lambda → S3, optional SNS email)
reports_bucket_name    = "my-acm-inventory-reports"
schedule_expression    = "cron(0 12 * * ? *)"  # daily 12:00 UTC
report_formats         = ["json", "csv"]
s3_prefix              = "acm-inventory/"
lambda_timeout_seconds = 60
lambda_memory_mb       = 256

# Email summary (optional)
enable_email_summary = true
email_recipient      = "alerts@example.com"
``` 

3. **Initialize and run**:

```
terraform init
terraform plan
terraform apply
```

4. **Show results (Terraform data-source inventory)**:

```
# High-level summary (account, region, counts)
terraform output acm_inventory_summary

# Full inventory (JSON map keyed by ARN)
terraform output -json acm_certificate_inventory | jq

# Certificates expiring within 30 days
terraform output -json acm_expiring_within_30_days | jq

# Simple breakdowns
terraform output acm_public_vs_private_counts
terraform output acm_aws_vs_customer_counts
```

5. **Lambda-generated reports**

- Artifacts will be written to the S3 bucket under the configured prefix, e.g.:
  - `s3://<reports_bucket_name>/acm-inventory/acm-inventory-<account>-<region>-<timestamp>.json`
  - `s3://<reports_bucket_name>/acm-inventory/acm-inventory-<account>-<region>-<timestamp>.csv`
- If `enable_email_summary = true`, confirm the email subscription sent by SNS to receive summaries.

Manual run: You can invoke the Lambda from the AWS Console or CLI to generate a report on-demand.

## 🔧 Understanding Variables
Defined in variables.tf:
- region (string, required) – AWS region to inventory (ACM is regional).
- profile (string, optional) – Named AWS CLI profile for auth.
- assume_role_arn (string, optional) – Cross-account role ARN (leave blank if not needed).
- assume_role_external_id (string, optional) – External ID when assuming the role.
  
- reports_bucket_name (string, required) – S3 bucket for Lambda report artifacts.
- enable_email_summary (bool, default=false) – Send SNS email summary.
- email_recipient (string, optional) – Recipient for SNS email (required if enabled).
- schedule_expression (string) – EventBridge schedule for Lambda.
- report_formats (list(string), default=["json","csv"]) – Formats to export.
- s3_prefix (string) – S3 key prefix for artifacts.
- lambda_timeout_seconds (number) – Lambda timeout.
- lambda_memory_mb (number) – Lambda memory.
  
These are consumed by providers.tf to configure the AWS provider and (optionally) assume a role.

## 📊 Inventory Details

The inventory normalizes each ACM certificate into a record with fields like:
- arn, domain_name, subject_alt_names, status
- not_before, not_after (expiration)
- in_use_by (ELB, CloudFront, etc.)
- issuer, key_algorithm, acm_type (AMAZON_ISSUED | IMPORTED | PRIVATE)
- visibility (PUBLIC | PRIVATE)
- source (AWS_PROVIDED | CUSTOMER_PROVIDED)
- expiring_in_30d, is_expired (booleans)

## Outputs
- acm_inventory_summary – Account/Region/Counts overview
- acm_certificate_inventory – Full inventory (map keyed by ARN)
- acm_expiring_within_30_days – List filtered to upcoming expirations
- acm_public_vs_private_counts – Count by visibility
- acm_aws_vs_customer_counts – Count by provenance

## 🧭 Multi-Region (Optional)

ACM is regional. To scan multiple regions:

- Add provider aliases (e.g., provider "aws" { alias = "use1" ... }, provider "aws" { alias = "usw2" ... }).

- Duplicate the data sources per alias (provider = aws.use1, provider = aws.usw2).

- Merge results into combined locals/outputs.

If you want, I can generate a ready-to-run multi-region variant—tell me the regions.

## 📦 Prerequisites

Terraform: ≥ 1.5

AWS Provider: ≥ 5.0

AWS credentials with acm:ListCertificates and acm:DescribeCertificate (and STS if assuming role).

For automated reporting:

- Permissions are created by Terraform: Lambda role can read ACM, write to S3, and publish to SNS (if enabled).
- Confirm SNS email subscription to start receiving messages.

🔒 Security Considerations

Least privilege: Grant only read permissions required for ACM listing/describe.

Cross-account: If assuming roles, scope trust and permissions appropriately.

Secrets: Use AWS SSO/STS or a secure credential helper for profiles; don’t hardcode PATs/keys in code.

🤝 Contributing

This is an educational repo to demonstrate ACM inventory patterns with Terraform. Feel free to:

Fork and tailor to your org (e.g., multi-region, export to CSV via external or local_file).

Open issues/PRs for improvements (filters, tagging, reporting integrations).

📄 License

Provided for educational purposes. Validate and test before using in production.

🏢 Owner

ZTMF (CMS) — Certificate Visibility & Lifecycle (Terraform + ACM)
