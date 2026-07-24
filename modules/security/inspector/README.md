# Amazon Inspector Organization Module

Enables and manages Amazon Inspector at organization scale using AWS Organizations policies. This module automates the deployment of Inspector scan enablement across organizational units and manages delegated administrator registration.

## Usage

```hcl
module "inspector" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/security/inspector?ref=security-inspector-v1.0"

  delegated_admin_account_id = var.inspector_delegated_admin_account_id
  primary_region             = var.aws_region

  ec2_scanning_enabled    = true
  ecr_scanning_enabled    = true
  lambda_standard_scanning_enabled = true

  organizational_units = [
    { path = ["Workloads", "Prod"] },
    { path = ["Workloads", "NonProd"] }
  ]

  tags = var.tags

  providers = {
    aws.org-management = aws.org-management
  }
}

# To pin to a specific version:
# source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/security/inspector?ref=security-inspector-v1.0"
```

## Requirements

### Terraform Version

- Terraform >= 1.0

### Providers

| Name | Version | Alias |
|------|---------|-------|
| aws | >= 6.23.0 | org-management |

The `aws.org-management` provider alias must be configured to authenticate as the AWS Organizations management account.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| delegated_admin_account_id | Account ID to register as the Amazon Inspector delegated administrator for the organization. | `string` | | yes |
| primary_region | Primary AWS Region where Amazon Inspector is enabled. | `string` | | yes |
| tags | Tags to apply to all resources. Passed in from the root module. | `map(string)` | | yes |
| enable_secondary_region | Whether to also enable Amazon Inspector in the secondary Region. | `bool` | `false` | no |
| secondary_region | Secondary AWS Region where Amazon Inspector is enabled. Only used when enable_secondary_region is true. | `string` | `""` | no |
| additional_regions | Additional AWS Regions, beyond the primary and secondary Region, where Amazon Inspector is enabled. | `list(string)` | `[]` | no |
| ec2_scanning_enabled | Enable Amazon Inspector EC2 instance scanning across the included organizational units and Regions. | `bool` | `false` | no |
| ecr_scanning_enabled | Enable Amazon Inspector ECR container image scanning across the included organizational units and Regions. | `bool` | `false` | no |
| lambda_standard_scanning_enabled | Enable Amazon Inspector Lambda function (package vulnerability) scanning across the included organizational units and Regions. | `bool` | `false` | no |
| lambda_code_scanning_enabled | Enable Amazon Inspector Lambda function code scanning across the included organizational units and Regions. | `bool` | `false` | no |
| code_repository_scanning_enabled | Enable Amazon Inspector code repository scanning across the included organizational units and Regions. | `bool` | `false` | no |
| organizational_units | Organizational units where Amazon Inspector scanning is enabled. Each entry's `path` is the list of OU names from the top level down to the target OU (e.g. `["Workloads"]` for a top-level OU, or `["Workloads", "NonProd"]` for an OU nested one level below it). Paths up to 3 levels deep are supported. | `list(object({ path = list(string) }))` | `[{ path = ["Workloads", "Prod"] }, { path = ["Workloads", "NonProd"] }]` | no |
| excluded_account_ids | Individual account IDs to explicitly exclude from Amazon Inspector scanning, even when they belong to an included organizational unit. | `list(string)` | `[]` | no |
| ecr_rescan_window | Duration window for Amazon Inspector ECR continuous re-scanning. Controls how long images are re-scanned after being pushed or after last use. Valid values: DAYS_3, DAYS_14, DAYS_30, DAYS_60, DAYS_90, DAYS_180, LIFETIME. | `string` | `"DAYS_3"` | no |

## Outputs

| Name | Description |
|------|-------------|
| delegated_admin_account_id | Account ID registered as the Amazon Inspector delegated administrator. |
| regions | Regions where Amazon Inspector enablement policies are managed. |
| enable_policy_id | ID of the Amazon Inspector enablement policy, or null when no scan type is enabled. |
| association_targets | Organizational unit IDs that the enablement policies are attached to. |

## Features

- **Organization-wide enablement**: Uses AWS Organizations policies to enable Inspector across multiple organizational units automatically
- **Flexible region support**: Configure primary, secondary, and additional regions for Inspector deployment
- **Multiple scan types**: Independently enable EC2, ECR, Lambda standard, Lambda code, and code repository scanning
- **OU path resolution**: Supports OU hierarchy with paths up to 3 levels deep for flexible targeting
- **Account exclusions**: Explicitly exclude specific accounts from Inspector scanning through account-level override policies
- **Delegated administrator**: Automatically registers and activates a delegated administrator account
- **ECR re-scanning configuration**: Configurable continuous re-scanning window for ECR image vulnerability detection
- **Automatic policy management**: Only creates and manages policies for enabled scan types, keeping the configuration minimal

## How It Works

1. **OU Resolution**: The module resolves organizational unit names to IDs by traversing the OU hierarchy (up to 3 levels deep)
2. **Policy Creation**: Creates an Inspector enablement policy containing only the enabled scan types for the configured regions
3. **OU Attachment**: Attaches the enablement policy to the resolved organizational units
4. **Account Exclusions**: For excluded accounts, creates and attaches a disable policy that overrides the OU-level enablement
5. **Delegated Admin**: Registers the specified account as the delegated administrator and activates Inspector in all managed regions
6. **ECR Configuration**: Applies ECR re-scanning configuration via AWS CLI to ensure consistent re-scanning behavior

## Provider Configuration

This module requires the `aws.org-management` provider alias to be configured in your root module:

```hcl
provider "aws" {
  alias = "org-management"
  # Configure with the management account credentials
  # This could be a separate assume_role configuration
}
```

Pass the provider to the module:

```hcl
module "inspector" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/security/inspector?ref=security-inspector-v1.0"

  # ... other configuration ...

  providers = {
    aws.org-management = aws.org-management
  }
}
```
