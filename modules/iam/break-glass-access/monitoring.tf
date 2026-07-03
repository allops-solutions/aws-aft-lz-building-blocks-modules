###############################################################################
# Break-glass usage alerting (CT management account, us-east-1)
#
# The detective control. Any break-glass user activity triggers SNS alerts to
# the root distribution list. This is the primary guardrail since SCPs cannot
# constrain the management account.
#
# Three EventBridge rules provide layered alerting:
#   1. Console sign-in       — any sign-in event by the break-glass user
#   2. Cross-account assume  — AssumeRole calls (switching into other accounts)
#   3. Write operations      — any mutating API call (readOnly=false), excluding
#                              crypto ops and events already covered by rules 1-2
#
# Console sign-in events (signin.amazonaws.com / ConsoleLogin) are GLOBAL events
# delivered only to us-east-1. STS and CloudTrail API events are also global.
# All break-glass alerting resources live in us-east-1.
#
# A CloudTrail trail is REQUIRED for EventBridge to receive CloudTrail events.
# If Control Tower centralized logging is enabled, the CT organization trail
# provides this. If not, this module creates a minimal trail specifically for
# EventBridge delivery.
###############################################################################

# --- SNS topic + email subscription (us-east-1) -----------------------------

resource "aws_sns_topic" "alerts" {
  provider = aws.org-management

  name = "break-glass-alerts"
  tags = var.tags
}

