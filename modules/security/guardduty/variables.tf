variable "delegated_admin_account_id" {
  description = "Account ID to register as the Amazon GuardDuty delegated administrator for the organization."
  type        = string
}

variable "s3_protection_enabled" {
  description = "Enable GuardDuty S3 Protection across enrolled accounts. Detects data exfiltration and destruction attempts in S3 buckets."
  type        = bool
  default     = false
}

variable "eks_audit_logs_enabled" {
  description = "Enable GuardDuty EKS Audit Log Monitoring across enrolled accounts. Analyzes Kubernetes audit logs for suspicious control plane activity."
  type        = bool
  default     = false
}

variable "ebs_malware_protection_enabled" {
  description = "Enable GuardDuty Malware Protection for EC2 across enrolled accounts. Scans EBS volumes for malware when threats are detected."
  type        = bool
  default     = false
}

variable "rds_protection_enabled" {
  description = "Enable GuardDuty RDS Protection across enrolled accounts. Detects anomalous login activity on Aurora and RDS databases."
  type        = bool
  default     = false
}

variable "lambda_protection_enabled" {
  description = "Enable GuardDuty Lambda Protection across enrolled accounts. Monitors Lambda network activity for threats like cryptomining."
  type        = bool
  default     = false
}

variable "runtime_monitoring_enabled" {
  description = "Enable GuardDuty Runtime Monitoring across enrolled accounts. Monitors OS-level events on EKS, EC2, and ECS/Fargate workloads."
  type        = bool
  default     = false
}

variable "ai_protection_enabled" {
  description = "Enable GuardDuty AI Protection across enrolled accounts. Detects threats to AI workloads built on Amazon Bedrock, AgentCore, and SageMaker AI."
  type        = bool
  default     = false
}

variable "runtime_monitoring_configuration" {
  description = <<-EOF
    Sub-feature configuration for Runtime Monitoring. Controls automated agent
    management for EKS, ECS Fargate, and EC2 workloads. Only effective when
    runtime_monitoring_enabled is true.

    All sub-features default to ALL (enabled) when Runtime Monitoring is active.
    Set individual sub-features to NONE to disable them.

    Example:
    ```
      runtime_monitoring_configuration = {
        EKS_ADDON_MANAGEMENT         = "ALL"
        ECS_FARGATE_AGENT_MANAGEMENT = "ALL"
        EC2_AGENT_MANAGEMENT         = "NONE"
      }
    ```
  EOF
  type        = map(string)
  default = {
    EKS_ADDON_MANAGEMENT         = "ALL"
    ECS_FARGATE_AGENT_MANAGEMENT = "ALL"
    EC2_AGENT_MANAGEMENT         = "ALL"
  }
  validation {
    condition = alltrue([
      for k, v in var.runtime_monitoring_configuration :
      contains(["EKS_ADDON_MANAGEMENT", "ECS_FARGATE_AGENT_MANAGEMENT", "EC2_AGENT_MANAGEMENT"], k) &&
      contains(["ALL", "NEW", "NONE"], v)
    ])
    error_message = "Valid keys: EKS_ADDON_MANAGEMENT, ECS_FARGATE_AGENT_MANAGEMENT, EC2_AGENT_MANAGEMENT. Valid values: ALL, NEW, NONE."
  }
}

variable "excluded_account_ids" {
  description = "Account IDs to exclude from GuardDuty enrollment. These accounts will not have GuardDuty enabled even if they are discovered in the AFT metadata table."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources. Passed in from the root module."
  type        = map(string)
}
