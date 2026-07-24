# Amazon GuardDuty Organization Configuration Module

This Terraform module configures Amazon GuardDuty at the organization level for AWS Control Tower landing zones. It registers a delegated administrator account, enables protection plan features, and automatically enrolls AFT-managed accounts as GuardDuty members.

## Features

- **Delegated Administrator Registration**: Designates a security/audit account as the organization's GuardDuty delegated administrator
- **Automatic Account Discovery**: Discovers and enrolls all accounts in Control Tower-managed OUs, with exclusion capabilities
- **Comprehensive Protection Plans**: Enable/disable GuardDuty protection features:
  - S3 Data Events detection
  - EKS Audit Log monitoring
  - EBS Malware Protection
  - RDS Login Events monitoring
  - Lambda Network activity monitoring
  - Runtime Monitoring with granular sub-feature control
  - AI Protection for advanced ML workloads
- **Fine-Grained Configuration**: Control Runtime Monitoring sub-features (EKS, ECS Fargate, EC2) independently
- **Account Exclusion**: Exclude specific accounts from GuardDuty enrollment
- **Explicit Enrollment Control**: Disables auto-enrollment to provide full control over which accounts receive protection
- **Malware Protection Service Access**: Enables the delegated administrator to create Malware Protection service-linked roles in member accounts

## Usage

```hcl
module "guardduty" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/security/guardduty?ref=security-guardduty-v1.0"

  delegated_admin_account_id = var.audit_account_id
  
  # Enable protection features
  s3_protection_enabled              = true
  eks_audit_logs_enabled             = true
  ebs_malware_protection_enabled     = true
  rds_protection_enabled             = true
  lambda_protection_enabled          = true
  runtime_monitoring_enabled         = true
  ai_protection_enabled              = true
  
  # Fine-tune Runtime Monitoring sub-features
  runtime_monitoring_configuration = {
    EKS_ADDON_MANAGEMENT         = "ALL"
    ECS_FARGATE_AGENT_MANAGEMENT = "ALL"
    EC2_AGENT_MANAGEMENT         = "ALL"
  }
  
  # Exclude specific accounts if needed
  excluded_account_ids = []
  
  tags = local.common_tags

  providers = {
    aws.org-management = aws.org-management
  }
}
```

### Pinning to a Specific Version

To pin to a specific version, use the ref parameter:

```hcl
source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/security/guardduty?ref=security-guardduty-v1.0"
```

Replace `v1.0` with the desired version tag.

## Requirements

### Terraform Version

```
>= 1.6.0
```

### Providers

| Name | Version | Configuration |
|------|---------|---|
| aws | >= 6.23.0 | Requires `aws.org-management` alias for organization APIs |
| time | >= 0.9.0 | - |

### Provider Configuration

This module requires two AWS provider configurations:

