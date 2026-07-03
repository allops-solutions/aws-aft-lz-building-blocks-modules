# ==============================================================================
# VPC Module — Variables
# ==============================================================================

variable "vpc_name" {
  description = "Name for the VPC (used in tags and resource names)."
  type        = string
}

variable "ipam_pool_id" {
  description = "IPAM pool ID from which this VPC allocates its CIDR."
  type        = string
}

variable "cidr_netmask_length" {
  description = "Netmask length for VPC CIDR allocation (16–24). If omitted, IPAM uses the pool's allocation_default_netmask_length."
  type        = number
  default     = null

  validation {
    condition     = var.cidr_netmask_length == null || (var.cidr_netmask_length >= 16 && var.cidr_netmask_length <= 24)
    error_message = "cidr_netmask_length must be between 16 and 24."
  }
}

variable "az_count" {
  description = "Number of Availability Zones (2–4)."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4."
  }
}

variable "enable_egress" {
  description = "Create Internet Gateway and NAT Gateway(s) for outbound internet access."
  type        = bool
  default     = true
}

variable "nat_high_availability" {
  description = "true = one NAT per AZ; false = single NAT in first AZ. If not set, defaults to true when vpc_name contains 'prod', false otherwise."
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
