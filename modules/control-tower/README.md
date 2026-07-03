# AWS Control Tower Landing Zone Module

This Terraform module provisions an AWS Control Tower landing zone with optional integrations for centralized logging, AWS Backup, AWS Config, and IAM Identity Center access management.

The module handles the creation of the landing zone manifest, enables organizational features for root access management, and deploys an OU-level region deny control that automatically discovers and targets Control Tower-managed organizational units.

## Usage

```hcl
module "control_tower" {
  source = "./modules/control-tower"

  # Required: Account IDs
  log_archive_account_id = "123456789012"
  audit_account_account_id = "123456789013"

  # Required: Governance configuration
  governed_regions      = ["eu-central-1", "eu-west-1"]
  landing_zone_version  = "3.3"

  # Optional: Centralized logging
  enable_centralized_logging           = true
  logging_bucket_retention_days        = 365
  access_logging_bucket_retention_days = 365
  kms_key_arn                          = "arn:aws:kms:eu-central-1:123456789012:key/12345678-1234-1234-1234-123456789012"

  # Optional: AWS Backup integration
  enable_backup            = true
  backup_central_account_id = "123456789014"
  backup_admin_account_id   = "123456789015"
  backup_kms_key_arn       = "arn:aws:kms:eu-central-1:123456789012:key/87654321-4321-4321-4321-210987654321"

  # Optional: AWS Config integration
  enable_config                           = true
  config_account_id                       = "123456789013"
  config_logging_bucket_retention_days    = 365
  config_access_logging_bucket_retention_days = 365
  config_kms_key_arn                      = ""

  # Optional: Access management via IAM Identity Center
  enable_access_management = true

  # Optional: Centralized root access management
  enable_centralized_root_access = true

  # Optional: Region deny control
  enable_region_deny_control = true
  region_deny_target_ou_arns = {
    "Workloads" = "arn:aws:organizations::123456789012:ou/o-xxxxx/ou-xxxx-yyyyyyyy"
  }
  region_deny_excluded_ou_names = []
  region_deny_extra_exempted_actions = [
    "bedrock:InvokeModel",
    "bedrock:InvokeModelWithResponseStream"
  ]
  region_deny_exempted_principal_arns = []
}
```

## Requirements

| Requirement | Version |
|---|---|
| Terraform | >= 1.5.0 |
| AWS Provider | >= 6.0.0 |

## Providers

