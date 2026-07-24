variable "delegated_admin_account_id" {
  description = "Account ID to register as the Amazon Inspector delegated administrator for the organization."
  type        = string
}

variable "primary_region" {
  description = "Primary AWS Region where Amazon Inspector is enabled."
  type        = string
}

variable "enable_secondary_region" {
  description = "Whether to also enable Amazon Inspector in the secondary Region."
  type        = bool
  default     = false
}

variable "secondary_region" {
  description = "Secondary AWS Region where Amazon Inspector is enabled. Only used when enable_secondary_region is true."
  type        = string
  default     = ""
}

variable "additional_regions" {
  description = "Additional AWS Regions, beyond the primary and secondary Region, where Amazon Inspector is enabled."
  type        = list(string)
  default     = []
}

variable "ec2_scanning_enabled" {
  description = "Enable Amazon Inspector EC2 instance scanning across the included organizational units and Regions."
  type        = bool
  default     = false
}

variable "ecr_scanning_enabled" {
  description = "Enable Amazon Inspector ECR container image scanning across the included organizational units and Regions."
  type        = bool
  default     = false
}

variable "lambda_standard_scanning_enabled" {
  description = "Enable Amazon Inspector Lambda function (package vulnerability) scanning across the included organizational units and Regions."
  type        = bool
  default     = false
}

variable "lambda_code_scanning_enabled" {
  description = "Enable Amazon Inspector Lambda function code scanning across the included organizational units and Regions."
  type        = bool
  default     = false
}

variable "code_repository_scanning_enabled" {
  description = "Enable Amazon Inspector code repository scanning across the included organizational units and Regions."
  type        = bool
  default     = false
}

variable "organizational_units" {
  description = <<-EOF
    Organizational units where Amazon Inspector scanning is enabled. Each entry's
    `path` is the list of OU names from the top level down to the target OU
    (e.g. `["Workloads"]` for a top-level OU, or `["Workloads", "NonProd"]` for
    an OU nested one level below it). Paths up to 3 levels deep are supported.
  EOF
  type = list(object({
    path = list(string)
  }))
  default = [
    { path = ["Workloads", "Prod"] },
    { path = ["Workloads", "NonProd"] },
  ]
}

variable "excluded_account_ids" {
  description = "Individual account IDs to explicitly exclude from Amazon Inspector scanning, even when they belong to an included organizational unit."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources. Passed in from the root module."
  type        = map(string)
}

variable "ecr_rescan_window" {
  description = "Duration window for Amazon Inspector ECR continuous re-scanning. Controls how long images are re-scanned after being pushed or after last use. Valid values: DAYS_3, DAYS_14, DAYS_30, DAYS_60, DAYS_90, DAYS_180, LIFETIME."
  type        = string
  default     = "DAYS_3"
}
