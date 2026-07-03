# AWS Control Tower Landing Zone Module

This Terraform module provisions an AWS Control Tower landing zone with IAM Identity Center integration, centralized logging, backup, AWS Config, and organizational controls. It manages the landing zone manifest, creates required IAM roles, and deploys the OU-level region deny control across Control Tower-registered organizational units.

## Usage

```hcl
module "control_tower" {
  source = "./modules/control-tower"

  # Required account IDs
  log_archive_account_id = "123456789012"
  audit_account_id       = "234567890123"

  # Regions and landing zone version
  governed_regions        = ["eu-central-1", "eu-west-1"]
  landing_zone_version    = "3.3"

  # Enable/disable features
  enable_access_management      = true
  enable_centralized_logging    = true
  enable_backup                 = false
  enable_config                 = true
  enable_region_deny_control    = true
  enable_centralized_root_access = true

  # Logging configuration
  logging_bucket_retention_days           = 365
  access_logging_bucket_retention_days    = 365
  config_logging_bucket_retention_days    = 365
  config_access_logging_bucket_retention_days = 365

  # Config integration
  config_account_id = "234567890123"

  # Optional: KMS encryption
  kms_key_arn             = ""
  config_kms_key_arn      = ""

  # Region deny control customization
  region_deny_target_ou_arns = {
    "Workloads" = "arn:aws:organizations::123456789012:ou/o-xxxxx/ou-xxxx-yyyyyyyy"
  }
  region_deny_excluded_ou_names      = []
  region_deny_extra_exempted_actions = []
  region_deny_exempted_principal_arns = []
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 6.0.0 |

> **Note:** The `aws_controltower_landing_zone` resource requires AWS Provider version 6.0.0 or later.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `log_archive_account_id` | The AWS account ID of the Log Archive account. | `string` | n/a | yes |
| `audit_account_id` | The AWS account ID of the Audit (Security) account. | `string` | n/a | yes |
| `governed_regions` | List of AWS regions to be governed by Control Tower. | `list(string)` | n/a | yes |
| `landing_zone_version` | The version of the Control Tower landing zone to deploy. | `string` | n/a | yes |
| `enable_access_management` | Whether Control Tower manages IAM Identity Center (directory groups and permission sets). Set to false when Identity Center was created separately or is managed outside of Control Tower. | `bool` | `false` | no |
| `enable_centralized_logging` | Whether Control Tower enables centralized logging (CloudTrail + S3 logging bucket). This controls the CloudTrail organization trail in Control Tower. When true, CT creates an org trail that logs to the centralized logging bucket. | `bool` | `true` | no |
| `enable_backup` | Whether Control Tower enables AWS Backup integration. When true, requires `backup_central_account_id`, `backup_admin_account_id`, and `backup_kms_key_arn`. | `bool` | `false` | no |
| `enable_config` | Whether Control Tower enables AWS Config integration. When true, requires `config_account_id`. Available in landing zone version 4.0+. Note: if disabled, `securityRoles`, `accessManagement`, and `backup` must also be disabled. | `bool` | `true` | no |
| `enable_region_deny_control` | Whether to deploy the CT.MULTISERVICE.PV.1 OU-level region deny control on the OUs passed in `region_deny_target_ou_arns`. This replaces the landing-zone-level `AWS-GR_REGION_DENY`. | `bool` | `true` | no |
| `enable_centralized_root_access` | Whether to enable centralized root access management via IAM Identity Center. When enabled, enables `RootCredentialsManagement` and `RootSessions` features for the organization. | `bool` | `true` | no |
| `logging_bucket_retention_days` | Days to retain logs in the centralized logging bucket. | `number` | `365` | no |
| `access_logging_bucket_retention_days` | Days to retain access logs for the logging bucket. | `number` | `365` | no |
| `kms_key_arn` | Optional KMS key ARN for encrypting Control Tower resources. | `string` | `""` | no |
| `backup_central_account_id` | AWS account ID for the central backup vault. Required when `enable_backup = true`. | `string` | `""` | no |
| `backup_admin_account_id` | AWS account ID for the backup administrator. Required when `enable_backup = true`. | `string` | `""` | no |
| `backup_kms_key_arn` | KMS key ARN for encrypting backups. Required when `enable_backup = true`. | `string` | `""` | no |
| `config_account_id` | AWS account ID for the AWS Config aggregator. Typically the audit/security account. Required when `enable_config = true`. | `string` | `""` | no |
| `config_logging_bucket_retention_days` | Days to retain AWS Config logs. | `number` | `365` | no |
| `config_access_logging_bucket_retention_days` | Days to retain access logs for the Config logging bucket. | `number` | `365` | no |
| `config_kms_key_arn` | Optional KMS key ARN for encrypting AWS Config resources. Leave empty to skip. | `string` | `""` | no |
| `region_deny_target_ou_arns` | Map of OU name → ARN for CT-registered OUs to apply the region deny control to. Only pass OUs that have `AWSControlTowerBaseline` enabled. | `map(string)` | `{}` | no |
| `region_deny_excluded_ou_names` | Names of OUs (keys from `region_deny_target_ou_arns`) to EXCLUDE from the region deny control. Use this to temporarily exempt specific OUs. | `list(string)` | `[]` | no |
| `region_deny_extra_exempted_actions` | Additional IAM actions to exempt from the region deny, merged with built-in exemptions (`bcm-dashboards`, `bcm-data-exports`, `bcm-pricing-calculator`, `pricingplanmanager`). Use this for service-specific needs like Bedrock cross-region inference. | `list(string)` | `[]` | no |
| `region_deny_exempted_principal_arns` | IAM principal ARNs exempted from the region deny control. These principals can operate in any region. `AWSControlTowerExecution` is always exempted by the control itself. Leave empty unless specific automation roles need unrestricted region access. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| `landing_zone_arn` | The ARN of the Control Tower landing zone. |
| `landing_zone_version` | The deployed version of the Control Tower landing zone. |
| `landing_zone_drift_status` | The drift status of the landing zone. |
| `identity_center_instance_arn` | ARN of the IAM Identity Center instance. |
| `organization_root_id` | The root ID of the AWS Organization. |
| `organization_id` | The ID of the AWS Organization. |

## Features

### Control Tower Landing Zone

Deploys a fully configured Control Tower landing zone with:
- Organization setup and management
- Automatic IAM role creation
- Landing zone version support
- Drift remediation via `INHERITANCE_DRIFT` for automatic account enrollment

### Centralized Logging

When enabled, Control Tower manages an organization-wide CloudTrail trail that logs to a centralized S3 bucket in the Log Archive account. Access logs are stored separately with configurable retention periods.

### AWS Backup Integration

Optional AWS Backup setup with centralized backup vault and administrator account configuration. Requires a dedicated backup central account and backup admin account.

### AWS Config Integration

Optional AWS Config integration for compliance monitoring and configuration tracking across the organization. Requires a dedicated Config account (typically the audit/security account).

### IAM Identity Center Permission Sets

When `enable_access_management = true`, the module automatically creates a `Control-Tower-Administrator` permission set with full administrator access and 4-hour session duration.

### Centralized Root Access Management

When enabled, activates `RootCredentialsManagement` and `RootSessions` features at the organization level for centralized root account access management through IAM Identity Center.

### OU-Level Region Deny Control (CT.MULTISERVICE.PV.1)

Deploys a configurable region deny control that:
- Automatically targets Control Tower-managed OUs (Security, Account Factory for Terraform)
- Accepts caller-provided OUs via `region_deny_target_ou_arns`
- Includes built-in exemptions for global/billing services (BCM Dashboards, BCM Data Exports, BCM Pricing Calculator, Pricing Plan Manager, UXC)
- Supports additional exemptions for service-specific needs (e.g., Bedrock cross-region inference)
- Allows principal-level exemptions for automation roles
- Supports temporary OU-level exemptions via `region_deny_excluded_ou_names`
- Applies to all governed regions with 61-minute timeout per OU

> **Note:** The `AWSControlTowerExecution` role is automatically exempted by AWS Control Tower itself and does not need to be specified.

## Important Notes

- **Landing Zone Version:** Refer to AWS Control Tower documentation for available versions. Version 4.0+ is required for AWS Config integration.
- **AWS Provider Version:** Requires AWS Provider >= 6.0.0 for `aws_controltower_landing_zone` resource support.
- **Config Dependency:** When `enable_config = false`, you must also disable `enable_access_management` and `enable_backup`.
- **Region Deny Control:** Only applies the control to OUs that have `AWSControlTowerBaseline` enabled. Do not include OUs already managed by Control Tower (Security, Sandbox) unless they are the ones created during landing zone setup.
- **Drift Remediation:** The landing zone automatically remediates `INHERITANCE_DRIFT`, which enables automatic account enrollment in the landing zone.

## Timeouts

- **Landing Zone Deployment:** Approximately 30–60 minutes
- **Region Deny Control:** 61 minutes per OU
