# AFT Landing Zone Pipeline Module

A Terraform module that provisions a self-managing CI/CD pipeline for AWS Control Tower Account Factory for Terraform (AFT) bootstrap repositories. The pipeline automates Terraform deployments of Control Tower, Organizations, AFT, and infrastructure as code across your AWS organization.

## Features

- **Dual VCS Support**: Works with both GitHub (CodeStarSourceConnection) and AWS CodeCommit
- **Flexible Workflow**: Choose between manual approval workflow (plan → review → apply) or fully automated (combined plan+apply)
- **Cross-Account Execution**: CodeBuild runs Terraform in the Control Tower management account with proper role assumption
- **Auto VCS Detection**: Automatically detects VCS provider from AFT SSM parameters
- **Artifact Management**: Integrated S3 bucket for pipeline artifacts with versioning and lifecycle policies
- **Comprehensive Logging**: CloudWatch log groups for build visibility and troubleshooting
- **Optional Triggers**: Control whether the pipeline triggers automatically on commits

## Usage

```hcl
module "landing_zone_pipeline" {
  # Pin to v1.0 or use a newer version by updating the ref
  # Format: <module-name-with-dashes>-<version>
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/aft/landing-zone-pipeline?ref=aft-landing-zone-pipeline-v1.0"

  providers = {
    aws                = aws.aft-management
    aws.org-management = aws.ct-management
  }

  ct_home_region              = "eu-central-1"
  ct_management_account_id    = "123456789012"
  aft_management_account_id   = "210987654321"
  customer_name               = "acme"
  github_username             = "acme-org"
  enable_manual_approval      = true
  enable_pipeline_trigger     = true

  tags = {
    Environment = "production"
    Project     = "aft-bootstrap"
  }
}
```

### Alternative: Fully Automated Pipeline (No Approval)

```hcl
module "landing_zone_pipeline" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/aft/landing-zone-pipeline?ref=aft-landing-zone-pipeline-v1.0"

  providers = {
    aws                = aws.aft-management
    aws.org-management = aws.ct-management
  }

  ct_home_region              = "eu-central-1"
  ct_management_account_id    = "123456789012"
  aft_management_account_id   = "210987654321"
  customer_name               = "acme"
  github_username             = "acme-org"
  enable_manual_approval      = false  # Combined plan+apply in one step
  enable_pipeline_trigger     = true

  tags = {
    Environment = "production"
  }
}
```

## Requirements

| Requirement | Version |
|-------------|---------|
| Terraform | >= 1.6.0 |

## Providers

| Name | Version | Description |
|------|---------|-------------|
| aws | >= 6.23.0 | AWS provider for the AFT management account |
| aws.org-management | >= 6.23.0 | AWS provider for the Control Tower / Organizations management account |

**Note**: The module uses provider aliases to support cross-account deployments. Configure the `aws.org-management` provider to assume a role or use credentials in the CT management account.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| ct_home_region | Control Tower home region — used to scope log/resource ARNs. | `string` | — | Yes |
| ct_management_account_id | The Control Tower / Organizations management account ID. CodeBuild assumes a role here to run Terraform. | `string` | — | Yes |
| aft_management_account_id | The AFT management account ID. Pipeline resources live here. | `string` | — | Yes |
| customer_name | Customer/project name prefix for the landing zone repo. Used to construct the repository name and resource identifiers. | `string` | — | Yes |
| github_username | GitHub organization or username that owns the landing zone repo. Read from SSM if not provided. | `string` | `""` | No |
| enable_manual_approval | If true, the pipeline runs Source → Plan → Manual Approval → Apply. If false, it runs Source → Apply (combined plan+apply). | `bool` | `true` | No |
| enable_pipeline_trigger | If true, the pipeline automatically triggers on pushes to the main branch. If false, the pipeline is created but must be triggered manually. | `bool` | `true` | No |
| tf_state_bucket | S3 bucket holding the Terraform state for this repo. If empty, defaults to `terraform-state-terraform-account-factory-{ct_management_account_id}`. | `string` | `""` | No |
| tf_state_key | S3 key (path) of the Terraform state file inside tf_state_bucket. If empty, defaults to `custom-aft-landing-zone/terraform.tfstate`. | `string` | `""` | No |
| ct_management_role_name | Name of the IAM role in the CT management account that CodeBuild assumes to run Terraform. | `string` | `"landing-zone-pipeline-execution"` | No |
| tags | Tags to apply to all resources. | `map(string)` | `{ "product" = "landing-zone", "created-by" = "AFT" }` | No |

