# Changelog

## [v2.0] - 2026-07-01

### Added

- `main.tf` — Core resource definitions for `aws_securityhub_configuration_policy` and `aws_securityhub_configuration_policy_association`.
- `variables.tf` — Full set of input variables: `name`, `description`, `association_targets`, `service_enabled`, `enabled_standard_arns`, `disabled_control_identifiers`, `enabled_control_identifiers`, and `security_control_custom_parameter`.
- `versions.tf` — Terraform and provider version constraints (Terraform >= 1.5.0, AWS provider >= 5.0).
- Support for all security control custom parameter types: `bool`, `double`, `enum`, `enum_list`, `int`, `int_list`, `string`, and `string_list`.
- Dynamic policy association with multiple targets (organization root, OU IDs, or account IDs) via `association_targets` variable.

### Removed

- `releases/v1.0.md` — Previous release notes file removed from the module source tree.
