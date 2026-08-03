# Changelog

## [2.0.0] - 2026-08-03

### Added
- New outputs for enhanced VPC introspection:
  - `default_security_group_id`, `default_network_acl_id`, `default_route_table_id` — VPC defaults
  - `vpc_instance_tenancy`, `vpc_enable_dns_support`, `vpc_enable_dns_hostnames`, `vpc_main_route_table_id` — VPC configuration
  - `vpc_owner_id` — AWS account owner of the VPC
  - `vpc_ipv6_association_id`, `vpc_ipv6_cidr_block`, `vpc_secondary_cidr_blocks` — IPv6/secondary CIDR status (null/empty by design)
  - `name` — VPC name for reference
  - `azs` — Availability Zone IDs in use
  - `igw_arn` — Internet Gateway ARN
  - `egress_only_internet_gateway_id` — Egress-only IGW status (null by design)
  - Expanded subnet outputs with separate maps, lists, and CIDR blocks for each tier (public, private, intra)
  - `public_subnets_ipv6_cidr_blocks`, `private_subnets_ipv6_cidr_blocks`, `intra_subnets_ipv6_cidr_blocks` — IPv6 CIDR status (empty by design)
  - `public_network_acl_id`, `public_network_acl_arn`, `private_network_acl_id`, `private_network_acl_arn`, `intra_network_acl_id`, `intra_network_acl_arn` — Network ACL status (null by design)
  - Route table and association outputs for all tiers
  - `nat_ids_by_az`, `nat_ids`, `nat_public_ips`, `natgw_interface_ids` — Expanded NAT Gateway outputs
  - `vpc_metadata` — Operational summary output with VPC configuration and topology details
- Validation on `cidr_netmask_length` to ensure integer values
- Validation on `az_count` to ensure integer values
- Precondition check `availability_zone_count` to validate that `az_count` does not exceed available Availability Zones in the region
- Input validation for `vpc_name` and `ipam_pool_id` to ensure they are not empty

### Changed
- NAT Gateway high-availability logic now strictly matches IPAM pool `environment` tag to the exact string `"production"` (case-insensitive after trimming), replacing regex-based matching
- `az_ids` now safely handles regions with fewer Availability Zones than `az_count` by using `min()` to prevent out-of-bounds slicing
- `pool_environment` local now normalizes the IPAM pool environment tag with `lower()` and `trimspace()` for consistent matching
- Variable descriptions enhanced for clarity and to document default behavior when values are omitted
- `data.aws_region.current.name` changed to `data.aws_region.current.region` in S3 and DynamoDB VPC endpoint service names for consistency with Terraform AWS provider best practices
- Reorganized and expanded outputs table with descriptive groupings for VPC, subnets, route tables, NAT, and RAM sections
- Several single-value outputs replaced with both map-based and list-based variants for greater flexibility

### Fixed
- Fixed potential crash when `az_count` exceeds the number of available Availability Zones by adding safety bounds checking on `az_ids` slice operation
- Corrected AWS data source attribute from `.name` to `.region` for VPC endpoint service name construction

### Removed
- Simplified NAT Gateway high-availability logic removed regex-based environment detection in favor of exact string matching
