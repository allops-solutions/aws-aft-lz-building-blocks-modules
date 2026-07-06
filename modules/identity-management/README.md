# AWS IAM Identity Center Permission Sets & Identity Management

Terraform module to manage AWS IAM Identity Center (SSO) permission sets and user-to-account assignments.

## Overview

This module separates three concerns to allow access to scale cleanly:

1. **Permission sets** — Define what permission sets exist (policies only)
2. **Groups** — Bulk assignments: one permission set to many users across organizational units
3. **Individual assignments** — One-off grants: a single user to specific accounts

A permission set is defined once and can be referenced by any number of groups and individual assignments.

## Key Design Decisions

- **No OU-level inheritance**: Identity Center has no native OU-level inheritance. This module implements a Terraform-side convenience: OU names are automatically expanded into their member account IDs, and one assignment per account is created.
- **Protected account filtering**: Assignments to protected accounts (management account and any caller-specified accounts) are completely prevented at the Terraform level—no assignment object is created.
- **Automatic deduplication**: When a user reaches the same account with the same permission set via multiple paths (two groups or a group + individual assignment), the assignments collapse into exactly one resource.
- **Identity Store lookup**: User emails are resolved to Identity Store user IDs automatically; no manual ID lookups required.

## Usage

```hcl
module "identity_management" {
  source = "./modules/identity-management"

  permission_sets = {
    AdministratorAccess = {
      description      = "Full administrative access"
      session_duration = "PT8H"
      managed_policies = ["arn:aws:iam::aws:policy/AdministratorAccess"]
      inline_policy    = ""
    }
    ReadOnlyAccess = {
      description      = "Read-only access"
      session_duration = "PT4H"
      managed_policies = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
      inline_policy    = ""
    }
    CustomPowerUser = {
      description      = "Custom power user with inline policy"
      session_duration = "PT12H"
      managed_policies = ["arn:aws:iam::aws:policy/PowerUserAccess"]
      inline_policy    = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect   = "Allow"
            Action   = "s3:*"
            Resource = "*"
          }
        ]
      })
    }
  }

  groups = {
    administrators = {
      permission_set = "AdministratorAccess"
      users          = ["admin1@example.com", "admin2@example.com"]
      account_ous    = ["Production", "Staging"]
      account_ids    = []
      all_accounts   = false
    }
    readonly_team = {
      permission_set = "ReadOnlyAccess"
      users          = ["auditor1@example.com", "auditor2@example.com"]
      account_ous    = ["Production"]
      account_ids    = ["123456789012"]
      all_accounts   = false
    }
  }

  individual_assignments = [
    {
      user           = "contractor@example.com"
      permission_set = "ReadOnlyAccess"
      account_ous    = []
      account_ids    = ["123456789012"]
    },
    {
      user           = "devops@example.com"
      permission_set = "CustomPowerUser"
      account_ous    = ["Development"]
      account_ids    = []
    }
  ]

  protected_account_ids = ["999999999999"]  # Customer-access account, never assign here
}
```

## Requirements

| Requirement | Version |
|---|---|
| Terraform | >= 1.0 |
| AWS Provider | ~> 5.79 |

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `permission_sets` | Permission set definitions. The map key is the permission set name as it appears in Identity Center (no prefix). Defines policies only — not who gets it or where. | `map(object({ description = string, session_duration = optional(string, "PT8H"), managed_policies = optional(list(string), []), inline_policy = optional(string, "") }))` | N/A | yes |
| `groups` | Artificial groups. Each group assigns one permission set to a list of users across the given OUs and/or accounts. Used to emulate Identity Center groups (unavailable with Google Workspace as the identity source). | `map(object({ permission_set = string, users = optional(list(string), []), account_ous = optional(list(string), []), account_ids = optional(list(string), []), all_accounts = optional(bool, false) }))` | `{}` | no |
| `individual_assignments` | One-off assignments for cases a group does not cover: a single user that needs a specific permission set on a specific OU or account. | `list(object({ user = string, permission_set = string, account_ous = optional(list(string), []), account_ids = optional(list(string), []) }))` | `[]` | no |
| `protected_account_ids` | Account IDs that must NEVER receive an assignment from this module instance, on top of the always-protected management account. Filtering happens on the final, fully-expanded target list, so an account listed here is excluded even if it was matched via an OU, an explicit account_id, or all_accounts. Used to ensure the partner customer-access account is reachable only through the dedicated customer-access module instance. | `list(string)` | `[]` | no |

