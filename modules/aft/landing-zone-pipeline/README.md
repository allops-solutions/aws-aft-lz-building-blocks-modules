# AWS AFT Landing Zone Pipeline Module

A Terraform module that provisions a self-managing AWS CodePipeline for the bootstrap repository in AWS Control Tower with Account Factory for Terraform (AFT). The pipeline orchestrates Terraform deployments of Control Tower, AFT, and organizational units (OUs) across accounts using cross-account IAM roles.

## Features

- **Multi-VCS Support**: Automatically detects and integrates with GitHub (via CodeStarSourceConnection) or AWS CodeCommit
- **Flexible Approval Workflows**: Choose between automated deployments or manual approval stages
- **Cross-Account Execution**: CodeBuild assumes a role in the Control Tower management account to run Terraform
- **Pipeline Triggers**: Automatic or manual triggering on repository pushes (with EventBridge support for CodeCommit)
- **Artifact Management**: S3-backed artifact storage with automatic lifecycle expiration
- **Comprehensive Logging**: CloudWatch log groups for audit trails and troubleshooting
- **ARM64 Optimization**: Uses cost-effective ARM64 CodeBuild environments

## Usage

```hcl
module "landing_zone_pipeline" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/aft/landing-zone-pipeline?ref=aft-landing-zone-pipeline-v1.0"

  ct_home_region              = "eu-central-1"
  ct_management_account_id    = "123456789012"
  aft_management_account_id   = "210987654321"
  customer_name               = "acme"
  github_username             = "acme-org"
  
  enable_manual_approval      = true
  enable_pipeline_trigger     = true
  
  tags = {
    "product"    = "landing-zone"
    "created-by" = "AFT"
    "environment" = "prod"
  }

  providers = {
    aws.org-management = aws.org-management
  }
}
```

### Pinning to a Specific Version

To pin to a specific version, update the `ref` parameter:

```hcl
source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/aft/landing-zone-pipeline?ref=aft-landing-zone-pipeline-v1.0"
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | >= 6.23.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `ct_home_region` | Control Tower home region — used to scope log/resource ARNs. | `string` | n/a | yes |
| `ct_management_account_id` | The Control Tower / Organizations management account ID. CodeBuild assumes a role here to run Terraform. | `string` | n/a | yes |
| `aft_management_account_id` | The AFT management account ID. Pipeline resources live here. | `string` | n/a | yes |
| `customer_name` | Customer/project name prefix for the landing zone repo. | `string` | n/a | yes |
| `github_username` | GitHub organization or username that owns the landing zone repo. Read from SSM if not provided. | `string` | `""` | no |
| `enable_pipeline_trigger` | If true, the pipeline automatically triggers on pushes to the main branch. If false, the pipeline is created but must be triggered manually. | `bool` | `true` | no |
| `enable_manual_approval` | If true, the pipeline runs Source → Plan → Manual Approval → Apply. If false, it runs Source → Apply (combined plan+apply). | `bool` | `true` | no |
| `tf_state_bucket` | S3 bucket holding the Terraform state for this repo. Used to grant the cross-account role access to state. | `string` | `""` | no |
| `tf_state_key` | S3 key (path) of the Terraform state file inside `tf_state_bucket`. | `string` | `""` | no |
| `ct_management_role_name` | Name of the IAM role in the CT management account that CodeBuild assumes to run Terraform. | `string` | `"landing-zone-pipeline-execution"` | no |
| `tags` | Tags to apply to all resources. | `map(string)` | `{ "product" = "landing-zone", "created-by" = "AFT" }` | no |

## Outputs

| Name | Description |
|------|-------------|
| `pipeline_name` | The name of the CodePipeline. |
| `pipeline_arn` | The ARN of the CodePipeline. |
| `artifacts_bucket_name` | The name of the S3 bucket used for pipeline artifacts. |
| `codebuild_plan_project_name` | The name of the CodeBuild plan project (only created when `enable_manual_approval = true`). |
| `codebuild_apply_project_name` | The name of the CodeBuild apply project. |
| `codebuild_role_arn` | The ARN of the IAM role used by CodeBuild projects. |
| `pipeline_role_arn` | The ARN of the IAM role used by CodePipeline. |
| `ct_execution_role_arn` | The ARN of the cross-account execution role in the Control Tower management account. |

## Architecture

### Pipeline Stages (with manual approval enabled)

```
Source → Plan → Manual Approval → Apply
```

The pipeline detects code changes in the landing zone repository and triggers a Terraform workflow:

1. **Source**: Retrieves the latest code from the VCS provider (GitHub or CodeCommit)
2. **Plan**: Runs `terraform plan` in the CT management account (visible in CloudWatch logs)
3. **Manual Approval**: Requires explicit approval before proceeding to apply
4. **Apply**: Runs `terraform apply` with the saved plan

### Pipeline Stages (with manual approval disabled)

```
Source → Apply
```

The combined apply stage runs `terraform init`, `terraform plan`, and `terraform apply` in a single CodeBuild execution.

### Cross-Account Role Assumption

- **AFT Account**: CodeBuild assumes the `aws_iam_role.codebuild` role to read artifacts and write logs
- **CT Management Account**: CodeBuild role assumes the `aws_iam_role.ct_execution` role (with AdministratorAccess) to run Terraform

This separation ensures Terraform state and resources remain in the Control Tower management account while the pipeline infrastructure lives in the AFT management account.

## VCS Configuration

The module automatically detects the VCS provider from SSM parameter store:

- **GitHub**: Reads `/aft/config/vcs/codeconnections-connection-arn` for the CodeStarSourceConnection ARN
- **CodeCommit**: Uses EventBridge to trigger the pipeline on repository pushes

Both configurations require SSM parameter `/aft/config/vcs/provider` to be set by AFT.

## Prerequisites

1. **SSM Parameters** (set by AFT):
   - `/aft/config/vcs/provider`: Must be either "github" or "codecommit"
   - `/aft/config/vcs/codeconnections-connection-arn`: Required if using GitHub

2. **AWS Accounts**:
   - Separate AFT management account and Control Tower management account
   - Cross-account IAM permissions already configured by AFT

3. **Terraform Backend** (optional):
   - If not specified, the module uses the default AFT state bucket
   - Override with `tf_state_bucket` and `tf_state_key` variables

## Notes

- The module requires two AWS provider aliases: `aws` (default, for AFT account) and `aws.org-management` (for Control Tower management account)
- CodeBuild projects use ARM64 (aarch64) environments for cost optimization
- S3 artifacts expire after 14 days; noncurrent versions expire after 7 days
- CloudWatch logs are retained for 365 days
- The pipeline uses CodePipeline V2 with SUPERSEDED execution mode (latest execution supersedes earlier ones)
