# Changelog

## [v1.0] - 2026-07-03

### Added
- Initial release of the Security Hub Policy module
- `aws_securityhub_configuration_policy` resource for creating custom Security Hub configuration policies
- `aws_securityhub_configuration_policy_association` resource for associating policies with targets (root, organizational units, or accounts)
- Support for configuring service enablement and enabled standards via ARNs
- Support for managing security controls through `disabled_control_identifiers` and `enabled_control_identifiers`
- Support for custom security control parameters with multiple value types (bool, double, enum, enum_list, int, int_list, string, string_list)
- Flexible parameter customization through `security_control_custom_parameter` variable with dynamic configuration
- Terraform >= 1.5.0 and AWS provider >= 5.0 support
