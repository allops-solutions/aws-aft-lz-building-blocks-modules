variable "ct_home_region" {
  description = "AWS region where Control Tower is deployed."
  type        = string
}

variable "ct_baseline_version" {
  description = "Version of the AWSControlTowerBaseline to enable on OUs."
  type        = string
}

variable "enable_backup" {
  description = "Whether to enable BackupBaseline on each OU (requires AWSControlTowerBaseline first)."
  type        = bool
  default     = false
}

variable "organizational_units" {
  description = "Full OU map (same shape as root variable). Used to derive child OUs."
  type = map(object({
    name       = string
    parent_id  = optional(string)
    parent_key = optional(string)
  }))
}

variable "root_ous" {
  description = <<-EOT
    Map of already-created root-level OUs, keyed by the same logical keys used
    in var.organizational_units. Each value must expose at minimum { id, arn }.
    Passed from aws_organizations_organizational_unit.root in the root module.
  EOT
  type = map(object({
    id  = string
    arn = string
  }))
}
