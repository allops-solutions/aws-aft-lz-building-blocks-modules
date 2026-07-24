# Changelog

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.0] - 2026-07-24

### Added

- Initial release of the security/guardduty module
- Organization-wide GuardDuty configuration with delegated administrator registration
- Automatic account discovery from Control Tower-managed organizational units (OUs)
- Support for multiple GuardDuty protection plans:
  - S3 Data Events protection
  - EKS Audit Log monitoring
  - EBS Malware Protection
  - RDS Login Events protection
  - Lambda Network Logs monitoring
  - Runtime Monitoring (EKS, EC2, ECS Fargate with configurable agent management)
  - AI Protection
- Explicit member account enrollment with full control over which accounts are protected
- Malware Protection service access enablement for delegated administrator
- Account exclusion mechanism via `excluded_account_ids` variable
- Comprehensive outputs: delegated admin account ID, detector ID, enrolled accounts, and protection plan configuration
