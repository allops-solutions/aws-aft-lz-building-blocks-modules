# ==============================================================================
# VPC IPAM Module
#
# Creates a hierarchical IPAM pool structure:
#   Organization Pool (top-level)
#     └── Regional Pools (one per region)
#           └── Environment Pools (prod/nonprod/shared per region)
#
# Pool sizes come from the caller (see the network customization variables).
#
# Approved ranges (approved_cidrs, optional):
#   The top-level CIDR is split into blocks of reservation_netmask_length
#   (default /16). Every block outside approved_cidrs gets a custom allocation
#   in the top-level pool, which blocks it for pools and VPCs and makes IPAM
#   flag VPCs created there as overlapping. To open more space, add the range
#   to approved_cidrs and to a regional pool's additional_cidrs.
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

  # Private IPv4 pools require the Advanced tier (also the provider default).
  tier = "advanced"

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

  # Cross-variable validations: fail the plan when inputs are inconsistent.
  lifecycle {
    precondition {
      condition     = length(local.environment_cidrs_outside_regional) == 0
      error_message = "Every environment pool CIDR (cidr and additional_cidrs) must be inside a CIDR of its regional pool. Invalid: ${join(", ", local.environment_cidrs_outside_regional)}."
    }
    precondition {
      condition     = !local.reservation_enabled || local.top_level_is_ipv4
      error_message = "approved_cidrs requires top_level_cidr to be an IPv4 CIDR."
    }
    precondition {
      condition     = !local.reservation_enabled || local.reservation_newbits >= 0
      error_message = "reservation_netmask_length (/${var.reservation_netmask_length}) must be equal to or longer than the top_level_cidr prefix (${var.top_level_cidr})."
    }
    precondition {
      condition     = !local.reservation_enabled || pow(2, max(local.reservation_newbits, 0)) <= local.reservation_max_blocks
      error_message = "reservation_netmask_length /${var.reservation_netmask_length} would split ${var.top_level_cidr} into more than ${local.reservation_max_blocks} reservation blocks. Use a shorter reservation_netmask_length."
    }
    precondition {
      condition     = length(local.approved_outside_top_level) == 0
      error_message = "Every approved_cidrs entry must be inside top_level_cidr (${var.top_level_cidr}). Invalid: ${join(", ", local.approved_outside_top_level)}."
    }
    precondition {
      condition     = length(local.approved_smaller_than_block) == 0
      error_message = "Every approved_cidrs entry must be /${var.reservation_netmask_length} or larger (reservation_netmask_length). Invalid: ${join(", ", local.approved_smaller_than_block)}."
    }
    precondition {
      condition     = length(local.approved_overlaps) == 0
      error_message = "approved_cidrs entries must not overlap: ${join("; ", local.approved_overlaps)}."
    }
    precondition {
      condition     = !local.reservation_enabled || length(local.regional_cidrs_not_approved) == 0
      error_message = "Every regional pool CIDR (cidr and additional_cidrs) must be inside an approved_cidrs entry, otherwise it would collide with a reservation. Not approved: ${join(", ", local.regional_cidrs_not_approved)}."
    }
  }
}

resource "aws_vpc_ipam_pool_cidr" "organization" {
  ipam_pool_id = aws_vpc_ipam_pool.organization.id
  cidr         = var.top_level_cidr
}

# ------------------------------------------------------------------------------
# Reservations ("approved ranges only" mode)
#
# One custom allocation per reservation block outside approved_cidrs.
# Regional pool CIDRs depend on this resource, so newly approved ranges are
# released here before they are provisioned to a regional pool.
# ------------------------------------------------------------------------------
resource "aws_vpc_ipam_pool_cidr_allocation" "reserved" {
  for_each = toset(local.reserved_cidrs)

  ipam_pool_id = aws_vpc_ipam_pool.organization.id
  cidr         = each.value
  description  = var.reservation_description

  tags = merge(var.tags, {
    Name             = "reserved-${each.value}"
    ipam-reservation = "not-approved-for-aws"
  })

  depends_on = [aws_vpc_ipam_pool_cidr.organization]
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

  depends_on = [aws_vpc_ipam_pool_cidr_allocation.reserved]
}

