# ==============================================================================
# VPC Module — Variables
# ==============================================================================

variable "vpc_name" {
  description = "Name for the VPC. It is used in resource names and tags."
  type        = string

  validation {
    condition     = trimspace(var.vpc_name) != ""
    error_message = "vpc_name must not be empty."
  }
}

variable "ipam_pool_id" {
  description = "ID of the IPv4 IPAM pool from which this VPC allocates its CIDR."
  type        = string

  validation {
    condition     = trimspace(var.ipam_pool_id) != ""
    error_message = "ipam_pool_id must not be empty."
  }
}

variable "cidr_netmask_length" {
  description = "Netmask length for the VPC CIDR allocated from IPAM. Must be an integer from /16 through /24. If omitted, IPAM uses the pool's allocation_default_netmask_length."
  type        = number
  default     = null

  validation {
    condition     = var.cidr_netmask_length == null || (floor(var.cidr_netmask_length) == var.cidr_netmask_length && var.cidr_netmask_length >= 16 && var.cidr_netmask_length <= 24)
    error_message = "cidr_netmask_length must be an integer between 16 and 24."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to use for each subnet tier. Must be an integer from 2 through 4 and cannot exceed the number of available AZs in the selected region."
  type        = number
  default     = 2

  validation {
    condition     = floor(var.az_count) == var.az_count && var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be an integer between 2 and 4."
  }
}

variable "enable_egress" {
  description = "Whether to create an Internet Gateway and NAT Gateway routing for outbound IPv4 internet access. When false, the VPC has no Internet Gateway, NAT Gateways, or default internet routes."
  type        = bool
  default     = true
}

variable "nat_high_availability" {
  description = "NAT Gateway topology. Set true for one NAT Gateway per AZ or false for one NAT Gateway in the first AZ. If omitted, the value is true only when the IPAM pool environment tag is exactly production; otherwise it is false."
  type        = bool
  default     = null
}

# --- RAM Sharing (centrally-managed topology) ---

variable "share_with_accounts" {
  description = "Account IDs to share subnets with via RAM. Leave empty if the VPC owner is also the consumer."
  type        = list(string)
  default     = []
}

variable "share_with_org_unit_arns" {
  description = "OU ARNs to share subnets with via RAM. Leave empty if the VPC owner is also the consumer."
  type        = list(string)
  default     = []
}

# --- DNS ---

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC."
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC."
  type        = bool
  default     = true
}

# --- Tags ---

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
