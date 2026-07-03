# Control Tower Module

Terraform module that provisions an AWS Control Tower landing zone with prerequisite IAM roles, configurable landing zone features, and OU-level compliance controls.

This module handles the complete lifecycle of Control Tower setup including automatic creation of the four required service roles, landing zone manifest configuration, and deployment of the CT.MULTISERVICE.PV.1 region deny control to managed OUs.

## Usage

```hcl
module "control_tower" {
  source = "./modules/control-tower"

  log_archive_account_id         = "123456789012"
  audit_account_id               = "123456789013"
  governed_regions               = ["eu-central-1", "us-east-1"]
  landing_zone_version           = "3.3"

  # Logging configuration
  enable_centralized_logging          = true
  logging_bucket_retention_days       = 365
  access_logging_bucket_retention_days = 90

  # AWS Config
  enable_config             = true
  config_account_id         = "123456789013"
  config_logging_bucket_retention_days = 365

  # Identity Center
  enable_access_management = true

  # Region deny control
  enable_region_deny_control = true
  region_deny_target_ou_arns = {
    "Workloads" = "arn:aws:organizations::123456789012:ou/o-exampleorgid/ou-exxx-workloads"
  }
  region_deny_extra_exempted_actions = ["bedrock:InvokeModel"]

  # Root access management
  enable_centralized_root_access = true
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 6.0.0 |
| time | >= 0.9.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `log_archive_account_id` | The AWS account ID of the Log Archive account. | `string` | | yes |
| `audit_account_id` | The AWS account ID of the Audit (Security) account. | `string` | | yes |
| `governed_regions` | List of AWS regions to be governed by Control Tower. | `list(string)` | | yes |
| `landing_zone_version` | The version of the Control Tower landing zone to deploy. | `string` | | yes |
| `enable_centralized_logging` | Whether Control Tower enables centralized logging (CloudTrail + S3 logging bucket). When true, CT creates an org trail that logs to the centralized logging bucket. | `bool` | `true` | no |
| `logging_bucket_retention_days` | Days to retain logs in the centralized logging bucket. | `number` | `365` | no |
| `access_logging_bucket_retention_days` | Days to retain access logs for the logging bucket. | `number` | `365` | no |
| `kms_key_arn` | Optional KMS key ARN for encrypting Control Tower resources. | `string` | `""` | no |
| `enable_config` | Whether Control Tower enables AWS Config integration. When true, requires `config_account_id`. Available in landing zone version 4.0+. Note: if disabled, securityRoles, accessManagement, and backup must also be disabled. | `bool` | `true` | no |
| `config_account_id` | AWS account ID for the AWS Config aggregator. Typically the audit/security account. Required when `enable_config = true`. | `string` | `""` | no |
| `config_logging_bucket_retention_days` | Days to retain AWS Config logs. | `number` | `365` | no |
| `config_access_logging_bucket_retention_days` | Days to retain access logs for the Config logging bucket. | `number` | `365` | no |
| `config_kms_key_arn` | Optional KMS key ARN for encrypting AWS Config resources. Leave empty to skip. | `string` | `""` | no |
| `enable_access_management` | Whether Control Tower manages IAM Identity Center (directory groups and permission sets). Set to false when Identity Center was created separately or is managed outside of Control Tower. | `bool` | `false` | no |
| `enable_backup` | Whether Control Tower enables AWS Backup integration. When true, requires `backup_central_account_id`, `backup_admin_account_id`, and `backup_kms_key_arn`. | `bool` | `false` | no |
| `backup_central_account_id` | AWS account ID for the central backup vault. Required when `enable_backup = true`. | `string` | `""` | no |
| `backup_admin_account_id` | AWS account ID for the backup administrator. Required when `enable_backup = true`. | `string` | `""` | no |
| `backup_kms_key_arn` | KMS key ARN for encrypting backups. Required when `enable_backup = true`. | `string` | `""` | no |
| `enable_region_deny_control` | Whether to deploy the CT.MULTISERVICE.PV.1 OU-level region deny control on the OUs passed in `region_deny_target_ou_arns`. This replaces the landing-zone-level AWS-GR_REGION_DENY. | `bool` | `true` | no |
| `region_deny_target_ou_arns` | Map of OU name → ARN for CT-registered OUs to apply the region deny control to. Only pass OUs that have AWSControlTowerBaseline enabled. | `map(string)` | `{}` | no |
| `region_deny_excluded_ou_names` | Names of OUs (keys from `region_deny_target_ou_arns`) to EXCLUDE from the region deny control. Use this to temporarily exempt specific OUs. | `list(string)` | `[]` | no |
| `region_deny_extra_exempted_actions` | Additional IAM actions to exempt from the region deny, merged with built-in exemptions (bcm-dashboards, bcm-data-exports, bcm-pricing-calculator, pricingplanmanager). Use this for service-specific needs like Bedrock cross-region inference. | `list(string)` | `[]` | no |
| `region_deny_exempted_principal_arns` | IAM principal ARNs exempted from the region deny control. These principals can operate in any region. AWSControlTowerExecution is always exempted by the control itself. Leave empty unless specific automation roles need unrestricted region access. | `list(string)` | `[]` | no |
| `enable_centralized_root_access` | Whether to enable centralized root access management via IAM Identity Center. When enabled, enables RootCredentialsManagement and RootSessions features for the organization. | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| `landing_zone_arn` | The ARN of the Control Tower landing zone. |
| `landing_zone_version` | The deployed version of the Control Tower landing zone. |
| `landing_zone_drift_status` | The drift status of the landing zone. |
| `identity_center_instance_arn` | ARN of the IAM Identity Center instance. |
| `organization_root_id` | The root ID of the AWS Organization. |
| `organization_id` | The ID of the AWS Organization. |

## Notes

- **AWS Provider requirement**: This module requires AWS Provider version >= 6.0.0, which includes support for `aws_controltower_landing_zone`.
- **Async operation**: Landing zone creation is asynchronous. Terraform polls internally and timeouts are set to 60 minutes per operation.
- **IAM propagation**: The module includes a 10-second delay after creating prerequisite IAM roles to allow global propagation before Control Tower attempts to assume them. This prevents validation errors during landing zone creation.
- **Security OUs**: The region deny control is automatically applied to the `Security` and `Account Factory for Terraform` OUs created by Control Tower. Do not add these OUs to `region_deny_target_ou_arns` manually.
- **Region deny exemptions**: Built-in exemptions cover billing services (bcm-*) and others missing from the default Control Tower template. The `AWSControlTowerExecution` role is always exempted by the control itself.
- **Identity Center**: If `enable_access_management = true`, the module creates a `Control-Tower-Administrator` permission set with 4-hour session duration and full AdministratorAccess policy.
- **Config availability**: AWS Config integration is available in landing zone version 4.0 and later.
