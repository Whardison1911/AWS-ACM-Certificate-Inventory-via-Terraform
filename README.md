# AWS-ACM-Certificate-Inventory-via-Terraform

nventory AWS Certificate Manager (ACM) certificates across regions and see when they expire—using pure Terraform.
By default it scans the configured provider region; optionally it also scans us-east-1 (where CloudFront certs live).

What you get

✅ List of all ACM certs (issued, pending, expired, etc.)

📍 Region-aware (current provider region + optional us-east-1)

🧾 Structured output with domain, status, NotAfter (expiry), in-use resources, and more

🧰 No side effects — data-only (reads, no resource creation)

Requirements

Terraform ≥ 1.5

AWS Provider ≥ 5.0 (uses data.aws_acm_certificates)

Files

acm_inventory.tf – main Terraform file with inputs, data sources, and outputs

Inputs
Variable	Type	Default	Description
region	string	—	Primary region to query (e.g., us-east-1)
include_us_east_1	bool	true	Also inventory ACM in us-east-1 (recommended for CloudFront)

The module defines an aws provider for your chosen region and an alias aws.use1 for us-east-1.

Output

acm_certs – a list of objects like:

[
  {
    "arn": "arn:aws:acm:us-east-1:123456789012:certificate/abcd-...",
    "region": "us-east-1",
    "domain": "example.com",
    "sans": ["www.example.com"],
    "type": "AMAZON_ISSUED",
    "status": "ISSUED",
    "in_use_by": ["arn:aws:cloudfront::123456789012:distribution/EDFDVBD6EXAMPLE"],
    "not_before": "2025-06-01T00:00:00Z",
    "not_after":  "2026-05-31T23:59:59Z",
    "renewal_eligibility": "ELIGIBLE",
    "key_algorithm": "RSA-2048",
    "signature_algorithm": "SHA256WITHRSA"
  }
]


Fields included: arn, region, domain, sans, type, status, in_use_by, not_before, not_after, renewal_eligibility, key_algorithm, signature_algorithm.

Quick Start

Create a working folder and save your file:

mkdir acm-inventory && cd acm-inventory
# save your acm_inventory.tf here


Set variables (example terraform.tfvars):

region            = "us-east-1"
include_us_east_1 = true


Run Terraform:

terraform init
terraform apply -auto-approve


View results:

terraform output -json acm_certs | jq .

Helpful jq Examples

Show domain & expiry (sorted soonest first):

terraform output -json acm_certs \
| jq -r '.[] | {domain, region, status, not_after} | @tsv' \
| sort -k4


Show certs expiring in the next 30 days:

deadline=$(date -u -v+30d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "+30 days" +"%Y-%m-%dT%H:%M:%SZ")
terraform output -json acm_certs \
| jq --arg deadline "$deadline" '
  .[] | select(.not_after <= $deadline) |
  {domain, region, status, not_after}'


Only show certs currently in use:

terraform output -json acm_certs \
| jq '.[] | select((.in_use_by|length) > 0) | {domain, region, in_use_by}'

Notes & Tips

CloudFront certificates are always in us-east-1; keep include_us_east_1 = true unless you know you don’t use CloudFront.

This uses data sources only — it won’t create/modify any resources.

If you have many accounts/regions, run this in a pipeline across each (e.g., via multiple workspaces, or a wrapper script that sets region and assumes roles).

For organizations: add tags, account id, or workspace to the output by extending the locals block.

Troubleshooting

data.aws_acm_certificates not found / schema errors: upgrade to AWS Provider ≥ 5.0.

Empty results: confirm you have ACM certs in that region and the credentials/role can read ACM.

JSON tooling: Install jq for pretty-printing and filtering.

License / Ownership

Owner: ZTMF (CMS)

Purpose: Inventory ACM certificates (domain, status, expiration) across regions.

Last updated: 2025-09-19
