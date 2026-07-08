# VPC IPAM Module

This module creates a hierarchical AWS VPC IP Address Manager (IPAM) structure for centralized IP address planning and management across your AWS organization. It establishes organization-level, regional, and environment-specific pools with support for multi-account CIDR allocation via AWS RAM.

## Features

- **Hierarchical Pool Structure**: Organization → Regional → Environment pools for logical IP address segmentation
- **Capacity Planning**: Pre-configured for four /12 environment pools per region (1,048,576 IPs each), with three pools in use and one reserved for expansion
- **Organization-Wide Delegation**: Register the Network account as an IPAM delegated administrator for organization-wide visibility into all VPCs, enabling CIDR collision detection and IP address monitoring
- **RAM Sharing**: Automatically share environment pools with AWS organization members, enabling workload accounts to allocate VPCs without centralized coordination
- **Flexible Configuration**: Customizable CIDR blocks, allocation netmask lengths, and multi-region support
- **Full Tagging Support**: Apply consistent tags across all IPAM resources

## Usage

```hcl
module "ipam" {
  # Pin to a specific version using the ref parameter
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/network/ipam?ref=network-ipam-v1.0"

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
    "production" = {
      regional_pool_key                 = "eu-central-1"
      cidr                              = "10.0.0.0/12"
      allocation_default_netmask_length = 22
      allocation_min_netmask_length     = 16
      allocation_max_netmask_length     = 28
    }
    "nonproduction" = {
      regional_pool_key                 = "eu-central-1"
      cidr                              = "10.16.0.0/12"
      allocation_default_netmask_length = 22
      allocation_min_netmask_length     = 16
      allocation_max_netmask_length     = 28
    }
    "shared-services" = {
      regional_pool_key                 = "eu-central-1"
      cidr                              = "10.32.0.0/12"
      allocation_default_netmask_length = 22
      allocation_min_netmask_length     = 16
      allocation_max_netmask_length     = 28
    }
  }

  share_with_organization = true
  organization_arn        = "arn:aws:organizations::ACCOUNT_ID:organization/o-ORGANIZATION_ID"

  tags = {
    Environment = "network"
    Project     = "aft-lz"
  }

  providers = {
    aws                = aws.network-account
    aws.org-management = aws.management-account
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | >= 5.0 |

## Providers

- `aws` - AWS provider for the network account
- `aws.org-management` - AWS provider for the organization management account (required when `share_with_organization = true`)

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `ipam_description` | Description for the IPAM instance. | `string` | `"Organization VPC IPAM"` | no |
| `operating_regions` | AWS regions where IPAM manages IP addresses. Must include the home region. | `list(string)` | n/a | yes |
| `top_level_cidr` | Top-level CIDR block for the organization pool (e.g., `10.0.0.0/8`). | `string` | n/a | yes |
| `regional_pools` | Map of regional pools to create under the top-level pool. Key is a logical name (e.g., `"eu-central-1"`), value defines the region and CIDR. Each regional pool is subdivided into environment pools. | `map(object({ region = string, cidr = string }))` | n/a | yes |
| `environment_pools` | Map of environment pools to create under each regional pool. Key is a logical name (e.g., `"production"`), value defines the CIDR, parent regional pool key, and allocation netmask settings. These are the pools from which VPCs actually allocate CIDRs. | `map(object({ regional_pool_key = string, cidr = string, allocation_default_netmask_length = optional(number, 22), allocation_min_netmask_length = optional(number, 16), allocation_max_netmask_length = optional(number, 28) }))` | n/a | yes |
| `share_with_organization` | Enable organization-wide IPAM. When `true`: registers this account as IPAM delegated administrator (org-wide visibility) and shares environment pools with the organization via RAM (accounts can allocate CIDRs). | `bool` | `false` | no |
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
| `ram_resource_share_arns` | Map of environment pool names to their RAM resource share ARNs (empty if sharing disabled). |

## Architecture

The module creates a three-level IPAM pool hierarchy:

```
Organization Pool (top-level, e.g., 10.0.0.0/8)
├── Regional Pool (e.g., eu-central-1: 10.0.0.0/10)
│   ├── Environment Pool - Production (e.g., 10.0.0.0/12)
│   ├── Environment Pool - Non-production (e.g., 10.16.0.0/12)
│   └── Environment Pool - Shared-services (e.g., 10.32.0.0/12)
└── Regional Pool (e.g., us-east-1: 10.64.0.0/10)
    ├── Environment Pool - Production (e.g., 10.64.0.0/12)
    ├── Environment Pool - Non-production (e.g., 10.80.0.0/12)
    └── Environment Pool - Shared-services (e.g., 10.96.0.0/12)
```

### Regional Capacity

Each /10 regional pool provides 4,194,304 IP addresses, supporting up to four /12 environment pools (1,048,576 IPs each). The default configuration uses three /12 pools, leaving one /12 block reserved for future use (sandbox, disaster recovery, compliance isolation, or partner access).

### Organization-Wide Delegation

When `share_with_organization = true`, this module:
- Registers the Network account as an IPAM delegated administrator
- Grants organization-wide visibility into all VPCs, enabling CIDR collision detection
- Shares environment pools via AWS RAM so member accounts can allocate VPCs

This is a read/monitoring capability for CIDR collision detection and does not grant workload accounts administrative access to IPAM. IPAM guarantees non-overlapping allocations regardless of who creates the VPC, making it safe to use alongside both centrally-managed VPCs and workload-account-created VPCs.

## Notes

- All CIDR blocks are validated at plan time. Invalid CIDR blocks will cause the plan to fail.
- At least one operating region must be specified.
- When using `share_with_organization = true`, ensure the `organization_arn` is provided and the `aws.org-management` provider alias is configured.
- Environment pools inherit their region from their parent regional pool automatically.
