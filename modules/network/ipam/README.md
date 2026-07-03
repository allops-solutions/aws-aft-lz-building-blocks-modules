# network/ipam

Terraform module that creates an AWS VPC IPAM (IP Address Manager) with a hierarchical pool structure designed for multi-account AWS Organizations.

The module provisions:

1. **Organization Pool** — A top-level pool holding the entire private address space.
2. **Regional Pools** — One per AWS region, carved from the organization pool.
3. **Environment Pools** — Leaf pools (e.g. production, non-production, shared-services) under each regional pool from which VPCs allocate CIDRs.

Environment pools are optionally shared with the entire AWS Organization via RAM so that workload accounts can allocate VPC CIDRs directly.

## Architecture

```
Organization Pool (e.g. 10.0.0.0/8)
  └── Regional Pool: eu-central-1 (e.g. 10.0.0.0/10)
        ├── Environment Pool: production       (e.g. 10.0.0.0/12)
        ├── Environment Pool: non-production   (e.g. 10.16.0.0/12)
        └── Environment Pool: shared-services  (e.g. 10.32.0.0/12)
```

## Usage

```hcl
module "ipam" {
  source = "./modules/network/ipam"

  providers = {
    aws                = aws.network
    aws.org-management = aws.management
  }

  ipam_description  = "Organization VPC IPAM"
  operating_regions = ["eu-central-1", "eu-west-1"]
  top_level_cidr    = "10.0.0.0/8"

  regional_pools = {
    eu-central-1 = {
      region = "eu-central-1"
      cidr   = "10.0.0.0/10"
    }
    eu-west-1 = {
      region = "eu-west-1"
      cidr   = "10.64.0.0/10"
    }
  }

  environment_pools = {
    euc1-production = {
      regional_pool_key                 = "eu-central-1"
      cidr                              = "10.0.0.0/12"
      allocation_default_netmask_length = 22
      allocation_min_netmask_length     = 16
      allocation_max_netmask_length     = 28
    }
    euc1-nonproduction = {
      regional_pool_key                 = "eu-central-1"
      cidr                              = "10.16.0.0/12"
      allocation_default_netmask_length = 22
      allocation_min_netmask_length     = 16
      allocation_max_netmask_length     = 28
    }
    euc1-shared-services = {
      regional_pool_key                 = "eu-central-1"
      cidr                              = "10.32.0.0/12"
      allocation_default_netmask_length = 22
      allocation_min_netmask_length     = 16
      allocation_max_netmask_length     = 28
    }
  }

  share_with_organization = true
  organization_arn        = "arn:aws:organizations::123456789012:organization/o-exampleorgid"

  tags = {
    ManagedBy = "terraform"
    Module    = "network/ipam"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | >= 5.0 |

## Providers

| Name | Description |
|------|-------------|
| `aws` | Used for all IPAM, RAM, and data source resources. |
| `aws.org-management` | Used to register the delegated IPAM administrator (only when `share_with_organization = true`). |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `ipam_description` | Description for the IPAM instance. | `string` | `"Organization VPC IPAM"` | no |
| `operating_regions` | List of AWS regions where IPAM manages IP addresses. Must include the IPAM home region. | `list(string)` | — | yes |
| `top_level_cidr` | Top-level CIDR block provisioned to the organization pool (e.g. `10.0.0.0/8`). | `string` | — | yes |
| `regional_pools` | Map of regional pools. Key is a logical name, value defines `region` and `cidr`. | `map(object({region=string, cidr=string}))` | — | yes |
| `environment_pools` | Map of environment pools. Key is a logical name, value defines `regional_pool_key`, `cidr`, and optional allocation netmask settings. | `map(object({...}))` | — | yes |
| `share_with_organization` | Whether to share IPAM pools with the entire AWS Organization via RAM. | `bool` | `true` | no |
| `organization_arn` | ARN of the AWS Organization. Required when `share_with_organization = true`. | `string` | `""` | no |
| `tags` | Tags to apply to all IPAM resources. | `map(string)` | `{}` | no |

### `environment_pools` object attributes

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `regional_pool_key` | `string` | — | Key in `regional_pools` that this environment pool belongs to. |
| `cidr` | `string` | — | CIDR block for this environment pool. |
| `allocation_default_netmask_length` | `number` | `22` | Default netmask length for allocations from this pool. |
| `allocation_min_netmask_length` | `number` | `16` | Minimum netmask length for allocations. |
| `allocation_max_netmask_length` | `number` | `28` | Maximum netmask length for allocations. |

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
| `ram_resource_share_arn` | ARN of the RAM resource share for IPAM pools (`null` if sharing disabled). |

## Notes

- The module requires a provider alias `aws.org-management` configured with credentials for the AWS Organizations management account. This is only used when `share_with_organization = true`.
- Regional pools are sized at `/10` by default, supporting up to four `/12` environment pools each (with one reserved for future use).
- All CIDR variables include validation to ensure well-formed CIDR notation.
