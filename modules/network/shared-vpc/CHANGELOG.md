# Changelog

## [v1.0] - 2026-06-30

### Added

- Initial release of the `network/shared-vpc` module.
- VPC creation with CIDR allocation from AWS IPAM pools.
- Configurable subnet layouts:
  - `workload` — private subnets + isolated subnets (for databases and internal services).
  - `minimal` — private subnets only.
- Automatic subnet CIDR calculation using `cidrsubnet` based on VPC CIDR and AZ count.
- Support for 2 or 3 Availability Zones.
- AWS RAM resource sharing of subnets to workload accounts (by account ID) and/or organizational units (by OU ARN).
- Optional VPC Peering connection to an egress VPC for centralized internet access.
- Default route (`0.0.0.0/0`) via peering connection on private subnets when egress peering is enabled.
- Separate route tables for private and isolated subnets (isolated subnets have no internet route).
- DNS hostnames and DNS support enabled by default.
- Configurable netmask length (default `/22`) with validation (must be between `/16` and `/28`).
- Comprehensive outputs: VPC ID/ARN/CIDR, subnet IDs/ARNs by AZ, route table IDs, peering connection ID, RAM share ARN, and availability zones used.
