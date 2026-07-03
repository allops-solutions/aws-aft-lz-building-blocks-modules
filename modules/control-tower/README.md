# AWS Control Tower Landing Zone Module

Terraform module that provisions a complete AWS Control Tower landing zone with prerequisite IAM roles, manifest configuration, and OU-level governance controls.

This module handles the infrastructure-as-code deployment of Control Tower, replacing manual console setup with repeatable, version-controlled Terraform. It creates the landing zone in the management account, provisions all required service roles, configures centralized logging and AWS Config, and applies OU-level region deny controls.

## Usage

```hcl
module "control_tower" {
  source = "./modules/control-tower"

  # Required accounts
  log_archive_account_id = "123456789012"
  audit_account_account_id = "123456789013"
  config_account_id = "123456789013"

  # Landing zone configuration
  landing_zone_version = "3.3"
  governed_regions = ["eu-central-1", "us-east-1"]

  # Optional: Enable access management (IAM Identity Center)
  enable_access_management = true

  # Optional: Region deny control configuration
  enable_region_deny_control = true
  region_deny_target_ou_arns = {
    "Workloads" = "arn:aws:organizations::123456789012:ou/o-abc123/ou-1234-abcd5678"
  }

  # Optional: Centralized logging
  enable_centralized_logging = true
  logging_bucket_retention_days = 365

  # Optional: AWS Config integration
  enable_config = true
  config_logging_bucket_retention_days = 365

  # Optional: Centralized root access via IAM Identity Center
  enable_centralized_root_access = true
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 6.0.0 |

The AWS provider version constraint of `>= 6.0.0` is required for `aws_controltower_landing_zone` support.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| log_archive_account_id | The AWS account ID of the Log Archive account. | `string` | n/a | yes |
| audit_account_id | The AWS account ID of the Audit (Security) account. | `string` | n/a | yes |
| governed_regions | List of AWS regions to be governed by Control Tower. | `list(string)` | n/a | yes |
| landing_zone_version | The version of the Control Tower landing zone to deploy. | `string` | n/a | yes |
| access_logging_bucket_retention_days | Days to retain access logs for the logging bucket. | `number` | `365` | no |
| backup_admin_account_id | AWS account ID for the backup administrator. Required when `enable_backup = true`. | `string` | `""` | no |
| backup_central_account_id | AWS account ID for the central backup vault. Required when `enable_backup = true`. | `string` | `""` | no |
| backup_kms_key_arn | KMS key ARN for encrypting backups. Required when `enable_backup = true`. | `string` | `""` | no |
| config_access_logging_bucket_retention_days | Days to retain access logs for the Config logging bucket. | `number` | `365` | no |
| config_account_id | AWS account ID for the AWS Config aggregator. Typically the audit/security account. Required when `enable_config = true`. | `string` | `""` | no |
| config_kms_key_arn | Optional KMS key ARN for encrypting AWS Config resources. Leave empty to skip. | `string` | `""` | no |
| config_logging_bucket_retention_days | Days to retain AWS Config logs. | `number` | `365` | no |
| enable_access_management | Whether Control Tower manages IAM Identity Center (directory groups and permission sets). Set to false when Identity Center was created separately or is managed outside of Control Tower. | `bool` | `false` | no |
| enable_backup | Whether Control Tower enables AWS Backup integration. When true, requires `backup_central_account_id`, `backup_admin_account_id`, and `backup_kms_key_arn`. | `bool` | `false` | no |
| enable_centralized_logging | Whether Control Tower enables centralized logging (CloudTrail + S3 logging bucket). This is what controls the CloudTrail organization trail in Control Tower. When true, CT creates an org trail that logs to the centralized logging bucket. | `bool` | `true` | no |
| enable_centralized_root_access | Whether to enable centralized root access management via IAM Identity Center. When enabled, enables RootCredentialsManagement and RootSessions features for the organization. | `bool` | `true` | no |
| enable_config | Whether Control Tower enables AWS Config integration. When true, requires `config_account_id`. Available in landing zone version 4.0+. Note: if disabled, securityRoles, accessManagement, and backup must also be disabled. | `bool` | `true` | no |
| enable_region_deny_control | Whether to deploy the CT.MULTISERVICE.PV.1 OU-level region deny control on the OUs passed in `region_deny_target_ou_arns`. This replaces the landing-zone-level AWS-GR_REGION_DENY. | `bool` | `true` | no |
| kms_key_arn | Optional KMS key ARN for encrypting Control Tower resources. | `string` | `""` | no |
| logging_bucket_retention_days | Days to retain logs in the centralized logging bucket. | `number` | `365` | no |
| region_deny_excluded_ou_names | Names of OUs (keys from `region_deny_target_ou_arns`) to EXCLUDE from the region deny control. Use this to temporarily exempt specific OUs. | `list(string)` | `[]` | no |
| region_deny_extra_exempted_actions | Additional IAM actions to exempt from the region deny, merged with built-in exemptions (bcm-dashboards, bcm-data-exports, bcm-pricing-calculator, pricingplanmanager). Use this for service-specific needs like Bedrock cross-region inference. | `list(string)` | `[]` | no |
| region_deny_exempted_principal_arns | IAM principal ARNs exempted from the region deny control. These principals can operate in any region. AWSControlTowerExecution is always exempted by the control itself. Leave empty unless specific automation roles need unrestricted region access. | `list(string)` | `[]` | no |
| region_deny_target_ou_arns | Map of OU name -> ARN for CT-registered OUs to apply the region deny control to. Only pass OUs that have AWSControlTowerBaseline enabled. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| identity_center_instance_arn | ARN of the IAM Identity Center instance. |
| landing_zone_arn | The ARN of the Control Tower landing zone. |
| landing_zone_drift_status | The drift status of the landing zone. |
| landing_zone_version | The deployed version of the Control Tower landing zone. |
| organization_id | The ID of the AWS Organization. |
| organization_root_id | The root ID of the AWS Organization. |

## Details

### Prerequisite IAM Roles

This module automatically creates the four service roles required by Control Tower before the landing zone can be deployed. These are normally created silently by the Control Tower console wizard but must be explicitly managed when using the API/Terraform:

- **AWSControlTowerAdmin** — Used by Control Tower to provision and manage the landing zone
- **AWSControlTowerCloudTrailRole** — Assumed by CloudTrail to publish audit logs
- **AWSControlTowerStackSetRole** — Assumed by CloudFormation to deploy stack sets
- **AWSControlTowerConfigAggregatorRoleForOrganizations** — Used by AWS Config for organization-level aggregation

### OU-Level Region Deny Control

The module provides an OU-level region deny control (CT.MULTISERVICE.PV.1) that replaces the landing-zone-level AWS-GR_REGION_DENY. This allows:

- Applying the control to specific OUs without affecting the entire landing zone
- Maintaining a custom, updatable exemptions list as AWS services evolve
- Excluding individual OUs temporarily without modifying module configuration

Built-in exemptions cover global and billing services not yet included in the Control Tower template (bcm-*, pricingplanmanager, uxc). Use `region_deny_extra_exempted_actions` for additional exemptions.

### Landing Zone Manifest

The module constructs a Control Tower landing zone manifest from the provided variables, supporting:

- **Centralized Logging** — Optional CloudTrail organization trail with retention
- **AWS Config Integration** — Organization-level Config aggregator with separate buckets
- **AWS Backup** — Central backup vault and administrator account setup
- **Security Roles** — Audit account configuration for security controls
- **Access Management** — IAM Identity Center integration for permission sets and directory groups

### Dependency Orchestration

The module properly sequences resource creation to ensure:

1. Prerequisite IAM roles exist before landing zone creation begins
2. RAM sharing with organizations is enabled before landing zone creation
3. The landing zone is fully deployed before controls are applied
4. IAM trusted access features are enabled only after landing zone deployment

## Notes

- Requires AWS provider >= 6.0.0 for `aws_controltower_landing_zone` support
- Landing zone creation is asynchronous; Terraform polls internally with a 60-minute timeout
- When `enable_config = false`, you must also set `enable_access_management = false`, `enable_backup = false`, and disable `securityRoles` in the manifest
- OUs created via this module are automatically registered with Control Tower and do not require manual enrollment
- The module manages only the landing zone resources; the AWS Organization itself is expected to already exist
