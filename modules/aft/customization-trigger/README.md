# AFT Customization Trigger Module

Automatically trigger Account Factory for Terraform (AFT) customizations on repository pushes.

## Overview

This module creates a CodePipeline V2 that watches the global-customizations and account-customizations repositories for pushes and automatically invokes the `aft-invoke-customizations` Step Function. The pipeline supports both GitHub (via CodeStarSourceConnection) and CodeCommit as source repositories.

The module automatically detects the VCS provider from AFT's SSM configuration and configures the appropriate source control integration. It runs in the AFT management account and is fully additive—it does not modify any existing AFT resources.

## Usage

```hcl
module "customization_trigger" {
  source = "./modules/aft/customization-trigger"

  ct_home_region             = "us-east-1"
  aft_management_account_id  = "123456789012"
  customer_name              = "acme"
  github_username            = "acme-org"  # Required only for GitHub

  tags = {
    "product"    = "aft"
    "created-by" = "AFT"
    "environment" = "prod"
  }
}
```

## Requirements

| Requirement | Version |
|-------------|---------|
| Terraform  | >= 1.5.0 |
| AWS Provider | >= 6.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `ct_home_region` | Control Tower home region. | `string` | — | yes |
| `aft_management_account_id` | The AWS account ID of the AFT management account where the Step Function lives. | `string` | — | yes |
| `customer_name` | Customer/project name prefix for AFT repo names. Used to construct repository names as `{customer_name}-aft-global-customizations` and `{customer_name}-aft-account-customizations`. | `string` | — | yes |
| `github_username` | GitHub organization or username that owns the AFT repos. Only used when VCS provider is GitHub. | `string` | `""` | no |
| `tags` | Tags to apply to all resources. | `map(string)` | `{ "product" = "aft", "created-by" = "AFT" }` | no |

## Outputs

This module does not declare any outputs.

## Details

### VCS Provider Detection

The module automatically detects the VCS provider from the `/aft/config/vcs/provider` SSM parameter (published by AFT). Based on the provider:

- **GitHub**: Uses CodeStarSourceConnection for repository access and V2 pipeline triggers
- **CodeCommit**: Uses CodeCommit source actions and EventBridge rules for push triggers

### Resources Created

- **CodePipeline V2**: Named `custom-aft-customization-trigger`, with Source and Invoke-Customizations stages
- **CodeBuild Project**: Invokes the `aft-invoke-customizations` Step Function with `{"include": [{"type": "all"}]}`
- **S3 Bucket**: Stores pipeline artifacts (expires after 1 day)
- **IAM Roles and Policies**:
  - CodePipeline role with permissions for source, CodeBuild, and S3
  - CodeBuild role with permissions to start Step Function executions and write logs
  - EventBridge role (CodeCommit only) to start pipeline executions
- **EventBridge Rules** (CodeCommit only): Monitors both customization repositories for pushes to the main branch

### Supported Source Repositories

The module monitors two repositories:

1. `{customer_name}-aft-global-customizations` — Global customizations
2. `{customer_name}-aft-account-customizations` — Account-specific customizations

Pushes to the `main` branch trigger an immediate pipeline execution, which invokes AFT customizations for all accounts.

## Prerequisites

- AFT is deployed and the `aft-invoke-customizations` Step Function exists
- For GitHub: CodeStarConnection ARN is published at `/aft/config/vcs/codeconnections-connection-arn` in SSM
- For CodeCommit: Both customization repositories exist in the same account
- The provider is configured to target the AFT management account

## Architecture Notes

- Pipeline runs in the AFT management account only (uses default provider)
- This module is fully non-destructive and does not interact with AFT core resources
- Artifacts are automatically cleaned up via S3 lifecycle policy
- CodeBuild uses ARM-based Lambda container for cost efficiency
