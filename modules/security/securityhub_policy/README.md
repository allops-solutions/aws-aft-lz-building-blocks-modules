# AWS Security Hub Policy Module

This Terraform module creates and manages AWS Security Hub configuration policies with support for custom security control parameters. It enables organizations to define centralized security baselines and apply them across AWS accounts, organizational units, or the organization root.

## Usage

```hcl
module "securityhub_policy" {
  source = "./modules/security/securityhub_policy"

  name        = "Organization Security Baseline"
  description = "Core security controls and standards for the organization"

  service_enabled       = true
  enabled_standard_arns = [
    "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
  ]

  disabled_control_identifiers = ["CIS.1.1"]
  
  security_control_custom_parameter = [
    {
      security_control_id = "IAM.7"
      parameters = [
        {
          name       = "RequireLowercaseCharacters"
          value_type = "CUSTOM"
          bool       = true
        },
        {
          name       = "MaxPasswordAge"
          value_type = "CUSTOM"
          int        = 60
        }
      ]
    }
  ]

  association_targets = [
    "r-1234",           # Root
    "ou-1234-abcdefgh", # Organizational Unit
    "123456789012"      # AWS Account ID
  ]
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
| name | Name of the Security Hub custom policy. | `string` | n/a | yes |
| description | Description of the Security Hub custom policy. | `string` | n/a | yes |
| service_enabled | Enable Security Hub custom policy for service. | `bool` | n/a | yes |
| association_targets | Security Hub custom policy association targets (e.g root, OU Id, or account Id). | `list(string)` | `[]` | no |
| enabled_standard_arns | List of standard ARNs to enable for Security Hub custom policy. | `list(string)` | `null` | no |
| disabled_control_identifiers | (Optional) A list of security controls that are disabled in the configuration policy. Security Hub enables all other controls (including newly released controls) other than the listed controls. Conflicts with enabled_control_identifiers. | `list(string)` | `[]` | no |
| enabled_control_identifiers | (Optional) A list of security controls that are enabled in the configuration policy. Security Hub disables all other controls (including newly released controls) other than the listed controls. Conflicts with disabled_control_identifiers. | `list(string)` | `null` | no |
| security_control_custom_parameter | (Optional) A list of control parameter customizations that are included in a configuration policy. Each entry specifies a security control ID and its custom parameters. Supported value types: `CUSTOM` or `DEFAULT`. Parameters support multiple value types: bool, double, enum, enum_list, int, int_list, string, string_list. See [AWS Security Hub Controls Reference](https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-controls-reference.html) for available controls and parameters. | `list(object({ security_control_id = string, parameters = list(object({ name = string, value_type = string, bool = optional(bool), double = optional(number), enum = optional(string), enum_list = optional(list(string)), int = optional(number), int_list = optional(list(number)), string = optional(string), string_list = optional(list(string)) })) }))` | `[]` | no |

## Outputs

This module does not produce any outputs. The created Security Hub configuration policy and its associations are managed as resources within the Terraform state.

## Notes

- **Control Conflicts**: `disabled_control_identifiers` and `enabled_control_identifiers` are mutually exclusive. Use one or the other, not both.
- **Default Controls**: When using `disabled_control_identifiers`, Security Hub automatically enables all other controls, including newly released ones.
- **Control Parameters**: Custom parameters are optional and control-specific. Refer to the AWS Security Hub Controls Reference documentation for valid parameters for each control.
- **Association Targets**: Targets can be the organization root (`r-*`), organizational units (`ou-*`), or individual AWS account IDs.
