variable "name" {
  description = "Name of the Security Hub custom policy."
  type        = string
}

variable "description" {
  description = "Description of the Security Hub custom policy."
  type        = string
}

variable "association_targets" {
  description = "Security Hub custom policy association targets (e.g root, OU Id, or account Id)."
  type        = list(string)
  default     = []
}

variable "service_enabled" {
  description = "Enable Security Hub custom policy for service."
  type        = bool
}

variable "enabled_standard_arns" {
  description = "List of standard ARNs to enable for Security Hub custom policy."
  type        = list(string)
  default     = null
}

variable "disabled_control_identifiers" {
  description = "(Optional) A list of security controls that are disabled in the configuration policy. Security Hub enables all other controls (including newly released controls) other than the listed controls. Conflicts with enabled_control_identifiers."
  type        = list(string)
  default     = []
}

variable "enabled_control_identifiers" {
  description = "(Optional) A list of security controls that are enabled in the configuration policy. Security Hub disables all other controls (including newly released controls) other than the listed controls. Conflicts with disabled_control_identifiers."
  type        = list(string)
  default     = null
}

variable "security_control_custom_parameter" {
  description = <<-EOF
  (Optional) A list of control parameter customizations that are included in a configuration policy.
  See https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-controls-reference.html

  Example:
  ```
  security_control_custom_parameter = [
    {
      security_control_id = "IAM.7"
      parameters = [
        {
          name       = "RequireLowercaseCharacters"
          value_type = "CUSTOM"
          bool       = false
        },
        {
          name       = "MaxPasswordAge"
          value_type = "CUSTOM"
          int        = 60
        }
      ]
    }
  ]
  ```
  EOF
  type = list(object({
    security_control_id = string
    parameters = list(object({
      name        = string
      value_type  = string #CUSTOM or DEFAULT
      bool        = optional(bool)
      double      = optional(number)
      enum        = optional(string)
      enum_list   = optional(list(string))
      int         = optional(number)
      int_list    = optional(list(number))
      string      = optional(string)
      string_list = optional(list(string))
    }))
  }))
  default = []
}