```hcl
# Default provider for delegated admin account resources
provider "aws" {
  region = var.region
}

# Organization management account provider
provider "aws" {
  alias  = "org-management"
  region = var.region
  
  assume_role {
    role_arn = "arn:aws:iam::${var.org_management_account_id}:role/YourAssumeRole"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|---|---|---|---|
| `delegated_admin_account_id` | Account ID to register as the Amazon GuardDuty delegated administrator for the organization. | `string` | - | Yes |
| `s3_protection_enabled` | Enable GuardDuty S3 Protection across enrolled accounts. Detects data exfiltration and destruction attempts in S3 buckets. | `bool` | `false` | No |
| `eks_audit_logs_enabled` | Enable GuardDuty EKS Audit Log Monitoring across enrolled accounts. Analyzes Kubernetes audit logs for suspicious control plane activity. | `bool` | `false` | No |
| `ebs_malware_protection_enabled` | Enable GuardDuty Malware Protection for EC2 across enrolled accounts. Scans EBS volumes for malware when threats are detected. | `bool` | `false` | No |
| `rds_protection_enabled` | Enable GuardDuty RDS Protection across enrolled accounts. Detects anomalous login activity on Aurora and RDS databases. | `bool` | `false` | No |
| `lambda_protection_enabled` | Enable GuardDuty Lambda Protection across enrolled accounts. Monitors Lambda network activity for threats like cryptomining. | `bool` | `false` | No |
| `runtime_monitoring_enabled` | Enable GuardDuty Runtime Monitoring across enrolled accounts. Monitors OS-level events on EKS, EC2, and ECS/Fargate workloads. | `bool` | `false` | No |
| `ai_protection_enabled` | Enable GuardDuty AI Protection across enrolled accounts. Detects threats to AI workloads built on Amazon Bedrock, AgentCore, and SageMaker AI. | `bool` | `false` | No |
| `runtime_monitoring_configuration` | Sub-feature configuration for Runtime Monitoring. Controls automated agent management for EKS, ECS Fargate, and EC2 workloads. Only effective when `runtime_monitoring_enabled` is true. Valid keys: `EKS_ADDON_MANAGEMENT`, `ECS_FARGATE_AGENT_MANAGEMENT`, `EC2_AGENT_MANAGEMENT`. Valid values: `ALL`, `NEW`, `NONE`. Defaults to `ALL` for all sub-features when enabled. | `map(string)` | `{ EKS_ADDON_MANAGEMENT = "ALL", ECS_FARGATE_AGENT_MANAGEMENT = "ALL", EC2_AGENT_MANAGEMENT = "ALL" }` | No |
| `excluded_account_ids` | Account IDs to exclude from GuardDuty enrollment. These accounts will not have GuardDuty enabled even if they are discovered in the AFT metadata table. | `list(string)` | `[]` | No |
| `tags` | Tags to apply to all resources. Passed in from the root module. | `map(string)` | - | Yes |

## Outputs

| Name | Description |
|------|---|
| `delegated_admin_account_id` | Account ID registered as the Amazon GuardDuty delegated administrator. |
| `detector_id` | GuardDuty detector ID in the delegated administrator account. |
| `enrolled_account_ids` | Account IDs enrolled as GuardDuty members. |
| `protection_plans` | Protection plan configuration applied to the organization. |

## How It Works

### Account Discovery

The module automatically discovers accounts in your organization:

1. Queries all top-level Organizational Units (OUs) beneath the organization root
2. Identifies OUs managed by Control Tower (those with at least one enabled Control Tower control)
3. Retrieves all descendant accounts from CT-managed OUs
4. Includes the organization management account
5. Excludes any accounts specified in `excluded_account_ids` and the delegated administrator account

### Protection Features

Each protection feature can be independently enabled or disabled. When enabled, the feature is applied to all enrolled member accounts. Runtime Monitoring includes sub-feature controls to enable/disable agent management for specific compute platforms (EKS, ECS Fargate, EC2).

### Enrollment Flow

1. Creates a GuardDuty detector in the delegated administrator account
2. Registers the delegated administrator with the organization
3. Creates a GuardDuty detector in the management account
4. Enables Malware Protection service access for the delegated administrator
5. Configures organization-level protection features
6. Enrolls discovered accounts as GuardDuty members (auto-enrollment is disabled for explicit control)

### Important Notes

- The module sets `auto_enable_organization_members = NONE` to prevent automatic enrollment of newly created accounts. Accounts created after this module is deployed must be explicitly enrolled or you can update the module to discover and enroll them.
- The deprecated `EKS_RUNTIME_MONITORING` feature is explicitly set to `NONE` to prevent Terraform drift.
- Runtime Monitoring sub-feature ordering is fixed to match AWS API ordering (ECS_FARGATE, EC2, EKS) to prevent perpetual resource replacement.
- A 5-second delay is introduced after enabling GuardDuty on the management account to allow service propagation before member enrollment.

## Examples

### Enable All Protection Features

```hcl
module "guardduty" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/security/guardduty?ref=security-guardduty-v1.0"

  delegated_admin_account_id = "123456789012"
  
  s3_protection_enabled              = true
  eks_audit_logs_enabled             = true
  ebs_malware_protection_enabled     = true
  rds_protection_enabled             = true
  lambda_protection_enabled          = true
  runtime_monitoring_enabled         = true
  ai_protection_enabled              = true
  
  tags = {
    Environment = "production"
    Module      = "guardduty"
  }

  providers = {
    aws.org-management = aws.org-management
  }
}
```

### Enable Runtime Monitoring with Selective Sub-Features

```hcl
module "guardduty" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/security/guardduty?ref=security-guardduty-v1.0"

  delegated_admin_account_id = "123456789012"
  
  runtime_monitoring_enabled = true
  runtime_monitoring_configuration = {
    EKS_ADDON_MANAGEMENT         = "ALL"
    ECS_FARGATE_AGENT_MANAGEMENT = "ALL"
    EC2_AGENT_MANAGEMENT         = "NONE"  # Exclude EC2 agent management
  }
  
  tags = local.common_tags

  providers = {
    aws.org-management = aws.org-management
  }
}
```

### Exclude Specific Accounts

```hcl
module "guardduty" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/security/guardduty?ref=security-guardduty-v1.0"

  delegated_admin_account_id = "123456789012"
  
  s3_protection_enabled  = true
  ebs_malware_protection_enabled = true
  
  excluded_account_ids = [
    "111111111111",  # Development account
    "222222222222"   # Testing account
  ]
  
  tags = local.common_tags

  providers = {
    aws.org-management = aws.org-management
  }
}
```

## Troubleshooting

### Malware Protection Service Access Warning

If you see a console warning about malware protection permissions, ensure the module has successfully enabled Malware Protection service access. This is handled automatically via the `terraform_data` provisioner that executes the AWS CLI command. Verify your AWS credentials have the necessary permissions and that the `ct-management` profile is correctly configured.

### Account Not Enrolled

Verify the account is:
- In a Control Tower-managed OU (has at least one CT control enabled)
- Not in the `excluded_account_ids` list
- Not the delegated administrator account

Use the `enrolled_account_ids` output to confirm which accounts were discovered and enrolled.

### Perpetual Resource Replacement

This can occur if Runtime Monitoring sub-feature ordering is disrupted. The module maintains fixed ordering to match AWS API responses. Verify the Terraform state is consistent with the AWS API by running `terraform refresh` and reviewing plan output.