## Outputs

| Name | Description |
|------|-------------|
| pipeline_name | The name of the CodePipeline. |
| pipeline_arn | The ARN of the CodePipeline. |
| pipeline_execution_role_arn | The ARN of the CodePipeline execution role. |
| codebuild_plan_project_name | The name of the CodeBuild plan project (only created when `enable_manual_approval = true`). |
| codebuild_apply_project_name | The name of the CodeBuild apply project. |
| codebuild_role_arn | The ARN of the CodeBuild execution role. |
| artifacts_bucket_name | The name of the S3 bucket used for pipeline artifacts. |
| artifacts_bucket_arn | The ARN of the S3 bucket used for pipeline artifacts. |
| ct_execution_role_arn | The ARN of the cross-account execution role in the CT management account. |
| ct_execution_role_name | The name of the cross-account execution role in the CT management account. |

## Architecture

The module creates the following infrastructure:

1. **CodePipeline (V2)**: Main orchestrator living in the AFT account
   - Supports automatic triggering for GitHub and CodeCommit repositories
   - Stages: Source → [Plan] → [Approval] → Apply (brackets indicate optional stages)

2. **CodeBuild Projects**: In the AFT account, assume cross-account role to execute Terraform
   - Plan project: `terraform plan` (created only with `enable_manual_approval = true`)
   - Apply project: `terraform apply` or combined `init+plan+apply`

3. **S3 Artifact Bucket**: In the AFT account for storing Terraform plans and build logs
   - Versioning enabled
   - 14-day expiration for artifacts, 7-day for noncurrent versions
   - Public access blocked

4. **IAM Roles**:
   - CodeBuild role (AFT account): Can assume cross-account CT role and write logs
   - CodePipeline role (AFT account): Can orchestrate builds and access artifacts
   - EventBridge role (AFT account, CodeCommit only): Can trigger pipeline
   - Cross-account execution role (CT account): Has AdministratorAccess to manage Control Tower, Organizations, and AFT

5. **VCS Integration**:
   - GitHub: Uses CodeStarSourceConnection (from SSM `/aft/config/vcs/codeconnections-connection-arn`)
   - CodeCommit: Uses EventBridge for branch push detection

6. **CloudWatch Logs**: Separate log groups for plan and apply builds (365-day retention)

## Prerequisites

### AFT Account

- Terraform >= 1.6.0
- AWS provider with credentials for the AFT management account
- AWS provider alias `aws.org-management` configured for the CT management account

### GitHub (if using GitHub for VCS)

- A CodeStarSourceConnection stored in SSM at `/aft/config/vcs/codeconnections-connection-arn`
- A GitHub repository named `{customer_name}-aft-control-tower-account-setup`

### CodeCommit (if using CodeCommit for VCS)

- A CodeCommit repository named `{customer_name}-aft-control-tower-account-setup` in the AFT account
- SSM parameter `/aft/config/vcs/provider` set to `codecommit`

### Control Tower Account

- An IAM role that will be created by this module (default name: `landing-zone-pipeline-execution`)
- Credentials configured for the `aws.org-management` provider

## Notes

- **VCS Provider Auto-detection**: The module reads `/aft/config/vcs/provider` from SSM to determine whether to use GitHub or CodeCommit. This parameter is typically set by AFT.
- **Cross-Account Execution**: All Terraform operations run in the Control Tower management account. The CodeBuild role in the AFT account assumes a role in the CT account for this purpose.
- **Terraform Version**: Currently pinned to `1.15.0` in the module. Modify the `terraform_version` local in `main.tf` to upgrade.
- **State Management**: Terraform state is stored in an S3 bucket in the CT account. Ensure proper backup and state lock configurations are in place.
- **Manual Approval**: When `enable_manual_approval = true`, pipeline deployments require approval before the Apply stage. This is recommended for production environments.
- **Pipeline Trigger**: When `enable_pipeline_trigger = true`, the pipeline automatically triggers on commits to the main branch. Set to `false` for manual-only deployments.

## Security Considerations

- The cross-account execution role in the CT account has `AdministratorAccess`. Limit role assumption to the CodeBuild role in the AFT account.
- S3 artifact bucket blocks all public access and enables versioning to protect build artifacts.
- CloudWatch logs are retained for 365 days. Adjust retention if compliance policies require longer periods.
- Ensure the VCS connection (CodeStarSourceConnection) has appropriate permissions in GitHub.

## License

[Insert your license here]
