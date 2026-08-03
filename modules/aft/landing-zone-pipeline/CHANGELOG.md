# Changelog

# Changelog

## [v1.0] - 2026-08-03

### Added

- Initial release of `aft/landing-zone-pipeline` module
- Self-managing CodePipeline for the bootstrap repository (Control Tower + AFT + OUs)
- Support for dual VCS providers: GitHub (via CodeStarSourceConnection) and CodeCommit
- Configurable pipeline layout with manual approval workflow (`enable_manual_approval`)
  - With approval: Source → Plan → Manual Approval → Apply
  - Without approval: Source → Apply (combined plan + apply in one CodeBuild run)
- Cross-account execution model: CodeBuild assumes a role in the CT management account to run Terraform
- Automatic VCS provider detection from AFT SSM parameters (`/aft/config/vcs/provider`)
- EventBridge-based triggers for CodeCommit repositories when pipeline trigger is enabled
- CodePipeline V2 with SUPERSEDED execution mode for GitHub repositories
- S3 bucket for pipeline artifacts with versioning, lifecycle policies, and public access blocking
- IAM roles and policies for CodeBuild, CodePipeline, and EventBridge
- CloudWatch log groups for CodeBuild plan and apply projects (365-day retention)
- Cross-account IAM execution role in CT management account with AdministratorAccess
- Configurable Terraform version, state bucket, and state key parameters
- Optional pipeline trigger control (`enable_pipeline_trigger`)
- Comprehensive variable support for customization (customer name, GitHub username, tags, etc.)
