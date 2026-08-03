# VPC Terraform Module

This module provisions a complete VPC with public, private, and isolated (intra) subnets across multiple Availability Zones. The VPC CIDR is allocated dynamically from an AWS IPAM pool, eliminating manual CIDR management. The module supports both centrally-managed (with RAM sharing) and isolated topologies.

## Features

- **IPAM-driven CIDR allocation** — VPC CIDR is automatically allocated from a specified IPAM pool
- **Multi-AZ subnets** — Configurable number of Availability Zones (2–4) with public, private, and isolated subnet tiers
- **NAT Gateway routing** — High-availability or single-AZ NAT Gateway topology (configurable or auto-detected from IPAM pool environment tag)
- **Gateway VPC Endpoints** — S3 and DynamoDB endpoints included automatically
- **DNS configuration** — Configurable DNS hostnames and support (enabled by default)
- **RAM sharing** — Optionally share subnets with other AWS accounts or OUs via AWS Resource Access Manager
- **Comprehensive outputs** — Extensive output values for VPC, subnets, route tables, NAT Gateways, and shared resources

## Usage

```hcl
module "vpc" {
  # Pin to a specific version using the ref parameter
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/network/vpc?ref=network-vpc-v2.0"

  vpc_name      = "production-vpc"
  ipam_pool_id  = "ipam-pool-0123456789abcdef0"
  az_count      = 3
  enable_egress = true

  # Optional: Share subnets with other accounts
  share_with_accounts = ["123456789012", "210987654321"]

  # Optional: Customize NAT Gateway topology (omit to auto-detect from IPAM pool)
  nat_high_availability = true

  tags = {
    Environment = "production"
    Team        = "platform"
  }
}

# Reference the outputs
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "private_subnets" {
  value = module.vpc.private_subnets
}
```

### Pinning to a Specific Version

Always pin the module to a specific version to ensure reproducible deployments:

```hcl
source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/network/vpc?ref=network-vpc-v2.0"
```

Replace `v2.0` with the desired version (e.g., `network-vpc-v1.0`, `network-vpc-v2.1`, etc.).

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | >= 6.23.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 6.23.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vpc_name | Name for the VPC. It is used in resource names and tags. | `string` | — | yes |
| ipam_pool_id | ID of the IPv4 IPAM pool from which this VPC allocates its CIDR. | `string` | — | yes |
| cidr_netmask_length | Netmask length for the VPC CIDR allocated from IPAM. Must be an integer from /16 through /24. If omitted, IPAM uses the pool's allocation_default_netmask_length. | `number` | `null` | no |
| az_count | Number of Availability Zones to use for each subnet tier. Must be an integer from 2 through 4 and cannot exceed the number of available AZs in the selected region. | `number` | `2` | no |
| enable_egress | Whether to create an Internet Gateway and NAT Gateway routing for outbound IPv4 internet access. When false, the VPC has no Internet Gateway, NAT Gateways, or default internet routes. | `bool` | `true` | no |
| nat_high_availability | NAT Gateway topology. Set `true` for one NAT Gateway per AZ or `false` for one NAT Gateway in the first AZ. If omitted, the value is `true` only when the IPAM pool environment tag is exactly `production` (case-insensitive); otherwise it is `false`. | `bool` | `null` | no |
| share_with_accounts | Account IDs to share subnets with via RAM. Leave empty if the VPC owner is also the consumer. | `list(string)` | `[]` | no |
| share_with_org_unit_arns | OU ARNs to share subnets with via RAM. Leave empty if the VPC owner is also the consumer. | `list(string)` | `[]` | no |
| enable_dns_hostnames | Enable DNS hostnames in the VPC. | `bool` | `true` | no |
| enable_dns_support | Enable DNS support in the VPC. | `bool` | `true` | no |
| tags | Tags to apply to all resources. | `map(string)` | `{}` | no |

## Outputs

### VPC Attributes

