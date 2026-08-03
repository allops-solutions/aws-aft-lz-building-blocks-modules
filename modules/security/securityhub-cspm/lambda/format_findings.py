"""Security Hub finding formatter.

Triggered by EventBridge on "Security Hub Findings - Imported" events. Renders
each finding (already severity-filtered by the EventBridge rule) into a concise,
human-readable message and publishes it to the notifications SNS topic.

Because Security Hub aggregates findings from GuardDuty, Inspector, Macie, IAM
Access Analyzer and the Config-backed security controls, a single generic
formatter covers every integrated product without service-specific handling.

Whether a finding is delivered or throttled is decided per product by a
notification policy (see ``_NOTIFICATION_POLICIES``). Products without a
dedicated policy always notify; only Security Hub's own control findings are
throttled today (see ``securityhub``). The product is identified by the ASFF
``ProductName`` field, because every finding arrives as a single "Security Hub
Findings - Imported" event whose EventBridge ``source`` is always
``aws.securityhub`` regardless of the product that generated it.
"""

import json
import logging
import os
import re

import boto3

import securityhub

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

sns = boto3.client("sns")

TOPIC_ARN = os.environ["TOPIC_ARN"]

_SUBJECT_MAX = 100
_NON_ASCII = re.compile(r"[^\x20-\x7E]")

# Per-product notification policies, tried in order. A policy is any module
# exposing ``matches(finding) -> bool`` and
# ``should_notify(finding) -> (bool, notification_type)``. The first policy that
# matches decides delivery; findings matched by no policy always notify. Add a
# new sibling module here to give another product (GuardDuty, Inspector, ...)
# its own rules without touching the handler.
_NOTIFICATION_POLICIES = (securityhub,)


def _get(obj, path, default=None):
    """Safely walk a nested dict path, returning default if any key is missing."""
    cur = obj
    for key in path:
        if isinstance(cur, dict) and key in cur:
            cur = cur[key]
        else:
            return default
    return cur


def _decide_notification(finding):
    """Return ``(should_notify, notification_type)`` for a finding.

    Delegates to the first registered product policy that matches. Findings from
    products without a dedicated policy (GuardDuty, Inspector, Macie, IAM Access
    Analyzer, ...) always notify with standard framing.
    """
    for policy in _NOTIFICATION_POLICIES:
        if policy.matches(finding):
            return policy.should_notify(finding)
    return True, None


def _clean_subject(text):
    text = _NON_ASCII.sub("", text).replace("\n", " ").strip()
    if len(text) > _SUBJECT_MAX:
        text = text[: _SUBJECT_MAX - 3].rstrip() + "..."
    return text or "Security Hub finding"


def _format_finding(finding, notification_type=None):
    severity = _get(finding, ["Severity", "Label"], "UNKNOWN")
    product = finding.get("ProductName") or "Security Hub"
    company = finding.get("CompanyName", "")
    account_id = finding.get("AwsAccountId", "unknown")
    account_name = finding.get("AwsAccountName", "")
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

    account_display = f"{account_id} ({account_name})" if account_name else account_id

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

    if notification_type == securityhub.FIRST_OBSERVED:
        header_lines = [
            f"[NEW] {severity} severity from {source_label}",
            "",
        ]
    elif notification_type == securityhub.MONTHLY_REMINDER:
        header_lines = [
            f"[REMINDER] {severity} severity from {source_label}",
            "",
            "This is a monthly reminder about an unresolved security finding.",
            "",
        ]
    else:
        header_lines = [
            f"{severity} severity finding from {source_label}",
            "",
        ]

    lines = header_lines + [
        f"Account:    {account_display}",
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

    if notification_type == securityhub.FIRST_OBSERVED:
        subject = _clean_subject(f"[NEW] [{severity}] {product}: {title}")
    elif notification_type == securityhub.MONTHLY_REMINDER:
        subject = _clean_subject(f"[REMINDER] [{severity}] {product}: {title}")
    else:
        subject = _clean_subject(f"[{severity}] {product}: {title}")
    return subject, "\n".join(lines)


def lambda_handler(event, context):
    findings = _get(event, ["detail", "findings"], []) or []

    logger.info(
        "Invoked: source=%s detail-type=%s findings=%d",
        event.get("source", ""),
        event.get("detail-type"),
        len(findings),
    )
    logger.debug("Event payload: %s", json.dumps(event))

    if not findings:
        logger.warning("No findings present in event; nothing to publish.")
        return {"findings_received": 0, "notifications_published": 0, "notifications_suppressed": 0}

    published = 0
    suppressed = 0

    for finding in findings:
        finding_id = finding.get("Id", "unknown")
        severity = _get(finding, ["Severity", "Label"], "UNKNOWN")
        product = finding.get("ProductName") or "Security Hub"

        should_notify, notification_type = _decide_notification(finding)

        if not should_notify:
            logger.debug(
                "Suppressed: severity=%s product=%s id=%s (already notified)",
                severity,
                product,
                finding_id,
            )
            suppressed += 1
            continue

        subject, body = _format_finding(finding, notification_type)
        try:
            response = sns.publish(TopicArn=TOPIC_ARN, Subject=subject, Message=body)
        except Exception:
            logger.exception("Failed to publish finding id=%s", finding_id)
            continue

        published += 1
        logger.info(
            "Published: severity=%s product=%s messageId=%s id=%s type=%s",
            severity,
            product,
            response.get("MessageId"),
            finding_id,
            notification_type or "standard",
        )

    logger.info(
        "Done: findings_received=%d notifications_published=%d notifications_suppressed=%d",
        len(findings),
        published,
        suppressed,
    )
    return {
        "findings_received": len(findings),
        "notifications_published": published,
        "notifications_suppressed": suppressed,
    }
