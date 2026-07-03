# network/shared-vpc

Creates a VPC in the Network account with a configurable subnet layout, shares subnets to workload accounts via AWS RAM, and optionally peers with an egress VPC for centralized internet access.

This module implements the **shared-vpc** network topology where the Network account owns all VPCs and workload accounts only deploy resources into shared subnets — they cannot create, modify, or delete networking constructs.

## Architecture

- **Private subnets** — Shared with workload accounts for running compute, containers, and application resources.
- **Isolated subnets** (workload layout only) — For databases and internal-only services with no internet route.
- **Egress peering** (optional) — Routes `0.0.0.0/0` traffic from private subnets through a VPC Peering connection to a centralized egress VPC.
- **RAM sharing** — Subnets are shared to workload accounts or OUs via AWS Resource Access Manager.

## Usage

```hcl
module "workload_vpc" {
  source = "./modules/network/shared-vpc"

  vpc_name            = "workload-prod"
  ipam_pool_id        = "ipam-pool-0abc123def456"
  cidr_netmask_length = 22
  az_count            = 2
  subnet_layout       = "workload"

  share_with_accounts = ["111111111111", "222222222222"]

  enable_egress_peering = true
  egress_vpc_id         = "vpc-0egress123"
  egress_vpc_owner_id   = "999999999999"
  egress_vpc_cidr       = "10.0.0.0/24"

  tags = {
    Environment = "production"
    ManagedBy   = "AFT"
  }
}
```

### Minimal layout (no isolated subnets)

```hcl
module "minimal_vpc" {
  source = "./modules/network/shared-vpc"

  vpc_name            = "tools-dev"
  ipam_pool_id        = "ipam-pool-0abc123def456"
  cidr_netmask_length = 24
  az_count            = 2
  subnet_layout       = "minimal"

  share_with_org_unit_arns = ["arn:aws:organizations::123456789012:ou/o-abc123/ou-def4-56789012"]

  tags = {
    Environment = "development"
    ManagedBy   = "AFT"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| [terraform](https://www.terraform.io/) | >= 1.6.0 |
| [aws](https://registry.terraform.io/providers/hashicorp/aws) | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `vpc_name` | Name/identifier for this VPC (used in tags and resource names). | `string` | — | yes |
| `ipam_pool_id` | IPAM pool ID from which this VPC allocates its CIDR. | `string` | — | yes |
| `cidr_netmask_length` | Netmask length for VPC CIDR allocation from IPAM pool (e.g. 22 for /22). Must be between 16 and 28. | `number` | `22` | no |
| `az_count` | Number of Availability Zones to use (2 or 3). | `number` | `2` | no |
| `subnet_layout` | Subnet layout template: `"workload"` (private + isolated subnets) or `"minimal"` (private subnets only). | `string` | `"workload"` | no |
| `share_with_accounts` | List of AWS account IDs to share subnets with via RAM. | `list(string)` | `[]` | no |
| `share_with_org_unit_arns` | List of OU ARNs to share subnets with via RAM (alternative to account IDs). | `list(string)` | `[]` | no |
| `enable_egress_peering` | Whether to create a VPC Peering connection to the egress VPC for internet access. | `bool` | `false` | no |
| `egress_vpc_id` | VPC ID of the egress VPC to peer with. Required when `enable_egress_peering = true`. | `string` | `""` | no |
| `egress_vpc_cidr` | CIDR block of the egress VPC. Used for route table entries. Required when `enable_egress_peering = true`. | `string` | `""` | no |
| `egress_vpc_owner_id` | Account ID that owns the egress VPC. For peering within the same account, this is the Network account ID. | `string` | `""` | no |
| `enable_dns_hostnames` | Whether to enable DNS hostnames in the VPC. | `bool` | `true` | no |
| `enable_dns_support` | Whether to enable DNS support in the VPC. | `bool` | `true` | no |
| `tags` | Tags to apply to all resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | ID of the shared VPC. |
| `vpc_arn` | ARN of the shared VPC. |
| `vpc_cidr_block` | CIDR block allocated to the VPC from IPAM. |
| `private_subnet_ids` | Map of AZ name to private subnet ID. |
| `private_subnet_arns` | List of private subnet ARNs. |
| `isolated_subnet_ids` | Map of AZ name to isolated subnet ID (empty if layout is `minimal`). |
| `isolated_subnet_arns` | List of isolated subnet ARNs. |
| `private_route_table_id` | ID of the private route table. |
| `isolated_route_table_id` | ID of the isolated route table (`null` if layout is `minimal`). |
| `vpc_peering_connection_id` | VPC Peering connection ID to egress VPC (`null` if peering disabled). |
| `ram_resource_share_arn` | ARN of the RAM resource share for subnet sharing. |
| `availability_zones` | List of availability zones used by this VPC. |

## Subnet CIDR Allocation

For a `/22` VPC (1024 IPs) with 2 AZs:

| Subnet Type | Size | IPs per Subnet | Total IPs |
|-------------|------|----------------|-----------|
| Private | /24 | 256 | 512 (2 AZs) |
| Isolated | /25 | 128 | 256 (2 AZs) |
| Reserved | — | — | 256 |

The module uses `cidrsubnet()` to automatically calculate subnet CIDRs relative to the VPC CIDR block.

## License

This module is part of the AFT account customizations repository.
