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

variable "approved_ranges" {
  description = <<-EOT
    Optional map of name => { region, cidrs, split } approved for AWS. When set,
    regional_pools and approved_cidrs are derived from it and the rest of
    top_level_cidr is reserved. environment_pools then act as templates for the
    VPC size rules of "production", "non-production" and "shared-services".
      split = true (default): pools "<name>-production" and "<name>-non-production"
                              (each CIDR in halves)
      split = false:          one shared-services pool "<name>" (each CIDR whole, /18 VPCs)
    Append only: the first CIDR is the primary CIDR of the entry's pools.
  EOT
  type = map(object({
    region = string
    cidrs  = list(string)
    split  = optional(bool, true)
  }))
  default  = {}
  nullable = false
  validation {
    condition     = alltrue([for name in keys(var.approved_ranges) : can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", name))])
    error_message = "approved_ranges names must be lowercase letters, digits and hyphens (e.g. workload-1)."
  }
  validation {
    condition     = alltrue([for name, v in var.approved_ranges : can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]$", v.region))])
    error_message = "Every approved_ranges region must be an AWS region name (e.g. eu-west-1)."
  }
  validation {
    condition     = alltrue([for r, v in var.approved_ranges : length(v.cidrs) > 0])
    error_message = "Every approved_ranges entry needs at least one CIDR."
  }
  validation {
    condition = alltrue(flatten([
      for r, v in var.approved_ranges : [
        for c in v.cidrs : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", c)) && can(cidrhost(c, 0))
      ]
    ]))
    error_message = "Every approved_ranges CIDR must be a valid IPv4 CIDR (e.g. 10.100.0.0/15)."
  }
  validation {
    condition = alltrue(flatten([
      for r, v in var.approved_ranges : [for c in v.cidrs : try(cidrsubnet(c, 0, 0) == c, false)]
    ]))
    error_message = "Every approved_ranges CIDR must use its network address (e.g. 10.100.0.0/15, not 10.101.0.0/15)."
  }
  validation {
    condition = alltrue(flatten([
      for r, v in var.approved_ranges : [for c in v.cidrs : try(tonumber(split("/", c)[1]) <= 16, false)]
    ]))
    error_message = "Every approved_ranges CIDR must be /16 or larger."
  }
  validation {
    condition     = length(distinct(flatten([for r, v in var.approved_ranges : v.cidrs]))) == length(flatten([for r, v in var.approved_ranges : v.cidrs]))
    error_message = "approved_ranges must not contain the same CIDR twice."
  }
}

variable "pool_sharing" {
  description = <<-EOT
    Map of environment => { org_units = [OU name paths], accounts = [account IDs] }
    that pools of that environment are shared with via RAM when
    share_with_organization = true. OUs are name paths from the organization root
    (up to 3 levels), resolved in the management account. Empty (default): each
    pool uses its own share_with_* values, or the whole organization if none.
    When set, every pool's environment needs an entry.
  EOT
  type = map(object({
    org_units = optional(list(string), [])
    accounts  = optional(list(string), [])
  }))
  default  = {}
  nullable = false
  validation {
    condition     = alltrue([for env, s in var.pool_sharing : length(s.org_units) + length(s.accounts) > 0])
    error_message = "Every pool_sharing entry needs at least one org unit or account."
  }
  validation {
    condition = alltrue(flatten([
      for env, s in var.pool_sharing : [for p in s.org_units : can(regex("^[^/]+(/[^/]+){0,2}$", p))]
    ]))
    error_message = "Each org_units entry must be an OU name path from the root with 1 to 3 levels, e.g. \"Workloads/NonProd\" (no leading or trailing slash)."
  }
  validation {
    condition = alltrue(flatten([
      for env, s in var.pool_sharing : [for a in s.accounts : can(regex("^[0-9]{12}$", a))]
    ]))
    error_message = "Each accounts entry must be a 12-digit AWS account ID."
  }
}

variable "vpc_requests" {
  description = "VPCs that will allocate from the pools (name => pool key and optional netmask). Only used to validate sizes against shared-services pools."
  type = map(object({
    pool_key       = string
    netmask_length = optional(number)
  }))
  default  = {}
  nullable = false
}

variable "regional_pools" {
  description = <<-EOT
    Map of regional pools to create under the top-level pool.
    Key is a logical name (e.g. "eu-central-1"), value defines the region and CIDR.
    Each regional pool is subdivided into environment pools.
    Ignored when approved_ranges is set.
  EOT
  type = map(object({
    region           = string
    cidr             = string
    additional_cidrs = optional(list(string), [])
  }))

  validation {
    condition = alltrue([
      for k, v in var.regional_pools : can(cidrhost(v.cidr, 0))
    ])
    error_message = "Each regional_pool cidr must be a valid CIDR block."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.regional_pools : [for c in v.additional_cidrs : try(cidrsubnet(c, 0, 0) == c, false)]
    ]))
    error_message = "Each regional_pool additional_cidrs entry must be a valid CIDR block written with its network address (e.g. 10.101.0.0/16, not 10.101.5.0/16)."
  }

  validation {
    condition = alltrue([
      for k, v in var.regional_pools : length(distinct(concat([v.cidr], v.additional_cidrs))) == length(v.additional_cidrs) + 1
    ])
    error_message = "A regional pool must not list the same CIDR twice (cidr and additional_cidrs must all be different)."
  }
}

