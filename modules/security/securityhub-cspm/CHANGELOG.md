# Changelog

# Changelog

All notable changes to the `security/securityhub-cspm` module are documented in this file.

## [v1.0] - 2026-08-03

### Added

- Initial release of the organization-wide AWS Security Hub CSPM module.
- Delegation of Security Hub administration to the designated security/audit account.
- Central Security Hub configuration with organization-wide configuration policies.
- Control Tower-managed OU discovery through AWS Organizations and Control Tower controls, with the delegated administrator account explicitly associated.
- Configurable Security Hub standards:
  - AWS Foundational Security Best Practices v1.0.0
  - CIS AWS Foundations Benchmark v5.0.0
  - AI Security Best Practices v1.0.0
  - AWS Resource Tagging Standard v1.0.0
- Configurable disabled security controls and finding aggregation across selected Regions.
- Deployment ordering support through `deployment_dependencies`.
- Security Hub finding notifications through EventBridge, a Python Lambda formatter, and an encrypted SNS topic with email subscription.
- Configurable notification severity floor, defaulting to `HIGH`.
- Notification policy that throttles Security Hub control findings while continuing to notify for other finding products after they pass the severity floor.
- Lambda test-event documentation covering end-to-end GuardDuty tests, pipeline smoke tests, and direct suppression-policy tests.

[v1.0]: https://github.com/allops-solutions/aws-aft-lz-building-blocks-modules/releases/tag/security-securityhub-cspm-v1.0
