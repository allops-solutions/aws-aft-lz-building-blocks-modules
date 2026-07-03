variable "ct_management_account_id" {
  description = "The Control Tower / Organizations management account ID. All break-glass resources are created here."
  type        = string

  validation {
    condition     = can(regex("^\\d{12}$", var.ct_management_account_id))
    error_message = "Account ID must be a 12-digit number."
  }
}

variable "break_glass_user_name" {
  description = "Name of the single break-glass IAM user created in the management account."
  type        = string
  default     = "break-glass-user"
}

variable "notification_email" {
  description = <<-EOT
    Email address subscribed to the break-glass usage SNS topic. This is intentionally
    the same mailbox as the organization root user (e.g. aws-root@example.com) so
    that break-glass activity is visible to the same closely-held distribution list.
    The subscription must be confirmed once by clicking the link in the confirmation email.
  EOT
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.notification_email))
    error_message = "notification_email must be a valid email address."
  }
}

variable "target_role_name" {
  description = <<-EOT
    The role the break-glass user switches into within each Control Tower-managed account.
    AWSControlTowerExecution exists in every CT-enrolled account, grants AdministratorAccess,
    and trusts the management account. Do not change unless your landing zone uses a different
    execution role.
  EOT
  type        = string
  default     = "AWSControlTowerExecution"
}

variable "refresh_schedule_expression" {
  description = "EventBridge schedule for the periodic bookmarks refresh (covers account suspensions, for which there is no event trigger). Defaults to weekly."
  type        = string
  default     = "rate(7 days)"
}

variable "bookmarks_object_key" {
  description = "S3 object key for the rendered break-glass bookmarks HTML page."
  type        = string
  default     = "breakglass.html"
}

variable "enable_centralized_logging" {
  description = <<-EOT
    Whether Control Tower centralized logging (organization CloudTrail trail) is enabled.
    When true, the CT org trail provides EventBridge delivery — no extra trail is created.
    When false, this module creates a minimal multi-region CloudTrail trail in the management
    account to ensure EventBridge can receive sign-in events for alerting.
  EOT
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources. Passed in from the root module — do not set defaults here."
  type        = map(string)
}
