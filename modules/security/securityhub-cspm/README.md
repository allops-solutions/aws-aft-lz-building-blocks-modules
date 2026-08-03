# AWS Security Hub CSPM

The `security/securityhub-cspm` Terraform module configures AWS Security Hub CSPM centrally for an AWS Control Tower organization. It enables Security Hub in the delegated administrator account, delegates organization administration, aggregates findings from selected Regions, creates a central configuration policy, and associates that policy with Control Tower-managed OUs.

The module also creates a finding-notification pipeline:

```text
Security Hub Findings - Imported -> EventBridge -> Lambda -> SNS -> email
```

The EventBridge rule forwards active, new findings at or above the configured severity floor. The Lambda applies product-specific delivery behavior: Security Hub control findings are throttled to first-observed and monthly-reminder notifications, while findings from other products such as GuardDuty, Inspector, Macie, and IAM Access Analyzer are delivered whenever they pass the severity floor.

## Usage

The module is intended to run in the Security Hub delegated administrator account and requires an AWS provider configuration for the organization management account through the `aws.org-management` alias.

```hcl
provider "aws" {
  region = "eu-central-1"
}

provider "aws" {
  alias  = "org-management"
  region = "eu-central-1"
}

module "securityhub_cspm" {
  # Pin the module to a specific release; update this ref deliberately when upgrading.
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/security/securityhub-cspm?ref=security-securityhub-cspm-v1.0"

  providers = {
    aws                = aws
    aws.org-management = aws.org-management
  }

  delegated_admin_account_id = "123456789012"
  region                     = "eu-central-1"
  secondary_region           = "us-east-1"

  # Optional: add more Regions whose findings should be aggregated.
  additional_regions = ["us-west-2"]

  # All four standards are enabled by default.
  foundational_security_enabled = true
  cis_benchmark_enabled          = true
  ai_security_enabled            = true
  resource_tagging_enabled      = true

  # Optional: order this module after other security-service modules.
  deployment_dependencies = [module.guardduty, module.inspector]

  tags = {
    Environment = "security"
    ManagedBy   = "terraform"
  }
}
```

The `aws` provider should target the delegated administrator/security account. The `aws.org-management` provider must target the AWS Organizations management account and have permission to register the delegated administrator.

After applying the module, the SNS email subscription must be confirmed from the email sent by AWS before notifications are delivered.

## Requirements

| Name | Version |
|---|---|
| Terraform | `>= 1.6.0` |
| AWS provider | `>= 6.23.0` |
| Time provider | `>= 0.9.0` |
| Archive provider | `>= 2.0.0` |

The AWS provider must include the `aws.org-management` configuration alias shown in the usage example. The deployment account must be the Security Hub delegated administrator, and the organization must be configured for the required AWS Control Tower and Security Hub operations.

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `delegated_admin_account_id` | Account ID to register as the Security Hub CSPM delegated administrator for the organization. | `string` | — | yes |
| `region` | Primary AWS Region where Security Hub CSPM is configured and where aggregated findings are collected. | `string` | — | yes |
| `secondary_region` | Secondary AWS Region where Security Hub CSPM is enabled and whose findings are aggregated into the home Region. | `string` | `""` | no |
| `additional_regions` | Additional AWS Regions where Security Hub CSPM is enabled, beyond the primary and secondary Regions. | `list(string)` | `[]` | no |
| `foundational_security_enabled` | Enable the AWS Foundational Security Best Practices v1.0.0 standard. | `bool` | `true` | no |
| `cis_benchmark_enabled` | Enable the CIS AWS Foundations Benchmark v5.0.0 standard. | `bool` | `true` | no |
| `ai_security_enabled` | Enable the AI Security Best Practices v1.0.0 standard. | `bool` | `true` | no |
| `resource_tagging_enabled` | Enable the AWS Resource Tagging Standard v1.0.0. | `bool` | `true` | no |
| `disabled_control_identifiers` | Security control identifiers to disable in the configuration policy. All other controls remain enabled. | `list(string)` | `[]` | no |
| `excluded_account_ids` | Account IDs to exclude from Security Hub CSPM policy associations. This input is reserved for exclusion behavior; this release does not yet apply it when calculating association targets. | `list(string)` | `[]` | no |
| `notification_min_severity` | Lowest finding severity label that triggers a notification. Accepted values are `LOW`, `MEDIUM`, `HIGH`, or `CRITICAL`; findings at this level and above are delivered. | `string` | `"HIGH"` | no |
| `deployment_dependencies` | Opaque values from other modules that must finish applying before this module creates resources, such as GuardDuty or Inspector modules. | `any` | `null` | no |
| `tags` | Tags to apply to all resources. | `map(string)` | — | yes |

The `region` value is the aggregation home Region and is also used to construct Region-specific standard ARNs. The home Region is not included in the finding aggregator's linked-region list; use `secondary_region` and `additional_regions` for other Regions.

## Outputs

| Name | Description |
|---|---|
| `configuration_policy_id` | UUID of the Security Hub CSPM configuration policy. |
| `configuration_policy_arn` | ARN of the Security Hub CSPM configuration policy. |
| `delegated_admin_account_id` | Account ID registered as the Security Hub CSPM delegated administrator. |
| `association_targets` | Set of OU IDs and account IDs associated with the configuration policy. |
| `notification_topic_arn` | ARN of the SNS topic that delivers formatted Security Hub finding notifications. |
| `notification_email` | Email address subscribed to the notification topic; this is the delegated administrator account's root email. |
| `notification_min_severity` | Lowest finding severity label that triggers a notification. |
| `notification_severity_labels` | Severity labels that trigger a notification, from the configured minimum through `CRITICAL`. |

## Notification behavior

The notification pipeline is always created. Set `notification_min_severity` to control the EventBridge severity floor; below-floor findings do not invoke the Lambda.

- `ProductName = "Security Hub"`: the Lambda sends a first-observed notification, a monthly reminder when `UpdatedAt` falls on the first day of a month, and suppresses other repeated notifications.
- Any other product: the Lambda sends a standard notification for every finding that passes the EventBridge floor.

The SNS topic uses the AWS-managed SNS KMS key. Recipients can stop delivery by unsubscribing from the SNS subscription.

## Testing

The module includes `lambda/TEST_EVENTS.md`, which documents:

1. A real GuardDuty end-to-end test using `guardduty create-sample-findings`.
2. A synthetic pipeline smoke test using `securityhub batch-import-findings`.
3. Direct Lambda tests for first-observed, suppressed, monthly-reminder, non-control-product, and mixed-batch behavior.

Replace the Region, account ID, and Lambda function name placeholders in that document before running the commands.
