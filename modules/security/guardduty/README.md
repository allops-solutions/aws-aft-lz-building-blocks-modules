# security/guardduty

Terraform module for managing AWS GuardDuty organization-level configuration. It enables centralized control over GuardDuty protection features and datasources across all accounts in an AWS Organization from the delegated administrator account.

## Usage

```hcl
module "guardduty" {
  source = "./modules/security/guardduty"

  auto_enable_organization_members = "ALL"

  datasources = {
    s3_logs            = true
    kubernetes         = true
    malware_protection = true
  }

  organization_features = {
    S3_DATA_EVENTS         = "ALL"
    EKS_AUDIT_LOGS         = "ALL"
    EBS_MALWARE_PROTECTION = "ALL"
    RDS_LOGIN_EVENTS       = "NEW"
    LAMBDA_NETWORK_LOGS    = "NEW"
    RUNTIME_MONITORING     = "ALL"
  }

  additional_configuration = {
    EKS_ADDON_MANAGEMENT         = "ALL"
    ECS_FARGATE_AGENT_MANAGEMENT = "ALL"
    EC2_AGENT_MANAGEMENT         = "ALL"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.5.0 |
| AWS Provider (`hashicorp/aws`) | >= 5.0 |

## Prerequisites

- GuardDuty must already be enabled in the delegated administrator account (a detector must exist).
- The module must be applied from the GuardDuty delegated administrator account.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `auto_enable_organization_members` | Define whether to enable GuardDuty Organization Configuration or not. Valid values: `ALL`, `NEW`, `NONE`. | `string` | `"ALL"` | no |
| `datasources` | Map of datasource toggles. Valid keys: `s3_logs`, `kubernetes`, `malware_protection`. | `map(bool)` | `{ s3_logs = false, kubernetes = false, malware_protection = false }` | no |
| `organization_features` | GuardDuty features to enable at the organization level. Valid feature keys: `S3_DATA_EVENTS`, `EKS_AUDIT_LOGS`, `EBS_MALWARE_PROTECTION`, `RDS_LOGIN_EVENTS`, `LAMBDA_NETWORK_LOGS`, `EKS_RUNTIME_MONITORING`, `RUNTIME_MONITORING`. Valid values: `ALL`, `NEW`, `NONE`. Note: specifying both `RUNTIME_MONITORING` and `EKS_RUNTIME_MONITORING` will cause an error. | `map(string)` | `{ S3_DATA_EVENTS = "NONE", EKS_AUDIT_LOGS = "NONE", EBS_MALWARE_PROTECTION = "NONE", RDS_LOGIN_EVENTS = "NONE", LAMBDA_NETWORK_LOGS = "NONE", RUNTIME_MONITORING = "NONE" }` | no |
| `additional_configuration` | Additional configuration for `RUNTIME_MONITORING` and `EKS_RUNTIME_MONITORING` features. Valid keys: `EKS_ADDON_MANAGEMENT`, `ECS_FARGATE_AGENT_MANAGEMENT`, `EC2_AGENT_MANAGEMENT`. Valid values: `ALL`, `NEW`, `NONE`. | `map(string)` | `{ EKS_ADDON_MANAGEMENT = "NONE", ECS_FARGATE_AGENT_MANAGEMENT = "NONE", EC2_AGENT_MANAGEMENT = "NONE" }` | no |

## Outputs

This module does not define any outputs.

## Resources

| Name | Type |
|------|------|
| `aws_guardduty_organization_configuration.this` | resource |
| `aws_guardduty_organization_configuration_feature.this` | resource |
| `aws_guardduty_detector.current` | data source |

## Notes

- When `auto_enable_organization_members` is set to `"NONE"`, the `aws_guardduty_organization_configuration_feature` resources are skipped entirely.
- The `additional_configuration` block is only attached to features named `RUNTIME_MONITORING` or `EKS_RUNTIME_MONITORING`.
- Per AWS documentation, do not specify both `RUNTIME_MONITORING` and `EKS_RUNTIME_MONITORING` in `organization_features` simultaneously.
