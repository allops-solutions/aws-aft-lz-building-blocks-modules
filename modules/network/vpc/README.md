# network/vpc Terraform Module

Creates a production-ready AWS VPC with automatic CIDR allocation from IPAM, three-tier subnet architecture, NAT gateways, and Resource Access Manager (RAM) sharing for centrally-managed network topologies.

## Key Features

- **IPAM-driven CIDR allocation** — No manual CIDR management; automatically allocates from an IPAM pool.
- **Three-tier subnet design** — Public (IGW access), private (NAT access), and isolated (no internet) subnets across multiple Availability Zones.
- **Flexible egress** — Optional Internet Gateway and NAT Gateway(s); NAT HA configurable per AZ or single-AZ mode.
- **Automatic NAT HA detection** — Defaults to HA for production environments (based on IPAM pool tags), single-AZ otherwise.
- **Gateway VPC Endpoints** — S3 and DynamoDB endpoints on all route tables for optimized AWS service access.
- **RAM sharing** — Seamlessly share subnets across accounts or OUs for centrally-managed topologies.
- **Comprehensive tagging** — Subnet tier tags and custom tags on all resources for operational clarity.

## Usage

```hcl
module "vpc" {
  # Pin to a specific version using the ref parameter
  # source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/network/vpc?ref=network-vpc-v1.0"
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/network/vpc?ref=network-vpc-v1.0"

  vpc_name          = "prod-vpc"
  ipam_pool_id      = aws_vpc_ipam_pool.main.id
  cidr_netmask_length = 20
  az_count          = 3
  enable_egress     = true
  nat_high_availability = true

  tags = {
    Environment = "production"
    CostCenter  = "platform"
  }
}

# Example: Share VPC subnets with other AWS accounts (centrally-managed)
module "vpc_shared" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/network/vpc?ref=network-vpc-v1.0"

  vpc_name          = "network-hub-vpc"
  ipam_pool_id      = aws_vpc_ipam_pool.main.id
  az_count          = 2
  enable_egress     = true

  # Share subnets with member accounts
  share_with_accounts = [
    "123456789012",
    "210987654321",
  ]

  tags = {
    Environment = "production"
  }
}

# Example: Isolated VPC (no internet access, no RAM sharing)
module "vpc_isolated" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/network/vpc?ref=network-vpc-v1.0"

  vpc_name     = "isolated-vpc"
  ipam_pool_id = aws_vpc_ipam_pool.main.id
  az_count     = 2
  enable_egress = false

  tags = {
    Environment = "production"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | >= 6.23.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vpc_name | Name for the VPC (used in tags and resource names). | `string` | | yes |
| ipam_pool_id | IPAM pool ID from which this VPC allocates its CIDR. | `string` | | yes |
| az_count | Number of Availability Zones (2–4). | `number` | `2` | no |
| cidr_netmask_length | Netmask length for VPC CIDR allocation (16–24). If omitted, IPAM uses the pool's allocation_default_netmask_length. | `number` | `null` | no |
| enable_egress | Create Internet Gateway and NAT Gateway(s) for outbound internet access. | `bool` | `true` | no |
| nat_high_availability | true = one NAT per AZ; false = single NAT in first AZ. If not set, defaults to true when IPAM pool is tagged with 'prod' environment, false otherwise. | `bool` | `null` | no |
| enable_dns_hostnames | Enable DNS hostnames in the VPC. | `bool` | `true` | no |
| enable_dns_support | Enable DNS support in the VPC. | `bool` | `true` | no |
| share_with_accounts | Account IDs to share subnets with via RAM. Leave empty if the VPC owner is also the consumer. | `list(string)` | `[]` | no |
| share_with_org_unit_arns | OU ARNs to share subnets with via RAM. Leave empty if the VPC owner is also the consumer. | `list(string)` | `[]` | no |
| tags | Tags to apply to all resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC ID. |
| vpc_arn | VPC ARN. |
| vpc_cidr_block | CIDR block allocated from IPAM. |
| public_subnet_ids | Map of AZ ID to public subnet ID. |
| public_subnet_arns | List of public subnet ARNs. |
| private_subnet_ids | Map of AZ ID to private subnet ID. |
| private_subnet_id_list | Flat list of private subnet IDs (convenience for resources that expect a list, e.g. VPC endpoints). |
| private_subnet_arns | List of private subnet ARNs. |
| isolated_subnet_ids | Map of AZ ID to isolated subnet ID. |
| isolated_subnet_arns | List of isolated subnet ARNs. |
| public_route_table_id | Public route table ID. |
| private_route_table_ids | Map of AZ ID to private route table ID. |
| isolated_route_table_id | Isolated route table ID. |
| internet_gateway_id | Internet Gateway ID (null if egress disabled). |
| nat_gateway_ids | Map of AZ ID to NAT Gateway ID. |
| nat_gateway_public_ips | Map of AZ ID to NAT Gateway public IP. |
| availability_zone_ids | AZ IDs used by this VPC. |
| ram_resource_share_arn | RAM resource share ARN (null if not shared). |
| vpc_metadata | VPC summary for operational reference. |
