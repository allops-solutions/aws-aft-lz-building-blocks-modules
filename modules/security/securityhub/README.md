# security/securityhub

Terraform module for managing AWS Security Hub at the organization level. This module configures cross-region finding aggregation and automatic enrollment of member accounts.

When `configuration_type` is set to `CENTRAL`, a finding aggregator is created to consolidate findings across regions. The module also manages organization-wide settings for automatic account enrollment and default standards enablement.

## Usage

```hcl
module "securityhub" {
  source = "./modules/security/securityhub"

  configuration_type    = "CENTRAL"
  linking_mode          = "ALL_REGIONS"
  auto_enable_accounts  = true
  auto_enable_standards = true
}
```

### LOCAL mode (no cross-region aggregation)

```hcl
module "securityhub" {
  source = "./modules/security/securityhub"

  configuration_type = "LOCAL"
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.62 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| configuration_type | Configuration type for Security Hub. Valid values are `CENTRAL` or `LOCAL`. | `string` | n/a | yes |
| linking_mode | Indicates whether to aggregate findings from all of the available Regions or from a specified list. Valid values are `NO_REGIONS`, `ALL_REGIONS`, `SPECIFIED_REGIONS`, or `ALL_REGIONS_EXCEPT_SPECIFIED`. | `string` | `"NO_REGIONS"` | no |
| specified_regions | List of regions to include or exclude (required if linking_mode is set to `ALL_REGIONS_EXCEPT_SPECIFIED` or `SPECIFIED_REGIONS`). | `list(string)` | `null` | no |
| auto_enable_accounts | Enable auto enable Security Hub for organization accounts. | `bool` | `false` | no |
| auto_enable_standards | Enable auto enable Security Hub standards for organization accounts. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| — | This module does not currently export any outputs. |

## Notes

- This module must be applied in the Security Hub delegated administrator account (or the management account).
- The finding aggregator resource is only created when `configuration_type` is set to `CENTRAL`.
- When using `SPECIFIED_REGIONS` or `ALL_REGIONS_EXCEPT_SPECIFIED` linking modes, you must provide the `specified_regions` variable.
