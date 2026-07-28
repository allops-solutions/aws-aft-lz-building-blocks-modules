# AWS Security Hub CSPM Module

Enables Security Hub Cloud Security Posture Management (CSPM) organization-wide with automated configuration policies, cross-region finding aggregation, and email notifications for security findings.

This module sets up Security Hub in the delegated administrator (audit) account, registers delegation at the organization level, configures central organization mode, creates a configuration policy with selected security standards, and automatically associates it with all Control Tower-managed organizational units. It also provides an EventBridge-driven notification pipeline that delivers formatted Security Hub findings to the audit account's email inbox.

## Usage

```hcl
module "securityhub_cspm" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/security/securityhub-cspm?ref=security-securityhub-cspm-v1.0"

  delegated_admin_account_id = var.audit_account_id
  region                     = var.primary_region
  secondary_region           = var.secondary_region
  additional_regions         = var.additional_regions

  foundational_security_enabled = true
  cis_benchmark_enabled         = true
  ai_security_enabled           = true
  resource_tagging_enabled      = true

  disabled_control_identifiers = []
  notification_min_severity    = "HIGH"

  deployment_dependencies = [
    module.guardduty.deployment_id,
    module.inspector.deployment_id,
  ]

  tags = var.common_tags

  providers = {
    aws                = aws.audit
    aws.org-management = aws.management
  }
}

# Pin to a specific version by appending ?ref=security-securityhub-cspm-v1.0
# To update to a newer version, change the ref tag (e.g. ?ref=security-securityhub-cspm-v1.1)
```

## Requirements

- **Terraform:** >= 1.6.0
- **AWS Provider:** >= 6.23.0 (with `aws.org-management` provider alias)
- **Time Provider:** >= 0.9.0
- **Archive Provider:** >= 2.0.0

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
| `deployment_dependencies` | Opaque values from other modules that must finish applying before this module creates any resources. Wire this to the modules Security Hub should run after (e.g. `[module.guardduty, module.inspector]`). Consumed only by an internal resource gate that the module's entry resources depend on. Unlike a module-level `depends_on`, this does NOT defer the module's data sources to apply time, so `for_each` over organization data keeps working at plan time. | `any` | `null` | no |
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
