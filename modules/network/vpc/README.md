# VPC Module

Creates a scalable, multi-tier VPC with automatic CIDR allocation from AWS IPAM. The module supports flexible deployment modes: centrally-managed network (with Resource Access Manager sharing) or isolated local VPC.

## Features

- **IPAM-driven CIDR allocation**: Automatically allocates VPC CIDR from an IPAM pool; no manual CIDR specification required
- **Multi-tier subnet architecture**: Public, private, and isolated subnets across 2–4 Availability Zones
- **Intelligent NAT configuration**: Automatically enables high-availability NAT (one per AZ) for production environments based on IPAM pool tags, or single-NAT for non-production
- **Gateway VPC Endpoints**: Built-in S3 and DynamoDB endpoints to reduce data transfer costs
- **RAM integration**: Share subnets with other AWS accounts or organizational units for centrally-managed network topology
- **Configurable egress control**: Optional Internet Gateway and NAT Gateways; disable to restrict outbound internet access
- **Per-AZ private routing**: Each AZ has its own private route table for fine-grained routing control
- **DNS control**: Configure DNS hostnames and DNS support per VPC

## Usage

### Basic Usage (Isolated VPC)

```hcl
module "vpc" {
  source = "./modules/network/vpc"

  vpc_name      = "my-vpc"
  ipam_pool_id  = aws_ec2_ipam_pool.main.id
  az_count      = 3
  enable_egress = true

  tags = {
    Environment = "production"
    Owner       = "platform-team"
  }
}

# Access outputs
resource "aws_ec2_instance" "example" {
  subnet_id = module.vpc.private_subnet_ids[data.aws_availability_zones.available.zone_ids[0]]
  # ...
}
```

### Centrally-Managed Network (with RAM Sharing)

```hcl
# In network account
module "vpc" {
  source = "./modules/network/vpc"

  vpc_name             = "central-vpc"
  ipam_pool_id         = aws_ec2_ipam_pool.main.id
  az_count             = 3
  enable_egress        = true
  nat_high_availability = true

  # Share subnets with member accounts
  share_with_accounts = [
    "123456789012",  # Member account 1
    "210987654321",  # Member account 2
  ]

  tags = {
    Environment = "production"
  }
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
```

### No Egress (Isolated Network)

```hcl
module "vpc_isolated" {
  source = "./modules/network/vpc"

  vpc_name      = "isolated-vpc"
  ipam_pool_id  = aws_ec2_ipam_pool.restricted.id
  az_count      = 2
  enable_egress = false  # No IGW or NAT

  tags = {
    Environment = "restricted"
  }
}
```

## Requirements

