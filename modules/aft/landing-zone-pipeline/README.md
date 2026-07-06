# AFT Landing Zone Pipeline Module

A Terraform module that provisions a self-managing AWS CodePipeline for Control Tower and Account Factory for Terraform (AFT) infrastructure automation. The pipeline orchestrates Terraform planning and application in the Control Tower management account from the AFT management account using cross-account role assumption.

## Overview

This module creates a complete CI/CD pipeline for managing Control Tower, Organizations, AFT, and related infrastructure. It supports both GitHub and AWS CodeCommit as source repositories, auto-detects VCS configuration from AFT SSM parameters, and provides flexible execution modes (manual approval or fully automated).

### Key Features

- **Multi-VCS Support**: Automatically detects and configures GitHub (CodeStarSourceConnection) or AWS CodeCommit
- **Flexible Execution**: Choose between manual approval workflow (plan review before apply) or automated mode (combined plan+apply)
- **Cross-Account Execution**: CodeBuild assumes a role in the Control Tower management account to run Terraform
- **Automatic Triggers**: EventBridge integration for CodeCommit or V2 pipeline triggers for GitHub
- **Artifact Management**: S3 bucket with versioning and automatic 14-day lifecycle cleanup
- **Comprehensive Logging**: CloudWatch log groups for plan and apply phases
- **Configuration Auto-Discovery**: Reads VCS provider and CodeConnections ARN from AFT-published SSM parameters

## Usage

### Basic Configuration

```hcl
module "aft_landing_zone_pipeline" {
  source = "./modules/aft/landing-zone-pipeline"

  # Required: AWS account and region configuration
  ct_home_region              = "eu-central-1"
  ct_management_account_id    = "123456789012"
  aft_management_account_id   = "210987654321"
  customer_name               = "acme"

  # Optional: GitHub configuration (if using GitHub as VCS)
  github_username = "acme-org"

  # Optional: Customize Terraform state location
  tf_state_bucket = "my-custom-state-bucket"
  tf_state_key    = "landing-zone/terraform.tfstate"

  # Optional: Manual approval workflow (default: true)
  enable_manual_approval = true

  # Optional: Enable automatic pipeline triggers (default: true)
  enable_pipeline_trigger = true

  # Optional: Custom IAM role name in CT management account
  ct_management_role_name = "landing-zone-execution-role"

  # Optional: Resource tags
  tags = {
    "Environment" = "production"
    "Team"        = "platform"
  }

  # Required: Provider aliases for cross-account access
  providers = {
    aws.org-management = aws.org-management
  }
}
```

### Provider Configuration

Configure two AWS providers in your root module:

```hcl
provider "aws" {
  alias  = "aft-management"
  region = var.ct_home_region
  # Default credentials for AFT management account
}

provider "aws" {
  alias  = "org-management"
  region = var.ct_home_region
  assume_role {
    role_arn = "arn:aws:iam::${var.ct_management_account_id}:role/cross-account-terraform-role"
  }
}

module "aft_landing_zone_pipeline" {
  source = "./modules/aft/landing-zone-pipeline"

  # ... module configuration ...

  providers = {
    aws = aws.aft-management
    aws.org-management = aws.org-management
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 6.0.0 |

### Pre-requisites

- **AFT Bootstrap Complete**: This module expects AFT to have published VCS configuration to SSM parameters (specifically `/aft/config/vcs/provider` and `/aft/config/vcs/codeconnections-connection-arn` for GitHub)
- **Buildspec Files**: The module expects buildspec files to exist at `modules/aft/landing-zone-pipeline/assets/buildspecs/`:
  - `buildspec-plan.yml` — Runs `terraform plan`
  - `buildspec-apply.yml` — Runs `terraform apply <plan-file>`
  - `buildspec-combined.yml` — Runs `terraform init`, `plan`, and `apply` in one build
- **Cross-Account Access**: The CT management account must permit the CodeBuild role (in AFT account) to assume the execution role

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `ct_home_region` | Control Tower home region — used to scope log and resource ARNs. | `string` | — | yes |
| `ct_management_account_id` | The Control Tower / Organizations management account ID. CodeBuild assumes a role here to run Terraform. | `string` | — | yes |
| `aft_management_account_id` | The AFT management account ID. Pipeline resources live here. | `string` | — | yes |
| `customer_name` | Customer/project name prefix for the landing zone repo and resource naming. | `string` | — | yes |
| `github_username` | GitHub organization or username that owns the landing zone repo. If empty, the module expects CodeCommit as the VCS provider. | `string` | `""` | no |
| `enable_pipeline_trigger` | If true, the pipeline automatically triggers on pushes to the main branch. If false, the pipeline is created but must be triggered manually. | `bool` | `true` | no |
| `enable_manual_approval` | If true, the pipeline runs Source → Plan → Manual Approval → Apply. If false, it runs Source → Apply (combined plan+apply in single CodeBuild run). | `bool` | `true` | no |
| `tf_state_bucket` | S3 bucket holding the Terraform state for this repo. If empty, defaults to `terraform-state-terraform-account-factory-{ct_management_account_id}`. | `string` | `""` | no |
| `tf_state_key` | S3 key (path) of the Terraform state file inside `tf_state_bucket`. If empty, defaults to `custom-aft-landing-zone/terraform.tfstate`. | `string` | `""` | no |
| `ct_management_role_name` | Name of the IAM role in the CT management account that CodeBuild assumes to run Terraform. | `string` | `"landing-zone-pipeline-execution"` | no |
| `tags` | Tags to apply to all provisioned resources. | `map(string)` | `{ "product" = "landing-zone", "created-by" = "AFT" }` | no |

## Outputs

| Name | Description |
|------|-------------|
| `codepipeline_arn` | ARN of the CodePipeline resource. |
| `codepipeline_name` | Name of the CodePipeline resource. |
| `codebuild_plan_project_arn` | ARN of the CodeBuild plan project (only created when `enable_manual_approval = true`). |
| `codebuild_apply_project_arn` | ARN of the CodeBuild apply project. |
| `artifact_bucket_name` | Name of the S3 artifact bucket. |
| `artifact_bucket_arn` | ARN of the S3 artifact bucket. |
| `codebuild_role_arn` | ARN of the IAM role assumed by CodeBuild. |
| `pipeline_role_arn` | ARN of the IAM role assumed by CodePipeline. |
| `ct_execution_role_arn` | ARN of the cross-account IAM role in the CT management account. |
| `ct_execution_role_name` | Name of the cross-account IAM role in the CT management account. |

## Architecture

### Pipeline Stages (Manual Approval Mode - Default)

```
Source (GitHub/CodeCommit) → Plan (CodeBuild) → Approval (Manual) → Apply (CodeBuild)
```

1. **Source Stage**: Pulls code from GitHub or CodeCommit repository on branch updates
2. **Plan Stage**: CodeBuild runs `terraform plan` and outputs the plan artifact
3. **Approval Stage**: Manual approval step (30-minute timeout) for plan review
4. **Apply Stage**: CodeBuild applies the approved plan

### Pipeline Stages (Automated Mode)

```
Source (GitHub/CodeCommit) → Apply (CodeBuild)
```

When `enable_manual_approval = false`, the plan and approval stages are skipped. CodeBuild runs `terraform init`, `plan`, and `apply` in a single combined build.

### Cross-Account Execution

- **Pipeline Resources**: CodePipeline, CodeBuild projects, S3 artifacts, and logging live in the **AFT management account**
- **Terraform Execution**: CodeBuild assumes a role in the **Control Tower management account** to run Terraform and manage infrastructure
- **State & Resources**: Terraform state and managed resources are in the **Control Tower management account**

This separation allows the AFT-managed pipeline to safely manage Control Tower, Organizations, and IAM without requiring all credentials in a single account.

### VCS Provider Auto-Detection

The module reads `/aft/config/vcs/provider` from AWS Systems Manager Parameter Store to determine whether to use GitHub or CodeCommit. AFT populates this parameter during bootstrap.

- **GitHub**: Requires CodeConnections ARN from `/aft/config/vcs/codeconnections-connection-arn`
- **CodeCommit**: Uses repository lookup and EventBridge triggers

## Notes

- The cross-account execution role in the CT management account is created with `AdministratorAccess` to manage Control Tower, Organizations, AFT, and IAM resources.
- Artifact bucket versioning is enabled with a 14-day lifecycle expiration policy for cost optimization.
- CloudWatch log groups retain logs for 365 days.
- Pipeline execution mode is set to `SUPERSEDED`, meaning new executions replace previous ones.
- Terraform version 1.15.0 is hardcoded in environment variables for both CodeBuild projects.

## Related Resources

- [AWS Control Tower](https://docs.aws.amazon.com/controltower/)
- [Account Factory for Terraform (AFT)](https://developer.hashicorp.com/terraform/tutorials/aws/aws-control-tower-aft)
- [AWS CodePipeline V2](https://docs.aws.amazon.com/codepipeline/latest/userguide/welcome.html)
- [AWS CodeBuild](https://docs.aws.amazon.com/codebuild/)
