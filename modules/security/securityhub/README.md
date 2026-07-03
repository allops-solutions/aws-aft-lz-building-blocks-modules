# Security Hub Module

Terraform module for managing AWS Security Hub organization configuration and finding aggregation.

This module enables centralized Security Hub management across AWS organizations, with support for cross-region finding aggregation and automatic account enrollment.

## Usage

### Central Configuration with All Regions Aggregation

```hcl
module "security_hub" {
  source = "./modules/security/securityhub"

  configuration_type       = "CENTRAL"
  linking_mode             = "ALL_REGIONS"
  auto_enable_accounts     = true
  auto_enable_standards    = true
}
```

### Central Configuration with Specified Regions

```hcl
module "security_hub" {
  source = "./modules/security/securityhub"

  configuration_type       = "CENTRAL"
  linking_mode             = "SPECIFIED_REGIONS"
  specified_regions        = ["us-east-1", "us-west-2", "eu-central-1"]
  auto_enable_accounts     = true
  auto_enable_standards    = true
}
```

### Local Configuration

```hcl
module "security_hub" {
  source = "./modules/security/securityhub"

  configuration_type       = "LOCAL"
  linking_mode             = "NO_REGIONS"
  auto_enable_accounts     = false
  auto_enable_standards    = false
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.62 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| configuration_type | Configuration type for Security Hub. Valid values: `CENTRAL` or `LOCAL` | `string` | n/a | yes |
| linking_mode | Indicates whether to aggregate findings from all available regions or from a specified list. Valid values: `NO_REGIONS`, `ALL_REGIONS`, `SPECIFIED_REGIONS`, `ALL_REGIONS_EXCEPT_SPECIFIED` | `string` | `"NO_REGIONS"` | no |
| specified_regions | List of regions to include or exclude. Required if linking_mode is set to `ALL_REGIONS_EXCEPT_SPECIFIED` or `SPECIFIED_REGIONS` | `list(string)` | `null` | no |
| auto_enable_accounts | Enable automatic enrollment of Security Hub for organization accounts | `bool` | `false` | no |
| auto_enable_standards | Enable automatic enrollment of Security Hub standards for organization accounts | `bool` | `false` | no |

## Outputs

This module does not provide any outputs.

## Notes

- The `configuration_type` is a required variable with no default value. It must be explicitly set to either `CENTRAL` or `LOCAL`.
- When `configuration_type` is set to `LOCAL`, the finding aggregator resource will not be created (count = 0).
- The `specified_regions` variable is optional but becomes required depending on the `linking_mode` configuration:
  - Required when `linking_mode = "SPECIFIED_REGIONS"` or `linking_mode = "ALL_REGIONS_EXCEPT_SPECIFIED"`
  - Ignored when `linking_mode = "NO_REGIONS"` or `linking_mode = "ALL_REGIONS"`
- Standards auto-enabling converts the boolean `auto_enable_standards` to either `"DEFAULT"` (true) or `"NONE"` (false) for the AWS API.
