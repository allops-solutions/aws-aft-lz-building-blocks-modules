# Changelog

## [v1.0] - 2026-07-24

### Added

- Initial release of the VPC IPAM module
- Hierarchical IPAM pool structure: organization → regional → environment pools
- Support for multi-region IPAM with operating region configuration
- Environment pool management for prod/nonprod/shared environments
- AWS RAM resource sharing to enable organization-wide IPAM delegation
- IPAM organization admin account delegation for centralized IP address management
- Comprehensive outputs including IPAM IDs, ARNs, pool IDs, and RAM share ARNs
- Input validation for CIDR blocks and operating regions
- Configurable allocation netmask lengths (default, min, max) for environment pools
- Resource tagging support for all IPAM and RAM resources

### Features

- **Hierarchical Pool Structure**: Creates three-tier IPAM pool hierarchy with organization-level top-level pool, regional pools per operating region, and environment pools for workload isolation
- **Regional Capacity Planning**: Supports up to four /12 environment pools per region (1,048,576 IPs each), with default three-pool configuration and one reserved block
- **Organization-wide Visibility**: Delegates IPAM administration to the network account for centralized CIDR collision detection and IP address monitoring
- **Flexible Sharing**: Optional RAM sharing of environment pools with the organization to enable member accounts to allocate VPCs from managed pools
- **Provider Aliases**: Supports multi-account setup with `aws.org-management` provider alias for organization administration


