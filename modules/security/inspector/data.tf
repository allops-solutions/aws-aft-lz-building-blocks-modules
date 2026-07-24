data "aws_organizations_organization" "org" {
  provider = aws.org-management
}

# ------------------------------------------------------------------------------
# Resolve organizational unit IDs by name path (up to 3 levels below root).
# Terraform data sources can't recurse dynamically, so each level is looked up
# explicitly and then combined into a single path -> id lookup map.
# ------------------------------------------------------------------------------
data "aws_organizations_organizational_units" "level_1" {
  provider  = aws.org-management
  parent_id = data.aws_organizations_organization.org.roots[0].id
}

data "aws_organizations_organizational_units" "level_2" {
  for_each = { for ou in data.aws_organizations_organizational_units.level_1.children : ou.name => ou.id }
  provider = aws.org-management

  parent_id = each.value
}

data "aws_organizations_organizational_units" "level_3" {
  for_each = {
    for entry in flatten([
      for parent_name, ous in data.aws_organizations_organizational_units.level_2 : [
        for ou in ous.children : {
          path = "${parent_name}/${ou.name}"
          id   = ou.id
        }
      ]
    ]) : entry.path => entry.id
  }
  provider = aws.org-management

  parent_id = each.value
}
