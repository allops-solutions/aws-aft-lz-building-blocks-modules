variable "ct_home_region" {
  description = "Control Tower home region — used to scope log/resource ARNs."
  type        = string
}

variable "ct_management_account_id" {
  description = "The Control Tower / Organizations management account ID. CodeBuild assumes a role here to run Terraform."
  type        = string
}

variable "aft_management_account_id" {
  description = "The AFT management account ID. Pipeline resources live here."
  type        = string
}

variable "github_username" {
  description = "GitHub organization or username that owns the landing zone repo."
  type        = string
}

variable "customer_name" {
  description = "Customer/project name prefix for the landing zone repo."
  type        = string
}

variable "enable_pipeline_trigger" {
  description = "If true, the pipeline automatically triggers on pushes to the main branch. If false, the pipeline is created but must be triggered manually."
  type        = bool
  default     = true
}

variable "enable_manual_approval" {
  description = "If true, the pipeline runs Source -> Plan -> Manual Approval -> Apply. If false, it runs Source -> Apply (combined plan+apply)."
  type        = bool
  default     = true
}

variable "tf_state_bucket" {
  description = "S3 bucket holding the Terraform state for this repo. Used to grant the cross-account role access to state."
  type        = string
  default     = ""
}

variable "tf_state_key" {
  description = "S3 key (path) of the Terraform state file inside tf_state_bucket."
  type        = string
  default     = ""
}

variable "ct_management_role_name" {
  description = "Name of the IAM role in the CT management account that CodeBuild assumes to run Terraform."
  type        = string
  default     = "landing-zone-pipeline-execution"
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default = {
    "product"    = "landing-zone"
    "created-by" = "AFT"
  }
}
