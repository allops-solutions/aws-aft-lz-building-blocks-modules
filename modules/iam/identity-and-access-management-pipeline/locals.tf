# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

locals {
  # Explicit variable wins, otherwise the value AFT published in SSM.
  vcs_provider = lower(trimspace(var.vcs_provider != null ? var.vcs_provider : data.aws_ssm_parameter.aft_vcs_provider[0].value))
  vcs = {
    is_codecommit         = local.vcs_provider == "codecommit"
    is_github             = local.vcs_provider == "github"
    is_github_enterprise  = local.vcs_provider == "githubenterprise"
    is_gitlab             = local.vcs_provider == "gitlab"
    is_gitlab_selfmanaged = local.vcs_provider == "gitlabselfmanaged"
  }
  # "null" is how AFT stores an unused URL in SSM; normalise it (and "") to null.
  _github_enterprise_url_raw  = var.github_enterprise_url != null ? var.github_enterprise_url : (local.vcs.is_github_enterprise ? data.aws_ssm_parameter.aft_github_enterprise_url[0].value : "null")
  _gitlab_selfmanaged_url_raw = var.gitlab_selfmanaged_url != null ? var.gitlab_selfmanaged_url : (local.vcs.is_gitlab_selfmanaged ? data.aws_ssm_parameter.aft_gitlab_selfmanaged_url[0].value : "null")
  github_enterprise_url       = contains(["", "null"], trimspace(local._github_enterprise_url_raw)) ? null : trimsuffix(trimspace(local._github_enterprise_url_raw), "/")
  gitlab_selfmanaged_url      = contains(["", "null"], trimspace(local._gitlab_selfmanaged_url_raw)) ? null : trimsuffix(trimspace(local._gitlab_selfmanaged_url_raw), "/")

  codeconnection_arn = (
    local.vcs.is_github ? aws_codeconnections_connection.github[0].arn :
    local.vcs.is_github_enterprise ? aws_codeconnections_connection.githubenterprise[0].arn :
    local.vcs.is_gitlab ? aws_codeconnections_connection.gitlab_com[0].arn :
    local.vcs.is_gitlab_selfmanaged ? aws_codeconnections_connection.gitlab[0].arn :
    null
  )
  event_rule_account_id = var.account_lifecycle_events_source == "CT" ? data.aws_organizations_organization.org[0].master_account_id : (var.account_lifecycle_events_source == "AFT" ? data.aws_ssm_parameter.aft_management_account_id[0].value : null)
}
