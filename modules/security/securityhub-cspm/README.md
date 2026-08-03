# Security Hub CSPM

Enables AWS Security Hub Cloud Security Posture Management (CSPM) organization-wide, configures security standards and controls, and delivers formatted finding notifications to the delegated administrator account.

## Usage

```hcl
module "security_hub_cspm" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/security/securityhub-cspm?ref=security-securityhub-cspm-v2.0"

  # Required variables
  delegated_admin_account_id = var.audit_account_id
  region                     = var.primary_region

  # Optional: configure additional regions for finding aggregation
  secondary_region   = "us-east-1"
  additional_regions = ["eu-west-1"]

  # Optional: enable/disable security standards
  foundational_security_enabled = true
  cis_benchmark_enabled         = true
  ai_security_enabled           = true
  resource_tagging_enabled      = true

  # Optional: disable specific controls in the configuration policy
  disabled_control_identifiers = [
    "SecurityHub.1",
    "SecurityHub.2",
  ]

  # Optional: configure finding notification severity threshold
  notification_min_severity = "HIGH"

  # Optional: sequence after other modules (e.g., GuardDuty, Inspector)
  deployment_dependencies = [
    module.guardduty.deployment_gate,
    module.inspector.deployment_gate,
  ]

  # Tags
  tags = var.common_tags
}

# To pin to a specific version:
#   source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/security/securityhub-cspm?ref=security-securityhub-cspm-v2.0"
```

## Requirements

| Requirement | Version |
|-------------|---------|
| Terraform   | >= 1.6.0 |
| aws         | >= 6.23.0 |
| time        | >= 0.9.0 |
| archive     | >= 2.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `delegated_admin_account_id` | Account ID to register as the Security Hub CSPM delegated administrator for the organization. | `string` | — | ✓ |
| `region` | Primary AWS Region where Security Hub CSPM is configured (home Region). Used to construct region-specific standard ARNs and as the finding aggregation target. | `string` | — | ✓ |
| `secondary_region` | Secondary AWS Region where Security Hub CSPM is enabled. Findings from this Region are aggregated into the home Region. | `string` | `""` | |
| `additional_regions` | Additional AWS Regions where Security Hub CSPM is enabled, beyond the primary and secondary Regions. | `list(string)` | `[]` | |
| `foundational_security_enabled` | Enable the AWS Foundational Security Best Practices v1.0.0 standard. | `bool` | `true` | |
| `cis_benchmark_enabled` | Enable the CIS AWS Foundations Benchmark v5.0.0 standard. | `bool` | `true` | |
| `ai_security_enabled` | Enable the AI Security Best Practices v1.0.0 standard. | `bool` | `true` | |
| `resource_tagging_enabled` | Enable the AWS Resource Tagging Standard v1.0.0. | `bool` | `true` | |
| `disabled_control_identifiers` | Security control identifiers to disable in the configuration policy. All other controls remain enabled. | `list(string)` | `[]` | |
| `excluded_account_ids` | Account IDs to exclude from the Security Hub CSPM configuration policy association. | `list(string)` | `[]` | |
| `notification_min_severity` | Lowest finding severity label that triggers a notification. Findings at this level and above are delivered. One of LOW, MEDIUM, HIGH, or CRITICAL. | `string` | `"HIGH"` | |
| `deployment_dependencies` | Opaque values from other modules that must finish applying before this module creates any resources. Wire this to the modules Security Hub should run after (e.g., `[module.guardduty, module.inspector]`). | `any` | `null` | |
| `tags` | Tags to apply to all resources. Passed in from the root module. | `map(string)` | — | ✓ |

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

### Security Hub CSPM Configuration
This module configures Security Hub in organization CENTRAL mode across the organization:

1. **Delegated administration**: Registers the specified account as the Security Hub delegated administrator.
2. **Finding aggregation**: Aggregates findings from the specified Regions into the home Region.
3. **Organization configuration**: Enables CENTRAL configuration mode with auto-enable disabled, ensuring all configuration is managed exclusively through configuration policies.
4. **Configuration policy**: Creates a policy that enables Security Hub and activates selected security standards (AWS Foundational Security Best Practices, CIS AWS Foundations Benchmark, AI Security Best Practices, and/or AWS Resource Tagging Standard).
5. **Policy association**: Associates the configuration policy with all Control Tower-managed OUs (excluding the Suspended and Security OUs) and the delegated administrator account itself.

### Finding Notifications
New, active findings at or above the configured severity threshold are automatically delivered to the delegated administrator account's email:

- **EventBridge rule**: Filters findings by severity (e.g., HIGH and CRITICAL) and workflow status (NEW, ACTIVE).
- **Lambda formatter**: Processes findings, applies per-product routing logic, and formats them for email delivery.
  - **Control findings** (ProductName = "Security Hub"): Notified on first observation, suppressed thereafter, with monthly reminders on the 1st of each month.
  - **Other products** (GuardDuty, Inspector, Macie, IAM Access Analyzer, etc.): Always notified if they clear the severity floor.
- **SNS topic**: Encrypts and delivers formatted notifications to the subscribed email address. Recipients can opt out by unsubscribing.

### Deployment Sequencing
To ensure dependent services are initialized before Security Hub starts aggregating findings, wire the `deployment_dependencies` variable to any prerequisite modules:

```hcl
deployment_dependencies = [
  module.guardduty.deployment_gate,
  module.inspector.deployment_gate,
]
```

## Testing Finding Notifications

See [`lambda/TEST_EVENTS.md`](./lambda/TEST_EVENTS.md) in the module source for comprehensive testing procedures:

- **Real end-to-end tests** using `guardduty create-sample-findings` to generate genuine findings.
- **Pipeline smoke tests** using `securityhub batch-import-findings` to validate the EventBridge → Lambda → SNS wiring.
- **Unit tests** using `lambda invoke` to exercise suppression policies and per-product routing without real findings.

## Notes

- **Security Hub delegated administrator** must be the same account where this module is deployed.
- **AWS Config** must be enabled in the delegated administrator account (Control Tower enables this automatically in audit accounts).
- **Organization structure** is discovered at plan time via AWS Organizations API. Top-level OUs with at least one enabled Control Tower control are automatically targeted.
- **Severity floor** is applied at the EventBridge rule level; findings below the threshold never invoke the Lambda, reducing unnecessary function executions.
- **Monthly reminders** for control findings are sent based on the date when the finding is re-evaluated (UpdatedAt) rather than when it was first observed.
