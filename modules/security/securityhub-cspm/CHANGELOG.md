# Changelog

## [v1.0.0] - 2026-07-24

### Added

- Initial release of the Security Hub CSPM module for organization-wide AWS Security Hub configuration.
- Automatic discovery and configuration of Control Tower-managed organizational units (OUs).
- Security Hub CSPM enablement in the delegated administrator account with consolidated control findings.
- Organization-wide central configuration mode with automatic delegation registration.
- Multi-region finding aggregation support with primary, secondary, and additional region options.
- Configurable security standards through individual toggles:
  - AWS Foundational Security Best Practices v1.0.0
  - CIS AWS Foundations Benchmark v5.0.0
  - AI Security Best Practices v1.0.0
  - AWS Resource Tagging Standard v1.0.0
- Configuration policy framework for managing security controls across the organization.
- Support for disabling specific security controls via `disabled_control_identifiers`.
- Automatic policy association with discovered Control Tower-managed OUs.
- Integrated finding notification pipeline:
  - EventBridge rule for severity-based filtering (LOW, MEDIUM, HIGH, CRITICAL).
  - AWS Lambda formatter for rendering findings into human-readable email notifications.
  - SNS topic with server-side encryption (AWS-managed key) for email delivery.
  - Automatic subscription to the delegated administrator account's root email.
- Deployment gate mechanism for sequencing with dependent modules (GuardDuty, Inspector, etc.).
- Comprehensive CloudWatch logging for the notification formatter Lambda (90-day retention).
- Support for account exclusions via `excluded_account_ids` variable.


