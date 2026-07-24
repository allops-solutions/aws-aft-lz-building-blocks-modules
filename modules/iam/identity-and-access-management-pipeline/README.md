# Identity and Access Management Pipeline Module

This Terraform module automates the deployment of an AWS CodePipeline infrastructure for identity and access management operations. It orchestrates Terraform-based account customizations through a fully managed CI/CD pipeline that integrates with AWS Control Tower or Account Factory for Terraform (AFT) account lifecycle events.

## Features

- **Multi-VCS Support**: Seamlessly integrate with AWS CodeCommit, GitHub, or GitHub Enterprise Server repositories
- **Event-Driven Automation**: Automatically trigger the pipeline on AWS Control Tower account creation/updates or AFT new account events
- **Terraform Automation**: Automated plan and apply stages with optional manual approval gates for governance
- **Flexible Workflows**: Choose between combined plan+apply or separated stages with manual review
- **Secure by Default**: Encrypted S3 buckets, least-privilege IAM roles, and CloudWatch logging
- **VPC Support**: Optional VPC configuration for CodeBuild and CodeConnections hosts
- **Production-Ready**: Includes Terraform state backend, artifact storage, and comprehensive logging

## Usage

```hcl
module "identity_and_access_management_pipeline" {
  # Pin to a specific version for production use:
  # source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/iam/identity-and-access-management-pipeline?ref=iam-identity-and-access-management-pipeline-v1.0"
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/iam/identity-and-access-management-pipeline?ref=iam-identity-and-access-management-pipeline-v1.0"

  solution_name                   = "aws-identity-mgmt"
  repository_name                 = "allops-solutions/aws-ps-pipeline"
  branch_name                     = "main"
  vcs_provider                    = "github"
  account_lifecycle_events_source = "CT"
  terraform_version               = "1.15.0"
  enable_manual_approval          = true

  tags = {
    Environment = "Production"
    Module      = "IdentityManagement"
  }

  providers = {
    aws                      = aws.primary-region
    aws.event-source-account = aws.org-management
  }
}
```

### Event Source Configuration

The module supports three account lifecycle event sources:

- **`"None"`** (default): Manual pipeline triggers only; no automatic event-based triggering
- **`"CT"`**: Captures AWS Control Tower account creation and update events from the management account
- **`"AFT"`**: Captures Account Factory for Terraform events from the AFT management account

When using `"CT"` or `"AFT"`, you must configure the `aws.event-source-account` provider alias to point to the appropriate management account.

### VPC Configuration

To enable VPC connectivity for CodeBuild and CodeConnections hosts:

```hcl
module "identity_and_access_management_pipeline" {
  # ... other configuration ...
  enable_vpc_config = true
  vpc_config = {
    vpc_id          = aws_vpc.main.id
    subnets         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups = [aws_security_group.codebuild.id]
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | >= 6.23.0 |

## Providers

| Name | Version | Alias | Purpose |
|------|---------|-------|---------|
| aws | >= 6.23.0 | — | Default provider for pipeline infrastructure |
| aws | >= 6.23.0 | event-source-account | Provider for the account containing account lifecycle events (AFT or Control Tower management account) |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `solution_name` | Solution name used for naming pipeline infrastructure resources (CodePipeline, CodeBuild, IAM roles, artifact bucket). Does NOT affect the Terraform state backend bucket. | `string` | `"aws-identity-mgmt"` | No |
| `repository_name` | VCS repository name. For external VCS (GitHub/GitHub Enterprise), provide the full repository path (e.g., `GitHubOrganization/repository-name`). For CodeCommit, use the repository name only. | `string` | `"aws-ps-pipeline"` | No |
| `branch_name` | Repository main branch name to monitor for changes. | `string` | `"main"` | No |
| `vcs_provider` | Version control system provider. Valid values: `"codecommit"`, `"github"`, `"githubenterprise"`. | `string` | `"github"` | No |
| `github_enterprise_url` | GitHub Enterprise Server base URL. Required only when `vcs_provider = "githubenterprise"`. | `string` | `"null"` | No |
| `account_lifecycle_events_source` | Event source for account lifecycle triggers. Valid values: `"AFT"` (Account Factory for Terraform), `"CT"` (Control Tower), `"None"` (manual triggers only). | `string` | `"None"` | No |
| `enable_vpc_config` | Enable VPC configuration for CodeBuild projects and CodeConnections hosts. | `bool` | `false` | No |
| `vpc_config` | VPC configuration object containing `vpc_id`, `subnets`, and `security_groups`. Required when `enable_vpc_config = true`. | `object({ vpc_id = string, subnets = list(string), security_groups = list(string) })` | `{ vpc_id = "", subnets = [], security_groups = [] }` | No |
| `terraform_version` | Terraform version to install and use in the CodeBuild pipeline. | `string` | `"1.15.0"` | No |
| `enable_manual_approval` | Enable a manual approval stage between Terraform plan and apply stages. When disabled, plan and apply run sequentially in a single build. | `bool` | `true` | No |
| `tags` | Additional tags to apply to all created resources. | `map(string)` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| `codepipeline_arn` | ARN of the CodePipeline. |
| `codepipeline_name` | Name of the CodePipeline. |
| `event_bus_arn` | ARN of the EventBridge event bus (if `account_lifecycle_events_source != "None"`). |
| `event_bus_name` | Name of the EventBridge event bus (if `account_lifecycle_events_source != "None"`). |
| `pipeline_bucket_name` | Name of the S3 bucket used for CodePipeline artifacts. |
| `tf_backend_bucket_name` | Name of the S3 bucket used for Terraform state backend. |
| `codebuild_plan_project_name` | Name of the CodeBuild plan project (if `enable_manual_approval = true`). |
| `codebuild_apply_project_name` | Name of the CodeBuild apply project. |
| `codecommit_repository_arn` | ARN of the CodeCommit repository (if `vcs_provider = "codecommit"`). |
| `codecommit_repository_clone_url_http` | HTTP clone URL of the CodeCommit repository (if `vcs_provider = "codecommit"`). |

## How It Works

1. **Version Control Integration**: The module monitors a specified branch in your Git repository (CodeCommit, GitHub, or GitHub Enterprise)
2. **Event Triggering**: Optionally triggers on AWS Control Tower or AFT account lifecycle events via EventBridge
3. **Terraform Plan**: Executes `terraform plan` to preview infrastructure changes
4. **Manual Approval** (optional): Requires human review before proceeding with apply
5. **Terraform Apply**: Executes `terraform apply` to provision the infrastructure
6. **Logging**: All pipeline activity is logged to CloudWatch Logs for auditing and troubleshooting

## Security Considerations

- **Encrypted Storage**: Both S3 buckets (pipeline artifacts and Terraform backend) use AWS KMS encryption at rest
- **Versioning Enabled**: S3 buckets maintain version history for disaster recovery
- **Public Access Blocked**: All S3 buckets block public access
- **IAM Least Privilege**: All IAM roles follow the principle of least privilege with minimal required permissions
- **Cross-Account Access**: When using Control Tower or AFT events, cross-account event delivery is restricted to the source management account
- **VPC Isolation**: Optional VPC configuration allows CodeBuild to run in a private network environment

## License

Copyright Amazon.com, Inc. or its affiliates. All rights reserved. SPDX-License-Identifier: Apache-2.0
