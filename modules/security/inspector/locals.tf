locals {
  # ------------------------------------------------------------------------------
  # OU path -> id lookup, built from the level 1/2/3 organizational unit lookups
  # in data.tf. Paths are "/"-joined OU name lists (e.g. "Workloads/NonProd").
  # ------------------------------------------------------------------------------
  ou_path_to_id_level_1 = {
    for ou in data.aws_organizations_organizational_units.level_1.children :
    ou.name => ou.id
  }

  ou_path_to_id_level_2 = merge([
    for parent_name, ous in data.aws_organizations_organizational_units.level_2 : {
      for ou in ous.children :
      "${parent_name}/${ou.name}" => ou.id
    }
  ]...)

  ou_path_to_id_level_3 = merge([
    for parent_path, ous in data.aws_organizations_organizational_units.level_3 : {
      for ou in ous.children :
      "${parent_path}/${ou.name}" => ou.id
    }
  ]...)

  ou_path_to_id = merge(
    local.ou_path_to_id_level_1,
    local.ou_path_to_id_level_2,
    local.ou_path_to_id_level_3,
  )

  # ------------------------------------------------------------------------------
  # Resolve caller-supplied OU paths (list of name segments) to OU IDs.
  # ------------------------------------------------------------------------------
  included_ou_ids = [
    for entry in var.organizational_units :
    local.ou_path_to_id[join("/", entry.path)]
  ]

  association_targets = toset(local.included_ou_ids)

  # ------------------------------------------------------------------------------
  # Individually excluded accounts can't be removed from an inherited OU
  # attachment, so a disable override policy is attached directly to them. AWS
  # Organizations resolves a Region listed in both an inherited enable list and
  # a more-specific disable list in favor of disable, so this wins over the
  # enablement policy.
  # See: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_inspector.html
  # ------------------------------------------------------------------------------
  has_excluded_accounts = length(var.excluded_account_ids) > 0
}
