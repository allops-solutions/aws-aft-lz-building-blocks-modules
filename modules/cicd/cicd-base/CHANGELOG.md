# Changelog

# Changelog

## [v1.0] - Initial release

### Added

- Added the `cicd/cicd-base` Terraform module with hub and spoke deployment modes.
- Added hub-mode support for creating a GitHub Actions OpenID Connect provider.
- Added repository-scoped GitHub OIDC IAM roles with optional additional managed policies.
- Added spoke-mode support for creating the `cicd-deployer` role trusted by the central CI/CD account and attached to `AdministratorAccess`.
- Added support for custom spoke deployment roles with managed policies, optional inline policies, and optional permissions boundaries.
- Added SSM Parameter Store publication of the CI/CD account ID and deployment-role ARNs in the AFT management account.
- Added outputs for GitHub OIDC roles, the default deployer role, and custom deployment roles.
- Added Terraform 1.6.0 and AWS provider 6.23.0 minimum version requirements, including the `aws.aft-management` provider alias.


## [1.0.0] - 2026-07-24

### Added

- Initial release of the CI/CD module for cross-account deployment orchestration
- **Hub mode** (CICD account):
  - GitHub Actions OpenID Connect (OIDC) provider with scoped IAM roles for repository-specific access
  - CodeBuild service role with permissions for artifact handling, CloudWatch logging, SSM parameter access, and workload role assumption
  - CodePipeline service role with permissions for artifact management, CodeBuild integration, CodeStar connections, and CodeCommit access
  - All hub roles can assume workload deployment roles across accounts
- **Spoke mode** (workload accounts):
  - Default deployment role (`cicd-deployer`) with AdministratorAccess, trusting the central CICD account
  - Support for custom deployment roles with configurable policies and permissions boundaries
  - Inline policy support for fine-grained permissions on custom roles
- **Cross-account role discovery** via SSM Parameter Store in the AFT management account:
  - Hub mode publishes service role ARNs (CodeBuild, CodePipeline, GitHub OIDC)
  - Spoke mode publishes deployment role ARNs (default and custom)
- Module outputs for hub and spoke role ARNs for downstream consumption
- Support for Terraform >= 1.6.0 and AWS provider >= 6.23.0 with provider alias configuration
