# Changelog

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
