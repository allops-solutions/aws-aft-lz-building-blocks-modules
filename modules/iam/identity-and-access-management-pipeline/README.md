# Identity and Access Management Pipeline Module

A comprehensive Terraform module for deploying an automated IAM management pipeline that orchestrates Terraform deployments across AWS accounts. The module provisions a complete CI/CD infrastructure using AWS CodePipeline, CodeBuild, and EventBridge with support for multiple version control systems and account lifecycle event triggers.

## Features

- **Multi-VCS Support**: Seamlessly integrate with AWS CodeCommit, GitHub, or GitHub Enterprise
- **Account Lifecycle Integration**: Automatically trigger Terraform deployments from AWS Control Tower or Account Factory for Terraform (AFT) account provisioning events
- **Flexible Approval Workflows**: Optional manual approval step between Terraform plan and apply stages
- **VPC Support**: Deploy CodeBuild projects and GitHub Enterprise connections within private VPCs
- **Security-First**: Pre-configured with encryption, versioning, and least-privilege IAM policies
- **State Management**: Dedicated S3 backend for Terraform state with versioning and encryption
- **Artifact Management**: Secure artifact storage with encryption and versioning for pipeline artifacts

## Usage

### Basic Example (GitHub with Manual Approval)

```hcl
module "identity_access_management_pipeline" {
  source = "./modules/iam/identity-and-access-management-pipeline"

  solution_name  = "aws-identity-mgmt"
  repository_name = "my-org/iam-terraform-repo"
  branch_name    = "main"
  vcs_provider   = "github"

  enable_manual_approval           = true
  account_lifecycle_events_source  = "None"
  terraform_version                = "1.15.0"

  tags = {
    Environment = "production"
    Owner       = "platform-team"
  }

  providers = {
    aws.event-source-account = aws
  }
}
```

### AWS Control Tower Integration

```hcl
module "identity_access_management_pipeline" {
  source = "./modules/iam/identity-and-access-management-pipeline"

  solution_name  = "aws-identity-mgmt"
  repository_name = "CodeCommit-Repo-Name"
  branch_name    = "main"
  vcs_provider   = "codecommit"

  enable_manual_approval           = false
  account_lifecycle_events_source  = "CT"
  terraform_version                = "1.15.0"

  tags = {
    Environment = "production"
  }

  providers = {
    aws.event-source-account = aws.ct-management  # Must have access to Control Tower management account
  }
}
```

### AFT (Account Factory for Terraform) Integration

```hcl
module "identity_access_management_pipeline" {
  source = "./modules/iam/identity-and-access-management-pipeline"

  solution_name  = "aws-identity-mgmt"
  repository_name = "my-org/iam-terraform-repo"
  branch_name    = "main"
  vcs_provider   = "github"

  enable_manual_approval           = true
  account_lifecycle_events_source  = "AFT"
  terraform_version                = "1.15.0"

  tags = {
    Environment = "production"
  }

  providers = {
    aws.event-source-account = aws.aft-management  # Must have access to AFT management account
  }
}
```

### VPC-Enabled Deployment (GitHub Enterprise)

