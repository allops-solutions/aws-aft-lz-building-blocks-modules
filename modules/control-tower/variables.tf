variable "log_archive_account_id" {
  description = "The AWS account ID of the Log Archive account."
  type        = string
}

variable "audit_account_id" {
  description = "The AWS account ID of the Audit (Security) account."
  type        = string
}

variable "governed_regions" {
  description = "List of AWS regions to be governed by Control Tower."
  type        = list(string)
}

variable "landing_zone_version" {
  description = "The version of the Control Tower landing zone to deploy."
  type        = string
}

variable "logging_bucket_retention_days" {
  description = "Days to retain logs in the centralized logging bucket."
  type        = number
  default     = 365
}

variable "access_logging_bucket_retention_days" {
  description = "Days to retain access logs for the logging bucket."
  type        = number
  default     = 365
}

variable "enable_access_management" {
  description = <<-EOT
    Whether Control Tower manages IAM Identity Center (directory groups and permission sets).
    Set to false when Identity Center was created separately or is managed outside of Control Tower.
  EOT
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "Optional KMS key ARN for encrypting Control Tower resources."
  type        = string
  default     = ""
}

variable "enable_centralized_logging" {
  description = <<-EOT
    Whether Control Tower enables centralized logging (CloudTrail + S3 logging bucket).
    This is what controls the CloudTrail organization trail in Control Tower.
    When true, CT creates an org trail that logs to the centralized logging bucket.
  EOT
  type        = bool
  default     = true
}

variable "enable_backup" {
  description = <<-EOT
    Whether Control Tower enables AWS Backup integration.
    When true, requires backup_central_account_id, backup_admin_account_id, and backup_kms_key_arn.
  EOT
  type        = bool
  default     = false
}

variable "backup_central_account_id" {
  description = "AWS account ID for the central backup vault. Required when enable_backup = true."
  type        = string
  default     = ""
}

variable "backup_admin_account_id" {
  description = "AWS account ID for the backup administrator. Required when enable_backup = true."
  type        = string
  default     = ""
}

variable "backup_kms_key_arn" {
  description = "KMS key ARN for encrypting backups. Required when enable_backup = true."
  type        = string
  default     = ""
}

variable "enable_config" {
  description = <<-EOT
    Whether Control Tower enables AWS Config integration.
    When true, requires config_account_id. Available in landing zone version 4.0+.
    Note: if disabled, securityRoles, accessManagement, and backup must also be disabled.
  EOT
  type        = bool
  default     = true
}

variable "config_account_id" {
  description = "AWS account ID for the AWS Config aggregator. Typically the audit/security account. Required when enable_config = true."
  type        = string
  default     = ""
}

variable "config_logging_bucket_retention_days" {
  description = "Days to retain AWS Config logs."
  type        = number
  default     = 365
}

variable "config_access_logging_bucket_retention_days" {
  description = "Days to retain access logs for the Config logging bucket."
  type        = number
  default     = 365
}

variable "config_kms_key_arn" {
  description = "Optional KMS key ARN for encrypting AWS Config resources. Leave empty to skip."
  type        = string
  default     = ""
}

# =============================================================================
# CT.MULTISERVICE.PV.1 — OU-Level Region Deny Control
# =============================================================================

variable "enable_region_deny_control" {
  description = <<-EOT
    Whether to deploy the CT.MULTISERVICE.PV.1 OU-level region deny control on
    the OUs passed in region_deny_target_ou_arns. This replaces the
    landing-zone-level AWS-GR_REGION_DENY.
  EOT
  type    = bool
  default = true
}

variable "region_deny_target_ou_arns" {
  description = <<-EOT
    Map of OU name -> ARN for CT-registered OUs to apply the region deny control to.
    Only pass OUs that have AWSControlTowerBaseline enabled.
  EOT
  type    = map(string)
  default = {}
}

variable "region_deny_excluded_ou_names" {
  description = <<-EOT
    Names of OUs (keys from region_deny_target_ou_arns) to EXCLUDE from the
    region deny control. Use this to temporarily exempt specific OUs.
  EOT
  type    = list(string)
  default = []
}

variable "region_deny_extra_exempted_actions" {
  description = <<-EOT
    Additional IAM actions to exempt from the region deny, merged with built-in
    exemptions (bcm-dashboards, bcm-data-exports, bcm-pricing-calculator,
    pricingplanmanager). Use this for service-specific needs like Bedrock
    cross-region inference.
  EOT
  type    = list(string)
  default = []
}

variable "region_deny_exempted_principal_arns" {
  description = <<-EOT
    IAM principal ARNs exempted from the region deny control. These principals
    can operate in any region. AWSControlTowerExecution is always exempted by
    the control itself. Leave empty unless specific automation roles need
    unrestricted region access.
  EOT
  type    = list(string)
  default = []
}

# =============================================================================
# Centralized Root Access Management
# =============================================================================

variable "enable_centralized_root_access" {
  description = <<-EOT
    Whether to enable centralized root access management via IAM Identity Center.
    When enabled, enables RootCredentialsManagement and RootSessions features
    for the organization.
  EOT
  type    = bool
  default = true
}