data "aws_iam_policy_document" "alerts_topic" {
  statement {
    sid       = "AllowEventBridgePublish"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  provider = aws.org-management

  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.alerts_topic.json
}

resource "aws_sns_topic_subscription" "email" {
  provider = aws.org-management

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# --- EventBridge rule: console sign-in (us-east-1) ---------------------------


resource "aws_cloudwatch_event_rule" "usage_signin" {
  provider = aws.org-management

  name        = "break-glass-activity"
  description = "Alert on console activity by the break-glass user (global events land in us-east-1)."

  # Console sign-in events use a dedicated detail-type. Without specifying it,
  # EventBridge will not match the ConsoleLogin event reliably.
  event_pattern = jsonencode({
    detail-type = ["AWS Console Sign In via CloudTrail"]
    detail = {
      userIdentity = {
        type     = ["IAMUser"]
        userName = [var.break_glass_user_name]
      }
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "usage_signin" {
  provider = aws.org-management

  rule      = aws_cloudwatch_event_rule.usage_signin.name
  target_id = "sns"
  arn       = aws_sns_topic.alerts.arn

  input_transformer {
    input_paths = {
      account     = "$.detail.recipientAccountId"
      time        = "$.detail.eventTime"
      sourceIp    = "$.detail.sourceIPAddress"
      eventName   = "$.detail.eventName"
      eventSource = "$.detail.eventSource"
    }
    input_template = <<-TEMPLATE
      "BREAK-GLASS USER ACTIVITY (management account <account>)."
      "If this is not part of a tracked emergency, treat it as a potential compromise."
      ""
      "Event:   <eventName>"
      "Service: <eventSource>"
      "Time:    <time>"
      "SourceIP:<sourceIp>"
      ""
      "Review CloudTrail in the management account and the break-glass runbook (BREAK_GLASS.md)."
    TEMPLATE
  }
}

# --- EventBridge rule: cross-account role assumption (us-east-1) ---------------
#
# Captures AssumeRole / AssumeRoleWithSAML / AssumeRoleWithWebIdentity calls made
# by the break-glass user. These are global STS events delivered to us-east-1.
# This alerts when the break-glass user switches into another account's role
# (e.g. AWSControlTowerExecution).

resource "aws_cloudwatch_event_rule" "usage_assume_role" {
  provider = aws.org-management

  name        = "break-glass-assume-role"
  description = "Alert when the break-glass user assumes a cross-account role."

  event_pattern = jsonencode({
    source      = ["aws.sts"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventName = ["AssumeRole", "AssumeRoleWithSAML", "AssumeRoleWithWebIdentity"]
      userIdentity = {
        type     = ["IAMUser"]
        userName = [var.break_glass_user_name]
      }
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "usage_assume_role" {
  provider = aws.org-management

  rule      = aws_cloudwatch_event_rule.usage_assume_role.name
  target_id = "sns"
  arn       = aws_sns_topic.alerts.arn

  input_transformer {
    input_paths = {
      account   = "$.detail.recipientAccountId"
      time      = "$.detail.eventTime"
      sourceIp  = "$.detail.sourceIPAddress"
      eventName = "$.detail.eventName"
      roleArn   = "$.detail.requestParameters.roleArn"
    }
    input_template = <<-TEMPLATE
      "BREAK-GLASS CROSS-ACCOUNT ROLE ASSUMPTION (from management account <account>)."
      "If this is not part of a tracked emergency, treat it as a potential compromise."
      ""
      "Event:    <eventName>"
      "Role ARN: <roleArn>"
      "Time:     <time>"
      "SourceIP: <sourceIp>"
      ""
      "The break-glass user has assumed a role in another account. All subsequent actions"
      "in that account will be logged under the assumed role's CloudTrail."
      ""
      "Review CloudTrail in both the management and target accounts, and follow BREAK_GLASS.md."
    TEMPLATE
  }
}

# --- EventBridge rule: write/mutating operations (us-east-1) ------------------
#
# Captures mutating (write) API calls made by the break-glass user in the
# management account. Uses CloudTrail's readOnly=false field to cleanly exclude
# all read operations (Get*, List*, Describe*, etc.) without maintaining an
# explicit exclusion list. Also excludes events already handled by the sign-in
# and assume-role rules above, plus noisy KMS crypto operations.

resource "aws_cloudwatch_event_rule" "usage_write_ops" {
  provider = aws.org-management

  name        = "break-glass-write-ops"
  description = "Alert on mutating (write) API calls by the break-glass user (excludes read-only operations)."

  # NOTE: CloudTrail events include a "readOnly" boolean field. We filter to
  # only match write (mutating) operations by requiring readOnly = false.
  # We also exclude events already covered by dedicated rules above (sign-in,
  # AssumeRole) and noisy crypto read operations that CloudTrail sometimes
  # marks as readOnly=false (KMS Encrypt/Decrypt/GenerateDataKey).
  event_pattern = jsonencode({
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      userIdentity = {
        type     = ["IAMUser"]
        userName = [var.break_glass_user_name]
      }
      readOnly = [false]
      eventName = [{
        "anything-but" = [
          # STS (handled by the dedicated assume-role rule above)
          "AssumeRole",
          "AssumeRoleWithSAML",
          "AssumeRoleWithWebIdentity",
          # KMS crypto ops that may be triggered implicitly
          "Decrypt",
          "Encrypt",
          "GenerateDataKey",
          "GenerateDataKeyWithoutPlaintext",
          "GenerateRandom",
          "ReEncrypt"
        ]
      }]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "usage_write_ops" {
  provider = aws.org-management

  rule      = aws_cloudwatch_event_rule.usage_write_ops.name
  target_id = "sns"
  arn       = aws_sns_topic.alerts.arn

  input_transformer {
    input_paths = {
      account     = "$.detail.recipientAccountId"
      time        = "$.detail.eventTime"
      sourceIp    = "$.detail.sourceIPAddress"
      eventName   = "$.detail.eventName"
      eventSource = "$.detail.eventSource"
    }
    input_template = <<-TEMPLATE
      "BREAK-GLASS WRITE OPERATION (management account <account>)."
      "If this is not part of a tracked emergency, treat it as a potential compromise."
      ""
      "Event:   <eventName>"
      "Service: <eventSource>"
      "Time:    <time>"
      "SourceIP:<sourceIp>"
      ""
      "This is a mutating (write) API call by the break-glass user."
      "Review CloudTrail for full request parameters and follow BREAK_GLASS.md."
    TEMPLATE
  }
}

# --- Conditional CloudTrail trail (when CT centralized logging is disabled) ---
#
# EventBridge requires an active CloudTrail trail to receive events. When CT
# manages logging via its organization trail, no extra trail is needed. When CT
# logging is disabled, this creates a minimal multi-region trail in the
# management account to ensure EventBridge delivery.

resource "aws_s3_bucket" "cloudtrail" {
  count    = var.enable_centralized_logging ? 0 : 1
  provider = aws.org-management

  bucket        = "break-glass-trail-${var.ct_management_account_id}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  count    = var.enable_centralized_logging ? 0 : 1
  provider = aws.org-management

  bucket                  = aws_s3_bucket.cloudtrail[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  count    = var.enable_centralized_logging ? 0 : 1
  provider = aws.org-management

  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}

data "aws_iam_policy_document" "cloudtrail_bucket" {
  count = var.enable_centralized_logging ? 0 : 1

  statement {
    sid       = "AWSCloudTrailAclCheck"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail[0].arn]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudtrail:us-east-1:${var.ct_management_account_id}:trail/break-glass-trail"]
    }
  }

  statement {
    sid       = "AWSCloudTrailWrite"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail[0].arn}/AWSLogs/${var.ct_management_account_id}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudtrail:us-east-1:${var.ct_management_account_id}:trail/break-glass-trail"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  count    = var.enable_centralized_logging ? 0 : 1
  provider = aws.org-management

  bucket = aws_s3_bucket.cloudtrail[0].id
  policy = data.aws_iam_policy_document.cloudtrail_bucket[0].json
}

resource "aws_cloudtrail" "break_glass" {
  count    = var.enable_centralized_logging ? 0 : 1
  provider = aws.org-management

  name                          = "break-glass-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail[0].id
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_logging                = true

  # Only management events (no data events) — minimal cost.
  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = var.tags

  depends_on = [aws_s3_bucket_policy.cloudtrail[0]]
}
