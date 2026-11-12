data "aws_ssoadmin_instances" "this" {}
data "aws_organizations_organization" "this" {}
data "aws_organizations_organizational_units" "root" {
  parent_id = data.aws_organizations_organization.this.roots[0].id
}

locals {
  identity_store_id = data.aws_ssoadmin_instances.this.identity_store_ids[0]
  instance_arn      = data.aws_ssoadmin_instances.this.arns[0]

  # Management account (protected by Control Tower) - always excluded, plus any
  # caller-supplied protected accounts (e.g. the partner customer-access acct).
  management_account_id = data.aws_organizations_organization.this.master_account_id

  protected_account_ids = toset(concat(
    [local.management_account_id],
    var.protected_account_ids,
  ))

  all_account_ids = [
    for account in data.aws_organizations_organization.this.accounts :
    account.id if account.status == "ACTIVE"
  ]

  # Root-level OUs, name => id. `account_ous` resolves through this map;
  # `nested_ous` entries are one level below it and resolve via
  # data.aws_organizations_organizational_units.nested_children below.
  ou_id_map = {
    for ou in data.aws_organizations_organizational_units.root.children :
    ou.name => ou.id
  }

  # One flattened shape for groups and individual assignments, so OU resolution
  # and validation never have to care which of the two a target came from.
  all_specs = merge(
    { for g_key, g in var.groups : "group/${g_key}" => {
      account_ous  = g.account_ous
      nested_ous   = g.nested_ous
      account_ids  = g.account_ids
      all_accounts = g.all_accounts
    } },
    { for idx, a in var.individual_assignments : "individual/${idx}" => {
      account_ous  = a.account_ous
      nested_ous   = a.nested_ous
      account_ids  = a.account_ids
      all_accounts = false
    } },
  )

  # The OU identifiers each spec targets: bare names for `account_ous` entries
  # and "parent/child" paths for `nested_ous` entries.
  spec_ou_keys = {
    for spec_key, spec in local.all_specs : spec_key => concat(
      spec.account_ous,
      [for n in spec.nested_ous : "${n.parent}/${n.name}"],
    )
  }

  all_nested_ou_pairs = distinct(flatten([
    for spec in values(local.all_specs) : [
      for n in spec.nested_ous : { key = "${n.parent}/${n.name}", parent = n.parent }
    ]
  ]))

  # Every user email referenced anywhere, for the Identity Store lookup.
  all_unique_emails = toset(concat(
    flatten([for g in values(var.groups) : g.users]),
    [for a in var.individual_assignments : a.user],
  ))
}

# Children of every parent named by a nested_ous entry, so a nested OU can be
# targeted by name instead of being silently dropped. Parents that are not root
# OUs are filtered out rather than indexed, so a typo surfaces as the
# precondition message below instead of a raw "invalid index" error.
data "aws_organizations_organizational_units" "nested_children" {
  for_each = {
    for parent in distinct([for p in local.all_nested_ou_pairs : p.parent]) :
    parent => local.ou_id_map[parent]
    if contains(keys(local.ou_id_map), parent)
  }

  parent_id = each.value
}

locals {
  requested_ou_keys = toset(flatten(values(local.spec_ou_keys)))

  # "parent/child" => child OU id, narrowed to the pairs actually requested so
  # sibling OUs under the same parent are not carried into assignments.tf.
  nested_ou_id_map = merge([
    for parent_key, level in data.aws_organizations_organizational_units.nested_children : {
      for ou in level.children :
      "${parent_key}/${ou.name}" => ou.id
      if contains(local.requested_ou_keys, "${parent_key}/${ou.name}")
    }
  ]...)

  # Every distinct OU target => its id, deduped across specs. Bare names come
  # from the root map; "parent/child" paths from the nested map. Unresolvable
  # keys are omitted rather than erroring here, so the preconditions below get
  # to report the problem with an actionable message instead of a raw lookup
  # failure.
  all_ou_ids = {
    for ou_key in local.requested_ou_keys : ou_key => (
      contains(keys(local.ou_id_map), ou_key)
      ? local.ou_id_map[ou_key]
      : lookup(local.nested_ou_id_map, ou_key, "")
    )
    if contains(keys(local.ou_id_map), ou_key) || contains(keys(local.nested_ou_id_map), ou_key)
  }

  # An OU name that matches nothing used to yield zero assignments with no
  # error at all — a silent loss of access. These feed hard preconditions below.
  # Each list is checked against the map that actually resolves it: bare
  # `account_ous` names against the root map, "parent/child" paths from
  # `nested_ous` against the nested map.
  unknown_account_ous = sort(setsubtract(
    toset(flatten([for spec in values(local.all_specs) : spec.account_ous])),
    toset(keys(local.ou_id_map)),
  ))

  unknown_nested_ous = sort(setsubtract(
    toset([for p in local.all_nested_ou_pairs : p.key]),
    toset(keys(local.nested_ou_id_map)),
  ))

  unknown_nested_parents = sort(distinct([
    for p in local.all_nested_ou_pairs : p.parent
    if !contains(keys(local.ou_id_map), p.parent)
  ]))
}

# Preconditions rather than `check` blocks: a failed check is only a warning and
# does not stop the apply, whereas a failed precondition blocks it.
resource "terraform_data" "ou_target_validation" {
  lifecycle {
    precondition {
      condition = length(local.unknown_nested_parents) == 0
      error_message = format(
        "nested_ous.parent must be a root-level OU name. Not found at the org root: %s.",
        join(", ", local.unknown_nested_parents),
      )
    }

    precondition {
      condition = length(local.unknown_account_ous) == 0
      error_message = format(
        "account_ous contains names that are not root-level OUs: %s. Each account_ous entry must match a root-level OU exactly. If the OU sits one level below a root OU, use nested_ous = [{ name = \"<child>\", parent = \"<root OU>\" }] instead.",
        join(", ", local.unknown_account_ous),
      )
    }

    precondition {
      condition = length(local.unknown_nested_ous) == 0
      error_message = format(
        "nested_ous references OUs that do not exist directly under the named parent: %s. Check both the child name and the parent, and note that only one level of nesting is supported.",
        join(", ", local.unknown_nested_ous),
      )
    }
  }
}
