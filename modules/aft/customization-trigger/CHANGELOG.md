# Changelog

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


## [1.0.0] - 2026-07-06

### Added
- Initial release of the aft/customization-trigger module
- CodePipeline V2 that automatically triggers customizations on repository pushes
- Automatic VCS provider detection (GitHub via CodeStarSourceConnection or CodeCommit)
- Support for both GitHub and CodeCommit source repositories
- IAM roles and policies for CodePipeline, CodeBuild, and EventBridge
- S3 bucket for pipeline artifacts with 1-day expiration lifecycle policy
- CodeBuild project that invokes the aft-invoke-customizations Step Function
- EventBridge rules for CodeCommit repository push events (main branch only)
- Dynamic trigger configuration based on VCS provider
- Tagging support for all created resources


## [1.0] - 2026-07-03

### Added
- Initial release of the `aft/customization-trigger` module
- CodePipeline V2 that monitors global-customizations and account-customizations repositories for pushes to the main branch
- Automatic invocation of the `aft-invoke-customizations` Step Function when repository changes are detected
- CodeBuild project for triggering the Step Function with customization parameters
- IAM roles and policies for CodePipeline and CodeBuild service permissions
- S3 bucket for pipeline artifacts with automatic 1-day expiration lifecycle
- Support for GitHub-based repository monitoring via CodeStar Connections
- Configuration parameters for Control Tower home region, AFT management account, GitHub credentials, and customer naming
- Default tagging support for all created resources
