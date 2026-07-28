# Changelog

## [1.0] - 2026-07-28

### Added

- Initial release of the Security Hub CSPM module
- Organization-wide Security Hub configuration in CENTRAL mode with automatic finding aggregation across all specified regions
- Automatic discovery and targeting of Control Tower-managed OUs via configuration policies
- Support for four security standards with individual toggle variables:
  - AWS Foundational Security Best Practices v1.0.0
  - CIS AWS Foundations Benchmark v5.0.0
  - AI Security Best Practices v1.0.0
  - AWS Resource Tagging Standard v1.0.0
- Fine-grained control over which security controls are enabled via `disabled_control_identifiers`
- Finding aggregation from primary, secondary, and additional AWS regions
- Automated Security Hub finding notifications via EventBridge → Lambda → SNS email pipeline
- Configurable notification severity filtering (LOW, MEDIUM, HIGH, CRITICAL)
- Automatic email subscription to the audit account's root email for notifications
- Delegated administrator account registration and management
- Comprehensive module outputs including configuration policy IDs, associated targets, and notification metadata
- Deployment ordering via `deployment_dependencies` to sequence after related modules (GuardDuty, Inspector, etc.)