### Input Field Reference

#### `permission_sets` fields

- `description` (string, required) — Human-readable description of the permission set
- `session_duration` (string, optional, default "PT8H") — ISO 8601 duration for session timeout (e.g., "PT4H", "PT8H", "PT12H")
- `managed_policies` (list(string), optional, default []) — AWS managed policy ARNs to attach
- `inline_policy` (string, optional, default "") — Inline policy JSON string (empty string means no inline policy)

#### `groups` fields

- `permission_set` (string, required) — Key of a permission set defined in `var.permission_sets`
- `users` (list(string), optional, default []) — User emails (Identity Center UserName) to assign
- `account_ous` (list(string), optional, default []) — OU names; automatically expands to all active accounts in each OU
- `account_ids` (list(string), optional, default []) — Specific account IDs to include
- `all_accounts` (bool, optional, default false) — Escape hatch: if true, targets every active account. Should remain false in normal use.

#### `individual_assignments` fields

- `user` (string, required) — User email (Identity Center UserName)
- `permission_set` (string, required) — Key of a permission set defined in `var.permission_sets`
- `account_ous` (list(string), optional, default []) — OU names; automatically expands to all active accounts in each OU
- `account_ids` (list(string), optional, default []) — Specific account IDs to include

## Outputs

| Name | Description |
|---|---|
| `permission_sets` | Map of permission set name => ARN created by this module instance. Useful for cross-stack references. |
| `assignment_count` | Number of account assignments created by this module instance. Provides visibility into the scope of access granted. |

## Behavior & Guarantees

### Protected Accounts

The management account is always protected and excluded from all assignments (enforced by Control Tower). Any account listed in `protected_account_ids` is also excluded.

Protection is complete: if an account is protected, no assignment object is created by this module, ensuring no access path exists to it.

### OU Expansion

OUs are expanded to their active member accounts at plan time. Only accounts with `ACTIVE` status are included.

### Deduplication

When a user reaches the same account with the same permission set via multiple paths (e.g., two groups or a group + individual assignment), the assignments are automatically deduplicated—exactly one `aws_ssoadmin_account_assignment` resource is created.

## Limitations & Considerations

- This module manages assignments only via user identities. Machine identities and service account assignments are not supported.
- Identity Center group-level assignments are not supported; use the `groups` input to emulate group-based access.
- The `all_accounts` field in groups is an escape hatch for special cases. Do not use it for normal deployments; protected account filtering is the recommended security boundary.
- Session duration must be specified in ISO 8601 format and must be between 15 minutes (PT15M) and 12 hours (PT12H).

## Maintenance & Troubleshooting

### Common Changes

**Add a user to a group**: Edit the `users` list for the group in the `groups` input.

**Create a new permission set**: Add it to `permission_sets`, then reference it from a group or individual assignment.

**Grant one-time access**: Add an entry to `individual_assignments`.

### Plan Output

Run `terraform plan` to preview all permission sets and assignments that will be created:

```bash
terraform plan
```

The plan output shows all `aws_ssoadmin_permission_set`, `aws_ssoadmin_account_assignment`, and policy attachment resources.

### Debugging Assignment Count Mismatches

If the assignment count is unexpected, check:

1. **Protected accounts**: Verify that no assignments target protected accounts (management + `protected_account_ids`).
2. **OU expansion**: Confirm that OU names match exactly and OUs contain active accounts.
3. **Deduplication**: Verify that no user is assigned the same permission set to the same account via multiple groups.
