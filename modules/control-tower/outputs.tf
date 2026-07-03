output "landing_zone_arn" {
  description = "The ARN of the Control Tower landing zone."
  value       = aws_controltower_landing_zone.this.arn
}

output "landing_zone_version" {
  description = "The deployed version of the Control Tower landing zone."
  value       = aws_controltower_landing_zone.this.version
}

output "landing_zone_drift_status" {
  description = "The drift status of the landing zone."
  value       = aws_controltower_landing_zone.this.drift_status
}

output "identity_center_instance_arn" {
  description = "ARN of the IAM Identity Center instance."
  value       = local.identity_center_instance_arn
}

output "organization_root_id" {
  description = "The root ID of the AWS Organization."
  value       = data.aws_organizations_organization.this.roots[0].id
}

output "organization_id" {
  description = "The ID of the AWS Organization."
  value       = data.aws_organizations_organization.this.id
}
