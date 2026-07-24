# Changelog

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

