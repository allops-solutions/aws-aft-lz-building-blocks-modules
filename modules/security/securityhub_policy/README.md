# security/securityhub_policy

Terraform module for creating and managing AWS Security Hub configuration policies and associating them with organizational targets. This module provides a declarative way to enable or disable Security Hub standards, controls, and override individual control parameters across your AWS Organization.

## Usage

```hcl
module "securityhub_policy" {
  source = "path/to/modules/security/securityhub_policy"

  name            = "org-default-securityhub-policy"
  description     = "Default Security Hub policy for the organization"
  service_enabled = true

  enabled_standard_arns = [
    "arn:aws:securityhub:eu-central-1::standards/aws-foundational-security-best-practices/v/1.0.0",
    "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0"
  ]

  disabled_control_identifiers = [
    "CloudTrail.2",
    "SSM.1"
  ]

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
          int        = 90
        }
      ]
    }
  ]

  association_targets = [
    "r-abcd",                # Organization root
    "ou-abcd-12345678"       # Organizational Unit
  ]
}
```

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.5.0 |
| AWS Provider (`hashicorp/aws`) | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `name` | Name of the Security Hub custom policy. | `string` | — | yes |
| `description` | Description of the Security Hub custom policy. | `string` | — | yes |
| `service_enabled` | Enable Security Hub custom policy for service. | `bool` | — | yes |
| `association_targets` | Security Hub custom policy association targets (e.g root, OU Id, or account Id). | `list(string)` | `[]` | no |
| `enabled_standard_arns` | List of standard ARNs to enable for Security Hub custom policy. | `list(string)` | `null` | no |
| `disabled_control_identifiers` | A list of security controls that are disabled in the configuration policy. Security Hub enables all other controls (including newly released controls) other than the listed controls. Conflicts with `enabled_control_identifiers`. | `list(string)` | `[]` | no |
| `enabled_control_identifiers` | A list of security controls that are enabled in the configuration policy. Security Hub disables all other controls (including newly released controls) other than the listed controls. Conflicts with `disabled_control_identifiers`. | `list(string)` | `null` | no |
| `security_control_custom_parameter` | A list of control parameter customizations that are included in a configuration policy. Supports parameter types: `bool`, `double`, `enum`, `enum_list`, `int`, `int_list`, `string`, `string_list`. See [AWS Security Hub Controls Reference](https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-controls-reference.html). | `list(object({...}))` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| — | This module does not currently export any outputs. |

## Resources

| Name | Type |
|------|------|
| `aws_securityhub_configuration_policy.policy` | resource |
| `aws_securityhub_configuration_policy_association.association` | resource |

## Notes

- The `disabled_control_identifiers` and `enabled_control_identifiers` variables are mutually exclusive. Use one approach (allow-list or deny-list) but not both.
- The `security_control_custom_parameter` variable accepts all AWS Security Hub parameter value types. Only set the field matching the parameter's expected type (e.g., set `int` for integer parameters, `bool` for boolean parameters).
- Policy associations use `depends_on` to ensure the policy is fully created before association attempts.
