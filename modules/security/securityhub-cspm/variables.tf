variable "delegated_admin_account_id" {
  description = "Account ID to register as the Security Hub CSPM delegated administrator for the organization."
  type        = string
}

variable "region" {
  description = "Primary AWS Region where Security Hub CSPM is configured (home Region). Used to construct region-specific standard ARNs and as the finding aggregation target."
  type        = string
}

variable "secondary_region" {
  description = "Secondary AWS Region where Security Hub CSPM is enabled. Findings from this Region are aggregated into the home Region."
  type        = string
  default     = ""
}

variable "additional_regions" {
  description = "Additional AWS Regions where Security Hub CSPM is enabled, beyond the primary and secondary Regions."
  type        = list(string)
  default     = []
}

# ------------------------------------------------------------------------------
# Standards — individual toggles, all enabled by default.
# ------------------------------------------------------------------------------

variable "foundational_security_enabled" {
  description = "Enable the AWS Foundational Security Best Practices v1.0.0 standard."
  type        = bool
  default     = true
}

variable "cis_benchmark_enabled" {
  description = "Enable the CIS AWS Foundations Benchmark v5.0.0 standard."
  type        = bool
  default     = true
}

variable "ai_security_enabled" {
  description = "Enable the AI Security Best Practices v1.0.0 standard."
  type        = bool
  default     = true
}

variable "resource_tagging_enabled" {
  description = "Enable the AWS Resource Tagging Standard v1.0.0."
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Controls configuration
# ------------------------------------------------------------------------------

variable "disabled_control_identifiers" {
  description = "Security control identifiers to disable in the configuration policy. All other controls remain enabled."
  type        = list(string)
  default     = []
}

# ------------------------------------------------------------------------------
# Account exclusions
# ------------------------------------------------------------------------------

variable "excluded_account_ids" {
  description = "Account IDs to exclude from the Security Hub CSPM configuration policy association."
  type        = list(string)
  default     = []
}

# ------------------------------------------------------------------------------
# Finding notifications (EventBridge -> Lambda formatter -> SNS -> email)
#
# The pipeline is always created and subscribes this account's own root email.
# Severity is the only knob; everything else is derived.
# ------------------------------------------------------------------------------

variable "notification_min_severity" {
  description = "Lowest finding severity label that triggers a notification. Findings at this level and above are delivered. One of LOW, MEDIUM, HIGH, or CRITICAL."
  type        = string
  default     = "MEDIUM"

  validation {
    condition     = contains(["LOW", "MEDIUM", "HIGH", "CRITICAL"], upper(var.notification_min_severity))
    error_message = "notification_min_severity must be one of LOW, MEDIUM, HIGH, or CRITICAL."
  }
}

# ------------------------------------------------------------------------------
# Tags
# ------------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources. Passed in from the root module."
  type        = map(string)
}
