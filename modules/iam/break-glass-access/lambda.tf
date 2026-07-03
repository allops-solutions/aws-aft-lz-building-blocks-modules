###############################################################################
# Refresh Lambda (CT management account, us-east-1)
#
# Enumerates Control Tower-enrolled accounts and rewrites breakglass.html in the
# bookmarks bucket. Triggered by Control Tower account lifecycle events and on a
# periodic schedule (the schedule covers suspensions, which have no CT event).
###############################################################################

data "archive_file" "refresh" {
  type        = "zip"
  source_file = "${path.module}/assets/lambda/index.py"
  output_path = "${path.module}/assets/lambda/build/refresh.zip"
}

data "aws_iam_policy_document" "refresh_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "refresh" {
  provider = aws.org-management

  name               = "break-glass-refresh"
  assume_role_policy = data.aws_iam_policy_document.refresh_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "refresh" {
  statement {
    sid    = "ReadOrganizations"
    effect = "Allow"
    actions = [
      "organizations:ListAccounts",
      "organizations:ListAccountsForParent",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadControlTower"
    effect = "Allow"
    actions = [
      "controltower:ListLandingZones",
      "controltower:ListBaselines",
      "controltower:ListEnabledBaselines",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "WriteBookmarksObject"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.bookmarks.arn}/${var.bookmarks_object_key}"]
  }

  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:us-east-1:${var.ct_management_account_id}:log-group:/aws/lambda/break-glass-refresh:*"]
  }
}

resource "aws_iam_role_policy" "refresh" {
  provider = aws.org-management

  name   = "break-glass-refresh"
  role   = aws_iam_role.refresh.id
  policy = data.aws_iam_policy_document.refresh.json
}

resource "aws_cloudwatch_log_group" "refresh" {
  provider = aws.org-management

  name              = "/aws/lambda/break-glass-refresh"
  retention_in_days = 365
  tags              = var.tags
}

resource "aws_lambda_function" "refresh" {
  provider = aws.org-management

  function_name    = "break-glass-refresh"
  description      = "Renders the break-glass switch-role bookmarks page from Control Tower-managed accounts."
  role             = aws_iam_role.refresh.arn
  handler          = "index.handler"
  runtime          = "python3.14"
  architectures    = ["arm64"]
  timeout          = 120
  memory_size      = 256
  filename         = data.archive_file.refresh.output_path
  source_code_hash = data.archive_file.refresh.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME      = aws_s3_bucket.bookmarks.id
      OBJECT_KEY       = var.bookmarks_object_key
      TARGET_ROLE_NAME = var.target_role_name
      MGMT_ACCOUNT_ID  = var.ct_management_account_id
    }
  }

  depends_on = [aws_cloudwatch_log_group.refresh]
  tags       = var.tags
}

###############################################################################
# Trigger 1: Control Tower account lifecycle events
#
# Control Tower emits CreateManagedAccount / UpdateManagedAccount events via
# CloudTrail/AWS Health into the default event bus in the home region when an
# account finishes enrolling. Refresh the page when that happens.
###############################################################################

resource "aws_cloudwatch_event_rule" "ct_lifecycle" {
  provider = aws.org-management

  name        = "break-glass-ct-lifecycle"
  description = "Refresh break-glass bookmarks when Control Tower enrolls/updates an account."

  event_pattern = jsonencode({
    source      = ["aws.controltower"]
    detail-type = ["AWS Service Event via CloudTrail"]
    detail = {
      eventName = ["CreateManagedAccount", "UpdateManagedAccount"]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "ct_lifecycle" {
  provider = aws.org-management

  rule      = aws_cloudwatch_event_rule.ct_lifecycle.name
  target_id = "refresh-lambda"
  arn       = aws_lambda_function.refresh.arn
}

resource "aws_lambda_permission" "ct_lifecycle" {
  provider = aws.org-management

  statement_id  = "AllowCTLifecycleInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.refresh.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ct_lifecycle.arn
}

###############################################################################
# Trigger 2: periodic schedule (covers suspensions — no CT event for those)
###############################################################################

resource "aws_cloudwatch_event_rule" "schedule" {
  provider = aws.org-management

  name                = "break-glass-schedule"
  description         = "Periodic refresh of break-glass bookmarks to pick up account status changes."
  schedule_expression = var.refresh_schedule_expression

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "schedule" {
  provider = aws.org-management

  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = "refresh-lambda"
  arn       = aws_lambda_function.refresh.arn
}

resource "aws_lambda_permission" "schedule" {
  provider = aws.org-management

  statement_id  = "AllowScheduleInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.refresh.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}
