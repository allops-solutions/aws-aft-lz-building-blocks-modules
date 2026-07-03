# VPC IPAM Module

A Terraform module for managing AWS VPC IP Address Manager (IPAM) at scale across the organization. This module creates a hierarchical IPAM pool structure that enables centralized IP address management, CIDR collision detection, and flexible address allocation across environments and regions.

## Architecture

The module creates a three-tier IPAM hierarchy:

```
Organization Pool (top-level)
  └── Regional Pools (one per region)
        └── Environment Pools (prod/nonprod/shared per region)
```

Environment pools are the leaf level from which VPCs allocate CIDR blocks. When organization-wide sharing is enabled, environment pools are shared via AWS Resource Access Manager (RAM), allowing member accounts to allocate CIDRs autonomously while maintaining centralized visibility and preventing collisions.

### Capacity Planning Example

For a /10 top-level CIDR (10.0.0.0/10 = 4,194,304 IPs per region):

- **Production:** 10.0.0.0/12 (1,048,576 IPs / 25% utilization)
- **Non-production:** 10.16.0.0/12 (1,048,576 IPs / 25% utilization)
- **Shared-services:** 10.32.0.0/12 (1,048,576 IPs / 25% utilization)
- **Reserved:** 10.48.0.0/12 (1,048,576 IPs / 25% utilization)
  - Available for: sandbox, DR, compliance-isolated environments, partner access, etc.

## Usage

### Basic Example (Single Region)

```hcl
module "ipam" {
  source = "./modules/network/ipam"

  operating_regions = ["eu-central-1"]
  top_level_cidr    = "10.0.0.0/10"

  regional_pools = {
    "eu-central-1" = {
      region = "eu-central-1"
      cidr   = "10.0.0.0/12"
    }
  }

  environment_pools = {
    "eu-central-1-production" = {
      regional_pool_key = "eu-central-1"
      cidr              = "10.0.0.0/13"
    }
    "eu-central-1-nonproduction" = {
      regional_pool_key = "eu-central-1"
      cidr              = "10.8.0.0/13"
    }
  }

  share_with_organization = false
  tags = {
    Environment = "production"
    Managed-by  = "Terraform"
  }
}
```

### Multi-Region with Organization Sharing

