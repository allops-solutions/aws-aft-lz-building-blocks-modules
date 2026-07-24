# Changelog

# Changelog

## [v1.0] - 2026-07-24

### Added

- Initial release of the `iam/break-glass-access` module
- Emergency break-glass IAM user in the Control Tower management account for failover access when IAM Identity Center and/or the external IdP are unavailable
- Console-only user with AdministratorAccess in the management account (no access keys)
- Random initial password generation with forced password change on first sign-in
- Secure credential storage in AWS Systems Manager Parameter Store (SecureString) with console URL and username
- MFA enforcement for console access
- Private, encrypted, and versioned S3 bucket (`bookmarks.tf`) to store the break-glass switch-role page
- Lambda function (`lambda.tf`) that automatically generates and maintains an HTML page listing all Control Tower-managed accounts for quick role-switching
- Dual Lambda trigger mechanisms:
  - EventBridge rule for Control Tower account lifecycle events (CreateManagedAccount, UpdateManagedAccount)
  - Periodic schedule (default: weekly) to detect account suspensions and status changes
- Comprehensive alerting and monitoring (`monitoring.tf`):
  - SNS topic with email subscription for all break-glass user activity
  - Three-layer EventBridge-based detection:
    - Console sign-in events
    - Cross-account role assumption (AssumeRole)
    - Mutating (write) API operations, with automatic exclusion of read-only operations and KMS crypto operations
- Conditional CloudTrail trail creation when Control Tower centralized logging is disabled
- Support for customizable target role name (defaults to `AWSControlTowerExecution`)
- Support for custom refresh schedule expression
- Tags support for resource organization and compliance

### Changed

- N/A (initial release)

### Fixed

- N/A (initial release)

### Removed

- N/A (initial release)


## [1.0.0] - 2026-07-03

### Added

- Initial release of `iam/break-glass-access` module
- Break-glass IAM user in Control Tower management account with console-only access, no access keys
- MFA-enforced assume-role capability to switch into `AWSControlTowerExecution` across all CT-managed accounts
- Self-service password change on first login; initial password stored securely in SSM Parameter Store
- Private, encrypted, versioned S3 bucket (`bookmarks`) holding rendered break-glass switch-role page
- Lambda function (`break-glass-refresh`) that enumerates Control Tower-managed accounts and renders bookmarks HTML
- EventBridge triggers for Lambda refresh:
  - Control Tower account lifecycle events (CreateManagedAccount, UpdateManagedAccount)
  - Periodic schedule (weekly, configurable) to pick up account suspensions
- Detective alerting via SNS email notifications on any break-glass user activity:
  - Console sign-in events
  - Cross-account role assumption (AssumeRole calls)
  - Mutating (write) API operations
- Conditional CloudTrail trail creation when Control Tower centralized logging is disabled
- All resources deployed exclusively in `us-east-1` (where global console events land)
- Support for provider alias `aws.org-management` to deploy into CT management account
- Full documentation in `main.tf` and design rationale in `BREAK_GLASS.md`

### Configuration

- Terraform >= 1.5.0
- AWS provider >= 6.0.0
- Archive provider >= 2.0.0
- Random provider >= 3.0.0
