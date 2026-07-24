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


## [v1.0] - 2026-07-03

### Added

- Initial release of the VPC module
- VPC creation with automatic CIDR allocation from AWS IPAM
- Three-tier subnet architecture: public, private, and isolated subnets
- Multi-AZ support (2–4 Availability Zones)
- Internet Gateway for public subnet internet access
- NAT Gateway(s) for private subnet egress, with configurable high-availability mode
- Automatic NAT HA detection based on IPAM pool environment tag
- Per-AZ route tables for private subnets
- Gateway VPC Endpoints for S3 and DynamoDB
- Resource Access Manager (RAM) integration for centrally-managed network topology
- Support for sharing subnets with specific AWS accounts or organizational units
- Configurable DNS hostnames and DNS support
- Default security group lockdown
- Comprehensive outputs including VPC metadata summary

### Features

- **IPAM-driven CIDR allocation**: No manual CIDR blocks required; integrates with AWS IPAM for dynamic allocation
- **Flexible NAT configuration**: Supports both single-NAT and high-availability (one per AZ) NAT Gateway deployments
- **Environment-aware defaults**: NAT HA automatically enabled for production environments based on IPAM pool tags
- **Dual-mode deployment**: Works as either a centrally-managed shared network (with RAM) or an isolated local VPC
- **Multi-tier routing**: Separate route tables and subnets for public, private, and isolated workloads
- **Built-in egress control**: Optional egress configuration to restrict internet access
- **Terraform 1.6+ support**: Uses modern Terraform features including for_each and for expressions
- **AWS Provider 5.0+**: Compatible with latest AWS provider versions
