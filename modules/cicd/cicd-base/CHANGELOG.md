# Changelog

# Changelog

All notable changes to this module are documented in this file. This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [v1.0] - 2026-08-03

### Added

- Initial release of the `cicd/cicd-base` Terraform module.
- Hub mode for central CI/CD accounts, including:
  - Optional GitHub Actions OIDC provider creation.
  - Repository-scoped GitHub OIDC IAM roles.
  - Permissions for OIDC roles to assume workload deployment roles.
  - Optional additional AWS managed policy attachments for OIDC roles.
  - SSM parameters publishing the central CI/CD account ID and OIDC role ARNs.
- Spoke mode for workload accounts, including:
  - A fixed `cicd-deployer` role trusted by the central CI/CD account.
  - `AdministratorAccess` attached to the default deployment role.
  - Optional custom deployment roles with managed policies, inline policies, and permissions boundaries.
  - SSM parameters publishing default and custom deployment role ARNs to the AFT management account.
- Outputs for GitHub OIDC role ARNs, the default deployer role, and custom role ARNs.
- Support for applying common tags to created resources.

[v1.0]: https://github.com/allops-solutions/aws-aft-lz-building-blocks-modules/releases/tag/cicd-cicd-base-v1.0
