variable "ct_home_region" {
  description = "Control Tower home region."
  type        = string
}

variable "aft_management_account_id" {
  description = "The AWS account ID of the AFT management account where the Step Function lives."
  type        = string
}

variable "github_username" {
  description = "GitHub organization or username that owns the AFT repos. Only used when VCS is GitHub."
  type        = string
  default     = ""
}

variable "customer_name" {
  description = "Customer/project name prefix for AFT repo names."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default = {
    "product"    = "aft"
    "created-by" = "AFT"
  }
}