| Requirement | Version |
|-------------|---------|
| terraform  | >= 1.6.0 |
| aws provider | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `vpc_name` | Name for the VPC (used in tags and resource names). | `string` | N/A | yes |
| `ipam_pool_id` | IPAM pool ID from which this VPC allocates its CIDR. | `string` | N/A | yes |
| `cidr_netmask_length` | Netmask length for VPC CIDR allocation (16–24). If omitted, IPAM uses the pool's `allocation_default_netmask_length`. | `number` | `null` | no |
| `az_count` | Number of Availability Zones (2–4). | `number` | `2` | no |
| `enable_egress` | Create Internet Gateway and NAT Gateway(s) for outbound internet access. | `bool` | `true` | no |
| `nat_high_availability` | `true` = one NAT per AZ; `false` = single NAT in first AZ. If not set, defaults to `true` when IPAM pool is tagged with a production environment, `false` otherwise. | `bool` | `null` | no |
| `share_with_accounts` | Account IDs to share subnets with via RAM. Leave empty if the VPC owner is also the consumer. | `list(string)` | `[]` | no |
| `share_with_org_unit_arns` | OU ARNs to share subnets with via RAM. Leave empty if the VPC owner is also the consumer. | `list(string)` | `[]` | no |
| `enable_dns_hostnames` | Enable DNS hostnames in the VPC. | `bool` | `true` | no |
| `enable_dns_support` | Enable DNS support in the VPC. | `bool` | `true` | no |
| `tags` | Tags to apply to all resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | VPC ID. |
| `vpc_arn` | VPC ARN. |
| `vpc_cidr_block` | CIDR block allocated from IPAM. |
| `public_subnet_ids` | Map of AZ ID to public subnet ID. |
| `public_subnet_arns` | List of public subnet ARNs. |
| `private_subnet_ids` | Map of AZ ID to private subnet ID. |
| `private_subnet_id_list` | Flat list of private subnet IDs (convenience for resources that expect a list, e.g. VPC endpoints). |
| `private_subnet_arns` | List of private subnet ARNs. |
| `isolated_subnet_ids` | Map of AZ ID to isolated subnet ID. |
| `isolated_subnet_arns` | List of isolated subnet ARNs. |
| `public_route_table_id` | Public route table ID. |
| `private_route_table_ids` | Map of AZ ID to private route table ID. |
| `isolated_route_table_id` | Isolated route table ID. |
| `internet_gateway_id` | Internet Gateway ID (`null` if egress disabled). |
| `nat_gateway_ids` | Map of AZ ID to NAT Gateway ID. |
| `nat_gateway_public_ips` | Map of AZ ID to NAT Gateway public IP. |
| `availability_zone_ids` | AZ IDs used by this VPC. |
| `ram_resource_share_arn` | RAM resource share ARN (`null` if not shared). |
| `vpc_metadata` | VPC summary for operational reference, including VPC name, ID, CIDR block, AZ count, NAT configuration, and sharing status. |

## Architecture

### Subnet Tiers

The module creates three subnet tiers across the specified Availability Zones:

- **Public**: Route to Internet Gateway; suitable for load balancers, NAT gateways, and other resources that require internet access
- **Private**: Route to NAT Gateway(s) for outbound internet access; suitable for application servers and worker nodes
- **Isolated**: No internet routes; suitable for databases, caches, and other sensitive resources

Each tier has its own route table configuration. Private subnets get per-AZ route tables (to optionally route to different NAT gateways), while public and isolated subnets share a single route table per tier.

### CIDR Allocation

CIDR blocks are automatically allocated from the specified IPAM pool. The module internally allocates `/20` blocks per subnet tier per AZ (using 4 bits of netmask). Example with `/20` VPC:

```
VPC CIDR: 10.0.0.0/20
├─ Public (AZ 1):   10.0.0.0/24
├─ Public (AZ 2):   10.0.1.0/24
├─ Private (AZ 1):  10.0.4.0/24
├─ Private (AZ 2):  10.0.5.0/24
├─ Isolated (AZ 1): 10.0.8.0/24
└─ Isolated (AZ 2): 10.0.9.0/24
```

### NAT Configuration

- **High Availability (HA)**: One NAT Gateway per AZ. Each private route table routes to its corresponding AZ's NAT gateway
- **Single NAT**: One NAT Gateway in the first AZ. All private route tables route to this single NAT gateway

NAT HA is automatically enabled when the IPAM pool is tagged with an environment containing "prod" (e.g., `environment = "production"`), unless the tag also contains "non-prod". Override with the `nat_high_availability` variable.

### Resource Access Manager (RAM)

When `share_with_accounts` or `share_with_org_unit_arns` are populated, the module creates a RAM resource share and associates all subnets (public, private, and isolated) for sharing. Member accounts can then use shared subnets via `data.aws_ec2_subnets` or similar data sources.

## Validation

The module includes validations for:
- `cidr_netmask_length`: Must be between 16 and 24
- `az_count`: Must be between 2 and 4

## Related

- [AWS IPAM Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-ipam.html)
- [Resource Access Manager Documentation](https://docs.aws.amazon.com/ram/latest/userguide/what-is.html)
