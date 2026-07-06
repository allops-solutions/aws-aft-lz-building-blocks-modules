# ==============================================================================
# Module interface
#
# This module does three things, and they are intentionally decoupled:
#   1. permission_sets        -> WHAT permission sets exist (policies only)
#   2. groups                 -> bulk assignment: a permission set to many users
#                                across OUs/accounts ("artificial groups")
#   3. individual_assignments -> one-off: a single user to specific OUs/accounts
#
# A permission set is defined once and can be referenced by any number of
# groups and individual assignments. Nothing is assigned org-wide unless a
# group explicitly opts in via all_accounts (default false).
# ==============================================================================

variable "permission_sets" {
  description = <<-EOT
    Permission set definitions. The map key is the permission set name as it
    appears in Identity Center (no prefix). Defines policies only — not who
    gets it or where.

    Fields:
    - description:      Human-readable description
    - session_duration: ISO 8601 duration (e.g. "PT8H"). Default "PT8H".
    - managed_policies: AWS managed policy ARNs to attach. Default [].
    - inline_policy:    Inline policy JSON string. Default "" (none).
  EOT
  type = map(object({
    description      = string
    session_duration = optional(string, "PT8H")
    managed_policies = optional(list(string), [])
    inline_policy    = optional(string, "")
  }))
}

variable "groups" {
  description = <<-EOT
    Artificial groups. Each group assigns ONE permission set to a list of users
    across the given OUs and/or accounts. This is the bulk-assignment path used
    to emulate Identity Center groups (which are unavailable with Google
    Workspace as the identity source).

    Fields:
    - permission_set: Key of a permission set defined in var.permission_sets.
    - users:          User emails (Identity Center UserName) to assign.
    - account_ous:    OU names; expands to all active accounts in each OU.
    - account_ids:    Specific account IDs to include.
    - all_accounts:   Escape hatch. If true, targets every active account.
                      Defaults to false and should stay false in normal use.
  EOT
  type = map(object({
    permission_set = string
    users          = optional(list(string), [])
    account_ous    = optional(list(string), [])
    account_ids    = optional(list(string), [])
    all_accounts   = optional(bool, false)
  }))
  default = {}
}

variable "individual_assignments" {
  description = <<-EOT
    One-off assignments for cases a group does not cover: a single user that
    needs a specific permission set on a specific OU or account.

    Fields:
    - user:           User email (Identity Center UserName).
    - permission_set: Key of a permission set defined in var.permission_sets.
    - account_ous:    OU names; expands to all active accounts in each OU.
    - account_ids:    Specific account IDs to include.
  EOT
  type = list(object({
    user           = string
    permission_set = string
    account_ous    = optional(list(string), [])
    account_ids    = optional(list(string), [])
  }))
  default = []
}

variable "protected_account_ids" {
  description = <<-EOT
    Account IDs that must NEVER receive an assignment from this module
    instance, on top of the always-protected management account. Filtering
    happens on the final, fully-expanded target list, so an account listed here
    is excluded even if it was matched via an OU, an explicit account_id, or
    all_accounts. Used to ensure the partner customer-access account is
    reachable only through the dedicated customer-access module instance.

    Default is a dummy value that never matches a real account, making the
    protection a harmless no-op in customer deployments where the add-on is
    absent.
  EOT
  type        = list(string)
  default     = []
}
