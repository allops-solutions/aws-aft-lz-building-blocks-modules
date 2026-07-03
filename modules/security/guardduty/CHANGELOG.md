# Changelog

## [v1.0] - 2026-07-03

### Added
- Initial release of the GuardDuty module
- Support for AWS GuardDuty organization configuration management
- `aws_guardduty_organization_configuration` resource for centralized GuardDuty setup
- `aws_guardduty_organization_configuration_feature` resource for enabling organization-wide features
- Data source to reference the current GuardDuty detector
- `auto_enable_organization_members` variable to control automatic member enrollment (ALL, NEW, NONE)
- `datasources` variable to enable S3 logs, Kubernetes audit logs, and malware protection data collection
- `organization_features` variable for enabling GuardDuty detection features:
  - S3_DATA_EVENTS
  - EKS_AUDIT_LOGS
  - EBS_MALWARE_PROTECTION
  - RDS_LOGIN_EVENTS
  - LAMBDA_NETWORK_LOGS
  - RUNTIME_MONITORING
  - EKS_RUNTIME_MONITORING
- `additional_configuration` variable for runtime monitoring supplementary settings:
  - EKS_ADDON_MANAGEMENT
  - ECS_FARGATE_AGENT_MANAGEMENT
  - EC2_AGENT_MANAGEMENT
- Input validation for all variables with descriptive error messages
- Support for Terraform >= 1.5.0 and AWS provider >= 5.0
