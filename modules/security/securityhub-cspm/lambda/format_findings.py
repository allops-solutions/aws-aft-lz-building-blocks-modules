"""Security Hub finding formatter.

Triggered by EventBridge on "Security Hub Findings - Imported" events. Renders
each finding (already severity-filtered by the EventBridge rule) into a concise,
human-readable message and publishes it to the notifications SNS topic.

Because Security Hub aggregates findings from GuardDuty, Inspector, Macie, IAM
Access Analyzer and the Config-backed security controls, this single formatter
covers every integrated product without service-specific handling.
"""

import json
import logging
import os
import re

import boto3

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

sns = boto3.client("sns")

TOPIC_ARN = os.environ["TOPIC_ARN"]

# Non-ASCII / control characters are stripped from the SNS Subject, which only
# accepts printable ASCII and a maximum of 100 characters.
_SUBJECT_MAX = 100
_NON_ASCII = re.compile(r"[^\x20-\x7E]")


def _get(obj, path, default=None):
    """Safely walk a nested dict path, returning default if any key is missing."""
    cur = obj
    for key in path:
        if isinstance(cur, dict) and key in cur:
            cur = cur[key]
        else:
            return default
    return cur


def _clean_subject(text):
    text = _NON_ASCII.sub("", text).replace("\n", " ").strip()
    if len(text) > _SUBJECT_MAX:
        text = text[: _SUBJECT_MAX - 3].rstrip() + "..."
    return text or "Security Hub finding"


def _format_finding(finding):
    severity = _get(finding, ["Severity", "Label"], "UNKNOWN")
    product = finding.get("ProductName") or "Security Hub"
    company = finding.get("CompanyName", "")
    account = finding.get("AwsAccountId", "unknown")
    region = finding.get("Region", "unknown")
    title = finding.get("Title", "").strip()
    description = finding.get("Description", "").strip()
    compliance = _get(finding, ["Compliance", "Status"])
    workflow = _get(finding, ["Workflow", "Status"])
    types = ", ".join(finding.get("Types", []) or [])
    first_seen = finding.get("FirstObservedAt") or finding.get("CreatedAt", "")
    last_seen = finding.get("UpdatedAt", "")
    remediation_text = _get(finding, ["Remediation", "Recommendation", "Text"], "")
    remediation_url = _get(finding, ["Remediation", "Recommendation", "Url"], "")
    finding_id = finding.get("Id", "")

    resources = finding.get("Resources", []) or []
    if resources:
        resource_block = "\n".join(
            f"  - {r.get('Type', 'Unknown')}: {r.get('Id', '')}" for r in resources
        )
    else:
        resource_block = "  (none reported)"

    source_label = f"{company} / {product}" if company and company != product else product
    console_url = (
        f"https://{region}.console.aws.amazon.com/securityhub/home"
        f"?region={region}#/findings"
    )

    lines = [
        f"{severity} severity finding from {source_label}",
        "",
        f"Account:    {account}",
        f"Region:     {region}",
        f"Source:     {source_label}",
        f"Severity:   {severity}",
    ]
    if compliance:
        lines.append(f"Compliance: {compliance}")
    if workflow:
        lines.append(f"Workflow:   {workflow}")

    lines += ["", f"Title:      {title}"]
    if description:
        lines += ["", "Description:", f"  {description}"]

    lines += ["", "Affected resources:", resource_block]

    if types:
        lines += ["", f"Finding types: {types}"]
    if first_seen:
        lines.append(f"First observed: {first_seen}")
    if last_seen:
        lines.append(f"Last updated:   {last_seen}")

    if remediation_text or remediation_url:
        lines += ["", "Remediation:"]
        if remediation_text:
            lines.append(f"  {remediation_text}")
        if remediation_url:
            lines.append(f"  {remediation_url}")

    lines += ["", f"Finding ID: {finding_id}", f"Open in console: {console_url}"]

    subject = _clean_subject(f"[{severity}] {product}: {title}")
    return subject, "\n".join(lines)


def lambda_handler(event, context):
    findings = _get(event, ["detail", "findings"], []) or []
    logger.info(
        "Invoked: source=%s detail-type=%s findings=%d",
        event.get("source"),
        event.get("detail-type"),
        len(findings),
    )
    # Full event only when explicitly debugging, to avoid noisy logs.
    logger.debug("Event payload: %s", json.dumps(event))

    if not findings:
        logger.warning("No findings present in event; nothing to publish.")
        return {"findings_received": 0, "notifications_published": 0}

    published = 0
    for finding in findings:
        finding_id = finding.get("Id", "unknown")
        severity = _get(finding, ["Severity", "Label"], "UNKNOWN")
        product = finding.get("ProductName") or "Security Hub"

        subject, body = _format_finding(finding)
        try:
            response = sns.publish(TopicArn=TOPIC_ARN, Subject=subject, Message=body)
        except Exception:
            logger.exception("Failed to publish finding id=%s", finding_id)
            continue

        published += 1
        logger.info(
            "Published: severity=%s product=%s messageId=%s id=%s",
            severity,
            product,
            response.get("MessageId"),
            finding_id,
        )

    logger.info(
        "Done: findings_received=%d notifications_published=%d",
        len(findings),
        published,
    )
    return {"findings_received": len(findings), "notifications_published": published}

"""
To test the Lambda, use:

aws securityhub batch-import-findings --region eu-central-1 --findings '[{
  "SchemaVersion":"2018-10-08",
  "Id":"test-notification-pipeline-001",
  "ProductArn":"arn:aws:securityhub:eu-central-1:294327208819:product/294327208819/default",
  "GeneratorId":"manual-pipeline-test",
  "AwsAccountId":"294327208819",
  "Types":["Software and Configuration Checks/Industry and Regulatory Standards"],
  "CreatedAt":"2026-07-23T12:00:00.000Z",
  "UpdatedAt":"2026-07-23T12:00:00.000Z",
  "Severity":{"Label":"HIGH"},
  "Title":"TEST - notification pipeline validation",
  "Description":"Synthetic finding to validate the Security Hub notification pipeline end to end.",
  "Resources":[{"Type":"Other","Id":"arn:aws:iam::294327208819:root"}],
  "RecordState":"ACTIVE",
  "Workflow":{"Status":"NEW"}
}]'
"""