| Name | Description |
|------|-------------|
| vpc_id | VPC ID |
| vpc_arn | VPC ARN |
| vpc_cidr_block | CIDR block allocated from IPAM |
| vpc_owner_id | The ID of the AWS account that owns the VPC |
| vpc_instance_tenancy | Tenancy of instances launched into the VPC |
| vpc_enable_dns_support | Whether the VPC has DNS support |
| vpc_enable_dns_hostnames | Whether the VPC has DNS hostname support |
| name | The name of the VPC specified as argument to this module |

### VPC Defaults

| Name | Description |
|------|-------------|
| default_security_group_id | The ID of the security group created by default on VPC creation |
| default_network_acl_id | The ID of the default network ACL |
| default_route_table_id | The ID of the default route table |
| vpc_main_route_table_id | The ID of the main route table associated with this VPC |

### IPv6 and Secondary CIDR Status

| Name | Description |
|------|-------------|
| vpc_ipv6_association_id | IPv6 CIDR association ID (always null — this module does not provision IPv6) |
| vpc_ipv6_cidr_block | IPv6 CIDR block (always null — this module does not provision IPv6) |
| vpc_secondary_cidr_blocks | Secondary IPv4 CIDR blocks (always empty — this module provisions only primary IPAM-allocated CIDR) |

### Availability Zones

| Name | Description |
|------|-------------|
| azs | A list of Availability Zone IDs used by this VPC |

### Internet Gateway

| Name | Description |
|------|-------------|
| igw_id | The ID of the Internet Gateway (null if `enable_egress` is false) |
| igw_arn | The ARN of the Internet Gateway (null if `enable_egress` is false) |
| egress_only_internet_gateway_id | ID of the egress-only Internet Gateway (always null — this module provisions IPv4 egress only) |

### Public Subnets

| Name | Description |
|------|-------------|
| public_subnet_ids_by_az | Map of Availability Zone ID to public subnet ID |
| public_subnet_objects | A list of all public subnets, containing the full objects |
| public_subnets | List of IDs of public subnets |
| public_subnet_arns | List of ARNs of public subnets |
| public_subnets_cidr_blocks | List of CIDR blocks of public subnets |
| public_subnets_ipv6_cidr_blocks | IPv6 CIDR blocks of public subnets (always empty — this module does not provision IPv6) |
| public_network_acl_id | ID of the dedicated public network ACL (always null — this module uses the default network ACL) |
| public_network_acl_arn | ARN of the dedicated public network ACL (always null — this module uses the default network ACL) |

### Public Route Tables

| Name | Description |
|------|-------------|
| public_route_table_ids | List of IDs of public route tables |
| public_internet_gateway_route_id | ID of the Internet Gateway route (null if `enable_egress` is false) |
| public_route_table_association_ids | List of IDs of public route table associations |

### Private Subnets

| Name | Description |
|------|-------------|
| private_subnet_ids_by_az | Map of Availability Zone ID to private subnet ID |
| private_subnet_objects | A list of all private subnets, containing the full objects |
| private_subnets | List of IDs of private subnets |
| private_subnet_arns | List of ARNs of private subnets |
| private_subnets_cidr_blocks | List of CIDR blocks of private subnets |
| private_subnets_ipv6_cidr_blocks | IPv6 CIDR blocks of private subnets (always empty — this module does not provision IPv6) |
| private_network_acl_id | ID of the dedicated private network ACL (always null — this module uses the default network ACL) |
| private_network_acl_arn | ARN of the dedicated private network ACL (always null — this module uses the default network ACL) |

### Private Route Tables

| Name | Description |
|------|-------------|
| private_route_table_ids_by_az | Map of Availability Zone ID to private route table ID |
| private_route_table_ids | List of IDs of private route tables |
| private_nat_gateway_route_ids | List of IDs of private NAT Gateway routes (empty if `enable_egress` is false) |
| private_route_table_association_ids | List of IDs of private route table associations |

### Isolated (Intra) Subnets

| Name | Description |
|------|-------------|
| intra_subnet_ids_by_az | Map of Availability Zone ID to intra subnet ID |
| intra_subnet_objects | A list of all intra subnets, containing the full objects |
| intra_subnets | List of IDs of intra subnets |
| intra_subnet_arns | List of ARNs of intra subnets |
| intra_subnets_cidr_blocks | List of CIDR blocks of intra subnets |
| intra_subnets_ipv6_cidr_blocks | IPv6 CIDR blocks of intra subnets (always empty — this module does not provision IPv6) |
| intra_network_acl_id | ID of the dedicated intra network ACL (always null — this module uses the default network ACL) |
| intra_network_acl_arn | ARN of the dedicated intra network ACL (always null — this module uses the default network ACL) |