```hcl
module "identity_access_management_pipeline" {
  source = "./modules/iam/identity-and-access-management-pipeline"

  solution_name          = "aws-identity-mgmt"
  repository_name        = "my-org/iam-terraform-repo"
  branch_name            = "main"
  vcs_provider           = "githubenterprise"
  github_enterprise_url  = "https://github.my-company.com"

  enable_vpc_config = true
  vpc_config = {
    vpc_id          = aws_vpc.pipeline.id
    subnets         = [aws_subnet.private[0].id, aws_subnet.private[1].id]
    security_groups = [aws_security_group.codebuild.id]
  }

  enable_manual_approval           = true
  account_lifecycle_events_source  = "None"
  terraform_version                = "1.15.0"

  tags = {
    Environment = "production"
  }

  providers = {
    aws.event-source-account = aws
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | ~> 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `solution_name` | Solution name used for naming pipeline infrastructure resources (CodePipeline, CodeBuild, IAM roles, artifact bucket). Does NOT affect the Terraform state backend bucket. | `string` | `"aws-identity-mgmt"` | No |
| `repository_name` | VCS repository name. For external VCS (GitHub/GitHub Enterprise), provide the full repository path (e.g., `GitHubOrganization/repository-name`). For CodeCommit, use the repository name only. | `string` | `"aws-ps-pipeline"` | No |
| `branch_name` | Repository main branch name to trigger the pipeline on. | `string` | `"main"` | No |
| `vcs_provider` | Version control system provider. Valid values: `codecommit`, `github`, or `githubenterprise`. | `string` | `"github"` | No |
| `github_enterprise_url` | GitHub Enterprise Server URL. Required only when `vcs_provider` is set to `githubenterprise`. Example: `https://github.my-company.com`. | `string` | `"null"` | No |
| `enable_vpc_config` | Enable VPC configuration for CodeBuild projects and CodeConnections Host. When enabled, `vpc_config` must be provided. | `bool` | `false` | No |
| `vpc_config` | VPC configuration for CodeBuild projects and GitHub Enterprise CodeConnections. Specify VPC ID, subnets, and security groups. Required only when `enable_vpc_config` is `true`. | <pre>object({<br>  vpc_id          = string<br>  subnets         = list(string)<br>  security_groups = list(string)<br>})</pre> | <pre>{<br>  vpc_id          = ""<br>  subnets         = []<br>  security_groups = []<br>}</pre> | No |
| `account_lifecycle_events_source` | Source of account lifecycle events to trigger the pipeline. Valid values: `AFT` (Account Factory for Terraform), `CT` (AWS Control Tower), or `None` (manual/webhook triggers only). When set to `CT` or `AFT`, configure the `aws.event-source-account` provider accordingly. | `string` | `"None"` | No |
| `terraform_version` | Terraform version to install and use in the CodeBuild pipeline. | `string` | `"1.15.0"` | No |
| `enable_manual_approval` | Enable a manual approval step between the Terraform plan and apply stages in the pipeline. When enabled, plan results must be reviewed and approved before apply proceeds. | `bool` | `true` | No |
| `tags` | Map of tags to apply to all resources created by this module. | `map(string)` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| `codepipeline_name` | Name of the CodePipeline pipeline. |
| `codepipeline_arn` | ARN of the CodePipeline pipeline. |
| `pipeline_bucket_name` | Name of the S3 bucket used for CodePipeline artifacts. |
| `pipeline_bucket_arn` | ARN of the S3 bucket used for CodePipeline artifacts. |
| `tf_backend_bucket_name` | Name of the S3 bucket used for Terraform state backend. |
| `tf_backend_bucket_arn` | ARN of the S3 bucket used for Terraform state backend. |
| `codebuild_plan_project_name` | Name of the CodeBuild project for Terraform plan (only created when `enable_manual_approval` is `true`). |
| `codebuild_apply_project_name` | Name of the CodeBuild project for Terraform apply. |
| `codepipeline_role_arn` | ARN of the IAM role used by CodePipeline. |
| `codebuild_role_arn` | ARN of the IAM role used by CodeBuild. |
| `codecommit_repository_arn` | ARN of the CodeCommit repository (only created when `vcs_provider` is `codecommit`). |
| `codecommit_repository_clone_url_http` | HTTPS clone URL of the CodeCommit repository (only created when `vcs_provider` is `codecommit`). |
| `github_connection_arn` | ARN of the GitHub CodeStar connection (only created when `vcs_provider` is `github`). |
| `github_enterprise_connection_arn` | ARN of the GitHub Enterprise CodeStar connection (only created when `vcs_provider` is `githubenterprise`). |
| `event_bus_arn` | ARN of the EventBridge event bus for account lifecycle events (only created when `account_lifecycle_events_source` is not `None`). |
| `event_bus_name` | Name of the EventBridge event bus for account lifecycle events (only created when `account_lifecycle_events_source` is not `None`). |
| `lambda_function_arn` | ARN of the Lambda function that forwards AFT events to the EventBridge bus (only created when `account_lifecycle_events_source` is `AFT`). |

## Provider Configuration

This module requires the primary `aws` provider and conditionally uses an additional `aws.event-source-account` provider alias depending on the `account_lifecycle_events_source` setting:

- **`account_lifecycle_events_source = "CT"`**: Set `aws.event-source-account` to a provider with access to your AWS Control Tower management account (the organization management account).
  
- **`account_lifecycle_events_source = "AFT"`**: Set `aws.event-source-account` to a provider with access to your AFT management account.

- **`account_lifecycle_events_source = "None"`**: Set `aws.event-source-account` to the default `aws` provider.