| Name | Version | Purpose |
|---|---|---|
| aws | >= 6.0.0 | AWS resources (Control Tower, Organizations, SSO, Config, Backup) |

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `log_archive_account_id` | The AWS account ID of the Log Archive account. | `string` | N/A | Yes |
| `audit_account_id` | The AWS account ID of the Audit (Security) account. | `string` | N/A | Yes |
| `governed_regions` | List of AWS regions to be governed by Control Tower. | `list(string)` | N/A | Yes |
| `landing_zone_version` | The version of the Control Tower landing zone to deploy. | `string` | N/A | Yes |
| `enable_access_management` | Whether Control Tower manages IAM Identity Center (directory groups and permission sets). Set to false when Identity Center was created separately or is managed outside of Control Tower. | `bool` | `false` | No |
| `enable_centralized_logging` | Whether Control Tower enables centralized logging (CloudTrail + S3 logging bucket). This controls the CloudTrail organization trail in Control Tower. When true, CT creates an org trail that logs to the centralized logging bucket. | `bool` | `true` | No |
| `logging_bucket_retention_days` | Days to retain logs in the centralized logging bucket. | `number` | `365` | No |
| `access_logging_bucket_retention_days` | Days to retain access logs for the logging bucket. | `number` | `365` | No |
| `kms_key_arn` | Optional KMS key ARN for encrypting Control Tower resources. | `string` | `""` | No |
| `enable_backup` | Whether Control Tower enables AWS Backup integration. When true, requires `backup_central_account_id`, `backup_admin_account_id`, and `backup_kms_key_arn`. | `bool` | `false` | No |
| `backup_central_account_id` | AWS account ID for the central backup vault. Required when `enable_backup = true`. | `string` | `""` | No |
| `backup_admin_account_id` | AWS account ID for the backup administrator. Required when `enable_backup = true`. | `string` | `""` | No |
| `backup_kms_key_arn` | KMS key ARN for encrypting backups. Required when `enable_backup = true`. | `string` | `""` | No |
| `enable_config` | Whether Control Tower enables AWS Config integration. When true, requires `config_account_id`. Available in landing zone version 4.0+. Note: if disabled, `securityRoles`, `accessManagement`, and `backup` must also be disabled. | `bool` | `true` | No |
| `config_account_id` | AWS account ID for the AWS Config aggregator. Typically the audit/security account. Required when `enable_config = true`. | `string` | `""` | No |
| `config_logging_bucket_retention_days` | Days to retain AWS Config logs. | `number` | `365` | No |
| `config_access_logging_bucket_retention_days` | Days to retain access logs for the Config logging bucket. | `number` | `365` | No |
| `config_kms_key_arn` | Optional KMS key ARN for encrypting AWS Config resources. Leave empty to skip. | `string` | `""` | No |
| `enable_region_deny_control` | Whether to deploy the CT.MULTISERVICE.PV.1 OU-level region deny control on the OUs passed in `region_deny_target_ou_arns`. This replaces the landing-zone-level AWS-GR_REGION_DENY. | `bool` | `true` | No |
| `region_deny_target_ou_arns` | Map of OU name → ARN for CT-registered OUs to apply the region deny control to. Only pass OUs that have AWSControlTowerBaseline enabled. | `map(string)` | `{}` | No |
| `region_deny_excluded_ou_names` | Names of OUs (keys from `region_deny_target_ou_arns`) to EXCLUDE from the region deny control. Use this to temporarily exempt specific OUs. | `list(string)` | `[]` | No |
| `region_deny_extra_exempted_actions` | Additional IAM actions to exempt from the region deny, merged with built-in exemptions (bcm-dashboards, bcm-data-exports, bcm-pricing-calculator, pricingplanmanager). Use this for service-specific needs like Bedrock cross-region inference. | `list(string)` | `[]` | No |
| `region_deny_exempted_principal_arns` | IAM principal ARNs exempted from the region deny control. These principals can operate in any region. AWSControlTowerExecution is always exempted by the control itself. Leave empty unless specific automation roles need unrestricted region access. | `list(string)` | `[]` | No |
| `enable_centralized_root_access` | Whether to enable centralized root access management via IAM Identity Center. When enabled, enables RootCredentialsManagement and RootSessions features for the organization. | `bool` | `true` | No |

## Outputs

| Name | Description |
|---|---|
| `landing_zone_arn` | The ARN of the Control Tower landing zone. |
| `landing_zone_version` | The deployed version of the Control Tower landing zone. |
| `landing_zone_drift_status` | The drift status of the landing zone. |
| `identity_center_instance_arn` | ARN of the IAM Identity Center instance. |
| `organization_root_id` | The root ID of the AWS Organization. |
| `organization_id` | The ID of the AWS Organization. |

## Key Features

### Control Tower Landing Zone

Creates a fully configured Control Tower landing zone with:
- **Governed regions** enforcement
- **Security roles** (AWS Config) optional integration
- **Centralized logging** with CloudTrail and S3 bucket retention policies
- **AWS Backup** optional integration with dedicated central and admin accounts
- **AWS Config** optional integration for compliance monitoring
- **Access Management** via IAM Identity Center (optional)

### OU-Level Region Deny Control (CT.MULTISERVICE.PV.1)

