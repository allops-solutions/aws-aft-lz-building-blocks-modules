output "delegated_admin_account_id" {
  description = "Account ID registered as the Amazon GuardDuty delegated administrator."
  value       = aws_guardduty_organization_admin_account.this.id
}

output "detector_id" {
  description = "GuardDuty detector ID in the delegated administrator account."
  value       = aws_guardduty_detector.this.id
}

output "enrolled_account_ids" {
  description = "Account IDs enrolled as GuardDuty members."
  value       = local.member_account_ids
}

output "protection_plans" {
  description = "Protection plan configuration applied to the organization."
  value       = local.organization_features
}
