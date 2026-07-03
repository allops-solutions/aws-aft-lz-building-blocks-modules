# network/egress

Terraform module that creates a dedicated egress VPC for centralized internet access. Workload VPCs in a shared-vpc topology route outbound traffic (`0.0.0.0/0`) through VPC Peering connections to this VPC, where NAT Gateways handle internet egress.

The module provisions:

- A VPC with CIDR allocated from an AWS VPC IPAM pool
- Public subnets with an Internet Gateway (for NAT Gateways)
- One NAT Gateway per AZ for high availability
- Private subnets that receive peered traffic from workload VPCs
- Return routes to send response traffic back through peering connections

## Traffic Flow

```
Workload VPC → VPC Peering → Egress Private Subnet → NAT GW → IGW → Internet
Internet → IGW → NAT GW → Egress Private Subnet → VPC Peering → Workload VPC
```

## Usage

```hcl
module "egress_vpc" {
  source = "./modules/network/egress"

  vpc_name            = "egress"
  ipam_pool_id        = aws_vpc_ipam_pool.main.id
  cidr_netmask_length = 22
  az_count            = 2

  peer_vpc_cidrs = {
    workload-a = "10.1.0.0/20"
    workload-b = "10.2.0.0/20"
  }

  peer_vpc_peering_connection_ids = {
    workload-a = aws_vpc_peering_connection.workload_a.id
    workload-b = aws_vpc_peering_connection.workload_b.id
  }

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
| aws (provider) | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `vpc_name` | Name for the egress VPC. | `string` | `"egress"` | no |
| `ipam_pool_id` | IPAM pool ID from which this VPC allocates its CIDR. | `string` | — | **yes** |
| `cidr_netmask_length` | Netmask length for VPC CIDR allocation from IPAM pool (e.g. 22 for /22). Must be between 16 and 28. | `number` | `22` | no |
| `az_count` | Number of Availability Zones for NAT Gateway deployment (2 or 3). Each AZ gets one NAT GW. | `number` | `2` | no |
| `peer_vpc_cidrs` | Map of peered workload VPC names to their CIDR blocks. Used to create return routes from the egress VPC back through the peering connections. | `map(string)` | `{}` | no |
| `peer_vpc_peering_connection_ids` | Map of peered workload VPC names to their VPC Peering connection IDs. Used to create return routes in the egress VPC route table. | `map(string)` | `{}` | no |
| `tags` | Tags to apply to all resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | ID of the egress VPC. |
| `vpc_arn` | ARN of the egress VPC. |
| `vpc_cidr_block` | CIDR block allocated to the egress VPC. |
| `vpc_owner_id` | AWS account ID that owns the egress VPC (Network account). |
| `internet_gateway_id` | ID of the Internet Gateway. |
| `nat_gateway_ids` | Map of AZ name to NAT Gateway ID. |
| `nat_eip_public_ips` | Map of AZ name to NAT Gateway public IP (for allowlisting). |
| `public_subnet_ids` | Map of AZ name to public subnet ID. |
| `private_subnet_ids` | Map of AZ name to private subnet ID. |
| `public_route_table_id` | ID of the public route table. |
| `private_route_table_ids` | Map of AZ name to private route table ID. |
| `availability_zones` | List of availability zones used. |
