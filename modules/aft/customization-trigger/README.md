# AFT Customization Trigger Module

A Terraform module that provisions an automated CI/CD pipeline for AWS Account Factory for Terraform (AFT) account customizations. The module creates a CodePipeline V2 that monitors your global and account-specific customization repositories and automatically triggers the AFT customization step function on code changes.

## Features

- **Automated Triggering**: Watches global-customizations and account-customizations repositories for changes on the main branch
- **Event-Driven Architecture**: Uses CodePipeline V2 with native Git push triggers (no polling required)
- **Step Function Integration**: Automatically invokes `aft-invoke-customizations` with full scope customizations
- **Additive Design**: Extends AFT without modifying any existing AFT resources or configurations
- **IAM Least Privilege**: Narrow, role-specific IAM policies for CodePipeline and CodeBuild
- **Artifact Management**: Includes S3 bucket with automatic lifecycle expiration (1 day)
- **GitHub Integration**: Works with GitHub repositories via CodeStar Connections

## Requirements

- **Terraform**: >= 1.5.0
- **AWS Provider**: >= 6.0.0
- AWS Control Tower with Account Factory for Terraform enabled
- CodeConnections configured in the AFT management account (created by the AFT module)
- Customization repositories available on GitHub with `main` branch

## Usage

```hcl
module "aft_customization_trigger" {
  source = "path/to/modules/aft/customization-trigger"

  ct_home_region              = "us-east-1"
  aft_management_account_id   = "123456789012"
  github_username             = "my-organization"
  customer_name               = "acme"

  tags = {
    "product"    = "aft"
    "created-by" = "AFT"
    "environment" = "prod"
  }
}
```

## How It Works

1. **Repository Monitoring**: The pipeline monitors two repositories:
   - `{github_username}/{customer_name}-aft-global-customizations`
   - `{github_username}/{customer_name}-aft-account-customizations`

2. **Trigger**: When code is pushed to the `main` branch of either repository, CodePipeline automatically starts execution

3. **Build Stage**: CodeBuild retrieves the source code and executes a build that invokes the Step Function

4. **Customization Execution**: The `aft-invoke-customizations` Step Function is triggered with `{"include": [{"type": "all"}]}`, applying all configured customizations

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `ct_home_region` | Control Tower home region where the AFT Step Function is deployed | `string` | N/A | yes |
| `aft_management_account_id` | AWS account ID of the AFT management account (where the Step Function lives) | `string` | N/A | yes |
| `github_username` | GitHub organization or username that owns the AFT repositories | `string` | N/A | yes |
| `customer_name` | Customer/project name prefix used in AFT repository names (e.g., `acme` for `acme-aft-account-customizations`) | `string` | N/A | yes |
| `tags` | Tags to apply to all resources created by this module | `map(string)` | `{"product" = "aft", "created-by" = "AFT"}` | no |

## Outputs

This module does not expose any outputs. Resources are managed internally and trigger the AFT Step Function through the CodePipeline automation.

## Resources Created

| Resource Type | Name | Purpose |
|---|---|---|
| `aws_codepipeline` | `custom-aft-customization-trigger` | V2 pipeline that watches repositories and orchestrates the build stage |
| `aws_codebuild_project` | `custom-aft-customization-trigger` | Build job that invokes the Step Function |
| `aws_iam_role` | `custom-aft-customization-trigger-pipeline` | IAM role for CodePipeline |
| `aws_iam_role` | `custom-aft-customization-trigger-codebuild` | IAM role for CodeBuild |
| `aws_s3_bucket` | `custom-aft-customization-trigger-*` | Artifact storage for pipeline (auto-expires after 1 day) |

## Notes

- This module runs in the AFT management account using the default AWS provider configuration
- The module reads the CodeConnections ARN from SSM Parameter Store path `/aft/config/vcs/codeconnections-connection-arn` (created by the AFT module)
- Pipeline artifacts are automatically cleaned up after 1 day via S3 lifecycle rules
- All resources are tagged with the provided `tags` variable for easy identification and cost allocation

## Integration with AFT

This module is designed as an extension to the official AWS Account Factory for Terraform module. It does not modify any existing AFT resources and can be added or removed independently.

For more information about AFT, see the [Hashicorp Account Factory for Terraform Tutorial](https://developer.hashicorp.com/terraform/tutorials/aws/aws-control-tower-aft).
