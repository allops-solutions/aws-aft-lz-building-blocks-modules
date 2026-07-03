# Control Tower Module

Provisions and manages an AWS Control Tower landing zone with configurable security controls, logging, backup integration, and organizational unit (OU) governance.

## Usage

```hcl
module "control_tower" {
  source = "./modules/control-tower"

  # Core requirements
  log_archive_account_id = "123456789012"
  audit_account_id       = "123456789013"
  governed_regions       = ["eu-central-1", "us-east-1"]
  landing_zone_version   = "4.0"

  # Access management (optional)
  enable_access_management = true

  # Logging and encryption (optional)
  enable_centralized_logging           = true
  logging_bucket_retention_days        = 365
  access_logging_bucket_retention_days = 365
  kms_key_arn                          = "arn:aws:kms:eu-central-1:123456789012:key/12345678-1234-1234-1234-123456789012"

  # AWS Config integration (optional)
  enable_config                       = true
  config_account_id                   = "123456789013"
  config_logging_bucket_retention_days = 365

  # Backup integration (optional)
  enable_backup             = true
  backup_central_account_id = "123456789014"
  backup_admin_account_id   = "123456789015"
  backup_kms_key_arn        = "arn:aws:kms:eu-central-1:123456789012:key/87654321-4321-4321-4321-210987654321"

  # Root access management (optional)
  enable_centralized_root_access = true

  # Region deny control (optional)
  enable_region_deny_control            = true
  region_deny_target_ou_arns            = { "Workloads" = "arn:aws:organizations::123456789012:ou/o-1234567890/ou-xxxx-yyyyyyyy" }
  region_deny_excluded_ou_names         = []
  region_deny_extra_exempted_actions    = ["bedrock:InvokeModel"]
  region_deny_exempted_principal_arns   = []
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 6.0.0 |

> **Note:** AWS Provider >= 6.0.0 is required for `aws_controltower_landing_zone` resource support.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| log_archive_account_id | The AWS account ID of the Log Archive account. | `string` | n/a | yes |
| audit_account_id | The AWS account ID of the Audit (Security) account. | `string` | n/a | yes |
| governed_regions | List of AWS regions to be governed by Control Tower. | `list(string)` | n/a | yes |
| landing_zone_version | The version of the Control Tower landing zone to deploy. | `string` | n/a | yes |
| enable_access_management | Whether Control Tower manages IAM Identity Center (directory groups and permission sets). Set to false when Identity Center was created separately or is managed outside of Control Tower. | `bool` | `false` | no |
| enable_centralized_logging | Whether Control Tower enables centralized logging (CloudTrail + S3 logging bucket). This controls the CloudTrail organization trail in Control Tower. When true, CT creates an org trail that logs to the centralized logging bucket. | `bool` | `true` | no |
| logging_bucket_retention_days | Days to retain logs in the centralized logging bucket. | `number` | `365` | no |
| access_logging_bucket_retention_days | Days to retain access logs for the logging bucket. | `number` | `365` | no |
| kms_key_arn | Optional KMS key ARN for encrypting Control Tower resources. | `string` | `""` | no |
| enable_backup | Whether Control Tower enables AWS Backup integration. When true, requires backup_central_account_id, backup_admin_account_id, and backup_kms_key_arn. | `bool` | `false` | no |
| backup_central_account_id | AWS account ID for the central backup vault. Required when enable_backup = true. | `string` | `""` | no |
| backup_admin_account_id | AWS account ID for the backup administrator. Required when enable_backup = true. | `string` | `""` | no |
| backup_kms_key_arn | KMS key ARN for encrypting backups. Required when enable_backup = true. | `string` | `""` | no |
| enable_config | Whether Control Tower enables AWS Config integration. When true, requires config_account_id. Available in landing zone version 4.0+. Note: if disabled, securityRoles, accessManagement, and backup must also be disabled. | `bool` | `true` | no |
| config_account_id | AWS account ID for the AWS Config aggregator. Typically the audit/security account. Required when enable_config = true. | `string` | `""` | no |
| config_logging_bucket_retention_days | Days to retain AWS Config logs. | `number` | `365` | no |
| config_access_logging_bucket_retention_days | Days to retain access logs for the Config logging bucket. | `number` | `365` | no |
| config_kms_key_arn | Optional KMS key ARN for encrypting AWS Config resources. Leave empty to skip. | `string` | `""` | no |
| enable_region_deny_control | Whether to deploy the CT.MULTISERVICE.PV.1 OU-level region deny control on the OUs passed in region_deny_target_ou_arns. This replaces the landing-zone-level AWS-GR_REGION_DENY. | `bool` | `true` | no |
| region_deny_target_ou_arns | Map of OU name -> ARN for CT-registered OUs to apply the region deny control to. Only pass OUs that have AWSControlTowerBaseline enabled. | `map(string)` | `{}` | no |
| region_deny_excluded_ou_names | Names of OUs (keys from region_deny_target_ou_arns) to EXCLUDE from the region deny control. Use this to temporarily exempt specific OUs. | `list(string)` | `[]` | no |
| region_deny_extra_exempted_actions | Additional IAM actions to exempt from the region deny, merged with built-in exemptions (bcm-dashboards, bcm-data-exports, bcm-pricing-calculator, pricingplanmanager). Use this for service-specific needs like Bedrock cross-region inference. | `list(string)` | `[]` | no |
| region_deny_exempted_principal_arns | IAM principal ARNs exempted from the region deny control. These principals can operate in any region. AWSControlTowerExecution is always exempted by the control itself. Leave empty unless specific automation roles need unrestricted region access. | `list(string)` | `[]` | no |
| enable_centralized_root_access | Whether to enable centralized root access management via IAM Identity Center. When enabled, enables RootCredentialsManagement and RootSessions features for the organization. | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| landing_zone_arn | The ARN of the Control Tower landing zone. |
| landing_zone_version | The deployed version of the Control Tower landing zone. |
| landing_zone_drift_status | The drift status of the landing zone. |
| identity_center_instance_arn | ARN of the IAM Identity Center instance. |
| organization_root_id | The root ID of the AWS Organization. |
| organization_id | The ID of the AWS Organization. |

## Notes

- Landing zone creation is an asynchronous operation; Terraform polls internally for status updates. Initial deployments typically take 30-60 minutes.
- The module includes built-in exemptions for global and billing services (BCM, Pricing Calculator, Pricing Plan Manager) in the region deny control. Additional service-specific exemptions can be added via `region_deny_extra_exempted_actions`.
- When `enable_access_management` is true, the module automatically creates an IAM Identity Center permission set with full administrator access. Session duration is set to 4 hours.
- The region deny control (CT.MULTISERVICE.PV.1) automatically targets the Security OU and Account Factory for Terraform OU created by Control Tower, in addition to any custom OUs specified.
- Inheritance drift is automatically remediated for accounts that enroll in OUs managed by this module.
- KMS encryption is optional for logging and Config resources; if not specified, AWS-managed keys will be used.
