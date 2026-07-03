# Changelog

## [v1.0] - 2026-07-03

### Added

- Initial release of the control-tower module
- AWS Control Tower landing zone provisioning with configurable manifest
- Support for centralized logging, backup integration, and AWS Config
- OU-level region deny control (CT.MULTISERVICE.PV.1) with built-in exemptions for global/billing services
- Centralized root access management via IAM Identity Center
- IAM Identity Center permission set creation when access management is enabled
- Resource Access Management (RAM) sharing with AWS Organizations
- Configurable landing zone version and governed regions
- Dynamic parameter handling for region deny control exemptions (actions and principals)
- 61-minute timeouts for control operations to accommodate large deployments
- Support for KMS encryption of logging and Config resources
- Configurable retention policies for logging and Config buckets
- Automatic inheritance drift remediation for enrolled accounts
- Data sources for organization reference and Identity Center instance lookup
