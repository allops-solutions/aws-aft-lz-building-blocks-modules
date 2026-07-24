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


## [1.0.0] - 2026-07-08

### Added

- Initial release of the VPC IPAM module
- Hierarchical IPAM pool structure with organization-level, regional, and environment-level pools
- Automatic IPAM instance creation with configurable operating regions
- Regional pool support with capacity planning for multiple environment pools (prod/nonprod/shared)
- Environment pools configured with customizable allocation netmask lengths (default/min/max)
- Organization-wide IPAM delegation to the Network account for centralized CIDR management and collision detection
- RAM sharing for environment pools to enable workload accounts to allocate VPC CIDRs
- Comprehensive outputs for all pool IDs, ARNs, and RAM share ARNs
- Input validation for CIDR blocks and required fields
- Full support for tagging across all IPAM resources
- Terraform >= 1.6.0 and AWS provider >= 5.0 support
- Provider alias support for organization management operations


## [1.0] - 2026-07-03

### Added

- Initial release of the VPC IPAM module
- Hierarchical IPAM pool structure: Organization → Regional → Environment pools
- Support for multi-region IPAM instances with configurable operating regions
- Three-tier pool architecture enabling flexible IP address management across environments
- Environment pools for production, non-production, and shared-services workloads
- Organization-wide IPAM capability with delegated administrator account setup
- AWS Resource Access Manager (RAM) sharing for environment pools with the organization
- CIDR collision detection and IP address monitoring across the organization
- Configurable allocation constraints (default, min, max netmask length) per environment pool
- Comprehensive tagging support across all IPAM resources
- Full output exports including IPAM IDs, ARNs, pool references, and RAM share details
- Input validation for CIDR blocks and operating regions
- Support for custom IPAM descriptions and resource tagging

### Changed

- N/A (initial release)

### Fixed

- N/A (initial release)

### Removed

- N/A (initial release)
