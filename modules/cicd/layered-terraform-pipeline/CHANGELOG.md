# Changelog

## [v1.0] - Initial release

### Added

- Added the `cicd/layered-terraform-pipeline` module for creating layered Terraform delivery pipelines with dependency-aware routing across development, intermediate, and production environments.
- Added dynamic CodePipeline V2 stage generation for direct applies, optional parallel dependent-layer applies, and production plan, approval, and apply stages.
- Added per-layer change detection using SSM last-applied commit watermarks, with support for forced full-sequential executions.
- Added GitHub CodeConnections and CodeCommit source support, including path-filtered GitHub triggers and EventBridge-based CodeCommit change detection.
- Added dedicated CodeBuild projects for routing, Terraform planning, and Terraform applying.
- Added optional manual approval notifications through SNS and configurable Terraform and CodeBuild settings.
- Added a separate, manual-only rollback pipeline that applies all layers in reverse dependency order at a selected commit.
- Added optional creation of a secure, versioned, encrypted S3 artifact bucket with lifecycle expiration and insecure-transport protection.
- Added dedicated CodePipeline and CodeBuild IAM roles with permissions scoped to the configured pipeline, artifacts, source, watermarks, reports, and deployer roles.
- Added optional creation of deployer roles in the current account for self-contained deployments.
- Added outputs for pipeline resources, generated stages, CodeBuild projects, deployer roles, artifact storage, watermark parameters, and the rollback pipeline.