Replaces the landing-zone-level `AWS-GR_REGION_DENY` with an OU-level control that:
- **Automatically discovers** Control Tower-owned OUs (Security, Account Factory for Terraform)
- **Targets caller-provided OUs** via `region_deny_target_ou_arns`
- **Includes built-in exemptions** for global and billing services:
  - `bcm-dashboards:*`
  - `bcm-data-exports:*`
  - `bcm-pricing-calculator:*`
  - `pricingplanmanager:*`
- **Supports additional exemptions** for service-specific cross-region operations (e.g., Bedrock inference)
- **Allows temporary OU exclusion** via `region_deny_excluded_ou_names`
- **Optional principal exemptions** for automation roles needing unrestricted region access
- **60-minute deployment timeout** per OU for reliable operation

### Centralized Root Access Management

Enables organization-wide features when `enable_centralized_root_access = true`:
- `RootCredentialsManagement` — Centralized management of root account credentials
- `RootSessions` — Monitored root account session tracking and management

### IAM Identity Center Integration

When `enable_access_management = true`:
- Creates a **Control-Tower-Administrator** permission set
- Attaches **AdministratorAccess** policy
- Sets session duration to **4 hours**
- Discovers and uses the existing IAM Identity Center instance

### Resource Access Manager (RAM)

Automatically enables AWS Organizations sharing to support:
- Cross-account resource sharing
- Organizational-level resource sharing policies

## Notes

- **AWS Provider Requirement**: `aws_controltower_landing_zone` requires AWS Provider version >= 6.0.0
- **Landing Zone Creation**: Asynchronous operation; Terraform polls internally for completion
- **Auto-Enrollment**: Set to `INHERITANCE_DRIFT` remediation to auto-enroll child accounts in applicable controls
- **Control Tower Dependencies**: The region deny control depends on the landing zone being deployed first
- **Config Dependencies**: When `enable_config = false`, you must also disable `enable_access_management` and `enable_backup`
- **Landing Zone Version**: Available versions include 3.0, 3.1, 3.2, 3.3, 4.0, and later. Check AWS documentation for feature availability per version

## Examples

### Minimal Configuration

```hcl
module "control_tower" {
  source = "./modules/control-tower"

  log_archive_account_id = "123456789012"
  audit_account_id       = "123456789013"
  governed_regions       = ["us-east-1"]
  landing_zone_version   = "3.3"
}
```

### Full Configuration with All Features

```hcl
module "control_tower" {
  source = "./modules/control-tower"

  log_archive_account_id = "123456789012"
  audit_account_id       = "123456789013"
  governed_regions       = ["eu-central-1", "eu-west-1", "us-east-1"]
  landing_zone_version   = "4.0"

  enable_access_management         = true
  enable_centralized_logging       = true
  logging_bucket_retention_days    = 2555  # 7 years
  kms_key_arn                      = aws_kms_key.control_tower.arn

  enable_backup              = true
  backup_central_account_id  = "123456789014"
  backup_admin_account_id    = "123456789015"
  backup_kms_key_arn        = aws_kms_key.backup.arn

  enable_config              = true
  config_account_id          = "123456789013"
  config_kms_key_arn        = aws_kms_key.config.arn

  enable_centralized_root_access = true

  enable_region_deny_control = true
  region_deny_target_ou_arns = {
    "Workloads"      = aws_organizations_organizational_unit.workloads.arn
    "Infrastructure" = aws_organizations_organizational_unit.infrastructure.arn
  }
  region_deny_extra_exempted_actions = [
    "bedrock:InvokeModel",
    "bedrock:InvokeModelWithResponseStream",
  ]
}
```

### Conditional Identity Center (Pre-Existing)

```hcl
module "control_tower" {
  source = "./modules/control-tower"

  log_archive_account_id = "123456789012"
  audit_account_id       = "123456789013"
  governed_regions       = ["eu-central-1"]
  landing_zone_version   = "3.3"

  # Identity Center was created separately
  enable_access_management = false
}
```