# Extra CIDRs for a regional pool (e.g. a range approved for a new project).
# A separate resource keeps the primary CIDR's state address stable.
resource "aws_vpc_ipam_pool_cidr" "regional_additional" {
  for_each     = local.regional_additional_cidrs
  ipam_pool_id = aws_vpc_ipam_pool.regional[each.value.pool].id
  cidr         = each.value.cidr

  depends_on = [
    aws_vpc_ipam_pool_cidr.organization,
    aws_vpc_ipam_pool_cidr_allocation.reserved,
  ]
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

  tags = merge(var.tags, { Name = "env-${each.key}", environment = coalesce(each.value.environment, each.key) })

  depends_on = [
    aws_vpc_ipam_pool_cidr.regional,
    aws_vpc_ipam_pool_cidr.regional_additional,
  ]
}

resource "aws_vpc_ipam_pool_cidr" "environment" {
  for_each     = var.environment_pools
  ipam_pool_id = aws_vpc_ipam_pool.environment[each.key].id
  cidr         = each.value.cidr
}

# Extra CIDRs for an environment pool. A separate resource keeps the primary
# CIDR's state address stable.
resource "aws_vpc_ipam_pool_cidr" "environment_additional" {
  for_each     = local.environment_additional_cidrs
  ipam_pool_id = aws_vpc_ipam_pool.environment[each.value.pool].id
  cidr         = each.value.cidr

  depends_on = [
    aws_vpc_ipam_pool_cidr.regional,
    aws_vpc_ipam_pool_cidr.regional_additional,
  ]
}

# ------------------------------------------------------------------------------
# RAM Sharing - Share environment pools with member accounts
#
# Controlled by share_with_organization. Each environment pool gets its own
# RAM share named after the pool, shared with:
#   - its share_with_accounts / share_with_org_unit_arns, when set
#   - the whole organization, otherwise
# Member accounts allocate VPC CIDRs from the pools shared with them. IPAM
# keeps allocations non-overlapping regardless of who creates the VPC.
# ------------------------------------------------------------------------------
resource "aws_ram_resource_share" "ipam_pools" {
  for_each = var.share_with_organization ? var.environment_pools : {}

  name                      = "ipam-pool-${each.key}"
  allow_external_principals = false
  tags = merge(var.tags, {
    Name        = "ipam-pool-${each.key}"
    environment = coalesce(each.value.environment, each.key)
  })
}

resource "aws_ram_resource_association" "ipam_pools" {
  for_each = var.share_with_organization ? var.environment_pools : {}

  resource_arn       = aws_vpc_ipam_pool.environment[each.key].arn
  resource_share_arn = aws_ram_resource_share.ipam_pools[each.key].arn
}

# Pools without explicit principals: shared with the whole organization.
resource "aws_ram_principal_association" "organization" {
  for_each = var.share_with_organization ? {
    for k, v in var.environment_pools : k => v
    if length(v.share_with_accounts) + length(v.share_with_org_unit_arns) == 0
  } : {}

  principal          = var.organization_arn
  resource_share_arn = aws_ram_resource_share.ipam_pools[each.key].arn
}

# Pools with explicit principals: shared only with those accounts and OUs.
resource "aws_ram_principal_association" "targeted" {
  for_each = var.share_with_organization ? {
    for item in flatten([
      for k, v in var.environment_pools : [
        for p in distinct(concat(v.share_with_accounts, v.share_with_org_unit_arns)) : { pool = k, principal = p }
      ]
    ]) : "${item.pool}|${item.principal}" => item
  } : {}

  principal          = each.value.principal
  resource_share_arn = aws_ram_resource_share.ipam_pools[each.value.pool].arn
}
