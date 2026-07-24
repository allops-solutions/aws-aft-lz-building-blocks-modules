# AFT Customization Trigger Module

This module provisions a CodePipeline V2 that automatically triggers AWS Account Factory for Terraform (AFT) customizations when changes are pushed to the global-customizations or account-customizations repositories.

The pipeline watches for pushes to the `main` branch and invokes the `aft-invoke-customizations` Step Function with `{"include": [{"type": "all"}]}`, enabling seamless deployment of account customizations across your AFT-managed infrastructure.

## Features

- **Automated Triggers**: Monitors both global and account customization repositories for changes
- **VCS Flexibility**: Automatically detects and supports GitHub (CodeStarSourceConnection) or AWS CodeCommit as your VCS provider
- **Zero Configuration**: VCS configuration is auto-detected from AFT-managed SSM parameters
- **Additive Only**: Does not modify any existing AFT resources; runs alongside the AFT module
- **Production-Ready**: Runs in the AFT management account with proper IAM least-privilege policies

## Usage

```hcl
module "aft_customization_trigger" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/aft/customization-trigger?ref=aft-customization-trigger-v1.0"

  ct_home_region             = "eu-central-1"
  aft_management_account_id  = "123456789012"
  customer_name              = "mycompany"
  github_username            = "my-org"  # Only required when using GitHub

  tags = {
    "product"    = "aft"
    "created-by" = "AFT"
    "environment" = "prod"
  }
}
```

### Pinning to a Specific Version

To pin to this version (v1.0) and receive patch updates:

```hcl
source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/aft/customization-trigger?ref=aft-customization-trigger-v1.0"
```

To pin to a future major version (e.g., v2.x.x):

```hcl
source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/aft/customization-trigger?ref=aft-customization-trigger-v2"
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | >= 6.23.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| ct_home_region | Control Tower home region. | `string` | n/a | yes |
| aft_management_account_id | The AWS account ID of the AFT management account where the Step Function lives. | `string` | n/a | yes |
| customer_name | Customer/project name prefix for AFT repo names. | `string` | n/a | yes |
| github_username | GitHub organization or username that owns the AFT repos. Only used when VCS is GitHub. | `string` | `""` | no |
| tags | Tags to apply to all resources. | `map(string)` | `{ "product" = "aft", "created-by" = "AFT" }` | no |

## Outputs

This module does not export any outputs. It manages internal AWS resources (CodePipeline, CodeBuild, IAM roles, S3 bucket, and EventBridge rules) that are referenced by their resource names within AWS.

## Architecture

The module creates the following AWS resources:

- **CodePipeline V2**: Orchestrates the customization trigger workflow
- **CodeBuild Project**: Executes the Step Function invocation
- **S3 Bucket**: Stores pipeline artifacts (expires after 1 day)
- **IAM Roles & Policies**: 
  - CodePipeline service role
  - CodeBuild service role with Step Function execution permissions
  - EventBridge service role (CodeCommit only)
- **EventBridge Rules**: Monitors CodeCommit repositories for branch updates (CodeCommit only)
- **CloudWatch Event Targets**: Routes CodeCommit events to the pipeline

## VCS Provider Support

The module automatically detects your VCS provider from the `/aft/config/vcs/provider` SSM parameter:

### GitHub

- Uses AWS CodeStarSourceConnection for repository access
- Requires the CodeConnections ARN from `/aft/config/vcs/codeconnections-connection-arn` SSM parameter
- Requires `github_username` variable to construct the full repository ID
- Triggers are configured via V2 pipeline trigger blocks

### AWS CodeCommit

- Uses native CodeCommit source provider
- Auto-detects repositories by name pattern: `{customer_name}-aft-global-customizations` and `{customer_name}-aft-account-customizations`
- Uses EventBridge rules to detect pushes to the `main` branch
- `github_username` variable is ignored

## IAM Permissions Required

When applying this module, ensure your Terraform execution role has permissions to create:

- CodePipeline resources
- CodeBuild projects
- CodeCommit repository read permissions (if using CodeCommit)
- CodeStarConnections read permissions (if using GitHub)
- IAM roles and inline policies
- S3 buckets
- EventBridge rules (if using CodeCommit)
- CloudWatch event targets (if using CodeCommit)

## Notes

- The pipeline only monitors the `main` branch in both repositories
- Artifact expiration is set to 1 day; adjust if longer retention is needed
- The CodeBuild environment uses ARM Lambda container (`BUILD_LAMBDA_1GB`) for cost efficiency
- All resources are created with a `custom-` prefix to distinguish them from core AFT components
- The module is safe to apply/destroy without affecting AFT core functionality
