# Changelog

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
