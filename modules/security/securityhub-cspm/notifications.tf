# ==============================================================================
# Security Hub finding notifications
#
# Because this account is the Security Hub delegated administrator with an
# ALL_REGIONS finding aggregator, every finding from every member account and
# Region — including those imported from GuardDuty, Inspector, Macie, and IAM
# Access Analyzer — arrives here as a "Security Hub Findings - Imported" event.
#
# A single EventBridge rule filters those events down to new, active findings at
# or above the configured severity, a Lambda renders them into readable text,
# and an SNS topic delivers them to this account's own email. The pipeline is
# always created; to stop receiving mail, unsubscribe from the SNS topic (the
# same opt-out model as Control Tower's aggregate topic).
#
#   EventBridge (severity-filtered) -> Lambda (formatter) -> SNS -> email
# ==============================================================================

data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# SNS topic — server-side encrypted with the AWS-managed key for SNS.
# ------------------------------------------------------------------------------
resource "aws_sns_topic" "notifications" {
  name              = local.notification_topic_name
  kms_master_key_id = "alias/aws/sns"

  # Shown as the sender's display name in delivered emails.
  display_name = "aws-security-hub-notifications"

  tags = var.tags

  depends_on = [terraform_data.deployment_gate]
}

# ------------------------------------------------------------------------------
# Topic policy — allow only the formatter Lambda's role (in this account) to
# publish. The default owner statement is retained for administration.
# ------------------------------------------------------------------------------
resource "aws_sns_topic_policy" "notifications" {
  arn = aws_sns_topic.notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DefaultOwnerAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action = [
          "SNS:GetTopicAttributes",
          "SNS:SetTopicAttributes",
          "SNS:AddPermission",
          "SNS:RemovePermission",
          "SNS:DeleteTopic",
          "SNS:Subscribe",
          "SNS:ListSubscriptionsByTopic",
          "SNS:Publish",
        ]
        Resource  = aws_sns_topic.notifications.arn
        Condition = { StringEquals = { "AWS:SourceOwner" = data.aws_caller_identity.current.account_id } }
      },
      {
        Sid       = "AllowFormatterLambdaPublish"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.formatter.arn }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.notifications.arn
      },
    ]
  })
}

# ------------------------------------------------------------------------------
# Email subscription — this account's own root email (the audit account).
# The recipient must confirm via the email AWS sends, and can unsubscribe at
# any time to stop delivery without removing the pipeline.
# ------------------------------------------------------------------------------
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "email"
  endpoint  = local.notification_email
}

# ------------------------------------------------------------------------------
# Formatter Lambda — IAM role, code package, log group, and function.
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "formatter_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "formatter" {
  name               = "${local.notification_topic_name}-formatter"
  assume_role_policy = data.aws_iam_policy_document.formatter_assume.json

  tags = var.tags

  depends_on = [terraform_data.deployment_gate]
}

data "aws_iam_policy_document" "formatter" {
  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.formatter.arn}:*"]
  }

  statement {
    sid       = "PublishNotifications"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.notifications.arn]
  }

  # Publishing to the SSE-enabled topic requires use of the AWS-managed SNS key,
  # scoped to calls made through the SNS service in this account.
  statement {
    sid    = "UseSnsManagedKey"
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["sns.${var.region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "formatter" {
  name   = "${local.notification_topic_name}-formatter"
  role   = aws_iam_role.formatter.id
  policy = data.aws_iam_policy_document.formatter.json
}

resource "aws_cloudwatch_log_group" "formatter" {
  name              = "/aws/lambda/${local.notification_topic_name}-formatter"
  retention_in_days = 90

  tags = var.tags

  depends_on = [terraform_data.deployment_gate]
}

data "archive_file" "formatter" {
  type        = "zip"
  source_file = "${path.module}/lambda/format_findings.py"
  output_path = "${path.module}/lambda/format_findings.zip"
}

resource "aws_lambda_function" "formatter" {
  function_name    = "${local.notification_topic_name}-formatter"
  description      = "Formats Security Hub findings into human-readable email notifications."
  role             = aws_iam_role.formatter.arn
  runtime          = "python3.13"
  handler          = "format_findings.lambda_handler"
  filename         = data.archive_file.formatter.output_path
  source_code_hash = data.archive_file.formatter.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      TOPIC_ARN = aws_sns_topic.notifications.arn
    }
  }

  depends_on = [
    aws_iam_role_policy.formatter,
    aws_cloudwatch_log_group.formatter,
  ]

  tags = var.tags
}

# ------------------------------------------------------------------------------
# EventBridge rule — new, active Security Hub findings at or above the minimum
# severity. Filtering on severity alone excludes passing control findings (which
# are INFORMATIONAL) while preserving GuardDuty and Inspector findings, which do
# not carry a Compliance status.
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "findings" {
  name        = "${local.notification_topic_name}-imported"
  description = "Routes new, active Security Hub findings at or above ${upper(var.notification_min_severity)} severity to the formatter Lambda."

  event_pattern = jsonencode({
    source        = ["aws.securityhub"]
    "detail-type" = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity    = { Label = local.notification_severity_labels }
        RecordState = ["ACTIVE"]
        Workflow    = { Status = ["NEW"] }
      }
    }
  })

  tags = var.tags

  depends_on = [terraform_data.deployment_gate]
}

resource "aws_cloudwatch_event_target" "formatter" {
  rule      = aws_cloudwatch_event_rule.findings.name
  target_id = "formatter-lambda"
  arn       = aws_lambda_function.formatter.arn
}

resource "aws_lambda_permission" "events" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.formatter.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.findings.arn
}
