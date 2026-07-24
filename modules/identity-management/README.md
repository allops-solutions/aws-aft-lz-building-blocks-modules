# identity-management

Terraform module for managing AWS IAM Identity Center (SSO) permission sets and user-to-account assignments.

This module separates permission set definitions (policies) from assignment logic, supporting both bulk assignment via artificial groups and one-off individual grants. It automatically resolves organizational units (OUs) to member accounts, eliminating manual account list maintenance.

## Usage

```hcl
module "identity_management" {
  # Pin to a specific version using the ref parameter
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/identity-management?ref=identity-management-v1.0"

  permission_sets = {
    AdministratorAccess = {
      description      = "Full administrator access"
      session_duration = "PT8H"
      managed_policies = ["arn:aws:iam::aws:policy/AdministratorAccess"]
      inline_policy    = ""
    }
    ReadOnlyAccess = {
      description      = "Read-only access"
      session_duration = "PT8H"
      managed_policies = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
      inline_policy    = ""
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
    auditors = {
      permission_set = "ReadOnlyAccess"
      users          = ["auditor@example.com"]
      account_ous    = ["Production", "Staging", "Development"]
      account_ids    = []
      all_accounts   = false
    }
  }

  individual_assignments = [
    {
      user           = "breakglass@example.com"
      permission_set = "AdministratorAccess"
      account_ous    = []
      account_ids    = ["123456789012"]
    }
  ]

  protected_account_ids = []
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | ~> 5.79 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| permission_sets | Permission set definitions. The map key is the permission set name as it appears in Identity Center (no prefix). Defines policies only — not who gets it or where. **Fields:** `description` (string) – Human-readable description; `session_duration` (string, optional) – ISO 8601 duration (e.g. "PT8H"). Default "PT8H"; `managed_policies` (list of strings, optional) – AWS managed policy ARNs to attach. Default []; `inline_policy` (string, optional) – Inline policy JSON string. Default "" (none). | `map(object({description = string, session_duration = optional(string, "PT8H"), managed_policies = optional(list(string), []), inline_policy = optional(string, "")}))` | n/a | yes |
| groups | Artificial groups. Each group assigns ONE permission set to a list of users across the given OUs and/or accounts. This is the bulk-assignment path used to emulate Identity Center groups (which are unavailable with Google Workspace as the identity source). **Fields:** `permission_set` (string) – Key of a permission set defined in `permission_sets`; `users` (list of strings, optional) – User emails (Identity Center UserName) to assign. Default []; `account_ous` (list of strings, optional) – OU names; expands to all active accounts in each OU. Default []; `account_ids` (list of strings, optional) – Specific account IDs to include. Default []; `all_accounts` (bool, optional) – Escape hatch. If true, targets every active account. Defaults to false and should stay false in normal use. | `map(object({permission_set = string, users = optional(list(string), []), account_ous = optional(list(string), []), account_ids = optional(list(string), []), all_accounts = optional(bool, false)}))` | `{}` | no |
| individual_assignments | One-off assignments for cases a group does not cover: a single user that needs a specific permission set on a specific OU or account. **Fields:** `user` (string) – User email (Identity Center UserName); `permission_set` (string) – Key of a permission set defined in `permission_sets`; `account_ous` (list of strings, optional) – OU names; expands to all active accounts in each OU. Default []; `account_ids` (list of strings, optional) – Specific account IDs to include. Default []. | `list(object({user = string, permission_set = string, account_ous = optional(list(string), []), account_ids = optional(list(string), [])}))` | `[]` | no |
| protected_account_ids | Account IDs that must NEVER receive an assignment from this module instance, on top of the always-protected management account. Filtering happens on the final, fully-expanded target list, so an account listed here is excluded even if it was matched via an OU, an explicit account_id, or all_accounts. Used to ensure the partner customer-access account is reachable only through the dedicated customer-access module instance. Default is an empty list. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| permission_sets | Map of permission set name → ARN created by this module instance. |
| assignment_count | Number of account assignments created by this module instance. |

## Architecture

The module operates in three distinct phases:

1. **Permission Set Definitions** – Define what permission sets exist with their policies (managed and/or inline) and session duration. Defined once, referenced by groups and individual assignments.

2. **Bulk Assignment (Groups)** – Assign a single permission set to multiple users across specified OUs and/or accounts. Each group targets a specific `permission_set` and a list of `users`, with targets specified via `account_ous` (OU names) and/or `account_ids`.

3. **Individual Assignments** – One-off grants for a single user to specific OUs and/or accounts. Used when a group does not provide the exact combination needed.

### OU Resolution

Identity Center has no OU-level inheritance. The module expands each referenced OU to its active member accounts and creates one assignment per account. This means:

- Specify OUs by name (e.g., "Production", "Staging").
- The module queries AWS Organizations to resolve each OU to its member account IDs.
- One assignment is created per account per user per permission set.
- The management account is always excluded automatically (protected by Control Tower).

### Deduplication

If a user receives the same permission set on the same account via multiple paths (e.g., two groups, or a group and an individual assignment), the module deduplicates and creates exactly one assignment resource. The deduplication key is `permission_set / email / account_id`.

### Protected Accounts

The `protected_account_ids` variable ensures certain accounts never receive assignments from this module instance. Filtering is applied to the final, fully-expanded target list, so an account listed here is excluded even if it was matched via an OU, explicit account ID, or `all_accounts = true`. This is primarily used to protect the partner customer-access account when multiple module instances are deployed.

## Data Sources

The module queries the following AWS data sources at apply time:

- `aws_ssoadmin_instances` – Retrieves the Identity Center instance ARN and Identity Store ID.
- `aws_organizations_organization` – Retrieves the organization and management account ID.
- `aws_organizations_organizational_units` – Retrieves root-level OUs.
- `aws_organizations_organizational_unit_descendant_accounts` – Expands each referenced OU to its member accounts.
- `aws_identitystore_user` – Looks up each user by email (UserName attribute) to retrieve their Identity Store user ID.

## Notes

- **No org-wide defaults** – Nothing is assigned organization-wide unless a group explicitly sets `all_accounts = true` (which defaults to false and should remain false in normal use).
- **Management account always protected** – The management account is automatically excluded from all assignments, regardless of OU or account targeting. This is enforced by Control Tower.
- **Permission set naming** – Permission set names are taken verbatim from the `permission_sets` map key. No prefix is added. A key of `AdministratorAccess` creates a permission set named exactly `AdministratorAccess`.
- **Identity source compatibility** – This module is designed to work with Google Workspace and other identity sources that do not support Identity Center native groups. It emulates groups via `groups` variable.

## Example: Add a User to a Group

Edit the `groups` variable and add the user email to the relevant user list:

```hcl
groups = {
  administrators = {
    permission_set = "AdministratorAccess"
    users = [
      "admin1@example.com",
      "admin2@example.com",  # ← add here
    ]
    account_ous = ["Production"]
    account_ids = []
  }
}
```

## Example: Add a New Permission Set

1. Define the permission set in `permission_sets`:

```hcl
permission_sets = {
  PowerUserAccess = {
    description      = "Power user access"
    session_duration = "PT8H"
    managed_policies = ["arn:aws:iam::aws:policy/PowerUserAccess"]
    inline_policy    = ""
  }
}
```

2. Reference it from a group or individual assignment:

```hcl
groups = {
  power_users = {
    permission_set = "PowerUserAccess"
    users          = ["user1@example.com"]
    account_ous    = ["Production"]
    account_ids    = []
  }
}
```

## Example: Grant One User Access to One Account

Use `individual_assignments` for a one-off grant:

```hcl
individual_assignments = [
  {
    user           = "auditor@example.com"
    permission_set = "ReadOnlyAccess"
    account_ous    = []
    account_ids    = ["123456789012"]
  }
]
```

## License

This module is part of the aws-aft-lz-building-blocks-modules project.