```hcl
module "ipam" {
  source = "./modules/network/ipam"

  operating_regions = ["eu-central-1", "us-east-1"]
  top_level_cidr    = "10.0.0.0/8"

  regional_pools = {
    "eu-central-1" = {
      region = "eu-central-1"
      cidr   = "10.0.0.0/10"
    }
    "us-east-1" = {
      region = "us-east-1"
      cidr   = "10.64.0.0/10"
    }
  }

  environment_pools = {
    "eu-central-1-production" = {
      regional_pool_key                 = "eu-central-1"
      cidr                              = "10.0.0.0/12"
      allocation_default_netmask_length = 22
      allocation_min_netmask_length     = 16
      allocation_max_netmask_length     = 28
    }
    "eu-central-1-nonproduction" = {
      regional_pool_key                 = "eu-central-1"
      cidr                              = "10.16.0.0/12"
      allocation_default_netmask_length = 22
    }
    "eu-central-1-shared" = {
      regional_pool_key                 = "eu-central-1"
      cidr                              = "10.32.0.0/12"
      allocation_default_netmask_length = 22
    }
    "us-east-1-production" = {
      regional_pool_key                 = "us-east-1"
      cidr                              = "10.64.0.0/12"
      allocation_default_netmask_length = 22
    }
    "us-east-1-nonproduction" = {
      regional_pool_key                 = "us-east-1"
      cidr                              = "10.80.0.0/12"
      allocation_default_netmask_length = 22
    }
  }

  share_with_organization = true
  organization_arn        = "arn:aws:organizations::123456789012:organization/o-xxxxxxxxxx"

  tags = {
    Environment = "production"
    Managed-by  = "Terraform"
  }
}

# Configure the org-management provider for delegated admin setup
provider "aws" {
  alias = "org-management"
  # Point to your organization management account
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | >= 5.0 |

### Provider Configuration

The module requires two AWS provider configurations:

- **default provider**: Credentials for the Network (IPAM) account where resources will be created
- **aws.org-management**: Credentials for the AWS Organization management account (required only when `share_with_organization = true`)

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| ipam_description | Description for the IPAM instance. | `string` | `"Organization VPC IPAM"` | No |
| operating_regions | AWS regions where IPAM manages IP addresses. Must include the home region. | `list(string)` | N/A | Yes |
| top_level_cidr | Top-level CIDR block for the organization pool (e.g., `10.0.0.0/8`). | `string` | N/A | Yes |
| regional_pools | Map of regional pools to create under the top-level pool. Key is a logical name (e.g., `"eu-central-1"`), value defines the region and CIDR. Each regional pool is subdivided into environment pools. | `map(object({ region = string, cidr = string }))` | N/A | Yes |
| environment_pools | Map of environment pools to create under each regional pool. Key is a logical name (e.g., `"production"`), value defines the CIDR, parent regional pool key, and allocation constraints. These are the pools from which VPCs actually allocate CIDRs. | `map(object({ regional_pool_key = string, cidr = string, allocation_default_netmask_length = optional(number, 22), allocation_min_netmask_length = optional(number, 16), allocation_max_netmask_length = optional(number, 28) }))` | N/A | Yes |
| share_with_organization | Enable organization-wide IPAM. When true, registers this account as IPAM delegated administrator (org-wide visibility) and shares environment pools with the organization via RAM (accounts can allocate CIDRs). | `bool` | `false` | No |
| organization_arn | ARN of the AWS Organization. Required when `share_with_organization = true`. | `string` | `""` | No |
| tags | Tags to apply to all IPAM resources. | `map(string)` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| ipam_id | ID of the IPAM instance. |
| ipam_arn | ARN of the IPAM instance. |
| ipam_private_default_scope_id | ID of the IPAM private default scope. |
| organization_pool_id | ID of the top-level organization IPAM pool. |
| regional_pool_ids | Map of regional pool logical names to their IPAM pool IDs. |
| environment_pool_ids | Map of environment pool logical names to their IPAM pool IDs. |
| environment_pool_arns | Map of environment pool logical names to their ARNs. |
| ram_resource_share_arn | RAM resource share ARN (null if sharing disabled). |

## Features

- **Hierarchical pool structure** — Organize IP addresses by region and environment
- **Multi-region support** — Create IPAM instances spanning multiple AWS regions
- **Organization-wide sharing** — Share environment pools across member accounts via RAM
- **CIDR collision detection** — Monitor and prevent overlapping IP allocations
- **Flexible allocation constraints** — Configure minimum, maximum, and default CIDR sizes per pool
- **Delegated administration** — Grant the Network account org-wide IPAM visibility
- **Comprehensive tagging** — Apply consistent tags across all IPAM resources

## Security Considerations

- **Delegated administrator access** — When `share_with_organization = true`, the Network account gains read-only, organization-wide visibility into all VPCs (even those created outside this automation). This is safe for monitoring but does not grant allocation permissions to workload accounts beyond what is explicitly shared via RAM.
- **RAM sharing restrictions** — Environment pools are shared only with the AWS Organization principal; external principals are not allowed (`allow_external_principals = false`).
- **Allocation autonomy** — When IPAM pools are shared via RAM, member accounts can allocate CIDRs independently while IPAM guarantees no collisions occur.

## Notes

- At least one operating region must be specified; typically this is the "home" region for the IPAM instance.
- Regional pools should be sized to accommodate growth (e.g., /10 per region for 4.19M IPs).
- Environment pools are subdivided from regional pools and should never overlap.
- The reserved block in the capacity planning example provides headroom for future growth or special-purpose pools.
