# VPC Module

The `network/vpc` Terraform module creates an IPv4 VPC with public, private, and isolated subnets across a configurable number of Availability Zones. The VPC CIDR is allocated from an AWS VPC IPAM pool, so callers do not need to provide a manual CIDR block.

The module supports both centrally managed network-account deployments and isolated member-account deployments:

- In a network account, populate `share_with_accounts` and/or `share_with_org_unit_arns` to share the module-managed subnets through AWS Resource Access Manager (RAM).
- In a member account, leave the sharing inputs empty and the VPC remains local to the account.

By default, the module creates IPv4 internet egress using an Internet Gateway and NAT Gateway(s), plus S3 and DynamoDB gateway endpoints. NAT high availability can be explicitly configured or inferred from the IPAM pool's `environment` tag.

## Usage

```hcl
module "vpc" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/network/vpc?ref=network-vpc-v1.0"
  # Pin to a specific release by setting the ref to the desired module tag, for example:
  # source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/network/vpc?ref=network-vpc-v1.0"

  vpc_name              = "shared-network"
  ipam_pool_id          = "ipam-pool-0123456789abcdef0"
  cidr_netmask_length   = 20
  az_count              = 3
  enable_egress         = true
  nat_high_availability = true

  # Optional: share all public, private, and isolated subnets through RAM.
  share_with_accounts       = ["111122223333"]
  share_with_org_unit_arns  = ["arn:aws:organizations::111122223333:ou/o-example/ou-example1"]

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

The `ipam_pool_id` must identify an IPv4 IPAM pool that can allocate the requested VPC CIDR. The module uses Availability Zone IDs rather than names to identify subnets consistently across accounts.

## Features

- Allocates the VPC CIDR from AWS VPC IPAM.
- Creates public, private, and isolated subnet tiers in each selected Availability Zone.
- Supports two through four Availability Zones.
- Creates one NAT Gateway per Availability Zone for high availability, or one NAT Gateway in the first Availability Zone for a lower-cost topology.
- Infers high-availability NAT configuration when `nat_high_availability` is `null`: it is enabled only when the IPAM pool has an `environment` tag whose value is `production` (case-insensitive and whitespace-trimmed).
- Can disable the Internet Gateway, NAT Gateways, and default IPv4 internet routes with `enable_egress = false`.
- Creates S3 and DynamoDB gateway endpoints for all module-managed route tables.
- Optionally shares all module-managed subnets through RAM.
- Does not provision IPv6 CIDR blocks, dedicated network ACLs, or an egress-only Internet Gateway.

## Requirements

| Name | Version |
|---|---|
| Terraform | `>= 1.6.0` |
| AWS provider | `>= 6.23.0` |

The AWS provider must be configured by the calling configuration with credentials and a region that contains the requested number of available Availability Zones.

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `vpc_name` | Name for the VPC. It is used in resource names and tags. | `string` | — | yes |
| `ipam_pool_id` | ID of the IPv4 IPAM pool from which this VPC allocates its CIDR. | `string` | — | yes |
| `cidr_netmask_length` | Netmask length for the VPC CIDR allocated from IPAM. Must be an integer from /16 through /24. If omitted, IPAM uses the pool's allocation default netmask length. | `number` | `null` | no |
| `az_count` | Number of Availability Zones to use for each subnet tier. Must be an integer from 2 through 4 and cannot exceed the number of available AZs in the selected region. | `number` | `2` | no |
| `enable_egress` | Whether to create an Internet Gateway and NAT Gateway routing for outbound IPv4 internet access. When `false`, the VPC has no Internet Gateway, NAT Gateways, or default internet routes. | `bool` | `true` | no |
| `nat_high_availability` | NAT Gateway topology. Set `true` for one NAT Gateway per AZ or `false` for one NAT Gateway in the first AZ. If omitted, the value is `true` only when the IPAM pool `environment` tag is exactly `production`; otherwise it is `false`. | `bool` | `null` | no |
| `share_with_accounts` | Account IDs to share subnets with through RAM. Leave empty if the VPC owner is also the consumer. | `list(string)` | `[]` | no |
| `share_with_org_unit_arns` | OU ARNs to share subnets with through RAM. Leave empty if the VPC owner is also the consumer. | `list(string)` | `[]` | no |
| `enable_dns_hostnames` | Enable DNS hostnames in the VPC. | `bool` | `true` | no |
| `enable_dns_support` | Enable DNS support in the VPC. | `bool` | `true` | no |
| `tags` | Tags to apply to all resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | VPC ID. |
| `vpc_arn` | VPC ARN. |
| `vpc_cidr_block` | CIDR block allocated from IPAM. |
| `default_security_group_id` | The ID of the security group created by default on VPC creation. |
| `default_network_acl_id` | The ID of the default network ACL. |
| `default_route_table_id` | The ID of the default route table. |
| `vpc_instance_tenancy` | Tenancy of instances launched into the VPC. |
| `vpc_enable_dns_support` | Whether the VPC has DNS support. |
| `vpc_enable_dns_hostnames` | Whether the VPC has DNS hostname support. |
| `vpc_main_route_table_id` | The ID of the main route table associated with this VPC. |
| `vpc_ipv6_association_id` | IPv6 CIDR association ID. Always `null` because this module does not provision IPv6 CIDR blocks. |
| `vpc_ipv6_cidr_block` | IPv6 CIDR block. Always `null` because this module does not provision IPv6 CIDR blocks. |
| `vpc_secondary_cidr_blocks` | Secondary IPv4 CIDR blocks. Always empty because this module provisions only the primary IPAM-allocated CIDR. |
| `vpc_owner_id` | The ID of the AWS account that owns the VPC. |
| `name` | The name of the VPC specified as an argument to this module. |
| `azs` | A list of Availability Zone IDs used by this VPC. |
| `igw_id` | The ID of the Internet Gateway, or `null` when egress is disabled. |
| `igw_arn` | The ARN of the Internet Gateway, or `null` when egress is disabled. |
| `egress_only_internet_gateway_id` | ID of the egress-only Internet Gateway. Always `null` because this module provisions IPv4 egress only. |
| `public_subnet_ids_by_az` | Map of Availability Zone ID to public subnet ID. |
| `public_subnet_objects` | A list of all public subnets, containing the full objects. |
| `public_subnets` | List of IDs of public subnets. |
| `public_subnet_arns` | List of ARNs of public subnets. |
| `public_subnets_cidr_blocks` | List of CIDR blocks of public subnets. |
| `public_subnets_ipv6_cidr_blocks` | IPv6 CIDR blocks of public subnets. Always empty because this module does not provision IPv6 CIDR blocks. |
| `public_network_acl_id` | ID of the dedicated public network ACL. Always `null` because this module uses the default network ACL. |
| `public_network_acl_arn` | ARN of the dedicated public network ACL. Always `null` because this module uses the default network ACL. |
| `public_route_table_ids` | List of IDs of public route tables. |
| `public_internet_gateway_route_id` | ID of the Internet Gateway route, or `null` when egress is disabled. |
| `public_route_table_association_ids` | List of IDs of public route table associations. |
| `private_subnet_ids_by_az` | Map of Availability Zone ID to private subnet ID. |
| `private_subnet_objects` | A list of all private subnets, containing the full objects. |
| `private_subnets` | List of IDs of private subnets. |
| `private_subnet_arns` | List of ARNs of private subnets. |
| `private_subnets_cidr_blocks` | List of CIDR blocks of private subnets. |
| `private_subnets_ipv6_cidr_blocks` | IPv6 CIDR blocks of private subnets. Always empty because this module does not provision IPv6 CIDR blocks. |
| `private_network_acl_id` | ID of the dedicated private network ACL. Always `null` because this module uses the default network ACL. |
| `private_network_acl_arn` | ARN of the dedicated private network ACL. Always `null` because this module uses the default network ACL. |
| `private_route_table_ids_by_az` | Map of Availability Zone ID to private route table ID. |
| `private_route_table_ids` | List of IDs of private route tables. |
| `private_nat_gateway_route_ids` | List of IDs of private NAT Gateway routes. Empty when egress is disabled. |
| `private_route_table_association_ids` | List of IDs of private route table associations. |
| `intra_subnet_ids_by_az` | Map of Availability Zone ID to intra (isolated) subnet ID. |
| `intra_subnet_objects` | A list of all intra (isolated) subnets, containing the full objects. |
| `intra_subnets` | List of IDs of intra (isolated) subnets. |
| `intra_subnet_arns` | List of ARNs of intra (isolated) subnets. |
| `intra_subnets_cidr_blocks` | List of CIDR blocks of intra (isolated) subnets. |
| `intra_subnets_ipv6_cidr_blocks` | IPv6 CIDR blocks of intra (isolated) subnets. Always empty because this module does not provision IPv6 CIDR blocks. |
| `intra_network_acl_id` | ID of the dedicated intra network ACL. Always `null` because this module uses the default network ACL. |
| `intra_network_acl_arn` | ARN of the dedicated intra network ACL. Always `null` because this module uses the default network ACL. |
| `intra_route_table_ids` | List of IDs of intra (isolated) route tables. |
| `intra_route_table_association_ids` | List of IDs of intra (isolated) route table associations. |
| `nat_ids_by_az` | Map of Availability Zone ID to NAT Gateway Elastic IP allocation ID. |
| `nat_ids` | List of Elastic IP allocation IDs created for NAT Gateways. |
| `nat_public_ips_by_az` | Map of Availability Zone ID to NAT Gateway public IP. |
| `nat_public_ips` | List of public Elastic IPs created for NAT Gateways. |
| `natgw_ids_by_az` | Map of Availability Zone ID to NAT Gateway ID. |
| `natgw_ids` | List of NAT Gateway IDs. |
| `natgw_interface_ids` | List of Network Interface IDs assigned to NAT Gateways. |
| `ram_resource_share_arn` | RAM resource share ARN, or `null` if subnets are not shared. |
| `vpc_metadata` | VPC summary for operational reference, including the VPC name, ID, CIDR block, AZ count, Availability Zone IDs, egress status, NAT configuration, and sharing status. |

## Subnet tiers and routing

Each selected Availability Zone receives one subnet in each tier:

- **Public:** associated with a shared public route table. When egress is enabled, the route table has a default route to the Internet Gateway.
- **Private:** each AZ has its own route table. When egress is enabled, the default route points to the NAT Gateway in the same AZ for high-availability mode, or to the NAT Gateway in the first AZ for single-AZ mode.
- **Isolated:** associated with a shared isolated route table with no default internet route.

S3 and DynamoDB gateway endpoints are associated with all public, private, and isolated route tables.

## RAM sharing

When either `share_with_accounts` or `share_with_org_unit_arns` is non-empty, the module creates one RAM resource share and associates every public, private, and isolated subnet with it. `allow_external_principals` is disabled. When both inputs are empty, no RAM resource share is created and `ram_resource_share_arn` is `null`.

## Versioning

This module is released from the GitHub repository using tags in the format `<module-name-with-dashes>-<version>`. The source for this release is:

```text
github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/network/vpc?ref=network-vpc-v1.0
```

For reproducible deployments, pin the module source to an explicit release tag rather than tracking a moving branch.
