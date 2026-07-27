# Security Hub CSPM Module

Enables and configures AWS Security Hub Cloud Security Posture Management (CSPM) at the organization level with centralized finding aggregation, multi-standard policy enforcement, and automated email notifications.

## Overview

This module automates Security Hub CSPM deployment across an AWS organization by:

- Enabling Security Hub CSPM in the delegated administrator (audit) account
- Registering the delegated administrator in the organization management account
- Configuring organization-wide central mode for unified finding management
- Aggregating findings across multiple regions into a primary region
- Creating and associating configuration policies with Control Tower-managed organizational units
- Supporting four security standards with individual enable/disable toggles
- Delivering formatted Security Hub findings to the audit account's email via EventBridge, Lambda, and SNS
- Automatically discovering and targeting all Control Tower-managed top-level OUs

## Usage

```hcl
# Pin to a specific version tag
# source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/security/securityhub-cspm?ref=security-securityhub-cspm-v1.0"

module "securityhub_cspm" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/security/securityhub-cspm?ref=security-securityhub-cspm-v1.0"

  # Organization and account configuration
  delegated_admin_account_id = "123456789012"
  region                      = "us-east-1"

  # Multi-region aggregation
  secondary_region   = "eu-central-1"
  additional_regions = ["ap-southeast-1"]

  # Security standards (all enabled by default)
  foundational_security_enabled = true
  cis_benchmark_enabled         = true
  ai_security_enabled           = true
  resource_tagging_enabled      = true

  # Optional: disable specific security controls
  disabled_control_identifiers = []

  # Finding notifications
  notification_min_severity = "HIGH"

  # Deployment ordering (wire modules that should complete first)
  deployment_dependencies = [
    module.guardduty.deployment_id,
    module.inspector.deployment_id,
  ]

  # Tags
  tags = {
    Environment = "prod"
    Service     = "security"
  }

  providers = {
    aws.org-management = aws.org-management
  }
}
```

## Requirements

### Terraform

- Terraform >= 1.6.0

### Providers

| Provider | Version | Purpose |
|----------|---------|---------|
| `aws` | >= 6.23.0 | AWS services in delegated admin account; requires `aws.org-management` alias for organization-level operations |
| `time` | >= 0.9.0 | Delay after delegated admin registration to allow organization sync |
| `archive` | >= 2.0.0 | Package Lambda function code |

### Multi-Account Setup

This module requires provider configuration for both the delegated administrator (audit) account and the organization management account:

```hcl
provider "aws" {
  alias = "org-management"
  # Configuration for organization management account
}

provider "aws" {
  # Default provider for delegated administrator account
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `delegated_admin_account_id` | Account ID to register as the Security Hub CSPM delegated administrator for the organization. | `string` | — | yes |
| `region` | Primary AWS Region where Security Hub CSPM is configured (home Region). Used to construct region-specific standard ARNs and as the finding aggregation target. | `string` | — | yes |
| `secondary_region` | Secondary AWS Region where Security Hub CSPM is enabled. Findings from this Region are aggregated into the home Region. | `string` | `""` | no |
| `additional_regions` | Additional AWS Regions where Security Hub CSPM is enabled, beyond the primary and secondary Regions. | `list(string)` | `[]` | no |
| `foundational_security_enabled` | Enable the AWS Foundational Security Best Practices v1.0.0 standard. | `bool` | `true` | no |
| `cis_benchmark_enabled` | Enable the CIS AWS Foundations Benchmark v5.0.0 standard. | `bool` | `true` | no |
| `ai_security_enabled` | Enable the AI Security Best Practices v1.0.0 standard. | `bool` | `true` | no |
| `resource_tagging_enabled` | Enable the AWS Resource Tagging Standard v1.0.0. | `bool` | `true` | no |
| `disabled_control_identifiers` | Security control identifiers to disable in the configuration policy. All other controls remain enabled. | `list(string)` | `[]` | no |
| `excluded_account_ids` | Account IDs to exclude from the Security Hub CSPM configuration policy association. | `list(string)` | `[]` | no |
| `notification_min_severity` | Lowest finding severity label that triggers a notification. Findings at this level and above are delivered. One of `LOW`, `MEDIUM`, `HIGH`, or `CRITICAL`. | `string` | `"HIGH"` | no |
| `deployment_dependencies` | Opaque values from other modules that must finish applying before this module creates any resources. Wire this to the modules Security Hub should run after (e.g., `[module.guardduty, module.inspector]`). Consumed only by an internal resource gate; does not defer data sources to apply time. | `any` | `null` | no |
| `tags` | Tags to apply to all resources. Passed in from the root module. | `map(string)` | — | yes |

## Outputs

| Name | Description |
|------|-------------|
| `configuration_policy_id` | UUID of the Security Hub CSPM configuration policy. |
| `configuration_policy_arn` | ARN of the Security Hub CSPM configuration policy. |
| `delegated_admin_account_id` | Account ID registered as the Security Hub CSPM delegated administrator. |
| `association_targets` | Set of OU IDs and account IDs associated with the configuration policy. |
| `notification_topic_arn` | ARN of the SNS topic that delivers formatted Security Hub finding notifications. |
| `notification_email` | Email address subscribed to the notification topic (this account's own root email). |
| `notification_min_severity` | Lowest finding severity label that triggers a notification. |
| `notification_severity_labels` | Severity labels that trigger a notification (the minimum and everything above it). |

## Behavior Notes

### Control Tower OU Discovery

The module automatically identifies Control Tower-managed organizational units (OUs) by querying the organization structure and checking for enabled Control Tower controls on each top-level OU. OUs named "Suspended" and "Security" are excluded from the configuration policy association, as they have special handling in Control Tower environments.

The delegated administrator account is added explicitly to the association targets to ensure it is covered by the configuration policy, even if it is not a member of a Control Tower-managed OU.

### Finding Aggregation

The finding aggregator links specified regions into the primary region (home region). The primary region must not be included in the `linked_regions` list as the AWS API rejects it.

A 90-second pause is inserted after delegated administrator registration to allow the organization data sync to complete before enabling central configuration. This prevents "organization is still syncing" errors.

### Notification Pipeline

The notification pipeline (EventBridge → Lambda → SNS → email) is always created and automatically subscribes the delegated administrator account's root email. Recipients can opt out by unsubscribing from the SNS topic without removing the pipeline infrastructure.

Severity filtering excludes INFORMATIONAL findings (which include passing control checks) to reduce noise while retaining findings from GuardDuty, Inspector, and other services.

### Configuration Policy

The configuration policy enables Security Hub service, activates selected standards, and allows disabling specific controls. When the policy is recreated due to variable changes, associations are destroyed first to avoid 409 conflicts with the API.

### Organization Configuration

Organization-wide central mode disables legacy auto-enable behavior, making configuration policy the sole source of truth for account-level settings.

## Security Considerations

- The SNS topic for notifications is encrypted with the AWS-managed key for SNS (`alias/aws/sns`)
- The Lambda formatter's IAM role is scoped to only publish to the notifications topic and write logs
- KMS permissions for the formatter are scoped to SNS calls within the specified region
- All resources are tagged for cost allocation and resource tracking
