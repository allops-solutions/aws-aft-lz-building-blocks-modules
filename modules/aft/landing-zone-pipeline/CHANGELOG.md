# Changelog

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.0] - 2026-07-24

### Added

- Initial release of the landing zone pipeline module
- CodePipeline V2 for self-managing the bootstrap repository (Control Tower + AFT + OUs)
- Support for both GitHub (via CodeStarSourceConnection) and AWS CodeCommit as VCS providers
- Automatic VCS provider detection from SSM parameter store (`/aft/config/vcs/provider`)
- Two pipeline execution modes:
  - **With manual approval (default)**: Source → Plan → Manual Approval → Apply stages
  - **Without manual approval**: Combined Source → Apply stage
- Cross-account IAM role assumption for Terraform execution in the Control Tower management account
- S3 artifact storage with versioning and automatic lifecycle expiration (14 days)
- CloudWatch log groups for CodeBuild plan and apply projects (365-day retention)
- EventBridge trigger integration for CodeCommit repositories (replaces V2 native triggers)
- Configurable pipeline trigger behavior via `enable_pipeline_trigger` variable
- Support for custom Terraform backend configuration (bucket and key)
- Comprehensive IAM policies for CodeBuild, CodePipeline, and EventBridge roles
- ARM64 CodeBuild environment using Amazon Linux 2
- Terraform 1.15.0 as the managed Terraform version
- Support for Terraform >= 1.6.0 with AWS provider >= 6.23.0
- Customizable tagging for all created resources


## [v1.0] - 2026-07-06

### Added

- Initial release of the `aft/landing-zone-pipeline` module
- CodePipeline V2 for automated Control Tower and AFT infrastructure management
- Dual VCS provider support: GitHub (via CodeStarSourceConnection) and AWS CodeCommit
- Configurable pipeline modes:
  - Manual approval mode: Source → Plan → Manual Approval → Apply
  - Automated mode: Source → Apply (combined plan+apply in single CodeBuild run)
- Cross-account Terraform execution via assumed role in Control Tower management account
- EventBridge integration for CodeCommit repository triggers
- CloudWatch logging for CodeBuild plan and apply phases
- S3 artifact storage with automatic lifecycle management (14-day retention)
- Versioned Terraform state bucket configuration with optional defaults
- VCS configuration auto-detection from AFT SSM parameters
- Configurable pipeline auto-triggering (can be disabled for manual execution)
- Customizable buildspec references via local file data sources
- Tagging support for all provisioned resources


## [v1.0] - 2026-07-03

### Added

- Initial release of the `aft/landing-zone-pipeline` module
- Self-managing CodePipeline for the Control Tower + AFT bootstrap repository
- AWS CodeConnections integration for GitHub source control
- Flexible pipeline modes:
  - **Manual approval mode** (default): Source → Plan → Manual Approval → Apply
  - **Combined mode**: Source → Apply (plan and apply in single CodeBuild run)
- CodeBuild projects for Terraform plan and apply operations
- S3 artifact store with versioning, lifecycle policies, and public access blocking
- CloudWatch log groups for CodeBuild execution tracking
- Cross-account IAM roles for secure Terraform execution in Control Tower management account
- Pipeline trigger configuration (automatic on main branch push or manual)
- Support for custom Terraform state bucket and key paths
- Comprehensive IAM policies for CodePipeline and CodeBuild services
- CodePipeline V2 with SUPERSEDED execution mode for optimal performance
- Configurable tags for all resources
