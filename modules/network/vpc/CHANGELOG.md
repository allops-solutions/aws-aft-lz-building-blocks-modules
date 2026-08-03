# Changelog

# Changelog

All notable changes to the `network/vpc` module are documented in this file.

## [v1.0] - 2026-08-03

### Added

- Initial release of the `network/vpc` Terraform module.
- IPAM-backed VPC CIDR allocation with configurable netmask length.
- Public, private, and isolated subnet tiers across two to four Availability Zones.
- Optional IPv4 internet egress through an Internet Gateway and NAT Gateway topology.
- Automatic NAT Gateway topology selection based on the IPAM pool's `environment` tag when `nat_high_availability` is omitted.
- S3 and DynamoDB gateway VPC endpoints attached to all module-managed route tables.
- DNS hostname and DNS support configuration for the VPC.
- Default security group tagging and locked-down default security group management.
- Optional AWS RAM sharing of all module-managed subnets with AWS accounts and Organizations OU ARNs.
- Outputs for VPC metadata, subnet IDs and ARNs, route tables, NAT gateways, Internet Gateway, and RAM resource share details.
- Input validation for VPC name, IPAM pool ID, CIDR netmask length, and Availability Zone count.
- Terraform version requirement of `>= 1.6.0` and AWS provider requirement of `>= 6.23.0`.
