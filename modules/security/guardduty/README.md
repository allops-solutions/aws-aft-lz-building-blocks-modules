# AWS GuardDuty Organization Module

A Terraform module for organizing and configuring Amazon GuardDuty across an AWS organization using a delegated administrator account. This module discovers all Control Tower-managed accounts, registers a delegated administrator, configures organization-wide protection plans, and explicitly enrolls accounts as GuardDuty members.

## Features

- **Automatic Account Discovery**: Discovers all accounts within Control Tower-managed organizational units (OUs) plus the management account
- **Delegated Administrator**: Registers a specified account as the GuardDuty organization delegated administrator
- **Protection Plans**: Configurable organization-wide GuardDuty features including S3, EKS, EBS, RDS, Lambda, Runtime Monitoring, and AI Protection
- **Member Enrollment**: Explicitly enrolls discovered accounts as GuardDuty members with full control over enrollment
- **Account Exclusion**: Exclude specific accounts from GuardDuty enrollment
- **Service Access**: Enables Malware Protection service access for the delegated administrator
- **Intelligent Dependency Management**: Handles timing requirements for GuardDuty API propagation and service enablement

## Usage

```hcl
# Pin to a specific version using the ref parameter
# source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/security/guardduty?ref=security-guardduty-v1.0"

module "guardduty" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/security/guardduty?ref=security-guardduty-v1.0"

  delegated_admin_account_id = "123456789012" # Security/Audit account ID

  # Enable protection plans as needed
  s3_protection_enabled              = true
  ebs_malware_protection_enabled      = true
  eks_audit_logs_enabled              = true
  rds_protection_enabled              = true
  lambda_protection_enabled           = true
  runtime_monitoring_enabled          = true
  ai_protection_enabled               = true

  # Configure Runtime Monitoring sub-features (only effective when runtime_monitoring_enabled = true)
  runtime_monitoring_configuration = {
    EKS_ADDON_MANAGEMENT         = "ALL"
    ECS_FARGATE_AGENT_MANAGEMENT = "ALL"
    EC2_AGENT_MANAGEMENT         = "ALL"
  }

  # Optionally exclude specific accounts
  excluded_account_ids = [
    "111111111111", # Development account
  ]

  tags = {
    Environment = "Production"
    Module      = "GuardDuty"
  }

  # Configure provider aliases for organization management account
  providers = {
    aws.org-management = aws.org-management
  }
}
```

### Provider Configuration

This module requires a provider alias for the organization management account. Configure it in your root module:

```hcl
provider "aws" {
  alias = "org-management"
  # Configuration for the organization management account
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | >= 6.23.0 |
| time | >= 0.9.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| delegated_admin_account_id | Account ID to register as the Amazon GuardDuty delegated administrator for the organization. | `string` | n/a | yes |
| s3_protection_enabled | Enable GuardDuty S3 Protection across enrolled accounts. Detects data exfiltration and destruction attempts in S3 buckets. | `bool` | `false` | no |
| eks_audit_logs_enabled | Enable GuardDuty EKS Audit Log Monitoring across enrolled accounts. Analyzes Kubernetes audit logs for suspicious control plane activity. | `bool` | `false` | no |
| ebs_malware_protection_enabled | Enable GuardDuty Malware Protection for EC2 across enrolled accounts. Scans EBS volumes for malware when threats are detected. | `bool` | `false` | no |
| rds_protection_enabled | Enable GuardDuty RDS Protection across enrolled accounts. Detects anomalous login activity on Aurora and RDS databases. | `bool` | `false` | no |
| lambda_protection_enabled | Enable GuardDuty Lambda Protection across enrolled accounts. Monitors Lambda network activity for threats like cryptomining. | `bool` | `false` | no |
| runtime_monitoring_enabled | Enable GuardDuty Runtime Monitoring across enrolled accounts. Monitors OS-level events on EKS, EC2, and ECS/Fargate workloads. | `bool` | `false` | no |
| ai_protection_enabled | Enable GuardDuty AI Protection across enrolled accounts. Detects threats to AI workloads built on Amazon Bedrock, AgentCore, and SageMaker AI. | `bool` | `false` | no |
| runtime_monitoring_configuration | Sub-feature configuration for Runtime Monitoring. Controls automated agent management for EKS, ECS Fargate, and EC2 workloads. Only effective when runtime_monitoring_enabled is true. Valid keys: EKS_ADDON_MANAGEMENT, ECS_FARGATE_AGENT_MANAGEMENT, EC2_AGENT_MANAGEMENT. Valid values: ALL, NEW, NONE. | `map(string)` | `{ EKS_ADDON_MANAGEMENT = "ALL", ECS_FARGATE_AGENT_MANAGEMENT = "ALL", EC2_AGENT_MANAGEMENT = "ALL" }` | no |
| excluded_account_ids | Account IDs to exclude from GuardDuty enrollment. These accounts will not have GuardDuty enabled even if they are discovered in the AFT metadata table. | `list(string)` | `[]` | no |
| tags | Tags to apply to all resources. Passed in from the root module. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| delegated_admin_account_id | Account ID registered as the Amazon GuardDuty delegated administrator. |
| detector_id | GuardDuty detector ID in the delegated administrator account. |
| enrolled_account_ids | Account IDs enrolled as GuardDuty members. |
| protection_plans | Protection plan configuration applied to the organization. |

## Notes

- **Account Discovery**: The module automatically discovers all accounts in Control Tower-managed organizational units (those with at least one enabled Control Tower control). The "Suspended" OU is explicitly excluded.
- **Auto-enable Disabled**: Organization-level auto-enable is configured as "NONE" to provide explicit control over account enrollment. Only accounts explicitly enrolled by this module receive GuardDuty protection.
- **Runtime Monitoring Agent Management**: When Runtime Monitoring is enabled, you can configure which workload types (EKS, EC2, ECS Fargate) have automated agent management enabled. Set individual sub-features to "NONE" to disable auto-management for specific workload types.
- **Malware Protection Service Access**: The module automatically enables Malware Protection service access for the delegated administrator account. This is required for the service-linked role to be created in member accounts.
- **API Propagation Delay**: A 60-second delay is implemented after enabling GuardDuty on the organization management account to allow API propagation. This is a one-time cost at initial provisioning.
- **Deprecated EKS_RUNTIME_MONITORING**: The EKS_RUNTIME_MONITORING feature is deprecated by AWS but explicitly managed by this module with a value of "NONE" to prevent Terraform drift on subsequent applies.
