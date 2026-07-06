# AWS Control Tower Module

Terraform module for provisioning and managing AWS Control Tower landing zones. Handles prerequisite IAM roles, landing zone creation, IAM Identity Center integration, organizational unit controls, and centralized root access management.

## Usage

```hcl
module "control_tower" {
  source = "./modules/control-tower"

  log_archive_account_id = "123456789012"
  audit_account_id       = "234567890123"
  governed_regions       = ["eu-central-1", "eu-west-1"]
  landing_zone_version   = "3.3"

  enable_access_management       = true
  enable_centralized_logging     = true
  enable_backup                  = false
  enable_config                  = true
  enable_centralized_root_access = true

  config_account_id = "234567890123"
  kms_key_arn       = "arn:aws:kms:eu-central-1:123456789012:key/12345678-1234-1234-1234-123456789012"

  # Region deny control configuration
  enable_region_deny_control = true
  region_deny_target_ou_arns = {
    Workloads      = "arn:aws:organizations::123456789012:ou/o-abc123/ou-xyz-workloads"
    Infrastructure = "arn:aws:organizations::123456789012:ou/o-abc123/ou-xyz-infra"
  }
  region_deny_extra_exempted_actions = [
    "bedrock:InvokeModel",
    "bedrock:InvokeModelWithResponseStream",
  ]

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

## Requirements

| Requirement | Version |
|-------------|---------|
| terraform | >= 1.0 |
| aws provider | >= 6.0.0 |
| time provider | >= 0.9.0 |

## Providers

| Provider | Version | Purpose |
|----------|---------|---------|
| `aws` | >= 6.0.0 | AWS Control Tower, IAM, Organizations, Config, SSO Admin resources |
| `time` | >= 0.9.0 | IAM propagation delay before landing zone creation |

## Important Notes

- **AWS Provider Requirement**: The `aws_controltower_landing_zone` resource requires AWS Provider version 6.0.0 or later.
- **Landing Zone Creation**: Asynchronous operation; Terraform polls internally. Initial deployment typically takes 70–120 minutes.
- **IAM Propagation**: A built-in 10-second delay prevents race conditions where Control Tower attempts to assume prerequisite roles before IAM propagates them globally.
- **Organization Prerequisite**: An AWS Organization must exist in the management account before this module is applied.
- **Control Tower OUs**: Do not manually add Control Tower-managed OUs (Security, Account Factory for Terraform) to `region_deny_target_ou_arns`; they are auto-discovered.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `log_archive_account_id` | The AWS account ID of the Log Archive account. | `string` | — | yes |
| `audit_account_id` | The AWS account ID of the Audit (Security) account. | `string` | — | yes |
| `governed_regions` | List of AWS regions to be governed by Control Tower. | `list(string)` | — | yes |
| `landing_zone_version` | The version of the Control Tower landing zone to deploy (e.g., "3.3"). | `string` | — | yes |
| `enable_access_management` | Whether Control Tower manages IAM Identity Center (directory groups and permission sets). Set to false when Identity Center was created separately or is managed outside of Control Tower. | `bool` | `false` | no |
| `enable_centralized_logging` | Whether Control Tower enables centralized logging (CloudTrail + S3 logging bucket). When true, CT creates an org trail that logs to the centralized logging bucket. | `bool` | `true` | no |
| `enable_backup` | Whether Control Tower enables AWS Backup integration. When true, requires `backup_central_account_id`, `backup_admin_account_id`, and `backup_kms_key_arn`. | `bool` | `false` | no |
| `enable_config` | Whether Control Tower enables AWS Config integration. When true, requires `config_account_id`. Available in landing zone version 4.0+. Note: if disabled, `securityRoles`, `accessManagement`, and `backup` must also be disabled. | `bool` | `true` | no |
| `enable_centralized_root_access` | Whether to enable centralized root access management via IAM Identity Center. When enabled, enables `RootCredentialsManagement` and `RootSessions` features for the organization. | `bool` | `true` | no |
| `enable_region_deny_control` | Whether to deploy the CT.MULTISERVICE.PV.1 OU-level region deny control on the OUs passed in `region_deny_target_ou_arns`. This replaces the landing-zone-level AWS-GR_REGION_DENY. | `bool` | `true` | no |
| `logging_bucket_retention_days` | Days to retain logs in the centralized logging bucket. | `number` | `365` | no |
| `access_logging_bucket_retention_days` | Days to retain access logs for the logging bucket. | `number` | `365` | no |
| `kms_key_arn` | Optional KMS key ARN for encrypting Control Tower resources (centralized logging). Leave empty to use S3-managed encryption. | `string` | `""` | no |
| `config_account_id` | AWS account ID for the AWS Config aggregator. Typically the audit/security account. Required when `enable_config = true`. | `string` | `""` | no |
| `config_logging_bucket_retention_days` | Days to retain AWS Config logs. | `number` | `365` | no |
| `config_access_logging_bucket_retention_days` | Days to retain access logs for the Config logging bucket. | `number` | `365` | no |
| `config_kms_key_arn` | Optional KMS key ARN for encrypting AWS Config resources. Leave empty to use S3-managed encryption. | `string` | `""` | no |
| `backup_central_account_id` | AWS account ID for the central backup vault. Required when `enable_backup = true`. | `string` | `""` | no |
| `backup_admin_account_id` | AWS account ID for the backup administrator. Required when `enable_backup = true`. | `string` | `""` | no |
| `backup_kms_key_arn` | KMS key ARN for encrypting backups. Required when `enable_backup = true`. | `string` | `""` | no |
| `region_deny_target_ou_arns` | Map of OU name → ARN for CT-registered OUs to apply the region deny control to. Only pass OUs that have `AWSControlTowerBaseline` enabled. | `map(string)` | `{}` | no |
| `region_deny_excluded_ou_names` | Names of OUs (keys from `region_deny_target_ou_arns`) to EXCLUDE from the region deny control. Use this to temporarily exempt specific OUs. | `list(string)` | `[]` | no |
| `region_deny_extra_exempted_actions` | Additional IAM actions to exempt from the region deny, merged with built-in exemptions (bcm-dashboards, bcm-data-exports, bcm-pricing-calculator, pricingplanmanager, uxc). Use this for service-specific needs like Bedrock cross-region inference. | `list(string)` | `[]` | no |
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

## Resource Overview

### IAM Roles

This module creates four Control Tower prerequisite IAM service roles required before landing zone creation:

- **AWSControlTowerAdmin** (`/service-role/`) — Allows Control Tower to provision and manage the landing zone. Attached policy: `AWSControlTowerServiceRolePolicy`. Inline policy grants `ec2:DescribeAvailabilityZones`.

- **AWSControlTowerCloudTrailRole** (`/service-role/`) — Allows CloudTrail to write audit logs to CloudWatch Logs. Attached policy: `AWSControlTowerCloudTrailRolePolicy`.

- **AWSControlTowerStackSetRole** (`/service-role/`) — Allows CloudFormation to assume `AWSControlTowerExecution` roles in managed accounts for stack set operations.

- **AWSControlTowerConfigAggregatorRoleForOrganizations** (`/service-role/`) — Allows AWS Config to create organization-level aggregators. Attached policy: `AWSConfigRoleForOrganizations`. Required for landing zone version < 4.0; in 4.0+, CT migrates to a service-linked role but this must exist at creation time.

### Landing Zone

The `aws_controltower_landing_zone` resource is configured with:

- Manifest JSON built conditionally from module inputs (logging, backup, config, security roles, access management).
- Version pinning via `landing_zone_version`.
- Automatic remediation of inheritance drift via `INHERITANCE_DRIFT` remediation type.
- 10-second IAM propagation delay before creation.

### Region Deny Control

The `aws_controltower_control` resource for CT.MULTISERVICE.PV.1 (OU-level region deny):

- Automatically discovers and targets Control Tower-managed OUs (Security, Account Factory for Terraform).
- Supports caller-provided OU targets via `region_deny_target_ou_arns`.
- Applies `AllowedRegions` parameter from `governed_regions`.
- Includes built-in exemptions for global/billing services and caller-provided extra exemptions via `region_deny_extra_exempted_actions`.
- Optionally exempts specified principals via `region_deny_exempted_principal_arns` (dynamic parameter).
- 60-minute timeout per control operation (create, update, delete).

### Identity Center Integration

When `enable_access_management = true`:

- Queries for the IAM Identity Center instance ARN.
- Creates a `Control-Tower-Administrator` permission set with `AdministratorAccess` policy.
- 4-hour session duration.

### Centralized Root Access

When `enable_centralized_root_access = true`:

- Enables `RootCredentialsManagement` and `RootSessions` features via `aws_iam_organizations_features`.
- Depends on landing zone creation for service integrations to be ready.

### AWS RAM Integration

- Enables AWS Resource Access Manager sharing with the organization via `aws_ram_sharing_with_organization`.
- Required dependency for landing zone creation to succeed.

## Control Tower Manifest Sections

The landing zone manifest is built dynamically from module inputs:

| Section | Control Variable | Default | Notes |
|---------|------------------|---------|-------|
| `governedRegions` | `governed_regions` | — | Required; list of regions managed by CT |
| `accessManagement` | `enable_access_management` | `false` | Enables Identity Center management by CT |
| `securityRoles` | `enable_config` | `true` | Enables security aggregation to audit account |
| `centralizedLogging` | `enable_centralized_logging` | `true` | Enables org CloudTrail and S3 logging |
| `backup` | `enable_backup` | `false` | Enables AWS Backup integration |
| `config` | `enable_config` | `true` | Enables AWS Config aggregation |

## Examples

### Minimal Landing Zone

```hcl
module "control_tower" {
  source = "./modules/control-tower"

