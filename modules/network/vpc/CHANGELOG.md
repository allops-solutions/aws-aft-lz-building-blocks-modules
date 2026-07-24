# Changelog

## [v1.0] - 2026-07-24

### Added

- Initial release of the network/vpc module.
- VPC creation with automatic CIDR allocation from IPAM pool.
- Three-tier subnet architecture: public, private, and isolated subnets across configurable Availability Zones (2–4).
- Internet Gateway for public subnet egress (configurable).
- NAT Gateway(s) for private subnet outbound internet access with high-availability option.
- Automatic NAT HA detection based on IPAM pool environment tags.
- Route tables for public, private, and isolated subnets with automatic route associations.
- Gateway VPC Endpoints for S3 and DynamoDB on all route tables.
- Resource Access Manager (RAM) sharing support for centrally-managed network topology.
- DNS hostname and DNS support configuration options.
- Comprehensive tagging strategy with support for custom tags on all resources.
- Default security group hardening (locked, no default rules).
- Output exports for VPC ID, subnet IDs/ARNs, route table IDs, NAT Gateway IPs, and metadata summary.


