import os
import json
import csv
import io
import boto3
from datetime import datetime, timezone


def _isoformat(dt_str: str) -> str:
    if not dt_str:
        return ""
    try:
        # ACM returns RFC3339/ISO-like timestamps; normalize to ISO 8601 Z
        dt = datetime.fromisoformat(dt_str.replace("Z", "+00:00"))
        return dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
    except Exception:
        return dt_str


def _list_all_certificates(acm_client):
    paginator = acm_client.get_paginator("list_certificates")
    certs = []
    for page in paginator.paginate(CertificateStatuses=["PENDING_VALIDATION","ISSUED","INACTIVE","EXPIRED","VALIDATION_TIMED_OUT","REVOKED","FAILED","NOT_IMPORTED"], Includes={"extendedKeyUsage": [], "keyTypes": [], "keyAlgorithms": []}):
        certs.extend(page.get("CertificateSummaryList", []))
    return certs


def _get_certificate_detail(acm_client, arn: str):
    try:
        detail = acm_client.describe_certificate(CertificateArn=arn)["Certificate"]
        return detail
    except Exception as e:
        return {"CertificateArn": arn, "error": str(e)}


def _flatten_certificate(detail: dict) -> dict:
    not_before = detail.get("NotBefore")
    not_after = detail.get("NotAfter")
    now = datetime.now(timezone.utc)
    expiring_in_30d = False
    is_expired = False
    if isinstance(not_after, datetime):
        is_expired = not_after < now
        expiring_in_30d = not_after >= now and (not_after - now).days <= 30

    cert_type = detail.get("Type")
    source = "CUSTOMER_PROVIDED" if cert_type == "IMPORTED" else "AWS_PROVIDED"
    visibility = "PRIVATE" if cert_type == "PRIVATE" else "PUBLIC"

    in_use_by = detail.get("InUseBy") or []

    return {
        "arn": detail.get("CertificateArn"),
        "domain_name": detail.get("DomainName"),
        "subject_alt_names": detail.get("SubjectAlternativeNames") or [],
        "status": detail.get("Status"),
        "not_before": not_before.isoformat() if isinstance(not_before, datetime) else _isoformat(str(not_before)),
        "not_after": not_after.isoformat() if isinstance(not_after, datetime) else _isoformat(str(not_after)),
        "in_use_by": in_use_by,
        "issuer": detail.get("Issuer"),
        "key_algorithm": detail.get("KeyAlgorithm"),
        "acm_type": cert_type,
        "visibility": visibility,
        "source": source,
        "expiring_in_30d": expiring_in_30d,
        "is_expired": is_expired,
    }


def _to_csv(rows: list) -> str:
    if not rows:
        return ""
    headers = [
        "arn",
        "domain_name",
        "status",
        "not_before",
        "not_after",
        "visibility",
        "source",
        "expiring_in_30d",
        "is_expired",
        "subject_alt_names",
        "in_use_by",
        "issuer",
        "key_algorithm",
    ]
    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=headers)
    writer.writeheader()
    for r in rows:
        row = r.copy()
        row["subject_alt_names"] = ";".join(row.get("subject_alt_names", []))
        row["in_use_by"] = ";".join(row.get("in_use_by", []))
        writer.writerow({k: row.get(k, "") for k in headers})
    return buf.getvalue()


def handler(event, context):
    region = os.environ.get("AWS_REGION", os.environ.get("AWS_DEFAULT_REGION", "us-east-1"))
    bucket = os.environ["REPORTS_BUCKET_NAME"]
    s3_prefix = os.environ.get("S3_PREFIX", "acm-inventory/")
    report_formats = [fmt.strip().lower() for fmt in os.environ.get("REPORT_FORMATS", "json,csv").split(",") if fmt.strip()]
    sns_topic_arn = os.environ.get("SNS_TOPIC_ARN", "")

    acm = boto3.client("acm", region_name=region)
    s3 = boto3.client("s3")
    sns = boto3.client("sns") if sns_topic_arn else None

    summaries = _list_all_certificates(acm)
    details = [_get_certificate_detail(acm, s.get("CertificateArn")) for s in summaries]
    rows = [_flatten_certificate(d) for d in details]

    account_id = boto3.client("sts").get_caller_identity()["Account"]
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

    uploaded = []
    if "json" in report_formats:
        body = json.dumps(rows, separators=(",", ":"))
        key = f"{s3_prefix}acm-inventory-{account_id}-{region}-{timestamp}.json"
        s3.put_object(Bucket=bucket, Key=key, Body=body.encode("utf-8"), ContentType="application/json")
        uploaded.append(key)

    if "csv" in report_formats:
        body = _to_csv(rows)
        key = f"{s3_prefix}acm-inventory-{account_id}-{region}-{timestamp}.csv"
        s3.put_object(Bucket=bucket, Key=key, Body=body.encode("utf-8"), ContentType="text/csv")
        uploaded.append(key)

    expiring_soon = [r for r in rows if r.get("expiring_in_30d") and not r.get("is_expired")]

    summary_msg = {
        "account_id": account_id,
        "region": region,
        "total": len(rows),
        "expiring_within_30_days": len(expiring_soon),
        "uploaded_keys": uploaded,
    }

    if sns:
        sns.publish(TopicArn=sns_topic_arn, Subject=f"ACM Inventory {region} ({len(rows)} certs)", Message=json.dumps(summary_msg))

    return {"status": "ok", **summary_msg}


