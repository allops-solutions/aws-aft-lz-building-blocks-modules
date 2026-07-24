output "delegated_admin_account_id" {
  description = "Account ID registered as the Amazon Inspector delegated administrator."
  value       = aws_inspector2_delegated_admin_account.this.account_id
}

output "regions" {
  description = "Regions where Amazon Inspector enablement policies are managed."
  value       = local.regions
}

output "enable_policy_id" {
  description = "ID of the Amazon Inspector enablement policy, or null when no scan type is enabled."
  value       = try(aws_organizations_policy.enable[0].id, null)
}

output "association_targets" {
  description = "Organizational unit IDs that the enablement policies are attached to."
  value       = local.association_targets
}
