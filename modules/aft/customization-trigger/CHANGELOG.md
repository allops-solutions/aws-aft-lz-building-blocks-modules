# Changelog

## [v2.0] — 2026-07-01

### Added

- `main.tf` — Full module implementation including:
  - CodePipeline V2 with git push triggers on `main` branch for both `global-customizations` and `account-customizations` repositories.
  - CodeBuild project using ARM Lambda container (`python3.14`) to invoke the `aft-invoke-customizations` Step Function.
  - Dedicated least-privilege IAM roles for CodePipeline and CodeBuild.
  - S3 artifact bucket with 1-day lifecycle expiration rule.
  - SSM parameter data source to read the CodeConnections ARN created by the AFT module.
- `variables.tf` — Module input variables: `ct_home_region`, `aft_management_account_id`, `github_username`, `customer_name`, `tags`.
- `versions.tf` — Terraform and provider version constraints (Terraform >= 1.5.0, AWS provider >= 6.0.0).

### Removed

- `releases/v1.0.md` — Previous release notes file removed from the module source tree.
