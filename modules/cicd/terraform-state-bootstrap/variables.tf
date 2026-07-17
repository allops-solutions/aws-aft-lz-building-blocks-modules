# ==============================================================================
# Terraform State Bootstrap Module — Variables
# ==============================================================================

variable "bucket_name_prefix" {
  description = "Prefix for the Terraform state bucket name. The current AWS account ID is appended automatically."
  type        = string
  default     = "terraform-state"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.bucket_name_prefix)) && length(var.bucket_name_prefix) <= 50
    error_message = "bucket_name_prefix must be a valid S3 bucket name prefix using lowercase letters, digits, dots, or hyphens, and must leave room for the appended account ID."
  }
}

variable "tags" {
  description = "Tags to apply to the Terraform state bucket resources."
  type        = map(string)
  default     = {}
}
