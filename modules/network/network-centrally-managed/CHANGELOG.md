# Changelog

# Changelog

## [v2.0] - 2026-07-01

### Added

- `main.tf` — Full implementation of the centrally-managed VPC module:
  - VPC with IPAM-driven CIDR allocation
  - Three-tier subnet architecture (public, private, isolated) across 2–4 AZs
  - Stable 16-block addressing scheme that supports adding AZs without renumbering
  - Internet Gateway (conditional on `enable_egress`)
  - NAT Gateway(s) with high-availability or single-AZ mode
  - Locked-down default security group (deny-all, CIS compliant)
  - S3 and DynamoDB Gateway VPC Endpoints (free, keeps traffic off NAT)
  - RAM resource share for subnet sharing with workload accounts/OUs
- `variables.tf` — All input variables with validation rules:
  - `vpc_name`, `ipam_pool_id`, `cidr_netmask_length` (16–22)
  - `az_count` (2–4, default 2)
  - `enable_egress` (default true), `nat_high_availability` (default true)
  - `share_with_accounts`, `share_with_org_unit_arns`
  - `enable_dns_hostnames`, `enable_dns_support`
  - `tags`
  - Future extension points: `additional_cidr_blocks`, `custom_tags_by_resource_type`
- `outputs.tf` — Comprehensive outputs:
  - VPC identifiers (`vpc_id`, `vpc_arn`, `vpc_cidr_block`)
  - Subnet IDs and ARNs for all three tiers (mapped by AZ ID)
  - Route table IDs (public, private per-AZ, isolated)
  - Internet Gateway ID, NAT Gateway IDs and public IPs
  - Availability Zone IDs used
  - RAM resource share ARN
  - `subnet_capacity` — calculated IP capacity per subnet for planning
  - `vpc_metadata` — consolidated VPC metadata object
- `versions.tf` — Terraform >= 1.6.0, AWS provider >= 5.0

### Removed

- `releases/v1.0.md` — Previous release notes file removed from module source (release documentation now managed externally).
