# Changelog

## [v1.0] - 2026-07-06

### Added

- Initial release of the identity-management module for AWS IAM Identity Center (SSO)
- Permission set management with support for AWS managed policies and inline policies
- Artificial group support for bulk user-to-permission-set assignments across OUs and accounts
- Individual assignment support for one-off per-user grants
- OU-to-account expansion: OUs are automatically expanded to their member accounts for targeting
- Protected account filtering to prevent assignments to management and customer-access accounts
- Identity Store user lookup and resolution
- Automatic deduplication of overlapping assignments (same user, permission set, account)
- Two module outputs: permission set ARNs and assignment count for visibility
- AWS provider constraint: ~> 5.79
