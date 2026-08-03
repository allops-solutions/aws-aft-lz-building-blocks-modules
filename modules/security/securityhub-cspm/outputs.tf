output "configuration_policy_id" {
  description = "UUID of the Security Hub CSPM configuration policy."
  value       = aws_securityhub_configuration_policy.this.id
}

output "configuration_policy_arn" {
  description = "ARN of the Security Hub CSPM configuration policy."
  value       = aws_securityhub_configuration_policy.this.arn
}

output "delegated_admin_account_id" {
  description = "Account ID registered as the Security Hub CSPM delegated administrator."
  value       = aws_securityhub_organization_admin_account.this.admin_account_id
}

output "association_targets" {
  description = "Set of OU IDs and account IDs associated with the configuration policy."
  value       = local.association_targets
}

output "notification_topic_arn" {
  description = "ARN of the SNS topic that delivers formatted Security Hub finding notifications."
  value       = aws_sns_topic.notifications.arn
}

output "notification_email" {
  description = "Email address subscribed to the notification topic (this account's own root email)."
  value       = local.notification_email
}

output "notification_min_severity" {
  description = "Lowest finding severity label that triggers a notification."
  value       = upper(var.notification_min_severity)
}

output "notification_severity_labels" {
  description = "Severity labels that trigger a notification (the minimum and everything above it)."
  value       = local.notification_severity_labels
}
