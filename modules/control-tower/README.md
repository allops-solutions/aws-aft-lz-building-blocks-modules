# AWS Control Tower Landing Zone Module

This Terraform module creates and manages an AWS Control Tower landing zone with comprehensive support for organizational units, IAM roles, security controls, and optional features like centralized logging, AWS Backup integration, and AWS Config aggregation.

The module handles all prerequisite IAM roles required by Control Tower, manages the landing zone manifest with conditional feature support, and deploys OU-level region deny controls to enforce governance across your organization.

## Usage

```hcl
module "control_tower" {
  # Pin to a specific version
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/control-tower?ref=control-tower-v1.0"

  # Required inputs
  log_archive_account_id = var.log_archive_account_id
  audit_account_id       = var.audit_account_id
  governed_regions       = ["eu-central-1", "eu-west-1"]
  landing_zone_version   = "4.0"

  # Optional: Configure region deny control
  enable_region_deny_control = true
  region_deny_target_ou_arns = {
    "Workloads" = "arn:aws:organizations::123456789012:ou/o-xxxxx/ou-xxxx-workloads"
  }
  region_deny_extra_exempted_actions = [
    "bedrock:InvokeModel",
    "bedrock:InvokeModelWithResponseStream",
  ]

  # Optional: Enable centralized root access management
  enable_centralized_root_access = true

  # Optional: Configure centralized logging
  enable_centralized_logging             = true
  logging_bucket_retention_days          = 365
  access_logging_bucket_retention_days   = 365
  kms_key_arn                            = "arn:aws:kms:eu-central-1:123456789012:key/12345678-1234-1234-1234-123456789012"

  # Optional: Enable Identity Center management
  enable_access_management = true

  # Optional: Enable AWS Backup integration
  enable_backup              = false
  backup_central_account_id  = ""
  backup_admin_account_id    = ""
  backup_kms_key_arn         = ""

  # Optional: Enable AWS Config integration
  enable_config                                  = true
  config_account_id                              = var.audit_account_id
  config_logging_bucket_retention_days           = 365
  config_access_logging_bucket_retention_days    = 365
  config_kms_key_arn                             = ""

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
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
|------|-------------|------|---------|----------|
| log_archive_account_id | The AWS account ID of the Log Archive account. | `string` | | yes |
| audit_account_id | The AWS account ID of the Audit (Security) account. | `string` | | yes |
| governed_regions | List of AWS regions to be governed by Control Tower. | `list(string)` | | yes |
| landing_zone_version | The version of the Control Tower landing zone to deploy. | `string` | | yes |
| enable_access_management | Whether Control Tower manages IAM Identity Center (directory groups and permission sets). Set to false when Identity Center was created separately or is managed outside of Control Tower. | `bool` | `false` | no |
| enable_backup | Whether Control Tower enables AWS Backup integration. When true, requires backup_central_account_id, backup_admin_account_id, and backup_kms_key_arn. | `bool` | `false` | no |
| enable_centralized_logging | Whether Control Tower enables centralized logging (CloudTrail + S3 logging bucket). This is what controls the CloudTrail organization trail in Control Tower. When true, CT creates an org trail that logs to the centralized logging bucket. | `bool` | `true` | no |
| enable_centralized_root_access | Whether to enable centralized root access management via IAM Identity Center. When enabled, enables RootCredentialsManagement and RootSessions features for the organization. | `bool` | `true` | no |
| enable_config | Whether Control Tower enables AWS Config integration. When true, requires config_account_id. Available in landing zone version 4.0+. Note: if disabled, securityRoles, accessManagement, and backup must also be disabled. | `bool` | `true` | no |
| enable_region_deny_control | Whether to deploy the CT.MULTISERVICE.PV.1 OU-level region deny control on the OUs passed in region_deny_target_ou_arns. This replaces the landing-zone-level AWS-GR_REGION_DENY. | `bool` | `true` | no |
| access_logging_bucket_retention_days | Days to retain access logs for the logging bucket. | `number` | `365` | no |
| backup_admin_account_id | AWS account ID for the backup administrator. Required when enable_backup = true. | `string` | `""` | no |
| backup_central_account_id | AWS account ID for the central backup vault. Required when enable_backup = true. | `string` | `""` | no |
| backup_kms_key_arn | KMS key ARN for encrypting backups. Required when enable_backup = true. | `string` | `""` | no |
| config_account_id | AWS account ID for the AWS Config aggregator. Typically the audit/security account. Required when enable_config = true. | `string` | `""` | no |
| config_access_logging_bucket_retention_days | Days to retain access logs for the Config logging bucket. | `number` | `365` | no |
| config_kms_key_arn | Optional KMS key ARN for encrypting AWS Config resources. Leave empty to skip. | `string` | `""` | no |
| config_logging_bucket_retention_days | Days to retain AWS Config logs. | `number` | `365` | no |
| kms_key_arn | Optional KMS key ARN for encrypting Control Tower resources. | `string` | `""` | no |
| logging_bucket_retention_days | Days to retain logs in the centralized logging bucket. | `number` | `365` | no |
| region_deny_excluded_ou_names | Names of OUs (keys from region_deny_target_ou_arns) to EXCLUDE from the region deny control. Use this to temporarily exempt specific OUs. | `list(string)` | `[]` | no |
| region_deny_extra_exempted_actions | Additional IAM actions to exempt from the region deny, merged with built-in exemptions (bcm-dashboards, bcm-data-exports, bcm-pricing-calculator, pricingplanmanager). Use this for service-specific needs like Bedrock cross-region inference. | `list(string)` | `[]` | no |
| region_deny_exempted_principal_arns | IAM principal ARNs exempted from the region deny control. These principals can operate in any region. AWSControlTowerExecution is always exempted by the control itself. Leave empty unless specific automation roles need unrestricted region access. | `list(string)` | `[]` | no |
| region_deny_target_ou_arns | Map of OU name -> ARN for CT-registered OUs to apply the region deny control to. Only pass OUs that have AWSControlTowerBaseline enabled. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| landing_zone_arn | The ARN of the Control Tower landing zone. |
| landing_zone_version | The deployed version of the Control Tower landing zone. |
| landing_zone_drift_status | The drift status of the landing zone. |
| identity_center_instance_arn | ARN of the IAM Identity Center instance. |
| organization_root_id | The root ID of the AWS Organization. |
| organization_id | The ID of the AWS Organization. |

## Features

### Control Tower Landing Zone

The module creates a Control Tower landing zone with a dynamically-generated manifest that supports:
- Configurable governed regions
- Centralized logging with CloudTrail organization trail
- AWS Backup integration (optional)
- AWS Config aggregation (optional)
- IAM Identity Center management (optional)

### Prerequisite IAM Roles

Control Tower requires four service roles to exist in the management account before the landing zone is created. The module creates:

- **AWSControlTowerAdmin**: Used by Control Tower to set up and manage the landing zone
- **AWSControlTowerCloudTrailRole**: Assumed by CloudTrail to publish audit logs
- **AWSControlTowerStackSetRole**: Assumed by CloudFormation to deploy stack sets into member accounts
- **AWSControlTowerConfigAggregatorRoleForOrganizations**: Used by AWS Config for organization-level aggregation

The module includes a 10-second propagation delay to ensure IAM changes are globally available before Control Tower attempts to create the landing zone.

### OU-Level Region Deny Control

The module deploys the CT.MULTISERVICE.PV.1 region deny control to enforce region governance at the OU level. This replaces the landing-zone-level AWS-GR_REGION_DENY control and includes:

- Automatic discovery of Control Tower-owned OUs (Security, Account Factory for Terraform)
- Support for caller-provided OU targets
- Built-in exemptions for global/billing services
- Configurable extra exemptions for service-specific needs
- Principal ARN exemptions for automation roles
- OU-level exclusion for temporary exemptions

**Built-in exempted services:**
- bcm-dashboards:*
- bcm-data-exports:*
- bcm-pricing-calculator:*
- pricingplanmanager:*
- uxc:*

### Centralized Root Access Management

When enabled, the module configures IAM Organizations features to enable centralized root access management via IAM Identity Center:

- RootCredentialsManagement
- RootSessions

This requires that Control Tower has already been deployed and enabled the required service integrations.

### RAM Organization Sharing

The module enables Resource Access Manager (RAM) sharing with AWS Organizations to support resource sharing across the organization.

## Configuration Examples

### Basic Setup with Region Deny

```hcl
module "control_tower" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/control-tower?ref=control-tower-v1.0"

  log_archive_account_id = "111111111111"
  audit_account_id       = "222222222222"
  governed_regions       = ["eu-central-1"]
  landing_zone_version   = "4.0"

  enable_region_deny_control = true
  region_deny_target_ou_arns = {
    "Workloads" = "arn:aws:organizations::123456789012:ou/o-xxxxx/ou-xxxx-workloads"
  }
}
```

### With AWS Backup and Config

```hcl
module "control_tower" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/control-tower?ref=control-tower-v1.0"

  log_archive_account_id = "111111111111"
  audit_account_id       = "222222222222"
  governed_regions       = ["eu-central-1", "eu-west-1"]
  landing_zone_version   = "4.0"

  enable_centralized_logging = true
  logging_bucket_retention_days = 2555  # 7 years

  enable_backup              = true
  backup_central_account_id  = "333333333333"
  backup_admin_account_id    = "444444444444"
  backup_kms_key_arn         = "arn:aws:kms:eu-central-1:123456789012:key/12345678-1234-1234-1234-123456789012"

  enable_config       = true
  config_account_id   = "222222222222"
  config_kms_key_arn  = "arn:aws:kms:eu-central-1:123456789012:key/87654321-4321-4321-4321-210987654321"

  enable_access_management = true
}
```

### With Custom Region Deny Exemptions

```hcl
module "control_tower" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/control-tower?ref=control-tower-v1.0"

  log_archive_account_id = "111111111111"
  audit_account_id       = "222222222222"
  governed_regions       = ["eu-central-1"]
  landing_zone_version   = "4.0"

  enable_region_deny_control = true
  region_deny_target_ou_arns = {
    "Workloads"      = "arn:aws:organizations::123456789012:ou/o-xxxxx/ou-xxxx-workloads"
    "Infrastructure" = "arn:aws:organizations::123456789012:ou/o-xxxxx/ou-xxxx-infrastructure"
  }

  # Exempt Bedrock cross-region operations for AI workloads
  region_deny_extra_exempted_actions = [
    "bedrock:InvokeModel",
    "bedrock:InvokeModelWithResponseStream",
  ]

  # Temporarily exclude the Infrastructure OU from region deny
  region_deny_excluded_ou_names = ["Infrastructure"]

  # Allow automation roles to operate in any region
  region_deny_exempted_principal_arns = [
    "arn:aws:iam::123456789012:role/CrossRegionAutomation"
  ]
}
```

## Notes

- The module requires AWS Provider >= 6.0.0 to support the `aws_controltower_landing_zone` and `aws_controltower_control` resources
- Landing zone creation is asynchronous; Terraform polls internally until the operation completes (default timeout: 2 hours)
- IAM role propagation can take several seconds; the module includes a built-in 10-second delay to prevent race conditions
- The region deny control requires that OUs are registered with Control Tower (have `AWSControlTowerBaseline` enabled)
- Control Tower-owned OUs (Security, Account Factory for Terraform) are automatically discovered and included in region deny targets
- When `enable_config = false`, other features like `securityRoles`, `accessManagement`, and `backup` must also be disabled in landing zone versions < 4.0

## References

- [AWS Control Tower API Prerequisites](https://docs.aws.amazon.com/controltower/latest/userguide/lz-api-prereques.html)
- [AWS Control Tower Roles](https://docs.aws.amazon.com/controltower/latest/userguide/roles-how.html)
- [AWS Control Tower Access Control](https://docs.aws.amazon.com/controltower/latest/userguide/access-control-managing-permissions.html)
- [AWS Control Tower Account Auto-Enrollment](https://docs.aws.amazon.com/controltower/latest/userguide/account-auto-enrollment.html)
