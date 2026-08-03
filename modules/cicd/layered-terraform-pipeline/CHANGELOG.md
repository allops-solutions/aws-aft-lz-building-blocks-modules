# Changelog

# Changelog

## [v1.0] - 2026-08-03

### Added

- Initial release of the `cicd/layered-terraform-pipeline` Terraform module.
- Generated AWS CodePipeline workflow for layered Terraform deployments across development, intermediate, and production environments.
- Change-aware routing with per-environment and per-layer SSM watermarks, sequential and parallel execution modes, and full sequential manual releases.
- Saved Terraform plan workflow with optional manual approvals, plan integrity checks, and production layer-by-layer promotion.
- Dedicated reverse-order production rollback pipeline controlled by a target commit.
- GitHub CodeConnections and CodeCommit source support, including branch and path-based change detection.
- CodeBuild route, plan, and apply projects with configurable compute, Terraform version, timeouts, artifact retention, IAM roles, and deployment-role creation.
