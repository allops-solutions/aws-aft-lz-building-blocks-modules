output "permission_sets" {
  description = "Map of permission set name => ARN created by this module instance."
  value       = local.permission_set_arns
}

output "assignment_count" {
  description = "Number of account assignments created by this module instance."
  value       = length(aws_ssoadmin_account_assignment.this)
}
