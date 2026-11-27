# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

variable "solution_name" {
  description = "Solution name. Used for naming pipeline infrastructure resources (CodePipeline, CodeBuild, IAM roles, artifact bucket). Does NOT affect the Terraform state backend bucket."
  type        = string
  default     = "aws-identity-mgmt"
}

variable "repository_name" {
  description = "VCS repository name. For external VCS, inform the full repository path (e.g. GitHubOrganization/repository-name)."
  type        = string
  default     = "aws-ps-pipeline"
}

variable "branch_name" {
  description = "Repository main branch name."
  type        = string
  default     = "main"
}

variable "vcs_provider" {
  description = <<-EOT
    VCS provider: codecommit, github, githubenterprise, gitlab, or gitlabselfmanaged.
    Leave null (default) to read it from the AFT management account SSM parameter
    /aft/config/vcs/provider via the aws.aft-management provider.
  EOT
  type        = string
  default     = null
  validation {
    condition     = var.vcs_provider == null || contains(["codecommit", "github", "githubenterprise", "gitlab", "gitlabselfmanaged"], coalesce(var.vcs_provider, "x"))
    error_message = "Valid values for vcs_provider are: codecommit, github, githubenterprise, gitlab, gitlabselfmanaged (or null to read from AFT SSM)."
  }
}
variable "github_enterprise_url" {
  description = <<-EOT
    GitHub Enterprise Server URL, scheme and host only (used when vcs_provider = githubenterprise).
    Leave null (default) to read it from /aft/config/vcs/github-enterprise-url in the AFT management account.
  EOT
  type        = string
  default     = null
}
variable "gitlab_selfmanaged_url" {
  description = <<-EOT
    GitLab self-managed URL, scheme and host only (used when vcs_provider = gitlabselfmanaged).
    Leave null (default) to read it from /aft/config/vcs/gitlab-selfmanaged-url in the AFT management account.
  EOT
  type        = string
  default     = null
}
variable "enable_vpc_config" {
  description = "Enable VPC configuration for CodeBuild project and CodeConnections Host."
  type        = bool
  default     = false
}

variable "vpc_config" {
  description = "VPC configuration to set to CodeBuild project and CodeConnections Host. (enable_vpc_config must be true)"
  type = object({
    vpc_id          = string
    subnets         = list(string)
    security_groups = list(string)
  })
  default = {
    vpc_id          = ""
    subnets         = []
    security_groups = []
  }
}

variable "account_lifecycle_events_source" {
  description = <<-EOF
    Define from where to capture account lifecycle events: AFT, Control Tower (CT) or None.
    Based on this choice, you also must change the provider for the source account (aws.event-source-account).
    For exemple:

      - For AFT as the source account, inform the provider with access to AFT management account:
        ```
          providers = {
            aws.event-source-account = aws.aft-management
          }
        ```

      - For CT as the source account, inform the provider with access to CT management account:
        ```
          providers = {
            aws.event-source-account = aws.org-management
          }
        ```

      - If you don't want to use account lifecycle events to trigger the pipeline, select None and inform the aws default provider:
        ```
          providers = {
            aws.event-source-account = aws
          }
    ```
  EOF
  type        = string
  default     = "None"
  validation {
    condition     = contains(["AFT", "CT", "None"], var.account_lifecycle_events_source)
    error_message = "Valid values for account_lifecycle_events_source are: AFT, CT or None"
  }
}

variable "terraform_version" {
  description = "Terraform version to install in the CodeBuild pipeline."
  type        = string
  default     = "1.15.0"
}

variable "enable_manual_approval" {
  description = "Enable a manual approval step between plan and apply stages in the pipeline."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
