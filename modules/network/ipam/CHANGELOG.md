# Changelog

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
