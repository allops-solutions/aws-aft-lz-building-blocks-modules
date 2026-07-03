# Changelog

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
