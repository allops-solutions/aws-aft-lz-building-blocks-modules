# Changelog

## [1.0.0] - 2026-07-24

### Added

- Initial release of the `aft/customization-trigger` module
- CodePipeline V2 that watches global-customizations and account-customizations repositories for pushes
- Automatic invocation of the `aft-invoke-customizations` Step Function on repository updates
- Support for both GitHub (via CodeStarSourceConnection) and AWS CodeCommit as VCS providers
- VCS provider auto-detection from SSM parameter store (`/aft/config/vcs/provider`)
- CodeBuild project for triggering Step Function executions
- S3 bucket for pipeline artifacts with 1-day expiration lifecycle policy
- EventBridge rules for CodeCommit repository change detection (when CodeCommit is the VCS provider)
- Comprehensive IAM roles and policies for CodePipeline, CodeBuild, and EventBridge services
- Configurable resource tagging for all AWS resources
- Monitoring of pushes to the `main` branch in both customization repositories


