# =============================================================================
# layered-terraform-pipeline -- inputs
# =============================================================================

variable "workload" {
  description = "Workload name. Used for the pipeline name, the state key prefix and the SSM watermark prefix."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}$", var.workload))
    error_message = "workload must be lowercase letters, digits and dashes."
  }
}

variable "layers" {
  description = "Layers in dependency order. The first entry is the base layer: whenever it applies, the whole run is forced sequential."
  type        = list(string)
  default     = ["network", "databases", "services"]

  validation {
    condition     = length(var.layers) >= 2
    error_message = "layers must contain at least a base layer and one dependent layer."
  }
}

# --- environments -----------------------------------------------------------

variable "dev_environment" {
  description = "The first environment. All environments except the last use direct apply with no plan or approval. Only the last environment (production) gets per-layer sequential plan -> approve -> apply."
  type = object({
    name       = optional(string, "dev")
    account_id = string
    region     = optional(string)
  })
}

variable "prod_environment" {
  description = "The last environment. Gets per-layer sequential plan -> approve -> apply. Each layer is planned, manually approved, and applied before the next layer begins."
  type = object({
    name       = optional(string, "prod")
    account_id = string
    region     = optional(string)
  })
}

variable "intermediate_environments" {
  description = "Environments inserted in order between dev and prod. Each uses direct apply (no plan or approval) just like dev."
  type = list(object({
    name       = string
    account_id = string
    region     = optional(string)
  }))
  default = []

  validation {
    condition     = length(var.intermediate_environments) <= 5
    error_message = "At most 5 intermediate environments. CodePipeline allows 50 stages per pipeline."
  }
}

# --- source -----------------------------------------------------------------

variable "source_provider" {
  description = "Where the code lives. 'github' uses a CodeConnections connection; 'codecommit' uses an EventBridge rule for change detection."
  type        = string
  default     = "github"

  validation {
    condition     = contains(["github", "codecommit"], var.source_provider)
    error_message = "source_provider must be 'github' or 'codecommit'."
  }
}

variable "connection_arn" {
  description = "CodeConnections connection ARN. Required when source_provider is 'github'."
  type        = string
  default     = null
}

variable "repository_id" {
  description = "Repository identifier: 'org/repo' for github, the repository name for codecommit."
  type        = string
}

variable "branch" {
  description = "The single source-of-truth branch that drives the pipeline."
  type        = string
  default     = "main"
}

# --- identity ---------------------------------------------------------------

variable "deployer_role_name" {
  description = "Name of the role assumed in each target account. 'cicd-deployer' is the architectural constant created by cicd-base in spoke mode."
  type        = string
  default     = "cicd-deployer"
}

variable "create_deployment_roles" {
  description = <<-EOT
    Create the deployer role in THIS account instead of assuming that it already
    exists in the target accounts.

    This is the self-contained configuration: pipeline, workload and state bucket
    all in one account. Every environment must point at the current account,
    because Terraform can only create the role where its provider is pointed.
  EOT
  type        = bool
  default     = false
}

variable "deployment_role_policy_arns" {
  description = "Policies attached to the deployer role when create_deployment_roles is true."
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}

# --- state and plans --------------------------------------------------------

variable "state_bucket_prefix" {
  description = "Prefix of the Terraform state bucket in each target account. The bucket is <prefix>-<account_id>."
  type        = string
  default     = "terraform-state"
}

variable "plan_prefix" {
  description = "Key prefix inside the state bucket where approved plans are stored."
  type        = string
  default     = "_plans"
}

variable "watermark_prefix" {
  description = "SSM Parameter Store prefix, in THIS account, for the last-applied commit per environment and layer."
  type        = string
  default     = "/pipeline"

  validation {
    condition     = startswith(var.watermark_prefix, "/") && !endswith(var.watermark_prefix, "/")
    error_message = "watermark_prefix must start with a slash and not end with one, e.g. /pipeline. It forms parameter names $${prefix}/<workload>/<env>/<layer>/last-applied-commit and the IAM ARNs are derived from it."
  }
}

# --- behaviour --------------------------------------------------------------

variable "enable_parallel_layers" {
  description = "For direct-apply environments, add a stage that applies the dependent layers in parallel when the base layer is untouched and no layer contract changed. The production environment always runs sequentially layer by layer."
  type        = bool
  default     = true
}

variable "enable_manual_approvals" {
  description = <<-EOT
    Whether the pipelines include manual approval actions.

    When false, every approval is removed from both pipelines and they run
    end-to-end: the inter-environment promotion approvals and the production
    per-layer approve stages disappear from the main pipeline, and the per-layer
    approve stages disappear from the rollback pipeline. Everything else -
    routing, plans, saved-plan applies, watermarks - is unchanged.

    The automatic source triggers are independent of this value. The GitHub
    trigger block and the CodeCommit EventBridge rule exist in every mode, so a
    push to the configured branch starts the pipeline even when a run flows
    straight through to the last environment. The rollback pipeline is always
    manual-only regardless of this value, because it has no trigger block and
    DetectChanges is always false.
  EOT
  type        = bool
  default     = true
}

variable "terraform_version" {
  description = "Terraform version installed by the buildspecs. Pin it: this is what actually runs against your infrastructure."
  type        = string
  default     = "1.15.3"
}

variable "buildspec_prefix" {
  description = "Directory in the source repository holding route.yml, plan.yml and apply.yml."
  type        = string
  default     = "buildspecs"
}

variable "build_timeout_minutes" {
  description = "Timeout for the plan and apply CodeBuild projects."
  type        = number
  default     = 60
}

variable "approval_sns_topic_arn" {
  description = "Optional SNS topic notified on manual approval actions."
  type        = string
  default     = null
}

# --- compute ----------------------------------------------------------------

variable "route_compute" {
  description = <<-EOT
    Compute for the routing step. Lambda compute starts in about a second and
    includes git and the AWS CLI, which is all the router needs.

    Lambda compute is not available in every Region. If yours is unsupported,
    switch to ARM_CONTAINER / BUILD_GENERAL1_SMALL with image
    aws/codebuild/amazonlinux2-aarch64-standard:4.0.
  EOT
  type = object({
    environment_type = optional(string, "ARM_LAMBDA_CONTAINER")
    compute_type     = optional(string, "BUILD_LAMBDA_1GB")
    image            = optional(string, "aws/codebuild/amazonlinux-aarch64-lambda-standard:python3.14")
  })
  default = {}
}

variable "terraform_compute" {
  description = "Compute for the plan and apply projects. Must not be Lambda compute: Terraform writes outside /tmp and can exceed the 15 minute Lambda ceiling."
  type = object({
    environment_type = optional(string, "ARM_CONTAINER")
    compute_type     = optional(string, "BUILD_GENERAL1_SMALL")
    image            = optional(string, "aws/codebuild/amazonlinux2-aarch64-standard:4.0")
  })
  default = {}

  validation {
    condition     = !can(regex("LAMBDA", var.terraform_compute.environment_type))
    error_message = "Lambda compute cannot run Terraform: it cannot write outside /tmp and is capped at 15 minutes."
  }
}

# --- artifacts --------------------------------------------------------------

variable "artifact_bucket_name" {
  description = "Existing CodePipeline artifact bucket. Leave null to have this module create one."
  type        = string
  default     = null
}

variable "artifact_retention_days" {
  description = "Days before pipeline artifacts expire. Only used for a bucket created by this module."
  type        = number
  default     = 90
}

variable "tags" {
  description = "Tags applied to everything this module creates."
  type        = map(string)
  default     = {}
}
