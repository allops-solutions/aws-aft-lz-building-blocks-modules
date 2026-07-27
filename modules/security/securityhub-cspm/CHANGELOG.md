# Changelog

# Changelog

## [1.0.0] - 2026-07-27

### Added

- Initial release of Security Hub CSPM module
- Organization-wide Security Hub CSPM configuration with central organization mode
- Automatic discovery of Control Tower-managed OUs for policy association
- Configuration policy targeting with support for multiple security standards
- Security standards support:
  - AWS Foundational Security Best Practices v1.0.0 (enabled by default)
  - CIS AWS Foundations Benchmark v5.0.0 (enabled by default)
  - AI Security Best Practices v1.0.0 (enabled by default)
  - AWS Resource Tagging Standard v1.0.0 (enabled by default)
- Configurable disabling of specific security controls via `disabled_control_identifiers`
- Multi-region finding aggregation with support for primary, secondary, and additional regions
- Finding aggregator setup that consolidates findings across specified regions into the home region
- Delegated administrator registration in the organization management account
- EventBridge-based Security Hub finding notifications pipeline:
  - Severity-filtered rule for new, active findings
  - Lambda formatter for human-readable email notifications
  - SNS topic delivery to the delegated administrator account's root email
  - Configurable severity threshold (LOW, MEDIUM, HIGH, CRITICAL)
- Deployment dependency gate for sequencing with other modules (e.g., GuardDuty, Inspector)
- Full IAM role and policy setup for the notification formatter Lambda
- KMS encryption for SNS topic using AWS-managed key
- CloudWatch log retention (90 days) for Lambda formatter
- Tag propagation across all created resources
- Provider configuration aliases for multi-account organization management
