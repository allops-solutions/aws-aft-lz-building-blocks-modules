# Changelog

## [v2.0] - 2026-07-01

### Added

- `data.tf` — Data source to look up the existing GuardDuty detector in the delegated administrator account (`aws_guardduty_detector.current`).
- `main.tf` — `aws_guardduty_organization_configuration` resource to manage organization-wide GuardDuty auto-enablement and datasource settings (S3 logs, Kubernetes audit logs, EBS malware protection).
- `main.tf` — `aws_guardduty_organization_configuration_feature` resource with `for_each` to independently configure each GuardDuty protection feature at the organization level.
- `main.tf` — Dynamic `additional_configuration` block for runtime monitoring features (EKS addon management, ECS Fargate agent management, EC2 agent management).
- `variables.tf` — `auto_enable_organization_members` variable with validation (`ALL`, `NEW`, `NONE`).
- `variables.tf` — `datasources` variable (`map(bool)`) to toggle S3 logs, Kubernetes audit logs, and malware protection.
- `variables.tf` — `organization_features` variable (`map(string)`) supporting all GuardDuty feature names with per-feature auto-enable control.
- `variables.tf` — `additional_configuration` variable (`map(string)`) for runtime monitoring add-on configuration.
- `versions.tf` — Terraform `>= 1.5.0` and AWS provider `>= 5.0` version constraints.
- Input validation rules on all variables to catch misconfiguration during the plan phase.

### Changed

- Module fully restructured from v1.0. All Terraform source files are new; the module interface is functionally equivalent but the internal implementation has been rewritten.

### Removed

- `releases/v1.0.md` — Previous release notes file removed from the module source tree.