variable "environment_pools" {
  description = <<-EOT
    Map of environment pools to create under each regional pool.
    Key is a logical name (e.g. "production"), value defines the CIDR and parent regional pool key.
    These are the pools from which VPCs actually allocate CIDRs.
    With approved_ranges, they are templates for the VPC size rules (see there).
  EOT
  type = map(object({
    regional_pool_key                 = string
    cidr                              = string
    additional_cidrs                  = optional(list(string), [])
    environment                       = optional(string) # "environment" tag value; defaults to the pool key
    share_with_accounts               = optional(list(string), [])
    share_with_org_unit_arns          = optional(list(string), [])
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

  validation {
    condition = alltrue(flatten([
      for k, v in var.environment_pools : [for c in v.additional_cidrs : try(cidrsubnet(c, 0, 0) == c, false)]
    ]))
    error_message = "Each environment_pool additional_cidrs entry must be a valid CIDR block written with its network address (e.g. 10.101.0.0/18)."
  }

  validation {
    condition = alltrue([
      for k, v in var.environment_pools : length(distinct(concat([v.cidr], v.additional_cidrs))) == length(v.additional_cidrs) + 1
    ])
    error_message = "An environment pool must not list the same CIDR twice (cidr and additional_cidrs must all be different)."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.environment_pools : [for a in v.share_with_accounts : can(regex("^[0-9]{12}$", a))]
    ]))
    error_message = "Each share_with_accounts entry must be a 12-digit AWS account ID."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.environment_pools : [
        for o in v.share_with_org_unit_arns : can(regex("^arn:aws[a-z-]*:organizations::[0-9]{12}:ou/o-[a-z0-9]{10,32}/ou-[a-z0-9]{4,32}-[a-z0-9]{8,32}$", o))
      ]
    ]))
    error_message = "Each share_with_org_unit_arns entry must be an OU ARN (arn:aws:organizations::<account>:ou/o-xxxx/ou-xxxx-xxxxxxxx)."
  }
}

variable "approved_cidrs" {
  description = <<-EOT
    Ranges approved for use in AWS ("approved ranges only" mode).
    Empty (default): nothing is reserved, behavior is unchanged.
    Non-empty: every reservation_netmask_length block of top_level_cidr that is
    outside these ranges is reserved with a custom allocation, so AWS can only
    use the approved ranges. Requirements (validated):
      - IPv4, written with the network address (10.100.0.0/15, not 10.101.0.0/15)
      - inside top_level_cidr, no overlaps, no duplicates
      - prefix equal to or shorter than reservation_netmask_length (e.g. /16 or larger)
      - every regional pool CIDR must be inside an approved range
    To release more space later, add the new range here and to a regional
    pool's additional_cidrs.
  EOT
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition = alltrue([
      for c in var.approved_cidrs : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", c)) && can(cidrhost(c, 0))
    ])
    error_message = "Each approved_cidrs entry must be a valid IPv4 CIDR block (e.g. 10.100.0.0/15)."
  }

  validation {
    condition = alltrue([
      for c in var.approved_cidrs : !can(cidrhost(c, 0)) || try(cidrsubnet(c, 0, 0) == c, false)
    ])
    error_message = "Each approved_cidrs entry must use its network address (e.g. 10.100.0.0/15, not 10.101.0.0/15)."
  }

  validation {
    condition     = length(distinct(var.approved_cidrs)) == length(var.approved_cidrs)
    error_message = "approved_cidrs must not contain duplicates."
  }
}

variable "reservation_netmask_length" {
  description = <<-EOT
    Size of the reservation blocks used when approved_cidrs is set. The
    top-level CIDR is split into blocks of this size and every block outside
    the approved ranges is reserved. Approved ranges must be this size or
    larger. Default /16: a /8 top level gives 256 blocks.
  EOT
  type        = number
  default     = 16
  nullable    = false

  validation {
    condition     = floor(var.reservation_netmask_length) == var.reservation_netmask_length && var.reservation_netmask_length >= 8 && var.reservation_netmask_length <= 24
    error_message = "reservation_netmask_length must be an integer between 8 and 24."
  }
}

variable "reservation_description" {
  description = "Description set on every reservation allocation (shown in the IPAM console)."
  type        = string
  default     = "Reserved: not approved for AWS use (on-premises or unassigned)"
  nullable    = false
}

variable "share_with_organization" {
  description = <<-EOT
    Enable organization-wide IPAM. When true:
      - Registers this account as IPAM delegated administrator (org-wide visibility)
      - Shares each environment pool via RAM (accounts can allocate CIDRs):
          * with its share_with_accounts / share_with_org_unit_arns, if set
          * with the whole organization, otherwise
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
