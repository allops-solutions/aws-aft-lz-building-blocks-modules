# Organizational Units Module

Manages AWS organizational units (OUs) for AWS Control Tower, including OU creation, baseline discovery, and automated Control Tower baseline enrollment.

## Overview

This module handles:
- Creation of child OUs nested under root organizational units
- Automatic discovery of Control Tower baseline definitions (AWSControlTowerBaseline, BackupBaseline, etc.)
- Detection of currently-enabled baselines (e.g., Identity Center)
- Enrollment of AWSControlTowerBaseline on all root and child OUs
- Optional enrollment of BackupBaseline when enabled
- Proper dependency sequencing to ensure baselines are applied in the correct order

Root OUs are created in the parent module to avoid circular dependencies with the Control Tower module.

## Usage

```hcl
module "organizational_units" {
  source = "./modules/organizational-units"

  ct_home_region       = var.ct_home_region
  ct_baseline_version  = "1.0"
  enable_backup        = true

  root_ous = {
    security = aws_organizations_organizational_unit.security
    workloads = aws_organizations_organizational_unit.workloads
  }

  organizational_units = {
    security = {
      name       = "Security"
      parent_id  = null
      parent_key = null
    }
    workloads = {
      name       = "Workloads"
      parent_id  = null
      parent_key = null
    }
    development = {
      name       = "Development"
      parent_id  = aws_organizations_organizational_unit.workloads.id
      parent_key = "workloads"
    }
    staging = {
      name       = "Staging"
      parent_id  = aws_organizations_organizational_unit.workloads.id
      parent_key = "workloads"
    }
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 6.0.0 |

**Note:** The AWS provider version >= 6.0.0 is required for `aws_controltower_landing_zone` and baseline resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| ct_home_region | AWS region where Control Tower is deployed. | `string` | | yes |
| ct_baseline_version | Version of the AWSControlTowerBaseline to enable on OUs. | `string` | | yes |
| enable_backup | Whether to enable BackupBaseline on each OU. Requires AWSControlTowerBaseline to be enabled first. | `bool` | `false` | no |
| organizational_units | Full OU map defining both root and child organizational units. Used to derive child OUs for creation. Each OU object must contain `name`, and optionally `parent_id` and `parent_key` for nesting. | `map(object({ name = string, parent_id = optional(string), parent_key = optional(string) }))` | | yes |
| root_ous | Map of already-created root-level OUs, keyed by logical identifiers. Each value must expose at minimum `{ id, arn }`. Passed from `aws_organizations_organizational_unit.root` in the parent module. | `map(object({ id = string, arn = string }))` | | yes |

## Outputs

| Name | Description |
|------|-------------|
| child_ous | Map of child OU logical keys to objects containing `id`, `arn`, and `name`. Use this to reference created child OUs in other modules. |
| baseline_ids | Discovered baseline name to ID map for the Control Tower home region. Includes AWSControlTowerBaseline, BackupBaseline, and other available baselines. |

## How It Works

### Baseline Discovery

The module uses an `external` data source to execute a Python script that:
1. Calls `list-baselines` to retrieve all available baseline definitions and extract their IDs
2. Calls `list-enabled-baselines` to detect which baselines are currently active
3. Specifically detects the IdentityCenterEnabledBaselineArn if Identity Center is deployed

The discovered baseline IDs are used to construct ARNs for enrollment on OUs.

### OU Hierarchy

- **Root OUs** are created in the parent module and passed to this module via `root_ous`
- **Child OUs** are created by this module when `parent_key` references a root OU key
- Nested OUs can reference parent OUs by their logical key in the `organizational_units` map

### Baseline Enrollment Sequence

1. AWSControlTowerBaseline is enrolled on all root OUs
2. AWSControlTowerBaseline is enrolled on all child OUs (depends on root baseline enrollment)
3. BackupBaseline is enrolled on root OUs (if `enable_backup = true`, depends on root baseline)
4. BackupBaseline is enrolled on child OUs (if `enable_backup = true`, depends on child baseline)

This sequencing ensures that baselines are applied in the correct order and that dependencies are satisfied.

### Identity Center Integration

When Identity Center is enabled on the Control Tower landing zone, the module detects the IdentityCenterEnabledBaselineArn and automatically passes it as a parameter to the AWSControlTowerBaseline. This parameter is required for proper Identity Center integration.

## Limitations

- Do not add OUs that are already managed by Control Tower (e.g., Security, Sandbox) to the `organizational_units` map unless you are importing them
- Root OUs must be created outside this module and passed in via `root_ous`
- Baseline discovery requires AWS CLI and Python 3 to be available in the Terraform execution environment
