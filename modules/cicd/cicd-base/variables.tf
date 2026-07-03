# ==============================================================================
# CI/CD Module — Variables
#
# This module supports two deployment types:
#   - "hub"   → deployed in the central CICD account (OIDC provider, service roles)
#   - "spoke" → deployed in workload accounts (cross-account deployment roles)
#
# The default deployer role is hardcoded:
#   Name:   cicd-deployer
#   Policy: AdministratorAccess
# This is an architectural constant — not configurable.
# ==============================================================================

variable "deployment_type" {
  description = "Whether this module is deployed in the central CICD account ('hub') or a workload account ('spoke')."
  type        = string
  validation {
    condition     = contains(["hub", "spoke"], var.deployment_type)
    error_message = "deployment_type must be 'hub' or 'spoke'."
  }
}

# --- Hub-mode variables (CICD account) ---

variable "github_oidc_roles" {
  description = <<-EOT
    Map of GitHub OIDC roles to create (hub mode only). Each role is scoped to
    specific repositories via subject_filter and granted sts:AssumeRole on
    workload deployment roles.

    Example:
      github_oidc_roles = {
        "github-infra-deployer" = {
          subject_filter = "repo:your-org/your-infra-repo:ref:refs/heads/main"
          policy_arns    = []
        }
      }
  EOT
  type = map(object({
    subject_filter = string
    policy_arns    = optional(list(string), [])
  }))
  default = {}
}

# --- Spoke-mode variables (workload accounts) ---

variable "cicd_account_id" {
  description = "AWS account ID of the central CICD account (spoke mode only). The deployment roles trust this account."
  type        = string
  default     = ""
}

variable "custom_deployment_roles" {
  description = <<-EOT
    Additional deployment roles with restricted permissions (spoke mode only).

    Example:
      custom_deployment_roles = {
        "app-deployer" = {
          policy_arns          = ["arn:aws:iam::aws:policy/AWSLambda_FullAccess"]
          inline_policy_json   = null
          permissions_boundary = null
        }
      }
  EOT
  type = map(object({
    policy_arns          = list(string)
    inline_policy_json   = optional(string)
    permissions_boundary = optional(string)
  }))
  default = {}
}

# --- Common ---

variable "tags" {
  description = "Tags to apply to all resources. Passed in from the root module."
  type        = map(string)
}
