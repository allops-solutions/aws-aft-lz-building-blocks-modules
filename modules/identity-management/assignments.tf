# ==============================================================================
# Assignments
#
# Identity Center has no OU-level inheritance: every assignment targets one
# specific account. "OU targeting" is a Terraform convenience — an OU name is
# expanded into its member account IDs here, and one assignment per account is
# created. Because of this, the protected_account_ids filter is a complete
# guarantee: if an account is filtered out, no assignment object exists for it,
# so no access path exists.
# ==============================================================================

# Resolve each referenced OU to the list of active account IDs it contains.
data "aws_organizations_organizational_unit_descendant_accounts" "this" {
  for_each  = { for ou_name in local.all_referenced_ous : ou_name => local.ou_id_map[ou_name] if contains(keys(local.ou_id_map), ou_name) }
  parent_id = each.value
}

locals {
  ou_accounts = {
    for ou_name, _ in data.aws_organizations_organizational_unit_descendant_accounts.this :
    ou_name => [
      for account in data.aws_organizations_organizational_unit_descendant_accounts.this[ou_name].accounts :
      account.id if account.status == "ACTIVE"
    ]
  }

  # Expand a target spec (all_accounts / account_ids / account_ous) into a
  # concrete, deduplicated, protected-filtered list of account IDs.
  expand_targets = {
    for key, spec in merge(
      { for g_key, g in var.groups : "group/${g_key}" => {
        account_ous  = g.account_ous
        account_ids  = g.account_ids
        all_accounts = g.all_accounts
      } },
      { for idx, a in var.individual_assignments : "individual/${idx}" => {
        account_ous  = a.account_ous
        account_ids  = a.account_ids
        all_accounts = false
      } },
    ) :
    key => [
      for account_id in distinct(concat(
        spec.all_accounts ? local.all_account_ids : [],
        spec.account_ids,
        flatten([for ou_name in spec.account_ous : lookup(local.ou_accounts, ou_name, [])]),
      )) : account_id
      if !contains(local.protected_account_ids, account_id)
    ]
  }
}

# ------------------------------------------------------------------------------
# User lookup (Identity Store)
# ------------------------------------------------------------------------------
data "aws_identitystore_user" "this" {
  for_each = local.all_unique_emails

  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = each.value
    }
  }
}

# ------------------------------------------------------------------------------
# Flatten groups + individual assignments into a single assignment set.
# Key format keeps group and individual assignments from colliding and stays
# stable across plans.
# ------------------------------------------------------------------------------
locals {
  group_assignments = flatten([
    for g_key, g in var.groups : [
      for email in distinct(g.users) : [
        for account_id in local.expand_targets["group/${g_key}"] : {
          permission_set = g.permission_set
          email          = email
          account_id     = account_id
        }
      ]
    ]
  ])

  individual_assignment_list = flatten([
    for idx, a in var.individual_assignments : [
      for account_id in local.expand_targets["individual/${idx}"] : {
        permission_set = a.permission_set
        email          = a.user
        account_id     = account_id
      }
    ]
  ])

  # Key by the assignment IDENTITY (permission set + user + account), not by its
  # source. A user who lands on the same account with the same permission set
  # via two groups, or via a group and an individual assignment, collapses into
  # exactly one assignment instead of colliding on duplicate resources.
  all_assignments = {
    for a in concat(local.group_assignments, local.individual_assignment_list) :
    "${a.permission_set}/${a.email}/${a.account_id}" => a
  }
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each = local.all_assignments

  instance_arn       = local.instance_arn
  permission_set_arn = local.permission_set_arns[each.value.permission_set]

  principal_id   = data.aws_identitystore_user.this[each.value.email].user_id
  principal_type = "USER"

  target_id   = each.value.account_id
  target_type = "AWS_ACCOUNT"
}
