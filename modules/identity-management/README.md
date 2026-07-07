# Identity Management Module

Manages AWS IAM Identity Center (SSO) permission sets and user-to-account assignments for AWS Organizations.

This module separates three independent concerns to support clean, scalable access management:

1. **Permission sets** — Define what permission sets exist (policies, session duration).
2. **Groups** — Bulk assignment of a permission set to multiple users across OUs.
3. **Individual assignments** — One-off grants for specific users to specific OUs or accounts.

A permission set is defined once and can be referenced by any number of groups and individual assignments.

## Usage

```hcl
module "identity_management" {
  source = "./modules/identity-management"

  permission_sets = {
    AdministratorAccess = {
      description      = "Full AWS administrator access"
      session_duration = "PT4H"
      managed_policies = ["arn:aws:iam::aws:policy/AdministratorAccess"]
      inline_policy    = ""
    }
    ReadOnlyAccess = {
      description      = "Read-only access to all resources"
      session_duration = "PT8H"
      managed_policies = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
      inline_policy    = ""
    }
    PowerUserAccess = {
      description      = "Power user with custom inline policy"
      session_duration = "PT8H"
      managed_policies = ["arn:aws:iam::aws:policy/PowerUserAccess"]
      inline_policy    = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Deny"
            Action = "iam:*"
            Resource = "*"
          }
        ]
      })
    }
  }

  groups = {
    administrators = {
      permission_set = "AdministratorAccess"
      users = [
        "alice@example.com",
        "bob@example.com"
      ]
      account_ous = ["Production", "Development"]
      account_ids = []
      all_accounts = false
    }
    auditors = {
      permission_set = "ReadOnlyAccess"
      users = [
        "auditor1@example.com",
        "auditor2@example.com"
      ]
      account_ous = []
      account_ids = []
      all_accounts = true
    }
  }

  individual_assignments = [
    {
      user           = "contractor@example.com"
      permission_set = "PowerUserAccess"
      account_ous    = ["Development"]
      account_ids    = []
    },
    {
      user           = "security-lead@example.com"
      permission_set = "ReadOnlyAccess"
      account_ous    = []
      account_ids    = ["123456789012"]
    }
  ]

  protected_account_ids = ["987654321098"]  # Partner customer-access account
}
```

## How Targeting Works

Identity Center has no OU-level inheritance — every assignment targets a specific account. OU names in this module are a Terraform convenience:

- The module expands each OU name into its member account IDs.
- One assignment resource is created per expanded account.
- This makes `protected_account_ids` a complete guarantee: if an account is in the protected list, no assignment object exists for it.

### Account Selection

For each group or individual assignment, you can combine:

- **`account_ous`** — OU names, expanded to all active accounts within each OU.
- **`account_ids`** — Specific account IDs to include.
- **`all_accounts`** — (Groups only) Target every active account in the organization. Defaults to `false` and should remain `false` in normal use.

The module automatically deduplicates overlapping targets. If a user lands on the same account with the same permission set via multiple groups or a group plus an individual assignment, exactly one assignment is created.

### Protected Accounts

The **management account** is always excluded (Control Tower places a resource policy blocking delegated admin access). Additionally, any account IDs in `protected_account_ids` are excluded from all assignments, even if they would otherwise match an OU, explicit account ID, or `all_accounts`.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | ~> 5.79 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| permission_sets | Permission set definitions. The map key is the permission set name as it appears in Identity Center (no prefix). Defines policies only — not who gets it or where. | `map(object({ description = string, session_duration = optional(string, "PT8H"), managed_policies = optional(list(string), []), inline_policy = optional(string, "") }))` | n/a | yes |
| groups | Artificial groups. Each group assigns ONE permission set to a list of users across the given OUs and/or accounts. Used to emulate Identity Center groups when unavailable with Google Workspace as the identity source. | `map(object({ permission_set = string, users = optional(list(string), []), account_ous = optional(list(string), []), account_ids = optional(list(string), []), all_accounts = optional(bool, false) }))` | `{}` | no |
| individual_assignments | One-off assignments: a single user that needs a specific permission set on a specific OU or account. | `list(object({ user = string, permission_set = string, account_ous = optional(list(string), []), account_ids = optional(list(string), []) }))` | `[]` | no |
| protected_account_ids | Account IDs that must NEVER receive an assignment from this module instance, on top of the always-protected management account. Filtering happens on the final, fully-expanded target list, so an account listed here is excluded even if matched via an OU, explicit account_id, or all_accounts. Used to ensure sensitive accounts (e.g., partner customer-access account) are reachable only through a dedicated module instance. | `list(string)` | `[]` | no |

### Input Field Details

**Permission Set Fields:**
- `description` — Human-readable description of the permission set.
- `session_duration` — ISO 8601 duration format (e.g., `PT4H`, `PT8H`, `PT12H`). Default is `PT8H`.
- `managed_policies` — List of AWS managed policy ARNs to attach. Default is empty list.
- `inline_policy` — Inline policy as a JSON string. Set to `""` for no inline policy. Default is `""`.

**Group Fields:**
- `permission_set` — Key of a permission set defined in `permission_sets`.
- `users` — List of user emails (Identity Center UserName) to assign.
- `account_ous` — OU names; each OU is expanded to all active accounts within it.
- `account_ids` — Specific account IDs to include.
- `all_accounts` — If `true`, targets every active account in the organization. Defaults to `false`.

**Individual Assignment Fields:**
- `user` — User email (Identity Center UserName).
- `permission_set` — Key of a permission set defined in `permission_sets`.
- `account_ous` — OU names; each OU is expanded to all active accounts within it.
- `account_ids` — Specific account IDs to include.

## Outputs

| Name | Description |
|------|-------------|
| permission_sets | Map of permission set name to ARN created by this module instance. |
| assignment_count | Number of account assignments created by this module instance. |

## How It Works

1. **Permission Set Definition** — Permission sets are created from `var.permission_sets`. Each key becomes the permission set name in Identity Center. Managed policies and inline policies are attached as specified.

2. **OU Resolution** — All referenced OU names are resolved to their member account IDs by querying AWS Organizations. Only active accounts are included.

3. **Target Expansion** — Groups and individual assignments are expanded into concrete account lists:
   - OU names are replaced with their member accounts.
   - Duplicates are removed.
   - Protected accounts are filtered out.

4. **User Lookup** — All referenced user emails are looked up in the Identity Store to obtain user IDs.

5. **Assignment Deduplication** — All group assignments and individual assignments are flattened into a single map keyed by `{permission_set}/{email}/{account_id}`. If a user lands on the same account with the same permission set via multiple paths, exactly one assignment is created.

6. **Account Assignment Creation** — One `aws_ssoadmin_account_assignment` resource is created per entry in the deduplicated assignment map.

## Notes

- Permission set names are taken verbatim from the map key in `permission_sets`. No prefix is added.
- Group and individual assignment definitions are independent; they can be managed in separate Terraform modules or from the same module by providing empty defaults.
- The module automatically excludes the management account from all assignments (protected by Control Tower).
- Account filtering is final and complete: if an account is protected, no assignment resource is created for it, guaranteeing no access path exists.
