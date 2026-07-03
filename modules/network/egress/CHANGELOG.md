# Changelog

## [v1.0] - 2026-06-30

### Added

- Dedicated egress VPC with CIDR allocated from AWS VPC IPAM.
- Public subnets with Internet Gateway for outbound internet access.
- NAT Gateways (one per AZ) for high-availability egress from private subnets.
- Private subnets for receiving traffic from peered workload VPCs.
- Per-AZ private route tables routing `0.0.0.0/0` through local NAT Gateway.
- Return routes in both private and public route tables to send response traffic back through VPC Peering connections to workload VPCs.
- Configurable AZ count (2 or 3) for NAT Gateway deployment.
- Configurable CIDR netmask length (16–28) for VPC allocation.
- Support for multiple peered workload VPCs via `peer_vpc_cidrs` and `peer_vpc_peering_connection_ids` variables.
- Outputs for VPC ID, ARN, CIDR block, subnet IDs, NAT Gateway IDs, EIP public IPs, and route table IDs.
