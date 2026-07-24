# VPC IPAM Module

Manages a hierarchical AWS VPC IP Address Manager (IPAM) pool structure for centralized IP address governance across AWS organizations. Enables automatic CIDR allocation with collision detection and supports organization-wide IP address monitoring.

## Features

- **Hierarchical Pool Structure**: Three-tier IPAM hierarchy (organization → regional → environment pools) for flexible IP address allocation
- **Multi-Region Support**: Configure IPAM to operate across multiple AWS regions with region-specific pool management
- **Environment Isolation**: Separate pools for production, non-production, and shared-services environments
- **Organization-Wide Governance**: Delegate IPAM administration to centrally manage IP addresses across all AWS accounts
- **Automated RAM Sharing**: Optionally share environment pools with organization members via AWS Resource Access Manager
- **Collision Detection**: Automatic CIDR conflict prevention for all VPCs, whether created through this module or manually
- **Flexible Allocation**: Configurable allocation netmask lengths (default, minimum, maximum) per environment pool

## Usage

```hcl
module "ipam" {
  # Pin to a specific version using the ref parameter
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/network/ipam?ref=network-ipam-v1.0"

  ipam_description       = "Organization VPC IPAM"
  operating_regions      = ["eu-central-1", "us-east-1"]
  top_level_cidr         = "10.0.0.0/8"
  share_with_organization = true
  organization_arn       = "arn:aws:organizations::123456789012:organization/o-abc123def456"

  regional_pools = {
    eu-central-1 = {
      region = "eu-central-1"
      cidr   = "10.0.0.0/10"
    }
    us-east-1 = {
      region = "us-east-1"
      cidr   = "10.64.0.0/10"
    }
  }

  environment_pools = {
    eu-central-1-production = {
      regional_pool_key                 = "eu-central-1"
      cidr                              = "10.0.0.0/12"
      allocation_default_netmask_length = 22
      allocation_min_netmask_length     = 16
      allocation_max_netmask_length     = 28
    }
    eu-central-1-nonproduction = {
      regional_pool_key                 = "eu-central-1"
      cidr                              = "10.16.0.0/12"
      allocation_default_netmask_length = 22
      allocation_min_netmask_length     = 16
      allocation_max_netmask_length     = 28
    }
    eu-central-1-shared = {
      regional_pool_key                 = "eu-central-1"
      cidr                              = "10.32.0.0/12"
      allocation_default_netmask_length = 22
      allocation_min_netmask_length     = 16
      allocation_max_netmask_length     = 28
    }
    us-east-1-production = {
      regional_pool_key                 = "us-east-1"
      cidr                              = "10.64.0.0/12"
      allocation_default_netmask_length = 22
      allocation_min_netmask_length     = 16
      allocation_max_netmask_length     = 28
    }
    us-east-1-nonproduction = {
      regional_pool_key                 = "us-east-1"
      cidr                              = "10.80.0.0/12"
      allocation_default_netmask_length = 22
      allocation_min_netmask_length     = 16
      allocation_max_netmask_length     = 28
    }
    us-east-1-shared = {
      regional_pool_key                 = "us-east-1"
      cidr                              = "10.96.0.0/12"
      allocation_default_netmask_length = 22
      allocation_min_netmask_length     = 16
      allocation_max_netmask_length     = 28
    }
  }

  tags = {
    Environment = "network"
    ManagedBy   = "terraform"
  }
}
```

## Regional Capacity Planning

Each regional pool operates on a /10 CIDR block, providing 4,194,304 IP addresses. The default configuration subdivides this into four /12 blocks (1,048,576 IPs each):

| Environment | CIDR Block | Allocation |
|-------------|-----------|-----------|
| Production | 10.x.0.0/12 | 25% (1M IPs) |
| Non-Production | 10.x.16.0/12 | 25% (1M IPs) |
| Shared Services | 10.x.32.0/12 | 25% (1M IPs) |
| Reserved | 10.x.48.0/12 | 25% (1M IPs) |

