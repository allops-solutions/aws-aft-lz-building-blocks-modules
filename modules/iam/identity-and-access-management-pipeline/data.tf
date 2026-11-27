# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

data "aws_ssoadmin_instances" "sso" {}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_organizations_organization" "org" {
  count = var.account_lifecycle_events_source == "CT" ? 1 : 0
}

data "local_file" "buildspec_plan" {
  filename = "${path.module}/assets/buildspecs/buildspec-plan.yml"
}

data "local_file" "buildspec_apply" {
  filename = "${path.module}/assets/buildspecs/buildspec-apply.yml"
}

data "local_file" "buildspec_combined" {
  filename = "${path.module}/assets/buildspecs/buildspec-combined.yml"
}

data "archive_file" "aft_new_account_event_forwarder" {
  count       = var.account_lifecycle_events_source == "AFT" ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/assets/lambda/aft-new-account-event-forwarder"
  output_path = "${path.module}/assets/lambda/aft-new-account-event-forwarder.zip"
}

data "aws_ssm_parameter" "aft_sns_notification_topic_arn" {
  count    = var.account_lifecycle_events_source == "AFT" ? 1 : 0
  provider = aws.event-source-account

  name = "/aft/account/aft-management/sns/topic-arn"
}

data "aws_ssm_parameter" "aft_management_account_id" {
  count    = var.account_lifecycle_events_source == "AFT" ? 1 : 0
  provider = aws.event-source-account

  name = "/aft/account/aft-management/account-id"
}

# ------------------------------------------------------------------------------
# VCS configuration published by AFT in the AFT management account.
# Only read when the matching input variable is left null. AFT stores the
# literal string "null" for URLs of providers that are not in use.
# ------------------------------------------------------------------------------
data "aws_ssm_parameter" "aft_vcs_provider" {
  count    = var.vcs_provider == null ? 1 : 0
  provider = aws.aft-management
  name     = "/aft/config/vcs/provider"
}
data "aws_ssm_parameter" "aft_github_enterprise_url" {
  count    = local.vcs.is_github_enterprise && var.github_enterprise_url == null ? 1 : 0
  provider = aws.aft-management
  name     = "/aft/config/vcs/github-enterprise-url"
}
data "aws_ssm_parameter" "aft_gitlab_selfmanaged_url" {
  count    = local.vcs.is_gitlab_selfmanaged && var.gitlab_selfmanaged_url == null ? 1 : 0
  provider = aws.aft-management
  name     = "/aft/config/vcs/gitlab-selfmanaged-url"
}
