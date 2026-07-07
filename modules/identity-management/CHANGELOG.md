# Changelog

## [v1.0] - 2026-07-07

### Added

- Initial release of the identity-management module.
- Permission set management with support for AWS managed policies and inline policies.
- Flexible assignment system supporting both bulk group assignments and individual one-off grants.
- OU-level targeting with automatic expansion to member accounts.
- Protected account filtering to prevent assignments to sensitive accounts (e.g., management account, partner customer-access accounts).
- Automatic deduplication of overlapping assignments (same user, permission set, and account via different paths).
- Identity Store user lookup and validation.
- Two module outputs: `permission_sets` (map of ARNs) and `assignment_count` (total assignments created).


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
