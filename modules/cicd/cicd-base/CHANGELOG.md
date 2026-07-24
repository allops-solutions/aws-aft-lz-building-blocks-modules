# Changelog

# Changelog

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

### Changed

### Fixed

### Removed


# Changelog

## [v1.0] - 2026-07-03

### Added

- Initial release of `cicd/cicd-base` module
- **Hub mode (CICD account):**
  - GitHub Actions OIDC provider configuration with federated trust
  - Configurable GitHub OIDC roles scoped to repository workflows
  - CodeBuild service role with permissions for cross-account role assumption, CloudWatch logs, S3 artifacts, SSM parameters, and KMS operations
  - CodePipeline service role with permissions for artifact management, CodeBuild integration, CodeStar connections, and CodeCommit
- **Spoke mode (workload accounts):**
  - Default deployment role (`cicd-deployer`) with AdministratorAccess trusting the CICD account
  - Support for custom deployment roles with configurable IAM policies and permissions boundaries
  - Inline policy support for complex role requirements
- **Role discovery via SSM Parameters:**
  - Automatic publication of all role ARNs to AFT management account
  - Hub mode: service role ARNs and central CICD account ID
  - Spoke mode: default and custom deployment role ARNs per account
- **Outputs:** ARNs for all created roles (service roles, GitHub OIDC roles, deployer roles, custom roles)
- **Provider configuration:** Support for provider aliases (`aws.aft-management`) for cross-account SSM parameter publishing
