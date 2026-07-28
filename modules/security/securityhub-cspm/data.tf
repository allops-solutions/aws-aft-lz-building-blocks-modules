# ------------------------------------------------------------------------------
# Organization structure — retrieve top-level OUs (direct children of root).
# If a top-level OU is managed by Control Tower, all OUs and accounts beneath
# it are considered CT-managed as well.
# ------------------------------------------------------------------------------
data "aws_organizations_organization" "org" {
  provider = aws.org-management
}

data "aws_organizations_organizational_units" "root" {
  provider  = aws.org-management
  parent_id = data.aws_organizations_organization.org.roots[0].id
}

# ------------------------------------------------------------------------------
# Identify Control Tower-managed OUs. A top-level OU is considered CT-managed
# if it has at least one enabled Control Tower control.
# ------------------------------------------------------------------------------
data "aws_controltower_controls" "root_ous" {
  for_each = { for ou in data.aws_organizations_organizational_units.root.children : ou.name => ou.arn }
  provider = aws.org-management

  target_identifier = each.value
}
