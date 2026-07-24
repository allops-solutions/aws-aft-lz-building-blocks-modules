# Changelog

## [1.0.0] - 2026-07-24

### Added

- Initial release of the Security Hub CSPM module
- Organization-wide Security Hub configuration in delegated administrator account
- Automatic discovery and targeting of Control Tower-managed OUs for policy association
- Security Hub configuration policy with support for four security standards:
  - AWS Foundational Security Best Practices v1.0.0
  - CIS AWS Foundations Benchmark v5.0.0
  - AI Security Best Practices v1.0.0
  - AWS Resource Tagging Standard v1.0.0
- Per-standard toggles to enable/disable individual security standards (all enabled by default)
- Configurable security control disabling via `disabled_control_identifiers` variable
- Finding aggregation across multiple AWS Regions with configurable secondary and additional regions
- Central organization configuration mode for unified account management
- Automated Security Hub finding notifications via EventBridge → Lambda → SNS → email pipeline
- Severity-based notification filtering (LOW, MEDIUM, HIGH, CRITICAL)
- Lambda formatter for human-readable email notifications of Security Hub findings
- Server-side encryption for SNS notification topic using AWS-managed SNS key
- Role-based access control for Lambda formatter
- CloudWatch logging for formatter Lambda with 90-day retention
- Automatic email subscription to the audit account's root email address
- Filtering logic that excludes passing control findings (INFORMATIONAL) while retaining real findings
