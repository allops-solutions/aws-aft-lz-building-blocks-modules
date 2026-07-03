# Changelog

# Changelog

## [v1.0] - 2026-07-03

### Added

- **Initial release of the control-tower module** — Complete AWS Control Tower landing zone provisioning via Terraform
- **Control Tower landing zone deployment** — Creates the landing zone with configurable manifest including security roles, centralized logging, AWS Config integration, and AWS Backup
- **Prerequisite IAM roles** — Automatically provisions the four required service roles:
  - `AWSControlTowerAdmin` — For Control Tower landing zone management
  - `AWSControlTowerCloudTrailRole` — For CloudTrail audit log delivery
  - `AWSControlTowerStackSetRole` — For CloudFormation stack set deployments
  - `AWSControlTowerConfigAggregatorRoleForOrganizations` — For AWS Config organization aggregation
- **OU-level region deny control (CT.MULTISERVICE.PV.1)** — Replaces the landing-zone-level AWS-GR_REGION_DENY with a configurable, updatable version that:
  - Applies to caller-provided OUs, Security OU, and Account Factory for Terraform OU
  - Includes built-in exemptions for global/billing services (bcm-*, pricingplanmanager, uxc)
  - Supports custom exempted actions and principal ARNs for service-specific needs
- **Centralized root access management** — Optional IAM Organizations feature integration for RootCredentialsManagement and RootSessions
- **IAM Identity Center permission set** — Auto-provisioned `Control-Tower-Administrator` permission set when access management is enabled
- **AWS RAM sharing with Organizations** — Enables resource sharing across the organization
- **Landing zone configuration options**:
  - Centralized logging with configurable retention
  - AWS Config integration with separate buckets and KMS support
  - AWS Backup central vault and admin account setup
  - Custom KMS key support for encrypted resources
- **Comprehensive variable support** for all landing zone manifest sections and control configurations
- **Dependency orchestration** — Proper sequencing of IAM roles, RAM enablement, and landing zone creation

### Changed

- N/A (initial release)

### Fixed

- N/A (initial release)

### Removed

- N/A (initial release)


# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-07-03

### Added

- Initial release of the control-tower module
- AWS Control Tower landing zone deployment with full manifest-based configuration
- Support for centralized logging (CloudTrail + S3 with configurable retention)
- Support for AWS Backup integration with central vault and admin account configuration
- Support for AWS Config integration with logging bucket configuration
- IAM Identity Center permission set creation (Control-Tower-Administrator) when access management is enabled
- Centralized root access management via IAM Identity Center (RootCredentialsManagement and RootSessions)
- Resource Access Manager (RAM) sharing with AWS Organizations
- OU-level region deny control (CT.MULTISERVICE.PV.1) with:
  - Automatic detection and targeting of Control Tower-managed OUs (Security, Account Factory for Terraform)
  - Support for caller-provided target OUs
  - Built-in exemptions for global/billing services (BCM Dashboards, BCM Data Exports, BCM Pricing Calculator, Pricing Plan Manager, UXC)
  - Configurable extra exemptions for service-specific needs (e.g., Bedrock cross-region inference)
  - Optional principal-level exemptions for automation roles
  - OU-level exclusion capability for temporary exemptions
- Drift remediation via INHERITANCE_DRIFT for automatic account enrollment
- Full support for landing zone versions via configurable version parameter
- Outputs for landing zone ARN, version, drift status, organization details, and Identity Center instance ARN


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
