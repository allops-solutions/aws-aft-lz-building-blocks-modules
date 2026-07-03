# ==============================================================================
# VPC IPAM Module — Variables
# ==============================================================================

variable "ipam_description" {
  description = "Description for the IPAM instance."
  type        = string
  default     = "Organization VPC IPAM"
}

variable "operating_regions" {
  description = "AWS regions where IPAM manages IP addresses. Must include the home region."
  type        = list(string)

  validation {
    condition     = length(var.operating_regions) > 0
    error_message = "At least one operating region must be specified."
  }
}

variable "top_level_cidr" {
  description = "Top-level CIDR block for the organization pool (e.g. 10.0.0.0/8)."
  type        = string

  validation {
    condition     = can(cidrhost(var.top_level_cidr, 0))
    error_message = "top_level_cidr must be a valid CIDR block."
  }
}

variable "regional_pools" {
  description = <<-EOT
    Map of regional pools to create under the top-level pool.
    Key is a logical name (e.g. "eu-central-1"), value defines the region and CIDR.
    Each regional pool is subdivided into environment pools.
  EOT
  type = map(object({
    region = string
    cidr   = string
  }))

  validation {
    condition = alltrue([
      for k, v in var.regional_pools : can(cidrhost(v.cidr, 0))
    ])
    error_message = "Each regional_pool cidr must be a valid CIDR block."
  }
}

variable "environment_pools" {
  description = <<-EOT
    Map of environment pools to create under each regional pool.
    Key is a logical name (e.g. "production"), value defines the CIDR and parent regional pool key.
    These are the pools from which VPCs actually allocate CIDRs.
  EOT
  type = map(object({
    regional_pool_key                 = string
    cidr                              = string
    allocation_default_netmask_length = optional(number, 22)
    allocation_min_netmask_length     = optional(number, 16)
    allocation_max_netmask_length     = optional(number, 28)
  }))

  validation {
    condition = alltrue([
      for k, v in var.environment_pools : can(cidrhost(v.cidr, 0))
    ])
    error_message = "Each environment_pool cidr must be a valid CIDR block."
  }
}

variable "share_with_organization" {
  description = <<-EOT
    Enable organization-wide IPAM. When true:
      - Registers this account as IPAM delegated administrator (org-wide visibility)
      - Shares environment pools with the organization via RAM (accounts can allocate CIDRs)
  EOT
  type        = bool
  default     = false
}

variable "organization_arn" {
  description = "ARN of the AWS Organization. Required when share_with_organization = true."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all IPAM resources."
  type        = map(string)
  default     = {}
}
