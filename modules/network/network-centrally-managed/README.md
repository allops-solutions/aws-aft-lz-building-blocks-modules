# network/network-centrally-managed

Creates a fully self-contained VPC in the Network account and shares its subnets to workload accounts via AWS RAM. Each VPC owns its own internet path — there is no central egress VPC and no VPC peering required.

## Architecture

Per VPC, the module provisions:

- **Internet Gateway** (for public subnets, conditional on `enable_egress`)
- **NAT Gateway(s)** (for private subnets) — high-availability (one per AZ) or single-AZ
- **Public, private, and isolated subnets** across the requested AZs
- **S3 + DynamoDB Gateway VPC Endpoints** (free, keeps that traffic off NAT)
- **Locked-down default security group** (deny-all, CIS compliant)
- **RAM subnet sharing** to workload accounts/OUs

### Subnet Tiers

| Tier | Purpose | Internet Route |
|------|---------|----------------|
| Public | Internet-facing LBs, bastion hosts | 0.0.0.0/0 → IGW |
| Private | Compute workloads (ECS, Lambda, EC2) | 0.0.0.0/0 → NAT |
| Isolated | Databases, caches | None |

Workload accounts deploy resources into the shared subnets but cannot create, modify, or delete any networking constructs.

## Usage

```hcl
module "vpc_production" {
  source = "path/to/modules/network/network-centrally-managed"

  vpc_name            = "prod-workloads"
  ipam_pool_id        = "ipam-pool-0123456789abcdef0"
  cidr_netmask_length = 16

  az_count              = 3
  enable_egress         = true
  nat_high_availability = true

  share_with_org_unit_arns = [
    "arn:aws:organizations::123456789012:ou/o-example/ou-abc1-prodou00"
  ]

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

### Non-production example (cost-optimized)

```hcl
module "vpc_dev" {
  source = "path/to/modules/network/network-centrally-managed"

  vpc_name            = "dev-workloads"
  ipam_pool_id        = "ipam-pool-0123456789abcdef0"
  cidr_netmask_length = 18

  az_count              = 2
  enable_egress         = true
  nat_high_availability = false  # single NAT, lower cost

  share_with_accounts = ["111111111111", "222222222222"]

  tags = {
    Environment = "development"
    ManagedBy   = "terraform"
  }
}
```

### Fully isolated VPC (no internet)

```hcl
module "vpc_isolated" {
  source = "path/to/modules/network/network-centrally-managed"

  vpc_name            = "isolated-data"
  ipam_pool_id        = "ipam-pool-0123456789abcdef0"
  cidr_netmask_length = 20

  az_count      = 2
  enable_egress = false  # no IGW, no NAT

  share_with_accounts = ["333333333333"]

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.6.0 |
| AWS provider | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `vpc_name` | Name/identifier for this VPC (used in tags and resource names). | `string` | — | yes |
| `ipam_pool_id` | IPAM pool ID from which this VPC allocates its CIDR. | `string` | — | yes |
| `cidr_netmask_length` | Netmask length for VPC CIDR allocation from IPAM pool (16–22). | `number` | — | yes |
| `az_count` | Number of Availability Zones to use (2, 3, or 4). | `number` | `2` | no |
| `enable_egress` | Whether this VPC has an internet path. When false, no IGW or NAT is created. | `bool` | `true` | no |
| `nat_high_availability` | When true, one NAT Gateway per AZ (HA). When false, a single NAT in the first AZ (lower cost). | `bool` | `true` | no |
| `share_with_accounts` | List of AWS account IDs to share subnets with via RAM. | `list(string)` | `[]` | no |
| `share_with_org_unit_arns` | List of OU ARNs to share subnets with via RAM. | `list(string)` | `[]` | no |
| `enable_dns_hostnames` | Whether to enable DNS hostnames in the VPC. | `bool` | `true` | no |
| `enable_dns_support` | Whether to enable DNS support in the VPC. | `bool` | `true` | no |
| `tags` | Tags to apply to all resources. Passed in from the root module. | `map(string)` | — | yes |
| `additional_cidr_blocks` | Additional CIDR blocks to associate with the VPC (reserved for future use). | `list(string)` | `[]` | no |
| `custom_tags_by_resource_type` | Resource-specific tag overrides (reserved for future use). | `map(map(string))` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | ID of the VPC. |
| `vpc_arn` | ARN of the VPC. |
| `vpc_cidr_block` | CIDR block allocated to the VPC from IPAM. |
| `public_subnet_ids` | Map of AZ ID to public subnet ID. |
| `public_subnet_arns` | List of public subnet ARNs. |
| `private_subnet_ids` | Map of AZ ID to private subnet ID. |
| `private_subnet_arns` | List of private subnet ARNs. |
| `isolated_subnet_ids` | Map of AZ ID to isolated subnet ID. |
| `isolated_subnet_arns` | List of isolated subnet ARNs. |
| `public_route_table_id` | ID of the public route table. |
| `private_route_table_ids` | Map of AZ ID to private route table ID. |
| `isolated_route_table_id` | ID of the isolated route table. |
| `internet_gateway_id` | ID of the Internet Gateway (null if egress disabled). |
| `nat_gateway_ids` | Map of AZ ID to NAT Gateway ID. |
| `nat_gateway_public_ips` | Map of AZ ID to NAT Gateway public IP (for allowlisting). |
| `availability_zone_ids` | List of Availability Zone IDs used by this VPC. |
| `ram_resource_share_arn` | ARN of the RAM resource share for subnet sharing (null if not shared). |
| `subnet_capacity` | Calculated IP capacity per subnet (useful for capacity planning). |
| `vpc_metadata` | VPC metadata for operational reference and future integrations. |

## Subnet Addressing Scheme

The VPC CIDR is split into 16 equal blocks (`newbits = 4`). Each tier reserves 4 block-slots (one per possible AZ), so adding a 3rd or 4th AZ never renumbers existing subnets.

```
subnet index = tier_offset × 4 + az_index

  public   (tier 0): slots 0–3
  private  (tier 1): slots 4–7
  isolated (tier 2): slots 8–11
  reserved (tier 3): slots 12–15
```

**Example — /16 VPC (65,536 IPs):** each subnet is a /20 with 4,091 usable IPs.
**Example — /18 VPC (16,384 IPs):** each subnet is a /22 with 1,019 usable IPs.

## Migration from v1.0

This release restructures the module packaging (release notes are now managed externally). There are **no breaking changes** to the Terraform resource definitions, variables, or outputs. Existing state is fully compatible — no `terraform state mv` or re-import is required.