The reserved block can be allocated to sandbox, disaster recovery, compliance-isolated, or partner-access environments as needed.

## Requirements

| Requirement | Version |
|-------------|---------|
| Terraform | >= 1.6.0 |
| AWS Provider | >= 6.23.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `ipam_description` | Description for the IPAM instance. | `string` | `"Organization VPC IPAM"` | no |
| `operating_regions` | AWS regions where IPAM manages IP addresses. Must include the home region. | `list(string)` | n/a | yes |
| `top_level_cidr` | Top-level CIDR block for the organization pool (e.g. `10.0.0.0/8`). | `string` | n/a | yes |
| `regional_pools` | Map of regional pools to create under the top-level pool. Key is a logical name (e.g. `"eu-central-1"`), value defines the region and CIDR. Each regional pool is subdivided into environment pools. | `map(object({region = string, cidr = string}))` | n/a | yes |
| `environment_pools` | Map of environment pools to create under each regional pool. Key is a logical name (e.g. `"production"`), value defines the CIDR and parent regional pool key. These are the pools from which VPCs actually allocate CIDRs. | `map(object({regional_pool_key = string, cidr = string, allocation_default_netmask_length = optional(number, 22), allocation_min_netmask_length = optional(number, 16), allocation_max_netmask_length = optional(number, 28)}))` | n/a | yes |
| `share_with_organization` | Enable organization-wide IPAM. When true: Registers this account as IPAM delegated administrator (org-wide visibility), Shares environment pools with the organization via RAM (accounts can allocate CIDRs). | `bool` | `false` | no |
| `organization_arn` | ARN of the AWS Organization. Required when `share_with_organization = true`. | `string` | `""` | no |
| `tags` | Tags to apply to all IPAM resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `ipam_id` | ID of the IPAM instance. |
| `ipam_arn` | ARN of the IPAM instance. |
| `ipam_private_default_scope_id` | ID of the IPAM private default scope. |
| `organization_pool_id` | ID of the top-level organization IPAM pool. |
| `regional_pool_ids` | Map of regional pool logical names to their IPAM pool IDs. |
| `environment_pool_ids` | Map of environment pool logical names to their IPAM pool IDs. |
| `environment_pool_arns` | Map of environment pool logical names to their ARNs. |
| `ram_resource_share_arns` | Map of environment pool name to its RAM resource share ARN (empty if sharing disabled). |

## Organization-Wide Delegation

When `share_with_organization` is set to `true`, this module:

1. Registers the network account as the IPAM delegated administrator, granting organization-wide visibility into all VPCs
2. Shares each environment pool with the organization via AWS Resource Access Manager (RAM)
3. Enables member accounts to allocate VPC CIDRs from the environment pools

The delegated administrator role provides read/monitoring capabilities for CIDR collision detection and IP address governance without granting member accounts the ability to modify IPAM pools.

## Architecture

```
Organization IPAM Instance
    ├── Organization Pool (10.0.0.0/8)
    │   ├── Regional Pool: eu-central-1 (10.0.0.0/10)
    │   │   ├── Environment Pool: production (10.0.0.0/12) [RAM Shared]
    │   │   ├── Environment Pool: nonproduction (10.16.0.0/12) [RAM Shared]
    │   │   ├── Environment Pool: shared-services (10.32.0.0/12) [RAM Shared]
    │   │   └── Environment Pool: reserved (10.48.0.0/12)
    │   │
    │   └── Regional Pool: us-east-1 (10.64.0.0/10)
    │       ├── Environment Pool: production (10.64.0.0/12) [RAM Shared]
    │       ├── Environment Pool: nonproduction (10.80.0.0/12) [RAM Shared]
    │       ├── Environment Pool: shared-services (10.96.0.0/12) [RAM Shared]
    │       └── Environment Pool: reserved (10.112.0.0/12)
```
