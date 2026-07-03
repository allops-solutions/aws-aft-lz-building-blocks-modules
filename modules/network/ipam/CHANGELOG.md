# Changelog

## [v1.0] - 2026-07-01

### Added

- IPAM instance with multi-region support via configurable `operating_regions`.
- Hierarchical pool structure: Organization → Regional → Environment pools.
- Top-level organization pool with configurable CIDR (`top_level_cidr`).
- Regional pools created dynamically from a `regional_pools` map variable.
- Environment pools (leaf pools) with configurable allocation netmask constraints (`allocation_default_netmask_length`, `allocation_min_netmask_length`, `allocation_max_netmask_length`).
- Optional IPAM delegated administrator registration via `aws_vpc_ipam_organization_admin_account` (enabled when `share_with_organization = true`).
- RAM resource share to expose environment pools to the entire AWS Organization.
- RAM principal association linking the organization ARN to the resource share.
- Input validation on all CIDR variables and `operating_regions`.
- Outputs for IPAM ID, ARN, scope ID, organization pool ID, regional pool IDs, environment pool IDs/ARNs, and RAM resource share ARN.
