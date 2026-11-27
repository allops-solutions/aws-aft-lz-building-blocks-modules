# ==============================================================================
# VPC IPAM Module - Approved ranges and pool sharing
#
# Turns the high-level inputs (approved_ranges, pool_sharing) into the pools the
# resources in main.tf create. Without approved_ranges, regional_pools,
# environment_pools and approved_cidrs are used exactly as passed in.
#
# With approved_ranges: one regional pool per entry, plus
# "<name>-production" and "<name>-non-production" pools (split = true) or a
# "<name>" shared-services pool (split = false) built from its CIDRs.
# Allocation rules (VPC sizes) come from the matching entries of
# environment_pools (used as templates), capped at the pool size;
# shared-services pools hand out /18 VPCs only.
# ==============================================================================
data "aws_region" "current" {}

locals {
  use_ranges  = length(var.approved_ranges) > 0
  home_region = data.aws_region.current.region

  # Pool layout per split value: environment => half of each CIDR (-1 = whole CIDR)
  split_layout = tomap({ production = 0, non-production = 1 })
  whole_layout = tomap({ shared-services = -1 })

  # shared-services pools (split = false): /16 -> 4 VPCs, /15 -> 8 VPCs.
  shared_vpc_netmask_length = 18

  effective_operating_regions = local.use_ranges ? distinct(concat(
    var.operating_regions, [local.home_region], [for name, r in var.approved_ranges : r.region]
  )) : var.operating_regions

  effective_approved_cidrs = local.use_ranges ? flatten([for name, r in var.approved_ranges : r.cidrs]) : var.approved_cidrs

  effective_regional_pools = local.use_ranges ? {
    for name, r in var.approved_ranges : name => {
      region           = r.region
      cidr             = r.cidrs[0]
      additional_cidrs = slice(r.cidrs, 1, length(r.cidrs))
    }
  } : var.regional_pools

  # Pool items grouped by pool name; a group with more than one item is a
  # name clash (checked in main.tf).
  derived_pool_groups = {
    for item in flatten([
      for name, r in var.approved_ranges : [
        for env, half in(r.split ? local.split_layout : local.whole_layout) : {
          key = r.split ? "${name}-${env}" : name
          # Netmask of the pool's primary CIDR; VPC sizes are capped at it.
          pool_prefix = tonumber(split("/", r.cidrs[0])[1]) + (half < 0 ? 0 : 1)
          range_name  = name
          env         = env
          half        = half
          cidrs       = r.cidrs
        }
      ]
    ]) : item.key => item...
  }
  duplicate_pool_names = [for k, g in local.derived_pool_groups : k if length(g) > 1]

  derived_environment_pools = {
    for key, g in local.derived_pool_groups : key => merge(var.environment_pools[g[0].env], {
      regional_pool_key                 = g[0].range_name
      cidr                              = g[0].half < 0 ? g[0].cidrs[0] : cidrsubnet(g[0].cidrs[0], 1, g[0].half)
      additional_cidrs                  = [for c in slice(g[0].cidrs, 1, length(g[0].cidrs)) : g[0].half < 0 ? c : cidrsubnet(c, 1, g[0].half)]
      environment                       = g[0].env
      allocation_default_netmask_length = g[0].half < 0 ? local.shared_vpc_netmask_length : max(var.environment_pools[g[0].env].allocation_default_netmask_length, g[0].pool_prefix)
      allocation_min_netmask_length     = g[0].half < 0 ? local.shared_vpc_netmask_length : max(var.environment_pools[g[0].env].allocation_min_netmask_length, g[0].pool_prefix)
      allocation_max_netmask_length     = g[0].half < 0 ? local.shared_vpc_netmask_length : var.environment_pools[g[0].env].allocation_max_netmask_length
    })
  }

  base_environment_pools = local.use_ranges ? local.derived_environment_pools : var.environment_pools

  # VPCs in a shared-services pool from approved_ranges that ask for a size
  # other than /18.
  shared_vpc_size_violations = [
    for name, v in var.vpc_requests : name
    if local.use_ranges && v.netmask_length != null &&
    try(local.base_environment_pools[v.pool_key].allocation_max_netmask_length == local.shared_vpc_netmask_length && local.pool_environments[v.pool_key] == "shared-services", false) &&
    v.netmask_length != local.shared_vpc_netmask_length
  ]

  # ----------------------------------------------------------------------------
  # Pool sharing (share_with_organization + pool_sharing)
  #
  # Pools are matched to pool_sharing by environment (the pool's "environment"
  # value, or its key). Only OUs of environments that have pools are looked up.
  # With an empty pool_sharing, each pool uses its own share_with_* values.
  # ----------------------------------------------------------------------------
  sharing_targeted  = var.share_with_organization && length(var.pool_sharing) > 0
  pool_environments = { for k, v in local.base_environment_pools : k => coalesce(v.environment, k) }
  sharing_envs      = local.sharing_targeted ? distinct(values(local.pool_environments)) : []
  sharing_ou_paths = distinct(flatten([
    for env, s in var.pool_sharing : s.org_units if contains(local.sharing_envs, env)
  ]))
  sharing_ou_arns = merge(
    { for p, ou in data.aws_organizations_organizational_unit.ou_level1 : p => ou.arn },
    { for p, ou in data.aws_organizations_organizational_unit.ou_level2 : p => ou.arn },
    { for p, ou in data.aws_organizations_organizational_unit.ou_level3 : p => ou.arn },
  )
  unshared_pools = [for k, env in local.pool_environments : k if local.sharing_targeted && !contains(keys(var.pool_sharing), env)]

  effective_environment_pools = {
    for k, v in local.base_environment_pools : k => merge(v, {
      share_with_accounts = local.sharing_targeted ? try(var.pool_sharing[local.pool_environments[k]].accounts, []) : v.share_with_accounts
      share_with_org_unit_arns = local.sharing_targeted ? [
        for p in try(var.pool_sharing[local.pool_environments[k]].org_units, []) : local.sharing_ou_arns[p]
      ] : v.share_with_org_unit_arns
    })
  }
}

# ------------------------------------------------------------------------------
# OU lookups for pool_sharing (management account, up to 3 levels).
# Only read when share_with_organization = true and pool_sharing is set.
# ------------------------------------------------------------------------------
data "aws_organizations_organization" "management" {
  count    = length(local.sharing_ou_paths) > 0 ? 1 : 0
  provider = aws.org-management
}

data "aws_organizations_organizational_unit" "ou_level1" {
  for_each  = toset([for p in local.sharing_ou_paths : split("/", p)[0]])
  provider  = aws.org-management
  parent_id = data.aws_organizations_organization.management[0].roots[0].id
  name      = each.value
}

data "aws_organizations_organizational_unit" "ou_level2" {
  for_each  = toset([for p in local.sharing_ou_paths : join("/", slice(split("/", p), 0, 2)) if length(split("/", p)) >= 2])
  provider  = aws.org-management
  parent_id = data.aws_organizations_organizational_unit.ou_level1[split("/", each.value)[0]].id
  name      = split("/", each.value)[1]
}

data "aws_organizations_organizational_unit" "ou_level3" {
  for_each  = toset([for p in local.sharing_ou_paths : p if length(split("/", p)) == 3])
  provider  = aws.org-management
  parent_id = data.aws_organizations_organizational_unit.ou_level2[join("/", slice(split("/", each.value), 0, 2))].id
  name      = split("/", each.value)[2]
}