### Intra Route Tables

| Name | Description |
|------|-------------|
| intra_route_table_ids | List of IDs of intra route tables |
| intra_route_table_association_ids | List of IDs of intra route table associations |

### NAT Gateways

| Name | Description |
|------|-------------|
| nat_ids_by_az | Map of Availability Zone ID to NAT Gateway Elastic IP allocation ID |
| nat_ids | List of Elastic IP allocation IDs created for NAT Gateways |
| nat_public_ips_by_az | Map of Availability Zone ID to NAT Gateway public IP |
| nat_public_ips | List of public Elastic IPs created for NAT Gateways |
| natgw_ids_by_az | Map of Availability Zone ID to NAT Gateway ID |
| natgw_ids | List of NAT Gateway IDs |
| natgw_interface_ids | List of Network Interface IDs assigned to NAT Gateways |

### Resource Access Manager (RAM) Sharing

| Name | Description |
|------|-------------|
| ram_resource_share_arn | RAM resource share ARN (null if not shared) |

### Operational Summary

| Name | Description |
|------|-------------|
| vpc_metadata | VPC summary for operational reference, including VPC name, ID, CIDR, AZ count, NAT configuration, and sharing status |

## Examples

### Basic VPC with Default Settings

```hcl
module "vpc" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/network/vpc?ref=network-vpc-v2.0"

  vpc_name     = "main-vpc"
  ipam_pool_id = "ipam-pool-0123456789abcdef0"

  tags = {
    Name        = "main-vpc"
    Environment = "production"
  }
}
```

### Multi-AZ VPC with High-Availability NAT

```hcl
module "vpc" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/network/vpc?ref=network-vpc-v2.0"

  vpc_name                = "multi-az-vpc"
  ipam_pool_id            = "ipam-pool-0123456789abcdef0"
  az_count                = 3
  nat_high_availability   = true
  cidr_netmask_length     = 20

  tags = {
    Environment = "production"
  }
}
```

### Shared VPC with RAM

```hcl
module "vpc" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/network/vpc?ref=network-vpc-v2.0"

  vpc_name      = "shared-vpc"
  ipam_pool_id  = "ipam-pool-0123456789abcdef0"
  az_count      = 2
  enable_egress = true

  # Share subnets with specific AWS accounts
  share_with_accounts = ["111111111111", "222222222222"]

  tags = {
    Environment = "production"
  }
}
```

### VPC with No Egress (Isolated)

```hcl
module "vpc" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/network/vpc?ref=network-vpc-v2.0"

  vpc_name      = "isolated-vpc"
  ipam_pool_id  = "ipam-pool-0123456789abcdef0"
  enable_egress = false

  tags = {
    Environment = "production"
  }
}
```

## Notes

### NAT Gateway High-Availability

If `nat_high_availability` is not explicitly set:
- The module checks the IPAM pool for an `environment` tag
- If the tag value (after lowercasing and trimming whitespace) is exactly `"production"`, NAT HA is enabled (one NAT per AZ)
- Otherwise, NAT HA is disabled (single NAT in the first AZ)

### Region Availability Zones

The module automatically validates that `az_count` does not exceed the number of available Availability Zones in the selected region. If this constraint is violated, Terraform will fail with a clear error message during planning.

### IPAM Pool Environment Tag

The IPAM pool should include an optional `environment` tag. Common values are:
- `production` — Triggers high-availability NAT Gateway topology
- `development`, `staging`, `test` — Single-AZ NAT Gateway topology

### Default Security Group

A default security group is created and locked down (no ingress/egress rules) to prevent accidental exposure.

### VPC Endpoints

S3 and DynamoDB Gateway VPC Endpoints are automatically created and associated with all route tables (public, private, and isolated). These endpoints reduce data transfer costs and improve security by eliminating the need for internet access to these services.
