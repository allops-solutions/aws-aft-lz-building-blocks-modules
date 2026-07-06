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

  ou_id_map = {
    for ou in data.aws_organizations_organizational_units.root.children :
    ou.name => ou.id
  }

  # Every OU name referenced by a group or an individual assignment.
  all_referenced_ous = toset(flatten(concat(
    [for g in values(var.groups) : g.account_ous],
    [for a in var.individual_assignments : a.account_ous],
  )))

  # Every user email referenced anywhere, for the Identity Store lookup.
  all_unique_emails = toset(concat(
    flatten([for g in values(var.groups) : g.users]),
    [for a in var.individual_assignments : a.user],
  ))
}
