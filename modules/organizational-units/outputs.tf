output "child_ous" {
  description = "Map of child OU logical key to { id, arn, name }."
  value = {
    for k, ou in aws_organizations_organizational_unit.child : k => {
      id   = ou.id
      arn  = ou.arn
      name = ou.name
    }
  }
}

output "baseline_ids" {
  description = "Discovered baseline name -> ID map for the CT home region."
  value       = local.baseline_ids
}
