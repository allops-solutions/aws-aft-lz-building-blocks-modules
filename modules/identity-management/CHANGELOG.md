# Changelog

# Changelog

## [v1.0] - 2026-07-24

### Added

- Initial release of the identity-management module for AWS IAM Identity Center (SSO) permission set and user-to-account assignment management.
- Permission set resource management with support for AWS managed policies and inline policies via `aws_ssoadmin_permission_set`, `aws_ssoadmin_managed_policy_attachment`, and `aws_ssoadmin_permission_set_inline_policy`.
- Group-based bulk assignment system: assign one permission set to multiple users across organizational units (OUs) and accounts using artificial groups.
- Individual assignment support for one-off, per-user grants to specific accounts or OUs.
- Automatic OU-to-account expansion: OUs are resolved to their member accounts with no manual account list maintenance required.
- Protected account filtering: management account automatically excluded; additional accounts can be protected from assignments via `protected_account_ids`.
- Identity Store user lookup via email (UserName attribute) with `aws_identitystore_user` data source.
- Deduplication of assignments: users receiving the same permission set on the same account via multiple paths (groups or individual assignments) result in a single assignment resource.
- Outputs: `permission_sets` map (name → ARN) and `assignment_count` for observability.
- AWS provider version constraint: ~> 5.79.
