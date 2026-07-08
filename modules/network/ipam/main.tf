# ==============================================================================
# VPC IPAM Module
#
# Creates a hierarchical IPAM pool structure:
#   Organization Pool (top-level)
#     └── Regional Pools (one per region)
#           └── Environment Pools (prod/nonprod/shared per region)
#
# Regional Pool Capacity Planning (/10 = 4,194,304 IPs per region):
#   - Supports FOUR /12 environment pools per region (1,048,576 IPs each)
#   - Default configuration uses THREE /12 pools (75% utilized):
#       * Production:      10.0.0.0/12   (25%)
#       * Non-production:  10.16.0.0/12  (25%)
#       * Shared-services: 10.32.0.0/12  (25%)
#   - ONE /12 block remains RESERVED: 10.48.0.0/12 (25%)
#       * Available for: sandbox, DR, compliance-isolated, partner-access, etc.
#
# Environment pools are shared via RAM so workload accounts (or the Network
# account itself in shared-vpc mode) can allocate VPC CIDRs from them.
# ==============================================================================

data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# Delegate IPAM administration to this (Network) account.
#
# Grants the Network account organization-wide visibility into all VPCs,
# enabling CIDR collision detection and IP address monitoring — even for VPCs
# created manually by workload accounts outside of this automation.
#
# This is a read/monitoring capability and is safe to enable regardless of
# topology. It does NOT grant workload accounts the ability to allocate CIDRs.
# ------------------------------------------------------------------------------
resource "aws_vpc_ipam_organization_admin_account" "this" {
  count    = var.share_with_organization ? 1 : 0
  provider = aws.org-management

  delegated_admin_account_id = data.aws_caller_identity.current.account_id
}

# ------------------------------------------------------------------------------
# IPAM Instance
# ------------------------------------------------------------------------------
resource "aws_vpc_ipam" "this" {
  description = var.ipam_description

  dynamic "operating_regions" {
    for_each = toset(var.operating_regions)
    content {
      region_name = operating_regions.value
    }
  }

  tags = merge(var.tags, { Name = var.ipam_description })
}

# ------------------------------------------------------------------------------
# Top-Level Pool (Organization scope)
# ------------------------------------------------------------------------------
resource "aws_vpc_ipam_pool" "organization" {
  address_family = "ipv4"
  ipam_scope_id  = aws_vpc_ipam.this.private_default_scope_id
  description    = "Organization top-level pool"
  tags           = merge(var.tags, { Name = "organization-top-level" })
}

resource "aws_vpc_ipam_pool_cidr" "organization" {
  ipam_pool_id = aws_vpc_ipam_pool.organization.id
  cidr         = var.top_level_cidr
}

# ------------------------------------------------------------------------------
# Regional Pools
# One per region, nested under the organization pool.
# ------------------------------------------------------------------------------
resource "aws_vpc_ipam_pool" "regional" {
  for_each = var.regional_pools

  address_family      = "ipv4"
  ipam_scope_id       = aws_vpc_ipam.this.private_default_scope_id
  source_ipam_pool_id = aws_vpc_ipam_pool.organization.id
  locale              = each.value.region
  description         = "Regional pool: ${each.key}"
  tags                = merge(var.tags, { Name = "regional-${each.key}" })

  depends_on = [aws_vpc_ipam_pool_cidr.organization]
}

resource "aws_vpc_ipam_pool_cidr" "regional" {
  for_each     = var.regional_pools
  ipam_pool_id = aws_vpc_ipam_pool.regional[each.key].id
  cidr         = each.value.cidr
}

# ------------------------------------------------------------------------------
# Environment Pools (prod/nonprod per region)
# These are the leaf pools from which VPCs allocate CIDRs.
# ------------------------------------------------------------------------------
resource "aws_vpc_ipam_pool" "environment" {
  for_each = var.environment_pools

  address_family      = "ipv4"
  ipam_scope_id       = aws_vpc_ipam.this.private_default_scope_id
  source_ipam_pool_id = aws_vpc_ipam_pool.regional[each.value.regional_pool_key].id
  locale              = var.regional_pools[each.value.regional_pool_key].region
  description         = "Environment pool: ${each.key}"

  allocation_default_netmask_length = each.value.allocation_default_netmask_length
  allocation_min_netmask_length     = each.value.allocation_min_netmask_length
  allocation_max_netmask_length     = each.value.allocation_max_netmask_length

  tags = merge(var.tags, { Name = "env-${each.key}", environment = each.key })

  depends_on = [aws_vpc_ipam_pool_cidr.regional]
}

resource "aws_vpc_ipam_pool_cidr" "environment" {
  for_each     = var.environment_pools
  ipam_pool_id = aws_vpc_ipam_pool.environment[each.key].id
  cidr         = each.value.cidr
}

# ------------------------------------------------------------------------------
# RAM Sharing — Share environment pools with the organization
#
# Controlled by share_with_organization (set via enable_ipam_org_wide in the
# network customization). When enabled, environment pools are shared via RAM
# so member accounts can allocate VPC CIDRs from them. This is required for
# the isolated topology and also safe to enable alongside centrally-managed
# VPCs — IPAM guarantees non-overlapping allocations regardless of who creates
# the VPC.
#
# Each environment pool gets its own RAM share with a descriptive name so
# consumer accounts can immediately identify which pool is prod/nonprod/shared
# without needing to cross-reference pool IDs with the network team.
# ------------------------------------------------------------------------------
resource "aws_ram_resource_share" "ipam_pools" {
  for_each = var.share_with_organization ? var.environment_pools : {}

  name                      = "ipam-pool-${each.key}"
  allow_external_principals = false
  tags = merge(var.tags, {
    Name        = "ipam-pool-${each.key}"
    environment = each.key
  })
}

resource "aws_ram_resource_association" "ipam_pools" {
  for_each = var.share_with_organization ? var.environment_pools : {}

  resource_arn       = aws_vpc_ipam_pool.environment[each.key].arn
  resource_share_arn = aws_ram_resource_share.ipam_pools[each.key].arn
}

resource "aws_ram_principal_association" "organization" {
  for_each = var.share_with_organization ? var.environment_pools : {}

  principal          = var.organization_arn
  resource_share_arn = aws_ram_resource_share.ipam_pools[each.key].arn
}
