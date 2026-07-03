# Changelog

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