### Example Provider Configuration

```hcl
provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "event-source-account"
  region = "us-east-1"
  
  assume_role {
    role_arn = "arn:aws:iam::123456789012:role/CrossAccountPipelineRole"
  }
}

module "pipeline" {
  source = "./modules/iam/identity-and-access-management-pipeline"
  
  account_lifecycle_events_source = "CT"
  # ... other configuration ...
  
  providers = {
    aws.event-source-account = aws.event-source-account
  }
}
```

## How It Works

### Pipeline Flow

1. **Source Stage**: CodePipeline retrieves Terraform configuration from the specified VCS (CodeCommit, GitHub, or GitHub Enterprise)
2. **Plan Stage** (optional): CodeBuild runs `terraform plan` and generates a plan file (only when manual approval is enabled)
3. **Approval Stage** (optional): Manual approval is required to proceed with apply (only when enabled)
4. **Apply Stage**: CodeBuild executes `terraform apply` to deploy infrastructure changes

### Event Triggering

The pipeline can be triggered through multiple mechanisms:

- **Manual Trigger**: Direct execution via AWS Console or AWS CLI
- **VCS Webhook**: Automatic trigger on push to specified branch (GitHub/GitHub Enterprise with V2 pipelines)
- **Control Tower Events**: Automatic trigger on account creation/update (when `account_lifecycle_events_source = "CT"`)
- **AFT Events**: Automatic trigger on AFT account provisioning (when `account_lifecycle_events_source = "AFT"`)
- **CodeCommit**: Automatic trigger on branch update via EventBridge (when using CodeCommit)

### State Management

Terraform state is stored in a dedicated S3 bucket with:
- Automatic versioning enabled for rollback capability
- Server-side encryption using AWS KMS
- Public access completely blocked
- Separate lifecycle from pipeline artifacts

### Security Posture

- **Encryption**: All S3 buckets encrypted with AWS KMS
- **Access Control**: IAM policies follow the principle of least privilege
- **Audit Trail**: S3 versioning and CloudWatch Logs (365-day retention) maintain complete audit history
- **Network Isolation**: Optional VPC deployment for private connectivity
- **Code Scanning**: Checkov annotations embedded for infrastructure security validation

## Terraform Buildspecs

The module uses three buildspec templates located in the `assets/buildspecs` directory:

- **buildspec-plan.yml**: Runs `terraform init`, `terraform validate`, and `terraform plan`
- **buildspec-apply.yml**: Runs `terraform init` and `terraform apply` (used when manual approval is enabled)
- **buildspec-combined.yml**: Runs `terraform init`, `terraform plan`, and `terraform apply` (used when manual approval is disabled)

Each buildspec is dynamically selected based on the `enable_manual_approval` setting.

## Permissions and IAM Roles

This module creates the following IAM roles:

- **CodePipeline Role**: Orchestrates pipeline execution, manages artifacts, and assumes CodeBuild roles
- **CodeBuild Role**: Executes Terraform commands, accesses S3 backends and artifact buckets, manages Identity Center resources
- **EventBridge Trigger Role**: Allows EventBridge rules to start pipeline execution
- **Control Tower Event Role** (CT mode): Captures Control Tower account events and forwards them to the pipeline event bus
- **Lambda Role** (AFT mode): Executes the event forwarder Lambda function and publishes events to the event bus

## Troubleshooting

### Pipeline Not Triggering from Account Lifecycle Events

- Verify the `aws.event-source-account` provider has the correct cross-account role with permissions to read SSM parameters and publish events
- Confirm the `account_lifecycle_events_source` variable matches your event source (AFT or CT)
- Check EventBridge rule patterns match your account IDs

### CodeBuild Failures

- Review CodeBuild logs in CloudWatch Logs at `/aws/codebuild/{solution_name}-plan` or `/aws/codebuild/{solution_name}-apply`
- Verify the Terraform version specified is compatible with your configurations
- Ensure IAM roles have sufficient permissions for your Terraform resources

### GitHub Connection Issues

- Authenticate the CodeStar connection in the AWS Console (required one-time setup)
- For GitHub Enterprise, verify the VPC has outbound access to your GitHub Enterprise URL
- Confirm the repository path format is correct: `Organization/Repository`

## License

Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
SPDX-License-Identifier: Apache-2.0
