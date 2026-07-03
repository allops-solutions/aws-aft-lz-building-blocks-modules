# AWS GuardDuty Module

Terraform module for managing AWS GuardDuty organization configuration and features at scale. This module enables centralized GuardDuty management across AWS organizations, allowing automatic member enrollment and selective enablement of detection features and data sources.

## Usage

```hcl
module "guardduty" {
  source = "./modules/security/guardduty"

  # Enable GuardDuty for all existing and new organization members
  auto_enable_organization_members = "ALL"

  # Enable specific data sources for threat detection
  datasources = {
    s3_logs            = true
    kubernetes         = true
    malware_protection = true
  }

  # Configure which detection features are enabled across the organization
  organization_features = {
    S3_DATA_EVENTS         = "NEW"
    EKS_AUDIT_LOGS         = "NEW"
    EBS_MALWARE_PROTECTION = "NEW"
    RDS_LOGIN_EVENTS       = "NEW"
    LAMBDA_NETWORK_LOGS    = "NEW"
    RUNTIME_MONITORING     = "NEW"
  }

  # Configure additional settings for runtime monitoring
  additional_configuration = {
    EKS_ADDON_MANAGEMENT         = "NEW"
    ECS_FARGATE_AGENT_MANAGEMENT = "NEW"
    EC2_AGENT_MANAGEMENT         = "NEW"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| auto_enable_organization_members | Define whether to enable GuardDuty Organization Configuration or not. Valid values: ALL (enable for all current and future members), NEW (enable only for new members), NONE (disable organization configuration). | `string` | `"ALL"` | no |
| datasources | Define the collected datasources configuration. Enables GuardDuty to monitor specific data sources for threat detection. Valid keys: s3_logs, kubernetes, malware_protection. | `map(bool)` | `{ s3_logs = false, kubernetes = false, malware_protection = false }` | no |
| organization_features | GuardDuty features that will be enabled across the organization. Valid feature names: S3_DATA_EVENTS, EKS_AUDIT_LOGS, EBS_MALWARE_PROTECTION, RDS_LOGIN_EVENTS, LAMBDA_NETWORK_LOGS, EKS_RUNTIME_MONITORING, RUNTIME_MONITORING. Valid values: NEW, ALL, NONE. **Note:** Specifying both RUNTIME_MONITORING (preferred) and EKS_RUNTIME_MONITORING will cause an error per [AWS GuardDuty API documentation](https://docs.aws.amazon.com/guardduty/latest/APIReference/API_OrganizationFeatureConfiguration.html). | `map(string)` | `{ S3_DATA_EVENTS = "NONE", EKS_AUDIT_LOGS = "NONE", EBS_MALWARE_PROTECTION = "NONE", RDS_LOGIN_EVENTS = "NONE", LAMBDA_NETWORK_LOGS = "NONE", RUNTIME_MONITORING = "NONE" }` | no |
| additional_configuration | Additional configuration for RUNTIME_MONITORING and EKS_RUNTIME_MONITORING features. Valid names: EKS_ADDON_MANAGEMENT (for RUNTIME_MONITORING or EKS_RUNTIME_MONITORING), ECS_FARGATE_AGENT_MANAGEMENT (for RUNTIME_MONITORING only), EC2_AGENT_MANAGEMENT (for RUNTIME_MONITORING only). Valid values: NEW, ALL, NONE. See [AWS GuardDuty API documentation](https://docs.aws.amazon.com/guardduty/latest/APIReference/API_OrganizationAdditionalConfiguration.html). | `map(string)` | `{ EKS_ADDON_MANAGEMENT = "NONE", ECS_FARGATE_AGENT_MANAGEMENT = "NONE", EC2_AGENT_MANAGEMENT = "NONE" }` | no |

## Outputs

| Name | Description |
|------|-------------|
| detector_id | The ID of the GuardDuty detector |

## Notes

- This module requires an AWS organization with GuardDuty already enabled at the organization level. Ensure the delegated administrator account or primary organization account has GuardDuty enabled before applying this module.
- The `auto_enable_organization_members` variable controls the scope of member account enrollment. Use "ALL" to enable for all members, "NEW" for future members only, or "NONE" to disable organization-wide configuration.
- Runtime monitoring features (RUNTIME_MONITORING and EKS_RUNTIME_MONITORING) cannot be enabled simultaneously per AWS API constraints.
- Enabling additional configuration options requires the corresponding runtime monitoring feature to be enabled.
- All input variables include validation to ensure only valid feature names and values are provided.
