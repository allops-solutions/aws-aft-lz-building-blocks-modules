# Changelog

## [v1.0] - 2026-07-24

### Added

- Initial release of the control-tower module
- AWS Control Tower landing zone deployment via Terraform with configurable manifest support
- Prerequisite IAM roles for Control Tower (AWSControlTowerAdmin, AWSControlTowerCloudTrailRole, AWSControlTowerStackSetRole, AWSControlTowerConfigAggregatorRoleForOrganizations)
- OU-level region deny control (CT.MULTISERVICE.PV.1) with configurable allowed regions and exemptions
- Built-in exemptions for global/billing services (bcm-dashboards, bcm-data-exports, bcm-pricing-calculator, pricingplanmanager, uxc)
- Support for control tower-managed IAM Identity Center with Control-Tower-Administrator permission set
- Centralized root access management via IAM Organizations features (RootCredentialsManagement, RootSessions)
- RAM sharing with AWS Organizations
- Configurable centralized logging (CloudTrail, S3 retention policies)
- Optional AWS Backup integration with separate central and admin account support
- Optional AWS Config integration with aggregator configuration
- IAM propagation delay handling to prevent CreateLandingZone race conditions
- Support for landing zone versions with dynamic manifest generation
- Built-in data source for looking up Control Tower-owned OUs (Security, Account Factory for Terraform)
- Dynamic OU exclusion for region deny control
- Support for principal ARN exemptions from region deny control
- Outputs for landing zone ARN, version, drift status, organization IDs, and Identity Center instance ARN

