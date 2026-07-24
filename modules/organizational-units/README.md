# Organizational Units Module

Manages AWS Organizations Organizational Units (OUs) with automatic Control Tower baseline registration. This module handles creation of nested OUs and automatic enablement of AWSControlTowerBaseline and optional BackupBaseline on all managed OUs.

## Features

- Hierarchical OU management: create root OUs and nested child OUs
- Automatic Control Tower baseline discovery from the CT home region
- Baseline enablement on root and child OUs with dependency ordering
- Optional BackupBaseline support
- Dynamic baseline parameters (Identity Center support)
- Output of discovered baseline IDs for reference

## Usage

```hcl
# Pin to a specific version by updating the ref tag
# ref format: organizational-units-<version>
# Example: organizational-units-v1.0

module "organizational_units" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/organizational-units?ref=organizational-units-v1.0"

  ct_home_region       = var.ct_home_region
  ct_baseline_version  = "3.3"
  enable_backup        = true
  organizational_units = var.organizational_units
  root_ous             = aws_organizations_organizational_unit.root
}

# To use a different version, update the ref:
# source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/organizational-units?ref=organizational-units-v1.1"
```

## Module Architecture

This module is designed to work alongside root-level OU creation in the root module:

1. **Root OUs** are created in the root module's `main.tf` (not in this module) to prevent circular dependencies with the `control_tower` module
2. **Child OUs** are created by this module, nested under root OUs via the `parent_key` reference
3. **Baselines** are auto-discovered and applied to both root and child OUs

The root module passes `aws_organizations_organizational_unit.root` to this module via `var.root_ous`.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 6.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 6.0 |
| external | (latest) |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `ct_home_region` | AWS region where Control Tower is deployed. | `string` | | yes |
| `ct_baseline_version` | Version of the AWSControlTowerBaseline to enable on OUs. | `string` | | yes |
| `enable_backup` | Whether to enable BackupBaseline on each OU (requires AWSControlTowerBaseline first). | `bool` | `false` | no |
| `organizational_units` | Full OU map (same shape as root variable). Used to derive child OUs. Each OU object has `name` (required), `parent_id` (optional), and `parent_key` (optional). Child OUs are identified by a non-null `parent_key`. | `map(object({`<br/>&nbsp;&nbsp;`name       = string`<br/>&nbsp;&nbsp;`parent_id  = optional(string)`<br/>&nbsp;&nbsp;`parent_key = optional(string)`<br/>`}))` | | yes |
| `root_ous` | Map of already-created root-level OUs, keyed by the same logical keys used in `var.organizational_units`. Each value must expose at minimum `{ id, arn }`. Passed from `aws_organizations_organizational_unit.root` in the root module. | `map(object({`<br/>&nbsp;&nbsp;`id  = string`<br/>&nbsp;&nbsp;`arn = string`<br/>`}))` | | yes |

## Outputs

| Name | Description |
|------|-------------|
| `child_ous` | Map of child OU logical key to `{ id, arn, name }`. Useful for referencing child OUs created by this module. |
| `baseline_ids` | Discovered baseline name → ID map for the CT home region. Includes all baselines available in the Control Tower home region (e.g., `AWSControlTowerBaseline`, `BackupBaseline`, `IdentityCenterBaseline`). |

## Notes

- Baseline discovery uses an external data source that calls `aws controltower list-baselines` and `aws controltower list-enabled-baselines`. The AWS CLI must be configured and accessible in the Terraform execution environment.
- The `IdentityCenterEnabledBaselineArn` parameter is automatically populated if Identity Center is already enabled in the Control Tower landing zone.
- Dependency ordering ensures root baselines are applied before child OUs, and child baselines follow parent baselines.
- The module requires root OUs to already exist; it does not create them. Root OU creation is managed in the root module to prevent circular dependencies.

## Example Configuration

```hcl
# variables.tf
variable "organizational_units" {
  type = map(object({
    name       = string
    parent_id  = optional(string)
    parent_key = optional(string)
  }))
}

# terraform.tfvars or locals
organizational_units = {
  security = {
    name = "Security"
  }
  workloads = {
    name = "Workloads"
  }
  dev = {
    name       = "Development"
    parent_key = "workloads"  # Nests under workloads OU
  }
  prod = {
    name       = "Production"
    parent_key = "workloads"  # Nests under workloads OU
  }
}
```

In this example:
- `security` and `workloads` are root OUs (no `parent_key`)
- `dev` and `prod` are child OUs nested under `workloads`
- All OUs receive the AWSControlTowerBaseline
- If `enable_backup = true`, all OUs also receive the BackupBaseline
