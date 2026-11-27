# ==============================================================================
# VPC IPAM Module - Locals
#
# CIDR arithmetic for the "approved ranges only" reservation feature and for
# the cross-variable validations (lifecycle preconditions in main.tf).
#
# Every IPv4 CIDR is converted to { prefix, int } where int is the network
# address as an integer. "A contains B" is then:
#   A.prefix <= B.prefix && floor(B.int / 2^(32 - A.prefix)) == floor(A.int / 2^(32 - A.prefix))
# ==============================================================================
locals {
  ipv4_cidr_regex = "^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$"

  reservation_enabled = length(var.approved_cidrs) > 0

  # Primary + additional CIDRs per pool
  regional_pool_cidrs    = { for k, v in var.regional_pools : k => concat([v.cidr], v.additional_cidrs) }
  environment_pool_cidrs = { for k, v in var.environment_pools : k => concat([v.cidr], v.additional_cidrs) }

  # Additional CIDRs flattened into stable for_each keys ("<pool>|<cidr>")
  regional_additional_cidrs = {
    for item in flatten([
      for k, v in var.regional_pools : [for c in v.additional_cidrs : { pool = k, cidr = c }]
    ]) : "${item.pool}|${item.cidr}" => item
  }
  environment_additional_cidrs = {
    for item in flatten([
      for k, v in var.environment_pools : [for c in v.additional_cidrs : { pool = k, cidr = c }]
    ]) : "${item.pool}|${item.cidr}" => item
  }

  all_cidrs = distinct(concat(
    [var.top_level_cidr],
    var.approved_cidrs,
    flatten(values(local.regional_pool_cidrs)),
    flatten(values(local.environment_pool_cidrs)),
  ))

  # Integer representation of every IPv4 CIDR the module works with
  cidr_info = {
    for c in local.all_cidrs : c => {
      prefix = tonumber(split("/", c)[1])
      int    = sum([for i, octet in split(".", cidrhost(c, 0)) : tonumber(octet) * pow(256, 3 - i)])
    } if can(regex(local.ipv4_cidr_regex, c)) && can(cidrhost(c, 0))
  }

  top_level_is_ipv4 = contains(keys(local.cidr_info), var.top_level_cidr)
  top_level         = local.top_level_is_ipv4 ? local.cidr_info[var.top_level_cidr] : { prefix = 0, int = 0 }
  approved          = [for c in var.approved_cidrs : merge(local.cidr_info[c], { cidr = c }) if contains(keys(local.cidr_info), c)]

  # ----------------------------------------------------------------------------
  # Validation findings (empty list = valid). Used by preconditions in main.tf.
  # ----------------------------------------------------------------------------
  approved_outside_top_level = [
    for a in local.approved : a.cidr if !(
      local.top_level.prefix <= a.prefix &&
      floor(a.int / pow(2, 32 - local.top_level.prefix)) == floor(local.top_level.int / pow(2, 32 - local.top_level.prefix))
    )
  ]

  approved_smaller_than_block = [for a in local.approved : a.cidr if a.prefix > var.reservation_netmask_length]

  approved_overlaps = flatten([
    for i, a in local.approved : [
      for j, b in local.approved : "${a.cidr} overlaps ${b.cidr}" if j > i &&
      floor(a.int / pow(2, 32 - min(a.prefix, b.prefix))) == floor(b.int / pow(2, 32 - min(a.prefix, b.prefix)))
    ]
  ])

  regional_cidrs_not_approved = [
    for c in distinct(flatten(values(local.regional_pool_cidrs))) : c
    if contains(keys(local.cidr_info), c) && !anytrue([
      for a in local.approved : try(
        a.prefix <= local.cidr_info[c].prefix &&
        floor(local.cidr_info[c].int / pow(2, 32 - a.prefix)) == floor(a.int / pow(2, 32 - a.prefix)),
        false
      )
    ])
  ]

  environment_cidrs_outside_regional = flatten([
    for k, v in var.environment_pools : [
      for c in local.environment_pool_cidrs[k] : "${k}: ${c}"
      if contains(keys(local.cidr_info), c) && !anytrue([
        for r in lookup(local.regional_pool_cidrs, v.regional_pool_key, []) :
        contains(keys(local.cidr_info), r) &&
        try(
          local.cidr_info[r].prefix <= local.cidr_info[c].prefix &&
          floor(local.cidr_info[c].int / pow(2, 32 - local.cidr_info[r].prefix)) == floor(local.cidr_info[r].int / pow(2, 32 - local.cidr_info[r].prefix)),
          false
        )
      ])
    ]
  ])

  # ----------------------------------------------------------------------------
  # Reservation blocks
  #
  # The top-level CIDR is split into fixed blocks of reservation_netmask_length.
  # Every block outside the approved CIDRs becomes a custom allocation in the
  # top-level pool. With fixed blocks, approving a range only deletes
  # reservations, so create/delete ordering stays safe.
  # ----------------------------------------------------------------------------
  reservation_max_blocks = 1024
  reservation_newbits    = var.reservation_netmask_length - local.top_level.prefix

  reservation_computable = (
    local.reservation_enabled &&
    local.top_level_is_ipv4 &&
    local.reservation_newbits >= 0 &&
    pow(2, max(local.reservation_newbits, 0)) <= local.reservation_max_blocks
  )

  reservation_blocks = local.reservation_computable ? [
    for i in range(pow(2, local.reservation_newbits)) : {
      cidr = cidrsubnet(var.top_level_cidr, local.reservation_newbits, i)
      int  = local.top_level.int + i * pow(2, 32 - var.reservation_netmask_length)
    }
  ] : []

  reserved_cidrs = [
    for b in local.reservation_blocks : b.cidr if !anytrue([
      for a in local.approved :
      a.prefix <= var.reservation_netmask_length &&
      floor(b.int / pow(2, 32 - a.prefix)) == floor(a.int / pow(2, 32 - a.prefix))
    ])
  ]
}