  log_archive_account_id = "123456789012"
  audit_account_id       = "234567890123"
  governed_regions       = ["eu-central-1"]
  landing_zone_version   = "3.3"

  enable_access_management   = false
  enable_backup              = false
}
```

### Full-Featured Landing Zone with Region Deny

```hcl
module "control_tower" {
  source = "./modules/control-tower"

  log_archive_account_id = "123456789012"
  audit_account_id       = "234567890123"
  governed_regions       = ["eu-central-1", "eu-west-1", "us-east-1"]
  landing_zone_version   = "3.3"

  # Logging and compliance
  enable_centralized_logging       = true
  logging_bucket_retention_days    = 2555  # 7 years
  access_logging_bucket_retention_days = 90
  kms_key_arn                      = aws_kms_key.ct.arn

  # Config and security
  enable_config                 = true
  config_account_id             = "234567890123"
  config_logging_bucket_retention_days = 1095  # 3 years

  # Access management
  enable_access_management       = true
  enable_centralized_root_access = true

  # Region deny control
  enable_region_deny_control = true
  region_deny_target_ou_arns = {
    Workloads      = aws_organizations_organizational_unit.workloads.arn
    Infrastructure = aws_organizations_organizational_unit.infrastructure.arn
  }
  region_deny_extra_exempted_actions = [
    "bedrock:InvokeModel",
    "bedrock:InvokeModelWithResponseStream",
    "kendra:BatchGetDocumentStatus",
  ]
}
```

## Deployment Timing

When deploying a new landing zone (`control_tower_mode = "terraform"` in the root module):

- **Control Tower Landing Zone**: 30–60 minutes
- **Organizational Units**: 20–30 minutes
- **Region Deny Controls**: ~15 minutes per OU (applied in parallel)
- **Total First Deploy**: 70–120 minutes

## References

- [AWS Control Tower Documentation](https://docs.aws.amazon.com/controltower/)
- [Control Tower Landing Zone API Prerequisites](https://docs.aws.amazon.com/controltower/latest/userguide/lz-api-prereques.html)
- [Control Tower IAM Roles](https://docs.aws.amazon.com/controltower/latest/userguide/roles-how.html)
- [Control Tower Controls Library](https://docs.aws.amazon.com/controltower/latest/userguide/controls.html)

## License

This module is provided as part of the AWS Landing Zone project.
