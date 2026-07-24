# AWS Security Hub CSPM Terraform Module

Enables and manages AWS Security Hub Cloud Security Posture Management (CSPM) across an organization. This module configures Security Hub in the delegated administrator account, establishes central organization-wide policy, automatically discovers and targets Control Tower-managed OUs, enables configurable security standards, and delivers formatted finding notifications via email.

## Usage

```hcl
module "securityhub_cspm" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/security/securityhub-cspm?ref=security-securityhub-cspm-v1.0"

  # Pin to a specific version
  # source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/security/securityhub-cspm?ref=security-securityhub-cspm-v1.0"

  delegated_admin_account_id = var.security_account_id
  region                     = var.home_region

  # Optional: enable additional regions for finding aggregation
  secondary_region   = "us-west-2"
  additional_regions = ["eu-west-1"]

  # Optional: disable specific security controls
  disabled_control_identifiers = [
    "SecurityHub.Config.1",
  ]

  # Optional: adjust notification severity threshold
  notification_min_severity = "HIGH"

  # Optional: customize all resources
  foundational_security_enabled = true
  cis_benchmark_enabled         = true
  ai_security_enabled           = true
  resource_tagging_enabled      = true

  tags = {
    Environment = "Production"
    Module      = "SecurityHub-CSPM"
  }

  # Required: provide org-management account provider
  providers = {
    aws                = aws.security-account
    aws.org-management = aws.org-management
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.6.0 |
| aws | >= 6.23.0 |
| archive | >= 2.0.0 |
| time | >= 0.9.0 |

## Providers

This module requires two AWS provider aliases:

- `aws` — The Security Hub delegated administrator account (where this module is applied)
- `aws.org-management` — The organization management account (for organization API calls and delegation)

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
| `notification_min_severity` | Lowest finding severity label that triggers a notification. Findings at this level and above are delivered. One of `LOW`, `MEDIUM`, `HIGH`, or `CRITICAL`. | `string` | `"MEDIUM"` | no |
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

## How It Works

### Organization Structure Discovery

The module automatically discovers Control Tower-managed OUs at the top level of the organization by querying for enabled Control Tower controls. Any top-level OU with at least one enabled control is considered CT-managed. The Security OU is included as a special case for potential future use, though Control Tower does not enable Config in the Account currently.

### Configuration Policy

A single Security Hub configuration policy is created with the selected security standards and optional disabled controls. This policy is then associated with all discovered CT-managed OUs, so accounts within those OUs automatically inherit the configuration. The policy enables centralized, organization-wide compliance posture visibility.

### Finding Aggregation

Findings from the primary Region (home Region) and any configured secondary/additional Regions are aggregated into the home Region. This allows centralized analysis and notification across all Regions from a single delegated administrator account.

### Finding Notifications

An event-driven pipeline automatically formats and delivers new, active Security Hub findings at or above a configurable severity threshold to the audit account's root email via SNS:

1. **EventBridge rule** filters findings by severity, record state, and workflow status
2. **Lambda formatter** renders findings into human-readable text
3. **SNS topic** delivers to the audit account's root email

Passing control findings (which carry INFORMATIONAL severity) are intentionally excluded to reduce noise. Recipients can opt out by unsubscribing from the SNS topic, mirroring Control Tower's own aggregate topic model.

## Notes

- The module does not currently include the organization management account in the configuration policy association, as Control Tower does not enable Config in that account. This may be added in a future release if justified.
- The Security OU is included in the discovery logic to support future use cases, though it is not currently targeted by default.
- Finding notifications are always created and enabled; to stop receiving them, unsubscribe from the SNS topic rather than removing the infrastructure.
- All Security Hub resources created by this module use the tag set provided via the `tags` variable.
